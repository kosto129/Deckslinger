# Enemy AI System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 3 (Adapt or Die)

## Summary

The Enemy AI System controls enemy behavior during combat: threat detection,
movement decisions, attack selection, telegraph timing, and behavioral
differentiation across enemy tiers (standard, elite, boss). It reads entity
state and drives actions through the same Animation State Machine and Combat
pipelines the player uses.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Entity Framework, Combat System, Animation State Machine`

## Overview

The Enemy AI System makes every enemy in Deckslinger feel intentional and
readable. Each enemy type has a behavior profile that defines how it perceives
threats, selects targets, chooses attacks, and positions itself. AI operates
through the same animation commitment and combat damage pipelines as the
player — enemies have windups, active frames, and recovery, making their
attacks telegraphed and dodgeable. The system uses a state machine architecture
(not behavior trees for MVP simplicity) where each enemy type defines its
states, transitions, and attack patterns. Enemies never cheat: they have the
same commitment rules, hitbox/hurtbox systems, and i-frame constraints as the
player. The difference is in their behavior patterns, not their mechanical
privileges.

## Player Fantasy

Every enemy is a puzzle to read. The melee Rustler charges with a visible
windup — dodge left and counterattack. The ranged Sharpshooter stands still
to aim — close the distance before the shot. The elite Enforcer has an
unbreakable attack pattern but telegraphs with a full-body glow. The player
learns each enemy's rhythm through repetition, building mastery (Pillar 3).
Combat is never random — every enemy action is telegraphed, every attack is
dodgeable, and every death teaches the player something. Enemies are fair
opponents, not random number generators.

## Detailed Rules

### AI Architecture

**AA.1 — State Machine Model**

Each enemy type uses a finite state machine (FSM) defined as a resource. States
are not shared between enemy types — each type has its own FSM definition.

Base AI states available to all enemies:

| State | Description | Can Attack | Can Move |
|-------|-------------|------------|----------|
| `IDLE` | Default. Waiting for stimulus. | No | No |
| `PATROL` | Moving along a defined path or zone. | No | Yes |
| `CHASE` | Moving toward target. | No | Yes |
| `POSITION` | Moving to an optimal attack position. | No | Yes |
| `ATTACK_WINDUP` | Telegraph before attack. | Committing | No |
| `ATTACKING` | Active frames. Hitbox live. | Yes | No |
| `ATTACK_RECOVERY` | Post-attack vulnerability. | No | No |
| `RETREAT` | Moving away from target. | No | Yes |
| `STUNNED` | Externally applied. No AI processing. | No | No |

**AA.2 — State Transitions**

Transitions are evaluated each physics frame in priority order:
1. Lifecycle overrides (DYING/STUNNED from Entity Framework — highest priority)
2. Current state's exit conditions
3. Global transitions (e.g., target lost → IDLE)

**AA.3 — AIBehaviorComponent**

The `AIBehaviorComponent` (from Entity Framework) hosts the FSM instance:

```gdscript
func set_behavior(behavior: EnemyBehaviorData) -> void
func get_current_state() -> AIState
func get_target() -> EntityBase
func is_active() -> bool
func pause() -> void  # called on STUNNED
func resume() -> void  # called on stun clear
```

### Target Acquisition

**TA.1 — Target Selection**

All MVP enemies target the player (single-player game). Target acquisition:

```
1. Find player entity in room (cached reference, not per-frame search)
2. Calculate distance and line of sight
3. If distance < DETECTION_RANGE and line of sight clear: target acquired
4. If target acquired: transition to CHASE or POSITION
5. If target lost (death, out of range): transition to IDLE or PATROL
```

**TA.2 — Detection Range**

Each enemy type has a `detection_range` (in pixels). Enemies do not react to
the player until within this range. This allows room design with enemies that
activate at different times.

**TA.3 — Line of Sight**

MVP uses simple distance check — no raycasting for LOS obstruction. Rooms are
open arenas without LOS-blocking obstacles in MVP. Post-MVP can add raycast
LOS for rooms with pillars/cover.

### Attack Patterns

**AP.1 — EnemyAttackData Resource**

Each enemy type defines one or more attacks:

| Field | Type | Description |
|-------|------|-------------|
| `attack_id` | `StringName` | Unique identifier |
| `damage` | `int` | Base damage |
| `windup_frames` | `int` | Telegraph duration |
| `active_frames` | `int` | Hitbox active duration |
| `recovery_frames` | `int` | Post-attack vulnerability |
| `range` | `float` | Maximum range to initiate attack |
| `cooldown_frames` | `int` | Minimum frames between uses |
| `hitbox_shape` | `Shape2D` | Attack hitbox definition |
| `telegraph_type` | `TelegraphType` enum | Visual telegraph style |
| `shake_intensity` | `float` | Screen shake on hit |
| `status_effects` | `Array[StringName]` | Status effects applied on hit |
| `weight` | `float` | Selection weight for random choice |

**AP.2 — Attack Selection**

When an enemy transitions to attack:
1. Filter available attacks by range (is target within attack range?)
2. Filter by cooldown (is the attack off cooldown?)
3. Select from remaining attacks using weighted random (`weight` field)
4. If no attacks available: stay in POSITION/CHASE until one is ready

**AP.3 — Telegraph Types**

| TelegraphType | Visual | Duration | Player Read |
|---------------|--------|----------|-------------|
| `FLASH` | Entity sprite flashes white | 6-12 frames | Quick attack, short warning |
| `GLOW` | Entity glows with attack color | 12-20 frames | Standard attack, clear warning |
| `CHARGE` | Entity leans back, particles gather | 20-30 frames | Heavy attack, long warning |
| `GROUND_MARKER` | AoE indicator on ground | 15-30 frames | Area attack, shows danger zone |

### Enemy Tier Definitions

**ET.1 — Standard Enemies**

Standard enemies are the baseline combat participants. 32×32 sprites, simple
FSMs with 2-3 attack patterns, moderate HP, and predictable behavior.

| Enemy | Behavior | Attacks | HP | Detection |
|-------|----------|---------|-----|-----------|
| Rustler (melee) | CHASE → close range → ATTACK | Slash (fast), Lunge (slow, longer range) | 25 | 160 px |
| Sharpshooter (ranged) | POSITION at range → ATTACK | Aimed Shot (slow, accurate) | 15 | 200 px |
| Drifter (patrol) | PATROL → detect → CHASE → ATTACK | Quick Stab, Dodge Back | 20 | 120 px |

**ET.2 — Elite Enemies**

Elites are enhanced versions with 32×48 sprites, more complex FSMs, higher HP,
and at least one mechanic that breaks a standard enemy's visual rules (per art
bible). Elites appear 1-2 per room in later floors.

| Enemy | Special Mechanic | Attacks | HP | Detection |
|-------|-----------------|---------|-----|-----------|
| Enforcer | Has a 3-hit combo sequence (committed chain) | Swing 1 → Swing 2 → Slam | 60 | 180 px |
| Witch Doctor | Applies status effects (burn, slow) | Fire Bolt (burn), Hex Wave (slow, AoE) | 35 | 220 px |

**ET.3 — Boss Behavior**

Bosses use multi-phase FSMs with phase transitions at HP thresholds. Boss AI
is detailed in the Boss System GDD (Vertical Slice priority). The Enemy AI
System provides the infrastructure; Boss System defines specific behaviors.

### Movement Behavior

**MB.1 — Movement Execution**

AI movement uses the same `MovementComponent` as the player. Movement speed
is defined per enemy type. AI sets a target position; MovementComponent handles
the frame-by-frame position update.

```gdscript
# AI sets movement intent
movement_component.set_target_position(target_pos)
movement_component.set_max_speed(enemy_speed)

# MovementComponent handles pathfinding (simple direct movement for MVP)
# and position updates each physics frame
```

**MB.2 — Positioning Logic**

| Behavior | Logic |
|----------|-------|
| CHASE | Move directly toward player position. Stop at melee range. |
| POSITION | Move to maintain optimal attack range. Strafe perpendicular to player. |
| RETREAT | Move directly away from player. Stop at max retreat distance or room edge. |
| PATROL | Move between waypoints defined in room data. |

**MB.3 — Collision Avoidance**

MVP: simple repulsion between enemies. Each enemy pushes away from overlapping
enemies with a gentle force. No pathfinding — rooms are open arenas.

```
For each other_enemy within SEPARATION_RADIUS:
  push_direction = (self.position - other_enemy.position).normalized()
  self.position += push_direction * SEPARATION_FORCE * delta
```

### Spawn Behavior

**SB.1 — Spawn Sequence**

When an enemy is activated by the Room Encounter System:
1. Entity lifecycle: INACTIVE → SPAWNING (Entity Framework)
2. AI state: `IDLE` (AI does not process during SPAWNING)
3. Spawn animation plays (per Animation State Machine)
4. On spawn complete: AI transitions to initial state (IDLE or PATROL)
5. After `AI_ACTIVATION_DELAY` frames: AI begins target acquisition

The activation delay gives the player a moment to see new enemies before they
react.

## Formulas

**F.1 — Attack Selection Weight**

```
Variables:
  attacks[]     = array of available EnemyAttackData
  weight[i]     = attack weight for attack i
  total_weight  = sum of all weights for available attacks

Output:
  selected_attack = chosen attack

Formula:
  roll = randf() * total_weight
  cumulative = 0
  for each attack in attacks:
    cumulative += attack.weight
    if roll < cumulative:
      selected_attack = attack
      break

Example (Rustler: Slash weight=3, Lunge weight=1):
  total_weight = 4
  Roll 0.0–2.99: Slash (75%)
  Roll 3.0–3.99: Lunge (25%)
```

**F.2 — Chase Speed Adjustment**

```
Variables:
  base_speed       = enemy's defined movement speed
  distance_to_target = pixels from enemy to player
  CHASE_SPEEDUP_DIST = distance at which enemy starts sprinting (default: 128 px)
  CHASE_SPEEDUP_MULT = sprint multiplier (default: 1.3)

Output:
  chase_speed = modified movement speed during CHASE

Formula:
  if distance_to_target > CHASE_SPEEDUP_DIST:
    chase_speed = base_speed * CHASE_SPEEDUP_MULT
  else:
    chase_speed = base_speed

Example (base_speed = 60 px/s, distance = 200 px):
  200 > 128 → chase_speed = 60 * 1.3 = 78 px/s

Example (base_speed = 60 px/s, distance = 80 px):
  80 < 128 → chase_speed = 60 px/s (normal speed, close enough)
```

**F.3 — Separation Force**

```
Variables:
  overlap_distance  = SEPARATION_RADIUS - distance_between_enemies
  SEPARATION_RADIUS = 24 px
  SEPARATION_FORCE  = 2.0 px/frame

Output:
  push_vector = displacement vector applied this frame

Formula:
  if distance_between < SEPARATION_RADIUS:
    push_dir = (self_pos - other_pos).normalized()
    push_magnitude = SEPARATION_FORCE * (overlap_distance / SEPARATION_RADIUS)
    push_vector = push_dir * push_magnitude
  else:
    push_vector = Vector2.ZERO

Example (two enemies 16 px apart, SEPARATION_RADIUS = 24):
  overlap = 24 - 16 = 8
  push_magnitude = 2.0 * (8/24) = 0.667 px/frame per enemy
```

**F.4 — Attack Cooldown**

```
Variables:
  last_attack_frame = frame when attack last completed
  current_frame     = current physics frame
  cooldown_frames   = from EnemyAttackData

Output:
  is_available = boolean

Formula:
  is_available = (current_frame - last_attack_frame) >= cooldown_frames

Example (Slash cooldown = 45 frames, last used at frame 200, current = 240):
  240 - 200 = 40 < 45 → not available (5 more frames)
```

## Edge Cases

- **Player dies mid-enemy-attack**: Enemy completes current action sequence
  (windup→active→recovery). After recovery, AI transitions to IDLE. Enemies
  do not celebrate or change behavior on player death — they simply stop
  acquiring targets.

- **Enemy stunned during ATTACK_WINDUP**: Attack is cancelled (per Animation
  State Machine rules). AI transitions to STUNNED. Attack cooldown does NOT
  start (attack never completed). On stun clear, AI re-evaluates from IDLE.

- **All attacks on cooldown**: Enemy stays in CHASE or POSITION, circling the
  player at the closest attack's range. No idle standing — the enemy maintains
  threatening positioning.

- **Enemy pushed into wall by knockback**: MovementComponent handles wall
  collision. Enemy slides along wall. AI resumes from current state once
  knockback velocity decays.

- **Two enemies try to occupy the same position**: Separation force pushes
  them apart gradually. They may overlap for 1-2 frames. No collision damage
  or interaction between enemies.

- **Target lost (player leaves detection range)**: Enemies don't chase
  indefinitely. After `CHASE_TIMEOUT` frames without reacquiring the target,
  enemy returns to IDLE or PATROL. In MVP room-based design, the player
  cannot actually leave detection range (rooms are small), but the timeout
  prevents softlocks.

- **Enemy spawns in attack range of player**: AI activation delay applies.
  Enemy doesn't immediately attack on spawn. Player gets `AI_ACTIVATION_DELAY`
  frames to react.

- **Enemy with 0 attacks defined**: Legal but combat-impotent. Enemy chases
  and positions but never attacks. Log a warning. This covers passive enemies
  (environmental hazards, moving obstacles).

- **Enforcer mid-combo when stunned**: Combo chain breaks. On stun clear,
  combo resets to attack 1. The Enforcer does not resume mid-combo.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Entity Framework | `AIBehaviorComponent`, `MovementComponent`, lifecycle states | Hard |
| Upstream | Combat System | Enemy attacks use same damage pipeline. Reads player position. | Hard |
| Upstream | Animation State Machine | Enemy actions go through same commitment phases | Hard |
| Upstream | Collision/Hitbox System | Enemy hitboxes enabled during ACTIVE, uses same hit detection | Hard |
| Downstream | Room Encounter System | AI activation triggered by room entry, enemy count tracking | Soft |
| Downstream | Status Effect System | Enemy attacks can apply status effects (via Combat System) | Soft |
| Downstream | Boss System | Boss AI extends enemy AI infrastructure with multi-phase FSM | Soft |

Public API (EnemyBehaviorData resource + runtime):

```gdscript
# Behavior definition (resource)
var enemy_type_id: StringName
var detection_range: float
var base_speed: float
var attacks: Array[EnemyAttackData]
var initial_state: AIState
var hp: int

# Runtime (on AIBehaviorComponent)
func set_behavior(behavior: EnemyBehaviorData) -> void
func get_current_state() -> AIState
func get_target() -> EntityBase
func is_active() -> bool
func pause() -> void
func resume() -> void
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `AI_ACTIVATION_DELAY` | 20 frames (333ms) | 10–40 | Delay after spawn before AI starts targeting. Lower = more aggressive. |
| `CHASE_TIMEOUT` | 300 frames (5s) | 120–600 | Frames without target before returning to IDLE. |
| `CHASE_SPEEDUP_DIST` | 128 px | 64–200 | Distance at which enemy speeds up during chase. |
| `CHASE_SPEEDUP_MULT` | 1.3 | 1.1–1.5 | Speed multiplier for distant chase. Too high = feels unfair. |
| `SEPARATION_RADIUS` | 24 px | 16–32 | Distance at which enemies push apart. Too low = clumping. |
| `SEPARATION_FORCE` | 2.0 px/frame | 1.0–4.0 | Push strength between overlapping enemies. |
| `RUSTLER_HP` | 25 | 15–40 | Melee standard enemy HP. |
| `SHARPSHOOTER_HP` | 15 | 10–25 | Ranged standard enemy HP (glass cannon). |
| `ENFORCER_HP` | 60 | 40–80 | Elite enemy HP. |

## Acceptance Criteria

1. **GIVEN** player enters detection range of idle Rustler, **WHEN**
   `AI_ACTIVATION_DELAY` frames pass, **THEN** Rustler transitions to CHASE.

2. **GIVEN** Rustler within Slash range and Slash off cooldown, **WHEN**
   attack selected, **THEN** Slash chosen ~75% of the time (weight 3 vs 1).

3. **GIVEN** enemy in ATTACK_WINDUP, **WHEN** telegraph visual observed,
   **THEN** telegraph type matches EnemyAttackData and duration matches
   windup_frames.

4. **GIVEN** enemy's attack connects with player hurtbox, **WHEN** damage
   resolves, **THEN** same Combat System pipeline used (damage modifiers,
   hit-stop, screen shake all apply).

5. **GIVEN** enemy stunned during ATTACK_WINDUP, **WHEN** stun applied,
   **THEN** attack cancelled, enemy enters STUNNED, attack cooldown not started.

6. **GIVEN** two enemies within SEPARATION_RADIUS, **WHEN** physics frame
   processes, **THEN** both push apart with force proportional to overlap.

7. **GIVEN** enemy with all attacks on cooldown, **WHEN** AI evaluates,
   **THEN** enemy continues CHASE/POSITION behavior without stopping.

8. **GIVEN** Enforcer mid-combo (attack 2 of 3), **WHEN** stunned, **THEN**
   combo resets. On stun clear, next attack starts from attack 1.

9. **GIVEN** enemy takes lethal damage, **WHEN** entity dies, **THEN** AI
   stops processing, no further state transitions occur.

10. **GIVEN** enemy spawns, **WHEN** spawn animation plays, **THEN** AI is
    inactive during SPAWNING, activates after spawn complete + activation delay.
