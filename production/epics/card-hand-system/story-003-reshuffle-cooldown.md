# Story 003: Reshuffle and Per-Slot Cooldown

> **Epic**: Card Hand System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-hand-system.md`
**Requirement**: `TR-HA-003`, `TR-HA-004`

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture
**ADR Decision Summary**: When draw pile empties and a draw is triggered, discard pile is shuffled using the same seeded RNG (advanced state) and becomes the new draw pile. Per-slot cooldowns are integer frame counters from `CardData.cooldown_frames`, tracked in `_slot_cooldowns` array, decrement per physics frame, pause during hit-stop.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Same RNG instance from story-001 continues advancing — seeded RNG state is preserved between shuffles. No post-cutoff API risk.

**Control Manifest Rules (Foundation/Core)**:
- Required: All gameplay timers count physics frames — `_slot_cooldowns` is an integer array
- Required: Buffer, animation, and camera timers freeze during hit-stop — slot cooldown timers freeze too

---

## Acceptance Criteria

- [ ] `_try_reshuffle_then_draw(slot: int) -> void` checks if `_discard_pile` is non-empty before reshuffling
- [ ] If discard pile non-empty: shuffle `_discard_pile` into `_draw_pile` using the same `_rng` instance (advancing its state); clear `_discard_pile`; emit `draw_pile_reshuffled()`; then draw top card into `slot`
- [ ] If both draw and discard piles are empty: slot remains null; `push_warning()` logged; no signal emitted
- [ ] `signal draw_pile_reshuffled()` typed (no parameters)
- [ ] `_slot_cooldowns: Array[int]` initialized to all-zeros (size HAND_SIZE) in `start_encounter()`
- [ ] When a card is drawn into a slot (`_execute_draw_into_slot()`): if `CardData.cooldown_frames > 0`, set `_slot_cooldowns[slot] = card.cooldown_frames`; else set to 0
- [ ] `_physics_process`: for each slot, if `_slot_cooldowns[slot] > 0` and NOT `_frozen`: decrement by 1
- [ ] Cooldown timers do NOT decrement when `_frozen = true` (hit-stop)
- [ ] `get_slot_cooldown(slot: int) -> int` returns `_slot_cooldowns[slot]`
- [ ] Card play validation in story-002 checks `_slot_cooldowns[slot] == 0` — this story ensures that contract is upheld
- [ ] Cooldowns cleared on `end_encounter()`: `_slot_cooldowns.fill(0)`

---

## Implementation Notes

From GDD UTD.3 (Empty Draw Pile) and CP.3 (Card Cooldown):

```gdscript
func _try_reshuffle_then_draw(slot: int) -> void:
    if _discard_pile.is_empty():
        push_warning("CardHandSystem: draw and discard piles both empty — slot %d remains empty" % slot)
        return

    # Shuffle discard into draw pile — same RNG advances state
    _draw_pile = _discard_pile.duplicate()
    _discard_pile.clear()
    _shuffle_array(_draw_pile)  # uses same _rng from story-001
    draw_pile_reshuffled.emit()

    # Now draw
    if not _draw_pile.is_empty():
        _execute_draw_into_slot(slot)

func _execute_draw_into_slot(slot: int) -> void:
    if _draw_pile.is_empty():
        _try_reshuffle_then_draw(slot)
        return
    var card: CardData = _draw_pile.pop_front()
    _hand_slots[slot] = card
    # Set cooldown if card has one
    _slot_cooldowns[slot] = card.cooldown_frames if card.cooldown_frames > 0 else 0
    card_drawn.emit(card, slot)

func _physics_process(_delta: float) -> void:
    if _frozen:
        return
    # Cooldown countdowns
    for i in range(HAND_SIZE):
        if _slot_cooldowns[i] > 0:
            _slot_cooldowns[i] -= 1
    # Pending draws (from story-002)
    # ...
```

Note: `CardData.cooldown_frames` is a field on the CardData Resource (defined in Card Data System / ADR-0004). Cards with `cooldown_frames = 0` have no cooldown restriction.

Formula F.3 (Reshuffle Frequency): `reshuffles = floor(cards_played / (deck_size - HAND_SIZE))`. With 8-card deck: reshuffle every 4 card plays.

---

## Out of Scope

- Story 001: Initial shuffle and draw (uses same `_rng` and `_shuffle_array()` defined there)
- Story 002: `_execute_draw_into_slot()` is called from story-002's pending draw logic; this story adds the cooldown assignment and reshuffle trigger within it
- Story 004: `get_slot_cooldown()` is a query function implemented in that story

---

## QA Test Cases

- **AC-1**: Reshuffle when draw pile empty
  - Given: Draw pile empty; discard pile has 4 cards; slot 0 pending draw
  - When: `_try_reshuffle_then_draw(0)` called
  - Then: `_discard_pile` is now empty; `_draw_pile` has 4 cards (shuffled); `draw_pile_reshuffled` emits; slot 0 receives top card from new draw pile; `card_drawn` emits

- **AC-2**: Both piles empty — warning logged
  - Given: Both `_draw_pile` and `_discard_pile` empty
  - When: `_try_reshuffle_then_draw(0)` called
  - Then: `push_warning()` called; `_hand_slots[0]` remains null; no crash; `draw_pile_reshuffled` NOT emitted

- **AC-3**: Reshuffle uses same RNG (advancing state)
  - Given: `_rng` seeded with seed X; draw pile exhausted; discard has 4 cards
  - When: Reshuffle occurs
  - Then: New draw pile order is deterministic given seed X and how many `randi_range()` calls were made before — same seed + same play history = same reshuffle order. Verified by running same encounter twice.

- **AC-4**: Cooldown set on draw
  - Given: Card with `cooldown_frames = 30` drawn into slot 2
  - When: `_execute_draw_into_slot(2)` executes
  - Then: `_slot_cooldowns[2] == 30`

- **AC-5**: Cooldown decrements each frame
  - Given: `_slot_cooldowns[2] = 15`; `_frozen = false`
  - When: 5 physics frames elapse
  - Then: `_slot_cooldowns[2] == 10`

- **AC-6**: Cooldown pauses during hit-stop
  - Given: `_slot_cooldowns[2] = 15`; `_frozen = true`
  - When: 5 physics frames elapse
  - Then: `_slot_cooldowns[2] == 15` (unchanged)

- **AC-7**: Cooldown blocks play (integration with story-002 validation)
  - Given: Slot 2 has a card; `_slot_cooldowns[2] = 5`
  - When: `try_play_card(2, ...)` called
  - Then: Returns false; `card_play_rejected(2, &"on_cooldown")` emits

- **AC-8**: Cooldown cleared on end_encounter
  - Given: `_slot_cooldowns = [10, 0, 5, 0]`
  - When: `end_encounter()` called
  - Then: `_slot_cooldowns = [0, 0, 0, 0]`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_hand/reshuffle_cooldown_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — CardData Resource with `cooldown_frames: int` field
- Depends on: Story 001 (Deck and Hand) — `_rng`, `_shuffle_array()`, `_draw_pile`, `_discard_pile` data structures must exist
- Depends on: Story 002 (Use-to-Draw) — `_execute_draw_into_slot()` is defined and called from story-002's draw scheduling logic; this story extends it with cooldown assignment
- Unlocks: Story 004 (Hand Queries — `get_slot_cooldown()` reads `_slot_cooldowns` populated here)
