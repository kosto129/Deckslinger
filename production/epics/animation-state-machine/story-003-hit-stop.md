# Story 003: Hit-Stop

> **Epic**: Animation State Machine
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/animation-state-machine.md`
**Requirement**: `TR-AS-003`

**ADR Governing Implementation**: ADR-0007: Animation Commitment and Hit-Stop
**ADR Decision Summary**: `apply_hitstop(frames)` freezes animation phase timers via `_hitstop_remaining` counter. Longer-wins policy: `_hitstop_remaining = maxi(_hitstop_remaining, frames)` — no additive stacking. Hit-stop also freezes `InputManager._frozen`, `CameraController._frozen`, and `MovementComponent._frozen`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff API risk. `maxi()` is a built-in GDScript global function available since Godot 4.0.

**Control Manifest Rules (Core)**:
- Required: Hit-stop freezes ALL gameplay systems simultaneously — AnimationComponent, InputManager, CameraController, MovementComponent
- Required: All gameplay timers count physics frames, not real-time seconds — `_hitstop_remaining` is an integer frame counter
- Required: Buffer, animation, and camera timers freeze during hit-stop

---

## Acceptance Criteria

- [ ] `apply_hitstop(frames: int) -> void` sets `_hitstop_remaining = maxi(_hitstop_remaining, frames)` (longer wins, no additive stacking)
- [ ] During `_physics_process`, if `_hitstop_remaining > 0`: decrement by 1 and return — `_phase_timer` does NOT decrement
- [ ] `is_in_hitstop() -> bool` returns true when `_hitstop_remaining > 0`
- [ ] `hitstop_started` signal emits when `_hitstop_remaining` transitions from 0 → positive
- [ ] `hitstop_ended` signal emits when `_hitstop_remaining` transitions from positive → 0
- [ ] AnimatedSprite2D frame does not advance during hit-stop (sprite is paused)
- [ ] `apply_hitstop(4)` during existing 6-frame hit-stop: `_hitstop_remaining` remains 6 (longer wins)
- [ ] `apply_hitstop(8)` during existing 6-frame hit-stop: `_hitstop_remaining` becomes 8 (new is longer)
- [ ] Hit-stop with `frames <= 0` is a no-op
- [ ] `InputManager.set_frozen(true)` is called when hit-stop begins; `set_frozen(false)` when it ends
- [ ] `CameraController.set_frozen(true)` is called when hit-stop begins; `set_frozen(false)` when it ends

---

## Implementation Notes

From ADR-0007: `_hitstop_remaining` is checked first in `_physics_process`. If positive, all timers are skipped. This means phase timers, i-frame timers (in HurtboxComponent), and cooldown timers are all implicitly frozen when AnimationComponent returns early.

```gdscript
var _hitstop_remaining: int = 0
var _was_in_hitstop: bool = false

signal hitstop_started()
signal hitstop_ended()

func apply_hitstop(frames: int) -> void:
    if frames <= 0:
        return
    var entering_hitstop: bool = _hitstop_remaining <= 0
    _hitstop_remaining = maxi(_hitstop_remaining, frames)
    if entering_hitstop:
        _on_hitstop_begin()

func _on_hitstop_begin() -> void:
    hitstop_started.emit()
    InputManager.set_frozen(true)
    CameraController.set_frozen(true)
    # AnimatedSprite2D pause handled by checking _hitstop_remaining in _update_sprite()

func _physics_process(_delta: float) -> void:
    if _hitstop_remaining > 0:
        _hitstop_remaining -= 1
        if _hitstop_remaining <= 0:
            _on_hitstop_end()
        return  # ALL timers frozen
    # ... normal phase processing
```

Formula F.2 (hit-stop duration from shake_intensity): `hitstop_frames = clamp(ceil(shake_intensity * 2), MIN_HITSTOP_FRAMES, MAX_HITSTOP_FRAMES)`. This formula lives in CombatSystem — AnimationComponent only receives the pre-calculated `frames` value.

Note: AnimatedSprite2D frame pausing — the sprite's `speed_scale` must be set to 0.0 during hit-stop and restored to 1.0 when hit-stop ends. Alternatively, call `animated_sprite.pause()` and `animated_sprite.play()`. Confirm Godot 4.6 AnimatedSprite2D API before implementation.

---

## Out of Scope

- Story 001: Core phase timer logic (hit-stop checks happen before phase logic)
- Story 002: Commitment enforcement (hit-stop is a pause, not a cancel)
- Combat System story-001: The formula `ceil(shake_intensity * 2)` lives in CombatSystem, not here
- Camera System: Screen shake application (separate from camera freeze)

---

## QA Test Cases

- **AC-1**: Hit-stop freezes phase timer
  - Given: Entity in WINDUP with `_phase_timer = 8`, `_hitstop_remaining = 0`
  - When: `apply_hitstop(6)` called; 3 physics frames elapse
  - Then: `_phase_timer` still equals 8 (not decremented); `_hitstop_remaining` equals 3
  - When: 3 more frames elapse (hit-stop expires)
  - Then: `_phase_timer` resumes decrementing normally

- **AC-2**: Longer-wins policy — new is shorter
  - Given: `_hitstop_remaining = 6`
  - When: `apply_hitstop(4)` called
  - Then: `_hitstop_remaining` remains 6

- **AC-3**: Longer-wins policy — new is longer
  - Given: `_hitstop_remaining = 4`
  - When: `apply_hitstop(8)` called
  - Then: `_hitstop_remaining` becomes 8

- **AC-4**: Signals fire correctly
  - Given: `_hitstop_remaining = 0`
  - When: `apply_hitstop(5)` called
  - Then: `hitstop_started` emits exactly once
  - When: 5 frames elapse
  - Then: `hitstop_ended` emits exactly once

- **AC-5**: No double-freeze on stacked apply calls
  - Given: `_hitstop_remaining = 4`
  - When: `apply_hitstop(6)` called (already in hit-stop)
  - Then: `hitstop_started` does NOT emit again (already in hit-stop)
  - Then: `_hitstop_remaining = 6`

- **AC-6**: Zero-frame call is no-op
  - Given: Any state
  - When: `apply_hitstop(0)` called
  - Then: `_hitstop_remaining` unchanged; no signals emit

- **AC-7**: InputManager frozen during hit-stop
  - Given: `_hitstop_remaining = 0`
  - When: `apply_hitstop(3)` called
  - Then: `InputManager.is_frozen()` returns true for 3 frames, then false

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/hit_stop_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (State Machine Core — hit-stop operates on `_phase_timer` and `_physics_process`)
- Depends on: Entity Framework epic (complete) — InputManager and CameraController autoloads must exist with `set_frozen()` API
- Unlocks: Story 004 (Sprite Integration — AnimatedSprite2D pause during hit-stop)
- Unlocks (cross-epic): Combat System story-001 (CombatSystem calls `apply_hitstop()` on both attacker and target); Combat System story-003 (hit-stop orchestration)
