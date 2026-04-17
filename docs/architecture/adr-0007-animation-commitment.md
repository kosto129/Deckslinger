# ADR-0007: Animation Commitment and Hit-Stop

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Animation |
| **Knowledge Risk** | LOW — AnimatedSprite2D, SpriteFrames unchanged. AnimationMixer base class (4.3) is in training data. |
| **References Consulted** | `docs/engine-reference/godot/modules/animation.md` |
| **Post-Cutoff APIs Used** | None for 2D sprite animation |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Entity Composition — AnimationComponent is a component), ADR-0004 (Data Resources — CardData provides frame counts) |
| **Enables** | ADR-0008 (Collision — hitbox enabled during ACTIVE), ADR-0009 (Damage Pipeline — active_started triggers resolution) |
| **Blocks** | Combat System, Card Hand System, Enemy AI implementation |
| **Ordering Note** | Must be accepted before any combat gameplay can be built |

## Context

### Problem Statement
Deckslinger's core design pillar is "Every Card Is a Commitment." When the player plays a card, they are locked into a windup→active→recovery animation sequence that cannot be cancelled. This commitment creates the tension and weight that defines the combat feel. We need an animation system that enforces these locks, drives hit-stop freezes, coordinates with the input buffer, and works with Godot's AnimatedSprite2D for 2D pixel art.

### Requirements
- Three-phase action sequence: WINDUP (telegraph) → ACTIVE (effect live) → RECOVERY (vulnerable)
- Frame counts from CardData/EnemyAttackData drive phase durations
- No input can cancel WINDUP, ACTIVE, or RECOVERY (only death or stun can interrupt)
- Hit-stop freezes both attacker and target, pausing all timers
- 8-directional sprite animation with facing locked during actions
- 12 art fps (each drawn frame held for 5 physics frames)

## Decision

**An `AnimationComponent` node on each entity runs a custom state machine that counts physics frames for each action phase. It drives an `AnimatedSprite2D` child for visual playback and emits signals at phase boundaries. Hit-stop is implemented as a frame-level pause of all animation and gameplay timers.**

### Animation State Machine

```gdscript
class_name AnimationComponent extends Node

enum AnimState { IDLE, RUN, WINDUP, ACTIVE, RECOVERY, HIT_REACT, STUNNED, SPAWNING, DYING }

var _state: AnimState = AnimState.IDLE
var _phase_timer: int = 0          # frames remaining in current timed phase
var _current_action_key: StringName = &""
var _locked_facing: Vector2 = Vector2.RIGHT
var _hitstop_remaining: int = 0

signal windup_started(key: StringName)
signal active_started(key: StringName)
signal recovery_started(key: StringName)
signal action_completed(key: StringName)
signal spawn_completed()
signal death_completed()
```

### Action Execution

```gdscript
func play_action(key: StringName, windup: int, active: int, recovery: int) -> void:
    _current_action_key = key
    _locked_facing = _get_current_facing()  # lock direction at commitment
    _enter_state(AnimState.WINDUP)
    _phase_timer = windup
    _windup_frames = windup
    _active_frames = active
    _recovery_frames = recovery

func _physics_process(_delta: float) -> void:
    if _hitstop_remaining > 0:
        _hitstop_remaining -= 1
        return  # ALL timers frozen during hit-stop

    if _phase_timer > 0:
        _phase_timer -= 1
        if _phase_timer <= 0:
            _advance_phase()

func _advance_phase() -> void:
    match _state:
        AnimState.WINDUP:
            _enter_state(AnimState.ACTIVE)
            _phase_timer = _active_frames
            active_started.emit(_current_action_key)
        AnimState.ACTIVE:
            _enter_state(AnimState.RECOVERY)
            _phase_timer = _recovery_frames
            recovery_started.emit(_current_action_key)
        AnimState.RECOVERY:
            _enter_state(AnimState.IDLE)
            action_completed.emit(_current_action_key)
```

### Hit-Stop Implementation

```gdscript
func apply_hitstop(frames: int) -> void:
    _hitstop_remaining = maxi(_hitstop_remaining, frames)  # longer wins, no stacking

# Hit-stop freezes:
# - Animation phase timers (this component)
# - AnimatedSprite2D frame advancement (paused)
# - Input buffer timer (InputManager._frozen = true)
# - Camera lerp and shake decay (CameraController._frozen = true)
# - Entity position (MovementComponent._frozen = true)
```

### Sprite Direction

```gdscript
# 8 directions: E, NE, N, NW, W, SW, S, SE
# Animation name format: "{state}_{direction}" e.g., "idle_e", "run_nw"
# During action: direction locked to _locked_facing
# During IDLE/RUN: direction follows facing_direction from InputManager/AI

func _get_animation_name(state: AnimState, direction: Vector2) -> StringName:
    var dir_suffix: String = _vector_to_dir_string(direction)
    var state_prefix: String = _state_to_prefix(state)
    return StringName(state_prefix + "_" + dir_suffix)
```

## Alternatives Considered

### Alternative 1: Godot AnimationPlayer with Method Tracks
- **Description**: Use AnimationPlayer's method call tracks to trigger phase events at specific keyframes
- **Pros**: Visual timeline in editor, art-driven timing
- **Cons**: Fragile — artists changing animation length breaks gameplay timing. GDD specifies frame counts as data, not art-driven.
- **Rejection Reason**: Gameplay timing must be data-driven (CardData frame counts), not art-driven. AnimationPlayer would couple gameplay to animation assets.

### Alternative 2: AnimationTree State Machine
- **Description**: Use Godot's AnimationTree with a StateMachine node for transitions
- **Pros**: Built-in state machine with transition blending
- **Cons**: Designed for smooth 3D blending, not frame-exact 2D commitment. Over-engineered for pixel art with discrete states.
- **Rejection Reason**: AnimationTree adds complexity without benefit for pixel art sprite animation. Our state machine is simpler and more precise.

## Consequences

### Positive
- Frame-exact commitment enforcement — every action locks for exactly the specified frames
- Hit-stop freezes ALL gameplay uniformly (animation, input, camera, movement)
- Data-driven: adding a new card with different timings requires zero code changes

### Negative
- Custom state machine means no visual editor for animation states (text-only)
- 8-direction sprites require 8× the art per animation state (4-direction + flip reduces this to 5×)

### Risks
- **Art/data mismatch**: If an art animation has 6 drawn frames but CardData specifies 20 physics frames of windup, the art loops awkwardly. Mitigation: art fps (12) × drawn frames should approximately match physics frame counts. Document the ratio per animation.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| animation-state-machine.md | AS.1 — State Definitions | 9 animation states implemented in AnimationComponent |
| animation-state-machine.md | AS.2 — Valid Transitions | State machine enforces transition rules |
| animation-state-machine.md | AS.3 — Action Sequence | play_action() → WINDUP → ACTIVE → RECOVERY with phase signals |
| animation-state-machine.md | HS.1–HS.3 — Hit-Stop | apply_hitstop() with longer-wins policy, all timers frozen |
| animation-state-machine.md | DA.1–DA.2 — Directional Animation | 8-direction with facing lock during actions |

## Performance Implications
- **CPU**: One integer decrement per entity per frame. Negligible.
- **Memory**: ~50 bytes per AnimationComponent. Negligible.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. play_action(key, 8, 3, 6) results in exactly 17 frames of lock, with signals at frames 0, 8, 11, and 17
2. During hit-stop, no entity moves, no timer decrements, AnimatedSprite2D frame is frozen
3. Facing direction is locked at WINDUP start and does not change until action_completed
4. Stun during WINDUP cancels the action — action_completed does NOT fire, entity enters STUNNED

## Related Decisions
- ADR-0001: Entity Composition (AnimationComponent is a child node)
- ADR-0005: Input Buffering (buffer consumed when action_completed fires)
- ADR-0008: Collision (hitbox enabled during ACTIVE state)
- ADR-0009: Damage Pipeline (active_started triggers damage resolution)
