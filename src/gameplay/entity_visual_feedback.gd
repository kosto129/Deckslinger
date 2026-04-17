## Provides visual feedback for entities: hit flash, death fade.
## Attach as child of any EntityBase with a ColorRect named "Sprite".
class_name EntityVisualFeedback
extends Node


var _entity: EntityBase
var _sprite: ColorRect
var _original_color: Color
var _flash_timer: int = 0

const FLASH_DURATION: int = 6
const DEATH_FADE_DURATION: float = 0.5


func _ready() -> void:
	_entity = get_parent() as EntityBase
	if _entity == null:
		return

	_sprite = _entity.get_node_or_null("Sprite") as ColorRect
	if _sprite:
		_original_color = _sprite.color

	# Connect to lifecycle for death handling
	_entity.lifecycle_state_changed.connect(_on_lifecycle_changed)

	# Connect to hurtbox for hit flash
	var hurtbox: HurtboxComponent = _entity.get_hurtbox()
	if hurtbox:
		hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(_delta: float) -> void:
	if _flash_timer > 0:
		_flash_timer -= 1
		if _flash_timer <= 0 and _sprite:
			_sprite.color = _original_color


func _on_hit_received(_hit_data: HitData) -> void:
	if _sprite:
		_sprite.color = Color.WHITE
		_flash_timer = FLASH_DURATION


func _on_lifecycle_changed(_old: Enums.LifecycleState, new_state: Enums.LifecycleState) -> void:
	if new_state == Enums.LifecycleState.DYING:
		_start_death_fade()


func _start_death_fade() -> void:
	if _entity == null:
		return

	var tween := _entity.create_tween()
	tween.tween_property(_entity, "modulate:a", 0.0, DEATH_FADE_DURATION)
	tween.tween_callback(_entity.despawn)
