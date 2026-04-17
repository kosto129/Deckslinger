## Frame-counting animation state machine for committal combat.
## Actions lock the entity for exact physics frame counts: WINDUP → ACTIVE → RECOVERY.
## Source: GDD animation-state-machine.md, ADR-0007
class_name AnimationComponent
extends Node


enum AnimState { IDLE, RUN, WINDUP, ACTIVE, RECOVERY, HIT_REACT, STUNNED, DYING, SPAWNING }

signal windup_started(animation_key: StringName)
signal active_started(animation_key: StringName)
signal recovery_started(animation_key: StringName)
signal action_completed(animation_key: StringName)

var _state: AnimState = AnimState.IDLE
var _phase_timer: int = 0
var _current_action_key: StringName = &""
var _windup_frames: int = 0
var _active_frames: int = 0
var _recovery_frames: int = 0
var _hitstop_remaining: int = 0


func _physics_process(_delta: float) -> void:
	if _hitstop_remaining > 0:
		_hitstop_remaining -= 1
		return

	if _phase_timer > 0:
		_phase_timer -= 1
		if _phase_timer <= 0:
			_advance_phase()


## Begins a 3-phase action: WINDUP → ACTIVE → RECOVERY.
## Rejected if already in an action. Caller should check is_in_action() first.
func play_action(key: StringName, windup: int, active: int, recovery: int) -> void:
	if is_in_action():
		return

	_current_action_key = key
	_windup_frames = windup
	_active_frames = active
	_recovery_frames = recovery

	if windup > 0:
		_state = AnimState.WINDUP
		_phase_timer = windup
		windup_started.emit(key)
	elif active > 0:
		_state = AnimState.ACTIVE
		_phase_timer = active
		windup_started.emit(key)
		active_started.emit(key)
	else:
		_state = AnimState.RECOVERY
		_phase_timer = maxi(recovery, 1)
		windup_started.emit(key)
		active_started.emit(key)
		recovery_started.emit(key)


## Returns true during WINDUP, ACTIVE, or RECOVERY phases.
func is_in_action() -> bool:
	return _state == AnimState.WINDUP or _state == AnimState.ACTIVE or _state == AnimState.RECOVERY


## Returns the current animation state.
func get_action_state() -> AnimState:
	return _state


## Returns the key of the current action, or empty if idle.
func get_current_action_key() -> StringName:
	return _current_action_key


## Applies hit-stop freeze for the given number of physics frames.
func apply_hitstop(frames: int) -> void:
	_hitstop_remaining = maxi(_hitstop_remaining, frames)


## Sets the animation state directly (for non-action states like STUNNED, DYING).
func set_state(new_state: AnimState) -> void:
	if is_in_action():
		return
	_state = new_state


## Sets the locomotion state (IDLE or RUN) when not in an action.
func set_locomotion(moving: bool) -> void:
	if is_in_action():
		return
	_state = AnimState.RUN if moving else AnimState.IDLE


# -- Private --

func _advance_phase() -> void:
	match _state:
		AnimState.WINDUP:
			if _active_frames > 0:
				_state = AnimState.ACTIVE
				_phase_timer = _active_frames
				active_started.emit(_current_action_key)
			elif _recovery_frames > 0:
				_state = AnimState.RECOVERY
				_phase_timer = _recovery_frames
				active_started.emit(_current_action_key)
				recovery_started.emit(_current_action_key)
			else:
				_finish_action()

		AnimState.ACTIVE:
			if _recovery_frames > 0:
				_state = AnimState.RECOVERY
				_phase_timer = _recovery_frames
				recovery_started.emit(_current_action_key)
			else:
				_finish_action()

		AnimState.RECOVERY:
			_finish_action()


func _finish_action() -> void:
	var key := _current_action_key
	_state = AnimState.IDLE
	_phase_timer = 0
	_current_action_key = &""
	action_completed.emit(key)
