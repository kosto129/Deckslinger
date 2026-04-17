# Story 001: Main Scene Structure

> **Epic**: Scene Management
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: N/A (architectural infrastructure)
**Requirement**: N/A — governed by ADR-0003: Scene Management and Room Transitions

**ADR Governing Implementation**: ADR-0003: Scene Management and Room Transitions
**ADR Decision Summary**: A persistent `Main.tscn` is the root scene. RoomContainer holds swappable room children. Player, GameCamera, UILayer, and DungeonMapLayer are persistent children of Main — they are never freed during a run. Rooms are disposable children of RoomContainer.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Node2D, CanvasLayer, ColorRect, and scene tree structure are unchanged in Godot 4.6. No post-cutoff API risk.

**Control Manifest Rules (Foundation)**:
- Required: Player entity is a persistent child of Main, not of any room scene.
- Required: Rooms are instantiated from PackedScene and freed on exit.
- Required: Room transitions use fade-to-black. TransitionOverlay tweens alpha.
- Forbidden: Never use `change_scene_to_packed()` for room transitions — it frees persistent nodes.

---

## Acceptance Criteria

- [ ] `src/Main.tscn` exists and is set as the main scene in `project.godot`
- [ ] Scene tree root is `Main` (Node2D)
- [ ] `RoomContainer` (Node2D) is a direct child of `Main`
- [ ] `Player` (EntityBase) is a direct child of `Main` (not a child of any room scene)
- [ ] `GameCamera` (Camera2D with CameraController script) is a direct child of `Main`
- [ ] `UILayer` (CanvasLayer) is a direct child of `Main`
- [ ] `UILayer` contains `TransitionOverlay` (ColorRect) sized to cover the full viewport (384×216), default color black, default alpha 0
- [ ] `DungeonMapLayer` (CanvasLayer) is a direct child of `Main`
- [ ] `RoomContainer` starts empty (no room children at scene load — first room is loaded by GameManager on run start)
- [ ] Scene tree structure matches the ADR-0003 specification exactly

---

## Scene Tree Specification

```
Main (Node2D)                          # Persistent root — never freed
├── RoomContainer (Node2D)             # Room scenes are children of this — starts empty
├── Player (EntityBase)                # Persistent — repositioned on transitions, never freed
├── GameCamera (Camera2D)              # CameraController script attached
├── UILayer (CanvasLayer)              # layer = 1
│   ├── TransitionOverlay (ColorRect)  # Full viewport, black, alpha=0 at start
│   ├── CardHandUI (Control)           # Placeholder — wired up in Card Hand epic
│   └── CombatHUD (Control)            # Placeholder — wired up in Combat HUD epic
└── DungeonMapLayer (CanvasLayer)      # layer = 2, map overlay
```

Note: `CardHandUI` and `CombatHUD` are added as placeholder Control nodes at
this stage. They have no script and no content. They establish the correct
node names and tree positions so downstream epics can reference them without
restructuring the scene.

---

## Implementation Notes

`TransitionOverlay` must be positioned and sized to cover the full 384×216
viewport. In Godot 4.6, use anchors: `anchor_left=0`, `anchor_top=0`,
`anchor_right=1`, `anchor_bottom=1`, with `offset_*=0`. This ensures it
scales with the viewport and covers the screen regardless of window size.

`UILayer` (CanvasLayer) layer ordering: UILayer at layer 1 renders above the
game world. DungeonMapLayer at layer 2 renders above UILayer (map is a
screen-space overlay). Adjust if art direction changes layer priorities.

The Player node at this stage is a placeholder EntityBase node (may be an
empty Node2D with the correct class_name if EntityBase is not yet complete).
The critical constraint is that it exists as a direct child of Main, not inside
any room.

GameCamera must have the CameraController script attached from Camera System
Story 002 before room transitions function. These stories may be developed in
parallel, but integration testing requires both.

---

## Out of Scope

- Story 002: SceneManager autoload and room transition logic
- Story 003: GameManager autoload and state machine
- Camera System: CameraController script implementation (parallel epic)
- Entity Framework: EntityBase full implementation (parallel epic)
- Card Hand UI epic, Combat HUD epic: UI node implementations

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Manual walkthrough — confirm scene tree structure matches spec
**Status**: [ ] Not yet created

Manual verification steps:
1. Open `src/Main.tscn` in Godot editor — confirm node hierarchy matches the spec above.
2. Verify `Player` is a direct child of `Main`, not inside `RoomContainer`.
3. Verify `TransitionOverlay` fills the viewport (no gaps at edges).
4. Run the scene — confirm no startup errors in output log.
5. Verify `RoomContainer` has zero children at startup.

---

## Dependencies

- Depends on: Camera System / Story 001 (viewport configured in project.godot before running Main.tscn)
- Depends on: Entity Framework / Story 002 (EntityBase — Player node type)
- Unlocks: Story 002 (SceneManager references RoomContainer, Player, GameCamera nodes in Main.tscn), Story 003 (GameManager loads first room into RoomContainer)
