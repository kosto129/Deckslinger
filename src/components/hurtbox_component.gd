## Defines where this entity can be hit.
## Receives hits from HitboxComponent and routes them to CombatSystem.
## Source: GDD collision-hitbox-system.md, ADR-0008
class_name HurtboxComponent
extends Area2D


signal hit_received(hit_data: HitData)

var _invincible: bool = false


func _ready() -> void:
	call_deferred("_auto_connect_combat")


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


## Sets invincibility (i-frames).
func set_invincible(invincible: bool) -> void:
	_invincible = invincible


func is_invincible() -> bool:
	return _invincible


func _auto_connect_combat() -> void:
	var combat := get_node_or_null("/root/Main/CombatSystem")
	if combat and combat is CombatSystem:
		if not hit_received.is_connected((combat as CombatSystem).process_hit):
			hit_received.connect((combat as CombatSystem).process_hit)
