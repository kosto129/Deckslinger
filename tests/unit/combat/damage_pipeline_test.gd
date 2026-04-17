# damage_pipeline_test.gd — Unit tests for CombatSystem damage pipeline
# Tests modifier chain, minimum damage, death guard, crit, and stun bonus.
extends GdUnitTestSuite


var _combat: CombatSystem
var _signal_log: Array[Dictionary]


func _make_entity(max_hp: int, stunned: bool = false) -> EntityBase:
	var entity := EntityBase.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = max_hp
	entity.add_child(health)
	add_child(entity)
	entity.activate()
	entity.spawn_complete()
	if stunned:
		entity.set_stunned(true)
	return entity


func _make_hit(damage: int, source: EntityBase, target: EntityBase, crit_chance: float = 0.0) -> HitData:
	var hit := HitData.new()
	hit.damage = damage
	hit.source_entity = source
	hit.target_entity = target
	hit.crit_chance = crit_chance
	hit.shake_intensity = 0.0
	return hit


func before_test() -> void:
	_combat = CombatSystem.new()
	_signal_log = []
	_combat.damage_dealt.connect(func(source: EntityBase, target: EntityBase, amount: int, is_crit: bool) -> void:
		_signal_log.append({"source": source, "target": target, "amount": amount, "is_crit": is_crit})
	)
	add_child(_combat)


func after_test() -> void:
	# Clean up all children
	for child in get_children():
		child.queue_free()


# -- AC-1: No modifiers --

func test_no_modifiers_exact_damage() -> void:
	var attacker := _make_entity(100)
	var target := _make_entity(100)

	var hit := _make_hit(15, attacker, target)
	_combat.process_hit(hit)

	assert_that(target.get_health().get_current_hp()).is_equal(85)
	assert_that(_signal_log.size()).is_equal(1)
	assert_that(_signal_log[0]["amount"]).is_equal(15)
	assert_that(_signal_log[0]["is_crit"]).is_false()


# -- AC-3: Stunned target --

func test_stunned_target_bonus_damage() -> void:
	var attacker := _make_entity(100)
	var target := _make_entity(100, true)  # STUNNED

	var hit := _make_hit(15, attacker, target)
	_combat.process_hit(hit)

	# floor(15 * 1.25) = 18
	assert_that(target.get_health().get_current_hp()).is_equal(82)
	assert_that(_signal_log[0]["amount"]).is_equal(18)


# -- AC-5: Minimum damage --

func test_minimum_damage_is_one() -> void:
	var attacker := _make_entity(100)
	var target := _make_entity(100)

	# 1 base damage with no modifiers = 1
	var hit := _make_hit(1, attacker, target)
	_combat.process_hit(hit)

	assert_that(target.get_health().get_current_hp()).is_equal(99)
	assert_that(_signal_log[0]["amount"]).is_equal(1)


# -- AC-6: Dead target guard --

func test_dead_target_ignored() -> void:
	var attacker := _make_entity(100)
	var target := _make_entity(10)

	# Kill the target first
	target.get_health().take_damage(10, attacker)
	target.die()

	var hit := _make_hit(15, attacker, target)
	_combat.process_hit(hit)

	assert_that(_signal_log.size()).is_equal(0)


# -- AC-7: Guaranteed crit --

func test_guaranteed_crit() -> void:
	var attacker := _make_entity(100)
	var target := _make_entity(100)

	var hit := _make_hit(10, attacker, target, 1.0)  # 100% crit
	_combat.process_hit(hit)

	# floor(10 * 1.5) = 15
	assert_that(target.get_health().get_current_hp()).is_equal(85)
	assert_that(_signal_log[0]["amount"]).is_equal(15)
	assert_that(_signal_log[0]["is_crit"]).is_true()


# -- Zero crit chance --

func test_zero_crit_chance_never_crits() -> void:
	var attacker := _make_entity(100)
	var target := _make_entity(100)

	var hit := _make_hit(10, attacker, target, 0.0)
	_combat.process_hit(hit)

	assert_that(target.get_health().get_current_hp()).is_equal(90)
	assert_that(_signal_log[0]["is_crit"]).is_false()


# -- Entity killed signal --

func test_entity_killed_signal() -> void:
	var attacker := _make_entity(100)
	var target := _make_entity(10)

	var killed_log: Array[EntityBase] = []
	_combat.entity_killed.connect(func(entity: EntityBase, _killer: EntityBase) -> void:
		killed_log.append(entity)
	)

	var hit := _make_hit(10, attacker, target)
	_combat.process_hit(hit)

	assert_that(killed_log.size()).is_equal(1)
	assert_that(target.get_lifecycle_state()).is_equal(Enums.LifecycleState.DYING)


# -- No HealthComponent guard --

func test_no_health_component_no_crash() -> void:
	var attacker := _make_entity(100)
	var target := EntityBase.new()
	add_child(target)
	target.activate()
	target.spawn_complete()

	var hit := _make_hit(10, attacker, target)
	_combat.process_hit(hit)

	assert_that(_signal_log.size()).is_equal(0)
