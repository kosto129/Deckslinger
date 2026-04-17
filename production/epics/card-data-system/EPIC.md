# Epic: Card Data System

> **Layer**: Foundation
> **GDD**: design/gdd/card-data-system.md
> **Architecture Module**: foundation/card_registry.gd (autoload) + foundation/data/
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories card-data-system`

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

## Next Step

Run `/create-stories card-data-system` to break this epic into implementable stories.
