# Epic: Card Data System

> **Layer**: Foundation
> **GDD**: design/gdd/card-data-system.md
> **Architecture Module**: foundation/card_registry.gd (autoload) + foundation/data/
> **Status**: Ready
> **Stories**: 4 stories created 2026-04-16

## Overview

Implement the CardData and CardEffect Resource classes, the CardRegistry
autoload that loads and indexes all card .tres files at startup, and author
the 10 starter cards as .tres files in `assets/data/cards/`. This establishes
the data pipeline that Card Hand, Deck Building, Combat, Reward, and UI
systems all consume.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Data Resource Architecture | Resources for static data, RefCounted for runtime, Enums autoload, duplicate_deep() | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CD-001 | CardData as Godot Resource (.tres files) | ADR-0004 ✅ |
| TR-CD-002 | CardEffect as nested Resource array on CardData | ADR-0004 ✅ |
| TR-CD-003 | CardRegistry autoload for runtime lookup by card_id | ADR-0004 ✅ |
| TR-CD-004 | Archetype, Rarity, CardType, EffectType enums in shared file | ADR-0004 ✅ |
| TR-CD-005 | Variable substitution in card description strings | ADR-0004 ✅ |

## Definition of Done

This epic is complete when:
- CardData and CardEffect Resource classes exist with all exported fields
- CardRegistry autoload loads all .tres files from assets/data/cards/
- 10 starter cards authored as .tres files (per GDD section D.5/CR.3)
- get_card(), get_cards_by_archetype(), get_starter_deck() all work
- Unit tests pass for registry loading, card lookup, starter deck composition
- All acceptance criteria from card-data-system.md are verified

## Stories

| Story | Title | Type | Status | Gate |
|-------|-------|------|--------|------|
| [001](story-001-card-data-resources.md) | CardData and CardEffect Resource Classes | Logic | Ready | BLOCKING |
| [002](story-002-card-registry.md) | CardRegistry Autoload | Logic | Ready | BLOCKING |
| [003](story-003-starter-cards.md) | Starter Card .tres Files | Config/Data | Ready | ADVISORY |
| [004](story-004-description-substitution.md) | Card Description Variable Substitution | Logic | Ready | BLOCKING |

**Implementation order**: 001 → 002 → 003 → 004 (each story unblocks the next)

## Next Step

Implement Story 001: `src/foundation/data/card_data.gd` and `src/foundation/data/card_effect.gd`
