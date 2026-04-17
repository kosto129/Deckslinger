# component_discovery_test.gd — Tests for component discovery and HealthComponent interface
# Validates EntityBase typed getters and HealthComponent take_damage/heal/signals.
extends GdUnitTestSuite


# -- Component Discovery Tests --

func test_get_health_returns_component_when_present() -> void:
	var entity := EntityBase.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	entity.add_child(health)
	add_child(entity)

	assert_that(entity.get_health()).is_not_null()
	assert_that(entity.get_health()).is_same(health)

	entity.queue_free()


func test_get_ai_returns_null_when_absent() -> void:
	var entity := EntityBase.new()
	add_child(entity)

	assert_that(entity.get_ai()).is_null()

	entity.queue_free()


func test_all_getters_null_for_bare_entity() -> void:
	var entity := EntityBase.new()
	add_child(entity)

	assert_that(entity.get_health()).is_null()
	assert_that(entity.get_hitbox()).is_null()
	assert_that(entity.get_hurtbox()).is_null()
	assert_that(entity.get_movement()).is_null()
	assert_that(entity.get_animation()).is_null()
	assert_that(entity.get_status_effects()).is_null()
	assert_that(entity.get_faction()).is_null()
	assert_that(entity.get_ai()).is_null()

	entity.queue_free()


# -- HealthComponent Tests --

func test_health_initial_hp_equals_max() -> void:
	var health := HealthComponent.new()
	health.max_hp = 50
	add_child(health)

	assert_that(health.get_current_hp()).is_equal(50)
	assert_that(health.get_max_hp()).is_equal(50)
	assert_that(health.is_alive()).is_true()

	health.queue_free()


func test_take_damage_reduces_hp() -> void:
	var health := HealthComponent.new()
	health.max_hp = 100
	add_child(health)

	var signal_log: Array[Array] = []
	health.health_changed.connect(func(old_hp: int, new_hp: int, source: Node) -> void:
		signal_log.append([old_hp, new_hp])
	)

	health.take_damage(30, null)

	assert_that(health.get_current_hp()).is_equal(70)
	assert_that(signal_log.size()).is_equal(1)
	assert_that(signal_log[0][0]).is_equal(100)
	assert_that(signal_log[0][1]).is_equal(70)

	health.queue_free()


func test_take_damage_floors_at_zero() -> void:
	var health := HealthComponent.new()
	health.max_hp = 10
	add_child(health)

	health.take_damage(999, null)

	assert_that(health.get_current_hp()).is_equal(0)
	assert_that(health.is_alive()).is_false()

	health.queue_free()


func test_take_damage_emits_died_signal() -> void:
	var health := HealthComponent.new()
	health.max_hp = 10
	add_child(health)

	var died_emitted := false
	health.died.connect(func(_entity: Node) -> void: died_emitted = true)

	health.take_damage(10, null)

	assert_that(died_emitted).is_true()

	health.queue_free()


func test_take_damage_ignored_when_dead() -> void:
	var health := HealthComponent.new()
	health.max_hp = 10
	add_child(health)

	health.take_damage(10, null)
	var signal_count := 0
	health.health_changed.connect(func(_o: int, _n: int, _s: Node) -> void: signal_count += 1)

	health.take_damage(5, null)

	assert_that(health.get_current_hp()).is_equal(0)
	assert_that(signal_count).is_equal(0)

	health.queue_free()


func test_heal_increases_hp() -> void:
	var health := HealthComponent.new()
	health.max_hp = 100
	add_child(health)

	health.take_damage(50, null)
	health.heal(20)

	assert_that(health.get_current_hp()).is_equal(70)

	health.queue_free()


func test_heal_capped_at_max() -> void:
	var health := HealthComponent.new()
	health.max_hp = 100
	add_child(health)

	health.take_damage(10, null)
	health.heal(999)

	assert_that(health.get_current_hp()).is_equal(100)

	health.queue_free()


func test_hp_fraction() -> void:
	var health := HealthComponent.new()
	health.max_hp = 200
	add_child(health)

	health.take_damage(100, null)

	assert_that(health.get_hp_fraction()).is_equal(0.5)

	health.queue_free()


# -- FactionComponent Tests --

func test_faction_hostility_player_vs_enemy() -> void:
	var player_faction := FactionComponent.new()
	player_faction.faction = FactionComponent.Faction.PLAYER
	var enemy_faction := FactionComponent.new()
	enemy_faction.faction = FactionComponent.Faction.ENEMY

	assert_that(player_faction.is_hostile_to(enemy_faction)).is_true()
	assert_that(enemy_faction.is_hostile_to(player_faction)).is_true()

	player_faction.free()
	enemy_faction.free()


func test_faction_neutral_not_hostile() -> void:
	var player_faction := FactionComponent.new()
	player_faction.faction = FactionComponent.Faction.PLAYER
	var neutral_faction := FactionComponent.new()
	neutral_faction.faction = FactionComponent.Faction.NEUTRAL

	assert_that(player_faction.is_hostile_to(neutral_faction)).is_false()

	player_faction.free()
	neutral_faction.free()
