## Tracks current and max HP for an entity.
## Exposes take_damage(), heal(), and emits signals on change/death.
## Source: GDD entity-framework.md (C.2), ADR-0001
class_name HealthComponent
extends Node


signal health_changed(old_hp: int, new_hp: int, source: Node)
signal died(entity: Node)

@export var max_hp: int = 100
var current_hp: int


func _ready() -> void:
	current_hp = max_hp


func take_damage(amount: int, source: Node) -> void:
	if current_hp <= 0:
		return
	var old_hp := current_hp
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(old_hp, current_hp, source)
	if current_hp <= 0:
		died.emit(get_parent())


func heal(amount: int) -> void:
	if current_hp <= 0:
		return
	var old_hp := current_hp
	current_hp = mini(current_hp + amount, max_hp)
	if current_hp != old_hp:
		health_changed.emit(old_hp, current_hp, null)


func get_current_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp


func get_hp_fraction() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func is_alive() -> bool:
	return current_hp > 0
