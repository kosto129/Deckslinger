# Room Encounter System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (Every Card Is a Commitment), Pillar 3 (Adapt or Die)

## Summary

The Room Encounter System orchestrates what happens inside each room: enemy
spawning sequences, encounter state management (setup → combat → clear →
reward), wave logic, and the transitions between room phases. It connects
Dungeon Generation (which room) with Combat, Enemy AI, and Reward (what
happens in the room).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Dungeon Generation, Combat, Enemy AI, Reward`

## Overview

The Room Encounter System is the director of each combat encounter. When the
player enters a room, this system reads the room data (enemy composition, spawn
points, wave configuration), locks the exits, spawns enemies in sequence, tracks
living enemy count, detects room clear, unlocks exits, and triggers the Reward
System. It manages the pacing within a room — not just "enemies appear" but
"enemies appear in a readable, fair, escalating sequence." Wave logic ensures
the player is never overwhelmed by spawning all enemies at once but also never
bored waiting for the next spawn. Non-combat rooms (rest, reward, shop) have
simplified encounter logic: enter → interact → complete.

## Player Fantasy

You enter a room. The exits seal behind you. A beat of silence — you read the
space, see the spawn positions light up. The first wave appears: two Rustlers.
You handle them. Before the last one falls, a second wave begins: a Rustler
and a Sharpshooter. The room is escalating. When the last enemy falls, a
satisfying "room clear" chime plays, the exits unseal, and your reward appears.
The room felt like a complete encounter — a beginning, middle, and climax —
not a random pile of enemies.

## Detailed Rules

### Encounter States

**ES.1 — State Machine**

| State | Description | Exits Locked | Enemies Active |
|-------|-------------|-------------|----------------|
| `SETUP` | Player entered, room initializing | Yes | No |
| `SPAWNING` | Enemies appearing in waves | Yes | Spawning |
| `COMBAT` | All waves spawned, enemies alive | Yes | Yes |
| `CLEARING` | Last enemy dying (death animation playing) | Yes | Dying |
| `CLEARED` | All enemies dead, reward available | No | No |
| `COMPLETE` | Player has collected reward and chosen exit | No | No |
| `IDLE` | Non-combat room (rest/reward/shop) | No | No |

**ES.2 — State Transitions**

```
Player enters room →
  SETUP (initialize room, read encounter data) →
  SPAWNING (spawn wave 1, then wave 2, etc.) →
  COMBAT (all waves spawned, enemies remain) →
  CLEARING (last enemy HP = 0, death animation) →
  CLEARED (all enemies despawned, reward generated) →
  COMPLETE (player collects reward, selects exit)

Non-combat rooms:
  Player enters → IDLE (interactions available) → COMPLETE (player selects exit)
```

### Wave System

**WS.1 — Wave Definition**

Each combat room's encounter is defined as an ordered list of waves:

```gdscript
class_name WaveData extends Resource

var enemies: Array[EnemySpawnEntry]  # which enemies and where
var spawn_delay_frames: int          # delay before this wave starts
var trigger: WaveTrigger             # what triggers this wave
```

**WS.2 — Wave Triggers**

| WaveTrigger | Condition | Example |
|-------------|-----------|---------|
| `ON_ENTER` | Triggers when encounter begins | First wave always uses this |
| `ON_TIMER` | Triggers after `spawn_delay_frames` from previous wave | Second wave after 120 frames |
| `ON_ENEMY_COUNT` | Triggers when living enemies drop to N | Wave 2 when wave 1 has 1 enemy left |
| `ON_PERCENT_CLEARED` | Triggers when N% of total enemies are dead | Elite reinforcements at 50% |

**WS.3 — Enemy Spawn Entry**

```gdscript
class_name EnemySpawnEntry extends Resource

var enemy_type_id: StringName   # references EnemyBehaviorData
var spawn_point_id: StringName  # which SpawnPoint node in room
var spawn_delay_frames: int     # delay within the wave (stagger)
```

**WS.4 — Spawn Sequence**

Within a wave, enemies spawn with staggered delays:
1. Wave trigger fires
2. For each EnemySpawnEntry in the wave (ordered by spawn_delay_frames):
   a. Wait `spawn_delay_frames` from wave start
   b. Instantiate enemy at designated spawn point
   c. Entity lifecycle: INACTIVE → call `activate()` → SPAWNING
   d. Spawn animation plays (per Animation State Machine)
   e. After spawn animation: entity → ACTIVE, AI begins

### Enemy Composition

**EC.1 — Composition by Room Type**

| Room Type | Waves | Total Enemies | Composition |
|-----------|-------|--------------|-------------|
| COMBAT (Floor 1) | 1-2 | 3-4 | All standard enemies |
| COMBAT (Floor 2+) | 2-3 | 4-6 | Standard + occasional mixed types |
| ELITE | 1-2 | 1-2 elites + 2-3 standard | Elite + support enemies |
| BOSS | 1 + phases | 1 boss + possible adds | Boss-specific (Boss System GDD) |

**EC.2 — Composition Rules**

- No more than 2 of the same enemy type in a single wave
- At least 1 melee enemy per combat room (ensures close-range engagement)
- Elite rooms always have at least 1 elite enemy
- Enemy count scales with floor number (per Dungeon Generation F.1)

### Room Clear Logic

**RC.1 — Clear Detection**

Room is cleared when:
1. All waves have been triggered AND
2. All spawned enemies have been despawned (death animation complete, `despawned` signal received)

The system tracks:
- `total_enemies_spawned`: incremented on each spawn
- `total_enemies_despawned`: incremented on each `despawned` signal
- Clear condition: `total_enemies_despawned >= total_enemies_spawned AND all_waves_triggered`

**RC.2 — Clear Sequence**

```
1. Last enemy despawns
2. Wait CLEAR_DELAY frames (dramatic pause)
3. Play room clear audio/VFX
4. Unlock exits
5. Generate reward (Reward System)
6. Transition to CLEARED state
7. Player can now interact with reward or select exit
```

### Non-Combat Rooms

**NCR.1 — Rest Room**

```
1. Enter → IDLE state
2. Show heal option (REST_HEAL_PERCENT of max HP)
3. Show trim option (if available)
4. Player interacts (heal, trim, or both)
5. Exits already unlocked → COMPLETE when player selects exit
```

**NCR.2 — Reward Room**

```
1. Enter → IDLE state
2. Chest/treasure visual in room center
3. Player interacts with chest → Reward System generates TREASURE tier reward
4. Draft screen appears
5. After draft → COMPLETE
```

## Formulas

**F.1 — Wave Timing**

```
Variables:
  wave_index     = 0-indexed wave number
  BASE_WAVE_DELAY = frames between waves (default: 90 = 1.5s)
  STAGGER_DELAY   = frames between enemies within a wave (default: 15 = 0.25s)

Output:
  wave_start_frame = when wave begins spawning (for ON_TIMER triggers)
  enemy_spawn_frame = when specific enemy in wave spawns

Formula:
  wave_start_frame = previous_wave_start + BASE_WAVE_DELAY
  enemy_spawn_frame = wave_start_frame + (enemy_index * STAGGER_DELAY)

Example (Wave 2, 3 enemies, wave starts at frame 90):
  Enemy 0: frame 90
  Enemy 1: frame 105
  Enemy 2: frame 120
  Full wave spawned over 0.5 seconds
```

**F.2 — Enemy Count by Floor**

```
(Same as Dungeon Generation F.1)
enemy_count = floor(base_enemy_count + (floor_number - 1) * ENEMY_SCALING)

The Room Encounter System reads this from the Dungeon Generation System's
FloorData. It does not recalculate — single source of truth.
```

## Edge Cases

- **Player kills all wave 1 enemies before wave 2 trigger**: If wave 2 uses
  `ON_TIMER`, it fires when the timer elapses regardless of enemy count. If
  wave 2 uses `ON_ENEMY_COUNT(0)`, it fires immediately when wave 1 clears.
  Both are valid wave designs.

- **Player dies during encounter**: Run ends. Room encounter state is
  irrelevant. Run State Manager handles death. Encounter does not "complete."

- **Enemy spawns at occupied spawn point**: Enemies push apart via AI separation
  force. Brief overlap is acceptable. Spawn points should be spaced by at
  least `SEPARATION_RADIUS * 2` to minimize this.

- **Room has 0 waves defined**: Non-combat room or content error. If room type
  is COMBAT, log error, immediately transition to CLEARED. Treat as empty room.

- **All spawn points occupied when wave triggers**: Spawn at the least-occupied
  spawn point. Enemies will separate naturally. Not ideal but prevents spawn
  failure.

- **Room clear with enemy stuck in DYING animation**: `despawned` signal is
  required for clear tracking. If death animation hangs, Entity Framework's
  `death_animation_timeout` force-despawns the entity. Room eventually clears.

- **Wave trigger ON_ENEMY_COUNT with N higher than current enemies**: Wave
  triggers immediately (condition already met). This can be used intentionally
  for instant follow-up waves.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Dungeon Generation | Room data, enemy composition, spawn points | Hard |
| Upstream | Combat System | `entity_killed` signal for enemy tracking | Hard |
| Upstream | Enemy AI System | Enemy type data for spawning behavior | Hard |
| Upstream | Entity Framework | `despawned` signal for clear detection, entity lifecycle | Hard |
| Downstream | Reward System | Triggers reward generation on room clear | Hard |
| Downstream | Camera System | Room bounds for camera setup on entry | Soft |
| Downstream | Card Hand System | Encounter start/end lifecycle | Hard |
| Downstream | Run State Manager | Room clear status for progression tracking | Soft |

Public API:

```gdscript
# Encounter lifecycle
func start_encounter(room_data: RoomData) -> void
func get_encounter_state() -> EncounterState
func get_enemies_remaining() -> int
func get_total_enemies() -> int

# Signals
signal encounter_started(room_data: RoomData)
signal wave_spawned(wave_index: int)
signal enemy_spawned(entity: EntityBase)
signal room_cleared(room_data: RoomData)
signal encounter_complete(room_data: RoomData)
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `CLEAR_DELAY` | 30 frames (0.5s) | 15–60 | Pause after last enemy dies before room clears. Dramatic beat. |
| `BASE_WAVE_DELAY` | 90 frames (1.5s) | 45–150 | Default delay between waves (ON_TIMER). |
| `STAGGER_DELAY` | 15 frames (0.25s) | 8–30 | Delay between enemies within a wave. Lower = more simultaneous. |
| `SETUP_FRAMES` | 30 frames (0.5s) | 15–60 | Frames in SETUP before first wave. Player reads the room. |
| `MAX_ENEMIES_ALIVE` | 6 | 4–8 | Cap on simultaneous living enemies. Waves wait if cap reached. |

## Acceptance Criteria

1. **GIVEN** player enters combat room, **WHEN** encounter starts, **THEN**
   exits lock, SETUP state for `SETUP_FRAMES`, then first wave spawns.

2. **GIVEN** wave with 3 enemies and STAGGER_DELAY=15, **WHEN** wave triggers,
   **THEN** enemies spawn 15 frames apart (frames 0, 15, 30).

3. **GIVEN** wave trigger ON_ENEMY_COUNT(1), **WHEN** living enemies drops to 1,
   **THEN** next wave triggers immediately.

4. **GIVEN** all enemies despawned and all waves triggered, **WHEN** clear
   checked, **THEN** room transitions to CLEARED after CLEAR_DELAY.

5. **GIVEN** room cleared, **WHEN** CLEARED state entered, **THEN** exits
   unlock, Reward System generates reward.

6. **GIVEN** rest room entered, **WHEN** encounter starts, **THEN** state is
   IDLE, exits are unlocked, heal/trim options available.

7. **GIVEN** `MAX_ENEMIES_ALIVE = 6` and 6 enemies alive, **WHEN** next wave
   would spawn, **THEN** wave is delayed until enemy count drops below cap.

8. **GIVEN** enemy stuck in DYING for `death_animation_timeout` frames, **WHEN**
   force-despawned, **THEN** despawned signal fires, room clear logic proceeds.

9. **GIVEN** `get_enemies_remaining()` called mid-combat, **WHEN** 2 of 5
   enemies dead, **THEN** returns 3.

10. **GIVEN** player dies during encounter, **WHEN** death processed, **THEN**
    encounter does not complete, no reward generated.
