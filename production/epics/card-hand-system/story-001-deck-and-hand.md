# Story 001: Deck and Hand Initialization

> **Epic**: Card Hand System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-hand-system.md`
**Requirement**: `TR-HA-002`, `TR-HA-005`

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture; ADR-0009: Damage Pipeline
**ADR Decision Summary**: Deck is stored as `Array[StringName]` of card IDs. CardData resolved via `CardRegistry.get_card()` at encounter start. Seeded `RandomNumberGenerator` for shuffle. Hand has `HAND_SIZE` slots. `end_encounter()` returns all cards to deck array.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `RandomNumberGenerator` API stable. `duplicate_deep()` required for Resources with nested sub-resources (available since 4.5 — confirmed available in 4.6). Do NOT use `duplicate()` on CardData with Array[CardEffect].

**Control Manifest Rules (Foundation/Core)**:
- Required: Deck stored as `Array[StringName]` of card IDs — reconstitute CardData via CardRegistry at encounter start
- Required: Static game data uses Godot Resources (.tres) — CardData is a Resource
- Required: Use `duplicate_deep()` when copying Resources with nested sub-resources
- Forbidden: Never store game data in JSON/YAML

---

## Acceptance Criteria

- [ ] `CardHandSystem` class exists: `class_name CardHandSystem extends Node`
- [ ] `const HAND_SIZE: int = 4` defined as a tuning constant
- [ ] `start_encounter(deck: Array[StringName], rng_seed: int) -> void` performs full initialization:
  - Resolves each card ID via `CardRegistry.get_card(id)` → Array of CardData
  - If a card ID is not found, logs `push_error()` and skips that card
  - Creates draw pile as a shuffled copy of the resolved deck
  - Shuffle uses `RandomNumberGenerator` seeded with `rng_seed`
  - Deals `HAND_SIZE` cards from draw pile into `_hand_slots: Array[CardData]` (null for empty slots)
  - Remaining cards stay in `_draw_pile: Array[CardData]`
  - `_discard_pile: Array[CardData]` starts empty
- [ ] `signal hand_ready()` emits at end of `start_encounter()` after dealing is complete
- [ ] `end_encounter() -> Array[StringName]` collects all cards from `_hand_slots` + `_draw_pile` + `_discard_pile`, returns their card IDs as `Array[StringName]`
- [ ] `signal hand_cleared()` emits at end of `end_encounter()`
- [ ] Seeded RNG: calling `start_encounter()` twice with the same `rng_seed` produces identical draw order
- [ ] After `end_encounter()`: total card count returned equals total cards provided to `start_encounter()` (no cards lost)
- [ ] `get_draw_pile_count() -> int` returns `_draw_pile.size()`
- [ ] `get_discard_pile_count() -> int` returns `_discard_pile.size()`

---

## Implementation Notes

From GDD DH.1–DH.4 and EL.1–EL.2:

```gdscript
class_name CardHandSystem extends Node

const HAND_SIZE: int = 4
const DRAW_DELAY: int = 6    # frames — tuning knob
const RESHUFFLE_DELAY: int = 0  # frames

var _hand_slots: Array[CardData] = []    # size = HAND_SIZE, null = empty slot
var _draw_pile: Array[CardData] = []
var _discard_pile: Array[CardData] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

signal hand_ready()
signal hand_cleared()
signal card_played(card_data: CardData, slot_index: int)
signal card_drawn(card_data: CardData, slot_index: int)
signal card_play_rejected(slot_index: int, reason: StringName)
signal draw_pile_reshuffled()

func start_encounter(deck: Array[StringName], rng_seed: int) -> void:
    _rng.seed = rng_seed
    _hand_slots.resize(HAND_SIZE)
    _hand_slots.fill(null)
    _draw_pile.clear()
    _discard_pile.clear()

    # Resolve card IDs to CardData
    var resolved_cards: Array[CardData] = []
    for card_id in deck:
        var card: CardData = CardRegistry.get_card(card_id)
        if card == null:
            push_error("CardHandSystem: card ID '%s' not found in registry" % card_id)
            continue
        resolved_cards.append(card)

    # Shuffle into draw pile
    _draw_pile = resolved_cards.duplicate()  # shallow copy of references — CardData is a Resource
    _shuffle_array(_draw_pile)

    # Deal opening hand
    for i in range(HAND_SIZE):
        if _draw_pile.is_empty():
            break
        _hand_slots[i] = _draw_pile.pop_front()

    hand_ready.emit()

func _shuffle_array(arr: Array) -> void:
    for i in range(arr.size() - 1, 0, -1):
        var j: int = _rng.randi_range(0, i)
        var temp = arr[i]
        arr[i] = arr[j]
        arr[j] = temp

func end_encounter() -> Array[StringName]:
    var all_cards: Array[CardData] = []
    for card in _hand_slots:
        if card != null:
            all_cards.append(card)
    all_cards.append_array(_draw_pile)
    all_cards.append_array(_discard_pile)

    var card_ids: Array[StringName] = []
    for card in all_cards:
        card_ids.append(card.card_id)

    _hand_slots.fill(null)
    _draw_pile.clear()
    _discard_pile.clear()

    hand_cleared.emit()
    return card_ids
```

Formula F.2 (Opening Hand Probability): `P_in_hand = HAND_SIZE / deck_size`. With 8 cards and HAND_SIZE=4, P = 50%.

---

## Out of Scope

- Story 002: Card play execution (use-to-draw cycle)
- Story 003: Reshuffle mechanics and per-slot cooldown tracking
- Story 004: Hand state query methods

---

## QA Test Cases

- **AC-1**: Correct distribution after start_encounter
  - Given: 8-card deck, HAND_SIZE = 4
  - When: `start_encounter(deck, seed)` called
  - Then: `_hand_slots` has 4 non-null cards; `_draw_pile` has 4 cards; `_discard_pile` is empty; `hand_ready()` emits

- **AC-2**: Seeded RNG reproducibility
  - Given: Same 8-card deck, same rng_seed
  - When: `start_encounter()` called twice (with `end_encounter()` between)
  - Then: Draw pile order is identical both times (same cards in same positions)

- **AC-3**: Different seeds produce different order
  - Given: Same 8-card deck, two different rng seeds (1234 vs 5678)
  - When: `start_encounter()` called with each seed
  - Then: Draw pile order is (very likely) different — not a strict test, more of a sanity check

- **AC-4**: end_encounter returns all cards
  - Given: 8-card deck dealt; 2 cards played (in discard), 1 in draw pile, 3 in hand, 1 empty slot
  - When: `end_encounter()` called
  - Then: Returns Array[StringName] with exactly 7 card IDs (8 - 1 missing due to empty slot after play... wait)
  - Correction: Returns all 8 card IDs — played cards are in discard, drawn replacement is in hand. All 8 accounted for.
  - Then: `hand_cleared()` emits; all internal arrays cleared

- **AC-5**: Unknown card ID skipped with error
  - Given: Deck array contains `&"nonexistent_card"`
  - When: `start_encounter()` called
  - Then: `push_error()` called with the card ID; remaining valid cards dealt normally; no crash

- **AC-6**: Deck smaller than HAND_SIZE
  - Given: 3-card deck, HAND_SIZE = 4
  - When: `start_encounter()` called
  - Then: All 3 cards dealt into slots 0–2; slot 3 is null; `_draw_pile` is empty; no crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_hand/deck_and_hand_test.gd` — must exist and pass
**Status**: [x] `tests/unit/card_hand/deck_and_hand_test.gd` — 10 test cases

---

## Dependencies

- Depends on: Entity Framework epic (complete) — CardRegistry autoload with `get_card(id: StringName) -> CardData`
- Depends on: Card Data System (ADR-0004) — CardData Resource class with `card_id: StringName` field
- Unlocks: Story 002 (Use-to-Draw — requires initialized hand/draw/discard data structures)
- Unlocks: Story 003 (Reshuffle and Cooldown — uses `_draw_pile` and `_discard_pile`)
- Unlocks: Story 004 (Hand Queries — queries the hand/pile state initialized here)
