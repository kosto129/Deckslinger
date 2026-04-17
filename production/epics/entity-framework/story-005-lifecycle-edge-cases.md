# Story 005: Lifecycle Edge Cases

> **Epic**: Entity Framework
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/entity-framework.md`
**Requirement**: `TR-EF-002`

**ADR Governing Implementation**: ADR-0001: Entity Composition Pattern
**ADR Decision Summary**: Entity lifecycle handles edge cases: spawn invulnerability, death timeout, stun-during-dying rejection, and force-despawn safety valve.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: None.

**Control Manifest Rules (Foundation)**:
- Required: All gameplay timers count physics frames, not real-time

---

## Acceptance Criteria

- [ ] Entity in SPAWNING ignores take_damage() — HP unchanged
- [ ] Entity in DYING ignores take_damage() — no double-death
- [ ] Entity in DYING for > `death_animation_timeout` frames triggers force-despawn
- [ ] Status effects applied during INACTIVE or SPAWNING are rejected
- [ ] BOSS stun cleared on phase transition: STUNNED → ACTIVE → phase transition executes
- [ ] Two take_damage() calls in same physics frame: first processes, second ignored if entity now DYING
- [ ] die() on entity with no HealthComponent transitions directly to DYING without error

---

## Implementation Notes

These are guard conditions on the lifecycle state machine from Story 002. Add frame-counted `_dying_timer` that increments each physics frame while in DYING state. If timer exceeds `death_animation_timeout`, call `despawn()` directly.

Spawn invulnerability: in `_physics_process`, if state is SPAWNING, reject all damage. This could be a check in HealthComponent.take_damage() or in the lifecycle guard.

---

## Out of Scope

- BOSS phase transition logic itself (Boss System, Vertical Slice)
- Status effect system implementation (Status Effect epic)

---

## QA Test Cases

- **AC-1**: Spawn invulnerability
  - Given: Entity in SPAWNING state with 100 HP
  - When: take_damage(50, attacker) called
  - Then: HP remains 100, no health_changed signal

- **AC-2**: Death timeout
  - Given: Entity in DYING state
  - When: death_animation_timeout frames elapse
  - Then: despawn() called automatically, despawned signal emits

- **AC-3**: Double-death prevention
  - Given: Entity in ACTIVE with 5 HP
  - When: take_damage(5) and take_damage(10) in same frame
  - Then: First processes (HP→0, DYING), second ignored

- **AC-4**: No HealthComponent die
  - Given: Entity (Prop type) with no HealthComponent
  - When: die() called
  - Then: Transitions to DYING without error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/entity/lifecycle_edge_cases_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (EntityBase), Story 003 (Components)
- Unlocks: None (final story in this epic)
