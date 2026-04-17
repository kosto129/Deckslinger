# Story 002: Use-to-Draw Cycle

> **Epic**: Card Hand System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-hand-system.md`
**Requirement**: `TR-HA-001`, `TR-HA-005`

**ADR Governing Implementation**: ADR-0009: Damage Pipeline; ADR-0005: Input Buffering (implicit — card play triggers AnimationComponent which feeds into combat)
**ADR Decision Summary**: `try_play_card()` validates the play, removes card from slot, adds to discard, calls `CombatSystem.execute_card()`, then schedules a draw after `DRAW_DELAY` frames. Signals `card_played` and `card_drawn` emit at appropriate moments. Play validation checks: not in action, not stunned, slot not empty, slot not on cooldown.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API risk for core logic. Frame-based delay uses integer counter in `_physics_process`, not `Timer` (per Control Manifest: all gameplay timers count physics frames).

**Control Manifest Rules (Foundation/Core)**:
- Required: All gameplay timers count physics frames, not real-time seconds — `DRAW_DELAY` is a frame counter
- Required: Buffer, animation, and camera timers freeze during hit-stop
- Forbidden: Never use real-time (seconds/milliseconds) for gameplay timing

---

## Acceptance Criteria

- [ ] `try_play_card(slot: int, aim_direction: Vector2) -> bool` implements full play validation and execution
- [ ] Validation checks (all must be true to play):
  1. `slot` is a valid index (0 to HAND_SIZE-1)
  2. `_hand_slots[slot]` is not null (slot contains a card)
  3. Card in slot is not on cooldown (`_slot_cooldowns[slot] == 0`)
  4. Player entity lifecycle is ACTIVE (not STUNNED, DYING, etc.)
  5. Player AnimationComponent `is_in_action()` returns false (not locked)
- [ ] If validation fails: `card_play_rejected(slot, reason: StringName)` emits with reason; return false
  - Reason strings: `&"empty_slot"`, `&"on_cooldown"`, `&"player_not_active"`, `&"player_locked"`
- [ ] If validation passes:
  - Remove card from `_hand_slots[slot]` (slot becomes null)
  - Append card to `_discard_pile`
  - Emit `card_played(card_data, slot)`
  - Call `CombatSystem.execute_card(card_data, aim_direction, player_entity)`
  - Schedule draw: after `DRAW_DELAY` frames, draw into `slot` (tracked via `_pending_draws` dictionary)
  - Return true
- [ ] Draw scheduling: `_pending_draws: Dictionary` maps `slot_index → frames_remaining`
- [ ] `_physics_process`: decrement each `_pending_draws` counter; when counter reaches 0, execute draw into that slot
- [ ] Draw execution: pop front card from `_draw_pile`; set `_hand_slots[slot] = card`; emit `card_drawn(card, slot)`
- [ ] If `_draw_pile` is empty when draw executes: trigger reshuffle (story-003 handles reshuffle; this story calls `_try_reshuffle_then_draw(slot)`)
- [ ] `_pending_draws` frame counters freeze during hit-stop (`_frozen` flag)
- [ ] `card_played` signal typed: `signal card_played(card_data: CardData, slot_index: int)`
- [ ] `card_drawn` signal typed: `signal card_drawn(card_data: CardData, slot_index: int)`

---

## Implementation Notes

From GDD UTD.1–UTD.3 and CP.1–CP.2:

```gdscript
var _pending_draws: Dictionary = {}   # slot_index (int) → frames_remaining (int)
var _slot_cooldowns: Array[int] = []  # size = HAND_SIZE, 0 = ready
var _frozen: bool = false

func try_play_card(slot: int, aim_direction: Vector2) -> bool:
    # Validate
    if slot < 0 or slot >= HAND_SIZE:
        return false
    if _hand_slots[slot] == null:
        card_play_rejected.emit(slot, &"empty_slot")
        return false
    if _slot_cooldowns[slot] > 0:
        card_play_rejected.emit(slot, &"on_cooldown")
        return false
    if _player_entity.get_lifecycle_state() != Enums.LifecycleState.ACTIVE:
        card_play_rejected.emit(slot, &"player_not_active")
        return false
    if _player_entity.get_animation() and _player_entity.get_animation().is_in_action():
        card_play_rejected.emit(slot, &"player_locked")
        return false

    # Execute play
    var card: CardData = _hand_slots[slot]
    _hand_slots[slot] = null
    _discard_pile.append(card)
    card_played.emit(card, slot)
    CombatSystem.execute_card(card, aim_direction, _player_entity)

    # Schedule replacement draw
    _pending_draws[slot] = DRAW_DELAY

    return true

func _physics_process(_delta: float) -> void:
    if _frozen:
        return
    # Cooldown timers — decremented in story-003
    # Pending draws
    var slots_to_draw: Array[int] = []
    for slot in _pending_draws.keys():
        _pending_draws[slot] -= 1
        if _pending_draws[slot] <= 0:
            slots_to_draw.append(slot)
    for slot in slots_to_draw:
        _pending_draws.erase(slot)
        _execute_draw_into_slot(slot)

func _execute_draw_into_slot(slot: int) -> void:
    if _draw_pile.is_empty():
        _try_reshuffle_then_draw(slot)  # story-003 handles reshuffle
        return
    var card: CardData = _draw_pile.pop_front()
    _hand_slots[slot] = card
    card_drawn.emit(card, slot)
```

GDD Formula F.4 (Effective Hand Throughput): `cards_per_second = 60 / avg_commitment`. With avg 20-frame commitment: 3 cards/second. At 3 cards/sec with 8-card deck, full cycle every ~1.3 seconds.

---

## Out of Scope

- Story 001: Deck initialization and encounter lifecycle
- Story 003: `_try_reshuffle_then_draw()` implementation and per-slot cooldown countdown
- Story 004: `is_slot_playable()` and other query methods
- `CombatSystem.execute_card()` implementation — defined in Combat System epic; this story calls it as a dependency

---

## QA Test Cases

- **AC-1**: Successful card play — use-to-draw cycle
  - Given: Slot 2 has a card, player is ACTIVE, not in action, no cooldown; draw pile has 4 cards
  - When: `try_play_card(2, Vector2.RIGHT)` called
  - Then: Returns true; `_hand_slots[2] == null` immediately; card appended to `_discard_pile`; `card_played` emits; `CombatSystem.execute_card()` called; after `DRAW_DELAY` frames `_hand_slots[2]` has new card; `card_drawn` emits

- **AC-2**: Play rejected — empty slot
  - Given: Slot 1 is null
  - When: `try_play_card(1, Vector2.RIGHT)` called
  - Then: Returns false; `card_play_rejected(1, &"empty_slot")` emits; no other side effects

- **AC-3**: Play rejected — player locked
  - Given: Slot 0 has a card; player AnimationComponent `is_in_action()` returns true
  - When: `try_play_card(0, Vector2.RIGHT)` called
  - Then: Returns false; `card_play_rejected(0, &"player_locked")` emits

- **AC-4**: Play rejected — player stunned
  - Given: Slot 0 has a card; player lifecycle = STUNNED
  - When: `try_play_card(0, Vector2.RIGHT)` called
  - Then: Returns false; `card_play_rejected(0, &"player_not_active")` emits

- **AC-5**: Draw delay frame counting
  - Given: Card played from slot 2; `DRAW_DELAY = 6`
  - When: 5 physics frames elapse
  - Then: `_hand_slots[2]` is still null (draw not yet executed)
  - When: 1 more frame elapses (frame 6)
  - Then: `_hand_slots[2]` has new card; `card_drawn` emits

- **AC-6**: Draw delay pauses during hit-stop
  - Given: Card played from slot 2; `DRAW_DELAY = 6`; after 3 frames, `_frozen = true` (hit-stop)
  - When: 3 more frames elapse while frozen
  - Then: `_hand_slots[2]` still null — counter has not continued
  - When: `_frozen = false`; 3 more frames elapse
  - Then: Draw executes on frame 6 of unfrozen time

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_hand/use_to_draw_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — player EntityBase with lifecycle state, AnimationComponent `is_in_action()`, CombatSystem reference
- Depends on: Story 001 (Deck and Hand) — `_hand_slots`, `_draw_pile`, `_discard_pile` data structures must be initialized
- Depends on: Animation State Machine story-001 (State Machine Core) — `is_in_action()` method must exist
- Depends on: Combat System story-001 (Damage Pipeline) — `CombatSystem.execute_card()` must exist (can be a stub for isolated testing)
- Unlocks: Story 003 (Reshuffle and Cooldown — `_try_reshuffle_then_draw()` called from here; cooldowns decrement in shared `_physics_process`)
- Unlocks: Story 004 (Hand Queries — `is_slot_playable()` uses the same validation logic)
