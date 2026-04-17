# ADR-0003: Scene Management and Room Transitions

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scene Architecture |
| **Knowledge Risk** | LOW — PackedScene, SceneTree, change_scene unchanged |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Entity Composition), ADR-0002 (Signal Architecture) |
| **Enables** | ADR-0006 (Viewport/Camera), ADR-0011 (Dungeon Generation) |
| **Blocks** | Dungeon Generation epic, Room Encounter epic |
| **Ordering Note** | Must be accepted before any room-based gameplay can be implemented |

## Context

### Problem Statement
Deckslinger is room-based: the player moves through discrete rooms in a dungeon floor. Each room is a hand-crafted PackedScene. We need a scene management strategy that handles: loading rooms, positioning the player, managing the transition (fade to black → swap scene → fade in), cleaning up old rooms, and maintaining persistent state (autoloads, camera, UI) across room changes.

### Requirements
- Room swap must not cause frame drops (rooms are small 2D scenes, instant load expected)
- Camera hard-cut with fade (per Camera GDD: TRANSITION_FADE_OUT + TRANSITION_FADE_IN frames)
- Player entity, camera, and UI persist across rooms — only room content swaps
- Autoloads (InputManager, RunStateManager, etc.) are unaffected by room changes

## Decision

**A `SceneManager` autoload manages room swapping by replacing a child node of the persistent Main scene. Rooms are instantiated synchronously from PackedScene and added to a `RoomContainer` node.**

### Scene Tree Structure

```
Main (Node2D)                          # Persistent root — never freed
├── RoomContainer (Node2D)             # Room scenes are children of this
│   └── [CurrentRoom] (Node2D)         # Swapped on transition
│       ├── TileMapLayer               # Room geometry
│       ├── SpawnPoints (Node2D)       # Enemy spawn positions
│       ├── PlayerSpawn (Marker2D)     # Player entry point
│       ├── ExitTriggers (Node2D)      # Area2D exit zones
│       └── RoomData (Node)            # Room metadata resource
├── Player (EntityBase)                # Persistent — reparented, not freed
├── GameCamera (Camera2D)              # Persistent camera
├── UILayer (CanvasLayer)              # Persistent UI
│   ├── CardHandUI
│   ├── TransitionOverlay (ColorRect)  # Fade to/from black
│   └── CombatHUD
└── DungeonMapLayer (CanvasLayer)      # Map overlay
```

### Transition Sequence

```gdscript
# SceneManager.transition_to_room(room_scene: PackedScene, player_spawn: Vector2)
func transition_to_room(room_scene: PackedScene, player_spawn: Vector2) -> void:
    transitioning = true
    emit_signal("transition_started")

    # 1. Fade to black
    await transition_overlay.fade_out(TRANSITION_FADE_OUT)

    # 2. Free old room
    var old_room: Node = room_container.get_child(0) if room_container.get_child_count() > 0 else null
    if old_room:
        room_container.remove_child(old_room)
        old_room.queue_free()

    # 3. Instantiate new room
    var new_room: Node2D = room_scene.instantiate()
    room_container.add_child(new_room)

    # 4. Position player
    player.global_position = player_spawn

    # 5. Update camera
    var bounds: Rect2 = new_room.get_node("RoomBounds").get_rect()
    camera.set_room_bounds(bounds)
    camera.snap_to_target()  # no lerp — instant reposition

    # 6. Fade in
    await transition_overlay.fade_in(TRANSITION_FADE_IN)

    transitioning = false
    emit_signal("room_entered", new_room)
```

### Key Rules

1. **Player is a persistent node** — child of Main, not of the room. Repositioned on each transition but never freed or re-instantiated during a run.
2. **Rooms are disposable** — instantiated from PackedScene, freed on exit. No room state persists (all persistent state lives in RunStateManager).
3. **Synchronous loading** — rooms are small 2D scenes (<50 nodes). No async loading needed for MVP. If profiling shows frame drops, add `ResourceLoader.load_threaded_request()` later.
4. **TransitionOverlay handles fade** — a CanvasLayer ColorRect that tweens alpha. Ensures no frame shows both old and new rooms.

## Alternatives Considered

### Alternative 1: Godot's change_scene_to_packed()
- **Description**: Use SceneTree.change_scene_to_packed() to swap the entire scene
- **Pros**: Built-in, simple
- **Cons**: Frees EVERYTHING including persistent nodes (player, camera, UI). Would require re-instantiating player and reconnecting signals on every room change.
- **Rejection Reason**: Too destructive. We need persistent nodes to survive room transitions.

### Alternative 2: Additive Scene Loading
- **Description**: Load new room while old room still exists, crossfade
- **Pros**: Smooth transitions, no black screen
- **Cons**: Two rooms in memory simultaneously, potential collision/signal conflicts during overlap, more complex
- **Rejection Reason**: Overkill for room-based design with hard cuts. The fade-to-black approach is simpler and matches the GDD specification.

## Consequences

### Positive
- Player, camera, UI, and autoloads persist seamlessly across room changes
- Room scenes are self-contained — designers can author them independently
- Transition is visually clean (fade to black prevents visual glitches)

### Negative
- Room scenes cannot reference the player directly in the editor (player is external)
- Signal connections between room entities and persistent systems must be set up at runtime in `_ready()`

### Risks
- **Orphaned references**: If a persistent system (RunStateManager) caches a reference to a room entity, it becomes invalid after room free. Mitigation: persistent systems connect via signals and use `is_instance_valid()` guards.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| camera-system.md | RT.1 — Hard Cut transitions | Fade-to-black between rooms, camera snaps to new position |
| dungeon-generation-system.md | RP.3 — Room Scene Requirements | Room scenes contain RoomBounds, SpawnPoints, PlayerSpawn, ExitTrigger |
| dungeon-generation-system.md | NAV.2 — No Backtracking | Old room is freed on exit — cannot return |
| room-encounter-system.md | Encounter lifecycle | room_entered signal triggers RoomEncounterManager.start_encounter() |

## Performance Implications
- **CPU**: PackedScene.instantiate() for a <50 node 2D scene: <1ms. Transition fade: negligible.
- **Memory**: One room in memory at a time. Peak during transition: two rooms briefly (old being freed, new being added). Total <5MB.
- **Load Time**: Synchronous load from disk: <5ms for small scenes. No loading screen needed.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. Transitioning between two rooms preserves player HP, deck state, and currency (RunStateManager data unchanged)
2. No frame renders both old and new rooms simultaneously (fade covers the swap)
3. Signal connections from room entities are cleaned up on room free (no errors in output log)
4. Camera bounds update correctly for the new room on every transition

## Related Decisions
- ADR-0001: Entity Composition (player entity structure persists across rooms)
- ADR-0006: Viewport/Camera Pipeline (camera behavior during transitions)
