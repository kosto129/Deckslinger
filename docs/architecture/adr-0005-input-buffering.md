# ADR-0005: Input Buffering and Action Map

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Input |
| **Knowledge Risk** | MEDIUM — SDL3 gamepad backend (4.5), dual-focus (4.6) |
| **References Consulted** | `docs/engine-reference/godot/modules/input.md` |
| **Post-Cutoff APIs Used** | SDL3 gamepad backend (transparent, API unchanged) |
| **Verification Required** | Test gamepad device detection with SDL3 backend; verify dual-focus doesn't affect gameplay input |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Signal Architecture — signals for device/mode changes) |
| **Enables** | ADR-0007 (Animation — buffer consumed after recovery), ADR-0009 (Damage Pipeline — combat reads buffered actions) |
| **Blocks** | Input System implementation, all combat/card play implementation |
| **Ordering Note** | Must be accepted before Combat or Card Hand can be built |

## Context

### Problem Statement
Deckslinger's committal combat locks the player into animation phases where input is blocked. Without input buffering, actions pressed during recovery frames are lost, making combat feel unresponsive. We need a buffering system that queues the player's intent and fires it when the character becomes actionable.

### Requirements
- Single-slot buffer (most-recent-wins replacement policy)
- Frame-counted expiry (8 frames = 133ms default)
- Buffer pauses during hit-stop and game pause
- Two input modes (GAMEPLAY/UI) with buffer clear on switch
- KB/M primary, gamepad secondary, automatic device detection

## Decision

**A single `InputManager` autoload polls Godot's Input singleton each `_physics_process`, maintains a single-slot action buffer with frame-counted expiry, and exposes query methods for movement, aim, and buffered actions.**

### InputManager Architecture

```gdscript
class_name InputManager extends Node
# Autoload — always active, survives room transitions

# Buffer state
var _buffered_action: StringName = &""
var _buffer_frame: int = 0
var _frame_counter: int = 0

# Device state
var _active_device: Enums.InputDevice = Enums.InputDevice.KEYBOARD_MOUSE
var _input_mode: Enums.InputMode = Enums.InputMode.GAMEPLAY

# Freeze state (hit-stop / pause)
var _frozen: bool = false

func _physics_process(_delta: float) -> void:
    if _frozen:
        return
    _frame_counter += 1
    _poll_device_switch()
    _check_buffered_actions()
    _expire_buffer()
```

### Buffer Flow

```
Player presses action key →
  _unhandled_input() detects InputEventAction →
  if action is bufferable (Pressed type, GAMEPLAY mode):
    _buffered_action = action_name
    _buffer_frame = _frame_counter
  │
  ▼ (each physics frame)
  Consumer calls consume_buffered_action("attack"):
    if _buffered_action == "attack" AND not expired:
      clear buffer → return true
    else:
      return false
```

### Action Map (Godot InputMap)

All actions are defined in Project Settings → Input Map:

| Action | Type | Buffer | KB/M | Gamepad |
|--------|------|--------|------|---------|
| `move_up/down/left/right` | Held | No | WASD | Left Stick |
| `attack` | Pressed | Yes | LMB | RB |
| `dodge` | Pressed | Yes | Space | LB |
| `card_1/2/3/4` | Pressed | Yes | 1/2/3/4 | D-Pad |
| `interact` | Pressed | Yes | E | A |
| `pause` | Pressed | No (immediate) | Escape | Start |
| `map` | Pressed | No | Tab | Select |
| `deck_view` | Pressed | No | C | Y |
| `aim` | Axis | No | Mouse pos | Right Stick |

### Aim System

```gdscript
func get_aim_direction() -> Vector2:
    match _active_device:
        Enums.InputDevice.KEYBOARD_MOUSE:
            # World-space mouse position relative to player
            var mouse_pos: Vector2 = get_viewport().get_mouse_position()
            var player_pos: Vector2 = _get_player_screen_pos()
            return (mouse_pos - player_pos).normalized()
        Enums.InputDevice.GAMEPAD:
            var stick: Vector2 = _apply_dead_zone(Input.get_vector(
                &"aim_left", &"aim_right", &"aim_up", &"aim_down"
            ))
            if stick.length() < 0.01:
                return get_facing_direction()  # fallback to movement direction
            return stick.normalized()
```

## Alternatives Considered

### Alternative 1: No Buffer (Immediate Input Only)
- **Rejection Reason**: Combat feels unresponsive — actions pressed during recovery are silently lost

### Alternative 2: Multi-Slot Queue Buffer
- **Description**: Queue of N actions, processed FIFO
- **Rejection Reason**: In fast combat, a stale action queue fires unexpected moves. Single-slot with most-recent-wins ensures the player's latest intent is respected.

## Consequences

### Positive
- Combat feels responsive despite committal animations
- Single autoload keeps input handling centralized and debuggable
- Device detection enables seamless KB/M ↔ gamepad switching

### Negative
- Buffer window tuning is critical — too short feels unresponsive, too long fires stale actions
- Must coordinate freeze state with Animation (hit-stop) and Game Manager (pause)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-system.md | A.1 — Named Actions | All 15 actions defined in Godot InputMap |
| input-system.md | B.1–B.6 — Buffer Model | Single-slot, most-recent-wins, frame-counted, mode-clear |
| input-system.md | M.1 — 8-Directional Movement | get_movement_vector() returns normalized Vector2 |
| input-system.md | AIM.1/AIM.2 — Aim System | Mouse world-pos or stick direction with dead zone |

## Performance Implications
- **CPU**: One `_physics_process` call per frame with simple arithmetic. <0.01ms.
- **Memory**: ~100 bytes for buffer state. Negligible.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. Action pressed during 8-frame recovery window fires on the first available frame after recovery
2. Action pressed 9+ frames before recovery ends expires and does not fire
3. Switching from GAMEPLAY to UI mode clears any buffered action
4. Gamepad stick inside dead zone (magnitude < 0.15) produces zero movement vector

## Related Decisions
- ADR-0007: Animation Commitment (defines when buffer can be consumed)
- ADR-0009: Damage Pipeline (combat system consumes buffered attack/card actions)
