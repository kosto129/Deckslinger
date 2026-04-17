# UX Spec: Card Hand HUD

> **Status**: Draft
> **Last Updated**: 2026-04-17
> **Screen Type**: In-game HUD (always visible during combat)
> **GDD Reference**: `design/gdd/card-hand-ui.md`

## Purpose

The Card Hand HUD displays the player's current hand of cards during combat.
It is the primary interface between the player and the card system — readable
at a glance during fast real-time action.

## Screen Layout

```
┌─────────────────────────────────────────────────┐
│                                                 │
│              GAMEPLAY AREA                      │
│              (384 × 186 px usable)              │
│                                                 │
│                                                 │
├────┬───────────────────────────────────────┬─────┤
│    │                                       │     │
│ DD │   [1]    [2]    [3]    [4]            │ DP  │  ← 30px bottom bar
│    │   card   card   card   card           │     │
└────┴───────────────────────────────────────┴─────┘

DD = Discard pile indicator (count)
DP = Draw pile indicator (count)
[1]-[4] = Card slots with hotkey labels
```

## Element Specifications

### Card Slots

| Property | Value |
|----------|-------|
| Count | `HAND_SIZE` (default 4, tunable 3-5) |
| Card size | 28×36 px per card |
| Spacing | 4 px between cards |
| Position | Bottom-center, 8px from viewport bottom |
| Arc | 3px max lift at center, 2° max tilt at edges |

### Card Visual States

| State | Visual | Interaction |
|-------|--------|-------------|
| **Playable** | Full brightness, icon visible, hotkey label | Press number/D-pad to play |
| **On Cooldown** | Dark overlay, cooldown timer text | Cannot play, timer counting down |
| **Empty** | Dim card outline, no icon | No interaction |
| **Being Played** | Rises 12px, fades out over 6 frames | Non-interactive |
| **Being Drawn** | Slides in from draw pile over 8 frames | Non-interactive during slide |

### Pile Indicators

| Element | Position | Content |
|---------|----------|---------|
| Draw pile | Right of hand | Stack icon + count number |
| Discard pile | Left of hand | Fan icon + count number |

### Hotkey Labels

| Mode | Display |
|------|---------|
| KB/M | Numbers: "1", "2", "3", "4" |
| Gamepad | D-pad icons: ↑, →, ↓, ← |

Switch driven by `InputManager.input_device_changed` signal.

## Interaction Flow

```
IDLE STATE:
  Mouse hover on card → tooltip appears (after 15-frame delay)
  Number key pressed → card plays (if playable)
  Gamepad D-pad → card plays immediately (no hover step)

CARD PLAY:
  Card rises + fades out (6 frames)
  Slot shows empty state
  After DRAW_DELAY (6 frames): new card slides in from draw pile
  Archetype color flash on arrival (3 frames)

REJECTED PLAY:
  Slot flashes red (4 frames)
  Slot shakes 2px horizontal (3 frames)

RESHUFFLE:
  Discard count glows briefly
  Arrow animation: discard → draw
  Draw count updates
```

## Tooltip

| Property | Value |
|----------|-------|
| Trigger | Mouse hover (15-frame delay) or gamepad highlight |
| Position | Above card, clamped to viewport |
| Content | Card name, description (with variable substitution), type label, "Lock: Xms" |
| Dismiss | On hover exit, or when any action begins |

## Accessibility

- Card archetypes distinguishable by frame shape (not just color)
- Hotkey labels always visible (not hidden behind hover)
- Tooltip text minimum 8px at native resolution
- Cooldown timer is numeric (not just visual fill)

## Godot 4.6 Considerations

- **Dual-focus**: Mouse hover and gamepad D-pad operate independently
- `grab_focus()` is for keyboard/gamepad only — mouse hover is separate
- Test both input paths: mouse hovering card while gamepad navigates
