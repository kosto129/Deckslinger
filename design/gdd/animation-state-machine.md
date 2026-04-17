# Animation State Machine

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (Every Card Is a Commitment)

## Summary

The Animation State Machine manages animation playback, state transitions, and
commitment enforcement for all entities. It translates lifecycle states,
movement, and combat actions into visual feedback while enforcing the timing
contracts (windup, active, recovery) that make combat feel weighty and committal.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Entity Framework`

## Overview

The Animation State Machine is the visual contract enforcer for Deckslinger's
committal combat. Every entity that animates — the player, enemies, bosses —
has an `AnimationComponent` that hosts a state machine dictating which animation
plays, how long it plays, and what the entity is allowed to do during playback.
When a card is played or an enemy attacks, the animation state machine locks
the entity into a sequence: windup frames (telegraphing), active frames (the
effect is live), and recovery frames (vulnerability window). The player cannot
cancel out of these phases — commitment IS the game. The system reads animation
keys from CardData and enemy behavior definitions, drives SpriteFrames playback,
and emits signals at phase boundaries so Combat, Card Hand, and Input Buffer
systems know when the entity is actionable again. It owns animation timing and
phase enforcement but not the gameplay consequences of those phases.

## Player Fantasy

Every action the player takes has visible weight. When they play a card, the
character's body shifts into a distinct windup pose — the player can read that
pose and know what's coming. The active frames deliver the payoff: the sword
swings, the shot fires, the effect resolves. Then recovery: the character is
exposed, slightly off-balance, for just long enough that the player feels the
cost of their choice. Enemies telegraph the same way — their windup poses are
readable silhouettes that a skilled player learns to recognize and react to.
Hit-stop freezes the action on impact, giving the player a moment to feel the
weight. Every frame of animation communicates something: "I'm preparing," "I'm
acting," "I'm vulnerable," "I'm ready again."

## Detailed Rules

### Animation States

**AS.1 — State Definitions**

The animation state machine operates independently from the Entity Lifecycle
State Machine (which tracks INACTIVE/SPAWNING/ACTIVE/STUNNED/DYING/DEAD). The
animation state machine only runs when the entity lifecycle is ACTIVE or STUNNED.

| Animation State | Description | Interruptible | Entity Can Move | Hitbox Active | Hurtbox Active |
|----------------|-------------|---------------|-----------------|---------------|----------------|
| `IDLE` | Default standing/breathing. Loops. | Yes | Yes | No | Yes |
| `RUN` | Locomotion animation. Loops. | Yes | Yes | No | Yes |
| `WINDUP` | Telegraph before action. Timed. | No | No | No | Yes |
| `ACTIVE` | Action resolves. Effect is live. Timed. | No | No | Yes (if attack) | Yes |
| `RECOVERY` | Post-action vulnerability. Timed. | No | No | No | Yes |
| `HIT_REACT` | Flinch on taking damage. Timed. | No | No | No | Yes |
| `STUNNED` | Stun animation. Loops until cleared. | No (cleared externally) | No | No | Yes |
| `DYING` | Death animation. Plays once. | No | No | No | No |
| `SPAWNING` | Spawn-in animation. Plays once. | No | No | No | No |

**AS.2 — Valid Transitions**

```
IDLE      → RUN         (movement input detected)
IDLE      → WINDUP      (action initiated: card play, enemy attack)
RUN       → IDLE        (movement input released)
RUN       → WINDUP      (action initiated while moving)
WINDUP    → ACTIVE      (windup_frames elapsed)
ACTIVE    → RECOVERY    (active_frames elapsed)
RECOVERY  → IDLE        (recovery_frames elapsed, no movement)
RECOVERY  → RUN         (recovery_frames elapsed, movement input held)
Any       → HIT_REACT   (damage received, if not in WINDUP/ACTIVE/RECOVERY)
HIT_REACT → IDLE        (hit_react_frames elapsed, no movement)
HIT_REACT → RUN         (hit_react_frames elapsed, movement held)
Any       → STUNNED     (stun status applied via Entity Framework)
STUNNED   → IDLE        (stun cleared)
Any       → DYING       (entity lifecycle → DYING)
```

**Commitment rule**: WINDUP, ACTIVE, and RECOVERY cannot be interrupted by
player input. They can only be interrupted by: death (→ DYING), stun
(→ STUNNED, only from certain states per Entity Framework rules), or hit-stop
(pause, not cancel). This is the core enforcement of Pillar 1.

**AS.3 — Action Sequence**

When an action is initiated (card play or enemy attack), the animation state
machine executes a three-phase sequence:

```
[IDLE/RUN] → WINDUP (windup_frames) → ACTIVE (active_frames) → RECOVERY (recovery_frames) → [IDLE/RUN]
```

The frame counts come from:
- Player cards: `CardData.windup_frames`, `CardData.active_frames` (inferred
  from animation), `CardData.recovery_frames`
- Enemy attacks: `EnemyAttackData.windup_frames`, etc. (defined in Enemy AI)

Signals emitted at phase boundaries:
```gdscript
signal windup_started(animation_key: StringName)
signal active_started(animation_key: StringName)
signal recovery_started(animation_key: StringName)
signal action_completed(animation_key: StringName)
```

### Directional Animations

**DA.1 — 8-Direction Support**

Each animation state has up to 8 directional variants matching the aim/facing
direction from the Input System. Animations are organized as SpriteFrames with
direction suffixes:

```
idle_e, idle_ne, idle_n, idle_nw, idle_w, idle_sw, idle_s, idle_se
run_e, run_ne, run_n, run_nw, run_w, run_sw, run_s, run_se
```

For MVP, animations can use 4 directions with horizontal flip:
- E, NE, N, NW are drawn
- W = flip(E), SW = flip(NE), S = drawn, SE = flip(NE mirrored)

The AnimationComponent resolves the current direction from the entity's facing
direction (provided by Input System for the player, by AI for enemies).

**DA.2 — Direction Locking During Actions**

During WINDUP/ACTIVE/RECOVERY, the entity's visual facing direction is locked
to the direction at the moment WINDUP began. The entity does not visually rotate
mid-action even if the aim direction changes. This reinforces commitment — you
attack in the direction you committed to.

### Hit-Stop

**HS.1 — Frame Freeze**

Hit-stop pauses both the attacker's and the target's animation state machines
for a specified number of frames. During hit-stop:

- Animation frame does not advance
- Animation state timer does not count down
- Entity position is frozen (no movement)
- Input buffer timer is frozen (per Input System rules)
- Camera holds position (per Camera System rules)
- Shake can still be applied (visual layer, not gameplay layer)

**HS.2 — Hit-Stop Duration**

Hit-stop duration is determined by the source:
- `CardData.shake_intensity` is used as a proxy: `hitstop_frames = ceil(shake_intensity * 2)`
- Minimum: 2 frames (33ms). Maximum: 8 frames (133ms).
- If `shake_intensity = 0`, no hit-stop occurs.

**HS.3 — Hit-Stop Stacking**

If a new hit-stop is triggered during an existing hit-stop, the longer remaining
duration wins. Hit-stops do not stack additively.

### Animation Playback

**AP.1 — SpriteFrames Integration**

Animations are played via Godot's `AnimatedSprite2D` node using `SpriteFrames`
resources. The AnimationComponent wraps this node and manages:
- Animation selection (state + direction → animation name)
- Frame rate enforcement (all gameplay animations at the project's fixed rate)
- Looping vs one-shot behavior
- Animation completion signals

**AP.2 — Frame Rate**

All gameplay animations play at a fixed rate derived from the physics frame rate
(60fps). Animation frame counts in CardData and enemy data directly correspond
to physics frames. One animation frame = one physics frame = 16.67ms.

Art frames (the actual drawn sprite frames) may run at a lower rate for pixel
art feel (e.g., 12 art frames per second = each art frame held for 5 physics
frames). The timing contract is in physics frames, not art frames.

**AP.3 — Animation Priority**

When multiple animation requests arrive in the same frame:
1. DYING (highest — always plays)
2. STUNNED
3. WINDUP/ACTIVE/RECOVERY (commitment — cannot be overridden except by 1-2)
4. HIT_REACT
5. IDLE/RUN (lowest — freely overridable)

### Entity Lifecycle Integration

**ELI.1 — Lifecycle-to-Animation Mapping**

| Entity Lifecycle State | Animation State | Behavior |
|----------------------|-----------------|----------|
| INACTIVE | None | AnimationComponent disabled. Invisible. |
| SPAWNING | SPAWNING | Spawn animation plays once. On complete, entity → ACTIVE. |
| ACTIVE | IDLE/RUN/WINDUP/ACTIVE/RECOVERY/HIT_REACT | Full state machine active. |
| STUNNED | STUNNED | Stun animation loops. State machine paused. |
| DYING | DYING | Death animation plays once. On complete, entity → DEAD. |
| DEAD | None | Entity being freed. No animation. |

**ELI.2 — Lifecycle Transitions**

The AnimationComponent listens to `lifecycle_state_changed` from EntityBase.
On lifecycle change, the animation state machine is forced to the corresponding
animation state regardless of current state (except: if in DYING, ignore all
further lifecycle changes).

## Formulas

**F.1 — Action Sequence Total Duration**

```
Variables:
  windup_frames   = frames in WINDUP state (from CardData or EnemyAttackData)
  active_frames   = frames in ACTIVE state
  recovery_frames = frames in RECOVERY state
  FRAME_RATE      = 60 fps

Output:
  total_lock_frames = total frames entity is non-interruptible
  total_lock_ms     = total lock time in milliseconds

Formula:
  total_lock_frames = windup_frames + active_frames + recovery_frames
  total_lock_ms = total_lock_frames / FRAME_RATE * 1000

Example (Quick Draw card: windup=8, active=3, recovery=6):
  total_lock_frames = 8 + 3 + 6 = 17
  total_lock_ms = 17 / 60 * 1000 = 283ms

Example (Heavy Blow card: windup=15, active=4, recovery=12):
  total_lock_frames = 15 + 4 + 12 = 31
  total_lock_ms = 31 / 60 * 1000 = 517ms
```

**F.2 — Hit-Stop Duration**

```
Variables:
  shake_intensity = from CardData or combat event (0.0 to 6.0)
  MIN_HITSTOP     = 2 frames
  MAX_HITSTOP     = 8 frames

Output:
  hitstop_frames = frames of animation freeze

Formula:
  if shake_intensity <= 0:
      hitstop_frames = 0
  else:
      hitstop_frames = clamp(ceil(shake_intensity * 2), MIN_HITSTOP, MAX_HITSTOP)

Example (shake_intensity = 3.0):
  hitstop_frames = clamp(ceil(3.0 * 2), 2, 8) = clamp(6, 2, 8) = 6

Example (shake_intensity = 1.0):
  hitstop_frames = clamp(ceil(1.0 * 2), 2, 8) = clamp(2, 2, 8) = 2
```

**F.3 — Art Frame Hold Duration**

```
Variables:
  art_fps          = target art frame rate (default: 12 fps)
  physics_fps      = 60 fps
  HOLD_FRAMES      = physics frames each art frame is displayed

Formula:
  HOLD_FRAMES = physics_fps / art_fps

Example:
  HOLD_FRAMES = 60 / 12 = 5  (each drawn frame shows for 5 physics frames)

For a 4-art-frame windup animation at 12 art fps:
  physics_frames = 4 * 5 = 20 physics frames = 333ms
```

## Edge Cases

- **Action initiated during HIT_REACT**: Rejected. The entity must return to
  IDLE or RUN before initiating a new action. Buffered inputs may fire when
  HIT_REACT completes (Input System handles buffer timing).

- **Stun applied during WINDUP**: The action is cancelled. Entity transitions
  to STUNNED. The card/attack is consumed (the card leaves the hand, the enemy's
  attack cooldown starts) but the effect never resolves. This is the stun's
  purpose — interrupting commitments.

- **Stun applied during ACTIVE**: The active effect has already resolved (damage
  dealt on ACTIVE start). Entity transitions to STUNNED during remaining active
  frames. Recovery is skipped. Visually jarring but mechanically correct — the
  damage went through.

- **Stun applied during RECOVERY**: Entity transitions to STUNNED. Recovery is
  cut short. When stun clears, entity returns to IDLE (not back to recovery).
  This is a benefit to the stunned entity — recovery is skipped.

- **Death during WINDUP**: Action is cancelled. Entity transitions to DYING
  immediately. Effect never resolves. Card is consumed, damage is not dealt.

- **Death during ACTIVE**: Effect has already resolved. Entity transitions to
  DYING. Remaining active frames are skipped. This can result in the entity
  dealing damage and dying in the same frame — valid.

- **Two hit-stops overlapping**: Longer remaining duration wins (per HS.3).
  If entity A hits entity B and entity C simultaneously, entity A gets the
  longest hit-stop from either impact.

- **Animation key not found in SpriteFrames**: Fallback to IDLE animation for
  the current direction. Log a warning with the missing key. Prevents crash
  from missing art assets during development.

- **Entity with no AnimationComponent**: Legal per Entity Framework (PROPs,
  some projectiles). No animation plays. Combat timing still uses frame counts
  but with no visual representation. Hitbox/hurtbox timing is driven by the
  combat system's internal frame counter instead.

- **Direction change during IDLE**: Immediate — IDLE animation switches to the
  new direction variant. No transition delay.

- **Rapid action cancellation (mashing during recovery)**: Recovery cannot be
  cancelled. Input is buffered (per Input System). When recovery ends, the
  buffered action fires on the next available frame.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Entity Framework | `AnimationComponent` node, `lifecycle_state_changed` signal | Hard |
| Downstream | Combat System | `active_started` signal triggers damage resolution, `action_completed` signals action end | Hard |
| Downstream | Card Hand System | `action_completed` signal enables next card play | Hard |
| Downstream | Input System | Reads animation state to determine if entity is locked (buffer decision) | Soft |
| Downstream | Camera System | `hit_stop` freeze propagates to camera hold | Soft |
| Downstream | Enemy AI System | AI reads animation state to time attacks; enemies use same state machine | Hard |
| Downstream | Collision/Hitbox System | Hitbox enabled/disabled based on ACTIVE state | Hard |

Public API (on AnimationComponent):

```gdscript
# Action initiation
func play_action(animation_key: StringName, windup: int, active: int, recovery: int) -> void
func is_in_action() -> bool  # true during WINDUP, ACTIVE, or RECOVERY
func get_action_state() -> AnimationState  # current state enum

# Hit reactions
func play_hit_react(duration_frames: int) -> void
func play_stun() -> void
func clear_stun() -> void

# Hit-stop
func apply_hitstop(frames: int) -> void
func is_in_hitstop() -> bool

# Direction
func set_facing_direction(direction: Vector2) -> void
func get_facing_direction() -> Vector2

# Lifecycle
func play_spawn() -> void
func play_death() -> void

# Signals
signal windup_started(animation_key: StringName)
signal active_started(animation_key: StringName)
signal recovery_started(animation_key: StringName)
signal action_completed(animation_key: StringName)
signal spawn_completed()
signal death_completed()
signal hitstop_started()
signal hitstop_ended()
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `HIT_REACT_FRAMES` | 10 (167ms) | 4–20 | Duration of flinch animation on taking damage. Too short = damage doesn't feel impactful. Too long = player feels helpless. |
| `MIN_HITSTOP_FRAMES` | 2 (33ms) | 1–4 | Minimum hit-stop duration. Below 1 frame = imperceptible. |
| `MAX_HITSTOP_FRAMES` | 8 (133ms) | 4–12 | Maximum hit-stop duration. Above 12 = combat feels sluggish. |
| `ART_FPS` | 12 | 8–15 | Art frames per second for sprite animation. Lower = chunkier pixel art feel. Higher = smoother. |
| `DIRECTION_COUNT` | 8 | 4 or 8 | Number of directional animation variants. 4 uses horizontal flip. 8 is fully drawn. |
| `SPAWN_ANIMATION_FRAMES` | 30 (500ms) | 15–60 | Duration of spawn-in animation. Must match Entity Framework's `spawn_invulnerability_frames`. |

## Acceptance Criteria

1. **GIVEN** player plays a card with windup=8, active=3, recovery=6, **WHEN**
   action begins, **THEN** entity is locked for exactly 17 physics frames and
   `action_completed` fires on frame 18.

2. **GIVEN** entity in WINDUP, **WHEN** player presses any action input, **THEN**
   input is ignored by animation system (buffered by Input System).

3. **GIVEN** entity in RECOVERY, **WHEN** recovery frames elapse and movement
   input is held, **THEN** entity transitions directly to RUN (no IDLE gap).

4. **GIVEN** entity facing East, **WHEN** WINDUP begins, **THEN** facing
   direction locks to East for entire WINDUP→ACTIVE→RECOVERY sequence even if
   aim changes.

5. **GIVEN** hit-stop triggered with shake_intensity=3.0, **WHEN** calculated,
   **THEN** both attacker and target freeze for 6 frames.

6. **GIVEN** entity in hit-stop, **WHEN** new hit-stop of 4 frames triggers
   with 5 frames remaining, **THEN** total remains at 5 frames (longer wins).

7. **GIVEN** stun applied during WINDUP, **WHEN** transition occurs, **THEN**
   entity enters STUNNED, action is cancelled, effect never resolves.

8. **GIVEN** entity death during ACTIVE, **WHEN** transition occurs, **THEN**
   entity enters DYING immediately, effect has already resolved (damage dealt).

9. **GIVEN** animation key "special_attack_e" not found in SpriteFrames,
   **WHEN** play_action called, **THEN** IDLE animation plays, warning logged.

10. **GIVEN** `active_started` signal fires, **WHEN** Combat System receives
    it, **THEN** hitbox is enabled and damage resolution begins.

11. **GIVEN** entity lifecycle transitions to DYING, **WHEN** entity is in any
    animation state, **THEN** death animation plays immediately (overrides all).

12. **GIVEN** spawn animation completes, **WHEN** `spawn_completed` fires,
    **THEN** entity transitions to IDLE with full state machine active.
