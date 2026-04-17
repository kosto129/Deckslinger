# Run State Manager

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: All (persistence infrastructure)

## Summary

The Run State Manager tracks all state for the current run: player deck, HP,
currency, floor progress, room history, and encounter results. It is the single
source of truth for "where is the player in this run and what do they have?"

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Deck Building System, Dungeon Generation System`

## Overview

The Run State Manager is the save file of a living run. It tracks everything
that persists between encounters: the player's current deck composition, their
HP, their currency, which floor they're on, which room they just cleared, what
rewards they've collected, and the run seed that makes procedural generation
reproducible. Every system that needs to know "what does the player have?" reads
from the Run State Manager. Every system that changes the player's persistent
state writes to it. It does not make decisions — it stores state and provides
access. On run start, it initializes from the starter deck and run parameters.
On run end (death or victory), it packages the run summary for meta-progression
(post-MVP) and statistics display.

## Player Fantasy

The Run State Manager is invisible. The player doesn't think about state
persistence — they think about their deck, their HP, their path through the
dungeon. When they check their deck mid-run, the Run State Manager provides
the data. When they clear a room and their HP persists to the next, the Run
State Manager holds that value. When a run ends and the death screen shows
"Floor 2, Room 7, 23 cards played, favorite card: Fan Shot," the Run State
Manager collected those statistics throughout the run. It's the memory of the
run.

## Detailed Rules

### Run Data

**RD.1 — RunState Resource**

```gdscript
class_name RunState extends Resource

# Identity
var run_seed: int                    # Master seed for all procedural generation
var run_id: int                      # Unique run identifier (incrementing)
var started_at: int                  # Unix timestamp of run start
var archetype: CardArchetype         # Player's chosen starting archetype

# Player State
var current_hp: int                  # Current HP (persists between rooms)
var max_hp: int                      # Maximum HP
var currency: int                    # Accumulated currency

# Deck
var deck: Array[StringName]          # Current deck (card IDs)

# Progression
var current_floor: int               # 1-indexed floor number
var current_room_index: int          # Index in the floor graph
var rooms_cleared: int               # Total rooms cleared this run
var floors_cleared: int              # Total floors cleared

# Floor Data
var floor_data: FloorData            # Current floor graph (from Dungeon Generation)
var visited_rooms: Array[int]        # Indices of rooms visited on current floor

# Statistics (tracked throughout run)
var cards_played: int                # Total card plays
var damage_dealt: int                # Total damage dealt to enemies
var damage_taken: int                # Total damage received
var enemies_killed: int              # Total enemies defeated
var cards_drafted: int               # Cards added via draft
var cards_trimmed: int               # Cards removed via trim
var cards_upgraded: int              # Cards upgraded
var favorite_card_id: StringName     # Most-played card (updated per encounter)
var run_duration_seconds: float      # Elapsed time
```

### Run Lifecycle

**RL.1 — Run Start**

```
1. Player selects starting archetype (or uses default)
2. RunState initialized:
   - run_seed = random or daily seed
   - current_hp = PLAYER_MAX_HP
   - currency = 0
   - deck = CardRegistry.get_starter_deck(archetype)
   - current_floor = 1
   - All statistics zeroed
3. Dungeon Generation creates Floor 1 using run_seed
4. floor_data stored in RunState
5. Player enters entry room
6. Emit run_started(run_state)
```

**RL.2 — Between Encounters**

After each room clear:
1. Card Hand System returns deck to RunState
2. Reward System adds currency to RunState
3. Deck Building System writes modified deck to RunState
4. HP changes are already reflected (HealthComponent → RunState sync)
5. Room added to visited_rooms
6. rooms_cleared incremented
7. Statistics updated (cards played, damage dealt, etc.)

**RL.3 — Floor Transition**

When boss is defeated:
1. floors_cleared incremented
2. current_floor incremented
3. HP healed by `FLOOR_HEAL_PERCENT` (per Combat System knob)
4. Dungeon Generation creates next floor
5. New floor_data stored
6. visited_rooms cleared
7. Player enters new floor's entry room

**RL.4 — Run End: Death**

```
1. Player HP reaches 0 in combat
2. Death animation plays
3. RunState captures final statistics
4. run_ended signal emits with outcome = DEATH
5. Death screen shows run summary
6. RunState archived (for meta-progression post-MVP)
7. Return to main menu / immediate restart option
```

**RL.5 — Run End: Victory**

```
1. Final boss defeated
2. Victory sequence plays
3. RunState captures final statistics
4. run_ended signal emits with outcome = VICTORY
5. Victory screen shows run summary + rewards
6. RunState archived
7. Return to main menu
```

### State Synchronization

**SS.1 — HP Sync**

Player HP is the source of truth in `HealthComponent` during combat. Between
encounters, RunState holds the authoritative value:

- On encounter start: `HealthComponent.set_hp(run_state.current_hp)`
- On encounter end: `run_state.current_hp = HealthComponent.get_current_hp()`
- On rest room heal: `run_state.current_hp = min(current_hp + heal_amount, max_hp)`

**SS.2 — Deck Sync**

Deck is the source of truth in Card Hand System during combat. Between
encounters, RunState holds the authoritative value:

- On encounter start: Card Hand System receives `run_state.deck`
- On encounter end: `run_state.deck = card_hand_system.end_encounter()`
- On draft/trim/upgrade: Deck Building System modifies `run_state.deck`

### Statistics Tracking

**ST.1 — Per-Encounter Statistics**

After each encounter, the following are aggregated:

| Stat | Source | Aggregation |
|------|--------|-------------|
| `cards_played` | Card Hand System | Sum per encounter |
| `damage_dealt` | Combat System `damage_dealt` signal | Sum all damage to enemies |
| `damage_taken` | Combat System `damage_dealt` signal (to player) | Sum all damage to player |
| `enemies_killed` | Combat System `entity_killed` signal | Count |

**ST.2 — Favorite Card**

Updated after each encounter:
```
card_play_counts[card_id] += plays_this_encounter
favorite_card_id = card with highest total play count
```

## Formulas

**F.1 — Run Seed Generation**

```
Variables:
  time_based = OS.get_unix_time()
  random     = randi()

Output:
  run_seed = deterministic seed for all procedural generation

Formula:
  run_seed = hash(time_based XOR random)
  (For daily challenges: run_seed = hash(date_string))
```

**F.2 — Rest Room Heal**

```
Variables:
  current_hp    = RunState.current_hp
  max_hp        = RunState.max_hp
  REST_HEAL_PERCENT = 0.30

Output:
  healed_hp = HP after rest heal

Formula:
  heal_amount = ceil(max_hp * REST_HEAL_PERCENT)
  healed_hp = min(current_hp + heal_amount, max_hp)

Example (current_hp = 55, max_hp = 100):
  heal_amount = ceil(100 * 0.30) = 30
  healed_hp = min(55 + 30, 100) = 85
```

## Edge Cases

- **Run seed collision (two runs with same seed)**: Functionally identical runs
  if same archetype is chosen. This is a feature for daily challenges, not a
  bug. For normal runs, collision probability is negligible.

- **Player exits game mid-run**: In MVP, run state is lost (no mid-run save).
  Save/Load System (Full Vision) will add persistence.

- **HP becomes 0 outside combat (e.g., status effect between rooms)**: Status
  effects clear between encounters. HP can only reach 0 during combat. If
  somehow it does (bug), treat as death.

- **Deck becomes empty (all cards trimmed below MIN)**: Prevented by
  `MIN_DECK_SIZE` enforcement in Deck Building System. If it occurs (bug), log
  error and add basic_strike to deck as fallback.

- **Statistics overflow**: All stat counters are `int`. A single run would need
  billions of card plays to overflow. No concern.

- **Run duration tracking during pause**: Timer pauses when game is paused.
  Only active gameplay time is counted.

- **Floor heal would exceed max HP**: Clamped to max_hp. Standard min/max
  clamping, no overhealing.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Deck Building System | Writes deck changes (draft, trim, upgrade) | Hard |
| Upstream | Dungeon Generation System | Writes floor data and room progression | Hard |
| Upstream | Combat System | HP sync, damage statistics, kill tracking | Hard |
| Upstream | Card Hand System | Deck sync between encounters | Hard |
| Upstream | Reward System | Currency accumulation | Hard |
| Downstream | Card Hand System | Provides deck at encounter start | Hard |
| Downstream | Dungeon Generation | Provides run_seed and floor_number | Hard |
| Downstream | All UI Systems | HP, currency, deck, floor info for display | Soft |
| Downstream | Meta-Progression (post-MVP) | Run results for persistent unlocks | Soft |

Public API:

```gdscript
# Run lifecycle
func start_run(archetype: CardArchetype, seed: int) -> void
func end_run(outcome: RunOutcome) -> RunSummary
func is_run_active() -> bool

# State access (read)
func get_current_hp() -> int
func get_max_hp() -> int
func get_currency() -> int
func get_deck() -> Array[StringName]
func get_current_floor() -> int
func get_run_seed() -> int
func get_run_statistics() -> RunStatistics

# State modification (write)
func set_current_hp(hp: int) -> void
func add_currency(amount: int) -> void
func set_deck(deck: Array[StringName]) -> void
func advance_room(room_index: int) -> void
func advance_floor() -> void

# Signals
signal run_started(run_state: RunState)
signal run_ended(summary: RunSummary, outcome: RunOutcome)
signal floor_advanced(floor_number: int)
signal room_advanced(room_index: int)
signal hp_changed(old_hp: int, new_hp: int)
signal currency_changed(old_amount: int, new_amount: int)
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `PLAYER_MAX_HP` | 100 | 60–200 | Starting and max HP. Shared with Combat System. |
| `STARTING_CURRENCY` | 0 | 0–50 | Currency at run start. 0 = earn everything. |
| `RESTART_DELAY_FRAMES` | 60 (1s) | 30–120 | Delay on death screen before restart is available. |

## Acceptance Criteria

1. **GIVEN** run started with GUNSLINGER archetype, **WHEN** RunState
   initialized, **THEN** deck = starter deck for Gunslinger, HP = max,
   currency = 0, floor = 1.

2. **GIVEN** encounter ends with player at 70 HP, **WHEN** RunState synced,
   **THEN** `get_current_hp()` returns 70.

3. **GIVEN** deck modified by Deck Building (card drafted), **WHEN** RunState
   queried, **THEN** `get_deck()` includes new card.

4. **GIVEN** boss defeated, **WHEN** floor advanced, **THEN** `current_floor`
   increments, HP healed by `FLOOR_HEAL_PERCENT`, new floor generated.

5. **GIVEN** player dies, **WHEN** `end_run(DEATH)` called, **THEN** RunSummary
   includes all statistics, `run_ended` signal fires.

6. **GIVEN** same run_seed and archetype, **WHEN** two runs started, **THEN**
   identical floor layouts and draft pools.

7. **GIVEN** 15 cards played in encounter, **WHEN** statistics updated, **THEN**
   `cards_played` increases by 15.

8. **GIVEN** rest room with REST_HEAL_PERCENT=0.30, max_hp=100, current_hp=55,
   **WHEN** heal applied, **THEN** HP becomes 85.

9. **GIVEN** run active, **WHEN** `is_run_active()` called, **THEN** returns true.

10. **GIVEN** run ended, **WHEN** `is_run_active()` called, **THEN** returns false.
