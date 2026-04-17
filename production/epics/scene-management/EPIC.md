# Epic: Scene Management

> **Layer**: Foundation
> **GDD**: N/A (architectural infrastructure — governed by ADR-0003)
> **Architecture Module**: core/scene_manager.gd (autoload) + core/game_manager.gd (autoload)
> **Status**: Ready
> **Stories**: 3 stories created

## Stories

| # | File | Type | Status | Description |
|---|------|------|--------|-------------|
| 001 | [story-001-main-scene.md](story-001-main-scene.md) | Integration | Ready | Main.tscn with RoomContainer, Player, GameCamera, UILayer, TransitionOverlay |
| 002 | [story-002-room-transitions.md](story-002-room-transitions.md) | Integration | Ready | SceneManager autoload: fade out → free → instantiate → position → camera → fade in |
| 003 | [story-003-game-manager.md](story-003-game-manager.md) | Logic | Ready | GameManager state machine: MENU → RUN → DEATH/VICTORY → MENU |

## Overview

Implement the SceneManager autoload that handles room loading/unloading via
child node swapping on a persistent Main scene, and the GameManager autoload
that manages the top-level game flow state machine (menu → run → death → menu).
This establishes the scene tree structure that all room-based gameplay depends
on: persistent player/camera/UI nodes that survive room transitions, and
disposable room scenes that are instantiated and freed per encounter.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Scene Management & Room Transitions | Persistent Main scene, rooms as swappable children, fade transitions | LOW |
| ADR-0002: Signal Architecture | room_entered, transition_started/ended signals | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CM-006 | Hard-cut room transitions with fade | ADR-0003 ✅ |
| TR-DG-003 | Hand-crafted room pool via PackedScene | ADR-0003 ✅ (partial — scene loading aspect) |

## Definition of Done

This epic is complete when:
- Main.tscn exists with RoomContainer, Player, GameCamera, UILayer nodes
- SceneManager autoload can load a room PackedScene as child of RoomContainer
- transition_to_room() performs fade-out → swap → fade-in without visual glitches
- Player entity persists across room transitions (HP, position updated correctly)
- GameManager state machine handles run start, run end (death/victory), return to menu
- Signal connections from room entities are cleaned up on room free (no errors)
- Integration test verifies two sequential room transitions preserve RunState

## Next Step

Implement Story 001 (Main.tscn structure), then Story 002 (SceneManager autoload), then Story 003 (GameManager). Stories are strictly sequential — each depends on the previous.
