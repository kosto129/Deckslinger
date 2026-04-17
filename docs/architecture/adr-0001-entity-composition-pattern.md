# ADR-0001: Entity Composition Pattern

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scene Architecture |
| **Knowledge Risk** | LOW — Node2D, scenes, and typed GDScript unchanged since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | `@abstract` (4.5) — optional, used for EntityBase method contracts |
| **Verification Required** | Verify `@abstract` decorator works on Node2D subclasses in 4.6 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — root architectural decision |
| **Enables** | ADR-0002 (Signal Architecture), ADR-0007 (Animation), ADR-0008 (Collision), ADR-0009 (Damage Pipeline) |
| **Blocks** | All Foundation and Core epics — cannot implement any entity without this pattern |
| **Ordering Note** | Must be the first ADR accepted. All other ADRs assume this structure exists. |

## Context

### Problem Statement
Deckslinger has 6 entity types (Player, Standard Enemy, Elite Enemy, Boss, Projectile, Prop) that share some but not all behaviors (health, movement, hitboxes, AI). We need a composition model that lets systems query "does this entity have health?" without knowing the entity type, while keeping each entity's scene file clean and editor-authorable.

### Constraints
- Godot 4.6, GDScript — no ECS available, must use node/scene architecture
- Entities are visual objects in 2D rooms — must extend Node2D for positioning
- Editor workflow: designers create entity scenes by adding/removing component nodes
- Performance: up to 8 entities per room (6 enemies + player + projectiles), well within budget

### Requirements
- Must support optional components (enemy has AI, player does not)
- Must support lifecycle state machine (6 states per Entity Framework GDD)
- Systems must discover components without coupling to entity type
- Entity scenes must be PackedScene files instantiable by Dungeon Generation

## Decision

**Entities use Godot's node composition: an `EntityBase` root node with typed child component nodes.**

### Architecture

```
EntityBase (Node2D)                    # class_name EntityBase
├── AnimatedSprite2D                   # Visual representation
├── HealthComponent (Node)             # class_name HealthComponent
├── HitboxComponent (Area2D)           # class_name HitboxComponent
├── HurtboxComponent (Area2D)          # class_name HurtboxComponent
├── MovementComponent (Node)           # class_name MovementComponent
├── AnimationComponent (Node)          # class_name AnimationComponent
├── StatusEffectComponent (Node)       # class_name StatusEffectComponent
├── FactionComponent (Node)            # class_name FactionComponent
└── AIBehaviorComponent (Node)         # class_name AIBehaviorComponent (enemies only)
```

### Key Rules

1. **EntityBase owns only identity and lifecycle.** Two fields: `entity_type: EntityType` (immutable) and `_lifecycle_state: LifecycleState` (private, changed via methods).

2. **Components are child nodes with `class_name`.** Each component is a separate `.gd` script with a unique `class_name`. Components are added as child nodes in the entity's `.tscn` scene file.

3. **Component discovery uses typed `get_node_or_null()`.** Systems find components by class:
   ```gdscript
   var health: HealthComponent = entity.get_node_or_null("HealthComponent")
   if health:
       health.take_damage(amount, source)
   ```
   A missing component is a valid state (e.g., Projectile has no HealthComponent).

4. **EntityBase exposes typed getters for common components** to reduce boilerplate:
   ```gdscript
   @onready var _health: HealthComponent = get_node_or_null("HealthComponent")
   func get_health() -> HealthComponent: return _health
   ```
   These are cached at `_ready()` time — no per-frame path lookups.

5. **No inheritance hierarchy beyond EntityBase.** There is no `EnemyBase` or `PlayerBase`. Entity type differences are expressed through which components are present, not through class hierarchy.

### Key Interfaces

```gdscript
class_name EntityBase extends Node2D

@export var entity_type: Enums.EntityType

signal lifecycle_state_changed(old_state: Enums.LifecycleState, new_state: Enums.LifecycleState)
signal despawned(entity: EntityBase)

func activate() -> void
func die() -> void
func despawn() -> void
func set_stunned(stunned: bool) -> void
func get_lifecycle_state() -> Enums.LifecycleState

# Cached component getters
func get_health() -> HealthComponent
func get_hitbox() -> HitboxComponent
func get_hurtbox() -> HurtboxComponent
func get_movement() -> MovementComponent
func get_animation() -> AnimationComponent
func get_status_effects() -> StatusEffectComponent
func get_faction() -> FactionComponent
func get_ai() -> AIBehaviorComponent  # null for player/projectiles/props
```

## Alternatives Considered

### Alternative 1: Pure Node Path Discovery (no cached getters)
- **Description**: Systems always call `entity.get_node_or_null("HealthComponent")` directly
- **Pros**: EntityBase has zero coupling to specific component types
- **Cons**: Verbose call sites, string-based paths are fragile, no autocomplete
- **Rejection Reason**: Typed getters with `@onready` caching give the best of both worlds — still composition, but with ergonomic access

### Alternative 2: Deep Inheritance Hierarchy
- **Description**: `EntityBase → EnemyBase → EliteEnemy`, etc.
- **Pros**: Strong typing, shared behavior in base classes
- **Cons**: Diamond problem with shared behaviors (e.g., both Player and Enemy have health), rigid hierarchy resists design changes, Godot's single-inheritance model makes this painful
- **Rejection Reason**: Composition via nodes is Godot-idiomatic and flexible. Inheritance creates coupling that breaks when GDD requirements change.

### Alternative 3: Component Registry Dictionary
- **Description**: EntityBase holds `var components: Dictionary = {}` mapping StringName → Node
- **Pros**: Fully dynamic, can add/remove at runtime
- **Cons**: No type safety, no editor discoverability, no autocomplete, runtime errors instead of editor warnings
- **Rejection Reason**: Loses Godot's main strength (visual scene composition in the editor)

## Consequences

### Positive
- Entities are fully authorable in the Godot editor (drag components into scene tree)
- Systems can be built independently — a system only needs to know its target component's API
- New entity types require zero code changes — just create a new `.tscn` with the right components
- Component getters provide type safety and autocomplete

### Negative
- EntityBase has `@onready` references to all component types — adding a new component type requires updating EntityBase
- Node tree is flat (all components are direct children) — deep nesting is not supported

### Risks
- **Component order dependency**: If components interact in `_ready()`, order matters. Mitigation: components should not reference each other in `_ready()` — use `_enter_tree()` for registration and first `_physics_process()` for cross-component setup.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| entity-framework.md | C.1 — Composition Model | EntityBase + typed child nodes implements the scene-based composition model |
| entity-framework.md | C.2 — Base Component Set | 8 component types defined with class_name |
| entity-framework.md | C.3 — Entity Creation/Destruction | PackedScene instantiation + activate()/die()/despawn() lifecycle |
| entity-framework.md | Entity Lifecycle State Machine | 6-state machine on EntityBase with signal emissions |

## Performance Implications
- **CPU**: Negligible. 8 entities × 8 components = 64 nodes max per room. Godot handles thousands.
- **Memory**: ~1KB per component node. Total entity memory well under 1MB per room.
- **Load Time**: PackedScene instantiation is near-instant for simple 2D scenes.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. EntityBase scene can be instantiated with all 8 components and transitions through all 6 lifecycle states
2. An entity with a missing component (e.g., no AIBehaviorComponent) does not error — getter returns null
3. Two different entity types (Player, Standard Enemy) can coexist in the same room using the same component interfaces
4. `@abstract` decorator works on EntityBase methods in Godot 4.6 (verify post-cutoff feature)

## Related Decisions
- ADR-0002: Signal Architecture (how components communicate)
- ADR-0008: Collision Layer Strategy (how HitboxComponent/HurtboxComponent are configured)
- ADR-0009: Damage Pipeline (how HealthComponent is accessed)
