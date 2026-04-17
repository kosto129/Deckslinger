# input_buffer_test.gd — Unit tests for InputManager buffer logic
# Tests buffer storage, expiry, priority, mode switching, and freeze.
extends GdUnitTestSuite


var _input_mgr: InputManager


func before_test() -> void:
	_input_mgr = InputManager.new()
	add_child(_input_mgr)


func after_test() -> void:
	if is_instance_valid(_input_mgr):
		_input_mgr.queue_free()


# Helper: simulate buffering an action at a specific frame
func _buffer_action_at_frame(action: StringName, target_frame: int) -> void:
	# Advance frame counter to target
	while _input_mgr.get_frame_counter() < target_frame:
		_input_mgr._physics_process(0.0)
	# Directly set buffer state (bypasses _unhandled_input which needs real InputEvents)
	_input_mgr._buffered_action = action
	_input_mgr._buffer_frame = _input_mgr.get_frame_counter()


# -- TC-BUF-001: Buffer stores and returns action within window --

func test_consume_returns_true_within_window() -> void:
	_buffer_action_at_frame(&"attack", 100)

	# Advance 6 frames (within 8 frame window)
	for i in range(6):
		_input_mgr._physics_process(0.0)

	var result := _input_mgr.consume_buffered_action(&"attack")

	assert_that(result).is_true()
	assert_that(_input_mgr.get_buffered_action()).is_equal(&"")


# -- TC-BUF-002: Buffer expires after BUFFER_WINDOW frames --

func test_consume_returns_false_after_expiry() -> void:
	_buffer_action_at_frame(&"attack", 100)

	# Advance 9 frames (exceeds 8 frame window)
	for i in range(9):
		_input_mgr._physics_process(0.0)

	var result := _input_mgr.consume_buffered_action(&"attack")

	assert_that(result).is_false()
	assert_that(_input_mgr.get_buffered_action()).is_equal(&"")


# -- TC-BUF-003: Most-recent-wins replacement --

func test_most_recent_wins_replacement() -> void:
	_buffer_action_at_frame(&"dodge", 100)

	# Advance 3 frames and buffer a different action
	for i in range(3):
		_input_mgr._physics_process(0.0)
	_input_mgr._buffered_action = &"attack"
	_input_mgr._buffer_frame = _input_mgr.get_frame_counter()

	assert_that(_input_mgr.get_buffered_action()).is_equal(&"attack")


# -- TC-BUF-004: Priority resolves same-frame conflict --

func test_priority_dodge_beats_attack() -> void:
	# Buffer attack first
	_buffer_action_at_frame(&"attack", 200)

	# Same frame: try to buffer dodge (higher priority)
	_input_mgr._try_buffer_action(&"dodge")

	assert_that(_input_mgr.get_buffered_action()).is_equal(&"dodge")


func test_priority_lower_does_not_replace_higher() -> void:
	# Buffer dodge first
	_buffer_action_at_frame(&"dodge", 200)

	# Same frame: try to buffer interact (lower priority)
	_input_mgr._try_buffer_action(&"interact")

	assert_that(_input_mgr.get_buffered_action()).is_equal(&"dodge")


# -- TC-BUF-005: Mode switch clears buffer --

func test_mode_switch_clears_buffer() -> void:
	_buffer_action_at_frame(&"attack", 50)

	var signal_fired := false
	var received_mode: Enums.InputMode
	_input_mgr.input_mode_changed.connect(func(mode: Enums.InputMode) -> void:
		signal_fired = true
		received_mode = mode
	)

	_input_mgr.set_input_mode(Enums.InputMode.UI)

	assert_that(_input_mgr.get_buffered_action()).is_equal(&"")
	assert_that(signal_fired).is_true()
	assert_that(received_mode).is_equal(Enums.InputMode.UI)


func test_mode_switch_same_mode_no_signal() -> void:
	var signal_count := 0
	_input_mgr.input_mode_changed.connect(func(_m: Enums.InputMode) -> void: signal_count += 1)

	_input_mgr.set_input_mode(Enums.InputMode.GAMEPLAY)

	assert_that(signal_count).is_equal(0)


# -- TC-BUF-006: Buffer frozen during hit-stop --

func test_frame_counter_frozen() -> void:
	# Advance to frame 10
	for i in range(10):
		_input_mgr._physics_process(0.0)
	var frame_before := _input_mgr.get_frame_counter()

	_input_mgr.set_frozen(true)

	# 20 more physics frames while frozen
	for i in range(20):
		_input_mgr._physics_process(0.0)

	assert_that(_input_mgr.get_frame_counter()).is_equal(frame_before)


func test_buffered_action_survives_freeze() -> void:
	_buffer_action_at_frame(&"attack", 50)

	_input_mgr.set_frozen(true)
	for i in range(20):
		_input_mgr._physics_process(0.0)
	_input_mgr.set_frozen(false)

	# Only 1 real frame has passed since unfreeze
	_input_mgr._physics_process(0.0)

	var result := _input_mgr.consume_buffered_action(&"attack")
	assert_that(result).is_true()


# -- TC-BUF-007: Non-bufferable actions --

func test_consume_returns_false_when_empty() -> void:
	var result := _input_mgr.consume_buffered_action(&"attack")
	assert_that(result).is_false()


func test_consume_wrong_action_returns_false() -> void:
	_buffer_action_at_frame(&"dodge", 10)

	var result := _input_mgr.consume_buffered_action(&"attack")

	assert_that(result).is_false()
	# Buffer should still hold dodge
	assert_that(_input_mgr.get_buffered_action()).is_equal(&"dodge")


# -- Buffer window constant --

func test_buffer_window_is_eight() -> void:
	assert_that(InputManager.BUFFER_WINDOW).is_equal(8)


# -- Edge: consume at exact boundary --

func test_consume_at_exact_boundary_is_valid() -> void:
	_buffer_action_at_frame(&"attack", 100)

	# Advance exactly 8 frames (boundary)
	for i in range(8):
		_input_mgr._physics_process(0.0)

	var result := _input_mgr.consume_buffered_action(&"attack")
	assert_that(result).is_true()
