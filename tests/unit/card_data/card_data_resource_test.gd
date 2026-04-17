# card_data_resource_test.gd — Unit tests for CardData and CardEffect Resource classes
# Validates instantiation, field defaults, nested effects, and type integrity.
extends GdUnitTestSuite


func test_card_data_instantiates_with_defaults() -> void:
	var card := CardData.new()

	assert_that(card.card_id).is_equal(&"")
	assert_that(card.rarity).is_equal(Enums.CardRarity.COMMON)
	assert_that(card.effects.size()).is_equal(0)
	assert_that(card.cooldown_frames).is_equal(0)
	assert_that(card.upgraded).is_false()
	assert_that(card.card_type).is_equal(Enums.CardType.ATTACK)
	assert_that(card.archetype).is_equal(Enums.CardArchetype.NEUTRAL)


func test_card_effect_instantiates_with_defaults() -> void:
	var effect := CardEffect.new()

	assert_that(effect.value).is_equal(0.0)
	assert_that(effect.secondary_value).is_equal(0.0)
	assert_that(effect.conditions.size()).is_equal(0)
	assert_that(effect.effect_type).is_equal(Enums.EffectType.DAMAGE)
	assert_that(effect.target_override).is_equal(Enums.TargetingMode.NONE)


func test_card_data_accepts_array_of_card_effects() -> void:
	var card := CardData.new()
	var effect_1 := CardEffect.new()
	effect_1.effect_type = Enums.EffectType.DAMAGE
	effect_1.value = 10.0
	var effect_2 := CardEffect.new()
	effect_2.effect_type = Enums.EffectType.HEAL
	effect_2.value = 5.0
	var effect_3 := CardEffect.new()
	effect_3.effect_type = Enums.EffectType.APPLY_STATUS
	effect_3.status_effect_id = &"burn"

	card.effects = [effect_1, effect_2, effect_3]

	assert_that(card.effects.size()).is_equal(3)


func test_nested_card_effect_accessible_by_index() -> void:
	var card := CardData.new()
	var effect := CardEffect.new()
	effect.effect_type = Enums.EffectType.SPAWN_PROJECTILE
	effect.value = 25.0
	card.effects = [CardEffect.new(), CardEffect.new(), effect]

	assert_that(card.effects[2].effect_type).is_equal(Enums.EffectType.SPAWN_PROJECTILE)
	assert_that(card.effects[2].value).is_equal(25.0)


func test_card_data_tags_stores_string_name_array() -> void:
	var card := CardData.new()
	card.tags = [&"fire", &"movement"]

	assert_that(card.tags[0]).is_equal(&"fire")
	assert_that(card.tags[1]).is_equal(&"movement")
	assert_that(card.tags.size()).is_equal(2)


func test_effect_condition_instantiates_without_error() -> void:
	var condition := EffectCondition.new()

	assert_that(condition.condition_type).is_equal(EffectCondition.ConditionType.HP_BELOW_PERCENT)
	assert_that(condition.threshold).is_equal(0.0)
	assert_that(condition.status_id).is_equal(&"")


func test_card_data_with_zero_effects_is_legal() -> void:
	var card := CardData.new()
	card.card_id = &"empty_card"
	card.effects = []

	assert_that(card.effects.is_empty()).is_true()
	assert_that(card.card_id).is_equal(&"empty_card")


func test_card_data_all_fields_settable() -> void:
	var card := CardData.new()
	card.card_id = &"test_slash"
	card.display_name = "Test Slash"
	card.description = "Deal {damage} damage"
	card.card_type = Enums.CardType.SKILL
	card.archetype = Enums.CardArchetype.GUNSLINGER
	card.rarity = Enums.CardRarity.RARE
	card.targeting = Enums.TargetingMode.AIMED
	card.cooldown_frames = 60
	card.animation_key = &"slash"
	card.windup_frames = 6
	card.active_frames = 3
	card.recovery_frames = 12
	card.shake_intensity = 2.5
	card.upgraded = true
	card.upgrade_card_id = &"test_slash_plus"
	card.tooltip_extra = "Extra info"

	assert_that(card.card_id).is_equal(&"test_slash")
	assert_that(card.card_type).is_equal(Enums.CardType.SKILL)
	assert_that(card.archetype).is_equal(Enums.CardArchetype.GUNSLINGER)
	assert_that(card.rarity).is_equal(Enums.CardRarity.RARE)
	assert_that(card.windup_frames).is_equal(6)
	assert_that(card.shake_intensity).is_equal(2.5)
	assert_that(card.upgraded).is_true()


func test_card_effect_with_conditions() -> void:
	var effect := CardEffect.new()
	var cond := EffectCondition.new()
	cond.condition_type = EffectCondition.ConditionType.HP_BELOW_PERCENT
	cond.threshold = 0.5
	effect.conditions = [cond]

	assert_that(effect.conditions.size()).is_equal(1)
	assert_that(effect.conditions[0].threshold).is_equal(0.5)
