# Reward System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 4 (Earn Everything)

## Summary

The Reward System determines what the player receives after clearing encounters:
card draft pools, rarity distribution, currency amounts, and reward tier based
on room type and performance. It feeds the Deck Building System with draft
choices and manages the economy of card acquisition.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Card Data System, Deck Building System`

## Overview

The Reward System is where Pillar 4 lives. Every reward the player receives is
earned through combat — harder rooms yield better rewards, and the reward tier
system ensures that risk correlates with payoff. After clearing a combat or
elite encounter, the system determines the reward tier, constructs a card draft
pool using rarity weights from the Card Data System (adjusted by floor and room
type), selects `DRAFT_CHOICES` cards, and presents them to the Deck Building
System for player selection. The system also manages currency drops (for
future shop integration) and tracks reward statistics for the Run State Manager.

## Player Fantasy

You clear the elite encounter — barely, with 15 HP left. The reward screen
opens and three cards fan out. Two uncommons and a rare. The rare is a
Gunslinger card that synergizes perfectly with your last two drafts. You earned
this. The dangerous path paid off. In a different run, you take the safe route
and get three commons. Fine cards, useful, but nothing exciting. The game
respects the correlation: risk = reward. Nothing is random — it's weighted by
what you chose to face.

## Detailed Rules

### Reward Tiers

**RW.1 — Tier Definitions**

| Tier | Triggered By | Rarity Floor | Currency | Special |
|------|-------------|-------------|----------|---------|
| `STANDARD` | Clear a COMBAT room | COMMON | `BASE_CURRENCY` | Normal draft |
| `ELITE` | Clear an ELITE room | UNCOMMON | `BASE_CURRENCY × 2` | At least 1 UNCOMMON+ guaranteed |
| `BOSS` | Defeat a boss | RARE | `BASE_CURRENCY × 3` | At least 1 RARE+ guaranteed, upgrade opportunity |
| `TREASURE` | Enter a REWARD room | UNCOMMON | `BASE_CURRENCY` | Guaranteed UNCOMMON+ option |
| `NONE` | REST room, SHOP room | — | 0 | No card reward |

**RW.2 — Rarity Floor**

The rarity floor guarantees at least one card of that rarity or higher in the
draft choices. If the random generation doesn't produce one, the lowest-rarity
choice is replaced.

### Draft Pool Construction

**DP.1 — Pool Generation Steps**

```
1. Get eligible cards from CardRegistry (filtered by Deck Building constraints)
2. For each of DRAFT_CHOICES slots:
   a. Roll rarity using adjusted weights (see F.1)
   b. Filter eligible cards by rolled rarity
   c. Select random card from filtered set (no duplicates in draft)
3. Apply rarity floor: if no card meets minimum, replace lowest rarity card
4. Return DRAFT_CHOICES cards to Deck Building System
```

**DP.2 — Weight Adjustment by Room Type**

| Room Type | COMMON Adj | UNCOMMON Adj | RARE Adj | LEGENDARY Adj |
|-----------|-----------|-------------|---------|--------------|
| COMBAT | ±0 | ±0 | ±0 | ±0 |
| ELITE | -15 | +5 | +8 | +2 |
| BOSS | -25 | +5 | +15 | +5 |
| REWARD | -10 | +5 | +4 | +1 |

These adjustments are added to the base weights from Card Data System F.2
(which already factor in floor number).

### Currency

**CUR.1 — Currency Drops**

MVP currency is a simple integer counter. No currency types.

| Knob | Default | Description |
|------|---------|-------------|
| `BASE_CURRENCY` | 10 | Currency per standard combat room |
| `ELITE_CURRENCY_MULT` | 2 | Elite rooms give 2× |
| `BOSS_CURRENCY_MULT` | 3 | Boss rooms give 3× |
| `CURRENCY_FLOOR_BONUS` | 5 | Additional currency per floor number |

```
currency_reward = (BASE_CURRENCY + floor_number * CURRENCY_FLOOR_BONUS) * tier_multiplier
```

Currency is spent at SHOP rooms (future: card purchases, upgrades, rerolls).
In MVP, currency is tracked but shop functionality may be placeholder.

### Performance Bonus

**PB.1 — Bonus Criteria**

Post-MVP feature. In MVP, all rewards are based on room type and floor only.

Future performance modifiers:
- No damage taken: +1 rarity tier upgrade to one draft slot
- All enemies killed within time limit: +bonus currency
- Used all archetype cards: +archetype-specific draft weighting

## Formulas

**F.1 — Adjusted Rarity Weight**

```
Variables:
  base_weight[r]   = from Card Data System F.2 (floor-adjusted)
  room_adj[r]      = room type adjustment (see DP.2 table)

Output:
  final_weight[r] = weight for rarity r in this draft

Formula:
  final_weight[r] = max(base_weight[r] + room_adj[r], 1)

Example (Floor 2, ELITE room):
  Base weights (floor 2): COMMON=56, UNCOMMON=27, RARE=16, LEGENDARY=4
  Elite adjustments: -15, +5, +8, +2
  Final: COMMON=41, UNCOMMON=32, RARE=24, LEGENDARY=6
  Total=103
  RARE chance: 24/103 = 23.3% (vs 15.5% in standard combat)
```

**F.2 — Currency Reward**

```
Variables:
  BASE_CURRENCY       = 10
  floor_number        = current floor (1-indexed)
  CURRENCY_FLOOR_BONUS = 5
  tier_multiplier     = from reward tier (1, 2, or 3)

Output:
  currency = integer currency awarded

Formula:
  currency = (BASE_CURRENCY + floor_number * CURRENCY_FLOOR_BONUS) * tier_multiplier

Example (Floor 2, ELITE):
  currency = (10 + 2 * 5) * 2 = 20 * 2 = 40

Example (Floor 3, BOSS):
  currency = (10 + 3 * 5) * 3 = 25 * 3 = 75
```

## Edge Cases

- **Eligible draft pool has fewer cards than DRAFT_CHOICES**: Show whatever is
  available. If pool has 2 cards, show 2 choices. If pool is empty, show "No
  cards available" and skip draft. Log a warning.

- **Rarity floor cannot be met (no RARE cards available for BOSS reward)**:
  Use next-lowest available rarity. If no UNCOMMON either, use COMMON. The
  floor is best-effort, not a hard requirement.

- **Player skips draft**: Currency is still awarded. Draft choices are discarded.
  Run continues.

- **Currency overflow**: No maximum currency cap. Integer tracking. Extremely
  unlikely to overflow `int` in a single run.

- **Reward triggered for room with no enemies (empty combat room)**: Treat as
  STANDARD tier. Award reward normally. The room was cleared (no enemies to
  fight = already clear).

- **Two rewards in the same room (e.g., embedded chest in combat room)**: Each
  reward is independent. Player gets combat clear reward + chest reward
  sequentially. Each generates its own draft pool.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Card Data System | Rarity weights, card pool for drafting | Hard |
| Upstream | Deck Building System | Draft pool filtering (exclude owned cards, enforce rarity caps) | Hard |
| Downstream | Deck Building System | Provides draft choices for player selection | Hard |
| Downstream | Run State Manager | Currency tracking, reward statistics | Soft |
| Downstream | Reward Screen UI | Presents draft choices and currency to player | Hard |
| Downstream | Room Encounter System | Triggers reward on room clear | Soft |

Public API:

```gdscript
# Reward generation
func generate_reward(room_type: RoomType, floor_number: int) -> RewardData
func get_draft_choices(reward: RewardData) -> Array[CardData]
func get_currency_reward(reward: RewardData) -> int

# Signals
signal reward_generated(reward_data: RewardData)
signal reward_collected(reward_data: RewardData)
signal reward_skipped(reward_data: RewardData)
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `BASE_CURRENCY` | 10 | 5–25 | Currency per standard room. Higher = faster shop access. |
| `ELITE_CURRENCY_MULT` | 2 | 1.5–3 | Elite room currency multiplier. |
| `BOSS_CURRENCY_MULT` | 3 | 2–5 | Boss room currency multiplier. |
| `CURRENCY_FLOOR_BONUS` | 5 | 0–10 | Additional currency per floor. Higher = currency scales faster. |
| `DRAFT_CHOICES` | 3 | 2–5 | Cards shown per draft. Shared with Deck Building System. |
| `ELITE_RARE_ADJUSTMENT` | +8 | +3 to +15 | Bonus to RARE weight in elite rooms. |
| `BOSS_RARE_ADJUSTMENT` | +15 | +8 to +25 | Bonus to RARE weight in boss rooms. |

## Acceptance Criteria

1. **GIVEN** standard combat room cleared on Floor 1, **WHEN** reward generated,
   **THEN** tier is STANDARD, 3 draft choices shown, currency = 15.

2. **GIVEN** elite room cleared on Floor 2, **WHEN** draft pool constructed,
   **THEN** at least 1 card is UNCOMMON or higher (rarity floor).

3. **GIVEN** boss defeated on Floor 1, **WHEN** reward generated, **THEN**
   at least 1 RARE+ card in draft, currency = 45, upgrade opportunity offered.

4. **GIVEN** Floor 2 elite room, **WHEN** rarity weights calculated, **THEN**
   RARE weight = base + 8 (elite adjustment), higher than standard combat.

5. **GIVEN** player skips draft, **WHEN** reward phase ends, **THEN** currency
   still awarded, no card added to deck.

6. **GIVEN** draft pool has only 2 eligible cards, **WHEN** DRAFT_CHOICES=3,
   **THEN** 2 cards shown, no crash.

7. **GIVEN** rest room entered, **WHEN** reward checked, **THEN** tier is NONE,
   no card draft, no currency.

8. **GIVEN** same seed and floor/room combination, **WHEN** draft generated
   twice, **THEN** identical card choices both times.
