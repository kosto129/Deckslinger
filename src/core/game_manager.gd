## Top-level game flow state machine: MENU → RUN → DEATH/VICTORY → MENU.
## Orchestrates run initialization, encounter flow, and run teardown.
## Source: ADR-0003
class_name GameManager
extends Node


enum GameState { MENU, RUN, DEATH, VICTORY }

signal run_started()
signal run_ended(outcome: Enums.RunOutcome)
signal returned_to_menu()

const DEFAULT_ROOM_PATH: String = "res://src/rooms/TestRoom.tscn"

var _state: GameState = GameState.MENU
var _card_hand: CardHandSystem


func _ready() -> void:
	call_deferred("_auto_start")


func get_state() -> GameState:
	return _state


## Starts a new run from the menu state.
func start_run() -> void:
	if _state != GameState.MENU:
		push_error("GameManager.start_run(): invalid from state %s" % GameState.keys()[_state])
		return

	_state = GameState.RUN

	# Activate the player entity
	var player := get_node_or_null("/root/Main/Player") as EntityBase
	if player:
		player.activate()
		player.spawn_complete()

	# Initialize card hand system
	_card_hand = get_node_or_null("/root/Main/CardHandSystem") as CardHandSystem
	if _card_hand:
		var starter_deck := _get_starter_deck()
		if starter_deck.size() > 0:
			_card_hand.start_encounter(starter_deck, randi())

	# Load the test room
	var room_scene := load(DEFAULT_ROOM_PATH) as PackedScene
	if room_scene and SceneManager:
		SceneManager.load_first_room(room_scene, Vector2(100, 108))

	run_started.emit()


## Ends the current run with the given outcome.
func end_run(outcome: Enums.RunOutcome) -> void:
	if _state != GameState.RUN:
		push_error("GameManager.end_run(): invalid from state %s" % GameState.keys()[_state])
		return

	if outcome == Enums.RunOutcome.DEATH:
		_state = GameState.DEATH
	else:
		_state = GameState.VICTORY

	if _card_hand:
		_card_hand.end_encounter()

	run_ended.emit(outcome)

	_state = GameState.MENU
	returned_to_menu.emit()


# -- Private --

func _auto_start() -> void:
	if _state == GameState.MENU:
		start_run()


func _get_starter_deck() -> Array[StringName]:
	var deck: Array[StringName] = []
	var all_cards := CardRegistry.get_all_cards()
	for card in all_cards:
		deck.append(card.card_id)
	# Pad to at least 8 cards by duplicating if we have any
	while deck.size() < 8 and deck.size() > 0:
		deck.append(deck[deck.size() - 1])
	return deck
