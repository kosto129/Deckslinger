# hit_detection_test.gd — Unit tests for HitboxComponent and HurtboxComponent
# Tests single-hit rule, HitData creation, and hurtbox signal emission.
extends GdUnitTestSuite


# -- HitData tests --

func test_hit_data_instantiates_with_defaults() -> void:
	var data := HitData.new()

	assert_that(data.damage).is_equal(0)
	assert_that(data.knockback_force).is_equal(0.0)
	assert_that(data.shake_intensity).is_equal(0.0)
	assert_that(data.status_effects.size()).is_equal(0)
	assert_that(data.source_entity).is_null()
	assert_that(data.target_entity).is_null()


func test_hit_data_fields_settable() -> void:
	var data := HitData.new()
	data.damage = 25
	data.knockback_force = 100.0
	data.shake_intensity = 3.0
	data.effect_source = &"quick_draw"
	data.crit_chance = 0.15
	data.status_effects = [&"burn"]

	assert_that(data.damage).is_equal(25)
	assert_that(data.knockback_force).is_equal(100.0)
	assert_that(data.effect_source).is_equal(&"quick_draw")
	assert_that(data.status_effects[0]).is_equal(&"burn")


# -- HitboxComponent tests --

func test_hitbox_starts_disabled() -> void:
	var hitbox := HitboxComponent.new()
	add_child(hitbox)

	assert_that(hitbox.is_active()).is_false()

	hitbox.queue_free()


func test_hitbox_enable_activates_monitoring() -> void:
	var hitbox := HitboxComponent.new()
	add_child(hitbox)

	hitbox.enable(HitData.new())

	assert_that(hitbox.is_active()).is_true()

	hitbox.queue_free()


func test_hitbox_disable_stops_monitoring() -> void:
	var hitbox := HitboxComponent.new()
	add_child(hitbox)

	hitbox.enable(HitData.new())
	hitbox.disable()

	assert_that(hitbox.is_active()).is_false()

	hitbox.queue_free()


func test_hitbox_clear_hit_targets() -> void:
	var hitbox := HitboxComponent.new()
	add_child(hitbox)

	# Simulate tracking
	hitbox._already_hit["fake_target"] = true
	assert_that(hitbox._already_hit.size()).is_equal(1)

	hitbox.clear_hit_targets()
	assert_that(hitbox._already_hit.size()).is_equal(0)

	hitbox.queue_free()


# -- HurtboxComponent tests --

func test_hurtbox_emits_hit_received() -> void:
	var hurtbox := HurtboxComponent.new()
	# Parent needs to be an active entity for the lifecycle check
	var entity := EntityBase.new()
	entity.add_child(hurtbox)
	add_child(entity)

	# Activate the entity so hits are accepted
	entity.activate()
	entity.spawn_complete()

	var received: Array[HitData] = []
	hurtbox.hit_received.connect(func(data: HitData) -> void: received.append(data))

	var hit := HitData.new()
	hit.damage = 10
	hurtbox.receive_hit(hit)

	assert_that(received.size()).is_equal(1)
	assert_that(received[0].damage).is_equal(10)

	entity.queue_free()


func test_hurtbox_rejects_hit_when_invincible() -> void:
	var hurtbox := HurtboxComponent.new()
	var entity := EntityBase.new()
	entity.add_child(hurtbox)
	add_child(entity)
	entity.activate()
	entity.spawn_complete()

	hurtbox.set_invincible(true)

	var received: Array[HitData] = []
	hurtbox.hit_received.connect(func(data: HitData) -> void: received.append(data))

	hurtbox.receive_hit(HitData.new())

	assert_that(received.size()).is_equal(0)

	entity.queue_free()


func test_hurtbox_rejects_hit_during_spawning() -> void:
	var hurtbox := HurtboxComponent.new()
	var entity := EntityBase.new()
	entity.add_child(hurtbox)
	add_child(entity)
	entity.activate()  # SPAWNING state

	var received: Array[HitData] = []
	hurtbox.hit_received.connect(func(data: HitData) -> void: received.append(data))

	hurtbox.receive_hit(HitData.new())

	assert_that(received.size()).is_equal(0)

	entity.queue_free()


func test_hurtbox_accepts_hit_during_stunned() -> void:
	var hurtbox := HurtboxComponent.new()
	var entity := EntityBase.new()
	entity.add_child(hurtbox)
	add_child(entity)
	entity.activate()
	entity.spawn_complete()
	entity.set_stunned(true)

	var received: Array[HitData] = []
	hurtbox.hit_received.connect(func(data: HitData) -> void: received.append(data))

	hurtbox.receive_hit(HitData.new())

	assert_that(received.size()).is_equal(1)

	entity.queue_free()
