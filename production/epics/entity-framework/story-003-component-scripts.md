# Story 003: Component Scripts

> **Epic**: Entity Framework
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/entity-framework.md`
**Requirement**: `TR-EF-003` (component discovery)

**ADR Governing Implementation**: ADR-0001: Entity Composition Pattern
**ADR Decision Summary**: Components are child nodes with class_name. EntityBase provides cached typed getters. Missing component returns null — valid state.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: None.

**Control Manifest Rules (Foundation)**:
- Required: A missing component is valid, not an error
- Required: Cache component references with @onready in EntityBase

---

## Acceptance Criteria

- [ ] 8 component scripts exist, each with unique `class_name`:
  - HealthComponent, HitboxComponent, HurtboxComponent, MovementComponent, AnimationComponent, StatusEffectComponent, FactionComponent, AIBehaviorComponent
- [ ] Each component extends the appropriate base (Node for logic-only, Area2D for hitbox/hurtbox)
- [ ] EntityBase typed getters return the component or null if absent
- [ ] Entity with missing component (e.g., no AIBehaviorComponent) does not error
- [ ] HealthComponent exposes: take_damage(), heal(), get_current_hp(), get_max_hp(), is_alive(), health_changed signal, died signal

---

## Implementation Notes

From ADR-0001: Components are stub scripts at this stage — full implementation happens in their respective epics (Combat implements HealthComponent logic, Collision implements Hitbox/Hurtbox, etc.). This story creates the scripts with class_name, basic exported fields, and signal declarations. EntityBase gets @onready getters for all 8.

HealthComponent is the most complete stub — it needs take_damage/heal/signals because the Combat System epic depends on this interface existing.

---

## Out of Scope

- Full HitboxComponent/HurtboxComponent logic (Collision/Hitbox epic)
- Full AnimationComponent state machine (Animation State Machine epic)
- Full StatusEffectComponent tick logic (Status Effect epic)
- Full AIBehaviorComponent FSM (Enemy AI epic)

---

## QA Test Cases

- **AC-1**: Component discovery
  - Given: EntityBase with HealthComponent child node
  - When: get_health() called
  - Then: Returns the HealthComponent instance (not null)

- **AC-2**: Missing component
  - Given: EntityBase without AIBehaviorComponent
  - When: get_ai() called
  - Then: Returns null, no error in output log

- **AC-3**: HealthComponent interface
  - Given: HealthComponent with max_hp=100, current_hp=100
  - When: take_damage(30, null) called
  - Then: current_hp=70, health_changed emitted with (100, 70, null)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/entity/component_discovery_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Enums), Story 002 (EntityBase)
- Unlocks: Story 004, Story 005, and all Core layer epics
