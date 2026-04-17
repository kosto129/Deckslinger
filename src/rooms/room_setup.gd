## Activates all entity children when the room enters the scene tree.
## Wires hurtbox signals to the combat system.
## Attach to any room scene root.
class_name RoomSetup
extends Node2D


func _ready() -> void:
	# Activate all entities in this room
	for child in get_children():
		if child is EntityBase:
			var entity: EntityBase = child as EntityBase
			entity.activate()
			entity.spawn_complete()

			# Wire hurtbox to combat system
			var hurtbox: HurtboxComponent = entity.get_hurtbox()
			if hurtbox:
				var combat := get_node_or_null("/root/CombatSystem")
				if combat == null:
					# Try finding it as an autoload or in the tree
					combat = _find_combat_system()
				if combat and combat is CombatSystem:
					(combat as CombatSystem).connect_hurtbox(hurtbox)


func _find_combat_system() -> Node:
	# CombatSystem might be in the Main scene or as part of game setup
	return get_tree().get_first_node_in_group(&"combat_system")
