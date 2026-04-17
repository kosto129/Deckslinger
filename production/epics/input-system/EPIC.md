# Epic: Input System

> **Layer**: Foundation
> **GDD**: design/gdd/input-system.md
> **Architecture Module**: foundation/input_manager.gd (autoload)
> **Status**: Ready
> **Stories**: 4 stories created

## Stories

| Story | Title | Type | Status | Depends On |
|-------|-------|------|--------|------------|
| [story-001-action-map.md](story-001-action-map.md) | Action Map Configuration | Config/Data | Ready | entity-framework/story-001 |
| [story-002-input-buffer.md](story-002-input-buffer.md) | Input Buffer | Logic | Ready | story-001 |
| [story-003-movement-aim.md](story-003-movement-aim.md) | Movement Vector and Aim Direction | Logic | Ready | story-001, story-002 |
| [story-004-device-detection.md](story-004-device-detection.md) | Device Detection and Mode Management | Integration | Ready | story-001, story-002, story-003 |

## Overview

Implement the InputManager autoload that translates raw hardware events into
named game actions, manages the single-slot input buffer with frame-counted
expiry, handles gamepad dead zone remapping, provides 8-directional movement
and aim queries, and supports device detection with automatic prompt switching.
This is the bridge between the player's physical inputs and every gameplay
system that responds to player intent.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Input Buffering & Action Map | Single-slot buffer, 8-frame expiry, frame-counted, GAMEPLAY/UI modes | MEDIUM |
| ADR-0002: Signal Architecture | input_device_changed and input_mode_changed signals | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-IN-001 | Named action map via Godot InputMap | ADR-0005 ✅ |
| TR-IN-002 | Single-slot input buffer (8 frames default) | ADR-0005 ✅ |
| TR-IN-003 | 8-directional movement with diagonal normalization | ADR-0005 ✅ |
| TR-IN-004 | Gamepad dead zone remapping (inner/outer thresholds) | ADR-0005 ✅ |
| TR-IN-005 | Two input modes (GAMEPLAY/UI) with buffer clear on switch | ADR-0005 ✅ |
| TR-IN-006 | Device detection with automatic UI prompt switching | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- InputManager autoload exists with all public methods from ADR-0005
- Godot InputMap configured with all 15 actions (project.godot)
- Buffer correctly stores, expires, and is consumed by test code
- Dead zone remapping produces correct output values
- Device switching fires input_device_changed signal
- Unit tests pass for buffer lifecycle, movement normalization, dead zone math

## Implementation Order

Stories must be implemented in dependency order:
1. story-001-action-map (project.godot configuration — no code dependencies)
2. story-002-input-buffer (InputManager autoload scaffold + buffer logic)
3. story-003-movement-aim (movement and aim query methods added to InputManager)
4. story-004-device-detection (device tracking, signals, freeze support — completes InputManager)
