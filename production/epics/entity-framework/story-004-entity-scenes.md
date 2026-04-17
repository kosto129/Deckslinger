# Story 004: Entity Scene Templates

> **Epic**: Entity Framework
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/entity-framework.md`
**Requirement**: `TR-EF-001`, `TR-EF-004`

**ADR Governing Implementation**: ADR-0001: Entity Composition Pattern
**ADR Decision Summary**: Entities are PackedScene files with EntityBase root and typed component children. Scene composition determines entity capabilities.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: None.

**Control Manifest Rules (Foundation)**:
- Required: Scenes/Prefabs use PascalCase matching root node
- Required: Collision footprints ~50% of sprite canvas

---

## Acceptance Criteria

- [ ] `Player.tscn` exists with EntityBase root + all 7 non-AI components + AnimatedSprite2D
- [ ] `StandardEnemy.tscn` exists with EntityBase root + all 8 components + AnimatedSprite2D
- [ ] `Projectile.tscn` exists with EntityBase root + HitboxComponent + MovementComponent only
- [ ] Player collision footprint is 16×16 px within 32×32 sprite canvas (~50% ratio)
- [ ] Standard enemy collision footprint is 16×16 px within 32×32 sprite canvas
- [ ] Each scene can be instantiated, activated, and transitions through lifecycle states
- [ ] Player scene has entity_type = PLAYER, enemy scene has STANDARD_ENEMY, projectile has PROJECTILE

---

## Implementation Notes

Create scene files in `assets/scenes/entities/`. Use placeholder sprites (colored rectangles) until art assets exist. CollisionShape2D on hitbox/hurtbox components should be configured with the correct footprint sizes from the GDD.

---

## Out of Scope

- Elite/Boss entity scenes (Feature layer)
- Prop entity scenes (deferred)
- Actual sprite art (art pipeline)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/entity/entity_scene_test.gd` — instantiate each scene, verify components present and lifecycle works
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (EntityBase), Story 003 (Components)
- Unlocks: Story 005, and all Core layer epics
