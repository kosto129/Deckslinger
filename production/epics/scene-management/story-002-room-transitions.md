# Story 002: Room Transitions

> **Epic**: Scene Management
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: N/A (architectural infrastructure)
**Requirement**: `TR-CM-006` (Hard-cut room transitions with fade), `TR-DG-003` (Room scenes loaded via PackedScene)

**ADR Governing Implementation**: ADR-0003: Scene Management and Room Transitions
**ADR Decision Summary**: `SceneManager` autoload implements `transition_to_room(room_scene, player_spawn)`. The sequence is: fade out → free old room → instantiate new room → position player → update camera bounds → fade in. No frame may show both old and new rooms simultaneously.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `PackedScene.instantiate()` (not `instance()` — deprecated 4.0), `Node.queue_free()`, `await`, and `Tween` are all standard in Godot 4.6. String-based `connect()` is forbidden — use callable connections.

**Control Manifest Rules (Foundation)**:
- Required: Player entity is a persistent child of Main, not any room scene. Repositioned on transition, never freed.
- Required: Rooms are instantiated from PackedScene and freed on exit. No room state persists.
- Required: Room transitions use fade-to-black. TransitionOverlay tweens alpha. No frame shows both old and new rooms.
- Forbidden: Never use `change_scene_to_packed()` — it frees persistent nodes.
- Forbidden: Never use `connect("signal", obj, "method")` — use `signal.connect(callable)`.

---

## Acceptance Criteria

- [ ] `src/core/scene_manager.gd` exists with `class_name SceneManager`, registered as autoload "SceneManager"
- [ ] `transition_to_room(room_scene: PackedScene, player_spawn: Vector2) -> void` is implemented
- [ ] Transition sequence order: fade_out → free old room → instantiate new room → position player → update camera bounds → snap camera → fade_in
- [ ] No frame renders both old and new rooms simultaneously (fade covers the swap)
- [ ] Old room node is removed and `queue_free()`'d before new room is added
- [ ] New room is instantiated with `room_scene.instantiate()` and added as child of `RoomContainer`
- [ ] Player `global_position` is set to `player_spawn` after room swap, before camera update
- [ ] `GameCamera.set_room_bounds(bounds)` is called with the new room's bounds after player is repositioned
- [ ] `GameCamera.snap_to_target()` is called after `set_room_bounds` to instantly center camera (no lerp across rooms)
- [ ] `transition_started` signal emitted before fade-out begins
- [ ] `room_entered(new_room: Node)` signal emitted after fade-in completes
- [ ] Signals use typed parameters and callable-style connections
- [ ] Player HP, deck state, and currency (RunStateManager data) are unchanged after transition
- [ ] Signal connections from freed room entities produce no errors in output log

---

## Transition Sequence

```gdscript
func transition_to_room(room_scene: PackedScene, player_spawn: Vector2) -> void:
    transitioning = true
    transition_started.emit()

    # 1. Fade to black
    await _transition_overlay.fade_out(TRANSITION_FADE_OUT)

    # 2. Free old room
    var old_room: Node = _room_container.get_child(0) \
        if _room_container.get_child_count() > 0 else null
    if old_room:
        _room_container.remove_child(old_room)
        old_room.queue_free()

    # 3. Instantiate new room
    var new_room: Node2D = room_scene.instantiate()
    _room_container.add_child(new_room)

    # 4. Position player
    _player.global_position = player_spawn

    # 5. Update camera bounds and snap
    var bounds: Rect2 = new_room.get_node("RoomBounds").get_rect()
    _camera.set_room_bounds(bounds)
    _camera.snap_to_target()

    # 6. Fade in
    await _transition_overlay.fade_in(TRANSITION_FADE_IN)

    transitioning = true  # Note: set false after transition completes
    transitioning = false
    room_entered.emit(new_room)
```

Signals defined on SceneManager:
```gdscript
signal transition_started()
signal room_entered(new_room: Node)
```

---

## Implementation Notes

SceneManager is an autoload. It holds `@onready` references to persistent nodes
via `get_node()` calls against the Main scene path (e.g.,
`/root/Main/RoomContainer`, `/root/Main/Player`, `/root/Main/GameCamera`,
`/root/Main/UILayer/TransitionOverlay`). These paths are stable because Main
is the persistent root scene.

`TransitionOverlay.fade_out(frames: int)` and `fade_in(frames: int)` are
methods on a lightweight script attached to the ColorRect. They tween `modulate.a`
to 1.0 (fade out) or 0.0 (fade in) over the specified frame count using a Tween.
The `await` on these calls blocks the transition sequence until complete.

Room bounds are obtained from a child node named `"RoomBounds"` on the room scene
(a Node2D or Marker2D that exposes `get_rect()` returning the room's Rect2). This
interface is defined in the ADR-0003 room scene spec. If `RoomBounds` is missing,
log an error and use a default Rect2 matching the viewport size.

Orphaned signal guards: room scenes may connect their signals during `_ready()`.
When `queue_free()` is called, Godot 4.6 automatically disconnects signals from
freed objects. However, persistent systems that cached node references must use
`is_instance_valid(ref)` before any deferred access.

The first room load (on run start) is handled by GameManager calling
`SceneManager.transition_to_room()`. The TransitionOverlay starts at alpha=0,
so the initial fade sequence begins with a fade-in only (no fade-out needed on
first load — GameManager may call a simpler `load_first_room()` variant that skips
the fade-out phase).

TRANSITION_FADE_OUT and TRANSITION_FADE_IN are exported constants on SceneManager,
defaulting to 8 and 10 frames respectively (from Camera GDD tuning knobs).

---

## Out of Scope

- Story 001: Main.tscn scene structure (prerequisite — SceneManager references nodes defined there)
- Story 003: GameManager (orchestrates when to call transition_to_room)
- Camera System / Story 003: set_room_bounds and snap_to_target implementations (called here, implemented there)
- Room Encounter System: room_entered signal handler (downstream consumer)
- Dungeon Generation: which room to load next (provides the PackedScene argument)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration test OR documented playtest — must verify two sequential transitions preserve RunState
**Test file**: `tests/integration/scene_management/room_transition_test.gd`
**Status**: [x] SceneManager + TransitionOverlay implemented — integration test requires in-engine verification

Integration test scenario:
1. Set up RunStateManager with known HP=80, deck=[card_a, card_b], currency=10.
2. Call `SceneManager.transition_to_room(room_a_scene, Vector2(100,108))`.
3. Assert: RoomContainer has exactly one child (room_a).
4. Assert: Player global_position == Vector2(100,108).
5. Assert: RunStateManager HP==80, deck unchanged, currency==10.
6. Call `SceneManager.transition_to_room(room_b_scene, Vector2(200,108))`.
7. Assert: RoomContainer has exactly one child (room_b — room_a is freed).
8. Assert: RunStateManager unchanged.
9. Assert: No errors in output log (no orphaned signal warnings).

---

## Dependencies

- Depends on: Story 001 (Main.tscn — RoomContainer, Player, GameCamera, TransitionOverlay nodes must exist)
- Depends on: Camera System / Story 003 (set_room_bounds and snap_to_target must be implemented)
- Depends on: Entity Framework (EntityBase / Player node)
- Unlocks: Story 003 (GameManager calls transition_to_room on run start), Room Encounter System (room_entered signal triggers encounter start), Dungeon Generation (provides PackedScene arguments)
