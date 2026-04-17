# Card Data System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 2 (Your Deck Is Your Identity), Pillar 4 (Earn Everything)

## Summary

The Card Data System defines the data schema for every card in Deckslinger as
Godot Resource files. It establishes card types, archetypes, rarity tiers,
effect definitions, and the resource structure that Card Hand, Deck Building,
Combat, and Reward systems consume. It owns the data — not the runtime behavior.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

The Card Data System is the blueprint layer for every card in the game. It
defines what a card IS (its stats, type, archetype, rarity, effects, targeting,
costs, and visual metadata) but not what a card DOES at runtime — that belongs
to Card Hand (play/draw), Combat (damage resolution), and Status Effect
(buff/debuff application). Cards are implemented as Godot Resource files
(`.tres`) extending a custom `CardData` resource class. This makes cards
data-driven, editor-authorable, and hot-reloadable. The system must support
the MVP card pool (~25 cards across 3 archetypes) and scale cleanly to 100+
cards without structural changes. Every gameplay value on a card is a tunable
field — nothing is hardcoded in scripts.

## Player Fantasy

Cards are the player's identity. Each card in the hand is a promise of what
they CAN do — a toolbox of abilities that defines their playstyle for this run.
When the player hovers over a card, they should instantly understand: what it
does, how strong it is, which archetype it belongs to, and whether it fits
their current strategy. Cards feel like physical objects with weight: a Common
card is a reliable workhorse, a Rare card is a signature move, and a Legendary
card is a run-defining windfall. The card data makes this legible before the
card is ever played.

## Detailed Rules

### Card Resource Schema

**S.1 — CardData Resource**

Every card is a `CardData` resource (`class_name CardData extends Resource`).
All fields are exported for editor authoring.

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `card_id` | `StringName` | Unique identifier (e.g., `"quick_draw"`) | Required |
| `display_name` | `String` | Player-facing name (e.g., "Quick Draw") | Required |
| `description` | `String` | Rules text with variable substitution (e.g., "Deal {damage} damage") | Required |
| `card_type` | `CardType` enum | ATTACK, SKILL, POWER | Required |
| `archetype` | `Archetype` enum | GUNSLINGER, DRIFTER, OUTLAW, NEUTRAL | Required |
| `rarity` | `Rarity` enum | COMMON, UNCOMMON, RARE, LEGENDARY | COMMON |
| `effects` | `Array[CardEffect]` | Ordered list of effects this card produces | Required |
| `targeting` | `TargetingMode` enum | SELF, DIRECTIONAL, AIMED, AOE_SELF, NONE | DIRECTIONAL |
| `cooldown_frames` | `int` | Minimum frames before this specific card can be played again after draw | 0 |
| `animation_key` | `StringName` | Key into Animation State Machine for play animation | Required |
| `windup_frames` | `int` | Frames before effect resolves (commitment window) | 12 |
| `active_frames` | `int` | Frames the hitbox/effect is live during resolution | 4 |
| `recovery_frames` | `int` | Frames after effect before player can act again | 8 |
| `card_art` | `Texture2D` | Card icon texture (32×32 px) | Placeholder |
| `card_color` | `Color` | Archetype tint applied to card frame | Derived from archetype |
| `sfx_play` | `AudioStream` | Sound on card play | null |
| `sfx_impact` | `AudioStream` | Sound on effect resolution | null |
| `shake_intensity` | `float` | Screen shake on impact (0 = none) | 0.0 |
| `upgraded` | `bool` | Whether this is the upgraded version | false |
| `upgrade_card_id` | `StringName` | card_id of the upgraded version (empty if no upgrade) | "" |
| `tags` | `Array[StringName]` | Freeform tags for synergy queries (e.g., "fire", "movement") | [] |
| `tooltip_extra` | `String` | Additional tooltip text for synergy hints | "" |

**S.2 — Card Types**

| CardType | Description | Example |
|----------|-------------|---------|
| `ATTACK` | Deals damage to targets. Has windup and recovery. Commits the player. | Quick Draw, Scatter Shot |
| `SKILL` | Utility effect — movement, buff, debuff, terrain. May or may not commit. | Tumble Roll, Smoke Bomb |
| `POWER` | Persistent effect for the rest of the encounter. Self-targeting. No windup. | Steady Aim, Hot Streak |

**S.3 — Archetypes**

Archetypes define the card's identity group and visual treatment. Each archetype
has a core fantasy and preferred playstyle.

| Archetype | Color | Fantasy | Mechanical Identity |
|-----------|-------|---------|---------------------|
| `GUNSLINGER` | Red/Ember | Offense, precision, high risk/reward | Direct damage, crit chance, glass cannon |
| `DRIFTER` | Blue/Teal | Control, positioning, calculated play | Debuffs, movement, area denial, defense |
| `OUTLAW` | Yellow/Amber | Chaos, synergy chains, gambling | Random effects, combo triggers, high variance |
| `NEUTRAL` | Grey/White | Utility, available to all builds | Basic attacks, generic utility, starter cards |

Archetype mixing is allowed and encouraged. A deck with Gunslinger + Outlaw
cards creates a "glass cannon gambler" playstyle. The archetype system enables
identity, not restriction.

**S.4 — Rarity Tiers**

| Rarity | Visual Treatment | Power Budget | Draft Weight | Deck Limit |
|--------|-----------------|--------------|--------------|------------|
| `COMMON` | Clean card frame, no glow | 1.0× baseline | 60% of draft pool | Unlimited |
| `UNCOMMON` | Subtle border shimmer | 1.3× baseline | 25% of draft pool | Unlimited |
| `RARE` | Animated border glow + archetype particles | 1.7× baseline | 12% of draft pool | 3 per deck |
| `LEGENDARY` | Full card glow + unique idle animation | 2.5× baseline | 3% of draft pool | 1 per deck |

Power budget is a design guideline for card authors, not a runtime mechanic.
A 1.0× Common attack might deal 15 damage; a 2.5× Legendary might deal 38
plus a unique effect. Deck limits are enforced by the Deck Building System.

### Effect System Schema

**E.1 — CardEffect Resource**

Each card contains an ordered array of `CardEffect` resources. Effects are
processed in order when the card resolves.

| Field | Type | Description |
|-------|------|-------------|
| `effect_type` | `EffectType` enum | What this effect does |
| `value` | `float` | Primary numeric value (damage, heal amount, duration, etc.) |
| `secondary_value` | `float` | Optional secondary value (radius, knockback force, etc.) |
| `target_override` | `TargetingMode` | Override card-level targeting for this specific effect (or INHERIT) |
| `status_effect_id` | `StringName` | If effect applies a status, which one |
| `status_duration_frames` | `int` | Duration of applied status effect in frames |
| `vfx_key` | `StringName` | Visual effect to spawn on resolution |
| `conditions` | `Array[EffectCondition]` | Conditions that must be true for this effect to fire |

**E.2 — Effect Types**

| EffectType | value Usage | secondary_value Usage |
|------------|-------------|----------------------|
| `DAMAGE` | Damage amount (before scaling) | Knockback force (0 = none) |
| `HEAL` | Heal amount | — |
| `APPLY_STATUS` | — (uses status_effect_id) | — |
| `MOVE_SELF` | Distance in pixels | Speed in px/frame |
| `SPAWN_PROJECTILE` | Projectile damage | Projectile speed (px/frame) |
| `AOE_DAMAGE` | Damage per target | Radius in pixels |
| `SHIELD` | Shield HP amount | Duration in frames (0 = until broken) |
| `DRAW_CARDS` | Number of additional cards to draw | — |
| `DISCARD` | Number of cards to discard from hand | — |

**E.3 — Effect Conditions**

Conditions gate whether an individual effect fires. Multiple conditions are
AND-evaluated.

| EffectCondition | Description |
|-----------------|-------------|
| `HP_BELOW_PERCENT(threshold)` | Player HP is below threshold % |
| `HP_ABOVE_PERCENT(threshold)` | Player HP is above threshold % |
| `HAS_STATUS(status_id)` | Player has the named status active |
| `ENEMY_COUNT_GTE(count)` | Room has >= count living enemies |
| `HAND_SIZE_LTE(count)` | Current hand has <= count cards |
| `COMBO_COUNT_GTE(count)` | Cards played this encounter >= count |

### Targeting Modes

**TM.1 — Targeting Definitions**

| TargetingMode | Description | Visual Indicator |
|---------------|-------------|-----------------|
| `SELF` | Effect applies to the player. No aim required. | Card glows on player sprite |
| `DIRECTIONAL` | Effect fires in the player's aim direction. | Aim arrow extends from player |
| `AIMED` | Effect fires toward a specific point (mouse/stick position). | Crosshair at aim target |
| `AOE_SELF` | Effect centered on player position. | Circle radius indicator around player |
| `NONE` | No targeting (Powers, passive triggers). | No indicator |

### Card Upgrades

**U.1 — Upgrade Rules**

- Each card may have exactly 0 or 1 upgraded version
- Upgraded cards have the same `card_type`, `archetype`, and `targeting`
- Upgrade improves numeric values (damage, duration, radius) or adds an effect
- Upgraded cards share the same `animation_key` (no new art required for MVP)
- `display_name` gains a "+" suffix (e.g., "Quick Draw" → "Quick Draw+")
- The upgraded version is a separate `CardData` resource, not a runtime modifier

**U.2 — Upgrade Power Guidelines**

| Upgrade Aspect | Typical Improvement | Example |
|----------------|---------------------|---------|
| Damage/Heal | +30% to +50% | 15 → 20 damage |
| Duration | +50% to +100% | 120 → 180 frames |
| Radius | +25% | 48 → 60 px |
| Added effect | One bonus effect appended | Add 60-frame burn status |
| Reduced commitment | -25% recovery frames | 12 → 9 recovery frames |

### Card Registry

**CR.1 — Registry Structure**

All `CardData` resources are stored in `assets/data/cards/` organized by
archetype:

```
assets/data/cards/
├── gunslinger/
│   ├── quick_draw.tres
│   ├── scatter_shot.tres
│   └── ...
├── drifter/
│   ├── smoke_bomb.tres
│   ├── tumble_roll.tres
│   └── ...
├── outlaw/
│   ├── wild_card.tres
│   ├── ricochet.tres
│   └── ...
└── neutral/
    ├── basic_strike.tres
    ├── basic_guard.tres
    └── ...
```

**CR.2 — Runtime Card Registry**

A singleton `CardRegistry` autoload loads all CardData resources at startup
and provides lookup by `card_id`:

```gdscript
func get_card(card_id: StringName) -> CardData
func get_cards_by_archetype(archetype: Archetype) -> Array[CardData]
func get_cards_by_rarity(rarity: Rarity) -> Array[CardData]
func get_cards_by_type(card_type: CardType) -> Array[CardData]
func get_all_cards() -> Array[CardData]
func get_starter_deck(archetype: Archetype) -> Array[CardData]
```

**CR.3 — Starter Decks**

Each archetype has a curated starter deck of 8 cards (all COMMON or NEUTRAL):

| Archetype | Starter Cards | Identity |
|-----------|--------------|----------|
| Gunslinger | 3 Gunslinger ATTACKs + 2 Neutral ATTACKs + 2 Neutral SKILLs + 1 Gunslinger SKILL | Offense-heavy, direct damage |
| Drifter | 2 Drifter ATTACKs + 2 Neutral ATTACKs + 3 Drifter SKILLs + 1 Neutral SKILL | Control-heavy, positioning |
| Outlaw | 2 Outlaw ATTACKs + 2 Neutral ATTACKs + 2 Outlaw SKILLs + 1 Neutral SKILL + 1 Outlaw POWER | Varied, unpredictable |

## Formulas

**F.1 — Damage Scaling by Rarity**

Design-time formula for card authors to maintain consistent power curves.

```
Variables:
  base_damage     = archetype's baseline damage for a COMMON ATTACK card
  rarity_mult     = rarity power multiplier (see table S.4)
  level_bonus     = 0 for base, upgrade improvement for upgraded version

Output:
  card_damage = final damage value authored on the CardData resource

Formula:
  card_damage = floor(base_damage * rarity_mult + level_bonus)

Archetype base damages:
  GUNSLINGER: base_damage = 18 (high single-target)
  DRIFTER:    base_damage = 12 (lower, compensated by utility)
  OUTLAW:     base_damage = 15 (medium, high variance cards may roll ±30%)
  NEUTRAL:    base_damage = 10 (weakest, compensated by universal availability)

Example (Rare Gunslinger attack):
  card_damage = floor(18 * 1.7 + 0) = floor(30.6) = 30

Example (Uncommon Outlaw attack, upgraded):
  card_damage = floor(15 * 1.3 + 5) = floor(19.5 + 5) = floor(24.5) = 24
```

**F.2 — Draft Weight Calculation**

Used by the Reward System to populate card draft pools.

```
Variables:
  base_weight    = rarity draft weight (COMMON: 60, UNCOMMON: 25, RARE: 12, LEGENDARY: 3)
  floor_number   = current dungeon floor (1-indexed)
  RARITY_FLOOR_SHIFT = per-floor adjustment (default: 2)

Output:
  adjusted_weight = weight used in weighted random selection

Formula:
  For COMMON:
    adjusted_weight = max(base_weight - (floor_number * RARITY_FLOOR_SHIFT), 20)
  For UNCOMMON:
    adjusted_weight = base_weight + floor_number * 1
  For RARE:
    adjusted_weight = base_weight + floor_number * RARITY_FLOOR_SHIFT
  For LEGENDARY:
    adjusted_weight = base_weight + max(floor_number - 3, 0) * 1

Example (Floor 4):
  COMMON:    max(60 - 4*2, 20) = max(52, 20) = 52
  UNCOMMON:  25 + 4*1 = 29
  RARE:      12 + 4*2 = 20
  LEGENDARY: 3 + max(4-3, 0)*1 = 4

  Total weight: 52 + 29 + 20 + 4 = 105
  Rare chance: 20/105 = 19.0%  (up from 12% on floor 1)
```

**F.3 — Commitment Frame Budget**

Design-time formula for calculating total lock-in time per card.

```
Variables:
  windup_frames   = frames before effect (authored on CardData)
  active_frames   = frames the effect/hitbox is live (authored on CardData)
  recovery_frames = frames after effect (authored on CardData)
  FRAME_RATE      = 60 fps

Output:
  total_commit_ms = total commitment time in milliseconds

Formula:
  total_commit_ms = (windup_frames + active_frames + recovery_frames) / FRAME_RATE * 1000

Card type guidelines:
  ATTACK:  windup 8-18,  active 2-6,  recovery 6-15  → 267-650ms total
  SKILL:   windup 4-10,  active 2-4,  recovery 4-10  → 167-400ms total
  POWER:   windup 0-4,   active 1-2,  recovery 6-10  → 117-267ms total

Example (Quick Draw — fast Gunslinger attack):
  windup = 8, active = 3, recovery = 6
  total_commit_ms = (8 + 3 + 6) / 60 * 1000 = 283ms

Example (Scatter Shot — heavy Gunslinger attack):
  windup = 15, active = 4, recovery = 12
  total_commit_ms = (15 + 4 + 12) / 60 * 1000 = 517ms
```

**F.4 — Deck Size Constraints**

```
Variables:
  MIN_DECK_SIZE = 6 cards (floor for trimming — can't go below)
  MAX_DECK_SIZE = 30 cards (ceiling — prevents bloated decks)
  STARTER_SIZE  = 8 cards

Deck cycling rate (how often a card appears in hand):
  avg_appearances_per_cycle = deck_size / hand_size

Example (8-card deck, 4-card hand):
  Each card appears roughly every 2 cycles through the deck (8/4 = 2)
  With use-to-draw, each card reappears after playing ~8 other cards

Example (20-card deck, 4-card hand):
  Each card appears roughly every 5 cycles (20/4 = 5)
  Much less predictable — player sees each card less often
```

## Edge Cases

- **Card with zero effects**: Legal but useless. The card plays its animation,
  commits the player, draws the next card, but does nothing. Design validation
  should flag this during authoring, but runtime does not crash.

- **Effect condition references a status the game doesn't have**: Condition
  evaluates to `false`. Effect does not fire. No error. Prevents crash if a
  card references a status from a future update.

- **Card's `upgrade_card_id` points to a non-existent card**: Upgrade option
  is not offered by the Deck Building System. CardRegistry logs a warning at
  startup. The base card functions normally.

- **Duplicate `card_id` in registry**: CardRegistry logs an error at startup
  and uses the last-loaded version. Two cards must never share an ID — this is
  a content authoring bug, not a runtime scenario.

- **Card with `cooldown_frames > 0` drawn into a full hand**: Cooldown timer
  starts on draw, not on hand entry. The card appears in hand but is visually
  dimmed and cannot be played until the cooldown expires. Card Hand System
  enforces this, using `cooldown_frames` from CardData.

- **Legendary card in draft when player already has 1 Legendary in deck**:
  Deck Building System excludes it from draft options. The Card Data System
  provides the data; the limit is enforced by Deck Building.

- **Card with `targeting = AIMED` used with gamepad**: Aim target is derived
  from right stick direction at a fixed distance from the player (per Input
  System rules). Functions identically to directional but at a fixed point.

- **Tag query for a tag no card has**: Returns empty array. No error. Tags
  are freeform — the system doesn't validate tag names.

- **Card's `windup_frames` is 0**: Effect resolves immediately on play. Legal
  for POWER type cards. ATTACK cards should always have windup > 0 (design
  validation flag, not runtime enforcement).

- **Multiple effects with different `target_override` values**: Each effect
  resolves against its own targeting independently. A card could deal
  directional damage AND apply a self-buff in the same play.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | None | Root dependency | — |
| Downstream | Card Hand System | Reads CardData for hand display, cooldown enforcement | Hard |
| Downstream | Combat System | Reads CardData effects (DAMAGE, SPAWN_PROJECTILE) for resolution | Hard |
| Downstream | Status Effect System | Reads `status_effect_id` and `status_duration_frames` | Hard |
| Downstream | Deck Building System | Reads CardData for draft display, rarity limits, upgrades | Hard |
| Downstream | Reward System | Reads rarity, archetype, tags for draft pool construction | Hard |
| Downstream | Card Hand UI | Reads display_name, description, card_art, card_color, rarity for rendering | Hard |
| Downstream | Animation State Machine | Reads `animation_key` for play animation | Soft |
| Downstream | Camera System | Reads `shake_intensity` for screen shake on impact | Soft |

The Card Data System is purely a data provider. It has no runtime behavior
and no update loop. All downstream systems read CardData resources; none
write to them.

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `MIN_DECK_SIZE` | 6 | 4–8 | Minimum deck size after trimming. Too low = too predictable. Too high = can't build focused decks. |
| `MAX_DECK_SIZE` | 30 | 20–40 | Maximum deck size. Too low = limited draft options. Too high = inconsistent draws. |
| `STARTER_DECK_SIZE` | 8 | 6–10 | Number of cards in starting deck. Affects early run consistency. |
| `RARE_DECK_LIMIT` | 3 | 2–5 | Max Rare cards per deck. Prevents decks from being all-Rare. |
| `LEGENDARY_DECK_LIMIT` | 1 | 1–2 | Max Legendary cards per deck. Ensures Legendary feels special. |
| `RARITY_FLOOR_SHIFT` | 2 | 1–4 | Per-floor draft weight adjustment. Higher = faster rarity curve. |
| `GUNSLINGER_BASE_DAMAGE` | 18 | 14–22 | Baseline damage for Gunslinger COMMON attacks. Sets archetype power floor. |
| `DRIFTER_BASE_DAMAGE` | 12 | 8–16 | Baseline damage for Drifter COMMON attacks. Lower because utility compensates. |
| `OUTLAW_BASE_DAMAGE` | 15 | 11–19 | Baseline damage for Outlaw COMMON attacks. Medium with high variance potential. |
| `NEUTRAL_BASE_DAMAGE` | 10 | 7–13 | Baseline damage for Neutral COMMON attacks. Weakest — universally available. |

## Acceptance Criteria

1. **GIVEN** a CardData resource with all required fields, **WHEN** loaded by
   CardRegistry, **THEN** all fields are accessible with correct types.

2. **GIVEN** a card with `card_type = ATTACK`, `archetype = GUNSLINGER`,
   `rarity = RARE`, **WHEN** damage is calculated per F.1, **THEN** damage
   equals `floor(18 * 1.7) = 30`.

3. **GIVEN** a card with 3 effects in its `effects` array, **WHEN** the card
   resolves, **THEN** effects process in array order (index 0 first).

4. **GIVEN** a card effect with `conditions = [HP_BELOW_PERCENT(50)]`, **WHEN**
   player HP is 60%, **THEN** the effect does not fire.

5. **GIVEN** a card effect with `conditions = [HP_BELOW_PERCENT(50)]`, **WHEN**
   player HP is 40%, **THEN** the effect fires normally.

6. **GIVEN** `get_cards_by_archetype(GUNSLINGER)` called, **WHEN** registry
   contains 5 Gunslinger cards and 3 Drifter cards, **THEN** returns exactly
   5 cards, all with `archetype == GUNSLINGER`.

7. **GIVEN** a card with `upgrade_card_id = "quick_draw_plus"`, **WHEN** the
   upgrade exists in registry, **THEN** upgrade card has same `card_type`,
   `archetype`, and `targeting` as the base card.

8. **GIVEN** Floor 4, **WHEN** draft weights calculated per F.2, **THEN**
   COMMON = 52, UNCOMMON = 29, RARE = 20, LEGENDARY = 4.

9. **GIVEN** a card with `cooldown_frames = 30`, **WHEN** drawn into hand,
   **THEN** card is visually dimmed for 30 frames and cannot be played until
   cooldown expires.

10. **GIVEN** a card with `targeting = DIRECTIONAL`, **WHEN** played, **THEN**
    effect resolves in the player's current aim direction (from Input System).

11. **GIVEN** duplicate `card_id` in two resource files, **WHEN** CardRegistry
    loads at startup, **THEN** warning is logged and last-loaded version is used.

12. **GIVEN** `get_starter_deck(GUNSLINGER)` called, **THEN** returns exactly
    `STARTER_DECK_SIZE` cards, all COMMON or NEUTRAL rarity.

13. **GIVEN** the variable substitution in `description = "Deal {damage} damage"`,
    **WHEN** displayed in Card Hand UI, **THEN** `{damage}` is replaced with
    the card's actual damage value from its first DAMAGE effect.

14. **GIVEN** any CardData resource, **WHEN** `windup_frames + recovery_frames`
    is calculated, **THEN** result falls within the commitment budget for its
    `card_type` (per F.3 guidelines).
