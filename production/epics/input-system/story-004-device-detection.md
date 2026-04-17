# Story 004: Device Detection and Mode Management

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/input-system.md`
**Requirements**: `TR-IN-005` (Two input modes GAMEPLAY/UI with buffer clear on switch), `TR-IN-006` (Device detection with automatic UI prompt switching)

**ADR Governing Implementation**: ADR-0005: Input Buffering and Action Map
**ADR Decision Summary**: InputManager tracks the last active input device (`KEYBOARD_MOUSE` or `GAMEPAD`). Switching device emits `input_device_changed(device: Enums.InputDevice)`. Two input modes (GAMEPLAY / UI) are managed via `set_input_mode()` which clears the buffer and emits `input_mode_changed(mode: Enums.InputMode)`. A `_frozen` flag (set externally by Animation / Game Manager) halts `_frame_counter` increments and pauses buffer expiry. Most-recent device wins on simultaneous input.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (SDL3 gamepad backend introduced in 4.5; verify `InputEventJoypadButton` and `InputEventJoypadMotion` fire correctly; verify dual-focus behaviour does not intercept gamepad events)
**Engine Notes**: Godot 4.6 uses SDL3 as its gamepad backend (transparent API change — `JOY_BUTTON_*` and `JOY_AXIS_*` constants are unchanged). Dual-focus (4.6 feature) separates mouse hover focus from keyboard/gamepad focus in UI Control nodes. In GAMEPLAY mode InputManager sits in `_unhandled_input` and should receive all joypad events not consumed by UI. Test device switch in a scene that has active Control nodes to confirm no event theft. See `docs/engine-reference/godot/modules/input.md`.

**Control Manifest Rules (Foundation)**:
- Required: Buffer, animation, and camera timers freeze during hit-stop — `_frozen` flag — source: ADR-0005
- Required: Use Callable-based signal connections — `signal.connect(callable)`, never string-based — source: ADR-0002
- Required: Type all signal parameters — no `Variant` catch-alls — source: ADR-0002
- Required: Signals use past tense for events — `input_device_changed`, `input_mode_changed` — source: ADR-0002
- Forbidden: Never use a global event bus autoload — signals live on the emitting object (InputManager) — source: ADR-0002

---

## Acceptance Criteria

- [ ] `InputManager` emits `input_device_changed(device: Enums.InputDevice)` when the active device changes from KEYBOARD_MOUSE to GAMEPAD or vice versa
- [ ] Signal does NOT fire when a gamepad event arrives and `_active_device` is already GAMEPAD
- [ ] Signal does NOT fire when a keyboard event arrives and `_active_device` is already KEYBOARD_MOUSE
- [ ] Device switch threshold: gamepad stick motion only triggers device switch if magnitude exceeds `DEVICE_SWITCH_THRESHOLD` (default 0.5) — prevents drift-induced switches
- [ ] `get_active_device() -> Enums.InputDevice` returns the current active device
- [ ] `InputManager` emits `input_mode_changed(mode: Enums.InputMode)` when `set_input_mode()` is called with a different mode
- [ ] `get_input_mode() -> Enums.InputMode` returns the current input mode
- [ ] `set_input_mode(Enums.InputMode.UI)` clears the buffer (AC from story-002 still passes after this story lands)
- [ ] `set_frozen(frozen: bool)` sets `_frozen` — when `true`, `_frame_counter` stops incrementing (AC from story-002 still passes)
- [ ] When window loses focus (`NOTIFICATION_WM_WINDOW_FOCUS_OUT`), all held inputs are released and buffer is cleared
- [ ] `_frozen = true` does NOT prevent device detection — device changes are still tracked during freeze (only frame counter and buffer expiry pause)
- [ ] `DEVICE_SWITCH_THRESHOLD` is a named constant, not a magic number
- [ ] Both signals have typed parameters matching `Enums.InputDevice` and `Enums.InputMode` respectively

---

## Signal Specifications

```gdscript
## Emitted when the active input device changes (KB/M <-> gamepad).
## Downstream systems (UI prompt swap, aim cursor visibility) connect here.
signal input_device_changed(device: Enums.InputDevice)

## Emitted when input mode changes between GAMEPLAY and UI.
## Combat, Card Hand, and Movement systems connect here to pause input handling.
signal input_mode_changed(mode: Enums.InputMode)
```

Signal parameters must use the registered `Enums` types. Never use `int` as a stand-in for an enum parameter — the signal definition must carry the type.

---

## Public API Summary (Full InputManager Interface)

After Story 004, InputManager exposes this complete public interface:

```gdscript
# From Story 003 — movement and aim queries
func get_movement_vector() -> Vector2
func get_facing_direction() -> Vector2
func get_aim_direction() -> Vector2
func get_aim_angle() -> float

# From Story 002 — buffer
func consume_buffered_action(action_name: StringName) -> bool

# From Story 004 — mode and device state
func get_input_mode() -> Enums.InputMode
func set_input_mode(mode: Enums.InputMode) -> void
func get_active_device() -> Enums.InputDevice
func set_frozen(frozen: bool) -> void

# Signals (Story 004)
signal input_device_changed(device: Enums.InputDevice)
signal input_mode_changed(mode: Enums.InputMode)
```

No other methods are part of the public API. Internal helpers (`_poll_device_switch`, `_apply_dead_zone`, `_expire_buffer`) are prefixed with `_` and must not be called by external systems.

---

## Device Detection Logic

Device switch detection runs inside `_unhandled_input(event: InputEvent)`:

```
if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
    new_device = KEYBOARD_MOUSE
elif event is InputEventJoypadButton:
    new_device = GAMEPAD
elif event is InputEventJoypadMotion:
    if event.axis_value.abs() >= DEVICE_SWITCH_THRESHOLD:
        new_device = GAMEPAD
    else:
        return  # stick drift — do not switch

if new_device != _active_device:
    _active_device = new_device
    input_device_changed.emit(_active_device)
```

The threshold guard on `InputEventJoypadMotion` prevents the right stick's resting drift (axis noise in SDL3) from continuously pinging device changes when the player is on keyboard.

---

## Freeze Behaviour

`set_frozen(true)` is called by:
- `AnimationComponent` at hit-stop start (ADR-0007)
- `GameManager` on pause (paired with `set_input_mode(UI)`)

`set_frozen(false)` is called by the same systems on resume.

When frozen:
- `_frame_counter` does NOT increment (buffer expiry pauses)
- `_poll_device_switch()` still runs (device changes are tracked)
- `_check_buffered_actions()` does NOT run (no new buffer writes)
- `consume_buffered_action()` still returns valid results — consuming systems may query during freeze; the buffer does not expire until unfreeze

---

## Window Focus Loss Handling

Override `_notification(what: int)` in InputManager:

```
if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
    _buffered_action = &""
    Input.action_release_all_actions()  # releases all held keys
```

This prevents ghost movement after alt-tab. `Input.action_release_all_actions()` is a Godot 4.x built-in that synthesizes release events for all currently-pressed actions.

> **Verify**: Confirm `action_release_all_actions()` exists in Godot 4.6 API. Check `docs/engine-reference/godot/modules/input.md` before implementing. If absent, iterate over held actions and call `Input.action_release()` individually.

---

## Out of Scope

- Story 001: Action map (prerequisite)
- Story 002: Buffer logic (prerequisite — `_frozen` setter wired here but buffer logic is in story-002)
- Story 003: Movement/aim queries (prerequisite)
- UI prompt icon swap (Presentation layer — downstream system listens to `input_device_changed` signal)
- Aim cursor visibility toggle for gamepad (Presentation layer — future story)
- Settings menu for dead zone and buffer window tuning (future story)

---

## Integration Verification Checklist

Because this is an Integration story, the following cross-system interactions must be manually verified in a test scene before marking Done:

- [ ] `input_device_changed` received by a stub UI node that logs the new device — confirm it fires exactly once on first gamepad button press from keyboard state
- [ ] `input_mode_changed` received by a stub combat node — confirm buffer is empty after mode switches to UI
- [ ] `set_frozen(true)` called from a test harness — confirm `_frame_counter` freezes and buffer does not expire during freeze
- [ ] Window alt-tab test: hold W key, alt-tab out, alt-tab back — confirm player is not moving after focus return
- [ ] Simultaneous KB/M and gamepad: hold WASD and push left stick — confirm movement vector uses KB/M, not stick (KB/M priority rule from GDD edge case)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration test OR documented playtest — BLOCKING gate
**Location**: `tests/integration/input/device_detection_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (action map), Story 002 (InputManager autoload with buffer and frame counter), Story 003 (movement/aim methods — completes the public API this story finalises)
- Unlocks: All downstream consumers — Combat System, Card Hand System, Movement (via Entity Framework), Camera System, All UI Systems (button prompt swap)
