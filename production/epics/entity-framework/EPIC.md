# Epic: Entity Framework

> **Layer**: Foundation
> **GDD**: design/gdd/entity-framework.md
> **Architecture Module**: foundation/entity_base + foundation/components/
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories entity-framework`

## Overview

Implement the EntityBase scene class and all 8 component types that form the
composition-based entity model for Deckslinger. This includes the 6-state
lifecycle state machine, typed component getters, and the shared Enums autoload.
Every other system in the game depends on these contracts. This epic also
creates the Enums autoload (`src/core/enums.gd`) since it is required by
EntityBase and all components.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Entity Composition Pattern | Node2D + typed child components, cached @onready getters | LOW |
| ADR-0002: Signal Architecture | Callable-based signals, typed parameters, cross-layer via signals | LOW |
| ADR-0004: Data Resource Architecture | Shared enums in autoload, Resource-based data | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-EF-001 | Composition model via Godot scenes + typed child nodes | ADR-0001 ✅ |
| TR-EF-002 | EntityType enum + 6-state lifecycle state machine | ADR-0001 ✅ |
| TR-EF-003 | Component discovery via typed get_node_or_null() | ADR-0001 ✅ |
| TR-EF-004 | Collision footprints ~50% of sprite canvas | ADR-0001 ✅ |

## Definition of Done

This epic is complete when:
- `src/core/enums.gd` autoload exists with all shared enums
- `EntityBase` class exists with lifecycle state machine and typed getters
- All 8 component scripts exist with class_name declarations
- Entity scenes can be instantiated and transition through all 6 lifecycle states
- Unit tests pass for lifecycle transitions and component presence/absence
- All acceptance criteria from entity-framework.md are verified

## Next Step

Run `/create-stories entity-framework` to break this epic into implementable stories.
