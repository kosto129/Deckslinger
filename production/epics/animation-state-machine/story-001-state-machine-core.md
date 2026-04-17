# Story 001: Animation State Machine Core

> **Epic**: Animation State Machine
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/animation-state-machine.md`
**Requirement**: `TR-AS-001`, `TR-AS-002`

**ADR Governing Implementation**: ADR-0007: Animation Commitment and Hit-Stop
**ADR Decision Summary**: Custom frame-counting state machine on AnimationComponent. 9 animation states with valid transition rules. play_action() locks entity for exact physics frame counts across WINDUP → ACTIVE → RECOVERY. Phase signals emitted at frame boundaries.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: AnimatedSprite2D and SpriteFrames unchanged in 4.4–4.6. No post-cutoff API risk.

**Control Manifest Rules (Core)**:
- Required: Actions use 3-phase commitment — WINDUP → ACTIVE → RECOVERY — frame counts from CardData/EnemyAttackData
- Required: AnimationComponent drives AnimatedSprite2D via SpriteFrames
- Forbidden: Never use AnimationPlayer or AnimationTree for gameplay timing — coupling gameplay to art asset length

---

## Acceptance Criteria

- [ ] `AnimationComponent` class exists extending Node, with `class_name AnimationComponent`
- [ ] `AnimState` enum defines 9 states: `IDLE, RUN, WINDUP, ACTIVE, RECOVERY, HIT_REACT, STUNNED, DYING, SPAWNING`
- [ ] `play_action(key: StringName, windup: int, active: int, recovery: int) -> void` stores frame counts and enters WINDUP
- [ ] `_phase_timer` decrements by 1 each physics frame (not during hit-stop)
- [ ] When `_phase_timer` reaches 0 in WINDUP → enters ACTIVE, resets `_phase_timer` to `active_frames`, emits `active_started`
- [ ] When `_phase_timer` reaches 0 in ACTIVE → enters RECOVERY, resets `_phase_timer` to `recovery_frames`, emits `recovery_started`
- [ ] When `_phase_timer` reaches 0 in RECOVERY → enters IDLE, emits `action_completed`
- [ ] `windup_started(key: StringName)` emits immediately when `play_action()` is called
- [ ] `is_in_action() -> bool` returns true during WINDUP, ACTIVE, or RECOVERY; false otherwise
- [ ] `get_action_state() -> AnimState` returns the current state enum value
- [ ] Valid transitions enforced: WINDUP/ACTIVE/RECOVERY cannot be entered by input while another is active
- [ ] All 4 phase signals are typed: `signal windup_started(animation_key: StringName)`, `signal active_started(animation_key: StringName)`, `signal recovery_started(animation_key: StringName)`, `signal action_completed(animation_key: StringName)`

---

## Implementation Notes

From ADR-0007: The state machine counts physics frames, not real-time delta. `_physics_process` is the only place where `_phase_timer` is decremented. All timing is data-driven — frame counts come from caller, not baked into the component.

```gdscript
class_name AnimationComponent extends Node

enum AnimState { IDLE, RUN, WINDUP, ACTIVE, RECOVERY, HIT_REACT, STUNNED, DYING, SPAWNING }

var _state: AnimState = AnimState.IDLE
var _phase_timer: int = 0
var _current_action_key: StringName = &""
var _windup_frames: int = 0
var _active_frames: int = 0
var _recovery_frames: int = 0
var _hitstop_remaining: int = 0

signal windup_started(animation_key: StringName)
signal active_started(animation_key: StringName)
signal recovery_started(animation_key: StringName)
signal action_completed(animation_key: StringName)

func play_action(key: StringName, windup: int, active: int, recovery: int) -> void:
    _current_action_key = key
    _locked_facing = _get_current_facing()
    _windup_frames = windup
    _active_frames = active
    _recovery_frames = recovery
    _enter_state(AnimState.WINDUP)
    _phase_timer = windup
    windup_started.emit(key)

func _physics_process(_delta: float) -> void:
    if _hitstop_remaining > 0:
        _hitstop_remaining -= 1
        return  # ALL timers frozen during hit-stop
    if _phase_timer > 0:
        _phase_timer -= 1
        if _phase_timer <= 0:
            _advance_phase()
```

Formula F.1 (total lock duration): `total_lock_frames = windup + active + recovery`. Example: Quick Draw (8, 3, 6) = 17 frames = 283ms. `action_completed` fires on frame 18.

---

## Out of Scope

- Story 002: Commitment enforcement (interrupt rules, direction locks)
- Story 003: Hit-stop implementation
- Story 004: AnimatedSprite2D sprite integration

---

## QA Test Cases

- **AC-1**: play_action phase sequence
  - Given: AnimationComponent in IDLE state
  - When: `play_action(&"quick_draw", 8, 3, 6)` called
  - Then: `windup_started` emits immediately; after 8 physics frames `active_started` emits; after 3 more frames `recovery_started` emits; after 6 more frames `action_completed` emits; total lock = exactly 17 frames
  - Edge case: Call at frame boundary — timer must count exactly, not off-by-one

- **AC-2**: is_in_action during each phase
  - Given: Entity begins play_action(key, 5, 5, 5)
  - When: Queried during WINDUP, ACTIVE, RECOVERY
  - Then: `is_in_action()` returns true for all three phases
  - When: `action_completed` fires and entity returns to IDLE
  - Then: `is_in_action()` returns false

- **AC-3**: play_action while already in action
  - Given: Entity is in WINDUP phase
  - When: `play_action()` called a second time
  - Then: Second call is rejected — state does not change, original sequence continues
  - Edge case: Caller must check `is_in_action()` before calling `play_action()`

- **AC-4**: Signal parameter correctness
  - Given: `play_action(&"heavy_blow_e", 15, 4, 12)` called
  - When: Each phase signal fires
  - Then: All four signals carry `animation_key = &"heavy_blow_e"`

- **AC-5**: Zero-frame edge case
  - Given: `play_action(&"instant", 0, 1, 0)` called
  - When: Physics frame processes
  - Then: WINDUP phase advances immediately (0-frame windup resolves on same frame), ACTIVE runs for 1 frame, RECOVERY resolves immediately

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/animation_state_machine_core_test.gd` — must exist and pass
**Status**: [x] `tests/unit/animation/animation_state_machine_core_test.gd` — 16 test cases

---

## Dependencies

- Depends on: Entity Framework epic (complete) — AnimationComponent is a child node of EntityBase; Enums autoload defines `AnimState` or equivalent
- Unlocks: Story 002 (Commitment Enforcement), Story 003 (Hit-Stop), Story 004 (Sprite Integration)
- Unlocks (cross-epic): Collision/Hitbox story-002, Combat System story-001
