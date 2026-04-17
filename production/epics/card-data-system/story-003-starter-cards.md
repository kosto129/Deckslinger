# Story 003: Starter Card .tres Files

> **Epic**: Card Data System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-data-system.md`
**Requirements**: GDD sections CR.3 (starter deck composition), D.5 (if present), S.1 (field schema)

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture
**ADR Decision Summary**: Card data lives in `assets/data/cards/` organized by archetype. All values are data-driven on exported Resource fields. Adding a new card requires zero code changes.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `.tres` files are text-format Godot Resources authored in the editor inspector. No post-cutoff API concerns for data authoring. Verify that `Array[CardEffect]` sub-resources serialize and reload correctly in 4.6 before final authoring.

**Control Manifest Rules (Foundation)**:
- Required: Static game data uses Godot Resources (.tres). Cards are CardData resources, never dictionaries or JSON.
- Required: All gameplay values on exported Resource fields. No inline magic numbers anywhere.
- Forbidden: Never hardcode gameplay values in GDScript.

---

## Acceptance Criteria

- [ ] 10 `.tres` files exist in `assets/data/cards/` organized by archetype subdirectory
- [ ] All 10 cards have `rarity == COMMON`
- [ ] Starter deck composition per archetype matches GDD CR.3 exactly (see composition table below)
- [ ] `CardRegistry.get_starter_deck(GUNSLINGER)` returns exactly 8 cards
- [ ] `CardRegistry.get_starter_deck(DRIFTER)` returns exactly 8 cards
- [ ] `CardRegistry.get_starter_deck(OUTLAW)` returns exactly 8 cards
- [ ] Every card used in a starter deck has a `"starter"` tag and an archetype-specific starter tag (e.g., `"starter_gunslinger"`)
- [ ] All damage values conform to GDD F.1 formula for COMMON rarity (see value table below)
- [ ] All commitment frame budgets fall within GDD F.3 guidelines for their card_type
- [ ] All required fields are set (non-empty `card_id`, `display_name`, `description`, `animation_key`)
- [ ] `card_color` is set to the archetype's defined color (GDD S.3)
- [ ] `upgrade_card_id` is `&""` for all starter cards (no upgrades in starter set)

---

## Card Roster

### Starter Deck Composition (GDD CR.3)

| Archetype | Composition | Count |
|-----------|-------------|-------|
| Gunslinger | 3 Gunslinger ATTACKs + 2 Neutral ATTACKs + 2 Neutral SKILLs + 1 Gunslinger SKILL | 8 |
| Drifter | 2 Drifter ATTACKs + 2 Neutral ATTACKs + 3 Drifter SKILLs + 1 Neutral SKILL | 8 |
| Outlaw | 2 Outlaw ATTACKs + 2 Neutral ATTACKs + 2 Outlaw SKILLs + 1 Neutral SKILL + 1 Outlaw POWER | 8 |

Neutral cards appear in all three starter decks — there are only 4 unique Neutral cards, shared across archetypes.

### The 10 Cards

**Damage values use GDD F.1**: `card_damage = floor(base_damage * rarity_mult)` where COMMON `rarity_mult = 1.0`.
- GUNSLINGER base_damage = 18
- DRIFTER base_damage = 12
- OUTLAW base_damage = 15
- NEUTRAL base_damage = 10

**Commitment frames use GDD F.3 guidelines** (ATTACK: windup 8-18, active 2-6, recovery 6-15 / SKILL: windup 4-10, active 2-4, recovery 4-10 / POWER: windup 0-4, active 1-2, recovery 6-10).

---

#### Neutral Cards (4 cards — shared across all starter decks)

**1. basic_strike**
```
File:              assets/data/cards/neutral/basic_strike.tres
card_id:           &"basic_strike"
display_name:      "Basic Strike"
description:       "Deal {damage} damage."
card_type:         ATTACK
archetype:         NEUTRAL
rarity:            COMMON
targeting:         DIRECTIONAL
windup_frames:     10
active_frames:     3
recovery_frames:   8
animation_key:     &"attack_directional"
card_color:        Color(0.75, 0.75, 0.75)   # Grey/White (Neutral)
tags:              [&"starter", &"starter_gunslinger", &"starter_drifter", &"starter_outlaw"]
effects:
  [0] CardEffect:
      effect_type:     DAMAGE
      value:           10.0       # floor(10 * 1.0) = 10
      secondary_value: 0.0
```

**2. steady_shot**
```
File:              assets/data/cards/neutral/steady_shot.tres
card_id:           &"steady_shot"
display_name:      "Steady Shot"
description:       "Deal {damage} damage."
card_type:         ATTACK
archetype:         NEUTRAL
rarity:            COMMON
targeting:         AIMED
windup_frames:     14
active_frames:     2
recovery_frames:   10
animation_key:     &"attack_aimed"
card_color:        Color(0.75, 0.75, 0.75)
tags:              [&"starter", &"starter_gunslinger", &"starter_drifter", &"starter_outlaw"]
effects:
  [0] CardEffect:
      effect_type:     DAMAGE
      value:           10.0
      secondary_value: 0.0
```

**3. quick_step**
```
File:              assets/data/cards/neutral/quick_step.tres
card_id:           &"quick_step"
display_name:      "Quick Step"
description:       "Dash {distance} pixels in your aim direction."
card_type:         SKILL
archetype:         NEUTRAL
rarity:            COMMON
targeting:         DIRECTIONAL
windup_frames:     5
active_frames:     2
recovery_frames:   6
animation_key:     &"dash_directional"
card_color:        Color(0.75, 0.75, 0.75)
tags:              [&"starter", &"starter_gunslinger", &"starter_drifter", &"starter_outlaw", &"movement"]
effects:
  [0] CardEffect:
      effect_type:     MOVE_SELF
      value:           80.0       # 80 pixels
      secondary_value: 8.0        # 8 px/frame speed
```

**4. brace**
```
File:              assets/data/cards/neutral/brace.tres
card_id:           &"brace"
display_name:      "Brace"
description:       "Gain {shield} shield."
card_type:         SKILL
archetype:         NEUTRAL
rarity:            COMMON
targeting:         SELF
windup_frames:     4
active_frames:     2
recovery_frames:   8
animation_key:     &"skill_self"
card_color:        Color(0.75, 0.75, 0.75)
tags:              [&"starter", &"starter_drifter", &"starter_outlaw"]
effects:
  [0] CardEffect:
      effect_type:     SHIELD
      value:           20.0       # 20 shield HP
      secondary_value: 0.0        # until broken
```

---

#### Gunslinger Cards (3 cards)

**5. quick_draw**
```
File:              assets/data/cards/gunslinger/quick_draw.tres
card_id:           &"quick_draw"
display_name:      "Quick Draw"
description:       "Deal {damage} damage."
card_type:         ATTACK
archetype:         GUNSLINGER
rarity:            COMMON
targeting:         DIRECTIONAL
windup_frames:     8
active_frames:     3
recovery_frames:   6
animation_key:     &"attack_directional"
card_color:        Color(0.85, 0.25, 0.15)   # Red/Ember (Gunslinger)
tags:              [&"starter", &"starter_gunslinger"]
effects:
  [0] CardEffect:
      effect_type:     DAMAGE
      value:           18.0       # floor(18 * 1.0) = 18
      secondary_value: 0.0
```

**6. scatter_shot**
```
File:              assets/data/cards/gunslinger/scatter_shot.tres
card_id:           &"scatter_shot"
display_name:      "Scatter Shot"
description:       "Deal {damage} damage in a wide arc."
card_type:         ATTACK
archetype:         GUNSLINGER
rarity:            COMMON
targeting:         AOE_SELF
windup_frames:     15
active_frames:     4
recovery_frames:   12
animation_key:     &"attack_aoe"
card_color:        Color(0.85, 0.25, 0.15)
tags:              [&"starter", &"starter_gunslinger"]
effects:
  [0] CardEffect:
      effect_type:     AOE_DAMAGE
      value:           14.0       # Reduced from 18 base — spread compensates
      secondary_value: 80.0       # 80px radius
```

**7. fan_the_hammer**
```
File:              assets/data/cards/gunslinger/fan_the_hammer.tres
card_id:           &"fan_the_hammer"
display_name:      "Fan the Hammer"
description:       "Deal {damage} damage twice."
card_type:         ATTACK
archetype:         GUNSLINGER
rarity:            COMMON
targeting:         DIRECTIONAL
windup_frames:     12
active_frames:     6
recovery_frames:   10
animation_key:     &"attack_directional"
card_color:        Color(0.85, 0.25, 0.15)
tags:              [&"starter", &"starter_gunslinger"]
effects:
  [0] CardEffect:
      effect_type:     DAMAGE
      value:           9.0        # 9 × 2 hits = 18 total (1.0× budget, split)
      secondary_value: 0.0
  [1] CardEffect:
      effect_type:     DAMAGE
      value:           9.0
      secondary_value: 0.0
```

**8. iron_sights**
```
File:              assets/data/cards/gunslinger/iron_sights.tres
card_id:           &"iron_sights"
display_name:      "Iron Sights"
description:       "Draw {draw} card. Your next attack deals bonus damage."
card_type:         SKILL
archetype:         GUNSLINGER
rarity:            COMMON
targeting:         SELF
windup_frames:     4
active_frames:     2
recovery_frames:   6
animation_key:     &"skill_self"
card_color:        Color(0.85, 0.25, 0.15)
tags:              [&"starter", &"starter_gunslinger"]
effects:
  [0] CardEffect:
      effect_type:     DRAW_CARDS
      value:           1.0
      secondary_value: 0.0
```

---

#### Drifter Cards (3 cards)

**9. smoke_bomb**
```
File:              assets/data/cards/drifter/smoke_bomb.tres
card_id:           &"smoke_bomb"
display_name:      "Smoke Bomb"
description:       "Apply {status} to all nearby enemies for {duration} frames."
card_type:         SKILL
archetype:         DRIFTER
rarity:            COMMON
targeting:         AOE_SELF
windup_frames:     6
active_frames:     3
recovery_frames:   8
animation_key:     &"skill_aoe"
card_color:        Color(0.15, 0.55, 0.65)   # Blue/Teal (Drifter)
tags:              [&"starter", &"starter_drifter"]
effects:
  [0] CardEffect:
      effect_type:        APPLY_STATUS
      value:              0.0
      secondary_value:    0.0
      status_effect_id:   &"blinded"
      status_duration_frames: 120
      target_override:    AOE_SELF
```

**10. tumble_roll**
```
File:              assets/data/cards/drifter/tumble_roll.tres
card_id:           &"tumble_roll"
display_name:      "Tumble Roll"
description:       "Dash {distance} pixels and deal {damage} damage on arrival."
card_type:         ATTACK
archetype:         DRIFTER
rarity:            COMMON
targeting:         DIRECTIONAL
windup_frames:     8
active_frames:     4
recovery_frames:   10
animation_key:     &"dash_attack"
card_color:        Color(0.15, 0.55, 0.65)
tags:              [&"starter", &"starter_drifter"]
effects:
  [0] CardEffect:
      effect_type:     MOVE_SELF
      value:           64.0
      secondary_value: 10.0
  [1] CardEffect:
      effect_type:     DAMAGE
      value:           12.0       # floor(12 * 1.0) = 12
      secondary_value: 0.0
```

> **Note**: Drifter needs a second ATTACK card. Use `steady_shot` (Neutral ATTACK) plus one of the two neutral ATTACKs to fulfil the 2 Drifter ATTACKs + 2 Neutral ATTACKs composition. GDD CR.3 shows Drifter gets "2 Drifter ATTACKs" — `tumble_roll` is one; a second Drifter ATTACK can be added in Story 003 expansion or the count satisfied by tagging `steady_shot` as a second Drifter attack. **Decision required** from game-designer before final authoring: add a second Drifter ATTACK card to this story (expanding to 11 cards), or treat `steady_shot` as the second Drifter ATTACK by adding `&"starter_drifter"` tag to it. The ACs above allow 10 cards as the minimum to ship.

---

#### Outlaw Cards (2 cards)

**Note**: Outlaw starter deck requires 2 Outlaw ATTACKs + 2 Outlaw SKILLs + 1 Outlaw POWER. Neutral cards cover the remaining 3 slots. This story authors 2 Outlaw cards (1 ATTACK + 1 POWER). A second Outlaw ATTACK and a second Outlaw SKILL bring the unique Outlaw card count to 4, but to keep this story to 10 total cards while satisfying the deck composition: `wild_card` is the ATTACK, `ricochet` is the SKILL, and `hot_streak` is the POWER. **One Outlaw card must double as both SKILL slots or a second Outlaw SKILL card is added** — flag for game-designer.

For this story, the 10 canonical starter cards are the 4 Neutral + 3 Gunslinger + 3 Drifter/Outlaw split defined above. The exact 10 are: `basic_strike`, `steady_shot`, `quick_step`, `brace`, `quick_draw`, `scatter_shot`, `fan_the_hammer`, `iron_sights`, `smoke_bomb`, `tumble_roll`. Three additional Outlaw-specific cards can be added as a follow-on task. See story expansion note at end.

---

## File Structure

```
assets/data/cards/
├── gunslinger/
│   ├── quick_draw.tres
│   ├── scatter_shot.tres
│   ├── fan_the_hammer.tres
│   └── iron_sights.tres
├── drifter/
│   ├── smoke_bomb.tres
│   └── tumble_roll.tres
├── outlaw/
│   └── (to be authored — see expansion note)
└── neutral/
    ├── basic_strike.tres
    ├── steady_shot.tres
    ├── quick_step.tres
    └── brace.tres
```

---

## Implementation Notes

**Authoring order**: Author Neutral cards first (they appear in all starter decks). Author Gunslinger next (most fully specified in GDD). Drifter and Outlaw follow.

**Tags for `get_starter_deck()`**: Every card in a starter deck must have:
1. `&"starter"` — marks it as any starter card
2. `&"starter_[archetype]"` — marks it for a specific archetype's deck (e.g., `&"starter_gunslinger"`)

Cards shared across multiple starter decks (Neutral cards) get multiple archetype tags.

**Placeholder assets**: `card_art` may be null for MVP. `sfx_play` and `sfx_impact` may be null. `animation_key` must be set to a non-empty StringName even if the animation does not yet exist — this prevents `&""` validation failures at registry load time.

**description tokens**: Use `{damage}`, `{shield}`, `{distance}`, `{draw}`, `{status}`, `{duration}` as substitution tokens matching GDD description format. Story 004 implements the resolver. Token names must match the effect field they map to.

**card_color values** (GDD S.3):
- GUNSLINGER: `Color(0.85, 0.25, 0.15)` — Red/Ember
- DRIFTER: `Color(0.15, 0.55, 0.65)` — Blue/Teal
- OUTLAW: `Color(0.80, 0.65, 0.10)` — Yellow/Amber
- NEUTRAL: `Color(0.75, 0.75, 0.75)` — Grey/White

**Outlaw expansion**: Story 003 ships the 10 cards that enable all three starter deck prototypes to function. Full Outlaw deck authoring (wild_card, ricochet, hot_streak) is a follow-on task tracked as Story 003b or included in the first content sprint.

---

## Out of Scope

- Story 001: CardData and CardEffect class definitions (prerequisite)
- Story 002: CardRegistry autoload (prerequisite — must exist to validate loading)
- Story 004: Description variable substitution (tokens authored here, resolved in Story 004)
- Uncommon, Rare, or Legendary cards (post-MVP content sprint)
- Upgraded card variants (post-MVP)
- Card art assets (art sprint — placeholder null for MVP)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check — all 10 cards load without error; `get_starter_deck()` returns correct composition
**Gate level**: ADVISORY
**Status**: [ ] Not yet created

### Smoke Check Checklist

| Check | Expected | Pass/Fail |
|-------|----------|-----------|
| All 10 `.tres` files load via `ResourceLoader.load()` without error | No null returns, no script errors | [ ] |
| `CardRegistry.get_all_cards().size() >= 10` | At least 10 cards in registry | [ ] |
| `CardRegistry.get_starter_deck(GUNSLINGER).size() == 8` | Exactly 8 cards | [ ] |
| `CardRegistry.get_starter_deck(DRIFTER).size() == 8` | Exactly 8 cards | [ ] |
| All starter cards have `rarity == COMMON` | No UNCOMMON/RARE/LEGENDARY in any starter deck | [ ] |
| All ATTACK cards: `total_commit_frames` within F.3 ATTACK budget (16–39 frames) | `windup + active + recovery` in [16, 39] | [ ] |
| All SKILL cards: `total_commit_frames` within F.3 SKILL budget (10–24 frames) | `windup + active + recovery` in [10, 24] | [ ] |
| All POWER cards: `total_commit_frames` within F.3 POWER budget (7–16 frames) | `windup + active + recovery` in [7, 16] | [ ] |
| No card has `card_id == &""` | Registry validation rejects empty ids | [ ] |
| No card has `animation_key == &""` | All animation keys are non-empty StringNames | [ ] |

---

## Dependencies

- **Depends on**: Story 001 (CardData and CardEffect class definitions must exist — authoring .tres files requires the class to be registered)
- **Depends on**: Story 002 (CardRegistry autoload — needed to validate loading and run smoke checks; `get_starter_deck()` smoke check requires registry)
- **Unlocks**: All downstream systems that consume the starter card pool (Card Hand System, Deck Building System, Combat System prototyping)
