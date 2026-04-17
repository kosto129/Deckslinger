# Epic: Input System

> **Layer**: Foundation
> **GDD**: design/gdd/input-system.md
> **Architecture Module**: foundation/input_manager.gd (autoload)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories input-system`

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

## Next Step

Run `/create-stories input-system` to break this epic into implementable stories.
