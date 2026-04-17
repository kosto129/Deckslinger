# Story 002: CardRegistry Autoload

> **Epic**: Card Data System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-data-system.md`
**Requirements**: `TR-CD-003` (CardRegistry autoload for runtime lookup by card_id)

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture
**ADR Decision Summary**: A singleton `CardRegistry` autoload loads all CardData resources at startup from `assets/data/cards/` and provides typed lookup methods. Deck is stored as `Array[StringName]` of card IDs — reconstituted via CardRegistry at encounter start.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `duplicate_deep()` (4.5+) is NOT used at load time — CardData resources are read-only at runtime for MVP. Verify that `DirAccess.get_files_at()` and recursive subdirectory scanning work correctly in 4.6 headless (CI). `ResourceLoader.load()` in Godot 4.6 returns `null` for missing files rather than crashing — null checks required after every load call. Performance guardrail: loading 25 .tres files at startup must complete in <100ms (ADR-0004).

**Control Manifest Rules (Foundation)**:
- Required: Static game data uses Godot Resources (.tres). CardRegistry loads resources, never constructs them from code.
- Required: All cross-system enums live in the Enums autoload. Registry queries use `Enums.CardArchetype`, `Enums.CardRarity`, `Enums.CardType`.
- Required: Deck stored as `Array[StringName]` of card IDs. CardRegistry is the resolution layer.
- Forbidden: Never hardcode gameplay values in GDScript. Starter deck composition must come from data (GDD CR.3), not inline arrays.
- Forbidden: Never use `duplicate()` on Resources with nested sub-resources.

---

## Acceptance Criteria

- [ ] `src/foundation/card_registry.gd` exists with `class_name CardRegistry extends Node`
- [ ] Registered as autoload named `"CardRegistry"` in `project.godot`
- [ ] `_ready()` scans `assets/data/cards/` recursively, loads all `.tres` files, populates internal index
- [ ] `get_card(card_id: StringName) -> CardData` returns the correct resource or `null` if not found
- [ ] `get_cards_by_archetype(archetype: Enums.CardArchetype) -> Array[CardData]` returns only cards matching the archetype
- [ ] `get_cards_by_rarity(rarity: Enums.CardRarity) -> Array[CardData]` returns only cards matching the rarity
- [ ] `get_cards_by_type(card_type: Enums.CardType) -> Array[CardData]` returns only cards matching the type
- [ ] `get_all_cards() -> Array[CardData]` returns every loaded card
- [ ] `get_starter_deck(archetype: Enums.CardArchetype) -> Array[CardData]` returns the correct 8 cards per GDD CR.3
- [ ] Duplicate `card_id`: warning is pushed via `push_warning()` at startup; last-loaded version is used
- [ ] Missing required field (`card_id == &""`): resource is rejected (not added to index), error pushed via `push_error()`
- [ ] `get_card()` called with an unknown id returns `null` without error or crash
- [ ] Loading completes in under 100ms for 25 .tres files (performance guardrail from ADR-0004)

---

## API Specification

```gdscript
class_name CardRegistry extends Node

## Loads all CardData .tres files from assets/data/cards/ at startup.
## Provides typed lookup methods for runtime card queries.

const CARDS_DIR: String = "res://assets/data/cards/"

# Returns the CardData with the given card_id, or null if not found.
func get_card(card_id: StringName) -> CardData

# Returns all cards belonging to the given archetype.
func get_cards_by_archetype(archetype: Enums.CardArchetype) -> Array[CardData]

# Returns all cards with the given rarity.
func get_cards_by_rarity(rarity: Enums.CardRarity) -> Array[CardData]

# Returns all cards with the given card_type.
func get_cards_by_type(card_type: Enums.CardType) -> Array[CardData]

# Returns all loaded cards.
func get_all_cards() -> Array[CardData]

# Returns the starter deck for the given archetype (8 cards, per GDD CR.3).
# Composition: card_ids are resolved from data — see Implementation Notes.
func get_starter_deck(archetype: Enums.CardArchetype) -> Array[CardData]
```

---

## Implementation Notes

**Recursive directory scan**: Use `DirAccess.open(CARDS_DIR)` with recursive traversal through `gunslinger/`, `drifter/`, `outlaw/`, `neutral/` subdirectories. Load each `.tres` file via `ResourceLoader.load()`. Cast result to `CardData`; if the cast fails (wrong resource type), push a warning and skip.

**Internal index**: Store loaded cards in a `Dictionary` typed `Dictionary` with key `StringName` (card_id) and value `CardData`. This provides O(1) lookup for `get_card()`. Keep a separate `Array[CardData]` for `get_all_cards()` to avoid repeated dictionary value extraction.

**Validation on load**: After loading each resource:
1. If `card_data.card_id == &""` — push_error, skip the resource (not added to index).
2. If `_cards.has(card_data.card_id)` — push_warning naming both the existing path and the duplicate path, overwrite with the new resource (last-loaded wins per GDD Edge Cases).
3. If `card_data.upgrade_card_id != &""` — defer upgrade validation to a second pass after all cards are loaded; warn if the referenced upgrade card_id does not exist in index.

**Starter deck composition**: `get_starter_deck()` must not hardcode card_id arrays inline. Options:
1. Each archetype's starter cards are tagged with a `"starter_gunslinger"` (etc.) tag in their `.tres` files, and `get_starter_deck()` filters by tag. (Preferred — data-driven, zero code changes to add/remove starter cards.)
2. A separate `starter_decks.tres` Resource maps archetype → Array[StringName] of card_ids.

Implement Option 1 (tag-based). Add tag `&"starter"` plus `&"starter_gunslinger"` (or appropriate archetype suffix) to each starter card's `tags` array when authoring Story 003.

**`get_cards_by_*` performance**: These are called infrequently (draft, deckbuilding). O(n) linear scan over `get_all_cards()` is acceptable for 25–100 cards. No caching needed for MVP.

**File location**: `src/foundation/card_registry.gd`

---

## Out of Scope

- Story 001: CardData and CardEffect class definitions (prerequisite)
- Story 003: Authoring the actual .tres files that this registry loads
- Story 004: Description variable substitution (separate concern)
- Draft pool weighted selection (belongs to Reward System)
- Deck limit enforcement (belongs to Deck Building System)
- Runtime mutation or `duplicate_deep()` (post-MVP)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit test — must pass (`tests/unit/card_registry/`)
**Gate level**: BLOCKING
**Status**: [x] `tests/unit/card_registry/card_registry_test.gd` — 10 test cases

### QA Test Cases

| ID | Scenario | Input | Expected Result | Pass/Fail |
|----|----------|-------|-----------------|-----------|
| T-002-01 | `get_card()` returns correct resource | Registry loaded with fixture cards; call `get_card(&"quick_draw")` | Returns the `CardData` with `card_id == &"quick_draw"` | [ ] |
| T-002-02 | `get_card()` returns null for unknown id | Call `get_card(&"nonexistent")` | Returns `null`; no crash | [ ] |
| T-002-03 | `get_cards_by_archetype()` filters correctly | Registry with 5 GUNSLINGER and 3 DRIFTER cards; call `get_cards_by_archetype(Enums.CardArchetype.GUNSLINGER)` | Returns array of size 5; every element has `archetype == GUNSLINGER` | [ ] |
| T-002-04 | `get_cards_by_rarity()` filters correctly | Registry with 4 COMMON and 2 RARE cards; call `get_cards_by_rarity(Enums.CardRarity.RARE)` | Returns array of size 2; every element has `rarity == RARE` | [ ] |
| T-002-05 | `get_all_cards()` returns full set | Registry with 8 total cards loaded | Returns array of size 8 | [ ] |
| T-002-06 | Duplicate card_id: warning emitted, last-loaded wins | Two fixture .tres files with `card_id == &"dupe_card"`; load both | `push_warning` called; `get_card(&"dupe_card")` returns the second-loaded resource | [ ] |
| T-002-07 | Missing card_id: resource rejected | Fixture .tres with `card_id == &""`; attempt load | `push_error` called; resource not in index; `get_all_cards().size()` does not include it | [ ] |
| T-002-08 | `get_starter_deck(GUNSLINGER)` returns 8 cards | Fixture cards tagged with `&"starter_gunslinger"`; call `get_starter_deck(GUNSLINGER)` | Returns array of size 8; all cards are COMMON or NEUTRAL archetype | [ ] |
| T-002-09 | `get_starter_deck()` returns only COMMON rarity | Same fixture as T-002-08 | Every card in result has `rarity == COMMON` | [ ] |
| T-002-10 | Invalid upgrade reference: warning emitted at startup | Fixture card with `upgrade_card_id == &"ghost_card"` that does not exist in index | `push_warning` called during `_ready()`; base card loads normally | [ ] |
| T-002-11 | `get_cards_by_type()` filters correctly | Registry with 3 ATTACK, 2 SKILL, 1 POWER cards | `get_cards_by_type(ATTACK)` returns 3; `get_cards_by_type(POWER)` returns 1 | [ ] |
| T-002-12 | Performance: 25 cards load under 100ms | Load 25 fixture .tres files | Elapsed time from `_ready()` start to index complete is under 100ms | [ ] |

---

## Dependencies

- **Depends on**: Story 001 (CardData and CardEffect classes must exist before registry can load instances)
- **Depends on**: Entity Framework Story 001 (Enums autoload — `Enums.CardArchetype`, `Enums.CardRarity`, `Enums.CardType` must be accessible)
- **Unlocks**: Story 003 (starter .tres files are what this registry loads), Story 004 (substitution reads CardData via registry), all downstream systems (Card Hand, Combat, Deck Building, Reward) that call `CardRegistry.get_card()` at runtime
