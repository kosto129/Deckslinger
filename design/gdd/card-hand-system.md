# Card Hand System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 2 (Your Deck Is Your Identity), Pillar 3 (Adapt or Die)

## Summary

The Card Hand System manages the player's active hand of cards during combat:
draw pile construction, use-to-draw cycling, card play execution, hand state
tracking, and the interface between player input and card effects. It is the
runtime engine for Deckslinger's core mechanic — the ever-shifting hand.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Card Data System, Input System`

## Overview

The Card Hand System is the beating heart of Deckslinger's moment-to-moment
gameplay. It takes a deck (an ordered list of CardData references from the
Deck Building System), shuffles it into a draw pile, deals an opening hand of
`HAND_SIZE` cards, and manages the use-to-draw cycle that makes every card
play reshape the player's options. When the player plays a card (via Input
System buffered action), the Card Hand System removes it from the hand,
triggers the Combat System to execute its effects, and immediately draws the
next card from the draw pile into the vacated slot. When the draw pile empties,
the discard pile is shuffled and becomes the new draw pile. The hand is never
static — it flows. The system owns the hand state (which cards are where) but
delegates effect execution to the Combat System and visual display to the Card
Hand UI.

## Player Fantasy

Your hand is alive. You play a card — your sword swings — and before the
recovery frames end, a new card slides into the gap. What was a defensive
hand is now aggressive. What was a hand full of movement options now has a
burst damage card you've been waiting for. You don't control what comes
next, but you built the deck, so every draw is a consequence of your
choices. The hand flows like a card trick: play, draw, play, draw. The best
players read two moves ahead: "If I play this card now, I'll draw... and THAT
opens up..." The hand is the improvisation engine. It's what makes each 30
seconds of combat feel like a jazz solo — structured chaos, where mastery is
adapting to what you're dealt.

## Detailed Rules

### Deck and Hand Structure

**DH.1 — Deck Composition**

At encounter start, the Card Hand System receives the player's current deck
from the Run State Manager as an `Array[StringName]` of card IDs. It looks up
each ID via `CardRegistry.get_card()` to get the full CardData.

**DH.2 — Draw Pile**

The draw pile is a shuffled copy of the deck. Shuffle uses a seeded RNG
(`RandomNumberGenerator`) with the seed set at encounter start. The seed is
derived from the run seed + room index, ensuring reproducible draws for
replay/debug but different sequences per room.

**DH.3 — Discard Pile**

Played cards go to the discard pile. The discard pile is an ordered list
(FIFO — first played is at the bottom). When the draw pile empties and a draw
is needed, the discard pile is shuffled and becomes the new draw pile.

**DH.4 — Hand Slots**

The hand has `HAND_SIZE` slots (default: 4). Each slot holds exactly one
CardData reference or is empty. Slots are indexed 0 through `HAND_SIZE - 1`,
corresponding to card_1 through card_4 input actions.

| Slot | Input Action | KB/M | Gamepad |
|------|-------------|------|---------|
| 0 | card_1 | 1 | D-Pad Up |
| 1 | card_2 | 2 | D-Pad Right |
| 2 | card_3 | 3 | D-Pad Down |
| 3 | card_4 | 4 | D-Pad Left |

### Use-to-Draw Mechanic

**UTD.1 — Core Rule**

When a card is played from a hand slot:
1. Card is removed from the slot (slot becomes temporarily empty)
2. Card is added to the discard pile
3. Combat System executes the card's effects
4. A new card is drawn from the draw pile into the vacated slot
5. If the drawn card has `cooldown_frames > 0`, it enters cooldown state

Steps 1-3 happen simultaneously (same frame). Step 4 happens on the next
frame after the card play animation begins (visual draw delay for readability).

**UTD.2 — Draw Timing**

The replacement card is drawn `DRAW_DELAY` frames after the card is played.
This delay is purely visual — the card is logically assigned to the slot
immediately but appears in the UI after the delay. This gives the player a
moment to register the gap before the new card fills it.

**UTD.3 — Empty Draw Pile**

When a draw is triggered and the draw pile is empty:
1. Check if discard pile has cards
2. If yes: shuffle discard pile → becomes new draw pile → draw from it
3. If both empty: no draw occurs. The slot remains empty. This should only
   happen if the deck has fewer cards than `HAND_SIZE` (prevented by
   `MIN_DECK_SIZE` from Card Data System)

**UTD.4 — Additional Draws**

Some card effects include `DRAW_CARDS` (draw extra cards beyond the standard
use-to-draw). These draws:
- Fill empty slots first (left to right)
- If all slots are full, the drawn cards are placed at the top of the draw
  pile (not discarded, not lost)
- Additional draws happen after the standard use-to-draw replacement

### Card Play Rules

**CP.1 — Play Validation**

A card play is valid when ALL of these are true:
1. The player is in IDLE or RUN animation state (not locked)
2. The input mode is GAMEPLAY (not UI)
3. The target slot contains a card (not empty)
4. The card in the target slot is not on cooldown
5. The player entity lifecycle is ACTIVE (not STUNNED, DYING, etc.)

If any condition fails, the card play is rejected. The Input System's buffer
may hold the action — when conditions become valid, the buffered play fires.

**CP.2 — Play Execution**

```
1. Input System: consume_buffered_action("card_N") returns true
2. Card Hand System validates play (CP.1)
3. If valid:
   a. Remove card from slot → add to discard pile
   b. Emit card_played(card_data, slot_index)
   c. Call CombatSystem.execute_card(card_data, aim_direction, player_entity)
   d. Schedule draw into vacated slot after DRAW_DELAY frames
4. If invalid:
   a. Emit card_play_rejected(slot_index, reason)
   b. No action taken
```

**CP.3 — Card Cooldown**

Cards with `cooldown_frames > 0` (from CardData) cannot be played for that
many frames after being drawn into the hand. During cooldown:
- The card is visible in the slot but dimmed (visual state for Card Hand UI)
- The slot reports as "not playable" to play validation
- Cooldown timer counts down each physics frame
- Cooldown timer pauses during hit-stop (consistent with all frame counters)

### Encounter Lifecycle

**EL.1 — Encounter Start**

```
1. Receive deck (Array[StringName]) from Run State Manager
2. Resolve all card IDs to CardData via CardRegistry
3. Shuffle deck into draw pile (seeded RNG)
4. Deal HAND_SIZE cards from draw pile into hand slots (left to right)
5. Apply cooldowns on any drawn cards with cooldown_frames > 0
6. Emit hand_ready()
7. Player can now play cards
```

**EL.2 — Encounter End**

```
1. Room Encounter System signals encounter complete
2. All cards in hand + discard + draw pile are returned to the deck
3. Deck state (card IDs, no order) is saved back to Run State Manager
4. Hand state is cleared
5. Emit hand_cleared()
```

Cards are never permanently lost during an encounter. Every card in the deck
at encounter start is in the deck at encounter end, regardless of hand/draw/
discard state.

### Hand State Queries

The Card Hand System exposes state for UI and other systems:

```gdscript
# Hand state
func get_card_in_slot(slot: int) -> CardData  # null if empty
func get_hand() -> Array[CardData]  # all cards currently in hand (may include nulls for empty slots)
func get_hand_size() -> int  # number of non-empty slots
func is_slot_playable(slot: int) -> bool  # true if card present, not on cooldown, player not locked
func get_slot_cooldown(slot: int) -> int  # remaining cooldown frames (0 = ready)

# Pile state
func get_draw_pile_count() -> int
func get_discard_pile_count() -> int
func get_deck_size() -> int  # total cards across all piles + hand

# Signals
signal card_played(card_data: CardData, slot_index: int)
signal card_drawn(card_data: CardData, slot_index: int)
signal card_play_rejected(slot_index: int, reason: StringName)
signal hand_ready()
signal hand_cleared()
signal draw_pile_reshuffled()
```

## Formulas

**F.1 — Deck Cycling Rate**

How quickly the player sees their full deck.

```
Variables:
  deck_size    = total cards in deck
  HAND_SIZE    = cards in hand (default: 4)

Output:
  full_cycle   = number of card plays to see every card once (average)

Formula:
  full_cycle = deck_size - HAND_SIZE
  (After dealing initial hand, remaining cards are in draw pile.
   Each play draws one card. After deck_size - HAND_SIZE plays,
   draw pile empties, discard reshuffles.)

Example (8-card deck, 4-card hand):
  full_cycle = 8 - 4 = 4 plays to empty draw pile
  After 4 plays: all 8 cards have been in hand at least once.
  Reshuffle occurs. Second cycle begins.

Example (20-card deck, 4-card hand):
  full_cycle = 20 - 4 = 16 plays to empty draw pile
  Much longer before seeing the full deck. Less predictable.
```

**F.2 — Card Appearance Probability**

Probability of a specific card being in the opening hand.

```
Variables:
  deck_size = total cards in deck
  HAND_SIZE = cards dealt (default: 4)

Output:
  P_in_hand = probability a specific card is in the opening hand

Formula:
  P_in_hand = HAND_SIZE / deck_size

Example (8-card deck):
  P_in_hand = 4/8 = 50% chance any specific card is in opening hand

Example (20-card deck):
  P_in_hand = 4/20 = 20% chance
```

This is why deck trimming matters — smaller decks mean more consistent access
to key cards (Pillar 2: Your Deck Is Your Identity).

**F.3 — Reshuffle Frequency**

How often the discard pile reshuffles into the draw pile.

```
Variables:
  deck_size    = total cards in deck
  HAND_SIZE    = 4
  cards_played = total card plays in the encounter

Output:
  reshuffles = number of times the discard has been reshuffled

Formula:
  reshuffles = floor(cards_played / (deck_size - HAND_SIZE))
  (approximate — extra draws from DRAW_CARDS effects accelerate this)

Example (8-card deck, 12 plays):
  reshuffles = floor(12 / 4) = 3 reshuffles
  Player has cycled their deck 3+ times in the encounter

Example (20-card deck, 12 plays):
  reshuffles = floor(12 / 16) = 0 reshuffles
  Player hasn't seen their full deck yet
```

**F.4 — Effective Hand Throughput**

Cards played per second of real combat time, considering commitment frames.

```
Variables:
  avg_commitment = average total_commitment_frames across cards in deck
  FRAME_RATE     = 60

Output:
  cards_per_second = throughput rate

Formula:
  cards_per_second = FRAME_RATE / avg_commitment

Example (avg commitment = 20 frames):
  cards_per_second = 60 / 20 = 3.0 cards/second
  At 3 cards/second with an 8-card deck: full cycle every ~1.3 seconds

Example (avg commitment = 30 frames):
  cards_per_second = 60 / 30 = 2.0 cards/second
  Slower, weightier combat. Full cycle every 2 seconds.
```

## Edge Cases

- **Play card from slot that's empty**: Input System buffers `card_3`, but by
  the time the buffer is consumed, slot 3 is empty (card was already played
  or never drawn). Play validation fails (CP.1 condition 3). No action taken.
  `card_play_rejected` emits with reason `"empty_slot"`.

- **All 4 slots empty simultaneously**: Only possible if deck has fewer than 4
  cards. `MIN_DECK_SIZE = 6` from Card Data System prevents this in normal
  play. If it somehow occurs (debug/cheat), the player has no cards to play.
  Combat continues — player can still move and dodge but cannot attack. The
  hand is empty until encounter ends.

- **Draw pile and discard pile both empty, draw triggered**: No card to draw.
  Slot remains empty. This happens only if deck_size < HAND_SIZE (should be
  prevented by validation). Log a warning.

- **Card played during hit-stop**: Player cannot play during hit-stop because
  the Animation State Machine is frozen (not in IDLE/RUN). The input is
  buffered. When hit-stop ends and the player returns to an actionable state
  (after recovery), the buffer fires.

- **DRAW_CARDS effect with full hand**: Extra drawn cards cannot fit in the
  hand. They are placed on top of the draw pile in draw order. Player sees
  them on the next cycle. No cards are lost.

- **Reshuffle during combat (draw pile empty)**: Discard pile is shuffled
  (same seeded RNG, advanced state). `draw_pile_reshuffled` signal fires.
  UI plays a brief shuffle animation on the deck indicator. Draw proceeds
  normally from the new draw pile.

- **Card play rejected due to cooldown**: `card_play_rejected` emits with
  reason `"on_cooldown"`. UI flashes the dimmed card briefly to indicate
  the attempt. The input is consumed (not re-buffered). Player must wait.

- **Player stunned with full hand**: Cards remain in hand. No card plays are
  possible during stun (entity lifecycle is STUNNED, fails CP.1 condition 5).
  When stun clears, hand is unchanged and cards are immediately playable.

- **Encounter ends with cards on cooldown**: Cooldown state is cleared on
  encounter end (EL.2). No cooldown carries between encounters.

- **Two card play inputs in the same frame**: Input System priority rules
  handle this — `card_1` has higher priority than `card_2` (per Input System
  B.6). Only one card is played per frame. The second input is lost (not
  buffered, because a different action already consumed the buffer slot).

- **Deck modification mid-encounter**: Not supported in MVP. The deck is fixed
  at encounter start and restored at encounter end. Future features (mid-combat
  card gain) would need to add cards directly to the discard pile.

- **Card's CardData not found in CardRegistry**: Card ID was valid when deck
  was built but registry changed (should never happen in production). Log an
  error. Skip the card during deal — treat it as if it doesn't exist. Deck
  functions with remaining cards.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Card Data System | `CardRegistry.get_card()` for resolving card IDs to CardData | Hard |
| Upstream | Input System | `consume_buffered_action("card_1..4")` for play input | Hard |
| Downstream | Combat System | `CombatSystem.execute_card()` for effect resolution | Hard |
| Downstream | Animation State Machine | Card play triggers action sequence via AnimationComponent | Hard |
| Downstream | Card Hand UI | `card_played`, `card_drawn` signals for visual updates | Hard |
| Downstream | Deck Building System | Receives modified deck between encounters | Hard |
| Downstream | Run State Manager | Reads/writes current deck state between encounters | Hard |
| Downstream | Status Effect System | Cards with APPLY_STATUS route through Combat System | Soft |

Public API:

```gdscript
# Encounter lifecycle
func start_encounter(deck: Array[StringName], rng_seed: int) -> void
func end_encounter() -> Array[StringName]  # returns deck card IDs

# Card play (called by game loop checking input buffer)
func try_play_card(slot: int, aim_direction: Vector2) -> bool

# Hand queries
func get_card_in_slot(slot: int) -> CardData
func get_hand() -> Array[CardData]
func get_hand_size() -> int
func is_slot_playable(slot: int) -> bool
func get_slot_cooldown(slot: int) -> int

# Pile queries
func get_draw_pile_count() -> int
func get_discard_pile_count() -> int

# Signals
signal card_played(card_data: CardData, slot_index: int)
signal card_drawn(card_data: CardData, slot_index: int)
signal card_play_rejected(slot_index: int, reason: StringName)
signal hand_ready()
signal hand_cleared()
signal draw_pile_reshuffled()
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `HAND_SIZE` | 4 | 3–5 | Cards in hand. 3 = constrained, fast cycling, high pressure. 5 = many options, slower cycling, lower pressure. THE critical design lever. |
| `DRAW_DELAY` | 6 frames (100ms) | 3–12 | Visual delay before replacement card appears. Too fast = player can't track changes. Too slow = hand feels sluggish. |
| `INITIAL_DEAL_DELAY` | 4 frames (67ms) | 0–8 | Delay between each card dealt at encounter start. 0 = all at once. Higher = dramatic deal-in. |
| `RESHUFFLE_DELAY` | 0 frames | 0–15 | Pause before drawing after reshuffle. 0 = seamless. Higher = player notices the reshuffle. |

**Critical note on HAND_SIZE**: This is the #1 design risk identified in the
game concept. The difference between 3 and 4 cards fundamentally changes the
game feel:
- **3 cards**: Higher pressure, faster cycling, each card play is a bigger
  percentage of your options (33%). More "make any hand work" feel.
- **4 cards**: More options per moment, slightly slower cycling, each play is
  25% of options. More "hold the right card for the right moment" feel.

Both must be prototyped. The Card Hand System supports either without code
changes — it's a tuning knob.

## Acceptance Criteria

1. **GIVEN** encounter starts with 8-card deck and HAND_SIZE=4, **WHEN** hand
   is dealt, **THEN** 4 cards are in hand, 4 cards are in draw pile, 0 in
   discard.

2. **GIVEN** player plays card from slot 2, **WHEN** play is valid, **THEN**
   card is removed from slot, added to discard, Combat System executes effects,
   and a new card is drawn into slot 2 after DRAW_DELAY frames.

3. **GIVEN** 4 cards played from an 8-card deck, **WHEN** draw pile empties,
   **THEN** discard pile is shuffled into new draw pile, `draw_pile_reshuffled`
   fires, and next draw succeeds.

4. **GIVEN** player presses card_3 during animation lock, **WHEN** lock ends
   within Input System buffer window, **THEN** card 3 plays immediately on the
   first available frame.

5. **GIVEN** card with cooldown_frames=30 is drawn, **WHEN** 15 frames pass,
   **THEN** `is_slot_playable()` returns false, `get_slot_cooldown()` returns
   15.

6. **GIVEN** card with cooldown_frames=30 is drawn, **WHEN** 30 frames pass,
   **THEN** `is_slot_playable()` returns true, `get_slot_cooldown()` returns 0.

7. **GIVEN** DRAW_CARDS effect draws 2 extra cards with full hand, **WHEN**
   draws resolve, **THEN** extra cards are placed on top of draw pile, not
   discarded.

8. **GIVEN** encounter ends, **WHEN** `end_encounter()` called, **THEN** all
   cards (hand + draw + discard) are returned as a single deck array.

9. **GIVEN** empty slot 3, **WHEN** player tries to play card_3, **THEN**
   `card_play_rejected` fires with reason "empty_slot", no action taken.

10. **GIVEN** player is STUNNED, **WHEN** card play attempted, **THEN** play
    rejected (entity not ACTIVE), hand remains unchanged.

11. **GIVEN** 8-card deck, HAND_SIZE=4, **WHEN** opening hand probability
    calculated for any specific card, **THEN** P = 4/8 = 50%.

12. **GIVEN** `HAND_SIZE = 3` (tuning knob changed), **WHEN** encounter starts
    with 8-card deck, **THEN** 3 cards dealt, 5 in draw pile. System functions
    without code changes.

13. **GIVEN** hit-stop active, **WHEN** player presses card input, **THEN**
    input is buffered, card play fires after hit-stop + recovery completes.

14. **GIVEN** seeded RNG with same seed and room index, **WHEN** encounter
    starts twice, **THEN** draw order is identical both times.
