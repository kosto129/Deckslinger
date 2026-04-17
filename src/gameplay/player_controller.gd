## Reads input from InputManager and drives player entity movement + card play.
## Attached to the Player node in Main.tscn.
## Source: GDD input-system.md, card-hand-system.md
class_name PlayerController
extends Node


var _entity: EntityBase
var _movement: MovementComponent
var _animation: AnimationComponent
var _hitbox: HitboxComponent


func _ready() -> void:
	_entity = get_parent() as EntityBase
	if _entity:
		_movement = _entity.get_movement()
		_animation = _entity.get_animation()
		_hitbox = _entity.get_hitbox()


func _physics_process(_delta: float) -> void:
	if _entity == null:
		return

	var state := _entity.get_lifecycle_state()
	if state != Enums.LifecycleState.ACTIVE:
		return

	_handle_movement()
	_handle_card_input()
	_handle_attack()


func _handle_movement() -> void:
	if _movement == null:
		return

	# Don't move during action commitment
	if _animation and _animation.is_in_action():
		_movement.velocity = Vector2.ZERO
		return

	var move_dir := InputManager.get_movement_vector()
	_movement.velocity = move_dir * _movement.move_speed

	if _entity:
		_entity.position += _movement.velocity * get_physics_process_delta_time()

	if move_dir.length() > 0.01:
		_movement.facing = move_dir.normalized()

	if _animation:
		_animation.set_locomotion(move_dir.length() > 0.01)


func _handle_card_input() -> void:
	if _animation and _animation.is_in_action():
		return

	# Check card slot inputs (1-4)
	for i in range(4):
		var action := &"card_%d" % (i + 1)
		if InputManager.consume_buffered_action(action):
			_try_play_card(i)
			return


func _handle_attack() -> void:
	if _animation and _animation.is_in_action():
		return

	if InputManager.consume_buffered_action(&"attack"):
		# Basic attack — play a generic attack animation
		if _animation:
			_animation.play_action(&"basic_attack", 6, 3, 8)
		if _hitbox:
			var hit := HitData.new()
			hit.source_entity = _entity
			hit.damage = 10
			hit.shake_intensity = 1.0
			_hitbox.enable(hit)
			# Disable after active phase via signal
			if _animation:
				_animation.recovery_started.connect(
					func(_key: StringName) -> void: _hitbox.disable(),
					CONNECT_ONE_SHOT
				)


func _try_play_card(slot_index: int) -> void:
	# CardHandSystem is accessed via the scene tree (not autoload for now)
	var card_hand := _find_card_hand_system()
	if card_hand == null:
		return

	var card: CardData = card_hand.try_play_card(slot_index)
	if card == null:
		return

	# Play the card's action animation
	if _animation:
		_animation.play_action(
			card.animation_key,
			card.windup_frames,
			card.active_frames,
			card.recovery_frames
		)

	# Enable hitbox during active phase for attack cards
	if card.card_type == Enums.CardType.ATTACK and _hitbox:
		var hit := HitData.new()
		hit.source_entity = _entity
		hit.damage = int(card.effects[0].value) if card.effects.size() > 0 else 0
		hit.shake_intensity = card.shake_intensity
		hit.effect_source = card.card_id
		if _animation:
			_animation.active_started.connect(
				func(_key: StringName) -> void: _hitbox.enable(hit),
				CONNECT_ONE_SHOT
			)
			_animation.recovery_started.connect(
				func(_key: StringName) -> void: _hitbox.disable(),
				CONNECT_ONE_SHOT
			)


func _find_card_hand_system() -> CardHandSystem:
	var node := get_node_or_null("/root/Main/CardHandSystem")
	if node is CardHandSystem:
		return node as CardHandSystem
	return null
