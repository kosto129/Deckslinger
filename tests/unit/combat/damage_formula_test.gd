# damage_formula_test.gd — Example unit test for the damage pipeline
# Validates Combat System formula: final_damage = max(floor(base * vuln * resist * stun * crit), 1)
extends GdUnitTestSuite


func test_base_damage_no_modifiers() -> void:
	var base_damage: int = 15
	var vulnerability: float = 1.0
	var resistance: float = 1.0
	var stun_bonus: float = 1.0
	var crit_mult: float = 1.0

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(15)


func test_vulnerable_target_increases_damage() -> void:
	var base_damage: int = 15
	var vulnerability: float = 1.5
	var resistance: float = 1.0
	var stun_bonus: float = 1.0
	var crit_mult: float = 1.0

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(22)


func test_resistant_target_reduces_damage() -> void:
	var base_damage: int = 15
	var vulnerability: float = 1.0
	var resistance: float = 0.5
	var stun_bonus: float = 1.0
	var crit_mult: float = 1.0

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(7)


func test_stunned_target_bonus_damage() -> void:
	var base_damage: int = 15
	var vulnerability: float = 1.0
	var resistance: float = 1.0
	var stun_bonus: float = 1.25
	var crit_mult: float = 1.0

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(18)


func test_critical_hit_multiplier() -> void:
	var base_damage: int = 15
	var vulnerability: float = 1.0
	var resistance: float = 1.0
	var stun_bonus: float = 1.0
	var crit_mult: float = 1.5

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(22)


func test_all_modifiers_stacked() -> void:
	var base_damage: int = 15
	var vulnerability: float = 1.5
	var resistance: float = 1.0
	var stun_bonus: float = 1.25
	var crit_mult: float = 1.5

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(42)


func test_vulnerable_plus_resistant_net_reduction() -> void:
	var base_damage: int = 15
	var vulnerability: float = 1.5
	var resistance: float = 0.5
	var stun_bonus: float = 1.0
	var crit_mult: float = 1.0

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(11)


func test_minimum_damage_is_one() -> void:
	# Even with extreme resistance, damage floors at 1
	var base_damage: int = 1
	var vulnerability: float = 1.0
	var resistance: float = 0.5
	var stun_bonus: float = 1.0
	var crit_mult: float = 1.0

	var final_damage: int = maxi(floori(base_damage * vulnerability * resistance * stun_bonus * crit_mult), 1)

	assert_that(final_damage).is_equal(1)
