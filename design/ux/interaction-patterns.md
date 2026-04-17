# Interaction Pattern Library

> **Status**: Initial
> **Last Updated**: 2026-04-17
> **Engine**: Godot 4.6

## Purpose

This library documents reusable interaction patterns used across all screens
and UI elements. Designers and programmers reference this to ensure consistency.

---

## Input Patterns

### IP-01: Action Confirmation (Single Press)

All gameplay actions use single press-to-execute. No hold-to-confirm, no
double-tap, no press-and-hold in combat.

| Input | KB/M | Gamepad |
|-------|------|---------|
| Play card | Number key (1-4) | D-pad direction |
| Attack | Left click | RB |
| Dodge | Space | LB |
| Interact | E | A (South) |

**Rule**: Every gameplay action fires on key-down. No modifier keys required
during combat.

### IP-02: Menu Navigation

| Action | KB/M | Gamepad |
|--------|------|---------|
| Navigate | Arrow keys / Mouse hover | D-pad / Left stick |
| Confirm | Enter / Left click | A (South) |
| Cancel / Back | Escape | B (East) |
| Tab switch | Tab / Q/E | LB/RB |

**Rule**: All menus support both mouse and gamepad navigation simultaneously
(Godot 4.6 dual-focus).

### IP-03: Card Draft Selection (Reward Screen)

1. Cards fan out with hover preview
2. Mouse: hover to preview, click to select
3. Gamepad: D-pad left/right to browse, A to select
4. Skip option always visible (button or key)
5. Confirmation prompt before finalizing (prevent mis-clicks)

### IP-04: Deck Trim Selection

1. Full deck displayed as scrollable grid
2. Mouse: hover to preview card details, click to select for removal
3. Gamepad: D-pad to navigate grid, A to select
4. Confirmation prompt: "Remove [Card Name]? This is permanent."
5. Cancel available at all times

---

## Feedback Patterns

### FP-01: Combat Impact

Every successful hit produces layered feedback:
1. **Visual**: Hit-stop freeze (2-8 frames) + screen shake + damage number
2. **Animation**: Target plays hit_react animation
3. **Audio**: Impact SFX (when implemented)

Scaling: stronger hits = longer stop + bigger shake + larger number.

### FP-02: Card Play Feedback

1. Card rises from hand slot and fades out (6 frames)
2. Player character enters windup animation
3. New card slides into vacated slot from draw pile (8 frames)
4. Archetype color flash on new card arrival (3 frames)

### FP-03: Rejected Action Feedback

When player attempts an invalid action (card on cooldown, during recovery):
1. Card slot flashes red (4 frames)
2. Slot shakes horizontally (2px, 3 frames)
3. No audio in MVP

### FP-04: Room Clear Feedback

1. Last enemy death plays extended hit-stop
2. 30-frame pause (dramatic beat)
3. Clear chime/VFX (when audio/VFX implemented)
4. Exits unlock (visual indicator)
5. Reward appears

---

## Navigation Patterns

### NP-01: Room Transition

1. Fade to black (8 frames)
2. Scene swap (instant, hidden by fade)
3. Fade from black (10 frames)
4. Player appears at spawn point, camera snaps to position

### NP-02: Dungeon Map Navigation

1. Map overlay appears over gameplay (dimmed background)
2. Available rooms highlighted, unavailable rooms dimmed
3. Connections shown as lines between room nodes
4. Mouse: click room to select. Gamepad: D-pad + A to confirm.
5. Map dismisses on room selection → room transition begins

### NP-03: Pause Menu

1. Escape / Start opens pause overlay
2. Game freezes (all timers pause, including input buffer)
3. Menu options: Resume, Settings, Deck View, Quit Run
4. Resume returns to exact game state (no buffer expiry during pause)

---

## Accessibility Patterns

### AP-01: Input Device Auto-Detection

- System detects last active input device
- UI prompts switch automatically (keyboard icons ↔ gamepad icons)
- No manual "controller mode" toggle needed
- Driven by `InputManager.input_device_changed` signal

### AP-02: Non-Color Information

All information conveyed by color must also be conveyed by a second channel:
- Card archetypes: color + frame shape
- Damage numbers: color + size (crit = larger)
- Status effects: color tint + icon
- Enemy telegraphs: color + animation pose
