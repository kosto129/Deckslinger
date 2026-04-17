# Deckslinger — Master Architecture

## Document Status

- **Version**: 1.0
- **Last Updated**: 2026-04-17
- **Engine**: Godot 4.6 (GDScript)
- **GDDs Covered**: All 16 MVP systems
- **ADRs Referenced**: ADR-0001 through ADR-0009 (all 9 Foundation + Core ADRs — Accepted)
- **Technical Director Sign-Off**: Pending
- **Lead Programmer Feasibility**: Pending

---

## Engine Knowledge Gap Summary

**Engine**: Godot 4.6 | **LLM Training**: ~4.3 | **Post-Cutoff**: 4.4, 4.5, 4.6

| Risk | Domain | Impact on Deckslinger |
|------|--------|----------------------|
| HIGH | UI Dual-Focus (4.6) | Card Hand UI, menus must handle separate mouse/keyboard focus paths |
| MEDIUM | SDL3 Gamepad (4.5) | Gamepad device detection may differ; API unchanged |
| MEDIUM | @abstract (4.5) | Optional: could enforce EntityBase/component contracts |
| MEDIUM | duplicate_deep() (4.5) | Required: CardData with nested CardEffect arrays must use this for copies |
| LOW | 2D Physics, Signals, Resources, AnimatedSprite2D, InputMap | Unchanged from training data — safe |

**Conclusion**: This is a 2D game. The vast majority of post-cutoff changes affect 3D rendering, physics, and IK — none of which apply. The one HIGH risk item (UI dual-focus) is in the Presentation layer and won't block Foundation/Core work.

---

## Technical Requirements Baseline

Extracted from 16 GDDs | 62 total requirements

### Foundation Layer

| Req ID | System | Requirement | Domain |
|--------|--------|-------------|--------|
| TR-EF-001 | Entity Framework | Composition-based entity model using Godot scenes + typed child nodes | Scene Architecture |
| TR-EF-002 | Entity Framework | EntityType enum + 6-state lifecycle state machine on EntityBase | Core |
| TR-EF-003 | Entity Framework | Component discovery via typed get_node_or_null() | Core |
| TR-EF-004 | Entity Framework | Collision footprints ~50% of sprite canvas | Physics |
| TR-IN-001 | Input System | Named action map using Godot InputMap | Input |
| TR-IN-002 | Input System | Single-slot input buffer with frame-counted expiry (8 frames default) | Input |
| TR-IN-003 | Input System | 8-directional movement with diagonal normalization | Input |
| TR-IN-004 | Input System | Gamepad dead zone remapping (inner/outer thresholds) | Input |
| TR-IN-005 | Input System | Two input modes (GAMEPLAY/UI) with buffer clear on switch | Input |
| TR-IN-006 | Input System | Device detection with automatic UI prompt switching | Input |
| TR-CD-001 | Card Data | CardData as Godot Resource (.tres files) | Data |
| TR-CD-002 | Card Data | CardEffect as nested Resource array on CardData | Data |
| TR-CD-003 | Card Data | CardRegistry autoload for runtime lookup by card_id | Data |
| TR-CD-004 | Card Data | Archetype, Rarity, CardType, EffectType enums in shared file | Data |
| TR-CD-005 | Card Data | Variable substitution in card description strings | Data |
| TR-CM-001 | Camera | 384×216 SubViewport with integer scaling to display | Rendering |
| TR-CM-002 | Camera | Exponential follow with pixel snapping (round to int) | Rendering |
| TR-CM-003 | Camera | Room boundary clamping | Rendering |
| TR-CM-004 | Camera | Screen shake with per-frame decay | Rendering |
| TR-CM-005 | Camera | Hit-freeze camera position hold | Rendering |
| TR-CM-006 | Camera | Hard-cut room transitions with fade overlay | Rendering |

### Core Layer

| Req ID | System | Requirement | Domain |
|--------|--------|-------------|--------|
| TR-AS-001 | Animation State Machine | 3-phase action sequence (windup→active→recovery) with frame counting | Animation |
| TR-AS-002 | Animation State Machine | Commitment enforcement — no cancel during action phases | Animation |
| TR-AS-003 | Animation State Machine | Hit-stop frame freeze on both attacker and target | Animation |
| TR-AS-004 | Animation State Machine | 8-directional sprite animation with direction locking during actions | Animation |
| TR-AS-005 | Animation State Machine | AnimatedSprite2D with SpriteFrames at 12 art fps (5 physics frames per art frame) | Animation |
| TR-CH-001 | Collision/Hitbox | Area2D-based hitbox/hurtbox with collision layer/mask | Physics |
| TR-CH-002 | Collision/Hitbox | Faction filtering via collision masks (7 layers) | Physics |
| TR-CH-003 | Collision/Hitbox | HitData packet creation and delivery via signals | Physics |
| TR-CH-004 | Collision/Hitbox | Single-hit rule per action per target (hit tracking set) | Physics |
| TR-CH-005 | Collision/Hitbox | I-frames with visual flicker (20 frames default) | Physics |
| TR-CH-006 | Collision/Hitbox | Dodge i-frames via hurtbox disable (12 frames) | Physics |
| TR-CO-001 | Combat | Multiplicative damage pipeline (base × vuln × resist × stun × crit) | Combat |
| TR-CO-002 | Combat | HealthComponent as sole HP authority | Combat |
| TR-CO-003 | Combat | Death sequence triggering Entity lifecycle transition | Combat |
| TR-CO-004 | Combat | Hit-stop orchestration across Animation + Camera + Input | Combat |
| TR-CO-005 | Combat | Floating damage number VFX spawning at hit position | Combat |
| TR-CO-006 | Combat | DoT damage through same pipeline (no hit-stop/shake) | Combat |
| TR-HA-001 | Card Hand | Use-to-draw cycling: play card → draw replacement | Gameplay |
| TR-HA-002 | Card Hand | Seeded RNG for draw pile shuffle (run_seed XOR room_index) | Gameplay |
| TR-HA-003 | Card Hand | Draw pile / discard pile management with reshuffle | Gameplay |
| TR-HA-004 | Card Hand | Per-slot cooldown tracking in physics frames | Gameplay |
| TR-HA-005 | Card Hand | Encounter lifecycle: deal → play → end → return to deck | Gameplay |

### Feature Layer

| Req ID | System | Requirement | Domain |
|--------|--------|-------------|--------|
| TR-SE-001 | Status Effects | StatusEffectData as Resource definitions | Data |
| TR-SE-002 | Status Effects | 4 stacking rules (REFRESH/INTENSITY/INDEPENDENT/NONE) | Gameplay |
| TR-SE-003 | Status Effects | Per-frame tick processing for DoT effects | Gameplay |
| TR-SE-004 | Status Effects | Modifier interface for Combat damage queries | Gameplay |
| TR-SE-005 | Status Effects | Shield damage absorption before HP | Gameplay |
| TR-SE-006 | Status Effects | Stun integration with Entity lifecycle | Gameplay |
| TR-EA-001 | Enemy AI | FSM per enemy type via EnemyBehaviorData Resource | AI |
| TR-EA-002 | Enemy AI | EnemyAttackData Resource with telegraph types | AI |
| TR-EA-003 | Enemy AI | Weighted random attack selection | AI |
| TR-EA-004 | Enemy AI | Separation force between overlapping enemies | AI |
| TR-DB-001 | Deck Building | Draft pool construction with rarity/duplicate filtering | Gameplay |
| TR-DB-002 | Deck Building | Deck size constraints (min 6, max 30) | Gameplay |
| TR-DB-003 | Deck Building | Rarity deck limits (3 Rare, 1 Legendary) | Gameplay |
| TR-DG-001 | Dungeon Gen | DAG floor graph with columns and branching | Procedural |
| TR-DG-002 | Dungeon Gen | Room type placement rules (no adjacent elites, etc.) | Procedural |
| TR-DG-003 | Dungeon Gen | Hand-crafted room pool via PackedScene selection | Scene Architecture |
| TR-DG-004 | Dungeon Gen | Seeded generation (run_seed XOR floor_number) | Procedural |
| TR-RW-001 | Reward | Tiered rewards by room type with rarity weight adjustment | Economy |
| TR-RE-001 | Room Encounter | 7-state encounter state machine | Gameplay |
| TR-RE-002 | Room Encounter | Wave-based enemy spawning with configurable triggers | Gameplay |
| TR-RE-003 | Room Encounter | Clear detection via despawn counting | Gameplay |
| TR-RS-001 | Run State | RunState as persistent data across encounters | Persistence |
| TR-RS-002 | Run State | HP/deck sync between combat and persistence layers | Persistence |
| TR-RS-003 | Run State | Run seed for reproducible procedural generation | Persistence |

### Presentation Layer

| Req ID | System | Requirement | Domain |
|--------|--------|-------------|--------|
| TR-UI-001 | Card Hand UI | Arc layout with dynamic slot count | UI |
| TR-UI-002 | Card Hand UI | Play/draw card animations | UI |
| TR-UI-003 | Card Hand UI | Draw pile / discard pile indicators | UI |
| TR-UI-004 | Card Hand UI | Archetype color tinting + rarity visual effects | UI |
| TR-UI-005 | Card Hand UI | Gamepad/KB+M prompt switching via input_device_changed | UI |

---

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                             │
│  Card Hand UI · Combat HUD* · Reward Screen UI* · Dungeon Map* │
│  (* = Vertical Slice / post-MVP)                                │
├─────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                  │
│  Status Effects · Enemy AI · Deck Building · Dungeon Generation │
│  Reward System · Room Encounter · Run State Manager             │
├─────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                     │
│  Animation State Machine · Collision/Hitbox · Combat System     │
│  Card Hand System                                               │
├─────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                               │
│  Entity Framework · Input System · Card Data System             │
│  Camera System · Shared Enums · Scene Management                │
├─────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER (Godot 4.6 Engine)                              │
│  Node2D · Area2D · AnimatedSprite2D · Camera2D · SubViewport    │
│  InputMap · Resource · PackedScene · RandomNumberGenerator       │
└─────────────────────────────────────────────────────────────────┘
```

**Cross-cutting infrastructure** (not GDD systems, but required):
- **Shared Enums** (`src/core/enums.gd`): EntityType, CardArchetype, CardRarity, CardType, EffectType, Rarity, etc.
- **Scene Management** (`src/core/scene_manager.gd`): Room loading/unloading, transition orchestration
- **Game Manager** (`src/core/game_manager.gd`): Run lifecycle, state machine for game flow (menu→run→death→menu)

---

## Module Ownership

### Foundation Layer

| Module | Owns | Exposes | Consumes | Autoload | Engine APIs |
|--------|------|---------|----------|----------|-------------|
| **Entity Framework** | Entity lifecycle state, EntityBase scene structure, component contracts | `EntityBase` class, `lifecycle_state_changed` signal, component typed getters | Nothing (root) | No (per-entity) | Node2D, Area2D |
| **Input System** | Action buffer, device state, input mode | `get_movement_vector()`, `consume_buffered_action()`, `get_aim_direction()`, mode/device signals | Godot InputMap events | Yes: `InputManager` | Input, InputEvent, InputMap |
| **Card Data System** | CardData/CardEffect resources, card registry | `CardRegistry.get_card()`, `get_cards_by_*()`, `get_starter_deck()` | .tres files from `assets/data/cards/` | Yes: `CardRegistry` | Resource, ResourceLoader |
| **Camera System** | Camera position, shake state, transition state | `request_shake()`, `set_room_bounds()`, `transition_to_room()`, `set_frozen()` | Player position (Entity), aim direction (Input), room bounds (Dungeon Gen) | No (scene node) | Camera2D, SubViewport, Tween |
| **Shared Enums** | All cross-system enum definitions | Enum types for all systems | Nothing | Yes: `Enums` (or `const` script) | — |
| **Scene Manager** | Room loading, active room reference | `load_room()`, `get_current_room()`, transition signals | Room PackedScenes, Camera System | Yes: `SceneManager` | PackedScene, SceneTree |

### Core Layer

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| **Animation State Machine** | Animation state per entity, phase timers, hit-stop state | `play_action()`, `is_in_action()`, phase signals (`windup_started`, `active_started`, etc.), `apply_hitstop()` | EntityBase lifecycle, CardData animation_key + frame counts |
| **Collision/Hitbox** | Hit detection, i-frame state, hitbox shapes | `HitboxComponent.enable/disable()`, `HurtboxComponent.hit_received` signal | Animation state (ACTIVE phase), Entity faction |
| **Combat System** | Damage pipeline, damage number spawning | `execute_card()`, `apply_dot_tick()`, `damage_dealt` / `entity_killed` signals | HitData from Collision, modifiers from Status Effects, CardData effects, HealthComponent |
| **Card Hand System** | Hand slots, draw/discard piles, encounter card state | `try_play_card()`, hand query methods, `card_played` / `card_drawn` signals | CardRegistry, InputManager buffer, CombatSystem for execution |

### Feature Layer

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| **Status Effect System** | Active effects per entity, tick timers, stacking state | `apply_effect()`, `get_damage_taken_multiplier()`, `get_speed_multiplier()`, effect signals | StatusEffectData resources, Entity lifecycle |
| **Enemy AI System** | FSM state per enemy, target tracking | `set_behavior()`, AI state queries | EntityBase, MovementComponent, AnimationComponent, CombatSystem pipeline |
| **Deck Building System** | Draft/trim/upgrade operations | `add_card()`, `remove_card()`, `upgrade_card()`, constraint queries | CardRegistry, RunState deck |
| **Dungeon Generation** | Floor graph, room pool, floor templates | `generate_floor()`, `get_available_exits()`, floor/room signals | Run seed, PackedScene room pool |
| **Reward System** | Draft pool construction, currency calculation | `generate_reward()`, `get_draft_choices()` | CardRegistry, DeckBuilding constraints, floor/room data |
| **Room Encounter** | Encounter state, wave state, enemy tracking | `start_encounter()`, `get_enemies_remaining()`, encounter signals | Dungeon Gen room data, Enemy AI, Entity despawned signals |
| **Run State Manager** | RunState (HP, deck, currency, floor, stats) | State read/write methods, run lifecycle signals | CardHandSystem (deck sync), CombatSystem (HP sync), DungeonGen (floor) |

### Presentation Layer

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| **Card Hand UI** | Card slot visuals, animations, tooltips | Nothing (pure display) | CardHandSystem signals, CardData visuals, InputManager device |

---

## Dependency Diagram

```
                    ┌──────────────┐
                    │ Card Hand UI │
                    └──────┬───────┘
                           │ reads
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
   ┌─────────────┐  ┌───────────┐   ┌───────────────┐
   │ Card Hand   │  │  Combat   │   │ Room Encounter│
   │ System      │◄─┤  System   │◄──┤    System     │
   └──────┬──────┘  └─────┬─────┘   └───────┬───────┘
          │               │                  │
          │          ┌────┴────┐        ┌────┴────┐
          │          ▼         ▼        ▼         ▼
          │   ┌──────────┐ ┌───────┐ ┌────────┐ ┌────────┐
          │   │Animation │ │Collis.│ │Enemy AI│ │Reward  │
          │   │State Mch │ │Hitbox │ └────┬───┘ │System  │
          │   └────┬─────┘ └───┬───┘      │     └────┬───┘
          │        │           │           │          │
          ▼        ▼           ▼           ▼          ▼
   ┌──────────┐ ┌───────────────────────────┐  ┌──────────┐
   │Card Data │ │     Entity Framework      │  │   Deck   │
   │ System   │ │                           │  │ Building │
   └──────────┘ └───────────────────────────┘  └──────────┘
          ▲                                         │
          │        ┌───────────────────┐            │
          └────────┤  Run State Mgr   │◄───────────┘
                   └────────┬──────────┘
                            │
                   ┌────────┴──────────┐
                   │ Dungeon Generation│
                   └───────────────────┘

   Cross-cutting: InputManager ──► Combat, Card Hand, Camera
                  Camera ◄── Combat (shake), Entity (position), Dungeon (bounds)
                  Status Effects ◄► Combat (modifiers), Entity (stun)
```

---

## Autoload Strategy

| Autoload | Script Path | Purpose | Justification |
|----------|-------------|---------|---------------|
| `Enums` | `src/core/enums.gd` | Shared enum definitions | Every system needs these; no natural owner |
| `CardRegistry` | `src/foundation/card_registry.gd` | Card data lookup | Read-only, needed by 8+ systems |
| `InputManager` | `src/foundation/input_manager.gd` | Input buffer + device state | Single instance, polled every frame |
| `RunStateManager` | `src/feature/run_state_manager.gd` | Run persistence | Persists across room scenes |
| `SceneManager` | `src/core/scene_manager.gd` | Room loading/transitions | Orchestrates scene tree changes |
| `GameManager` | `src/core/game_manager.gd` | Game flow state machine | Top-level lifecycle (menu→run→death) |

**NOT autoloads** (instantiated per room/encounter):
- CombatManager — created when encounter starts, freed on room exit
- CardHandSystem — created per encounter, holds per-encounter hand state
- RoomEncounterManager — created per room entry
- Camera — persistent scene node (child of Main, not autoload)
- All entities — per-room instantiation

---

## Data Flow

### 1. Frame Update Path (Combat)

```
_physics_process(delta):
│
├─ InputManager._physics_process()
│   ├─ Poll Godot Input for held actions (movement)
│   ├─ Decrement buffer timer
│   └─ Update aim direction (mouse position or stick)
│
├─ Per-Entity._physics_process():
│   ├─ AnimationComponent: advance phase timers, check transitions
│   ├─ StatusEffectComponent: tick active effects, apply DoT
│   ├─ MovementComponent: apply velocity + speed modifiers
│   ├─ AIBehaviorComponent (enemies): evaluate FSM transitions
│   └─ HitboxComponent/HurtboxComponent: Godot handles Area2D overlap detection
│
├─ CombatManager._physics_process():
│   ├─ Check InputManager.consume_buffered_action() for card plays
│   ├─ Process hit_received signals queued this frame
│   └─ Update damage number animations
│
├─ CardHandSystem:
│   ├─ Process pending draws (DRAW_DELAY timer)
│   └─ Decrement cooldown timers
│
└─ Camera._physics_process():
    ├─ Lerp toward target (player + look-ahead)
    ├─ Apply shake offset
    ├─ Clamp to room bounds
    └─ Snap to integer pixels
```

### 2. Card Play Sequence

```
Player presses "1" key
  │
  ▼
InputManager: buffer action "card_1" with frame timestamp
  │
  ▼ (next frame, player in IDLE/RUN)
CombatManager: consume_buffered_action("card_1") → true
  │
  ▼
CardHandSystem.try_play_card(slot=0, aim_dir):
  ├─ Validate: slot occupied, not on cooldown, entity ACTIVE
  ├─ Remove card from slot → add to discard
  ├─ Emit card_played(card_data, 0)
  ├─ Schedule draw into slot 0 after DRAW_DELAY frames
  │
  ▼
CombatSystem.execute_card(card_data, aim_dir, player):
  ├─ Read card_data.effects array
  ├─ AnimationComponent.play_action(animation_key, windup, active, recovery)
  │   ├─ Lock facing direction
  │   ├─ Enter WINDUP state
  │   ├─ After windup_frames → emit active_started
  │   │   ├─ HitboxComponent.enable(hit_data_template)
  │   │   ├─ Area2D overlap → HurtboxComponent.hit_received
  │   │   ├─ CombatSystem: apply_modifiers → take_damage → emit damage_dealt
  │   │   ├─ Apply hit-stop (Animation + Camera + Input frozen)
  │   │   ├─ Request screen shake (Camera)
  │   │   └─ Spawn damage number
  │   ├─ After active_frames → HitboxComponent.disable(), enter RECOVERY
  │   └─ After recovery_frames → emit action_completed → entity free to act
  │
  ▼ (DRAW_DELAY frames after play)
CardHandSystem: draw from draw pile → slot 0
  └─ Emit card_drawn(new_card, 0)
      └─ CardHandUI: animate card sliding into slot
```

### 3. Room Transition Sequence

```
Last enemy despawns
  │
  ▼
RoomEncounterManager: total_despawned >= total_spawned → CLEARING
  ├─ Wait CLEAR_DELAY frames
  ├─ Transition to CLEARED
  ├─ Unlock exits
  │
  ▼
RewardSystem.generate_reward(room_type, floor):
  ├─ Construct draft pool (CardRegistry + DeckBuilding constraints)
  ├─ Select DRAFT_CHOICES cards
  └─ Present to UI
  │
  ▼
Player selects next room on dungeon map
  │
  ▼
CardHandSystem.end_encounter() → return deck to RunStateManager
RunStateManager: sync HP, increment rooms_cleared, add currency
  │
  ▼
SceneManager.transition_to_room(next_room):
  ├─ Camera: fade to black (TRANSITION_FADE_OUT frames)
  ├─ Free current room scene
  ├─ Instantiate new room PackedScene
  ├─ Position player at PlayerSpawn
  ├─ Camera: snap to new position, set room bounds
  ├─ Camera: fade from black (TRANSITION_FADE_IN frames)
  │
  ▼
RoomEncounterManager.start_encounter(room_data):
  ├─ CardHandSystem.start_encounter(deck, seed)
  ├─ Spawn wave 1 after SETUP_FRAMES
  └─ Combat begins
```

### 4. Initialization Order

```
Autoloads (Godot loads in project.godot order):
  1. Enums          — pure data, no dependencies
  2. CardRegistry   — loads all .tres from assets/data/cards/
  3. InputManager   — configures InputMap actions
  4. RunStateManager — empty state, awaits run start
  5. SceneManager   — holds room reference
  6. GameManager    — top-level state machine, loads Main scene

Main scene tree:
  Main (Node2D)
  ├─ GameCamera (Camera2D + SubViewport setup)
  ├─ RoomContainer (Node2D) ← rooms instantiated here
  ├─ UILayer (CanvasLayer, z_index=10)
  │   ├─ CardHandUI
  │   ├─ CombatHUD (VS+)
  │   └─ TransitionOverlay (ColorRect for fades)
  └─ DungeonMapUI (CanvasLayer, z_index=20, hidden during combat)
```

---

## API Boundaries

### EntityBase → All Systems

```gdscript
class_name EntityBase extends Node2D

enum EntityType { PLAYER, STANDARD_ENEMY, ELITE_ENEMY, BOSS, PROJECTILE, PROP }
enum LifecycleState { INACTIVE, SPAWNING, ACTIVE, STUNNED, DYING, DEAD }

var entity_type: EntityType
var _lifecycle_state: LifecycleState = LifecycleState.INACTIVE

signal lifecycle_state_changed(old_state: LifecycleState, new_state: LifecycleState)
signal despawned(entity: EntityBase)

func activate() -> void
func die() -> void
func despawn() -> void
func set_stunned(stunned: bool) -> void
func get_lifecycle_state() -> LifecycleState
```

### InputManager → Combat, Card Hand, Camera

```gdscript
class_name InputManager extends Node

enum InputMode { GAMEPLAY, UI }
enum InputDevice { KEYBOARD_MOUSE, GAMEPAD }

signal input_device_changed(device: InputDevice)
signal input_mode_changed(mode: InputMode)

func get_movement_vector() -> Vector2        # normalized, 0-1 magnitude
func get_facing_direction() -> Vector2       # normalized
func get_aim_direction() -> Vector2          # normalized, 8-dir snapped
func get_aim_angle() -> float                # radians
func consume_buffered_action(action: StringName) -> bool
func get_input_mode() -> InputMode
func set_input_mode(mode: InputMode) -> void
func get_active_device() -> InputDevice
```

### CardRegistry → Card Hand, Deck Building, Reward, UI

```gdscript
class_name CardRegistry extends Node

func get_card(card_id: StringName) -> CardData           # null if not found
func get_cards_by_archetype(arch: CardArchetype) -> Array[CardData]
func get_cards_by_rarity(rarity: CardRarity) -> Array[CardData]
func get_starter_deck(arch: CardArchetype) -> Array[CardData]
func get_all_cards() -> Array[CardData]
```

### CombatSystem → Collision, Status Effects, Card Hand, Camera

```gdscript
class_name CombatSystem extends Node

signal damage_dealt(source: EntityBase, target: EntityBase, amount: int, is_crit: bool)
signal entity_killed(entity: EntityBase, killer: EntityBase)
signal combat_shake_requested(intensity: float)
signal hit_stop_triggered(duration_frames: int)

func execute_card(card_data: CardData, aim_dir: Vector2, source: EntityBase) -> void
func apply_dot_tick(target: EntityBase, damage: int, source_status: StringName) -> void
```

### CardHandSystem → Combat, Run State, UI

```gdscript
class_name CardHandSystem extends Node

signal card_played(card_data: CardData, slot_index: int)
signal card_drawn(card_data: CardData, slot_index: int)
signal card_play_rejected(slot_index: int, reason: StringName)
signal hand_ready()
signal hand_cleared()
signal draw_pile_reshuffled()

func start_encounter(deck: Array[StringName], rng_seed: int) -> void
func end_encounter() -> Array[StringName]
func try_play_card(slot: int, aim_direction: Vector2) -> bool
func get_card_in_slot(slot: int) -> CardData
func is_slot_playable(slot: int) -> bool
func get_draw_pile_count() -> int
func get_discard_pile_count() -> int
```

### RunStateManager → All Feature/Presentation Systems

```gdscript
class_name RunStateManager extends Node

signal run_started(run_state: RunState)
signal run_ended(summary: RunSummary, outcome: RunOutcome)
signal floor_advanced(floor_number: int)
signal hp_changed(old_hp: int, new_hp: int)

func start_run(archetype: CardArchetype, seed: int) -> void
func end_run(outcome: RunOutcome) -> RunSummary
func get_current_hp() -> int
func get_deck() -> Array[StringName]
func set_deck(deck: Array[StringName]) -> void
func get_run_seed() -> int
func add_currency(amount: int) -> void
```

---

## Source Directory Structure

```
src/
├── core/
│   ├── enums.gd                    # All shared enums
│   ├── game_manager.gd             # Game flow state machine (autoload)
│   └── scene_manager.gd            # Room loading/transitions (autoload)
├── foundation/
│   ├── entity_base.gd              # EntityBase class
│   ├── components/
│   │   ├── health_component.gd
│   │   ├── hitbox_component.gd
│   │   ├── hurtbox_component.gd
│   │   ├── movement_component.gd
│   │   ├── animation_component.gd
│   │   ├── status_effect_component.gd
│   │   ├── faction_component.gd
│   │   └── ai_behavior_component.gd
│   ├── input_manager.gd            # Input buffer + device (autoload)
│   ├── card_registry.gd            # Card data registry (autoload)
│   ├── camera_controller.gd        # Camera follow + shake + transitions
│   └── data/
│       ├── card_data.gd            # CardData Resource class
│       ├── card_effect.gd          # CardEffect Resource class
│       ├── hit_data.gd             # HitData RefCounted class
│       └── status_effect_data.gd   # StatusEffectData Resource class
├── gameplay/
│   ├── combat_system.gd            # Damage pipeline
│   ├── card_hand_system.gd         # Hand management + use-to-draw
│   ├── animation_state_machine.gd  # Phase enforcement (on AnimationComponent)
│   ├── status_effect_system.gd     # Effect tick processing (on StatusEffectComponent)
│   ├── enemy_ai/
│   │   ├── ai_state_machine.gd     # FSM runner
│   │   ├── ai_states/              # Individual state scripts
│   │   └── enemy_behavior_data.gd  # EnemyBehaviorData Resource
│   ├── deck_building_system.gd     # Draft/trim/upgrade operations
│   ├── dungeon_generation.gd       # Floor graph builder
│   ├── reward_system.gd            # Draft pool + currency
│   ├── room_encounter_manager.gd   # Encounter state machine + waves
│   └── run_state_manager.gd        # Run persistence (autoload)
├── ui/
│   ├── card_hand_ui.gd             # Hand display
│   ├── damage_number.gd            # Floating damage text
│   └── transition_overlay.gd       # Fade to/from black
└── data/
    └── run_state.gd                # RunState Resource class
```

---

## Architecture Principles

1. **Signals over direct calls for cross-layer communication.** Systems in the same layer may call each other directly. Systems in different layers communicate via signals (decoupled). Exception: Foundation autoloads (InputManager, CardRegistry) expose synchronous query methods that any layer may call.

2. **Resources for data, RefCounted for runtime packets.** Static game data (cards, effects, enemies) lives in `.tres` Resource files. Runtime data passed between systems (HitData, draft choices) uses RefCounted objects that are garbage-collected.

3. **Entity composition via Godot nodes, not inheritance.** EntityBase is the only base class. All behavior is attached via typed child nodes (components). Systems discover components via `get_node_or_null()` — a missing component is a valid state, not an error.

4. **Frame-counted timers, not real-time.** All gameplay timers (buffer window, animation phases, i-frames, cooldowns, hit-stop) count physics frames, not seconds. This keeps gameplay deterministic and synchronized. Timers pause during hit-stop and game pause.

5. **Single owner per data.** Every piece of mutable state has exactly one owning system. Other systems read via query methods or react via signals. No shared mutable state between systems.

---

## ADR Audit

### Existing ADRs: 9

| ADR | Title | Status | Layer |
|-----|-------|--------|-------|
| ADR-0001 | Entity Composition Pattern | Proposed | Foundation |
| ADR-0002 | Signal Architecture | Proposed | Foundation |
| ADR-0003 | Scene Management & Room Transitions | Proposed | Foundation |
| ADR-0004 | Data Resource Architecture | Proposed | Foundation |
| ADR-0005 | Input Buffering & Action Map | Proposed | Foundation |
| ADR-0006 | Viewport & Camera Pipeline | Proposed | Foundation |
| ADR-0007 | Animation Commitment & Hit-Stop | Proposed | Core |
| ADR-0008 | Collision Layer Strategy | Proposed | Core |
| ADR-0009 | Damage Pipeline & Health Authority | Proposed | Core |

### Traceability Coverage: 47/62

All Foundation and Core technical requirements are covered by ADRs 0001-0009. The 15 uncovered requirements are in Feature and Presentation layers (ADRs 0010-0014, deferred to implementation).

---

## Required ADRs

### Must Have Before Coding (Foundation + Core)

| # | ADR Title | Covers | Layer |
|---|-----------|--------|-------|
| 1 | **Entity Composition Pattern** | TR-EF-001, TR-EF-002, TR-EF-003, TR-EF-004 | Foundation |
| 2 | **Signal Architecture and Cross-System Communication** | All cross-system interactions, Principle #1 | Foundation |
| 3 | **Scene Management and Room Transitions** | TR-CM-006, TR-DG-003, room loading strategy | Foundation |
| 4 | **Data Resource Architecture** | TR-CD-001, TR-CD-002, TR-SE-001, TR-EA-001, TR-EA-002 | Foundation |
| 5 | **Input Buffering and Action Map** | TR-IN-001 through TR-IN-006 | Foundation |
| 6 | **Viewport and Camera Pipeline** | TR-CM-001 through TR-CM-005 | Foundation |
| 7 | **Animation Commitment and Hit-Stop** | TR-AS-001 through TR-AS-005, TR-CO-004 | Core |
| 8 | **Collision Layer Strategy** | TR-CH-001 through TR-CH-006 | Core |
| 9 | **Damage Pipeline and Health Authority** | TR-CO-001 through TR-CO-006 | Core |

### Should Have Before Feature Layer

| # | ADR Title | Covers | Layer |
|---|-----------|--------|-------|
| 10 | **Enemy AI FSM Architecture** | TR-EA-001 through TR-EA-004 | Feature |
| 11 | **Dungeon Graph Generation** | TR-DG-001 through TR-DG-004 | Feature |
| 12 | **Run State Persistence and Sync** | TR-RS-001 through TR-RS-003 | Feature |

### Can Defer to Implementation

| # | ADR Title | Covers | Layer |
|---|-----------|--------|-------|
| 13 | **Card Hand UI Layout and Animation** | TR-UI-001 through TR-UI-005 | Presentation |
| 14 | **Reward Economy and Draft Weights** | TR-RW-001, TR-DB-001 through TR-DB-003 | Feature |

---

## Open Questions

1. **Component discovery pattern**: Should EntityBase use `get_node_or_null()` with known paths, or typed getter methods? Typed getters are safer but couple EntityBase to specific components. → Resolve in ADR #1.

2. **Entity pooling**: Should frequently spawned entities (projectiles, standard enemies) use object pooling? → Defer to prototype performance profiling.

3. **Card effect execution model**: Should CardEffect.execute() be a virtual method on each effect type, or should CombatSystem switch on EffectType enum? Polymorphism is cleaner but requires a script per effect type. → Resolve in ADR #4.

4. **Encounter-scoped vs persistent nodes**: Should CombatSystem and CardHandSystem be instantiated per encounter, or persist as autoloads with start/end lifecycle? Autoloads are simpler; per-encounter is cleaner isolation. → Resolve in ADR #2.

5. **UI dual-focus handling (Godot 4.6)**: Card Hand UI needs to work with both mouse hover and gamepad D-pad. The 4.6 dual-focus system means these are separate focus paths. → Resolve in ADR #13 when Presentation layer is built.
