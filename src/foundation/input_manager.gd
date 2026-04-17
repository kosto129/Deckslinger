## Manages input buffering, mode switching, and freeze support.
## Single-slot buffer with most-recent-wins replacement and frame-counted expiry.
## Source: GDD input-system.md, ADR-0005
class_name InputManager
extends Node


signal input_mode_changed(new_mode: Enums.InputMode)

## Buffer window in physics frames (default 8 = ~133ms at 60fps).
const BUFFER_WINDOW: int = 8

## Bufferable actions in priority order (lower index = higher priority).
const BUFFERABLE_ACTIONS: Array[StringName] = [
	&"dodge",
	&"attack",
	&"card_1",
	&"card_2",
	&"card_3",
	&"card_4",
	&"interact",
]

## Actions that are never buffered (held or immediate).
const NON_BUFFERABLE_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"pause",
	&"map",
	&"deck_view",
]

const INNER_DEAD_ZONE: float = 0.15
const OUTER_DEAD_ZONE: float = 0.95

const SNAP_DIRECTIONS: Array[Vector2] = [
	Vector2.RIGHT,                            # 0 = E
	Vector2(0.7071, -0.7071),                 # 1 = NE
	Vector2.UP,                               # 2 = N
	Vector2(-0.7071, -0.7071),                # 3 = NW
	Vector2.LEFT,                             # 4 = W
	Vector2(-0.7071, 0.7071),                 # 5 = SW
	Vector2.DOWN,                             # 6 = S
	Vector2(0.7071, 0.7071),                  # 7 = SE
]

var _buffered_action: StringName = &""
var _buffer_frame: int = 0
var _frame_counter: int = 0
var _frozen: bool = false
var _input_mode: Enums.InputMode = Enums.InputMode.GAMEPLAY
var _active_device: Enums.InputDevice = Enums.InputDevice.KEYBOARD_MOUSE
var _facing_direction: Vector2 = Vector2.RIGHT


func _physics_process(_delta: float) -> void:
	if not _frozen:
		_frame_counter += 1


func _unhandled_input(event: InputEvent) -> void:
	if _input_mode != Enums.InputMode.GAMEPLAY:
		return

	if not event.is_pressed() or event.is_echo():
		return

	for action_name in BUFFERABLE_ACTIONS:
		if event.is_action(action_name):
			_try_buffer_action(action_name)
			return


## Attempts to consume the buffered action. Returns true if a matching,
## non-expired action was buffered. Clears the buffer on consumption or expiry.
func consume_buffered_action(action_name: StringName) -> bool:
	if _buffered_action == &"":
		return false

	# Check expiry
	if (_frame_counter - _buffer_frame) > BUFFER_WINDOW:
		_buffered_action = &""
		return false

	if _buffered_action == action_name:
		_buffered_action = &""
		return true

	return false


## Switches between GAMEPLAY and UI input modes. Clears buffer on switch.
func set_input_mode(mode: Enums.InputMode) -> void:
	if _input_mode == mode:
		return
	_input_mode = mode
	_buffered_action = &""
	input_mode_changed.emit(mode)


func get_input_mode() -> Enums.InputMode:
	return _input_mode


## Sets the freeze state. When frozen, frame counter and buffer expiry pause.
func set_frozen(frozen: bool) -> void:
	_frozen = frozen


func is_frozen() -> bool:
	return _frozen


func get_frame_counter() -> int:
	return _frame_counter


func get_buffered_action() -> StringName:
	return _buffered_action


## Returns the normalized movement vector from WASD / left stick.
func get_movement_vector() -> Vector2:
	if _input_mode != Enums.InputMode.GAMEPLAY:
		return Vector2.ZERO

	var raw := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", 0.0)

	if _active_device == Enums.InputDevice.GAMEPAD:
		raw = _apply_dead_zone(raw)

	if raw.length() > 1.0:
		raw = raw.normalized()

	if raw.length() > 0.01:
		_facing_direction = raw.normalized()

	return raw


## Returns the aim direction as a normalized vector.
## KB/M: direction from player to mouse. Gamepad: right stick or facing fallback.
func get_aim_direction(player_world_pos: Vector2 = Vector2.ZERO) -> Vector2:
	if _active_device == Enums.InputDevice.KEYBOARD_MOUSE:
		var viewport := get_viewport()
		if viewport:
			var mouse_screen := viewport.get_mouse_position()
			var canvas_xform := viewport.get_canvas_transform()
			var mouse_world := canvas_xform.affine_inverse() * mouse_screen
			var dir := (mouse_world - player_world_pos)
			if dir.length() > 0.01:
				_facing_direction = dir.normalized()
				return _facing_direction
	else:
		var stick := Input.get_vector(&"aim_stick_x", &"aim_stick_x", &"aim_stick_y", &"aim_stick_y", 0.0)
		# Manual read for right stick axes
		var stick_x := Input.get_axis(&"aim_stick_x", &"aim_stick_x")
		var stick_y := Input.get_axis(&"aim_stick_y", &"aim_stick_y")
		stick = Vector2(stick_x, stick_y)
		stick = _apply_dead_zone(stick)
		if stick.length() > 0.01:
			_facing_direction = stick.normalized()
			return _facing_direction

	return _facing_direction


## Returns the last known non-zero facing direction.
func get_facing_direction() -> Vector2:
	return _facing_direction


## Returns the 8-way snapped aim direction index (0=E, 1=NE, 2=N, ... 7=SE).
func get_snapped_aim_index(aim_dir: Vector2 = Vector2.ZERO) -> int:
	if aim_dir.length() < 0.01:
		aim_dir = _facing_direction
	var angle := aim_dir.angle()
	var snap_size := PI / 4.0
	var index := int(round(angle / snap_size)) % 8
	if index < 0:
		index += 8
	return index


# -- Private --

func _try_buffer_action(action_name: StringName) -> void:
	# If buffer is empty or a new frame, just store it
	if _buffered_action == &"" or _buffer_frame != _frame_counter:
		_buffered_action = action_name
		_buffer_frame = _frame_counter
		return

	# Same frame: priority resolution (lower index = higher priority)
	var new_priority := BUFFERABLE_ACTIONS.find(action_name)
	var current_priority := BUFFERABLE_ACTIONS.find(_buffered_action)
	if new_priority < current_priority:
		_buffered_action = action_name
		_buffer_frame = _frame_counter


func _apply_dead_zone(stick: Vector2) -> Vector2:
	var raw: float = stick.length()
	if raw < INNER_DEAD_ZONE:
		return Vector2.ZERO
	elif raw > OUTER_DEAD_ZONE:
		return stick.normalized()
	var remapped: float = (raw - INNER_DEAD_ZONE) / (OUTER_DEAD_ZONE - INNER_DEAD_ZONE)
	return stick.normalized() * remapped
