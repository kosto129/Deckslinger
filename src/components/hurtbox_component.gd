## Defines where this entity can be hit.
## Receives hits from HitboxComponent and emits hit_received signal.
## Source: GDD collision-hitbox-system.md, ADR-0008
class_name HurtboxComponent
extends Area2D


signal hit_received(hit_data: HitData)

var _invincible: bool = false


## Called by HitboxComponent when an overlap is detected.
func receive_hit(hit_data: HitData) -> void:
	if _invincible:
		return

	# Only process hits on ACTIVE or STUNNED entities
	var parent := get_parent()
	if parent is EntityBase:
		var entity: EntityBase = parent as EntityBase
		var state := entity.get_lifecycle_state()
		if state != Enums.LifecycleState.ACTIVE and state != Enums.LifecycleState.STUNNED:
			return

	hit_received.emit(hit_data)


## Sets invincibility (i-frames). Full implementation in story-003.
func set_invincible(invincible: bool) -> void:
	_invincible = invincible


func is_invincible() -> bool:
	return _invincible
