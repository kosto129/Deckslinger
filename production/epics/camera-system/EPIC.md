# Epic: Camera System

> **Layer**: Foundation
> **GDD**: design/gdd/camera-system.md
> **Architecture Module**: foundation/camera_controller.gd
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories camera-system`

## Overview

Implement the CameraController that manages the 384×216 pixel-perfect viewport,
exponential player follow with look-ahead, room boundary clamping, screen shake
with decay, and hit-freeze camera hold. Configure Godot Project Settings for
integer scaling and pixel snapping. This provides the visual foundation that
every gameplay system renders through.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Viewport & Camera Pipeline | 384×216 SubViewport, integer scaling, lerp follow, pixel snap | LOW |
| ADR-0003: Scene Management | Room bounds provided on transition, camera snaps on room change | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CM-001 | 384×216 SubViewport with integer scaling | ADR-0006 ✅ |
| TR-CM-002 | Exponential follow with pixel snapping | ADR-0006 ✅ |
| TR-CM-003 | Room boundary clamping | ADR-0006 ✅ |
| TR-CM-004 | Screen shake with per-frame decay | ADR-0006 ✅ |
| TR-CM-005 | Hit-freeze camera position hold | ADR-0006 ✅ |
| TR-CM-006 | Hard-cut room transitions with fade overlay | ADR-0003, ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- Project Settings configured for 384×216, canvas_items, keep aspect, pixel snapping
- CameraController follows player with exponential lerp and integer snap
- Look-ahead offsets camera in aim direction
- Room bounds clamp prevents viewport showing outside room
- request_shake() produces decaying shake effect
- set_frozen() holds camera position during hit-stop
- Transition overlay fades to/from black
- Unit tests pass for clamping math, shake decay, integer scaling

## Next Step

Run `/create-stories camera-system` to break this epic into implementable stories.
