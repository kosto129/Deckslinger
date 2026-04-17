# Control Manifest

> **Engine**: Godot 4.6 (GDScript)
> **Last Updated**: 2026-04-17
> **Manifest Version**: 2026-04-17
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009
> **Status**: Active — regenerate with `/create-control-manifest` when ADRs change

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: entity framework, input, card data, camera, scene management, enums*

### Required Patterns

- **Entities use Node2D composition with typed child component nodes.** EntityBase is the only base class. All behavior is attached via `class_name` child nodes. — source: ADR-0001
- **Cache component references with `@onready` in EntityBase.** Never call `get_node_or_null()` per frame. Use typed getter methods (`get_health()`, `get_hitbox()`, etc.). — source: ADR-0001
- **A missing component is valid, not an error.** Systems must null-check component getters. Projectiles have no HealthComponent — this is by design. — source: ADR-0001
- **Use Callable-based signal connections.** Always `signal.connect(callable)`, never string-based `connect("signal", obj, "method")`. — source: ADR-0002
- **Type all signal parameters.** No `Variant` catch-alls. Every parameter has a type annotation. — source: ADR-0002
- **Signals use past tense for events, present tense for requests.** `health_changed`, `entity_killed` (events). `combat_shake_requested` (requests). — source: ADR-0002
- **Player entity is a persistent child of Main, not of any room scene.** Player is repositioned on room transition but never freed during a run. — source: ADR-0003
- **Rooms are instantiated from PackedScene and freed on exit.** No room state persists — all persistent state lives in RunStateManager autoload. — source: ADR-0003
- **Room transitions use fade-to-black (hard cut).** TransitionOverlay tweens alpha. No frame may show both old and new rooms simultaneously. — source: ADR-0003
- **Static game data uses Godot Resources (.tres).** CardData, StatusEffectData, EnemyBehaviorData, EnemyAttackData, RoomData are all `extends Resource`. — source: ADR-0004
- **Runtime-only packets use RefCounted.** HitData, RewardData, FloorData are `extends RefCounted` — never saved to disk. — source: ADR-0004
- **Use `duplicate_deep()` (4.5+) when copying Resources with nested sub-resources.** Never use `duplicate()` for CardData with Array[CardEffect]. — source: ADR-0004
- **All cross-system enums live in the Enums autoload (`src/core/enums.gd`).** Never define enums inside component or system scripts that other systems need to read. — source: ADR-0004
- **Input buffer uses single-slot, most-recent-wins policy.** New bufferable action replaces any existing buffer. — source: ADR-0005
- **All gameplay timers count physics frames, not real-time seconds.** Buffer window, animation phases, i-frames, cooldowns, hit-stop — all use integer frame counters. — source: ADR-0005
- **Buffer, animation, and camera timers freeze during hit-stop.** InputManager, AnimationComponent, and CameraController all respect a `_frozen` flag. — source: ADR-0005
- **Render to 384×216 with `canvas_items` stretch mode and `keep` aspect.** Enable `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` in Project Settings. — source: ADR-0006
- **Camera position must be rounded to integer pixels after ALL calculations** (follow + look-ahead + shake + clamp). Use `Vector2(round(x), round(y))`. — source: ADR-0006

### Forbidden Approaches

- **Never use deep inheritance for entity types.** No `EnemyBase`, `PlayerBase`, `BossBase` class hierarchies. Use component composition. — source: ADR-0001
- **Never use a global event bus autoload.** Signals live on the object that produces the event. A centralized EventBus obscures data flow. — source: ADR-0002
- **Never write cross-system state directly.** System A never modifies System B's internal variables. Use public methods or signals. — source: ADR-0002
- **Never use untyped signals.** Every signal must have typed parameters. — source: ADR-0002
- **Never use `change_scene_to_packed()` for room transitions.** It frees all nodes including persistent ones (player, camera, UI). Use SceneManager child swap instead. — source: ADR-0003
- **Never store game data in JSON/YAML.** Use Godot Resources for all static data — they have editor integration, type safety, and hot-reload. — source: ADR-0004
- **Never hardcode gameplay values in GDScript.** All tuning values belong on exported Resource fields or in tuning knob constants. — source: ADR-0004
- **Never use `duplicate()` on Resources with nested sub-resources.** Always `duplicate_deep()`. — source: ADR-0004
- **Never use real-time (seconds/milliseconds) for gameplay timing.** Frame-counted integers only. `delta` is for rendering interpolation, not gameplay logic. — source: ADR-0005
- **Never render at fractional pixel scale.** Integer scaling only. Letterbox the remainder. — source: ADR-0006

### Performance Guardrails

- **Entity system**: max 8 entities × 8 components = 64 nodes per room. Well within budget. — source: ADR-0001
- **Signal overhead**: <0.01ms per frame at ~20 signals/frame. — source: ADR-0002
- **Room transition**: <1ms for PackedScene instantiation of <50 node 2D scenes. — source: ADR-0003
- **CardRegistry startup**: <100ms to load 25 .tres files. — source: ADR-0004

---

## Core Layer Rules

*Applies to: animation state machine, collision/hitbox, combat system, card hand system*

### Required Patterns

- **Actions use 3-phase commitment: WINDUP → ACTIVE → RECOVERY.** Frame counts come from CardData (player) or EnemyAttackData (enemies). No phase can be cancelled by player input. — source: ADR-0007
- **Hit-stop freezes ALL gameplay systems simultaneously.** AnimationComponent, InputManager, CameraController, and MovementComponent all pause. Only death or stun can interrupt a committed action. — source: ADR-0007
- **Facing direction locks at WINDUP start.** The entity's visual direction does not change during WINDUP/ACTIVE/RECOVERY even if aim input changes. — source: ADR-0007
- **AnimationComponent drives AnimatedSprite2D via SpriteFrames.** Animation names follow the pattern `{state}_{direction}` (e.g., `idle_e`, `run_nw`). — source: ADR-0007
- **Use Area2D for all hitbox/hurtbox detection.** HitboxComponent and HurtboxComponent are separate Area2D nodes with configured collision layers/masks. — source: ADR-0008
- **Configure collision layer/mask pairs so Godot handles faction filtering.** Player hitbox (layer 1) masks enemy hurtbox (layer 4). No per-frame faction checks in code. — source: ADR-0008
- **HitboxComponent tracks entities already hit per action.** A `Dictionary` of hit entities is cleared on `action_completed`. One hit per target per action. — source: ADR-0008
- **I-frames are frame-counted on HurtboxComponent.** 20 frames default. Timer pauses during hit-stop. Visual flicker alternates every 3 frames. — source: ADR-0008
- **All damage flows through CombatSystem's pipeline.** `_process_hit()` for direct hits, `apply_dot_tick()` for DoT. No system bypasses the pipeline. — source: ADR-0009
- **Damage modifiers are multiplicative: base × vuln × resist × stun × crit.** Floor result to int. Minimum 1 damage. — source: ADR-0009
- **HealthComponent is the sole authority on entity HP.** Only CombatSystem calls `take_damage()` and `heal()`. No other system directly modifies HP. — source: ADR-0009
- **Death processing: entity.die() → DYING lifecycle → death animation → despawn().** Kill credit tracked via `source` parameter on `take_damage()`. — source: ADR-0009
- **Killing blows get extended hit-stop.** `death_hitstop = normal_hitstop + DEATH_HITSTOP_BONUS` frames. — source: ADR-0009

### Forbidden Approaches

- **Never use AnimationPlayer or AnimationTree for gameplay timing.** Use the custom frame-counting state machine. AnimationPlayer timelines couple gameplay to art asset length. — source: ADR-0007
- **Never allow player input to cancel WINDUP, ACTIVE, or RECOVERY.** Commitment is the core game design. Only death or stun interrupts. — source: ADR-0007
- **Never use PhysicsBody2D for combat collision.** Area2D is detection-only. Hitboxes should not push entities — knockback is handled by the damage pipeline. — source: ADR-0008
- **Never check faction in code after overlap detection.** Layer/mask configuration handles faction filtering at the physics engine level. — source: ADR-0008
- **Never calculate damage inside HitboxComponent.** All damage math belongs in CombatSystem. Hitbox only detects contact and delivers HitData. — source: ADR-0009
- **Never use additive damage modifiers.** Multiplicative stacking creates more dramatic combat moments (Pillar 1). — source: ADR-0009

### Performance Guardrails

- **AnimationComponent**: 1 integer decrement per entity per frame. <0.01ms. — source: ADR-0007
- **Collision**: 8 entities × 2 Area2D = 16 Area2D nodes. Godot broadphase handles this trivially. — source: ADR-0008
- **Damage pipeline**: max ~10 hits per frame worst case. <0.1ms total. — source: ADR-0009

---

## Feature Layer Rules

*Applies to: status effects, enemy AI, deck building, dungeon generation, rewards, room encounters, run state*

### Required Patterns

- **StatusEffectData is a Resource with stacking rules.** 4 stacking types: REFRESH, INTENSITY, INDEPENDENT, NONE. — source: ADR-0004
- **Enemy AI uses FSM with states defined per EnemyBehaviorData Resource.** No behavior trees for MVP. — source: ADR-0004
- **Deck is stored as Array[StringName] of card IDs.** Reconstitute CardData via CardRegistry at encounter start. — source: ADR-0004
- **Dungeon floors use seeded RNG: `run_seed XOR floor_number`.** Same seed = same layout. — source: implied by ADR-0004 + dungeon-generation GDD
- **RunStateManager is the single source of truth for run persistence.** HP, deck, currency, floor progress. All other systems sync to it between encounters. — source: ADR-0003

### Forbidden Approaches

- **Never persist room-specific state across room transitions.** All encounter state is discarded when the room is freed. Persistent state lives in RunStateManager only. — source: ADR-0003

---

## Presentation Layer Rules

*Applies to: Card Hand UI, Combat HUD, damage numbers, menus*

### Required Patterns

- **Test UI with both mouse AND gamepad input paths.** Godot 4.6 dual-focus means mouse hover and keyboard focus are separate. — source: engine-reference
- **Use `grab_focus()` for keyboard/gamepad focus only.** It does not affect mouse focus in 4.6. — source: engine-reference
- **Use `tr()` for all player-facing strings.** Localization-ready from day one. — source: engine-reference

### Forbidden Approaches

- **Never assume `grab_focus()` affects mouse focus.** Keyboard and mouse focus are separate in Godot 4.6. — source: engine-reference

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables/Functions | snake_case | `move_speed`, `take_damage()` |
| Signals/Events | snake_case past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes/Prefabs | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Draw calls | ~1000 |
| Memory ceiling | 512 MB |

### Approved Libraries / Addons

- **GdUnit4** — approved for automated testing (unit + integration)

### Forbidden APIs (Godot 4.6)

These APIs are deprecated or changed. Do not use them:

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `bone_pose_updated` signal | `skeleton_updated` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |
| `Texture2D` in shader params | `Texture` base type | 4.4 |
| String-based `connect()` | Typed signal connections | 4.0 |
| `$NodePath` in `_process()` | `@onready var` cached reference | — |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | — |

### Cross-Cutting Constraints

- **All public methods must be unit-testable.** Use dependency injection over singletons where possible. — source: coding-standards
- **Gameplay values must be data-driven.** Exported Resource fields or named constants. Never inline magic numbers. — source: coding-standards
- **Commits must reference the relevant design document or task ID.** — source: coding-standards
- **Use StringName (`&"action_name"`) for action names in hot paths.** String literals are slower for dictionary lookups. — source: engine-reference
