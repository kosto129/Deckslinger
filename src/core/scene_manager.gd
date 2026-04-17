## Manages room transitions via child-swap on RoomContainer.
## Persistent nodes (Player, Camera, UI) are never freed.
## Source: ADR-0003
class_name SceneManager
extends Node


signal transition_started()
signal room_entered(new_room: Node)

## Fade durations in seconds (converted from frames: 8/60 and 10/60).
const FADE_OUT_DURATION: float = 0.133
const FADE_IN_DURATION: float = 0.167

var transitioning: bool = false

var _room_container: Node2D
var _player: Node2D
var _camera: Camera2D
var _transition_overlay: TransitionOverlay


func _ready() -> void:
	# Deferred so Main scene tree is fully built
	call_deferred("_cache_references")


func _cache_references() -> void:
	_room_container = get_node_or_null("/root/Main/RoomContainer")
	_player = get_node_or_null("/root/Main/Player")
	_camera = get_node_or_null("/root/Main/GameCamera")
	_transition_overlay = get_node_or_null("/root/Main/UILayer/TransitionOverlay")


## Full room transition with fade-to-black.
func transition_to_room(room_scene: PackedScene, player_spawn: Vector2) -> void:
	if transitioning:
		push_warning("SceneManager: transition already in progress, ignoring")
		return

	transitioning = true
	transition_started.emit()

	# 1. Fade to black
	if _transition_overlay:
		await _transition_overlay.fade_out(FADE_OUT_DURATION)

	# 2. Free old room
	_free_current_room()

	# 3. Instantiate new room
	var new_room: Node2D = room_scene.instantiate()
	_room_container.add_child(new_room)

	# 4. Position player
	if _player:
		_player.global_position = player_spawn

	# 5. Update camera bounds and snap
	_update_camera_for_room(new_room)

	# 6. Fade in
	if _transition_overlay:
		await _transition_overlay.fade_in(FADE_IN_DURATION)

	transitioning = false
	room_entered.emit(new_room)


## Loads the first room without fade-out (overlay starts transparent).
func load_first_room(room_scene: PackedScene, player_spawn: Vector2) -> void:
	if transitioning:
		return

	transitioning = true
	transition_started.emit()

	var new_room: Node2D = room_scene.instantiate()
	_room_container.add_child(new_room)

	if _player:
		_player.global_position = player_spawn

	_update_camera_for_room(new_room)

	# Fade in from black (overlay may start at alpha=1 for first room)
	if _transition_overlay:
		await _transition_overlay.fade_in(FADE_IN_DURATION)

	transitioning = false
	room_entered.emit(new_room)


## Returns the current room node, or null if no room is loaded.
func get_current_room() -> Node:
	if _room_container and _room_container.get_child_count() > 0:
		return _room_container.get_child(0)
	return null


# -- Private --

func _free_current_room() -> void:
	if _room_container == null:
		return
	for child in _room_container.get_children():
		_room_container.remove_child(child)
		child.queue_free()


func _update_camera_for_room(room: Node2D) -> void:
	if _camera == null:
		return

	var room_bounds_node := room.get_node_or_null("RoomBounds")
	if room_bounds_node and room_bounds_node.has_method("get_rect"):
		_camera.set("room_bounds", room_bounds_node.get_rect())
	if _camera.has_method("snap_to_target"):
		_camera.snap_to_target()
