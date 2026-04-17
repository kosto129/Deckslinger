## Activates all entity children when the room enters the scene tree.
## Attach to any room scene root node.
class_name RoomSetup
extends Node2D


func _ready() -> void:
	# Deferred so all children are fully in the tree
	call_deferred("_activate_entities")


func _activate_entities() -> void:
	for child in get_children():
		if child is EntityBase:
			var entity: EntityBase = child as EntityBase
			if entity.get_lifecycle_state() == Enums.LifecycleState.INACTIVE:
				entity.activate()
				entity.spawn_complete()
