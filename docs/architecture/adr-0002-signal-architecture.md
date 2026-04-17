# ADR-0002: Signal Architecture and Cross-System Communication

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Signal/Callable system unchanged since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Entity Composition Pattern) |
| **Enables** | All Core and Feature layer ADRs |
| **Blocks** | Any system that communicates across module boundaries |
| **Ordering Note** | Second ADR to accept — defines how all systems talk to each other |

## Context

### Problem Statement
16 game systems need to communicate without creating a dependency web. The Entity Framework emits lifecycle events, Combat emits damage events, Card Hand emits play/draw events, and UI systems need to react to all of them. We need a communication pattern that keeps systems decoupled while remaining debuggable and type-safe.

### Constraints
- Godot signals are the native decoupling mechanism — must use Callable-based connections (string-based deprecated)
- No centralized event bus — Godot's signal system is already per-object, and a global bus obscures data flow
- Debug builds must be able to trace signal connections

### Requirements
- Cross-layer communication must use signals (Architecture Principle #1)
- Same-layer systems may call each other directly via typed references
- Autoloads expose synchronous query methods callable by any layer
- Signal signatures must be typed (no `Variant` catch-alls)

## Decision

**Use Godot's native signal system with three communication tiers: direct calls within layers, typed signals across layers, and autoload queries for global state.**

### Communication Tiers

| Tier | When | Mechanism | Example |
|------|------|-----------|---------|
| **Direct Call** | Same layer, known reference | Method call via typed variable | CombatSystem calls AnimationComponent.play_action() |
| **Signal** | Cross-layer, event notification | Godot signal with typed parameters | `entity_killed(entity, killer)` from Combat → Room Encounter |
| **Autoload Query** | Any layer reads global state | Synchronous method on autoload | `CardRegistry.get_card(id)`, `InputManager.get_aim_direction()` |

### Signal Naming Convention

```
# Past tense for events that already happened
signal health_changed(old_hp: int, new_hp: int, source: EntityBase)
signal entity_killed(entity: EntityBase, killer: EntityBase)
signal card_played(card_data: CardData, slot_index: int)

# Present tense for requests
signal combat_shake_requested(intensity: float)
```

### Connection Pattern

```gdscript
# Always use Callable-based connections (never string-based)
func _ready() -> void:
    combat_system.entity_killed.connect(_on_entity_killed)

# Type all signal parameters — no untyped signals
signal damage_dealt(source: EntityBase, target: EntityBase, amount: int, is_crit: bool)
```

### Signal Ownership

Each signal is defined on the system that PRODUCES the event:

| Signal | Defined On | Consumed By |
|--------|-----------|-------------|
| `lifecycle_state_changed` | EntityBase | AnimationComponent, StatusEffectComponent |
| `hit_received` | HurtboxComponent | CombatSystem |
| `damage_dealt` | CombatSystem | UI (damage numbers), Statistics |
| `entity_killed` | CombatSystem | RoomEncounterManager, Statistics |
| `combat_shake_requested` | CombatSystem | CameraController |
| `card_played` | CardHandSystem | CardHandUI, Statistics |
| `card_drawn` | CardHandSystem | CardHandUI |
| `room_cleared` | RoomEncounterManager | RewardSystem, SceneManager |
| `run_started` / `run_ended` | RunStateManager | GameManager, UI |
| `input_device_changed` | InputManager | All UI systems |

### Forbidden Patterns

- **No global event bus.** Signals live on the object that produces the event. A global bus obscures data flow and makes debugging harder.
- **No cross-system state writes.** System A never writes to System B's internal state. It calls a public method or emits a signal that B reacts to.
- **No string-based connect().** Always use `signal.connect(callable)` syntax.
- **No untyped signals.** Every signal parameter must have a type annotation.

## Alternatives Considered

### Alternative 1: Centralized Event Bus Autoload
- **Description**: Single `EventBus` autoload with all signals defined in one place
- **Pros**: One place to see all events, easy to connect from anywhere
- **Cons**: Becomes a god object, obscures who produces what, all systems depend on it, hard to trace data flow
- **Rejection Reason**: Godot's per-object signals are already decoupled. A bus adds indirection without benefit for a 16-system game.

### Alternative 2: Observer Pattern via Custom Classes
- **Description**: Systems register as observers on a shared Observable base
- **Pros**: Classic pattern, language-agnostic
- **Cons**: Reinvents Godot's signal system, loses editor integration, more boilerplate
- **Rejection Reason**: Godot signals ARE the observer pattern, already built-in with editor support.

## Consequences

### Positive
- Data flow is traceable: find the signal definition → find all connections via "Find Usages"
- Type-safe parameters catch errors at parse time, not runtime
- No singleton coupling — systems connect to specific objects, not globals

### Negative
- Connection setup requires knowing which object to connect to (must have a reference)
- Signals are fire-and-forget — no return value (use direct calls when response is needed)

### Risks
- **Signal disconnection on scene free**: When a room is freed, all signal connections from room objects are automatically cleaned up. Systems that hold references to freed objects will error. Mitigation: use `is_instance_valid()` guards, or connect with `CONNECT_ONE_SHOT` for single-use signals.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| entity-framework.md | Interactions with Other Systems | Defines signal-based communication for all 6 downstream systems |
| combat-system.md | Hit-stop orchestration | CombatSystem emits signals to Animation + Camera + Input |
| card-hand-system.md | card_played / card_drawn signals | Typed signals with CardData + slot_index parameters |
| input-system.md | input_device_changed signal | InputManager signal consumed by all UI systems |

## Performance Implications
- **CPU**: Godot signals have ~0.1μs overhead per emission. At 60fps with ~20 signals/frame, total cost < 0.01ms. Negligible.
- **Memory**: Signal connections are lightweight references. No concern.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. A signal emitted by CombatSystem is received by RoomEncounterManager without either system importing the other
2. Freeing a room scene does not produce errors in autoload signal handlers
3. All signal parameters are typed — GDScript static analysis reports no untyped signal warnings

## Related Decisions
- ADR-0001: Entity Composition Pattern (signals on EntityBase and components)
- ADR-0009: Damage Pipeline (combat signal chain)
