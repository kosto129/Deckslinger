# Card Hand UI

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 2 (Your Deck Is Your Identity), Pillar 3 (Adapt or Die)

## Summary

The Card Hand UI renders the player's card hand during combat: card
positioning, archetype-based visual styling, slot states (playable, cooldown,
empty), draw/play animations, and the deck/discard pile indicators. It reads
from the Card Hand System and Card Data System, providing the visual layer
that makes the hand readable at a glance during fast real-time combat.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Card Hand System`

## Overview

The Card Hand UI is the player's constant companion during combat. It sits at
the bottom of the screen, showing 3-4 card slots in a slight arc, each
displaying the card's icon, archetype color, and slot number. The UI must be
readable at a glance — the player is fighting enemies and needs to know which
cards are available without pausing to read text. Archetype colors (red/blue/
yellow/white) provide instant identification. Rarity affects the card frame's
visual treatment (per Card Data System rarity visual register rules). When a
card is played, it animates out of the hand and a new card slides in from the
draw pile indicator. The hand always communicates three things: what you have,
what you just lost, and what you just gained.

## Player Fantasy

The hand lives at the bottom of the screen like a poker hand — always visible,
always shifting. You glance down and see red-red-blue-yellow. Two Gunslinger
attacks, a Drifter control card, and an Outlaw wildcard. You know your options
by color alone. You press 1 — the first red card launches upward and an enemy
takes damage. A new card slides into the gap: another blue. Your hand just
shifted from aggressive to defensive. You adapt. The hand's arc, the color
glow, the slide animation — they all make the cards feel like physical objects
in your hand, not abstract ability cooldowns.

## Detailed Rules

### Layout

**L.1 — Hand Position**

The hand is positioned at the bottom-center of the viewport:

| Property | Value |
|----------|-------|
| Anchor | Bottom center |
| Y offset | 8 px from bottom edge |
| Total width | `HAND_SIZE * (CARD_WIDTH + CARD_SPACING)` |
| Centered | Horizontally centered in viewport |

**L.2 — Card Slot Layout**

Cards are arranged in a slight arc for visual appeal:

| Property | Default |
|----------|---------|
| `CARD_WIDTH` | 28 px |
| `CARD_HEIGHT` | 36 px |
| `CARD_SPACING` | 4 px |
| `ARC_HEIGHT` | 3 px (max lift at center cards) |
| `ARC_ROTATION` | 2° (max tilt at outer cards) |

Arc calculation for slot `i` (0-indexed, `n` total slots):
```
center = (n - 1) / 2.0
offset = i - center  # -1.5 to 1.5 for 4 cards
arc_y = -ARC_HEIGHT * (1.0 - (offset / center) ** 2)
arc_rot = ARC_ROTATION * (offset / center)
```

**L.3 — Slot Numbering**

Each slot shows its hotkey number (1-4) in a small label above the card.
When gamepad is active, the label switches to the D-pad direction icon.
Driven by `input_device_changed` signal from Input System.

### Card Rendering

**CR.1 — Card Visual Components**

Each card slot renders:

| Element | Size | Description |
|---------|------|-------------|
| Card frame | 28×36 px | Border styled by rarity (flat/shimmer/glow/dimensional) |
| Card icon | 24×24 px | From `CardData.card_art`, centered in frame |
| Archetype tint | Frame overlay | Tinted by `CardData.card_color` (archetype color) |
| Slot number | 8×8 px label | Above card, shows hotkey |
| Cooldown overlay | 28×36 px | Semi-transparent dark overlay when on cooldown |
| Cooldown timer | Text | Remaining cooldown in frames/10 (rounded tenths of seconds) |

**CR.2 — Rarity Visual Register**

| Rarity | Frame Treatment |
|--------|----------------|
| COMMON | Flat border, no animation |
| UNCOMMON | Subtle border shimmer (2-frame loop) |
| RARE | Animated border glow + small archetype-colored particles |
| LEGENDARY | Full card glow + particle field + subtle idle animation |

**CR.3 — State Visualization**

| State | Visual |
|-------|--------|
| Playable | Full brightness, card icon visible |
| On cooldown | Darkened overlay, cooldown timer shown |
| Empty slot | Dim outline of card shape, no icon |
| Being played | Card animates upward and fades out |
| Being drawn | Card slides in from draw pile indicator |
| Hovered (gamepad) | Slight lift (3px up) + name tooltip |

### Animations

**AN.1 — Card Play Animation**

When a card is played from slot `i`:
1. Card scales up to 110% over 3 frames
2. Card moves upward 12px and fades to 0% opacity over 6 frames
3. Slot becomes empty (empty state visual)
4. After `DRAW_DELAY` frames: draw animation begins

**AN.2 — Card Draw Animation**

When a new card is drawn into slot `i`:
1. Card starts at draw pile indicator position (right side of hand area)
2. Card slides to slot `i` position over `DRAW_ANIM_FRAMES` frames (8 frames)
3. Card starts at 80% scale, reaches 100% at destination
4. Archetype color flash on arrival (brief 3-frame tint pulse)

**AN.3 — Initial Deal Animation**

At encounter start, cards deal into hand left-to-right:
1. Each card slides from draw pile to its slot
2. Staggered by `INITIAL_DEAL_DELAY` frames between cards
3. Same slide animation as draw but slightly slower (10 frames)

**AN.4 — Reshuffle Indicator**

When discard pile reshuffles into draw pile:
1. Discard count number briefly glows
2. Arrow animation from discard indicator to draw indicator
3. Draw count updates to new total
4. Duration: 15 frames

### Pile Indicators

**PI.1 — Draw Pile Indicator**

| Property | Value |
|----------|-------|
| Position | Right of hand, bottom-right area |
| Visual | Stack of cards icon + count number |
| Count | From `CardHandSystem.get_draw_pile_count()` |

**PI.2 — Discard Pile Indicator**

| Property | Value |
|----------|-------|
| Position | Left of hand, bottom-left area |
| Visual | Fanned cards icon + count number |
| Count | From `CardHandSystem.get_discard_pile_count()` |

Both indicators update in real-time as cards are played and drawn.

### Tooltip

**TT.1 — Hover Tooltip**

When a card slot is hovered (mouse hover or gamepad selection):
- Tooltip appears above the card showing:
  - `display_name`
  - `description` (with variable substitution)
  - `card_type` label
  - Commitment time: "Lock: Xms"
- Tooltip dismisses when hover ends or combat action begins
- Tooltip does NOT pause gameplay — player must read quickly

**TT.2 — Tooltip Position**

Tooltip renders above the hovered card, clamped to viewport bounds. If too
close to top edge, tooltip renders below the card instead.

### Input Integration

**II.1 — Slot Selection Feedback**

- KB/M: No hover state on slots (cards are played via number keys, not
  clicking). Mouse hover shows tooltip.
- Gamepad: D-pad highlights the corresponding slot with a selection indicator.
  Pressing the D-pad direction both selects AND plays the card (no two-step
  select-then-confirm).

**II.2 — Rejected Play Feedback**

When a card play is rejected (on cooldown, empty slot, player locked):
- Card slot flashes red for 4 frames
- Brief "cannot play" shake (2px horizontal, 3 frames)
- No sound in MVP (future: error buzz SFX)

## Formulas

**F.1 — Arc Position**

```
Variables:
  i           = slot index (0-indexed)
  n           = HAND_SIZE (total slots)
  CARD_WIDTH  = 28 px
  CARD_SPACING = 4 px
  ARC_HEIGHT  = 3 px
  ARC_ROTATION = 2 degrees

Output:
  slot_x      = horizontal position
  slot_y      = vertical position (negative = upward)
  slot_rot    = rotation in degrees

Formula:
  center = (n - 1) / 2.0
  offset = i - center
  slot_x = (i - center) * (CARD_WIDTH + CARD_SPACING)
  slot_y = -ARC_HEIGHT * (1.0 - (offset / center) ** 2) if center > 0 else 0
  slot_rot = ARC_ROTATION * (offset / center) if center > 0 else 0

Example (4 cards, slot 0):
  center = 1.5, offset = -1.5
  slot_x = -1.5 * 32 = -48 px from center
  slot_y = -3 * (1.0 - (-1.5/1.5)^2) = -3 * (1.0 - 1.0) = 0 (outer card, no lift)
  slot_rot = 2 * (-1.5/1.5) = -2° (tilted left)

Example (4 cards, slot 1):
  offset = -0.5
  slot_x = -0.5 * 32 = -16 px from center
  slot_y = -3 * (1.0 - (-0.5/1.5)^2) = -3 * (1.0 - 0.111) = -2.67 px (lifted)
  slot_rot = 2 * (-0.5/1.5) = -0.67° (slight left tilt)
```

**F.2 — Play Animation Trajectory**

```
Variables:
  start_pos   = card slot position
  PLAY_RISE   = 12 px upward
  PLAY_FRAMES = 6 frames
  t           = current frame / PLAY_FRAMES (0.0 to 1.0)

Output:
  card_y      = vertical position during animation
  card_alpha  = opacity during animation

Formula:
  card_y = start_pos.y - (PLAY_RISE * ease_out(t))
  card_alpha = 1.0 - t
  ease_out(t) = 1.0 - (1.0 - t) * (1.0 - t)  # quadratic ease out

Example (frame 3 of 6):
  t = 3/6 = 0.5
  ease_out(0.5) = 1.0 - 0.25 = 0.75
  card_y = start_y - (12 * 0.75) = start_y - 9
  card_alpha = 0.5
```

## Edge Cases

- **HAND_SIZE changes between runs (tuning knob adjusted)**: UI layout
  recalculates dynamically. Arc formula handles any slot count. No hardcoded
  positions.

- **Card with very long display_name**: Tooltip text wraps at 120 characters
  max. Names exceeding card frame width are not displayed on the card itself
  (icon-only during combat).

- **Three cards in a 4-slot hand (one empty)**: Empty slot shows dim outline.
  Other three cards maintain their arc positions — they don't collapse to fill
  the gap. Slot numbering is stable (slot 3 is always slot 3).

- **All slots empty**: All slots show dim outlines. No cards playable. This
  state should be prevented by MIN_DECK_SIZE but UI handles it gracefully.

- **Rapid card plays (playing cards faster than draw animation)**: Draw
  animation is purely visual. The card is logically in the slot even if the
  slide animation hasn't completed. Playing a "sliding in" card is valid —
  the animation snaps to completion, and the play animation begins.

- **Tooltip open when combat action starts**: Tooltip dismisses immediately.
  No tooltip during WINDUP/ACTIVE/RECOVERY.

- **Resolution change during gameplay**: UI recalculates positions based on
  viewport size (384×216 native). Card sizes are fixed in native pixels — they
  scale with the integer viewport scaling.

- **Gamepad D-pad rapid cycling**: Each D-pad press plays the card in that
  slot. No selection-then-confirm. Rapid presses = rapid plays (limited by
  animation commitment).

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Card Hand System | `card_played`, `card_drawn`, `hand_ready` signals; hand state queries | Hard |
| Upstream | Card Data System | `CardData` for icon, archetype, rarity, display_name, description | Hard |
| Upstream | Input System | `input_device_changed` for button prompt swap | Soft |
| Downstream | None | Pure presentation layer — no downstream consumers | — |

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `CARD_WIDTH` | 28 px | 24–36 | Card slot width. Larger = easier to read, more screen space used. |
| `CARD_HEIGHT` | 36 px | 30–44 | Card slot height. |
| `CARD_SPACING` | 4 px | 2–8 | Gap between cards. Larger = clearer separation, wider total hand. |
| `ARC_HEIGHT` | 3 px | 0–6 | Maximum arc lift. 0 = flat line. Higher = more curved hand feel. |
| `ARC_ROTATION` | 2° | 0–5 | Maximum card tilt. Higher = more fanned look. |
| `DRAW_ANIM_FRAMES` | 8 | 4–15 | Duration of draw slide animation. |
| `PLAY_ANIM_FRAMES` | 6 | 3–10 | Duration of play animation (rise + fade). |
| `PLAY_RISE` | 12 px | 6–20 | How far the played card rises before disappearing. |
| `TOOLTIP_DELAY` | 15 frames (0.25s) | 0–30 | Delay before tooltip appears on hover. 0 = instant. |

## Acceptance Criteria

1. **GIVEN** encounter starts with 4 cards dealt, **WHEN** hand renders,
   **THEN** 4 card slots visible in arc at bottom-center, each showing icon
   and archetype color.

2. **GIVEN** Gunslinger card in slot 1, **WHEN** rendered, **THEN** card
   frame has red/ember tint matching GUNSLINGER archetype.

3. **GIVEN** RARE card in hand, **WHEN** rendered, **THEN** card frame has
   animated glow + particle effect per rarity visual register.

4. **GIVEN** card played from slot 2, **WHEN** animation plays, **THEN** card
   rises 12px and fades out over 6 frames, slot shows empty state.

5. **GIVEN** new card drawn into slot 2, **WHEN** draw animation plays,
   **THEN** card slides from draw pile indicator to slot 2 over 8 frames.

6. **GIVEN** card on cooldown (15 frames remaining), **WHEN** rendered, **THEN**
   dark overlay visible, cooldown timer displays "0.3".

7. **GIVEN** draw pile at 3 cards, **WHEN** indicator rendered, **THEN**
   draw pile shows count "3".

8. **GIVEN** card play rejected (cooldown), **WHEN** feedback plays, **THEN**
   slot flashes red for 4 frames with 2px shake.

9. **GIVEN** mouse hovers over slot 3 for `TOOLTIP_DELAY` frames, **WHEN**
   tooltip appears, **THEN** shows card name, description, type, and lock time.

10. **GIVEN** gamepad active, **WHEN** D-pad left pressed, **THEN** slot 4
    card plays immediately (no hover → confirm flow).

11. **GIVEN** `HAND_SIZE = 3` (tuning knob), **WHEN** UI renders, **THEN** 3
    slots displayed, arc recalculates, no layout errors.

12. **GIVEN** discard pile reshuffles, **WHEN** indicator animates, **THEN**
    arrow from discard to draw pile plays, draw count updates.
