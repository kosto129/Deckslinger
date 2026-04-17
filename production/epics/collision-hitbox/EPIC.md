# Epic: Collision/Hitbox System

> **Layer**: Core
> **GDD**: design/gdd/collision-hitbox-system.md
> **Architecture Module**: foundation/components/hitbox_component.gd + hurtbox_component.gd
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories collision-hitbox`

## Overview

Implement the HitboxComponent and HurtboxComponent as Area2D-based collision
nodes with 7-layer faction filtering, HitData packet creation and delivery,
single-hit-per-action tracking, i-frame management with visual flicker, and
dodge invulnerability via hurtbox disable. This is the spatial truth layer
that determines what hits what.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008: Collision Layer Strategy | 7 layers, pre-configured masks, Area2D detection | LOW |
| ADR-0001: Entity Composition | Components as child nodes of EntityBase | LOW |
| ADR-0007: Animation Commitment | ACTIVE phase enables hitbox | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CH-001 | Area2D-based hitbox/hurtbox with collision layers | ADR-0008 ✅ |
| TR-CH-002 | Faction filtering via collision masks (7 layers) | ADR-0008 ✅ |
| TR-CH-003 | HitData packet creation and delivery via signals | ADR-0008 ✅ |
| TR-CH-004 | Single-hit rule per action per target | ADR-0008 ✅ |
| TR-CH-005 | I-frames with visual flicker (20 frames) | ADR-0008 ✅ |
| TR-CH-006 | Dodge i-frames via hurtbox disable (12 frames) | ADR-0008 ✅ |

## Definition of Done

This epic is complete when:
- HitboxComponent and HurtboxComponent scripts exist with class_name
- 7 collision layers configured in Godot Project Settings
- HitData RefCounted class created with all fields
- Hitbox enable/disable integrates with AnimationComponent ACTIVE phase
- Single-hit tracking prevents multi-frame damage
- I-frames with flicker work on HurtboxComponent
- Faction filtering verified: no friendly fire, no self-damage
- Unit tests pass for i-frame timing, single-hit rule, faction filtering

## Next Step

Run `/create-stories collision-hitbox` to break this epic into implementable stories.
