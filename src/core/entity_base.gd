## Base class for all game entities.
## Owns identity (entity_type) and lifecycle state machine.
## All behavior is attached via typed child component nodes.
## Source: ADR-0001 (Entity Composition Pattern), GDD entity-framework.md
class_name EntityBase
extends Node2D


@export var entity_type: Enums.EntityType

signal lifecycle_state_changed(old_state: Enums.LifecycleState, new_state: Enums.LifecycleState)
signal despawned(entity: EntityBase)

var _lifecycle_state: Enums.LifecycleState = Enums.LifecycleState.INACTIVE

## Cached component references — null if the component is not present.
@onready var _health: HealthComponent = get_node_or_null("HealthComponent")
@onready var _hitbox: HitboxComponent = get_node_or_null("HitboxComponent")
@onready var _hurtbox: HurtboxComponent = get_node_or_null("HurtboxComponent")
@onready var _movement: MovementComponent = get_node_or_null("MovementComponent")
@onready var _animation: AnimationComponent = get_node_or_null("AnimationComponent")
@onready var _status_effects: StatusEffectComponent = get_node_or_null("StatusEffectComponent")
@onready var _faction: FactionComponent = get_node_or_null("FactionComponent")
@onready var _ai: AIBehaviorComponent = get_node_or_null("AIBehaviorComponent")


func get_lifecycle_state() -> Enums.LifecycleState:
	return _lifecycle_state


## Transitions from INACTIVE to SPAWNING.
func activate() -> void:
	if _lifecycle_state != Enums.LifecycleState.INACTIVE:
		push_error("EntityBase.activate(): invalid from state %s" % Enums.LifecycleState.keys()[_lifecycle_state])
		return
	_set_state(Enums.LifecycleState.SPAWNING)


## Called when spawn animation completes. Transitions SPAWNING to ACTIVE.
func spawn_complete() -> void:
	if _lifecycle_state != Enums.LifecycleState.SPAWNING:
		push_error("EntityBase.spawn_complete(): invalid from state %s" % Enums.LifecycleState.keys()[_lifecycle_state])
		return
	_set_state(Enums.LifecycleState.ACTIVE)


## Transitions ACTIVE or STUNNED to DYING.
func die() -> void:
	if _lifecycle_state != Enums.LifecycleState.ACTIVE and _lifecycle_state != Enums.LifecycleState.STUNNED:
		push_error("EntityBase.die(): invalid from state %s" % Enums.LifecycleState.keys()[_lifecycle_state])
		return
	_set_state(Enums.LifecycleState.DYING)


## Transitions DYING to DEAD. Emits despawned signal and frees the entity.
func despawn() -> void:
	if _lifecycle_state != Enums.LifecycleState.DYING:
		push_error("EntityBase.despawn(): invalid from state %s" % Enums.LifecycleState.keys()[_lifecycle_state])
		return
	_set_state(Enums.LifecycleState.DEAD)
	despawned.emit(self)
	queue_free()


## Applies or removes stun. ACTIVE <-> STUNNED transitions only.
func set_stunned(stunned: bool) -> void:
	if stunned:
		if _lifecycle_state != Enums.LifecycleState.ACTIVE:
			push_error("EntityBase.set_stunned(true): invalid from state %s" % Enums.LifecycleState.keys()[_lifecycle_state])
			return
		_set_state(Enums.LifecycleState.STUNNED)
	else:
		if _lifecycle_state != Enums.LifecycleState.STUNNED:
			push_error("EntityBase.set_stunned(false): invalid from state %s" % Enums.LifecycleState.keys()[_lifecycle_state])
			return
		_set_state(Enums.LifecycleState.ACTIVE)


# -- Component Getters (null-safe) --

func get_health() -> HealthComponent:
	return _health


func get_hitbox() -> HitboxComponent:
	return _hitbox


func get_hurtbox() -> HurtboxComponent:
	return _hurtbox


func get_movement() -> MovementComponent:
	return _movement


func get_animation() -> AnimationComponent:
	return _animation


func get_status_effects() -> StatusEffectComponent:
	return _status_effects


func get_faction() -> FactionComponent:
	return _faction


func get_ai() -> AIBehaviorComponent:
	return _ai


# -- Private --

func _set_state(new_state: Enums.LifecycleState) -> void:
	var old_state := _lifecycle_state
	_lifecycle_state = new_state
	lifecycle_state_changed.emit(old_state, new_state)
