## Top-level game flow state machine: MENU → RUN → DEATH/VICTORY → MENU.
## Orchestrates run initialization, encounter flow, and run teardown.
## Source: ADR-0003
class_name GameManager
extends Node


enum GameState { MENU, RUN, DEATH, VICTORY }

signal run_started()
signal run_ended(outcome: Enums.RunOutcome)
signal returned_to_menu()

var _state: GameState = GameState.MENU

## The first room scene to load on run start.
## Set this in the editor or via code before calling start_run().
@export var first_room_scene: PackedScene
@export var first_spawn_position: Vector2 = Vector2(192, 108)

## Card hand system reference — found at runtime.
var _card_hand: CardHandSystem


func _ready() -> void:
	# Auto-start a run for MVP testing (skip menu)
	call_deferred("_auto_start_if_configured")


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

	# Initialize card hand system if present
	_card_hand = _find_card_hand_system()
	if _card_hand:
		# Start with a default starter deck
		var starter_deck := _get_starter_deck()
		_card_hand.start_encounter(starter_deck, randi())

	# Load first room if configured
	if first_room_scene and SceneManager:
		SceneManager.load_first_room(first_room_scene, first_spawn_position)

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

	# Auto-return to menu
	_state = GameState.MENU
	returned_to_menu.emit()


# -- Private --

func _auto_start_if_configured() -> void:
	if first_room_scene != null and _state == GameState.MENU:
		start_run()


func _find_card_hand_system() -> CardHandSystem:
	var node := get_tree().get_first_node_in_group(&"card_hand_system")
	if node is CardHandSystem:
		return node as CardHandSystem
	return null


func _get_starter_deck() -> Array[StringName]:
	# For MVP: return a hardcoded set of card IDs that match starter .tres files
	# In production this would come from RunStateManager
	var deck: Array[StringName] = []
	var all_cards := CardRegistry.get_all_cards()
	for card in all_cards:
		deck.append(card.card_id)
	# Pad to at least 8 cards by duplicating
	while deck.size() < 8 and deck.size() > 0:
		deck.append(deck[deck.size() - 1])
	return deck
