# Collision/Hitbox System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (Every Card Is a Commitment)

## Summary

The Collision/Hitbox System manages per-frame hitbox/hurtbox detection for all
combat interactions, using Godot's Area2D nodes with faction-based filtering.
It determines what hits what, delivers HitData to the Combat System, and
enforces hit rules (multi-hit prevention, invincibility frames, priority).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Entity Framework`

## Overview

The Collision/Hitbox System is the spatial truth of Deckslinger's combat. It
answers one question per physics frame: "Did anything hit anything?" Every
entity with combat participation has a `HurtboxComponent` (where it can be
hit) and optionally a `HitboxComponent` (where it can hit others). Hitboxes
are enabled only during the ACTIVE phase of an animation sequence (per
Animation State Machine rules) and disabled otherwise. When a hitbox overlaps
a hurtbox, the system checks faction validity (enemies can't hit enemies,
player can't hit self), builds a `HitData` packet, and delivers it to the
hurtbox. The hurtbox routes the hit to the Combat System for damage
resolution. The Collision/Hitbox System never calculates damage — it only
detects contact and delivers data.

## Player Fantasy

Hits feel honest. When the player's sword visually connects with an enemy,
the hit registers. When an enemy's attack visually misses, no damage is dealt.
The collision footprints (defined in Entity Framework) are generous to the
player — slightly smaller than sprites — so near-misses feel like skillful
dodges rather than unfair hits. The player builds trust in the collision system
through consistent behavior: if it looked like it hit, it hit. If it looked
like it missed, it missed.

## Detailed Rules

### Collision Architecture

**CA.1 — Component Structure**

Each combat-participating entity has up to two collision components:

| Component | Node Type | Purpose | Controlled By |
|-----------|-----------|---------|---------------|
| `HitboxComponent` | Area2D | Deals hits to overlapping hurtboxes | Animation State Machine (enable/disable) |
| `HurtboxComponent` | Area2D | Receives hits from overlapping hitboxes | Always active when entity lifecycle is ACTIVE/STUNNED |

Both components are child nodes of `EntityBase`. Their shapes are defined by
`CollisionShape2D` children and match the entity's collision footprint from
the Entity Framework.

**CA.2 — Collision Layers**

Godot's collision layer/mask system separates concerns:

| Layer | Bit | Used By |
|-------|-----|---------|
| `PLAYER_HITBOX` | 1 | Player's HitboxComponent |
| `PLAYER_HURTBOX` | 2 | Player's HurtboxComponent |
| `ENEMY_HITBOX` | 3 | Enemy HitboxComponents |
| `ENEMY_HURTBOX` | 4 | Enemy HurtboxComponents |
| `PROJECTILE_PLAYER` | 5 | Player-faction projectile hitboxes |
| `PROJECTILE_ENEMY` | 6 | Enemy-faction projectile hitboxes |
| `ENVIRONMENT` | 7 | Walls, obstacles (for movement collision, not combat) |

Mask configuration ensures:
- Player hitbox detects enemy hurtboxes (layer 1 masks layer 4)
- Enemy hitbox detects player hurtbox (layer 3 masks layer 2)
- Player projectiles detect enemy hurtboxes (layer 5 masks layer 4)
- Enemy projectiles detect player hurtbox (layer 6 masks layer 2)
- No friendly fire: player hitbox does NOT mask player hurtbox
- No enemy-on-enemy: enemy hitbox does NOT mask enemy hurtbox

**CA.3 — Hitbox Shapes**

Hitbox shapes vary by attack type:

| Attack Pattern | Shape | Typical Size | Example |
|----------------|-------|-------------|---------|
| Melee strike | Rectangle | 20×12 px, offset in facing direction | Quick Draw, enemy melee |
| Wide slash | Rectangle or Polygon | 28×16 px, offset + rotated | Heavy Blow |
| Cone/Fan | Polygon (triangle) | 24px depth, 30° angle | Fan Shot |
| Line/Beam | Thin rectangle | 4×64 px, along aim direction | Beam attacks |
| AoE circle | Circle | 32–64 px radius | Smoke Screen |
| Projectile | Circle or small rectangle | 4–8 px radius | Bullet, thrown object |

Shapes are defined per animation key in the entity's scene file. The
AnimationComponent enables the correct hitbox shape when ACTIVE begins.

### Hit Detection

**HD.1 — Detection Timing**

Hit detection occurs every physics frame (`_physics_process`). Godot's Area2D
overlap detection handles the spatial query. The HitboxComponent listens for
`area_entered` signals from overlapping HurtboxComponents.

**HD.2 — HitData Structure**

When a valid hit is detected, a `HitData` resource is created and passed to
the hurtbox:

```gdscript
class_name HitData extends RefCounted

var source_entity: EntityBase      # who attacked
var target_entity: EntityBase      # who was hit
var damage: int                    # base damage (before Combat System modifiers)
var knockback_direction: Vector2   # normalized direction of knockback
var knockback_force: float         # knockback magnitude (0 = none)
var hit_position: Vector2          # world position of collision point
var effect_source: StringName      # card_id or enemy_attack_id that caused this
var shake_intensity: float         # screen shake to request (0 = none)
var status_effects: Array[StringName]  # status effect IDs to apply on hit
```

**HD.3 — Hit Delivery**

```
HitboxComponent.area_entered(hurtbox_area) →
  HitboxComponent creates HitData →
  HurtboxComponent.receive_hit(hit_data) →
  HurtboxComponent emits hit_received(hit_data) signal →
  Combat System processes damage
```

The HitboxComponent creates the HitData because it knows the source (attacker,
card, damage values). The HurtboxComponent receives it and routes to Combat.

### Hit Rules

**HR.1 — Single-Hit Rule**

A hitbox can only hit the same hurtbox once per action sequence (one
WINDUP→ACTIVE→RECOVERY cycle). This prevents multi-frame hitboxes from
dealing damage every frame of overlap. Implementation: each HitboxComponent
maintains a `Set` of entity IDs already hit during the current action. The
set is cleared when the action sequence ends (`action_completed` signal).

**HR.2 — Multi-Target Hits**

A hitbox CAN hit multiple different hurtboxes in the same action. A wide slash
that overlaps two enemies hits both (once each). Each generates its own HitData.

**HR.3 — Invincibility Frames (I-Frames)**

After being hit, an entity gains `IFRAMES_DURATION` frames of invincibility.
During i-frames, the HurtboxComponent ignores all incoming hits. Visual
feedback: the entity sprite flickers (alternates visible/invisible every 3
frames). I-frames do not apply during hit-stop — the freeze frames don't
count toward i-frame duration.

**HR.4 — Projectile Hit Rules**

Projectile hitboxes follow different rules:
- Projectiles destroy on first hit (single-target): hitbox disabled after
  first `area_entered`, projectile enters despawn sequence
- Piercing projectiles: can hit multiple targets but still only once per target
  (same single-hit rule)
- Projectiles do NOT have i-frame interaction — a projectile can hit an entity
  even if another projectile hit them recently (i-frames only apply to the
  same source type within the same action)

**HR.5 — Dodge I-Frames**

During a dodge/dash action (initiated by the dodge input), the player's
hurtbox is disabled for `DODGE_IFRAMES` frames. This is a full invulnerability
window, not a flickering i-frame. The player can dodge through enemy attacks
and projectiles. The dodge i-frames are a property of the dodge action, not
the Collision System — but the Collision System enforces them by reading the
hurtbox enabled state.

### Shape Management

**SM.1 — Dynamic Shape Activation**

Entities may have multiple hitbox shapes (one per attack type). Only one is
active at a time. The AnimationComponent selects the correct shape by enabling
the corresponding `CollisionShape2D` child when an action begins:

```
play_action("heavy_blow_e") →
  Enable CollisionShape2D "hitbox_heavy_blow" →
  Disable all other hitbox collision shapes
```

**SM.2 — Shape Positioning**

Hitbox shapes are positioned relative to the entity's origin and offset in the
facing direction. When the facing direction is locked during an action (per
Animation State Machine rules), the hitbox position is also locked.

## Formulas

**F.1 — I-Frame Timer**

```
Variables:
  iframes_remaining  = frames of invincibility left
  IFRAMES_DURATION   = total i-frame duration (default: 20 frames = 333ms)
  in_hitstop         = whether hit-stop is active (boolean)

Output:
  is_invincible = boolean (true if entity should ignore hits)

Formula:
  Per physics frame:
    if NOT in_hitstop:
        iframes_remaining = max(iframes_remaining - 1, 0)
    is_invincible = iframes_remaining > 0

Example:
  Entity hit at frame 100. IFRAMES_DURATION = 20.
  Frame 100: iframes_remaining = 20, is_invincible = true
  Frame 110: iframes_remaining = 10, is_invincible = true
  Frame 115: hit-stop begins (3 frames). Timer pauses.
  Frame 118: hit-stop ends. iframes_remaining still 10.
  Frame 128: iframes_remaining = 0, is_invincible = false
```

**F.2 — Flicker Timing**

```
Variables:
  iframes_remaining = current i-frame counter
  FLICKER_INTERVAL  = frames between visibility toggles (default: 3)

Output:
  is_visible = boolean for sprite rendering

Formula:
  if iframes_remaining > 0:
      is_visible = (iframes_remaining / FLICKER_INTERVAL) % 2 == 0
  else:
      is_visible = true

Example (FLICKER_INTERVAL = 3, starting at 20):
  Frame 20-18: visible (20/3=6, even)
  Frame 17-15: hidden (17/3=5, odd)
  Frame 14-12: visible
  Frame 11-9: hidden
  ... alternating until 0
```

**F.3 — Knockback Vector**

```
Variables:
  source_pos = attacker world position (Vector2)
  target_pos = target world position (Vector2)
  knockback_force = from CardData or enemy attack data (float, pixels)

Output:
  knockback_velocity = Vector2 applied to target's movement

Formula:
  direction = (target_pos - source_pos).normalized()
  knockback_velocity = direction * knockback_force

Example:
  source_pos = (100, 50), target_pos = (120, 50), knockback_force = 32
  direction = (20, 0).normalized() = (1, 0)
  knockback_velocity = (32, 0)  # pushed 32px to the right
```

**F.4 — Hitbox Offset by Facing Direction**

```
Variables:
  facing_dir     = entity facing direction (normalized Vector2)
  base_offset    = hitbox offset distance from entity origin (default: 12px)
  hitbox_local   = base local position of the hitbox shape

Output:
  hitbox_world_offset = world-space offset for the hitbox

Formula:
  hitbox_world_offset = facing_dir * base_offset

Example (facing East):
  facing_dir = (1, 0), base_offset = 12
  hitbox_world_offset = (12, 0)  # hitbox extends 12px to the right

Example (facing NE):
  facing_dir = (0.707, -0.707), base_offset = 12
  hitbox_world_offset = (8.5, -8.5)  # offset diagonally
```

## Edge Cases

- **Hitbox and hurtbox overlap on spawn**: Entities in SPAWNING state have
  hurtboxes disabled. No hit can register during spawn animation. Prevents
  enemies from being hit before they're visible.

- **Two hitboxes overlap the same hurtbox in the same frame**: Each generates
  a separate HitData. Both are delivered. Combat System processes them
  sequentially. I-frames from the first hit may block the second if they're
  from the same source category.

- **Entity dies mid-hit-delivery**: HitData is delivered to a DYING entity.
  HurtboxComponent checks lifecycle state — if DYING or DEAD, hit is discarded.
  No damage to dead entities.

- **Hitbox extends outside room bounds**: Legal. The hitbox detects any
  overlapping hurtbox regardless of room bounds. Room bounds are a camera
  concern, not a collision concern.

- **Projectile hits wall (ENVIRONMENT layer)**: Projectile listens for
  ENVIRONMENT collisions separately. On wall hit: projectile despawns, no
  damage dealt. The wall is not a hurtbox.

- **Player hurtbox disabled during dodge, enemy hitbox sweeps through**:
  No hit registered. The hitbox's `area_entered` signal does not fire because
  the hurtbox collision shape is disabled. When dodge ends and hurtbox
  re-enables, no retroactive detection occurs — the hitbox may have already
  passed through.

- **AoE effect centered on player position**: Player's own hurtbox is not hit
  because the player hitbox layer does not mask the player hurtbox layer.
  Faction filtering prevents self-damage.

- **Hitbox active for 0 frames** (active_frames = 0 in animation): The hitbox
  is never enabled. No hit can occur. This is a degenerate case that should be
  caught by CardData validation.

- **Entity has HitboxComponent but no HurtboxComponent**: Legal (projectiles).
  The entity can deal damage but cannot receive it. Functions correctly.

- **Multiple collision shapes on one hitbox**: Only the shapes marked as
  enabled contribute to overlap detection. The AnimationComponent is responsible
  for enabling exactly one shape per action.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Entity Framework | `HitboxComponent`, `HurtboxComponent` nodes, `FactionComponent` for filtering | Hard |
| Upstream | Animation State Machine | `active_started` / `action_completed` signals for hitbox enable/disable timing | Hard |
| Downstream | Combat System | Delivers `HitData` via `hit_received` signal on HurtboxComponent | Hard |
| Downstream | Camera System | `shake_intensity` from HitData triggers screen shake | Soft |
| Downstream | Status Effect System | `status_effects` array in HitData triggers status application | Soft |

Public API (on HitboxComponent):

```gdscript
func enable(hit_data_template: HitData) -> void  # enable with pre-filled damage data
func disable() -> void
func is_active() -> bool
func clear_hit_targets() -> void  # reset single-hit tracking
```

Public API (on HurtboxComponent):

```gdscript
func receive_hit(hit_data: HitData) -> void
func set_invincible(frames: int) -> void
func is_invincible() -> bool
func set_enabled(enabled: bool) -> void  # for dodge i-frames

signal hit_received(hit_data: HitData)
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `IFRAMES_DURATION` | 20 frames (333ms) | 10–40 | Post-hit invincibility. Too low = player feels juggled. Too high = player ignores threats. |
| `DODGE_IFRAMES` | 12 frames (200ms) | 6–20 | Dodge invulnerability window. Too low = dodge feels useless. Too high = dodge trivializes combat. |
| `FLICKER_INTERVAL` | 3 frames | 2–5 | I-frame visual flicker rate. Lower = faster flicker. Higher = slower, more noticeable. |
| `KNOCKBACK_FRICTION` | 0.85 | 0.7–0.95 | Per-frame velocity multiplier for knockback decay. Lower = stops faster. Higher = slides further. |
| `MAX_KNOCKBACK_FORCE` | 64 px | 32–128 | Hard cap on knockback distance. Prevents entities from being launched off-screen. |
| `HITBOX_OFFSET_BASE` | 12 px | 8–20 | Default distance hitbox extends from entity origin. Affects melee reach. |

## Acceptance Criteria

1. **GIVEN** player's hitbox overlaps an enemy's hurtbox during ACTIVE phase,
   **WHEN** factions are hostile, **THEN** HitData is delivered to the enemy's
   HurtboxComponent exactly once.

2. **GIVEN** player's hitbox overlaps two enemy hurtboxes simultaneously,
   **WHEN** both are valid targets, **THEN** both receive separate HitData
   in the same frame.

3. **GIVEN** player's hitbox overlaps the same enemy for 3 consecutive frames,
   **WHEN** single-hit rule is active, **THEN** only one HitData is delivered
   (first frame of overlap).

4. **GIVEN** enemy hit by player, **WHEN** `IFRAMES_DURATION = 20`, **THEN**
   enemy ignores all hits for 20 physics frames (excluding hit-stop frames).

5. **GIVEN** player in dodge with `DODGE_IFRAMES = 12`, **WHEN** enemy hitbox
   sweeps through player position, **THEN** no hit is registered.

6. **GIVEN** player's AoE attack centered on self, **WHEN** hitbox overlaps
   player's own hurtbox, **THEN** no hit is registered (faction filtering).

7. **GIVEN** projectile hits an enemy, **WHEN** single-target projectile,
   **THEN** projectile despawns after first hit.

8. **GIVEN** entity in SPAWNING state, **WHEN** hitbox overlaps its hurtbox,
   **THEN** no hit registered (hurtbox disabled during spawn).

9. **GIVEN** hit-stop active with 5 i-frames remaining, **WHEN** 3-frame
   hit-stop occurs, **THEN** i-frame counter pauses for 3 frames, then resumes.

10. **GIVEN** knockback_force = 32, source at (100,50), target at (120,50),
    **WHEN** knockback calculated, **THEN** velocity = (32, 0) rightward.

11. **GIVEN** entity transitions to DYING, **WHEN** hitbox was active, **THEN**
    hitbox is disabled immediately, hurtbox is disabled.

12. **GIVEN** hitbox shape "heavy_blow" enabled, **WHEN** action completes,
    **THEN** shape is disabled and hit target set is cleared.
