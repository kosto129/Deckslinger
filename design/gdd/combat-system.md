# Combat System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (Every Card Is a Commitment), Pillar 3 (Adapt or Die)

## Summary

The Combat System is the central authority for damage resolution, health
management, death processing, hit-stop orchestration, and the enforcement of
combat feel. It receives HitData from the Collision System, applies damage
modifiers, manages entity health, triggers death sequences, and coordinates
hit-stop across Animation and Camera systems.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Entity Framework, Input System, Animation State Machine, Collision/Hitbox System`

## Overview

The Combat System makes every hit in Deckslinger mean something. When the
Collision/Hitbox System detects a valid hit and delivers HitData, the Combat
System takes over: it reads the base damage, applies any modifiers (status
effects, vulnerability states), resolves the final damage number, subtracts
from the target's health via HealthComponent, triggers screen shake and
hit-stop for impact feel, spawns damage number VFX, checks for death, and
emits signals that the rest of the game reacts to. It does not decide what
hits what (Collision) or what animation plays (Animation State Machine) or
what card was played (Card Hand) — it is the damage pipeline between
"something connected" and "something happened." Every combat interaction in
the game flows through this system: player attacks, enemy attacks, projectile
hits, AoE effects, and status effect ticks.

## Player Fantasy

Combat feels like a bar fight in a Sergio Leone film: deliberate, weighty,
consequential. Every hit lands with authority — the screen freezes for a
heartbeat, the target flinches, a damage number cracks off them. The player
feels the difference between a Quick Draw (small shake, short stop) and a
Heavy Blow (big shake, long stop, the enemy staggers back). When an enemy
dies, the death hit has a distinct finality — the last hit-stop is slightly
longer, the shake slightly harder. The player never doubts whether their
attack connected. They never feel cheated by invisible damage or silent hits.
Combat rewards commitment: you chose this attack, you locked in, it landed,
and you felt it.

## Detailed Rules

### Damage Pipeline

**DP.1 — Damage Resolution Flow**

```
1. Collision System delivers HitData to HurtboxComponent
2. HurtboxComponent emits hit_received(hit_data)
3. Combat System receives hit_received signal
4. Combat System checks: is target valid? (ACTIVE or STUNNED, not invincible)
5. Combat System calculates final damage:
   final_damage = apply_modifiers(hit_data.damage, source, target)
6. Combat System calls target.health_component.take_damage(final_damage, source)
7. HealthComponent updates HP, emits health_changed(old_hp, new_hp, source)
8. Combat System triggers combat feedback:
   a. Request hit-stop (both attacker and target)
   b. Request screen shake (Camera System)
   c. Spawn damage number VFX
   d. Apply knockback to target
   e. Trigger hit_react animation on target (if not in commitment)
9. Combat System checks: did target die?
   If HP <= 0: trigger death sequence
```

**DP.2 — Damage Modifiers**

Modifiers are applied in order. Each is multiplicative with the running total.

| Modifier | Source | Effect | Default |
|----------|--------|--------|---------|
| Vulnerability | Status Effect System | Target has `VULNERABLE` status: ×1.5 damage | ×1.0 |
| Resistance | Status Effect System | Target has `RESISTANT` status: ×0.5 damage | ×1.0 |
| Stun Bonus | Animation State Machine | Target is STUNNED: ×1.25 damage | ×1.0 |
| Critical Hit | Card Data / Combat | Roll-based crit: ×`CRIT_MULTIPLIER` damage | ×1.0 (no crit) |

```
final_damage = floor(base_damage * vulnerability * resistance * stun_bonus * crit)
final_damage = max(final_damage, 1)  # minimum 1 damage
```

**DP.3 — Critical Hits**

Critical hits are card-driven, not random by default. Cards that crit have a
`crit_chance` field (0.0–1.0). On hit resolution:

```
roll = randf()  # 0.0 to 1.0
if roll < crit_chance:
    crit = CRIT_MULTIPLIER
    trigger crit VFX
else:
    crit = 1.0
```

MVP cards have `crit_chance = 0.0` unless explicitly designed as crit cards
(Gunslinger archetype specialty). This keeps crit as an opt-in mechanic, not
a universal random element.

### Health Management

**HM.1 — HealthComponent Contract**

The HealthComponent (defined in Entity Framework) is the single source of
truth for entity HP. The Combat System interacts with it exclusively through
its public API:

```gdscript
func take_damage(amount: int, source: EntityBase) -> void
func heal(amount: int) -> void
func get_current_hp() -> int
func get_max_hp() -> int
func get_hp_fraction() -> float  # current_hp / max_hp
func is_alive() -> bool

signal health_changed(old_hp: int, new_hp: int, source: EntityBase)
signal died(entity: EntityBase)
```

**HM.2 — HP Rules**

- HP is an integer. No fractional health.
- HP cannot exceed `max_hp`. Overhealing is clamped.
- HP cannot go below 0. Overkill damage is absorbed.
- `take_damage(0)` is a no-op. No event emitted.
- `heal(0)` is a no-op. No event emitted.
- Only the Combat System calls `take_damage()`. No other system directly
  modifies HP (except Status Effect System for DoT/HoT, which calls through
  the same Combat System pipeline).

**HM.3 — Player HP**

| Stat | Default | Source |
|------|---------|--------|
| `player_max_hp` | 100 | Tuning knob |
| `player_start_hp` | 100 (full) | Run start |
| HP persists between rooms | Yes | Run State Manager |
| HP restores between floors | Partial (heal 30%) | Reward System / Run State |

### Death Processing

**D.1 — Death Sequence**

When `HealthComponent.died(entity)` fires:

1. Combat System calls `entity.die()` (Entity Framework lifecycle → DYING)
2. Animation State Machine plays death animation
3. All hitboxes and hurtboxes are disabled
4. Entity is removed from AI targeting pools
5. Death animation completes → entity calls `entity.despawn()`
6. `despawned` signal fires → Room Encounter System updates enemy count

**D.2 — Kill Credit**

The `source` parameter in `take_damage()` tracks who dealt the killing blow.
This is used for:
- XP/reward attribution (if added post-MVP)
- Death VFX direction (death animation faces away from killer)
- Stats tracking (kills per card type)

**D.3 — Overkill**

If damage exceeds remaining HP, the excess is discarded. No mechanical
consequence to overkill damage. Visual feedback may scale with overkill
magnitude (larger shake, more particles) as a juice enhancement post-MVP.

### Hit-Stop Orchestration

**HSO.1 — Triggering Hit-Stop**

The Combat System is the authority on when hit-stop occurs. On successful
damage resolution:

1. Calculate hit-stop duration from `HitData.shake_intensity` (per Animation
   State Machine formula F.2: `hitstop_frames = clamp(ceil(intensity * 2), 2, 8)`)
2. Apply hit-stop to BOTH attacker and target via AnimationComponent
3. Notify Camera System to freeze
4. Notify Input System to freeze buffer timer

**HSO.2 — Death Hit-Stop**

When the killing blow is dealt, hit-stop duration is extended by
`DEATH_HITSTOP_BONUS` frames. This gives a distinct "final hit" feel.

```
death_hitstop = normal_hitstop + DEATH_HITSTOP_BONUS
```

### Screen Shake Orchestration

The Combat System requests screen shake from the Camera System via signal:

```gdscript
signal combat_shake_requested(intensity: float)
```

Shake intensity comes from `HitData.shake_intensity` (which originates from
`CardData.shake_intensity` or enemy attack data). The Combat System does not
own shake behavior — it only requests it.

### Damage Numbers

**DN.1 — Damage Number Spawning**

On each successful damage resolution, the Combat System spawns a floating
damage number at the hit position:

| Property | Value | Source |
|----------|-------|--------|
| Position | `HitData.hit_position` | Collision System |
| Text | `final_damage` as string | Combat System |
| Color | White (normal), Yellow (crit), Red (player taking damage) | Combat System |
| Animation | Float upward 16px over 30 frames, then fade out over 15 frames | Hardcoded |
| Font size | 8px (normal), 10px (crit) | Hardcoded |

**DN.2 — Damage Number Stacking**

If multiple damage numbers spawn at similar positions within 5 frames, each
subsequent number is offset by 8px upward to prevent overlap.

### Status Effect Damage

**SED.1 — DoT (Damage over Time)**

Status effects that deal periodic damage (burn, poison) call through the
Combat System's damage pipeline:

```
CombatSystem.apply_dot_tick(target, dot_damage, status_source)
```

DoT damage:
- Does NOT trigger hit-stop (continuous damage shouldn't freeze gameplay)
- Does NOT trigger screen shake
- Does NOT trigger knockback
- DOES spawn damage numbers (smaller, different color: orange for burn, green
  for poison)
- DOES trigger death if HP reaches 0
- DOES respect vulnerability/resistance modifiers

### Combat Actions

**CA.1 — Action Execution Flow**

When the player plays a card (Card Hand System → Combat System):

```
1. Card Hand System calls CombatSystem.execute_card(card_data, aim_direction)
2. Combat System reads card_data.effects array
3. For each effect:
   a. If DAMAGE: create HitData template, pass to Collision System via hitbox
   b. If APPLY_STATUS: queue status application for resolved targets
   c. If MOVE_SELF: apply movement via MovementComponent
   d. If HEAL: call health_component.heal()
   e. If SPAWN_PROJECTILE: instantiate projectile entity
   f. If DRAW_CARDS: signal Card Hand System to draw
4. Animation State Machine plays the card's animation_key
5. Hitbox enabled during ACTIVE phase
6. On hit detection: Collision → Combat damage pipeline
```

**CA.2 — Enemy Attack Flow**

Enemy attacks follow the same pipeline but originate from Enemy AI:

```
1. Enemy AI initiates attack
2. Animation State Machine plays enemy attack animation
3. Hitbox enabled during ACTIVE phase
4. On hit detection: same Collision → Combat damage pipeline
```

## Formulas

**F.1 — Final Damage Calculation**

```
Variables:
  base_damage       = from HitData (card or enemy attack base damage)
  vulnerability     = 1.5 if target has VULNERABLE, else 1.0
  resistance        = 0.5 if target has RESISTANT, else 1.0
  stun_bonus        = 1.25 if target is STUNNED, else 1.0
  crit_mult         = CRIT_MULTIPLIER if crit rolled, else 1.0
  CRIT_MULTIPLIER   = 1.5 (default)

Output:
  final_damage = integer damage applied to target HP

Formula:
  final_damage = floor(base_damage * vulnerability * resistance * stun_bonus * crit_mult)
  final_damage = max(final_damage, 1)

Example (normal hit, no modifiers):
  base_damage = 15, all multipliers = 1.0
  final_damage = floor(15 * 1.0 * 1.0 * 1.0 * 1.0) = 15

Example (hit on vulnerable stunned target with crit):
  base_damage = 15, vulnerability = 1.5, stun_bonus = 1.25, crit = 1.5
  final_damage = floor(15 * 1.5 * 1.0 * 1.25 * 1.5) = floor(42.19) = 42

Example (hit on resistant target):
  base_damage = 15, resistance = 0.5
  final_damage = floor(15 * 1.0 * 0.5 * 1.0 * 1.0) = floor(7.5) = 7
```

**F.2 — Death Hit-Stop Duration**

```
Variables:
  normal_hitstop     = from Animation State Machine F.2
  DEATH_HITSTOP_BONUS = additional frames on killing blow (default: 3)

Output:
  death_hitstop = total freeze frames on kill

Formula:
  death_hitstop = normal_hitstop + DEATH_HITSTOP_BONUS

Example (shake_intensity = 3.0):
  normal_hitstop = clamp(ceil(3.0 * 2), 2, 8) = 6
  death_hitstop = 6 + 3 = 9 frames (150ms)
```

**F.3 — Damage Number Position Offset**

```
Variables:
  hit_position      = world position of hit
  stack_index       = number of damage numbers spawned within 5 frames at similar position
  STACK_OFFSET      = vertical offset per stacked number (default: 8px)

Output:
  display_position = final position for the damage number

Formula:
  display_position = hit_position + Vector2(0, -stack_index * STACK_OFFSET)

Example (third damage number in a burst):
  hit_position = (120, 80), stack_index = 2
  display_position = (120, 80 - 16) = (120, 64)
```

**F.4 — DoT Damage Per Tick**

```
Variables:
  dot_base_damage   = per-tick damage from status effect definition
  tick_interval     = frames between ticks (from Status Effect System)
  total_duration    = total effect duration in frames
  vulnerability     = modifier (same as F.1)
  resistance        = modifier (same as F.1)

Output:
  damage_per_tick   = integer damage per tick
  total_ticks       = number of times damage is dealt
  total_dot_damage  = cumulative damage over full duration

Formula:
  damage_per_tick = max(floor(dot_base_damage * vulnerability * resistance), 1)
  total_ticks = floor(total_duration / tick_interval)
  total_dot_damage = damage_per_tick * total_ticks

Example (burn: 3 damage/tick, every 30 frames, 180 frame duration):
  damage_per_tick = max(floor(3 * 1.0 * 1.0), 1) = 3
  total_ticks = floor(180 / 30) = 6
  total_dot_damage = 3 * 6 = 18 damage over 3 seconds
```

## Edge Cases

- **Damage dealt to entity at exactly 1 HP**: `final_damage >= 1` always.
  Entity dies. Death sequence triggers. No edge case with minimum damage
  keeping entities alive indefinitely.

- **Heal and damage in the same frame**: Both process. Order: damage resolves
  first (from Collision detection), then heal resolves (from card effect or
  status). If damage kills the entity, the heal does not fire (entity is DYING).

- **Crit on a 0-crit-chance card**: `crit_chance = 0.0` means `randf() < 0.0`
  is always false. No crit ever occurs. No special handling needed.

- **Multiple damage modifiers that cancel out**: Vulnerability (1.5) and
  Resistance (0.5) applied to the same hit: `1.5 * 0.5 = 0.75`. Net result
  is damage reduction. Multiplicative stacking means no modifier is ignored.

- **Player attacks enemy and enemy attacks player in the same frame**: Both
  hits resolve independently. Both may trigger hit-stop. The longer hit-stop
  wins (per Animation State Machine rules). Both take damage. Both may die.
  Simultaneous death is valid — if both entities die, room clears and player
  death takes priority (run ends).

- **DoT tick kills entity during another entity's attack animation**: Death
  sequence triggers immediately. If the dying entity was mid-attack (WINDUP
  or ACTIVE), the attack is cancelled (per Animation State Machine edge cases).
  The DoT source entity gets kill credit.

- **Damage to entity with no HealthComponent**: HurtboxComponent checks for
  HealthComponent. If missing, the hit is received but no damage is applied.
  Hit-stop and shake still fire (the impact still "feels" real even if no HP
  changes). This covers decorative props that react to hits visually.

- **Knockback pushes entity into wall**: Movement system handles wall collision.
  Entity slides along the wall. Knockback velocity decays normally. No extra
  damage from wall impact (no "wall splat" mechanic in MVP).

- **0 base_damage hit (pure status application)**: `final_damage = max(0 * ..., 1) = 1`.
  Minimum 1 damage is always dealt. If a card should apply status without
  damage, it should use a separate APPLY_STATUS effect without a DAMAGE effect
  on the hitbox. The minimum-1 rule only applies when a DAMAGE effect is
  being resolved.

- **Hit-stop during hit-stop**: Longer remaining duration wins (no additive
  stacking per Animation State Machine HS.3). Combat System defers to
  AnimationComponent for this arbitration.

- **Screen shake during room transition**: Camera System clears shake on
  transition start (per Camera System rules). Combat System does not need
  special handling — it requests shake, Camera decides whether to apply it.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Entity Framework | `HealthComponent` for HP management, `EntityBase` for lifecycle | Hard |
| Upstream | Input System | `consume_buffered_action()` for dodge timing, `get_aim_direction()` | Hard |
| Upstream | Animation State Machine | `active_started` signal for effect resolution timing, hit-stop API | Hard |
| Upstream | Collision/Hitbox System | `hit_received` signal with HitData for damage pipeline input | Hard |
| Upstream | Card Data System | `CardData` for damage values, effects, shake intensity | Hard |
| Downstream | Status Effect System | Applies status effects from HitData, reads vulnerability/resistance | Hard |
| Downstream | Camera System | `combat_shake_requested` signal for screen shake | Soft |
| Downstream | Card Hand System | `execute_card` entry point for card play resolution | Hard |
| Downstream | Enemy AI System | Enemy attacks use same damage pipeline | Hard |
| Downstream | Room Encounter System | Death signals for enemy count tracking and reward triggers | Soft |
| Downstream | Run State Manager | Player death triggers run end | Soft |

Public API:

```gdscript
# Card execution (called by Card Hand System)
func execute_card(card_data: CardData, aim_direction: Vector2, source: EntityBase) -> void

# DoT damage (called by Status Effect System)
func apply_dot_tick(target: EntityBase, damage: int, source_status: StringName) -> void

# Damage query (for UI / tooltips)
func calculate_damage_preview(base_damage: int, source: EntityBase, target: EntityBase) -> int

# Signals
signal damage_dealt(source: EntityBase, target: EntityBase, amount: int, is_crit: bool)
signal entity_killed(entity: EntityBase, killer: EntityBase)
signal combat_shake_requested(intensity: float)
signal hit_stop_triggered(duration_frames: int)
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `PLAYER_MAX_HP` | 100 | 60–200 | Player's maximum health. Lower = more punishing. Higher = more forgiving. |
| `CRIT_MULTIPLIER` | 1.5 | 1.25–2.5 | Damage multiplier on critical hit. Higher = more burst, more variance. |
| `VULNERABLE_MULTIPLIER` | 1.5 | 1.25–2.0 | Damage multiplier when target has VULNERABLE status. |
| `RESISTANT_MULTIPLIER` | 0.5 | 0.25–0.75 | Damage multiplier when target has RESISTANT status. |
| `STUN_DAMAGE_BONUS` | 1.25 | 1.0–1.5 | Bonus damage to stunned targets. 1.0 = no bonus. |
| `DEATH_HITSTOP_BONUS` | 3 frames | 0–6 | Extra hit-stop on killing blow. 0 = no special death feel. |
| `DAMAGE_NUMBER_FLOAT_DISTANCE` | 16 px | 8–32 | How far damage numbers float upward. |
| `DAMAGE_NUMBER_FLOAT_FRAMES` | 30 | 15–45 | Duration of damage number float animation. |
| `DAMAGE_NUMBER_FADE_FRAMES` | 15 | 10–30 | Duration of damage number fade-out. |
| `FLOOR_HEAL_PERCENT` | 0.30 | 0.0–0.5 | HP healed between dungeon floors. 0 = no healing. |

## Acceptance Criteria

1. **GIVEN** HitData with base_damage=15 and no active modifiers, **WHEN**
   damage resolves, **THEN** target loses exactly 15 HP.

2. **GIVEN** target has VULNERABLE status, **WHEN** hit with base_damage=15,
   **THEN** final_damage = floor(15 * 1.5) = 22.

3. **GIVEN** target is STUNNED, **WHEN** hit with base_damage=15, **THEN**
   final_damage = floor(15 * 1.25) = 18.

4. **GIVEN** base_damage=15, VULNERABLE + RESISTANT on same target, **WHEN**
   damage resolves, **THEN** final_damage = floor(15 * 1.5 * 0.5) = floor(11.25) = 11.

5. **GIVEN** target at 1 HP, **WHEN** any damage is dealt, **THEN** target
   HP reaches 0, `died` signal fires, death sequence begins.

6. **GIVEN** killing blow with shake_intensity=3.0, **WHEN** hit-stop
   calculated, **THEN** duration = ceil(3.0*2) + 3 = 9 frames.

7. **GIVEN** damage dealt to target, **WHEN** Combat System processes hit,
   **THEN** screen shake is requested, hit-stop is applied to both attacker
   and target, and damage number spawns at hit position.

8. **GIVEN** DoT tick deals 3 damage, **WHEN** tick resolves, **THEN** target
   loses 3 HP, no hit-stop, no screen shake, damage number spawns.

9. **GIVEN** player and enemy attack each other in the same frame, **WHEN**
   both hits resolve, **THEN** both take damage independently, longer hit-stop
   wins.

10. **GIVEN** heal(20) and take_damage(30) in the same frame on entity with
    50 HP, **WHEN** both process, **THEN** damage first (50→20), then heal
    (20→40). Final HP = 40.

11. **GIVEN** entity with no HealthComponent receives HitData, **WHEN** hit
    processes, **THEN** hit-stop and shake fire but no damage is applied.

12. **GIVEN** player HP = 100, `PLAYER_MAX_HP = 100`, **WHEN** heal(20) called,
    **THEN** HP remains 100 (clamped to max).

13. **GIVEN** `damage_dealt` signal fires, **WHEN** observed, **THEN** it
    includes source entity, target entity, final damage amount, and crit flag.

14. **GIVEN** three damage numbers spawn within 5 frames at similar positions,
    **WHEN** displayed, **THEN** each is offset 8px upward from the previous.
