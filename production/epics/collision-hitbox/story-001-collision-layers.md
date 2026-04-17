# Story 001: Collision Layer Configuration

> **Epic**: Collision/Hitbox System
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/collision-hitbox-system.md`
**Requirement**: `TR-CH-001`, `TR-CH-002`

**ADR Governing Implementation**: ADR-0008: Collision Layer Strategy
**ADR Decision Summary**: 7 Godot collision layers with pre-configured masks on Area2D nodes. Faction filtering handled entirely at the physics engine level — no per-frame code checks needed. Guarantees: no friendly fire, no self-damage, no enemy-on-enemy damage.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Area2D collision layers/masks API unchanged across 4.4–4.6. Jolt physics (4.6 default) only affects 3D — 2D Area2D detection is unaffected.

**Control Manifest Rules (Core)**:
- Required: Use Area2D for all hitbox/hurtbox detection — Area2D is detection-only, not a physics body
- Required: Configure collision layer/mask pairs so Godot handles faction filtering — no per-frame faction checks in code
- Forbidden: Never use PhysicsBody2D for combat collision
- Forbidden: Never check faction in code after overlap detection

---

## Acceptance Criteria

- [ ] Godot Project Settings → Physics → 2D → Layer Names configured with 7 named layers:
  - Layer 1: `PLAYER_HITBOX`
  - Layer 2: `PLAYER_HURTBOX`
  - Layer 3: `ENEMY_HITBOX`
  - Layer 4: `ENEMY_HURTBOX`
  - Layer 5: `PROJECTILE_PLAYER`
  - Layer 6: `PROJECTILE_ENEMY`
  - Layer 7: `ENVIRONMENT`
- [ ] `HitboxComponent` (Area2D) for player entity: `collision_layer = 1` (PLAYER_HITBOX), `collision_mask = 4` (ENEMY_HURTBOX)
- [ ] `HurtboxComponent` (Area2D) for player entity: `collision_layer = 2` (PLAYER_HURTBOX), `collision_mask = 3 | 6` (ENEMY_HITBOX + PROJECTILE_ENEMY)
- [ ] `HitboxComponent` (Area2D) for enemy entity: `collision_layer = 3` (ENEMY_HITBOX), `collision_mask = 2` (PLAYER_HURTBOX)
- [ ] `HurtboxComponent` (Area2D) for enemy entity: `collision_layer = 4` (ENEMY_HURTBOX), `collision_mask = 1 | 5` (PLAYER_HITBOX + PROJECTILE_PLAYER)
- [ ] Player projectile hitbox: `collision_layer = 5` (PROJECTILE_PLAYER), `collision_mask = 4 | 7` (ENEMY_HURTBOX + ENVIRONMENT)
- [ ] Enemy projectile hitbox: `collision_layer = 6` (PROJECTILE_ENEMY), `collision_mask = 2 | 7` (PLAYER_HURTBOX + ENVIRONMENT)
- [ ] Verified in engine: Player hitbox overlapping player hurtbox produces NO `area_entered` signal
- [ ] Verified in engine: Enemy hitbox overlapping enemy hurtbox produces NO `area_entered` signal

---

## Implementation Notes

From ADR-0008: Layer/mask pairs are set on each component's Area2D node. In GDScript, collision layers and masks are set as bitmasks. Layer bit positions are 1-indexed (bit 0 = layer 1).

```gdscript
# Layer bit helpers — define as constants in a collision_layers.gd or in Enums
const LAYER_PLAYER_HITBOX:    int = 1        # bit 0
const LAYER_PLAYER_HURTBOX:   int = 1 << 1  # bit 1
const LAYER_ENEMY_HITBOX:     int = 1 << 2  # bit 2
const LAYER_ENEMY_HURTBOX:    int = 1 << 3  # bit 3
const LAYER_PROJ_PLAYER:      int = 1 << 4  # bit 4
const LAYER_PROJ_ENEMY:       int = 1 << 5  # bit 5
const LAYER_ENVIRONMENT:      int = 1 << 6  # bit 6

# Player HitboxComponent setup
func _configure_player_hitbox(hitbox: Area2D) -> void:
    hitbox.collision_layer = LAYER_PLAYER_HITBOX
    hitbox.collision_mask  = LAYER_ENEMY_HURTBOX
```

Preferred approach: Set layer/mask values directly in the Godot editor on the component scene (.tscn files) rather than in code. Constants are used only for documentation and test verification.

Project Settings path (Godot 4.6): `Project → Project Settings → General → Physics → 2D → Layer Names`. Enter the layer name string in the corresponding slot (slot 1 = "PLAYER_HITBOX", etc.).

---

## Out of Scope

- Story 002: HitboxComponent and HurtboxComponent logic (enable/disable, HitData creation)
- Story 003: I-frames and flicker
- CollisionShape2D hitbox shapes — defined per entity in entity scene files, not in this story

---

## QA Test Cases

This is a Config/Data story. Verification is a smoke-check on Project Settings and in-engine behavior.

- **AC-1**: Layer names in Project Settings
  - Given: Project opened in Godot 4.6
  - When: Inspect Project Settings → Physics → 2D → Layer Names
  - Then: Slots 1–7 display the exact names listed in acceptance criteria

- **AC-2**: No self-damage (player AoE)
  - Given: Player HitboxComponent and Player HurtboxComponent instantiated in the same scene
  - When: Both nodes overlap in physics frame
  - Then: No `area_entered` signal fires on either component (masks exclude own faction)

- **AC-3**: No friendly fire (enemy-on-enemy)
  - Given: Two enemy entities with HitboxComponent (layer 3) and HurtboxComponent (layer 4)
  - When: Enemy hitbox overlaps enemy hurtbox
  - Then: No `area_entered` signal fires

- **AC-4**: Player hits enemy
  - Given: Player HitboxComponent (layer 1, mask 4) and Enemy HurtboxComponent (layer 4)
  - When: Components overlap
  - Then: `area_entered` fires on Player HitboxComponent — enemy hurtbox is detected

- **AC-5**: Enemy projectile hits player
  - Given: Enemy Projectile (layer 6, mask 2) and Player HurtboxComponent (layer 2)
  - When: Components overlap
  - Then: `area_entered` fires — hit is detected

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check at `production/qa/smoke-collision-layers.md` — layer names verified in Project Settings, AC-2 through AC-5 manually verified in engine
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — HitboxComponent and HurtboxComponent exist as Area2D child nodes on EntityBase
- Unlocks: Story 002 (Hit Detection — HitboxComponent logic requires layers to be configured)
- Unlocks: Story 003 (I-Frames — HurtboxComponent logic requires correct layer setup)
