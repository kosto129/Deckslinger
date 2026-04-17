# animation_state_machine_core_test.gd — Tests for AnimationComponent state machine
# Validates phase sequencing, frame counting, signal emissions, and edge cases.
extends GdUnitTestSuite


var _anim: AnimationComponent
var _signals: Dictionary  # StringName -> Array of emitted keys


func before_test() -> void:
	_anim = AnimationComponent.new()
	_signals = {}
	_anim.windup_started.connect(func(key: StringName) -> void:
		_signals[&"windup"] = _signals.get(&"windup", []) as Array
		_signals[&"windup"].append(key)
	)
	_anim.active_started.connect(func(key: StringName) -> void:
		_signals[&"active"] = _signals.get(&"active", []) as Array
		_signals[&"active"].append(key)
	)
	_anim.recovery_started.connect(func(key: StringName) -> void:
		_signals[&"recovery"] = _signals.get(&"recovery", []) as Array
		_signals[&"recovery"].append(key)
	)
	_anim.action_completed.connect(func(key: StringName) -> void:
		_signals[&"completed"] = _signals.get(&"completed", []) as Array
		_signals[&"completed"].append(key)
	)
	add_child(_anim)


func after_test() -> void:
	if is_instance_valid(_anim):
		_anim.queue_free()


func _tick(frames: int) -> void:
	for i in range(frames):
		_anim._physics_process(0.0)


# -- AC-1: Full phase sequence --

func test_play_action_full_sequence() -> void:
	_anim.play_action(&"quick_draw", 8, 3, 6)

	# Windup started immediately
	assert_that(_signals.get(&"windup", []).size()).is_equal(1)
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.WINDUP)

	# Tick 8 frames (windup)
	_tick(8)
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.ACTIVE)
	assert_that(_signals.get(&"active", []).size()).is_equal(1)

	# Tick 3 frames (active)
	_tick(3)
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.RECOVERY)
	assert_that(_signals.get(&"recovery", []).size()).is_equal(1)

	# Tick 6 frames (recovery)
	_tick(6)
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.IDLE)
	assert_that(_signals.get(&"completed", []).size()).is_equal(1)


func test_total_lock_frames_exact() -> void:
	_anim.play_action(&"test", 8, 3, 6)

	# Total = 17 frames
	_tick(16)
	assert_that(_anim.is_in_action()).is_true()

	_tick(1)
	assert_that(_anim.is_in_action()).is_false()


# -- AC-2: is_in_action during each phase --

func test_is_in_action_during_windup() -> void:
	_anim.play_action(&"test", 5, 5, 5)
	assert_that(_anim.is_in_action()).is_true()


func test_is_in_action_during_active() -> void:
	_anim.play_action(&"test", 5, 5, 5)
	_tick(5)
	assert_that(_anim.is_in_action()).is_true()


func test_is_in_action_during_recovery() -> void:
	_anim.play_action(&"test", 5, 5, 5)
	_tick(10)
	assert_that(_anim.is_in_action()).is_true()


func test_is_in_action_false_after_complete() -> void:
	_anim.play_action(&"test", 5, 5, 5)
	_tick(15)
	assert_that(_anim.is_in_action()).is_false()


# -- AC-3: Reject second play_action while in action --

func test_play_action_rejected_while_in_action() -> void:
	_anim.play_action(&"first", 10, 5, 5)
	_tick(3)

	_anim.play_action(&"second", 2, 2, 2)

	# Should still be in first action
	assert_that(_anim.get_current_action_key()).is_equal(&"first")
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.WINDUP)


# -- AC-4: Signal parameter correctness --

func test_all_signals_carry_correct_key() -> void:
	_anim.play_action(&"heavy_blow_e", 15, 4, 12)
	_tick(15 + 4 + 12)

	assert_that(_signals[&"windup"][0]).is_equal(&"heavy_blow_e")
	assert_that(_signals[&"active"][0]).is_equal(&"heavy_blow_e")
	assert_that(_signals[&"recovery"][0]).is_equal(&"heavy_blow_e")
	assert_that(_signals[&"completed"][0]).is_equal(&"heavy_blow_e")


# -- AC-5: Zero-frame edge case --

func test_zero_windup_skips_to_active() -> void:
	_anim.play_action(&"instant", 0, 1, 0)

	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.ACTIVE)
	assert_that(_signals.get(&"windup", []).size()).is_equal(1)
	assert_that(_signals.get(&"active", []).size()).is_equal(1)


func test_zero_windup_and_recovery() -> void:
	_anim.play_action(&"instant", 0, 1, 0)

	_tick(1)

	assert_that(_anim.is_in_action()).is_false()
	assert_that(_signals.get(&"completed", []).size()).is_equal(1)


# -- Hit-stop freezes timer --

func test_hitstop_pauses_phase_timer() -> void:
	_anim.play_action(&"test", 5, 3, 3)
	_tick(2)  # 2 frames into windup

	_anim.apply_hitstop(10)
	_tick(10)  # All frozen

	# Should still be in windup, 3 frames remaining
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.WINDUP)

	_tick(3)  # Finish remaining windup
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.ACTIVE)


# -- Initial state --

func test_initial_state_is_idle() -> void:
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.IDLE)
	assert_that(_anim.is_in_action()).is_false()


# -- Locomotion --

func test_set_locomotion_run() -> void:
	_anim.set_locomotion(true)
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.RUN)


func test_set_locomotion_idle() -> void:
	_anim.set_locomotion(true)
	_anim.set_locomotion(false)
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.IDLE)


func test_set_locomotion_rejected_during_action() -> void:
	_anim.play_action(&"test", 5, 5, 5)
	_anim.set_locomotion(true)
	assert_that(_anim.get_action_state()).is_equal(AnimationComponent.AnimState.WINDUP)
