# Story 002: Input Buffer

> **Epic**: Input System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/input-system.md`
**Requirements**: `TR-IN-002` (Single-slot input buffer, 8 frames default), `TR-IN-005` (Two input modes with buffer clear on switch)

**ADR Governing Implementation**: ADR-0005: Input Buffering and Action Map
**ADR Decision Summary**: Single-slot buffer, most-recent-wins replacement policy. Frame-counted expiry (8 frames default). Buffer pauses during hit-stop (`_frozen` flag). Buffer is cleared on mode switch (GAMEPLAY ↔ UI). Consumers call `consume_buffered_action(action_name)` — the buffer does not push; it waits to be pulled.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (SDL3 gamepad backend; verify `_unhandled_input` fires reliably for gamepad button events)
**Engine Notes**: `_unhandled_input()` is the correct hook for detecting button press events that have not been claimed by a Control node. In GAMEPLAY mode this is safe. In UI mode, Control nodes may consume input before InputManager sees it — this is expected behaviour and is why UI mode blocks buffering.

**Control Manifest Rules (Foundation)**:
- Required: Input buffer uses single-slot, most-recent-wins policy — source: ADR-0005
- Required: All gameplay timers count physics frames, not real-time seconds — source: ADR-0005
- Required: Buffer, animation, and camera timers freeze during hit-stop (`_frozen` flag) — source: ADR-0005
- Forbidden: Never use real-time (seconds/milliseconds) for gameplay timing — source: ADR-0005

---

## Acceptance Criteria

- [ ] `src/foundation/input_manager.gd` exists with `class_name InputManager extends Node`
- [ ] Script is registered as autoload named `InputManager` in `project.godot`
- [ ] `_frame_counter` increments once per `_physics_process` call when `_frozen` is false
- [ ] `_frame_counter` does NOT increment when `_frozen` is true
- [ ] Pressing a bufferable action stores it in `_buffered_action` with the current `_frame_counter` value as `_buffer_frame`
- [ ] `consume_buffered_action(action_name)` returns `true` and clears the buffer when a matching, non-expired action is buffered
- [ ] `consume_buffered_action(action_name)` returns `false` when no matching action is buffered
- [ ] `consume_buffered_action(action_name)` returns `false` and clears the buffer when the stored action has expired (`current_frame - buffer_frame > BUFFER_WINDOW`)
- [ ] Pressing a second bufferable action while buffer holds a different action replaces it (most-recent-wins)
- [ ] `set_input_mode(mode)` clears `_buffered_action` immediately and emits `input_mode_changed`
- [ ] Held actions (`move_up/down/left/right`) are never written to the buffer
- [ ] `pause` action is never written to the buffer
- [ ] `BUFFER_WINDOW` is a named constant (not a magic number), default value 8

---

## Formulas

### F.3 — Input Buffer Expiry (from GDD)

**Named expression:**

```
is_valid = (current_frame - buffer_frame) <= BUFFER_WINDOW
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `current_frame` | int | 0 – unbounded | Current physics frame counter value |
| `buffer_frame` | int | 0 – unbounded | Frame counter value when action was buffered |
| `BUFFER_WINDOW` | int | 4 – 15 | Maximum buffer lifetime in physics frames (default: 8) |
| `is_valid` | bool | true / false | Whether the buffered action is still consumable |

**Output range**: Boolean. The buffer is either valid or it is not — no clamping required.

**Worked example**:
- `buffer_frame = 142`, `current_frame = 148`, `BUFFER_WINDOW = 8`
- `148 - 142 = 6 <= 8` → `is_valid = true`
- `buffer_frame = 142`, `current_frame = 151`, `BUFFER_WINDOW = 8`
- `151 - 142 = 9 > 8` → `is_valid = false` (buffer cleared)

---

## Buffer Priority (GDD B.6)

When multiple bufferable actions are pressed in the same physics frame, only the highest-priority action is stored. Priority order (lower index = higher priority):

| Priority | Action |
|----------|--------|
| 0 (highest) | `dodge` |
| 1 | `attack` |
| 2 | `card_1` |
| 3 | `card_2` |
| 4 | `card_3` |
| 5 | `card_4` |
| 6 (lowest) | `interact` |

This is implemented as an ordered Array or Dictionary constant in InputManager so the order is data-driven and not buried in if-else chains.

---

## Implementation Notes

The buffer logic lives entirely inside `InputManager` autoload. Key implementation points:

1. **Frame counter**: Increment `_frame_counter` in `_physics_process` only when `_frozen == false`.
2. **Action detection**: Use `_unhandled_input(event: InputEvent)` to detect `InputEventAction` with `is_pressed() == true` and `is_echo() == false`. Echo events must be ignored — they are OS key-repeat signals, not new presses.
3. **Bufferability check**: Before writing to `_buffered_action`, confirm the action is in the bufferable set (see Action Map table in story-001). Use a `const BUFFERABLE_ACTIONS: Array[StringName]` constant.
4. **Priority resolution**: If multiple bufferable actions arrive in `_unhandled_input` in the same frame, compare their priority index. Lower index replaces higher index only if `_buffered_action` already holds a lower-priority action or is empty.
5. **Expiry**: Check expiry at the top of `consume_buffered_action` — not in `_physics_process`. This keeps the expiry check co-located with consumption and avoids a separate expiry sweep.
6. **Mode switch**: `set_input_mode()` must set `_buffered_action = &""` before emitting the signal. Consumers that listen to `input_mode_changed` must not find a stale buffer on the first poll after the switch.
7. **StringName constants**: Declare all action names as `const` `StringName` values at the top of the file (e.g., `const ACTION_ATTACK: StringName = &"attack"`). Avoids string allocation in hot paths.

---

## Out of Scope

- Story 001: InputMap configuration (action names must exist before this compiles)
- Story 003: Movement vector and aim direction (separate query methods — not part of buffer logic)
- Story 004: Device detection and `_frozen` flag coordination (freeze support is scaffolded here but the setter is wired in story-004)

---

## QA Test Cases

### TC-BUF-001: Buffer stores and returns action within window

**Given** `_frame_counter = 100` and `BUFFER_WINDOW = 8`
**When** player presses `attack` (bufferable, GAMEPLAY mode)
**And** `consume_buffered_action(&"attack")` is called at `_frame_counter = 106`
**Then** the method returns `true` and `_buffered_action` is reset to `&""`

---

### TC-BUF-002: Buffer expires after BUFFER_WINDOW frames

**Given** `_frame_counter = 100` and `BUFFER_WINDOW = 8`
**When** player presses `attack` at frame 100
**And** `consume_buffered_action(&"attack")` is called at `_frame_counter = 109`
**Then** the method returns `false` and `_buffered_action` is reset to `&""`

---

### TC-BUF-003: Most-recent-wins replacement

**Given** `_buffered_action = &"dodge"` buffered at frame 100
**When** player presses `attack` at frame 103
**Then** `_buffered_action` is `&"attack"` and `_buffer_frame` is 103

---

### TC-BUF-004: Priority resolves same-frame conflict

**Given** `_frame_counter = 200`
**When** both `dodge` and `attack` are pressed in the same physics frame
**Then** `_buffered_action` is `&"dodge"` (priority 0 beats priority 1)

---

### TC-BUF-005: Mode switch clears buffer

**Given** `_buffered_action = &"attack"` buffered at frame 50
**When** `set_input_mode(Enums.InputMode.UI)` is called
**Then** `_buffered_action` is `&""` immediately
**And** `input_mode_changed` signal fires with `Enums.InputMode.UI`

---

### TC-BUF-006: Buffer frozen during hit-stop

**Given** `_frozen = true`
**When** 20 physics frames elapse
**Then** `_frame_counter` has not changed
**And** a buffered action that was valid before freeze is still valid after unfreeze

---

### TC-BUF-007: Held and immediate actions are not buffered

**Given** GAMEPLAY mode and `_frozen = false`
**When** player presses `move_up` (Held) or `pause` (immediate)
**Then** `_buffered_action` remains `&""` after the press

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit tests (GdUnit4) — BLOCKING gate
**Location**: `tests/unit/input/input_buffer_test.gd`
**Status**: [x] `tests/unit/input/input_buffer_test.gd` — 13 test cases

---

## Dependencies

- Depends on: Story 001 (action map — action StringNames must exist in project.godot; Enums autoload must be registered)
- Unlocks: Story 003 (movement-aim — builds on InputManager scaffold), Story 004 (device-detection — adds `_frozen` setter and device tracking to same autoload)
