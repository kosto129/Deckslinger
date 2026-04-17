# Deck Building System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 2 (Your Deck Is Your Identity), Pillar 4 (Earn Everything)

## Summary

The Deck Building System manages deck modification between encounters: card
drafting (adding cards), card removal (trimming), and card upgrades. It
enforces deck constraints (size limits, rarity caps) and presents the player
with meaningful choices that shape their run identity.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Card Data System, Card Hand System`

## Overview

The Deck Building System is where Pillar 2 lives. Between encounters, the
player shapes their deck — and by extension, their playstyle — through three
operations: drafting new cards from a reward pool, removing (trimming) weak or
redundant cards to increase consistency, and upgrading existing cards to
improve their power. Every choice is a tradeoff: adding a powerful card
increases options but dilutes draw consistency; trimming a card reduces
versatility but concentrates the deck's identity; upgrading commits resources
to an existing card rather than gaining a new one. The system enforces deck
constraints (MIN_DECK_SIZE, MAX_DECK_SIZE, rarity limits) and exposes the deck
state to the Run State Manager for persistence across encounters.

## Player Fantasy

The reward screen is where runs are won or lost. Three cards fan out before
you — each one a promise and a risk. The rare Gunslinger card would be
devastating with your current deck, but you already have two rares. The common
Drifter card fills a defensive gap you felt in the last fight. You draft the
Drifter card, then trim the basic strike you've been meaning to cut. Your deck
is tighter now: 7 cards, all intentional, each one earning its slot. You feel
like a craftsman building a weapon. The deck IS you.

## Detailed Rules

### Draft Operation

**DR.1 — Draft Presentation**

After each qualifying encounter (per Reward System rules), the player is
presented with `DRAFT_CHOICES` cards to choose from:

| Property | Value |
|----------|-------|
| Choices shown | `DRAFT_CHOICES` (default: 3) |
| Selection | Pick exactly 1, or skip (take none) |
| Rarity distribution | Determined by Reward System using Card Data draft weights |
| Archetype filter | No filter — any archetype can appear |
| Duplicate filter | No cards already in the player's deck appear in draft |

**DR.2 — Draft Rules**

- Player must choose 1 card or explicitly skip
- Chosen card is immediately added to the deck
- Skipped cards are discarded (not saved for later)
- If deck would exceed `MAX_DECK_SIZE` after draft, draft is blocked — player
  must trim first (or skip)
- Draft choices are generated once per reward. Leaving and re-entering the
  screen shows the same choices (no rerolling by exiting)

### Trim Operation

**TR.1 — Trim Presentation**

The player can remove cards from their deck at designated trim opportunities
(rest rooms, post-encounter option):

| Property | Value |
|----------|-------|
| Cards shown | Full current deck |
| Selection | Remove 0 or 1 card per opportunity |
| Restriction | Cannot trim below `MIN_DECK_SIZE` |
| Cost | Free in MVP (future: currency cost) |

**TR.2 — Trim Rules**

- Removed card is permanently gone for this run
- Cannot trim the last card of a given type if it would leave the deck with
  no ATTACK cards (at least 1 ATTACK must remain)
- Trimming is optional — player can always skip
- Trimmed card is shown briefly with a "removed" animation for confirmation

### Upgrade Operation

**UP.1 — Upgrade Presentation**

At designated upgrade opportunities (specific reward rooms, currency purchase):

| Property | Value |
|----------|-------|
| Cards shown | All upgradeable cards in current deck |
| Selection | Upgrade 0 or 1 card per opportunity |
| Eligibility | Card has `upgrade_card_id` set and is not already upgraded |

**UP.2 — Upgrade Rules**

- The base card is replaced by its upgraded version in the deck
- Upgraded card retains its position in the deck order
- Upgrade is permanent for the run
- Already-upgraded cards cannot be upgraded again (one upgrade tier in MVP)
- Cards without `upgrade_card_id` in CardData cannot be upgraded

### Deck Constraints

**DC.1 — Size Constraints**

| Constraint | Value | Enforcement |
|------------|-------|-------------|
| `MIN_DECK_SIZE` | 6 | Cannot trim below this. Always enforced. |
| `MAX_DECK_SIZE` | 30 | Cannot draft above this. Must trim first. |
| `STARTER_DECK_SIZE` | 8 | Initial deck at run start. |

**DC.2 — Rarity Constraints**

| Constraint | Value | Enforcement |
|------------|-------|-------------|
| `RARE_DECK_LIMIT` | 3 | Cannot draft a RARE if deck already has 3 RAREs |
| `LEGENDARY_DECK_LIMIT` | 1 | Cannot draft a LEGENDARY if deck already has 1 |
| COMMON / UNCOMMON | No limit | Always draftable |

Rarity constraints filter the draft pool — restricted cards don't appear as
choices, not as a post-selection rejection.

**DC.3 — Minimum Attack Rule**

The deck must always contain at least 1 ATTACK-type card. This prevents the
player from building a deck that literally cannot deal damage (which would
softlock encounters with mandatory enemy kills).

### Deck State Interface

**DSI.1 — Deck Representation**

The deck is stored as `Array[StringName]` (card IDs). Order is preserved but
only matters for initial shuffle seed. The Deck Building System writes to this
array; the Card Hand System and Run State Manager read from it.

```gdscript
# Deck modification
func add_card(card_id: StringName) -> bool  # false if constraints violated
func remove_card(card_id: StringName) -> bool  # false if below min size
func upgrade_card(card_id: StringName) -> bool  # false if not upgradeable

# Queries
func get_deck() -> Array[StringName]
func get_deck_size() -> int
func get_card_count_by_rarity(rarity: Rarity) -> int
func can_add_card(card_data: CardData) -> bool  # checks all constraints
func can_remove_card(card_id: StringName) -> bool  # checks min size + attack rule
func get_upgradeable_cards() -> Array[StringName]
```

## Formulas

**F.1 — Draft Pool Construction**

```
Variables:
  all_cards       = CardRegistry.get_all_cards()
  current_deck    = player's current deck card IDs
  deck_rares      = count of RARE cards in current deck
  deck_legendaries = count of LEGENDARY cards in current deck
  RARE_LIMIT      = RARE_DECK_LIMIT
  LEGENDARY_LIMIT = LEGENDARY_DECK_LIMIT

Output:
  eligible_pool = cards that can appear in draft

Formula:
  eligible_pool = all_cards.filter(card =>
    card.card_id NOT IN current_deck
    AND (card.rarity != RARE OR deck_rares < RARE_LIMIT)
    AND (card.rarity != LEGENDARY OR deck_legendaries < LEGENDARY_LIMIT)
    AND card.starter_card == false  # starters don't appear in drafts
  )

Example (deck has 2 RAREs, 0 LEGENDARYs, 12 cards):
  RARE cards: eligible (2 < 3)
  LEGENDARY cards: eligible (0 < 1)
  Cards already in deck: excluded
  Starter cards: excluded
```

**F.2 — Deck Consistency Score**

Design-time metric for evaluating how focused a deck is.

```
Variables:
  deck_size         = total cards in deck
  primary_archetype = archetype with most cards
  primary_count     = count of primary archetype cards
  HAND_SIZE         = 4

Output:
  consistency = 0.0 to 1.0 (higher = more focused)

Formula:
  archetype_ratio = primary_count / deck_size
  cycle_speed = HAND_SIZE / deck_size
  consistency = (archetype_ratio + cycle_speed) / 2.0

Example (8-card deck, 5 Gunslinger, 3 Neutral):
  archetype_ratio = 5/8 = 0.625
  cycle_speed = 4/8 = 0.5
  consistency = (0.625 + 0.5) / 2.0 = 0.5625

Example (6-card deck, 5 Gunslinger, 1 Neutral):
  archetype_ratio = 5/6 = 0.833
  cycle_speed = 4/6 = 0.667
  consistency = (0.833 + 0.667) / 2.0 = 0.75 (very focused)
```

## Edge Cases

- **Draft with deck at MAX_DECK_SIZE**: Draft screen shows cards but the
  "Add" button is disabled with message "Deck full — trim a card first."
  Player can skip or navigate to trim before returning. Draft choices persist.

- **All draft choices are cards the player already has**: Draft pool was
  depleted. Show "No new cards available" message. Player gets no draft this
  reward. Extremely rare with 25+ card pool.

- **Trim would leave 0 ATTACK cards**: Trim is blocked for that specific card.
  Card is visually marked "Cannot remove — last attack card." Other cards can
  still be trimmed.

- **Trim at MIN_DECK_SIZE**: Trim button is disabled entirely. Message:
  "Deck is at minimum size."

- **Upgrade card whose upgrade doesn't exist in registry**: `upgrade_card_id`
  points to a missing card. Upgrade option is not shown for this card. Log a
  warning. Base card functions normally.

- **Draft a card, then immediately trim it**: Legal. The card was added to the
  deck and can be removed in the same reward screen if a trim opportunity is
  available. Player pays whatever trim cost applies (free in MVP).

- **Deck has duplicate card IDs**: Should not occur (draft filters duplicates).
  If it somehow does (debug/cheat), both instances function. Trim removes one
  instance. No crash.

- **Player skips every draft for the entire run**: Legal but challenging. Deck
  stays at starter size. The game is harder but not impossible — this is a
  valid challenge run playstyle.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Card Data System | `CardRegistry` for card lookups, rarity data, upgrade paths | Hard |
| Upstream | Card Hand System | Receives modified deck at encounter start | Hard |
| Downstream | Reward System | Provides draft pool, rarity weights | Hard |
| Downstream | Run State Manager | Persists deck state between encounters | Hard |
| Downstream | Reward Screen UI | Renders draft choices, trim interface, upgrade interface | Hard |

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `DRAFT_CHOICES` | 3 | 2–5 | Cards shown per draft. More = easier to find synergies. Fewer = harder choices. |
| `MIN_DECK_SIZE` | 6 | 4–8 | Minimum after trimming. Lower = more consistent but riskier. |
| `MAX_DECK_SIZE` | 30 | 20–40 | Maximum deck. Higher = more draft freedom, less consistency. |
| `RARE_DECK_LIMIT` | 3 | 2–5 | Rare cap. Higher = more power ceiling. Lower = rares feel rarer. |
| `LEGENDARY_DECK_LIMIT` | 1 | 1–2 | Legendary cap. 1 = truly special. 2 = build-around possible. |
| `TRIM_COST` | 0 (free) | 0–50 currency | Future: currency cost for trimming. 0 in MVP. |
| `UPGRADE_COST` | 0 (free) | 0–100 currency | Future: currency cost for upgrading. 0 in MVP. |

## Acceptance Criteria

1. **GIVEN** reward screen with DRAFT_CHOICES=3, **WHEN** displayed, **THEN**
   exactly 3 cards shown, none duplicating cards already in deck.

2. **GIVEN** player drafts a card, **WHEN** deck updated, **THEN** deck size
   increases by 1, new card is in the deck array.

3. **GIVEN** deck at MAX_DECK_SIZE, **WHEN** draft screen shown, **THEN**
   add button disabled, "deck full" message displayed.

4. **GIVEN** deck has 3 RARE cards, **WHEN** draft pool constructed, **THEN**
   no RARE cards appear in draft choices.

5. **GIVEN** player trims a card with deck_size > MIN_DECK_SIZE, **WHEN**
   confirmed, **THEN** card removed, deck size decreases by 1.

6. **GIVEN** deck at MIN_DECK_SIZE, **WHEN** trim attempted, **THEN** trim
   blocked, "minimum size" message shown.

7. **GIVEN** deck has 1 ATTACK card, **WHEN** player tries to trim it, **THEN**
   trim blocked for that card, "last attack card" message shown.

8. **GIVEN** card with upgrade_card_id set, **WHEN** upgrade selected, **THEN**
   base card replaced by upgraded version in deck at same position.

9. **GIVEN** already-upgraded card, **WHEN** upgrade screen shown, **THEN**
   card not listed as upgradeable.

10. **GIVEN** player skips draft, **WHEN** confirmed, **THEN** deck unchanged,
    draft choices discarded, game continues.

11. **GIVEN** `can_add_card()` called with a LEGENDARY when deck has 1, **WHEN**
    checked, **THEN** returns false.

12. **GIVEN** deck modification occurs, **WHEN** Run State Manager queried,
    **THEN** deck state reflects the change immediately.
