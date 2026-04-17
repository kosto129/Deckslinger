# Epic: Card Hand System

> **Layer**: Core
> **GDD**: design/gdd/card-hand-system.md
> **Architecture Module**: gameplay/card_hand_system.gd
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories card-hand-system`

## Overview

Implement the CardHandSystem that manages the player's active hand during
combat: shuffling the deck into a draw pile, dealing the opening hand,
executing the use-to-draw cycle (play card → draw replacement), managing
draw/discard piles with reshuffle, tracking per-slot cooldowns, and
coordinating encounter start/end deck sync with RunStateManager.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Data Resource Architecture | CardData consumed from CardRegistry | MEDIUM |
| ADR-0005: Input Buffering | Buffer consumed for card play actions | MEDIUM |
| ADR-0009: Damage Pipeline | execute_card() entry point for combat resolution | LOW |
| ADR-0003: Scene Management | Encounter lifecycle sync across room transitions | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-HA-001 | Use-to-draw cycling mechanic | ADR-0009 ✅ |
| TR-HA-002 | Seeded RNG for draw pile shuffle | ADR-0004 ✅ |
| TR-HA-003 | Draw/discard pile management with reshuffle | ADR-0004 ✅ |
| TR-HA-004 | Per-slot cooldown tracking in physics frames | ADR-0005 ✅ |
| TR-HA-005 | Encounter lifecycle: deal → play → end → return deck | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- start_encounter() shuffles deck and deals HAND_SIZE cards
- try_play_card() validates, removes card, triggers CombatSystem, schedules draw
- Use-to-draw: played card → discard → draw replacement after DRAW_DELAY
- Empty draw pile triggers discard reshuffle
- Cooldown tracking blocks play until timer expires
- end_encounter() returns all cards to deck array
- Seeded RNG produces identical draw order for same seed
- Unit tests pass for draw order, reshuffle, cooldown, encounter lifecycle

## Next Step

Run `/create-stories card-hand-system` to break this epic into implementable stories.
