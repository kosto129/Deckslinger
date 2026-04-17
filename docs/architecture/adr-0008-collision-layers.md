# ADR-0008: Collision Layer Strategy

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics (2D) |
| **Knowledge Risk** | LOW — Area2D, CollisionShape2D, collision layers/masks unchanged |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md` |
| **Post-Cutoff APIs Used** | None — 2D physics unchanged. Jolt default only affects 3D. |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Entity Composition — HitboxComponent/HurtboxComponent are entity children), ADR-0007 (Animation — ACTIVE phase enables hitbox) |
| **Enables** | ADR-0009 (Damage Pipeline — HitData delivery triggers damage resolution) |
| **Blocks** | Combat System implementation, all combat-related testing |
| **Ordering Note** | Must be accepted before Combat System can process hits |

## Context

### Problem Statement
Deckslinger's combat requires precise per-frame hitbox/hurtbox detection with faction filtering (player hits enemies, enemies hit player, no friendly fire, no self-damage). We need a collision layer strategy that Godot's Area2D system can evaluate efficiently with zero custom overlap checks.

## Decision

**Use 7 Godot collision layers with pre-configured masks on Area2D nodes so that Godot's built-in overlap detection handles all faction filtering automatically. HitboxComponent and HurtboxComponent are separate Area2D nodes with configured layer/mask pairs.**

### Layer Assignment

| Layer | Bit | Name | Used By |
|-------|-----|------|---------|
| 1 | `PLAYER_HITBOX` | Player's HitboxComponent |
| 2 | `PLAYER_HURTBOX` | Player's HurtboxComponent |
| 3 | `ENEMY_HITBOX` | Enemy HitboxComponents |
| 4 | `ENEMY_HURTBOX` | Enemy HurtboxComponents |
| 5 | `PROJECTILE_PLAYER` | Player-faction projectile hitboxes |
| 6 | `PROJECTILE_ENEMY` | Enemy-faction projectile hitboxes |
| 7 | `ENVIRONMENT` | Walls, obstacles (movement collision) |

### Mask Configuration

| Component | Layer (what it IS) | Mask (what it DETECTS) | Result |
|-----------|-------------------|----------------------|--------|
| Player Hitbox | 1 | 4 | Player hits enemy hurtboxes |
| Player Hurtbox | 2 | 3, 6 | Player is hit by enemy hitboxes + enemy projectiles |
| Enemy Hitbox | 3 | 2 | Enemies hit player hurtbox |
| Enemy Hurtbox | 4 | 1, 5 | Enemies are hit by player hitboxes + player projectiles |
| Player Projectile | 5 | 4, 7 | Player projectiles hit enemy hurtboxes + walls |
| Enemy Projectile | 6 | 2, 7 | Enemy projectiles hit player hurtbox + walls |

**Guarantees by configuration:**
- No friendly fire (player hitbox never masks player hurtbox)
- No self-damage (AoE from player ignores player hurtbox)
- No enemy-on-enemy damage (enemy hitbox never masks enemy hurtbox)
- Projectiles hit walls (layer 7 detected by projectile masks)

### HitData Delivery

```gdscript
# On HitboxComponent — enabled during ACTIVE animation phase
func _on_area_entered(area: Area2D) -> void:
    if area is HurtboxComponent:
        var hurtbox: HurtboxComponent = area as HurtboxComponent
        if _already_hit.has(hurtbox.get_parent()):
            return  # single-hit rule
        _already_hit[hurtbox.get_parent()] = true
        var hit_data: HitData = _create_hit_data(hurtbox)
        hurtbox.receive_hit(hit_data)
```

### Single-Hit Rule

HitboxComponent maintains a `Dictionary` of entities already hit during the current action. Cleared when AnimationComponent emits `action_completed`:

```gdscript
var _already_hit: Dictionary = {}  # EntityBase → true

func enable(template: HitData) -> void:
    _hit_data_template = template
    _already_hit.clear()
    monitoring = true

func disable() -> void:
    monitoring = false
```

### I-Frames

HurtboxComponent tracks invincibility:

```gdscript
var _iframes_remaining: int = 0

func receive_hit(hit_data: HitData) -> void:
    if _iframes_remaining > 0:
        return  # invincible — ignore hit
    hit_received.emit(hit_data)
    _iframes_remaining = IFRAMES_DURATION

func _physics_process(_delta: float) -> void:
    if _frozen: return
    if _iframes_remaining > 0:
        _iframes_remaining -= 1
        _update_flicker()
```

## Alternatives Considered

### Alternative 1: Manual Overlap Checks (no layers)
- **Description**: All hitboxes on same layer, check faction in code after overlap detected
- **Pros**: Simpler layer setup
- **Cons**: Every overlap triggers code even for invalid pairs (player hitbox overlaps player hurtbox). Wastes CPU on spurious checks.
- **Rejection Reason**: Godot's layer/mask system exists precisely to filter at the physics engine level. More efficient and less error-prone.

### Alternative 2: PhysicsBody2D with Collision Groups
- **Description**: Use CharacterBody2D or StaticBody2D instead of Area2D
- **Pros**: Built-in physics response (push, slide)
- **Cons**: Combat hitboxes are detection-only, not physics bodies. We don't want hitboxes to push entities — that's handled by knockback in the damage pipeline.
- **Rejection Reason**: Area2D is the correct Godot node for detection-only collision.

## Consequences

### Positive
- All faction filtering happens at the engine level — zero per-frame code for filtering
- Adding new factions (future: neutral NPCs) requires adding layers, not changing code
- Single-hit rule and i-frames are simple frame-counted systems

### Negative
- Godot has 32 collision layers total — 7 used here, leaves 25 for future use. Not a concern.
- Hitbox shapes must be authored per attack in scene files (no procedural hitbox generation)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| collision-hitbox-system.md | CA.1 — Component Structure | HitboxComponent (Area2D) + HurtboxComponent (Area2D) as entity children |
| collision-hitbox-system.md | CA.2 — Collision Layers | 7 layers with mask configuration for faction filtering |
| collision-hitbox-system.md | HD.2 — HitData Structure | HitData RefCounted with source, target, damage, knockback, effects |
| collision-hitbox-system.md | HR.1 — Single-Hit Rule | _already_hit Dictionary cleared per action |
| collision-hitbox-system.md | HR.3 — I-Frames | HurtboxComponent frame counter with flicker |
| collision-hitbox-system.md | HR.5 — Dodge I-Frames | HurtboxComponent.set_enabled(false) during dodge |

## Performance Implications
- **CPU**: Godot's Area2D overlap is broadphase-optimized. 8 entities × 2 areas each = 16 Area2D nodes. Negligible.
- **Memory**: ~200 bytes per collision component. Negligible.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. Player hitbox overlapping enemy hurtbox triggers hit_received signal
2. Player hitbox overlapping player hurtbox does NOT trigger any signal (faction filtering)
3. Enemy hitbox overlapping enemy hurtbox does NOT trigger any signal
4. Same hitbox overlapping same hurtbox for 5 consecutive frames triggers hit_received exactly once (single-hit rule)
5. After taking a hit, entity ignores all hits for IFRAMES_DURATION frames

## Related Decisions
- ADR-0001: Entity Composition (components as child nodes)
- ADR-0007: Animation (ACTIVE phase enables hitbox)
- ADR-0009: Damage Pipeline (receives HitData from collision)
