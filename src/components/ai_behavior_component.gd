## Attachment point for enemy AI behavior trees or state machines.
## Full AI logic implemented in Enemy AI epic.
## Source: GDD entity-framework.md (C.2), ADR-0001
class_name AIBehaviorComponent
extends Node


var _target: Node = null
var _is_active: bool = false


func set_target(target: Node) -> void:
	_target = target


func get_target() -> Node:
	return _target


func is_active() -> bool:
	return _is_active


func set_active(active: bool) -> void:
	_is_active = active
