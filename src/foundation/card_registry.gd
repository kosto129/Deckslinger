## Loads all CardData .tres files at startup and provides typed lookup methods.
## Autoloaded as "CardRegistry". Read-only at runtime for MVP.
## Source: GDD card-data-system.md (CR.1), ADR-0004
class_name CardRegistry
extends Node


const CARDS_DIR: String = "res://assets/data/cards/"

var _cards: Dictionary = {}  # StringName -> CardData
var _all_cards: Array[CardData] = []


func _ready() -> void:
	_load_cards_recursive(CARDS_DIR)
	_validate_upgrade_references()


## Returns the CardData with the given card_id, or null if not found.
func get_card(card_id: StringName) -> CardData:
	return _cards.get(card_id, null)


## Returns all cards belonging to the given archetype.
func get_cards_by_archetype(archetype: Enums.CardArchetype) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in _all_cards:
		if card.archetype == archetype:
			result.append(card)
	return result


## Returns all cards with the given rarity.
func get_cards_by_rarity(rarity: Enums.CardRarity) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in _all_cards:
		if card.rarity == rarity:
			result.append(card)
	return result


## Returns all cards with the given card_type.
func get_cards_by_type(card_type: Enums.CardType) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in _all_cards:
		if card.card_type == card_type:
			result.append(card)
	return result


## Returns all loaded cards.
func get_all_cards() -> Array[CardData]:
	return _all_cards


## Returns the starter deck for the given archetype.
## Cards are tagged with "starter" + "starter_<archetype>" in their .tres files.
func get_starter_deck(archetype: Enums.CardArchetype) -> Array[CardData]:
	var archetype_tag := &"starter_%s" % Enums.CardArchetype.keys()[archetype].to_lower()
	var result: Array[CardData] = []
	for card in _all_cards:
		if card.tags.has(&"starter") and card.tags.has(archetype_tag):
			result.append(card)
	return result


## Returns the number of loaded cards.
func get_card_count() -> int:
	return _all_cards.size()


# -- Private --

func _load_cards_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir():
			_load_cards_recursive(full_path)
		elif file_name.ends_with(".tres"):
			_load_card_file(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_card_file(path: String) -> void:
	var resource := ResourceLoader.load(path)
	if resource == null:
		push_error("CardRegistry: failed to load resource at %s" % path)
		return

	if not resource is CardData:
		push_warning("CardRegistry: resource at %s is not CardData, skipping" % path)
		return

	var card: CardData = resource
	if card.card_id == &"":
		push_error("CardRegistry: card at %s has empty card_id, rejected" % path)
		return

	if _cards.has(card.card_id):
		push_warning("CardRegistry: duplicate card_id '%s' at %s — overwriting previous" % [card.card_id, path])

	_cards[card.card_id] = card
	# Replace in _all_cards if duplicate, otherwise append
	var existing_idx := -1
	for i in range(_all_cards.size()):
		if _all_cards[i].card_id == card.card_id:
			existing_idx = i
			break
	if existing_idx >= 0:
		_all_cards[existing_idx] = card
	else:
		_all_cards.append(card)


func _validate_upgrade_references() -> void:
	for card in _all_cards:
		if card.upgrade_card_id != &"" and not _cards.has(card.upgrade_card_id):
			push_warning("CardRegistry: card '%s' references upgrade '%s' which does not exist" % [card.card_id, card.upgrade_card_id])
