# entity_base_lifecycle_test.gd — Unit tests for EntityBase lifecycle state machine
# Validates all valid transitions, invalid transition rejection, and signal emissions.
extends GdUnitTestSuite


var _entity: EntityBase
var _signal_log: Array[Array]


func before_test() -> void:
	_entity = EntityBase.new()
	_signal_log = []
	_entity.lifecycle_state_changed.connect(_on_lifecycle_state_changed)
	add_child(_entity)


func after_test() -> void:
	if is_instance_valid(_entity):
		_entity.queue_free()


func _on_lifecycle_state_changed(old_state: Enums.LifecycleState, new_state: Enums.LifecycleState) -> void:
	_signal_log.append([old_state, new_state])


# -- activate() tests --

func test_activate_transitions_inactive_to_spawning() -> void:
	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.INACTIVE)

	_entity.activate()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.SPAWNING)


func test_activate_emits_lifecycle_signal() -> void:
	_entity.activate()

	assert_that(_signal_log.size()).is_equal(1)
	assert_that(_signal_log[0][0]).is_equal(Enums.LifecycleState.INACTIVE)
	assert_that(_signal_log[0][1]).is_equal(Enums.LifecycleState.SPAWNING)


func test_activate_rejected_when_already_active() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_signal_log.clear()

	_entity.activate()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.ACTIVE)
	assert_that(_signal_log.size()).is_equal(0)


# -- spawn_complete() tests --

func test_spawn_complete_transitions_spawning_to_active() -> void:
	_entity.activate()

	_entity.spawn_complete()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.ACTIVE)


func test_spawn_complete_rejected_when_inactive() -> void:
	_entity.spawn_complete()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.INACTIVE)
	assert_that(_signal_log.size()).is_equal(0)


# -- die() tests --

func test_die_transitions_active_to_dying() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_signal_log.clear()

	_entity.die()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.DYING)
	assert_that(_signal_log.size()).is_equal(1)
	assert_that(_signal_log[0][0]).is_equal(Enums.LifecycleState.ACTIVE)
	assert_that(_signal_log[0][1]).is_equal(Enums.LifecycleState.DYING)


func test_die_transitions_stunned_to_dying() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_entity.set_stunned(true)
	_signal_log.clear()

	_entity.die()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.DYING)


func test_die_rejected_when_inactive() -> void:
	_entity.die()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.INACTIVE)


func test_die_rejected_when_already_dying() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_entity.die()
	_signal_log.clear()

	_entity.die()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.DYING)
	assert_that(_signal_log.size()).is_equal(0)


# -- despawn() tests --

func test_despawn_transitions_dying_to_dead() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_entity.die()
	_signal_log.clear()

	var despawn_emitted := false
	_entity.despawned.connect(func(_e: EntityBase) -> void: despawn_emitted = true)

	_entity.despawn()

	assert_that(despawn_emitted).is_true()


func test_despawn_rejected_when_active() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_signal_log.clear()

	_entity.despawn()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.ACTIVE)
	assert_that(_signal_log.size()).is_equal(0)


# -- set_stunned() tests --

func test_set_stunned_true_transitions_active_to_stunned() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_signal_log.clear()

	_entity.set_stunned(true)

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.STUNNED)
	assert_that(_signal_log.size()).is_equal(1)
	assert_that(_signal_log[0][0]).is_equal(Enums.LifecycleState.ACTIVE)
	assert_that(_signal_log[0][1]).is_equal(Enums.LifecycleState.STUNNED)


func test_set_stunned_false_transitions_stunned_to_active() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_entity.set_stunned(true)
	_signal_log.clear()

	_entity.set_stunned(false)

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.ACTIVE)
	assert_that(_signal_log.size()).is_equal(1)


func test_set_stunned_true_rejected_when_not_active() -> void:
	_entity.set_stunned(true)

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.INACTIVE)


func test_set_stunned_false_rejected_when_not_stunned() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_signal_log.clear()

	_entity.set_stunned(false)

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.ACTIVE)
	assert_that(_signal_log.size()).is_equal(0)


# -- Full lifecycle test --

func test_full_lifecycle_inactive_to_dead() -> void:
	_entity.activate()
	_entity.spawn_complete()
	_entity.die()

	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.DYING)
	assert_that(_signal_log.size()).is_equal(3)


# -- Component getter tests --

func test_component_getters_return_null_when_no_children() -> void:
	assert_that(_entity.get_health()).is_null()
	assert_that(_entity.get_hitbox()).is_null()
	assert_that(_entity.get_hurtbox()).is_null()
	assert_that(_entity.get_movement()).is_null()
	assert_that(_entity.get_animation()).is_null()
	assert_that(_entity.get_status_effects()).is_null()
	assert_that(_entity.get_faction()).is_null()
	assert_that(_entity.get_ai()).is_null()


# -- Initial state test --

func test_initial_state_is_inactive() -> void:
	assert_that(_entity.get_lifecycle_state()).is_equal(Enums.LifecycleState.INACTIVE)
