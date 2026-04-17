## Hosts active status effects on an entity. Ticked each physics frame.
## Full effect logic implemented in Status Effect System epic.
## Source: GDD entity-framework.md (C.2), ADR-0001
class_name StatusEffectComponent
extends Node


signal effect_applied(effect_id: StringName)
signal effect_removed(effect_id: StringName)

var _active_effects: Dictionary = {}


func apply_effect(effect_id: StringName, effect: RefCounted) -> void:
	_active_effects[effect_id] = effect
	effect_applied.emit(effect_id)


func remove_effect(effect_id: StringName) -> void:
	if _active_effects.has(effect_id):
		_active_effects.erase(effect_id)
		effect_removed.emit(effect_id)


func has_effect(effect_id: StringName) -> bool:
	return _active_effects.has(effect_id)


func get_active_effects() -> Dictionary:
	return _active_effects


## Returns the combined damage taken multiplier from all active effects.
## Stub: returns 1.0 until Status Effect System epic implements real modifiers.
func get_damage_taken_multiplier() -> float:
	return 1.0
