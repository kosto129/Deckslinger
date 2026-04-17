# deck_and_hand_test.gd — Unit tests for CardHandSystem
# Tests deck init, hand dealing, card play, draw cycle, and end encounter.
extends GdUnitTestSuite


var _hand_system: CardHandSystem
var _registry: CardRegistry


func _make_test_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for i in range(8):
		var card := CardData.new()
		card.card_id = &"card_%d" % i
		card.display_name = "Card %d" % i
		cards.append(card)
	return cards


func before_test() -> void:
	# Set up a mock registry
	_registry = CardRegistry.new()
	_registry.name = "CardRegistry"
	add_child(_registry)

	var cards := _make_test_cards()
	for card in cards:
		_registry._cards[card.card_id] = card
		_registry._all_cards.append(card)

	_hand_system = CardHandSystem.new()
	add_child(_hand_system)


func after_test() -> void:
	for child in get_children():
		child.queue_free()


func _get_deck_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for i in range(8):
		ids.append(&"card_%d" % i)
	return ids


# -- AC-1: Correct distribution --

func test_start_encounter_deals_four_cards() -> void:
	var hand_ready_emitted := false
	_hand_system.hand_ready.connect(func() -> void: hand_ready_emitted = true)

	_hand_system.start_encounter(_get_deck_ids(), 42)

	var non_null_count := 0
	for i in range(CardHandSystem.HAND_SIZE):
		if _hand_system.get_card_at_slot(i) != null:
			non_null_count += 1

	assert_that(non_null_count).is_equal(4)
	assert_that(_hand_system.get_draw_pile_count()).is_equal(4)
	assert_that(_hand_system.get_discard_pile_count()).is_equal(0)
	assert_that(hand_ready_emitted).is_true()


# -- AC-2: Seeded RNG reproducibility --

func test_same_seed_same_order() -> void:
	_hand_system.start_encounter(_get_deck_ids(), 12345)
	var first_hand: Array[StringName] = []
	for i in range(CardHandSystem.HAND_SIZE):
		var card := _hand_system.get_card_at_slot(i)
		first_hand.append(card.card_id if card else &"")

	_hand_system.end_encounter()
	_hand_system.start_encounter(_get_deck_ids(), 12345)
	var second_hand: Array[StringName] = []
	for i in range(CardHandSystem.HAND_SIZE):
		var card := _hand_system.get_card_at_slot(i)
		second_hand.append(card.card_id if card else &"")

	assert_that(first_hand).is_equal(second_hand)


# -- AC-4: end_encounter returns all cards --

func test_end_encounter_returns_all_card_ids() -> void:
	_hand_system.start_encounter(_get_deck_ids(), 42)

	var hand_cleared := false
	_hand_system.hand_cleared.connect(func() -> void: hand_cleared = true)

	var returned := _hand_system.end_encounter()

	assert_that(returned.size()).is_equal(8)
	assert_that(hand_cleared).is_true()


# -- AC-5: Unknown card ID --

func test_unknown_card_id_skipped() -> void:
	var deck: Array[StringName] = [&"card_0", &"nonexistent", &"card_1", &"card_2", &"card_3"]
	_hand_system.start_encounter(deck, 42)

	# 4 valid cards, 1 invalid = 4 total resolved
	var total := 0
	for i in range(CardHandSystem.HAND_SIZE):
		if _hand_system.get_card_at_slot(i) != null:
			total += 1
	total += _hand_system.get_draw_pile_count()

	assert_that(total).is_equal(4)


# -- AC-6: Deck smaller than HAND_SIZE --

func test_small_deck_partial_hand() -> void:
	var deck: Array[StringName] = [&"card_0", &"card_1", &"card_2"]
	_hand_system.start_encounter(deck, 42)

	var non_null := 0
	for i in range(CardHandSystem.HAND_SIZE):
		if _hand_system.get_card_at_slot(i) != null:
			non_null += 1

	assert_that(non_null).is_equal(3)
	assert_that(_hand_system.get_card_at_slot(3)).is_null()
	assert_that(_hand_system.get_draw_pile_count()).is_equal(0)


# -- Card play --

func test_try_play_card_removes_from_hand() -> void:
	_hand_system.start_encounter(_get_deck_ids(), 42)

	var played_card := _hand_system.try_play_card(0)

	assert_that(played_card).is_not_null()
	assert_that(_hand_system.get_card_at_slot(0)).is_null()
	assert_that(_hand_system.get_discard_pile_count()).is_equal(1)


func test_try_play_empty_slot_rejected() -> void:
	_hand_system.start_encounter(_get_deck_ids(), 42)
	_hand_system.try_play_card(0)  # Empty slot 0

	var rejected := false
	_hand_system.card_play_rejected.connect(func(_s: int, _r: StringName) -> void: rejected = true)

	var result := _hand_system.try_play_card(0)

	assert_that(result).is_null()
	assert_that(rejected).is_true()


func test_try_play_invalid_slot_rejected() -> void:
	_hand_system.start_encounter(_get_deck_ids(), 42)

	var result := _hand_system.try_play_card(99)

	assert_that(result).is_null()


# -- HAND_SIZE constant --

func test_hand_size_is_four() -> void:
	assert_that(CardHandSystem.HAND_SIZE).is_equal(4)
