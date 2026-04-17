# Dungeon Generation System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 3 (Adapt or Die), Pillar 4 (Earn Everything)

## Summary

The Dungeon Generation System creates procedural floor layouts from a pool of
hand-crafted rooms, generates branching paths with risk/reward choices, and
manages room connectivity. It builds the physical structure of each run —
the "where" that Combat, Enemy AI, and Reward systems populate with the "what."

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Entity Framework`

## Overview

The Dungeon Generation System builds the player's journey through each run.
A floor is not a grid of random tiles — it's a graph of hand-crafted rooms
connected by branching paths. The player sees a map of room nodes and chooses
which path to take, trading safety for reward. Each room has a type (combat,
elite, rest, reward, shop, boss) that determines what happens inside. Room
layouts are hand-designed scene files — the procedural element is which rooms
appear where and how they connect, not the room geometry itself. This gives
level designers control over encounter spaces while the system provides run
variety. A floor always starts with an entry room and ends with a boss room,
with `ROOMS_PER_FLOOR` rooms between them across `PATH_COLUMNS` columns of
branching choices.

## Player Fantasy

The dungeon map unfolds before you — a web of branching paths with icons
hinting at what lies ahead. The safe path has two combat rooms and a rest
stop. The dangerous path has an elite encounter but a rare card reward behind
it. You've been trimming your deck and feel confident. You take the dangerous
path. The dungeon rewards your risk — or punishes your hubris. Either way,
the choice was yours. Every run tells a different story because every run
follows a different path through a different arrangement of rooms.

## Detailed Rules

### Floor Structure

**FS.1 — Floor Graph**

A floor is a directed acyclic graph (DAG) of room nodes:

```
[Entry] → Column 1 → Column 2 → ... → Column N → [Boss]
```

| Property | Value |
|----------|-------|
| Entry room | Always 1, always a combat tutorial/warm-up room |
| Columns | `PATH_COLUMNS` (default: 4) |
| Rooms per column | `ROOMS_PER_COLUMN` (default: 2-3, varies by column) |
| Boss room | Always 1, always the final node |
| Total rooms | Entry + sum(column rooms) + Boss = ~10-14 rooms per floor |

**FS.2 — Path Branching**

Each room node connects forward to 1-2 rooms in the next column. The player
chooses which connected room to enter. Constraints:
- Every room must be reachable from at least one room in the previous column
- Every room must connect to at least one room in the next column
- No isolated rooms (every room is on a valid path from entry to boss)
- Cross-connections between lanes create meaningful route choices

**FS.3 — Column Configuration**

| Column | Rooms | Typical Types |
|--------|-------|---------------|
| Entry | 1 | Combat (easy) |
| 1 | 2 | Combat, Combat |
| 2 | 3 | Combat, Elite, Rest |
| 3 | 2 | Combat, Reward |
| 4 | 3 | Combat, Elite, Rest |
| Boss | 1 | Boss |

Column configurations are defined per floor as templates. The system selects
room types within each column based on the template and randomization.

### Room Types

**RT.1 — Room Type Definitions**

| Type | Icon | What Happens | Frequency |
|------|------|-------------|-----------|
| `COMBAT` | Sword | Standard enemy encounter. 3-5 enemies. Reward on clear. | 50-60% |
| `ELITE` | Skull | Elite enemy encounter. 1-2 elites. Better reward. | 10-15% |
| `REST` | Campfire | Heal `REST_HEAL_PERCENT` HP. Optional trim opportunity. | 10-15% |
| `REWARD` | Chest | Card draft with guaranteed UNCOMMON+ option. | 10% |
| `SHOP` | Coin | Future: buy/sell cards with currency. Empty room in MVP. | 5% |
| `BOSS` | Crown | Boss encounter. One per floor. Clears the floor. | 1 per floor |
| `ENTRY` | Door | First room. Easy combat. Warm-up. | 1 per floor |

**RT.2 — Room Type Placement Rules**

- No two ELITE rooms in adjacent columns
- At least one REST room per floor
- REWARD room never in column 1 (earn rewards, don't start with them)
- BOSS always in final position
- ENTRY always in first position
- No back-to-back REST rooms on the same path

### Room Pool

**RP.1 — Hand-Crafted Rooms**

Each room type has a pool of hand-crafted scene files:

```
assets/scenes/rooms/
├── combat/
│   ├── combat_arena_01.tscn
│   ├── combat_arena_02.tscn
│   └── ...
├── elite/
│   ├── elite_arena_01.tscn
│   └── ...
├── rest/
│   ├── rest_room_01.tscn
│   └── ...
├── boss/
│   ├── boss_arena_01.tscn
│   └── ...
└── entry/
    ├── entry_room_01.tscn
    └── ...
```

**RP.2 — Room Selection**

For each node in the floor graph:
1. Determine room type (from column template + randomization)
2. Filter room pool by type
3. Exclude rooms already used on this floor (no repeats per floor)
4. Select randomly from remaining pool (seeded RNG)
5. If pool exhausted: allow repeats from least-recently-used

**RP.3 — Room Scene Requirements**

Each room scene must contain:
- `RoomBounds` node: defines camera clamping rectangle
- `SpawnPoints` node: positions for enemy spawning (combat/elite rooms)
- `PlayerSpawn` node: where the player appears on room entry
- `ExitTrigger` node(s): areas that trigger room completion/transition
- `RoomData` resource: metadata (room type, difficulty rating, tags)

### Floor Generation Algorithm

**FG.1 — Generation Steps**

```
1. Read floor template (column count, room counts per column, type weights)
2. Create floor graph structure (nodes + edges)
3. For each column:
   a. Determine room count for this column
   b. Assign room types based on template weights + placement rules
   c. Connect rooms to previous column (ensure all reachable)
   d. Connect rooms to next column (ensure all connect forward)
4. Select room scenes from pool for each node
5. Determine enemy compositions for combat rooms (from Enemy AI data)
6. Store floor graph in FloorData resource
7. Emit floor_generated(floor_data)
```

**FG.2 — Seeded Generation**

All randomization uses a seeded `RandomNumberGenerator`:
```
floor_seed = run_seed XOR floor_number
rng = RandomNumberGenerator.new()
rng.seed = floor_seed
```

Same run seed + floor number = same floor layout. Enables debug reproduction
and future daily challenge runs.

### Navigation

**NAV.1 — Room Transitions**

When the player clears a room (all enemies defeated, or non-combat room action
completed):
1. Exit trigger activates
2. Dungeon Map UI shows available next rooms
3. Player selects next room
4. Camera System performs room transition (hard cut with fade)
5. New room loads, player spawns at PlayerSpawn
6. Room encounter begins (Room Encounter System activates enemies)

**NAV.2 — No Backtracking**

Once the player leaves a room, they cannot return to it. Progression is
strictly forward through the floor graph. This prevents farming and maintains
pacing.

## Formulas

**F.1 — Floor Difficulty Scaling**

```
Variables:
  floor_number     = current floor (1-indexed)
  base_enemy_count = base enemies per combat room (default: 3)
  ENEMY_SCALING    = additional enemies per floor (default: 0.5)
  base_enemy_hp_mult = 1.0 for floor 1

Output:
  enemy_count = enemies in a combat room on this floor
  hp_mult     = HP multiplier for enemies on this floor

Formula:
  enemy_count = floor(base_enemy_count + (floor_number - 1) * ENEMY_SCALING)
  hp_mult = 1.0 + (floor_number - 1) * HP_SCALING_PER_FLOOR

Example (Floor 1):
  enemy_count = floor(3 + 0 * 0.5) = 3
  hp_mult = 1.0 + 0 * 0.15 = 1.0

Example (Floor 3):
  enemy_count = floor(3 + 2 * 0.5) = floor(4.0) = 4
  hp_mult = 1.0 + 2 * 0.15 = 1.3 (enemies have 30% more HP)
```

**F.2 — Edge Connection Probability**

```
Variables:
  rooms_this_col  = room count in current column
  rooms_next_col  = room count in next column
  MIN_CONNECTIONS = each room must have at least 1 forward connection
  MAX_CONNECTIONS = 2

Output:
  edges = list of (room_a, room_b) connections

Algorithm:
  1. For each room in this column: connect to nearest room in next column (guaranteed 1)
  2. For each room in next column with 0 incoming: connect from nearest in this column
  3. For remaining slots: add cross-connections with P = CROSS_CONNECT_CHANCE
```

## Edge Cases

- **Room pool has fewer rooms than floor needs**: Allow repeats. Select from
  full pool, preferring rooms not yet used on this floor. Log a warning if
  repeats are needed. MVP with a small room pool will hit this often.

- **Column has 0 rooms assigned**: Invalid template. Generator logs error and
  adds 1 COMBAT room as fallback. Should be caught by template validation.

- **Player at full HP entering REST room**: Heal is still offered (clamped to
  max). Trim opportunity still available. Room is not wasted — trim is valuable.

- **All paths through floor lead to ELITE rooms**: Template placement rules
  should prevent this (no back-to-back elites). If it occurs due to template
  error, the floor is harder but not impossible.

- **Boss room with no forward connections**: Correct — boss is terminal.
  Defeating the boss triggers floor completion and next floor generation (or
  run victory on final floor).

- **Run seed = 0**: Valid seed. RNG operates normally with seed 0. No special
  handling needed.

- **Floor generation on a floor number beyond designed content**: Use the
  highest floor template available with scaling multipliers. Endless mode
  support for post-MVP.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Entity Framework | Room scenes contain entity spawn points | Hard |
| Downstream | Room Encounter System | Provides room data (type, enemies, spawn points) | Hard |
| Downstream | Reward System | Room type determines reward tier | Soft |
| Downstream | Run State Manager | Floor progress, current room, available paths | Hard |
| Downstream | Camera System | Room bounds for camera clamping | Hard |
| Downstream | Dungeon Map UI | Floor graph for map display | Hard |

Public API:

```gdscript
# Generation
func generate_floor(floor_number: int, run_seed: int) -> FloorData
func get_current_room() -> RoomData
func get_available_exits() -> Array[RoomNode]

# Navigation
func select_next_room(room_node: RoomNode) -> void
func is_floor_complete() -> bool

# Signals
signal floor_generated(floor_data: FloorData)
signal room_entered(room_data: RoomData)
signal room_cleared(room_data: RoomData)
signal floor_completed(floor_number: int)
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `PATH_COLUMNS` | 4 | 3–6 | Columns between entry and boss. More = longer floor, more choices. |
| `ROOMS_PER_COLUMN_MIN` | 2 | 1–3 | Minimum rooms in a column. |
| `ROOMS_PER_COLUMN_MAX` | 3 | 2–4 | Maximum rooms in a column. |
| `CROSS_CONNECT_CHANCE` | 0.3 | 0.1–0.6 | Probability of extra connections between columns. More = more route options. |
| `REST_HEAL_PERCENT` | 0.30 | 0.15–0.50 | HP healed at rest rooms. |
| `ENEMY_SCALING` | 0.5 | 0.25–1.0 | Extra enemies per floor. Higher = steeper difficulty curve. |
| `HP_SCALING_PER_FLOOR` | 0.15 | 0.10–0.25 | Enemy HP increase per floor. Higher = spongier enemies later. |
| `COMBAT_ROOM_WEIGHT` | 55 | 40–70 | Percentage weight for combat rooms in column template. |
| `ELITE_ROOM_WEIGHT` | 12 | 5–20 | Percentage weight for elite rooms. |
| `REST_ROOM_WEIGHT` | 13 | 8–20 | Percentage weight for rest rooms. |

## Acceptance Criteria

1. **GIVEN** `generate_floor(1, seed)` called, **WHEN** floor generated,
   **THEN** floor has entry room, `PATH_COLUMNS` columns, and boss room.

2. **GIVEN** any generated floor, **WHEN** graph traversed, **THEN** at least
   one valid path exists from entry to boss.

3. **GIVEN** same run_seed and floor_number, **WHEN** floor generated twice,
   **THEN** identical floor layout both times.

4. **GIVEN** floor graph displayed, **WHEN** player selects a connected room,
   **THEN** room loads and encounter begins.

5. **GIVEN** player clears a room, **WHEN** exits shown, **THEN** only
   forward-connected rooms are selectable. No backtracking.

6. **GIVEN** column template specifies 2-3 rooms, **WHEN** rooms assigned,
   **THEN** room count is within range and room types follow placement rules.

7. **GIVEN** no two ELITE rooms in adjacent columns rule, **WHEN** floor
   generated, **THEN** no path through the floor has back-to-back ELITE rooms.

8. **GIVEN** at least one REST room per floor rule, **WHEN** floor generated,
   **THEN** at least one REST room exists in the floor graph.

9. **GIVEN** Floor 3 with `ENEMY_SCALING = 0.5`, **WHEN** combat room enemy
   count calculated, **THEN** count = floor(3 + 2*0.5) = 4 enemies.

10. **GIVEN** boss defeated, **WHEN** `is_floor_complete()` checked, **THEN**
    returns true, `floor_completed` signal fires.
