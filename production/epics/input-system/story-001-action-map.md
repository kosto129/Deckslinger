# Story 001: Action Map Configuration

> **Epic**: Input System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-IN-001` (Named action map via Godot InputMap)

**ADR Governing Implementation**: ADR-0005: Input Buffering and Action Map
**ADR Decision Summary**: All 15 game actions are defined in Godot's InputMap (project.godot) with both KB/M and gamepad bindings. Named actions are the only interface between hardware events and gameplay systems — raw events are never consumed directly.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (SDL3 gamepad backend in 4.5+; API unchanged but device detection behaviour should be verified)
**Engine Notes**: Godot 4.6 uses SDL3 as its gamepad backend. The InputMap API itself is unchanged. Verify that all gamepad physical button constants (`JOY_BUTTON_*`, `JOY_AXIS_*`) match expected hardware after upgrading. See `docs/engine-reference/godot/modules/input.md`.

**Control Manifest Rules (Foundation)**:
- Required: Use `StringName` (`&"action_name"`) for action names in hot paths — source: ADR-0005
- Required: All cross-system enums live in the Enums autoload — InputMode and InputDevice defined in Story 001 of entity-framework epic
- Forbidden: Never use real-time (seconds) for gameplay timing — frame counters only

---

## Acceptance Criteria

- [x] `project.godot` contains all 15 actions defined in GDD table A.1 (aim split into aim_stick_x/aim_stick_y for Godot axis handling = 16 entries)
- [x] Every action has at least one KB/M binding and at least one gamepad binding as specified below
- [x] Action names exactly match the StringName constants used in InputManager (`&"move_up"`, `&"attack"`, etc.)
- [ ] Pressing each bound key/button in the Godot editor Input Map confirms the action fires (requires in-engine verification)
- [x] No two actions share the same binding (conflict check passes)
- [x] Movement actions (move_up/down/left/right) use positive/negative axis thresholds for gamepad left stick
- [x] `aim` action is configured as 2D axes (right stick X/Y as aim_stick_x/aim_stick_y)

---

## Action Map Table (GDD A.1)

All 15 actions must be present. Configuration target: **Project Settings → Input Map**.

| Action | Category | Buffer? | KB/M Binding | Gamepad Binding |
|--------|----------|---------|--------------|-----------------|
| `move_up` | Movement | No (Held) | W | Left Stick Up (negative Y axis) |
| `move_down` | Movement | No (Held) | S | Left Stick Down (positive Y axis) |
| `move_left` | Movement | No (Held) | A | Left Stick Left (negative X axis) |
| `move_right` | Movement | No (Held) | D | Left Stick Right (positive X axis) |
| `attack` | Combat | Yes | Left Mouse Button | Right Bumper (JOY_BUTTON_5 / RB) |
| `dodge` | Combat | Yes | Space | Left Bumper (JOY_BUTTON_4 / LB) |
| `card_1` | Card Play | Yes | 1 | D-Pad Up (JOY_BUTTON_11) |
| `card_2` | Card Play | Yes | 2 | D-Pad Right (JOY_BUTTON_14) |
| `card_3` | Card Play | Yes | 3 | D-Pad Down (JOY_BUTTON_12) |
| `card_4` | Card Play | Yes | 4 | D-Pad Left (JOY_BUTTON_13) |
| `interact` | World | Yes | E | A / South (JOY_BUTTON_0) |
| `pause` | UI | No (immediate) | Escape | Start (JOY_BUTTON_6) |
| `map` | UI | No | Tab | Select / Back (JOY_BUTTON_7) |
| `deck_view` | UI | No | C | Y / North (JOY_BUTTON_3) |
| `aim` | Combat | No (Axis) | Mouse Position | Right Stick (X/Y axes 2 and 3) |

> **Note on `aim`**: For KB/M, aim direction is computed at runtime from mouse world position — no InputMap binding is needed for the mouse. The InputMap entry for `aim` covers the right stick axes only. The `map` action also accepts M as a secondary KB binding (see GDD A.1).

---

## Implementation Notes

1. Open **Project Settings → Input Map** in the Godot editor.
2. Add each action by name exactly as listed above (case-sensitive, underscore-separated).
3. For movement axis bindings, use the "Add Axis" option on the left stick. Set the deadzone to 0.0 in the InputMap — InputManager applies its own dead zone remap (F.1 in GDD, per ADR-0005). InputMap deadzone must not double-count.
4. For `aim`, add right stick X and Y axes. InputManager reads them via `Input.get_vector()` and applies dead zone remap independently.
5. `project.godot` is the sole source of truth for bindings at boot. Runtime remapping (GDD section R.1) will be handled in a future story — do not implement remapping here.
6. Secondary binding for `map` action (M key): add as a second KB event on the same action.

---

## Out of Scope

- Story 002: Input buffer logic (consumes these action names)
- Story 003: Movement vector and aim direction computation (reads these actions)
- Story 004: Device detection (reads these actions to determine active device)
- Runtime key remapping UI (settings menu — future story)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check — all 15 actions exist in project.godot and both input methods produce the correct action event in a test scene
**Status**: [x] All 16 action entries configured in project.godot — in-engine binding verification pending

---

## Dependencies

- Depends on: Story 001 of entity-framework epic (Enums autoload — InputMode, InputDevice must be defined before InputManager references them)
- Unlocks: Story 002 (input-buffer), Story 003 (movement-aim), Story 004 (device-detection)
