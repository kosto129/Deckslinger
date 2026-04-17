# card_registry_test.gd — Unit tests for CardRegistry lookup methods
# Tests use programmatic card creation since .tres files require the import pipeline.
extends GdUnitTestSuite


var _registry: CardRegistry


func _make_card(id: StringName, archetype: Enums.CardArchetype, rarity: Enums.CardRarity, card_type: Enums.CardType, tags: Array[StringName] = []) -> CardData:
	var card := CardData.new()
	card.card_id = id
	card.display_name = str(id)
	card.archetype = archetype
	card.rarity = rarity
	card.card_type = card_type
	card.tags = tags
	return card


func before_test() -> void:
	_registry = CardRegistry.new()
	add_child(_registry)

	# Manually populate the registry (bypass filesystem loading)
	var cards: Array[CardData] = [
		_make_card(&"quick_draw", Enums.CardArchetype.GUNSLINGER, Enums.CardRarity.COMMON, Enums.CardType.ATTACK, [&"starter", &"starter_gunslinger"]),
		_make_card(&"fan_fire", Enums.CardArchetype.GUNSLINGER, Enums.CardRarity.COMMON, Enums.CardType.ATTACK, [&"starter", &"starter_gunslinger"]),
		_make_card(&"reload", Enums.CardArchetype.GUNSLINGER, Enums.CardRarity.COMMON, Enums.CardType.SKILL, [&"starter", &"starter_gunslinger"]),
		_make_card(&"smoke_bomb", Enums.CardArchetype.DRIFTER, Enums.CardRarity.COMMON, Enums.CardType.SKILL),
		_make_card(&"blade_dance", Enums.CardArchetype.DRIFTER, Enums.CardRarity.RARE, Enums.CardType.ATTACK),
		_make_card(&"outlaw_shot", Enums.CardArchetype.OUTLAW, Enums.CardRarity.UNCOMMON, Enums.CardType.ATTACK),
		_make_card(&"neutral_block", Enums.CardArchetype.NEUTRAL, Enums.CardRarity.COMMON, Enums.CardType.SKILL),
		_make_card(&"power_surge", Enums.CardArchetype.GUNSLINGER, Enums.CardRarity.LEGENDARY, Enums.CardType.POWER),
	]

	for card in cards:
		_registry._cards[card.card_id] = card
		_registry._all_cards.append(card)


func after_test() -> void:
	if is_instance_valid(_registry):
		_registry.queue_free()


func test_get_card_returns_correct_resource() -> void:
	var card := _registry.get_card(&"quick_draw")

	assert_that(card).is_not_null()
	assert_that(card.card_id).is_equal(&"quick_draw")


func test_get_card_returns_null_for_unknown_id() -> void:
	var card := _registry.get_card(&"nonexistent")

	assert_that(card).is_null()


func test_get_cards_by_archetype_filters_correctly() -> void:
	var gunslinger_cards := _registry.get_cards_by_archetype(Enums.CardArchetype.GUNSLINGER)

	assert_that(gunslinger_cards.size()).is_equal(4)
	for card in gunslinger_cards:
		assert_that(card.archetype).is_equal(Enums.CardArchetype.GUNSLINGER)


func test_get_cards_by_rarity_filters_correctly() -> void:
	var rare_cards := _registry.get_cards_by_rarity(Enums.CardRarity.RARE)

	assert_that(rare_cards.size()).is_equal(1)
	assert_that(rare_cards[0].card_id).is_equal(&"blade_dance")


func test_get_cards_by_type_filters_correctly() -> void:
	var attack_cards := _registry.get_cards_by_type(Enums.CardType.ATTACK)

	assert_that(attack_cards.size()).is_equal(4)
	for card in attack_cards:
		assert_that(card.card_type).is_equal(Enums.CardType.ATTACK)


func test_get_all_cards_returns_full_set() -> void:
	var all_cards := _registry.get_all_cards()

	assert_that(all_cards.size()).is_equal(8)


func test_get_card_count() -> void:
	assert_that(_registry.get_card_count()).is_equal(8)


func test_get_starter_deck_by_tag() -> void:
	var starter := _registry.get_starter_deck(Enums.CardArchetype.GUNSLINGER)

	assert_that(starter.size()).is_equal(3)
	for card in starter:
		assert_that(card.tags.has(&"starter")).is_true()
		assert_that(card.tags.has(&"starter_gunslinger")).is_true()


func test_get_starter_deck_empty_for_untagged_archetype() -> void:
	var starter := _registry.get_starter_deck(Enums.CardArchetype.OUTLAW)

	assert_that(starter.size()).is_equal(0)


func test_get_cards_by_type_power() -> void:
	var power_cards := _registry.get_cards_by_type(Enums.CardType.POWER)

	assert_that(power_cards.size()).is_equal(1)
	assert_that(power_cards[0].card_id).is_equal(&"power_surge")
