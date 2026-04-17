# Story 004: Hand State Queries

> **Epic**: Card Hand System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-hand-system.md`
**Requirement**: `TR-HA-004`, `TR-HA-005`

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture
**ADR Decision Summary**: CardHandSystem exposes a complete read-only query API for UI and other systems. Queries are O(1) or O(HAND_SIZE) — no complex lookups. `card_play_rejected` emits with a typed reason StringName when play validation fails.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API risk. All query methods are pure GDScript accessors.

**Control Manifest Rules (Foundation/Core)**:
- Required: Cross-system state access via public methods — systems read CardHandSystem state through this API only
- Forbidden: Never write cross-system state directly

---

## Acceptance Criteria

- [ ] `get_card_in_slot(slot: int) -> CardData` returns `_hand_slots[slot]` or null if empty/invalid index
- [ ] `get_hand() -> Array[CardData]` returns a copy of `_hand_slots` (size HAND_SIZE, may contain nulls for empty slots)
- [ ] `get_hand_size() -> int` returns count of non-null entries in `_hand_slots`
- [ ] `is_slot_playable(slot: int) -> bool` returns true if ALL of:
  - `slot` is a valid index
  - `_hand_slots[slot]` is not null
  - `_slot_cooldowns[slot] == 0`
  - Player entity lifecycle is ACTIVE
  - Player AnimationComponent `is_in_action()` returns false
- [ ] `get_slot_cooldown(slot: int) -> int` returns `_slot_cooldowns[slot]`; returns 0 for invalid slot
- [ ] `get_draw_pile_count() -> int` returns `_draw_pile.size()`
- [ ] `get_discard_pile_count() -> int` returns `_discard_pile.size()`
- [ ] `get_deck_size() -> int` returns total cards across hand + draw pile + discard pile (all non-null)
- [ ] `card_play_rejected` signal has exactly two typed parameters: `signal card_play_rejected(slot_index: int, reason: StringName)`
- [ ] All documented reason codes are used in `try_play_card()` (from story-002):
  - `&"empty_slot"` — slot contains no card
  - `&"on_cooldown"` — `_slot_cooldowns[slot] > 0`
  - `&"player_not_active"` — lifecycle is not ACTIVE
  - `&"player_locked"` — animation is in action (WINDUP/ACTIVE/RECOVERY)
- [ ] Query methods are safe to call before `start_encounter()` — return empty/zero values, no crash

---

## Implementation Notes

From GDD "Hand State Queries" section and CP.1 (Play Validation):

```gdscript
func get_card_in_slot(slot: int) -> CardData:
    if slot < 0 or slot >= HAND_SIZE:
        return null
    return _hand_slots[slot]

func get_hand() -> Array[CardData]:
    return _hand_slots.duplicate()  # return copy, not internal array reference

func get_hand_size() -> int:
    var count: int = 0
    for card in _hand_slots:
        if card != null:
            count += 1
    return count

func is_slot_playable(slot: int) -> bool:
    if slot < 0 or slot >= HAND_SIZE:
        return false
    if _hand_slots[slot] == null:
        return false
    if _slot_cooldowns[slot] > 0:
        return false
    if _player_entity == null:
        return false
    if _player_entity.get_lifecycle_state() != Enums.LifecycleState.ACTIVE:
        return false
    var anim: AnimationComponent = _player_entity.get_animation()
    if anim and anim.is_in_action():
        return false
    return true

func get_slot_cooldown(slot: int) -> int:
    if slot < 0 or slot >= HAND_SIZE:
        return 0
    return _slot_cooldowns[slot]

func get_draw_pile_count() -> int:
    return _draw_pile.size()

func get_discard_pile_count() -> int:
    return _discard_pile.size()

func get_deck_size() -> int:
    return get_hand_size() + _draw_pile.size() + _discard_pile.size()
```

Note: `get_hand()` returns a shallow copy of `_hand_slots` (the Array copy, not the CardData objects themselves). Callers must not modify the returned array. CardData objects are Resources — callers should not modify them either.

---

## Out of Scope

- Story 001: Data structure initialization
- Story 002: `try_play_card()` which calls `is_slot_playable()` logic internally
- Story 003: Cooldown tracking (this story reads `_slot_cooldowns`; story 003 owns the writes)
- Card Hand UI: Visual representation of playability state (UI reads via these queries)

---

## QA Test Cases

- **AC-1**: get_card_in_slot — happy path and edge cases
  - Given: `_hand_slots = [CardA, null, CardC, CardD]`
  - When: `get_card_in_slot(0)` called
  - Then: Returns CardA
  - When: `get_card_in_slot(1)` called
  - Then: Returns null
  - When: `get_card_in_slot(10)` called (out of bounds)
  - Then: Returns null without crash

- **AC-2**: get_hand returns copy (not reference)
  - Given: `_hand_slots` contains 3 cards
  - When: `get_hand()` called
  - Then: Returns Array of size 4; modifying the returned array does NOT change `_hand_slots`

- **AC-3**: get_hand_size counts non-null only
  - Given: `_hand_slots = [CardA, null, CardC, null]`
  - When: `get_hand_size()` called
  - Then: Returns 2

- **AC-4**: is_slot_playable — all conditions
  - Given: Slot 0 has a card; no cooldown; player ACTIVE; not in action
  - When: `is_slot_playable(0)` called
  - Then: Returns true
  - Given: Same but player is STUNNED
  - Then: Returns false
  - Given: Same (player ACTIVE) but `_slot_cooldowns[0] = 5`
  - Then: Returns false
  - Given: Same but `_hand_slots[0] == null`
  - Then: Returns false

- **AC-5**: get_slot_cooldown accuracy
  - Given: `_slot_cooldowns = [15, 0, 3, 0]`
  - When: `get_slot_cooldown(0)` called
  - Then: Returns 15
  - When: `get_slot_cooldown(2)` called
  - Then: Returns 3
  - When: `get_slot_cooldown(1)` called
  - Then: Returns 0

- **AC-6**: get_deck_size totals correctly
  - Given: Hand has 3 cards, draw pile has 2, discard has 1
  - When: `get_deck_size()` called
  - Then: Returns 6

- **AC-7**: Queries safe before start_encounter
  - Given: CardHandSystem instantiated but `start_encounter()` not yet called
  - When: All query methods called
  - Then: No crashes; `get_card_in_slot(0)` returns null; `get_hand_size()` returns 0; `get_deck_size()` returns 0; `is_slot_playable(0)` returns false

- **AC-8**: card_play_rejected signal parameters
  - Given: Slot 2 is on cooldown
  - When: `try_play_card(2, Vector2.RIGHT)` called
  - Then: `card_play_rejected` emits with `slot_index = 2` and `reason = &"on_cooldown"`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_hand/hand_queries_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — player EntityBase, AnimationComponent `is_in_action()`
- Depends on: Story 001 (Deck and Hand) — `_hand_slots`, `_draw_pile`, `_discard_pile` data structures
- Depends on: Story 002 (Use-to-Draw) — `try_play_card()` uses `is_slot_playable()` logic; `card_play_rejected` signal defined there
- Depends on: Story 003 (Reshuffle and Cooldown) — `_slot_cooldowns` populated by story-003
- Unlocks (cross-epic): Card Hand UI (subscribes to all signals, reads all query methods); Combat HUD pile count display
