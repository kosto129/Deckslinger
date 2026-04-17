# Story 002: Hit Detection

> **Epic**: Collision/Hitbox System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/collision-hitbox-system.md`
**Requirement**: `TR-CH-003`, `TR-CH-004`

**ADR Governing Implementation**: ADR-0008: Collision Layer Strategy
**ADR Decision Summary**: HitboxComponent listens for `area_entered` on its Area2D, creates a HitData packet, and calls `HurtboxComponent.receive_hit()`. Single-hit tracking via `_already_hit` Dictionary cleared on `action_completed`. The HitboxComponent knows the attacker context; the HurtboxComponent routes hits to Combat System.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Area2D.area_entered` signal, `Area2D.monitoring` property unchanged. `RefCounted` base class for HitData unchanged.

**Control Manifest Rules (Core)**:
- Required: HitboxComponent tracks entities already hit per action — `Dictionary` cleared on `action_completed`
- Required: Runtime-only packets use RefCounted — HitData is `extends RefCounted`, never saved to disk
- Forbidden: Never calculate damage inside HitboxComponent — all damage math belongs in CombatSystem
- Forbidden: Never check faction in code after overlap detection — layer/mask handles it

---

## Acceptance Criteria

- [ ] `HitData` class exists: `class_name HitData extends RefCounted` with all fields typed:
  - `var source_entity: EntityBase`
  - `var target_entity: EntityBase`
  - `var damage: int`
  - `var knockback_direction: Vector2`
  - `var knockback_force: float`
  - `var hit_position: Vector2`
  - `var effect_source: StringName`
  - `var shake_intensity: float`
  - `var status_effects: Array[StringName]`
  - `var crit_chance: float`
- [ ] `HitboxComponent` class exists: `class_name HitboxComponent extends Area2D`
- [ ] `enable(hit_data_template: HitData) -> void` enables `monitoring = true` and stores template; clears `_already_hit`
- [ ] `disable() -> void` sets `monitoring = false`
- [ ] `is_active() -> bool` returns current `monitoring` state
- [ ] `clear_hit_targets() -> void` clears `_already_hit` Dictionary
- [ ] On `area_entered(area)`: if `area is HurtboxComponent` AND target entity not in `_already_hit`: add to `_already_hit`, create HitData from template, set `target_entity` and `hit_position`, call `area.receive_hit(hit_data)`
- [ ] `HurtboxComponent` class exists: `class_name HurtboxComponent extends Area2D`
- [ ] `receive_hit(hit_data: HitData) -> void` emits `hit_received(hit_data)` if not invincible and entity is ACTIVE or STUNNED
- [ ] `signal hit_received(hit_data: HitData)` is typed
- [ ] HitboxComponent connects to AnimationComponent's `action_completed` signal to call `clear_hit_targets()`
- [ ] HitboxComponent connects to AnimationComponent's `active_started` signal to call `enable()`; `action_completed` calls `disable()` after clearing

---

## Implementation Notes

From ADR-0008: The single-hit rule is enforced by `_already_hit: Dictionary`. Keys are EntityBase references (the target entity). The Dictionary is cleared on each new action. Multiple targets CAN be hit in the same action — only repeat hits on the same target are blocked.

```gdscript
class_name HitboxComponent extends Area2D

var _hit_data_template: HitData = null
var _already_hit: Dictionary = {}  # EntityBase → true

signal # no signals — HitboxComponent calls into HurtboxComponent directly

func enable(hit_data_template: HitData) -> void:
    _hit_data_template = hit_data_template
    _already_hit.clear()
    monitoring = true

func disable() -> void:
    monitoring = false

func clear_hit_targets() -> void:
    _already_hit.clear()

func _on_area_entered(area: Area2D) -> void:
    if not area is HurtboxComponent:
        return
    var hurtbox: HurtboxComponent = area as HurtboxComponent
    var target: EntityBase = hurtbox.get_parent() as EntityBase
    if target == null or _already_hit.has(target):
        return
    _already_hit[target] = true
    var hit_data: HitData = HitData.new()
    # Copy template fields
    hit_data.source_entity = _hit_data_template.source_entity
    hit_data.damage = _hit_data_template.damage
    hit_data.effect_source = _hit_data_template.effect_source
    hit_data.shake_intensity = _hit_data_template.shake_intensity
    hit_data.status_effects = _hit_data_template.status_effects
    hit_data.knockback_force = _hit_data_template.knockback_force
    hit_data.crit_chance = _hit_data_template.crit_chance
    # Fill per-hit fields
    hit_data.target_entity = target
    hit_data.hit_position = global_position  # approximate; can refine to overlap midpoint
    hit_data.knockback_direction = (target.global_position - hit_data.source_entity.global_position).normalized()
    hurtbox.receive_hit(hit_data)
```

HurtboxComponent signal routing:
```gdscript
class_name HurtboxComponent extends Area2D

signal hit_received(hit_data: HitData)

func receive_hit(hit_data: HitData) -> void:
    # i-frame check in story-003 — placeholder here
    hit_received.emit(hit_data)
```

---

## Out of Scope

- Story 001: Collision layer configuration (must be complete before this story can be tested)
- Story 003: I-frame handling inside `receive_hit()` — this story emits hit immediately; story 003 adds the invincibility guard
- Combat System: Damage calculation — `hit_received` signal is consumed by CombatSystem

---

## QA Test Cases

- **AC-1**: Single-hit rule
  - Given: HitboxComponent enabled with template; Enemy HurtboxComponent overlaps for 5 consecutive frames
  - When: Physics processes 5 frames
  - Then: `hurtbox.receive_hit()` called exactly once; `_already_hit` contains the target entity

- **AC-2**: Multi-target hit
  - Given: HitboxComponent enabled; two different enemy HurtboxComponents overlap simultaneously
  - When: Both `area_entered` events fire in same physics frame
  - Then: Both hurtboxes receive their own HitData (separate instances); `_already_hit` contains both entities

- **AC-3**: _already_hit cleared on new action
  - Given: First action completes — `_already_hit` contains one entity
  - When: `action_completed` signal fires from AnimationComponent
  - Then: `clear_hit_targets()` called; `_already_hit` is empty
  - When: New action begins with `enable()` called
  - Then: Same entity can be hit again in the new action

- **AC-4**: HitData fields populated correctly
  - Given: HitboxComponent enabled with template (damage=15, source=PlayerEntity)
  - When: Hitbox overlaps EnemyHurtbox at position (120, 80)
  - Then: HitData.source_entity == PlayerEntity; HitData.damage == 15; HitData.target_entity == EnemyEntity; HitData.hit_position approximately (120, 80)

- **AC-5**: Disabled hitbox produces no hits
  - Given: HitboxComponent with `monitoring = false`
  - When: Enemy hurtbox passes through hitbox area
  - Then: No `area_entered` event fires; no HitData created

- **AC-6**: HurtboxComponent emits hit_received
  - Given: `receive_hit(hit_data)` called on HurtboxComponent
  - When: No i-frames active (story 003 not yet applied)
  - Then: `hit_received(hit_data)` signal emits with the correct HitData

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/hit_detection_test.gd` — must exist and pass
**Status**: [x] `tests/unit/collision/hit_detection_test.gd` — 10 test cases

---

## Dependencies

- Depends on: Entity Framework epic (complete) — EntityBase, HitboxComponent and HurtboxComponent as Area2D nodes, entity getter methods
- Depends on: Story 001 (Collision Layer Configuration) — layer/mask must be set for detection to work
- Depends on: Animation State Machine story-001 (State Machine Core) — `action_completed` and `active_started` signals must exist
- Unlocks: Story 003 (I-Frames — adds guard inside `receive_hit()`)
- Unlocks (cross-epic): Combat System story-001 (CombatSystem connects to `hit_received` signal)
