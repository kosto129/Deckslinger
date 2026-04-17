# Story 002: EntityBase Lifecycle State Machine

> **Epic**: Entity Framework
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/entity-framework.md`
**Requirement**: `TR-EF-001`, `TR-EF-002`

**ADR Governing Implementation**: ADR-0001: Entity Composition Pattern
**ADR Decision Summary**: EntityBase extends Node2D with entity_type (immutable) and _lifecycle_state (private). Lifecycle transitions via public methods. Signals emitted on state change.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: @abstract decorator (4.5) optional for method contracts.

**Control Manifest Rules (Foundation)**:
- Required: EntityBase is the only entity base class — no inheritance hierarchy
- Required: Cache component references with @onready
- Forbidden: Never use deep inheritance for entity types

---

## Acceptance Criteria

- [x] `EntityBase` class exists extending Node2D with `entity_type` and `_lifecycle_state`
- [x] 6 lifecycle states: INACTIVE → SPAWNING → ACTIVE → STUNNED → DYING → DEAD
- [x] `activate()` transitions INACTIVE → SPAWNING
- [x] `die()` transitions ACTIVE/STUNNED → DYING
- [x] `despawn()` transitions DYING → DEAD and calls `queue_free()`
- [x] `set_stunned(true)` transitions ACTIVE → STUNNED; `set_stunned(false)` transitions STUNNED → ACTIVE
- [x] `lifecycle_state_changed(old, new)` signal emits on every valid transition
- [x] `despawned(entity)` signal emits before `queue_free()`
- [x] Invalid transitions (e.g., DEAD → ACTIVE) are rejected with error log in debug
- [x] `get_lifecycle_state()` returns current state

---

## Implementation Notes

From ADR-0001: EntityBase owns only identity and lifecycle. The state machine is private — external systems trigger transitions via public methods only. Add @onready cached getters for all 8 component types (null-safe, components may not exist).

```gdscript
@export var entity_type: Enums.EntityType
var _lifecycle_state: Enums.LifecycleState = Enums.LifecycleState.INACTIVE

signal lifecycle_state_changed(old_state: Enums.LifecycleState, new_state: Enums.LifecycleState)
signal despawned(entity: EntityBase)
```

---

## Out of Scope

- Story 003: Individual component scripts
- Story 004: Entity scene templates
- Story 005: Edge cases (spawn invulnerability, death timeout)

---

## QA Test Cases

- **AC-1**: activate() transition
  - Given: Entity in INACTIVE state
  - When: activate() called
  - Then: State is SPAWNING, lifecycle_state_changed emitted with (INACTIVE, SPAWNING)
  - Edge cases: activate() called when already ACTIVE → rejected

- **AC-2**: die() transition
  - Given: Entity in ACTIVE with any HP
  - When: die() called
  - Then: State is DYING, signal emitted
  - Edge cases: die() called in INACTIVE → rejected; die() in DYING → rejected

- **AC-3**: despawn() cleanup
  - Given: Entity in DYING
  - When: despawn() called
  - Then: despawned signal emits, queue_free() called
  - Edge cases: despawn() in ACTIVE → rejected

- **AC-4**: Stun transitions
  - Given: Entity in ACTIVE
  - When: set_stunned(true) called
  - Then: State is STUNNED, signal emitted
  - When: set_stunned(false) called
  - Then: State is ACTIVE, signal emitted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/entity/entity_base_lifecycle_test.gd` — must exist and pass
**Status**: [x] `tests/unit/entity/entity_base_lifecycle_test.gd` — 17 test cases

---

## Dependencies

- Depends on: Story 001 (Shared Enums)
- Unlocks: Story 003, Story 004, Story 005
