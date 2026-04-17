# Input System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (Every Card Is a Commitment)

## Summary

The Input System translates raw hardware events (keyboard, mouse, gamepad) into
named game actions and manages an input buffer that allows players to queue
actions during animation commitment windows. It owns no gameplay logic — it
provides the translation layer that Combat, Card Hand, and Movement consume.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

The Input System is the bridge between the player's physical inputs and every
gameplay system that responds to player intent. It defines a canonical action
map (named actions like `move_up`, `attack`, `card_1`), handles device detection
and switching, normalizes analog stick input with configurable dead zones, and
maintains a single-slot input buffer that lets players queue their next action
during animation recovery frames. In a committal combat game where every action
locks the player into an animation, the buffer window is what separates "this
feels responsive" from "this feels laggy." The Input System never decides what
an action does — that belongs to Combat and Card Hand. It only decides what
action the player intended and when they intended it.

## Player Fantasy

The player never thinks about the Input System. When it works, every action
feels like it responded to their intent — not too early, not too late. The
buffer window creates the invisible safety net that makes committal combat feel
precise rather than punishing. The player pressed dodge during a sword swing's
recovery, and the dodge fires the instant recovery ends. They feel skilled. The
Input System made that possible, but the player credits their own reflexes.

## Detailed Rules

### Action Map

**A.1 — Named Actions**

All game systems consume named actions, never raw input events. Actions are
defined in Godot's InputMap and extended with custom buffering logic.

| Action | Category | Type | KB/M Binding | Gamepad Binding |
|--------|----------|------|-------------|-----------------|
| `move_up` | Movement | Held | W | Left Stick Up |
| `move_down` | Movement | Held | S | Left Stick Down |
| `move_left` | Movement | Held | A | Left Stick Left |
| `move_right` | Movement | Held | D | Left Stick Right |
| `attack` | Combat | Pressed | Left Click | Right Bumper (RB) |
| `dodge` | Combat | Pressed | Space | Left Bumper (LB) |
| `card_1` | Card Play | Pressed | 1 | D-Pad Up |
| `card_2` | Card Play | Pressed | 2 | D-Pad Right |
| `card_3` | Card Play | Pressed | 3 | D-Pad Down |
| `card_4` | Card Play | Pressed | 4 | D-Pad Left |
| `interact` | World | Pressed | E | A (South) |
| `pause` | UI | Pressed | Escape | Start |
| `map` | UI | Pressed | Tab / M | Select / Back |
| `deck_view` | UI | Pressed | C | Y (North) |
| `aim` | Combat | Axis | Mouse Position | Right Stick |

Action types:
- **Pressed**: Fires once on key-down. Bufferable.
- **Held**: Fires every physics frame while held. Not buffered.
- **Axis**: Continuous directional value. Not buffered.

**A.2 — Input Modes**

The system operates in two mutually exclusive modes:

| Mode | Active Actions | Triggered By |
|------|---------------|--------------|
| `GAMEPLAY` | All movement, combat, card play, interact | Default; resume from pause |
| `UI` | UI navigation only (confirm, cancel, navigate) | Pause menu, reward screen, map screen |

Mode switch clears the input buffer. UI mode blocks all gameplay actions.
Gameplay mode blocks UI navigation inputs.

**A.3 — Device Detection**

The system tracks the last active input device:

- On any keyboard/mouse event → set `active_device = KEYBOARD_MOUSE`
- On any gamepad event → set `active_device = GAMEPAD`
- Device switch emits `input_device_changed(new_device)` signal
- UI elements listen to this signal to swap button prompt icons

No simultaneous dual-device input — most recent device wins.

### Input Buffering

**B.1 — Buffer Model**

Single-slot buffer. Only one action can be buffered at a time. If a new
bufferable action is pressed while a buffer already holds an action, the new
action replaces the old one (most-recent-wins policy).

**B.2 — Buffer Lifecycle**

1. Player presses a bufferable action (Pressed type)
2. If the player character is in a state that cannot execute the action
   (animation lock, recovery, stun), the action is stored in the buffer with
   a timestamp
3. Each physics frame, the consuming system (Combat, Card Hand) calls
   `consume_buffered_action(action_name) -> bool`
4. If the buffer holds a matching action and the buffer has not expired,
   return `true` and clear the buffer
5. If expired or no match, return `false`

**B.3 — Buffer Expiry**

Buffered actions expire after `BUFFER_WINDOW` frames. The timer counts physics
frames, not real-time, to stay synchronized with gameplay. If the game is
paused, the buffer timer pauses (no expiry during pause).

**B.4 — Non-Bufferable Actions**

Movement (held actions) and aim (axis) are never buffered — they reflect
instantaneous state. `pause` is never buffered — it always fires immediately.
`interact` is buffered with the same window as combat actions.

**B.5 — Buffer and Mode Switches**

When input mode changes (GAMEPLAY → UI or vice versa), the buffer is cleared.
This prevents a buffered attack from firing when unpausing.

**B.6 — Buffer Priority**

If multiple bufferable actions are pressed in the same physics frame, priority
order: `dodge` > `attack` > `card_1` > `card_2` > `card_3` > `card_4` >
`interact`. Only the highest-priority action is buffered.

### Movement Input

**M.1 — 8-Directional Movement**

Movement is 8-directional. The input vector is constructed from the four
movement actions (WASD / left stick) and normalized to prevent diagonal speed
boost.

KB/M: Binary direction (0 or 1 per axis). Diagonal inputs produce a vector
like (1, 1) which is normalized to (0.707, 0.707).

Gamepad: Analog magnitude from left stick after dead zone processing. Direction
is quantized to 8 directions (N, NE, E, SE, S, SW, W, NW) for consistent
gameplay behavior, but magnitude is preserved for walk/run differentiation if
needed.

**M.2 — Facing Direction**

The player's facing direction is determined by:
- KB/M: Mouse position relative to player (aim direction)
- Gamepad: Right stick direction if deflected; otherwise movement direction;
  if stationary and stick at rest, last known facing

Facing direction is separate from movement direction. The player can move left
while facing right (strafing behavior).

### Aim System

**AIM.1 — KB/M Aim**

Mouse world position is the aim target. The aim angle is calculated from
player position to mouse world position using `atan2()`. For gameplay purposes,
aim is snapped to the nearest 8 directions (45-degree increments) to match
the pixel art animation set.

**AIM.2 — Gamepad Aim**

Right stick direction after dead zone processing is the aim direction. If the
right stick is at rest (inside dead zone), aim defaults to the current facing
direction.

**AIM.3 — Aim Cursor**

KB/M: No visible cursor during gameplay — aim is implied by mouse position.
Cursor is visible in UI mode.

Gamepad: A subtle aim indicator shows the current aim direction at a fixed
distance from the player. Always visible in GAMEPLAY mode when using gamepad.

### Key Remapping

**R.1 — Remapping Rules**

- All bindings are remappable from the settings menu
- Two actions cannot share the same binding (conflict detection)
- Movement actions (WASD) cannot be rebound to mouse buttons
- `pause` must always have a binding (cannot be unbound)
- Remappings are saved to user config and persist across sessions
- Reset to defaults option always available

## Formulas

**F.1 — Gamepad Dead Zone Remap**

Transforms raw stick magnitude to usable range, eliminating drift in the dead
zone and ensuring full range output.

```
Variables:
  raw       = raw stick magnitude (0.0 to 1.0)
  inner_dz  = inner dead zone threshold (default: 0.15)
  outer_dz  = outer dead zone threshold (default: 0.95)

Output:
  magnitude = remapped magnitude (0.0 to 1.0)

Formula:
  if raw < inner_dz:
      magnitude = 0.0
  elif raw > outer_dz:
      magnitude = 1.0
  else:
      magnitude = (raw - inner_dz) / (outer_dz - inner_dz)

Example:
  raw = 0.55, inner_dz = 0.15, outer_dz = 0.95
  magnitude = (0.55 - 0.15) / (0.95 - 0.15)
  magnitude = 0.40 / 0.80 = 0.50
```

Output range: 0.0 to 1.0 (clamped). Values below inner dead zone return
exactly 0.0 (no drift). Values above outer dead zone return exactly 1.0 (full
deflection is reachable without crushing the stick).

**F.2 — Movement Vector Normalization**

Prevents diagonal speed boost for keyboard input.

```
Variables:
  input_x = horizontal input (-1, 0, or 1 for KB; -1.0 to 1.0 for gamepad)
  input_y = vertical input (-1, 0, or 1 for KB; -1.0 to 1.0 for gamepad)

Output:
  move_dir = normalized direction vector (length <= 1.0)

Formula:
  raw_vector = Vector2(input_x, input_y)
  if raw_vector.length() > 1.0:
      move_dir = raw_vector.normalized()
  else:
      move_dir = raw_vector

Example (keyboard diagonal):
  input_x = 1, input_y = -1
  raw_vector = Vector2(1, -1), length = 1.414
  move_dir = Vector2(0.707, -0.707), length = 1.0

Example (gamepad partial):
  input_x = 0.3, input_y = 0.0
  raw_vector = Vector2(0.3, 0.0), length = 0.3
  move_dir = Vector2(0.3, 0.0)  # no normalization needed
```

**F.3 — Input Buffer Expiry**

Determines whether a buffered action is still valid.

```
Variables:
  buffer_frame   = physics frame when action was buffered
  current_frame  = current physics frame counter
  BUFFER_WINDOW  = max buffer duration in frames (default: 8)

Output:
  is_valid = boolean (true if buffer has not expired)

Formula:
  is_valid = (current_frame - buffer_frame) <= BUFFER_WINDOW

Example:
  buffer_frame = 142, current_frame = 148, BUFFER_WINDOW = 8
  148 - 142 = 6 <= 8 → is_valid = true

  buffer_frame = 142, current_frame = 152, BUFFER_WINDOW = 8
  152 - 142 = 10 > 8 → is_valid = false (expired, buffer cleared)
```

**F.4 — Aim Direction 8-Way Snap**

Converts continuous aim angle to nearest 8 directions for animation selection.

```
Variables:
  aim_angle = atan2(target_y - player_y, target_x - player_x)  (radians)
  SNAP_SIZE = PI / 4  (45 degrees in radians)

Output:
  snapped_index = integer 0-7 (N, NE, E, SE, S, SW, W, NW)
  snapped_angle = snapped_index * SNAP_SIZE

Formula:
  snapped_index = round(aim_angle / SNAP_SIZE) % 8
  snapped_angle = snapped_index * SNAP_SIZE

Example (mouse slightly above-right of player):
  aim_angle = 0.35 radians (~20 degrees)
  SNAP_SIZE = 0.785 radians
  snapped_index = round(0.35 / 0.785) % 8 = round(0.446) % 8 = 0
  snapped_angle = 0.0 radians (East / right)
```

## Edge Cases

- **Buffered card slot is empty**: Player presses `card_3` during recovery, but
  when the buffer fires, card slot 3 is empty (card was played by another input
  before buffer consumed). Buffer consumes successfully (returns true to input
  system), Card Hand System receives the action but treats it as a no-op. No
  error, no sound — the moment passed.

- **`card_4` pressed with 3-card hand**: If the current hand size is 3, `card_4`
  action is accepted by the Input System (it doesn't know hand size) but
  rejected by Card Hand System. Input System's job is translation, not validation.

- **Simultaneous KB/M and gamepad input in same frame**: Most recent device
  wins for `active_device`. For conflicting movement vectors, gamepad left
  stick is ignored if any WASD key is held (KB/M takes priority within the
  same frame). For conflicting actions, both are processed — buffer priority
  rules (B.6) resolve which is buffered.

- **Gamepad right stick at rest during combat**: Aim defaults to current facing
  direction (from movement or last known facing). Player can still attack and
  play cards — they aim in the direction they're facing.

- **Pause pressed during animation lock**: Pause always fires immediately
  regardless of player state. Game pauses. Buffer timer freezes. On unpause,
  buffer resumes with remaining time. No buffer expiry occurs during pause.

- **Rapid button mashing (same action pressed repeatedly)**: Each press
  overwrites the buffer with a fresh timestamp. The buffer always holds the
  most recent press. This prevents stale inputs from firing and ensures the
  player's latest intent is respected.

- **Input during SPAWNING state**: Input System accepts and buffers the action.
  The consuming system (Combat) rejects it because the entity is in SPAWNING
  state (per Entity Framework rules). Buffer may expire before SPAWNING ends —
  this is intentional. No pre-spawn action queuing.

- **Dodge pressed with no movement input (stationary)**: Dodge fires in the
  current facing direction. If no facing direction exists (impossible in
  practice — facing always has a value after first input), dodge fires to the
  right (default).

- **Alt-tab / window focus loss**: All held inputs are released. Buffer is
  cleared. Movement stops. On focus regain, fresh input state is read. No
  ghost inputs from held keys during focus loss.

- **Two bufferable actions pressed in exact same physics frame**: Priority
  order applies (B.6). Only the highest-priority action is buffered. Lower
  priority action is dropped. This is rare (requires sub-frame simultaneity)
  but deterministic.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | None | Root dependency | — |
| Downstream | Combat System | `consume_buffered_action("attack")`, `consume_buffered_action("dodge")`, `get_aim_direction()` | Hard |
| Downstream | Card Hand System | `consume_buffered_action("card_1..4")`, `get_aim_direction()` | Hard |
| Downstream | Movement (via Entity Framework) | `get_movement_vector()`, `get_facing_direction()` | Hard |
| Downstream | Camera System | `get_aim_direction()` for look-ahead | Soft |
| Downstream | All UI Systems | `input_device_changed` signal for button prompt swap | Soft |
| Downstream | Animation State Machine | Indirectly via Combat/Movement consuming buffered actions | Soft |

The Input System depends on nothing. It exposes these public methods:

```gdscript
# Movement (called every physics frame by movement logic)
func get_movement_vector() -> Vector2
func get_facing_direction() -> Vector2

# Aim (called by combat and card systems)
func get_aim_direction() -> Vector2
func get_aim_angle() -> float

# Buffer (called by consuming systems when they're ready to act)
func consume_buffered_action(action_name: StringName) -> bool

# State
func get_input_mode() -> InputMode  # GAMEPLAY or UI
func set_input_mode(mode: InputMode) -> void
func get_active_device() -> InputDevice  # KEYBOARD_MOUSE or GAMEPAD
```

Signals:
```gdscript
signal input_device_changed(device: InputDevice)
signal input_mode_changed(mode: InputMode)
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `BUFFER_WINDOW` | 8 frames (133ms @ 60fps) | 4–15 frames | How long a buffered action stays valid. Too low = inputs feel dropped. Too high = stale inputs fire unexpectedly. |
| `INNER_DEAD_ZONE` | 0.15 | 0.05–0.30 | Stick magnitude below this is treated as zero. Too low = stick drift. Too high = sluggish response. |
| `OUTER_DEAD_ZONE` | 0.95 | 0.85–1.00 | Stick magnitude above this is treated as 1.0. Too low = can't reach full speed. Too high = requires crushing the stick. |
| `AIM_SNAP_DIRECTIONS` | 8 | 4, 8, or 16 | Number of discrete aim directions. 4 = cardinal only. 8 = matches animation set. 16 = smoother but needs 16-dir sprites. |
| `DEVICE_SWITCH_THRESHOLD` | 0.5 | 0.1–0.8 | Minimum stick magnitude to trigger device switch from KB/M to gamepad. Prevents accidental switches from stick resting position drift. |
| `BUFFER_PRIORITY_DODGE` | 0 (highest) | — | Priority rank for dodge in same-frame conflicts. Lower = higher priority. |
| `BUFFER_PRIORITY_ATTACK` | 1 | — | Priority rank for attack. |

**Cross-system note**: `BUFFER_WINDOW` should be validated against Animation
State Machine recovery frame counts once that GDD is written. If the shortest
recovery animation is 6 frames, an 8-frame buffer gives a 2-frame grace window.

## Acceptance Criteria

1. **GIVEN** player presses W+D simultaneously, **WHEN** movement vector is
   read, **THEN** vector is normalized to length 1.0 (no diagonal speed boost).

2. **GIVEN** gamepad left stick at magnitude 0.10 with `INNER_DEAD_ZONE = 0.15`,
   **WHEN** movement vector is read, **THEN** magnitude is exactly 0.0.

3. **GIVEN** gamepad left stick at magnitude 0.55, **WHEN** dead zone remap
   applied, **THEN** output magnitude equals 0.50 (per formula F.1).

4. **GIVEN** player presses `attack` during animation lock, **WHEN** the lock
   ends within `BUFFER_WINDOW` frames, **THEN** attack fires immediately on
   the first available frame.

5. **GIVEN** player presses `attack` during animation lock, **WHEN** the lock
   persists beyond `BUFFER_WINDOW` frames, **THEN** buffered attack expires
   and does not fire.

6. **GIVEN** player presses `dodge` then `attack` during the same animation
   lock, **WHEN** buffer is checked, **THEN** attack is buffered (most recent
   wins, per B.1).

7. **GIVEN** player presses `dodge` and `attack` in the same physics frame,
   **WHEN** buffer is checked, **THEN** dodge is buffered (priority B.6).

8. **GIVEN** game is paused with a buffered action, **WHEN** pause duration
   exceeds `BUFFER_WINDOW`, **THEN** buffer timer is frozen during pause and
   the action is still valid on unpause.

9. **GIVEN** input mode is UI, **WHEN** player presses `attack`, **THEN**
   action is ignored (not buffered, not processed).

10. **GIVEN** input mode switches from GAMEPLAY to UI, **WHEN** buffer held
    an action, **THEN** buffer is cleared immediately.

11. **GIVEN** mouse is 20 degrees right of player center, **WHEN** aim snap
    applied with 8 directions, **THEN** snapped direction is East (0 degrees).

12. **GIVEN** gamepad right stick is inside dead zone during combat, **WHEN**
    aim direction is queried, **THEN** returns current facing direction.

13. **GIVEN** player switches from keyboard to gamepad mid-gameplay, **WHEN**
    gamepad stick exceeds `DEVICE_SWITCH_THRESHOLD`, **THEN**
    `input_device_changed` signal fires with `GAMEPAD`.

14. **GIVEN** window loses focus while W key is held, **WHEN** focus is lost,
    **THEN** movement stops immediately and buffer is cleared.

15. **GIVEN** `card_4` is pressed, **WHEN** hand only has 3 cards, **THEN**
    Input System buffers the action normally (validation is Card Hand's job).

16. **GIVEN** player presses `pause`, **WHEN** player is in animation lock,
    **THEN** pause fires immediately (not buffered, not blocked).
