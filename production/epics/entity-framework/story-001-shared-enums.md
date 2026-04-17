# Story 001: Shared Enums Autoload

> **Epic**: Entity Framework
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/entity-framework.md`
**Requirement**: `TR-EF-002` (EntityType enum), `TR-CD-004` (shared enums)

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture
**ADR Decision Summary**: All cross-system enums live in a single Enums autoload script to prevent circular imports and ensure type consistency.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: None — enum definitions are pure GDScript.

**Control Manifest Rules (Foundation)**:
- Required: All cross-system enums live in the Enums autoload
- Forbidden: Never define enums inside component scripts that other systems need

---

## Acceptance Criteria

- [x] `src/core/enums.gd` exists with `class_name Enums`
- [x] All 13 enum types defined: EntityType, LifecycleState, CardArchetype, CardRarity, CardType, EffectType, TargetingMode, EffectCategory, StackingRule, InputMode, InputDevice, RoomType, RunOutcome
- [x] Script registered as autoload in `project.godot`
- [x] Enums are accessible from any script via `Enums.EntityType.PLAYER` syntax

---

## Implementation Notes

Create `src/core/enums.gd` with all enum definitions from ADR-0004. Register as autoload named "Enums" in Project Settings. This is the first file created — everything else depends on it.

---

## Out of Scope

- Story 002: EntityBase class (uses these enums)
- Story 003: Component scripts (use these enums)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check — enums load without error
**Status**: [x] Smoke check — enums load via autoload, all 13 types defined

---

## Dependencies

- Depends on: None (first story)
- Unlocks: Story 002, Story 003
