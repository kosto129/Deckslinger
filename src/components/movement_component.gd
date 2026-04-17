## Tracks velocity, facing direction, and movement constraints for an entity.
## Full movement logic depends on Input System and Animation State Machine.
## Source: GDD entity-framework.md (C.2), ADR-0001
class_name MovementComponent
extends Node


signal facing_changed(new_facing: Vector2)

@export var move_speed: float = 100.0
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
