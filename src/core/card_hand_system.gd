## Manages the player's card hand, draw pile, and discard pile during encounters.
## Implements the use-to-draw cycle: play a card → discard → draw replacement.
## Source: GDD card-hand-system.md, ADR-0004, ADR-0009
class_name CardHandSystem
extends Node


const HAND_SIZE: int = 4
const DRAW_DELAY_FRAMES: int = 6
const RESHUFFLE_DELAY_FRAMES: int = 0

signal hand_ready()
signal hand_cleared()
signal card_played(card_data: CardData, slot_index: int)
signal card_drawn(card_data: CardData, slot_index: int)
signal card_play_rejected(slot_index: int, reason: StringName)
signal draw_pile_reshuffled()

var _hand_slots: Array[CardData] = []
var _draw_pile: Array[CardData] = []
var _discard_pile: Array[CardData] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _slot_cooldowns: Array[int] = []  # Per-slot frame cooldowns


func _ready() -> void:
	_hand_slots.resize(HAND_SIZE)
	_hand_slots.fill(null)
	_slot_cooldowns.resize(HAND_SIZE)
	_slot_cooldowns.fill(0)


func _physics_process(_delta: float) -> void:
	# Tick per-slot cooldowns
	for i in range(HAND_SIZE):
		if _slot_cooldowns[i] > 0:
			_slot_cooldowns[i] -= 1
			if _slot_cooldowns[i] <= 0 and _hand_slots[i] == null:
				_draw_to_slot(i)


## Initializes the encounter: resolves deck, shuffles, deals opening hand.
func start_encounter(deck: Array[StringName], rng_seed: int) -> void:
	_rng.seed = rng_seed
	_hand_slots.resize(HAND_SIZE)
	_hand_slots.fill(null)
	_draw_pile.clear()
	_discard_pile.clear()
	_slot_cooldowns.resize(HAND_SIZE)
	_slot_cooldowns.fill(0)

	# Resolve card IDs to CardData
	var resolved: Array[CardData] = []
	for card_id in deck:
		var card: CardData = CardRegistry.get_card(card_id)
		if card == null:
			push_error("CardHandSystem: card ID '%s' not found in registry" % card_id)
			continue
		resolved.append(card)

	# Shuffle into draw pile
	_draw_pile = resolved.duplicate()
	_shuffle_array(_draw_pile)

	# Deal opening hand
	for i in range(HAND_SIZE):
		if _draw_pile.is_empty():
			break
		_hand_slots[i] = _draw_pile.pop_front()

	hand_ready.emit()


## Plays the card at the given slot index. Returns the CardData if successful.
func try_play_card(slot_index: int) -> CardData:
	if slot_index < 0 or slot_index >= HAND_SIZE:
		card_play_rejected.emit(slot_index, &"invalid_slot")
		return null

	var card: CardData = _hand_slots[slot_index]
	if card == null:
		card_play_rejected.emit(slot_index, &"empty_slot")
		return null

	if _slot_cooldowns[slot_index] > 0:
		card_play_rejected.emit(slot_index, &"on_cooldown")
		return null

	# Remove from hand, add to discard
	_hand_slots[slot_index] = null
	_discard_pile.append(card)

	# Start draw delay for this slot
	_slot_cooldowns[slot_index] = DRAW_DELAY_FRAMES

	card_played.emit(card, slot_index)
	return card


## Ends the encounter and returns all card IDs.
func end_encounter() -> Array[StringName]:
	var all_cards: Array[CardData] = []
	for card in _hand_slots:
		if card != null:
			all_cards.append(card)
	all_cards.append_array(_draw_pile)
	all_cards.append_array(_discard_pile)

	var card_ids: Array[StringName] = []
	for card in all_cards:
		card_ids.append(card.card_id)

	_hand_slots.fill(null)
	_draw_pile.clear()
	_discard_pile.clear()
	_slot_cooldowns.fill(0)

	hand_cleared.emit()
	return card_ids


## Returns the card at the given slot, or null.
func get_card_at_slot(slot_index: int) -> CardData:
	if slot_index < 0 or slot_index >= HAND_SIZE:
		return null
	return _hand_slots[slot_index]


func get_hand_slots() -> Array[CardData]:
	return _hand_slots


func get_draw_pile_count() -> int:
	return _draw_pile.size()


func get_discard_pile_count() -> int:
	return _discard_pile.size()


func get_slot_cooldown(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= HAND_SIZE:
		return 0
	return _slot_cooldowns[slot_index]


# -- Private --

func _draw_to_slot(slot_index: int) -> void:
	if _draw_pile.is_empty():
		_reshuffle_discard()
	if _draw_pile.is_empty():
		return  # No cards left anywhere

	var card: CardData = _draw_pile.pop_front()
	_hand_slots[slot_index] = card
	card_drawn.emit(card, slot_index)


func _reshuffle_discard() -> void:
	if _discard_pile.is_empty():
		return
	_draw_pile = _discard_pile.duplicate()
	_discard_pile.clear()
	_shuffle_array(_draw_pile)
	draw_pile_reshuffled.emit()


func _shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
