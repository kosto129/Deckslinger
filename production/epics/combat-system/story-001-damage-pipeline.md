# Story 001: Damage Pipeline

> **Epic**: Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-CO-001`, `TR-CO-002`

**ADR Governing Implementation**: ADR-0009: Damage Pipeline and Health Authority
**ADR Decision Summary**: `CombatSystem._process_hit()` applies multiplicative modifier chain: `base × vuln × resist × stun_bonus × crit`, floored to int, minimum 1. `HealthComponent.take_damage()` is the sole HP modification path. `damage_dealt` signal emits with source, target, amount, and crit flag.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No engine-specific APIs. Pure GDScript math. `floori()` and `maxi()` are built-in GDScript globals unchanged across versions.

**Control Manifest Rules (Core)**:
- Required: All damage flows through CombatSystem's pipeline — `_process_hit()` for direct hits
- Required: Damage modifiers are multiplicative — `base × vuln × resist × stun × crit`; floor to int; minimum 1 damage
- Required: HealthComponent is the sole authority on entity HP — only CombatSystem calls `take_damage()`
- Forbidden: Never use additive damage modifiers
- Forbidden: Never calculate damage inside HitboxComponent

---

## Acceptance Criteria

- [ ] `CombatSystem` class exists: `class_name CombatSystem extends Node`
- [ ] `_process_hit(hit_data: HitData) -> void` is the entry point for all direct hit damage
- [ ] Guard: if target entity has no HealthComponent, or health is not alive, return without processing
- [ ] Guard: if target entity lifecycle is DYING or DEAD, return without processing (dead entities ignore further damage)
- [ ] Vulnerability multiplier: read from `StatusEffectComponent.get_damage_taken_multiplier()` on target; default 1.0 if component absent
- [ ] Resistance multiplier: read from `StatusEffectComponent` (combined into `get_damage_taken_multiplier()` — StatusEffectComponent applies both); default 1.0
- [ ] Stun bonus: if target lifecycle state is STUNNED, multiply by `STUN_DAMAGE_BONUS = 1.25`; otherwise 1.0
- [ ] Crit: roll `randf() < hit_data.crit_chance`; if true, multiply by `CRIT_MULTIPLIER = 1.5`; set `is_crit = true`
- [ ] `final_damage = maxi(floori(hit_data.damage * vuln * stun_bonus * crit_mult), 1)`
- [ ] `HealthComponent.take_damage(final_damage, hit_data.source_entity)` is the only HP modification call
- [ ] `damage_dealt` signal emits: `signal damage_dealt(source: EntityBase, target: EntityBase, amount: int, is_crit: bool)`
- [ ] `HealthComponent.take_damage(0)` is never called (guarded by minimum 1)
- [ ] `CombatSystem` connects to `HurtboxComponent.hit_received` signals on entities present in the encounter

---

## Implementation Notes

From ADR-0009: The pipeline is a 9-step function. Steps 1–4 are covered in this story. Steps 5–9 (feedback, death) are in stories 002–003. This story implements the math core.

```gdscript
class_name CombatSystem extends Node

const STUN_DAMAGE_BONUS: float = 1.25
const CRIT_MULTIPLIER: float = 1.5
const MIN_HITSTOP_FRAMES: int = 2
const MAX_HITSTOP_FRAMES: int = 8
const DEATH_HITSTOP_BONUS: int = 3

signal damage_dealt(source: EntityBase, target: EntityBase, amount: int, is_crit: bool)
signal entity_killed(entity: EntityBase, killer: EntityBase)
signal combat_shake_requested(intensity: float)
signal hit_stop_triggered(duration_frames: int)

func _process_hit(hit_data: HitData) -> void:
    var target: EntityBase = hit_data.target_entity
    var health: HealthComponent = target.get_health()
    if not health or not health.is_alive():
        return

    # Read status modifiers
    var status: StatusEffectComponent = target.get_status_effects()
    var vuln: float = status.get_damage_taken_multiplier() if status else 1.0

    # Stun bonus
    var stun_bonus: float = STUN_DAMAGE_BONUS if target.get_lifecycle_state() == Enums.LifecycleState.STUNNED else 1.0

    # Crit roll
    var is_crit: bool = randf() < hit_data.crit_chance
    var crit_mult: float = CRIT_MULTIPLIER if is_crit else 1.0

    # Final damage
    var final_damage: int = maxi(floori(hit_data.damage * vuln * stun_bonus * crit_mult), 1)

    # Apply to health
    health.take_damage(final_damage, hit_data.source_entity)

    # Emit signal
    damage_dealt.emit(hit_data.source_entity, target, final_damage, is_crit)

    # Feedback + death check — handled by stories 002 and 003
    _trigger_combat_feedback(hit_data, final_damage, is_crit)
    if not health.is_alive():
        _process_death(target, hit_data.source_entity, hit_data.shake_intensity)
```

Formula reference (GDD F.1 and ADR-0009):
- Normal hit, base 15: `floor(15 × 1.0 × 1.0 × 1.0) = 15`
- Vulnerable stunned crit, base 15: `floor(15 × 1.5 × 1.25 × 1.5) = floor(42.19) = 42`
- Resistant target, base 15: `floor(15 × 0.5) = floor(7.5) = 7`

---

## Out of Scope

- Story 002: Death processing (`_process_death()`)
- Story 003: Combat feedback (`_trigger_combat_feedback()` — hit-stop, shake, damage numbers)
- Story 004: DoT damage (`apply_dot_tick()`)
- `execute_card()` entry point — defined as part of Combat System integration but not in this story

---

## QA Test Cases

- **AC-1**: No modifiers — exact damage
  - Given: HitData with `damage = 15`, `crit_chance = 0.0`; target has no status effects, not STUNNED
  - When: `_process_hit()` called
  - Then: `HealthComponent.take_damage(15, source)` called; `damage_dealt` emits with `amount = 15, is_crit = false`

- **AC-2**: Vulnerable target
  - Given: HitData `damage = 15`; target `get_damage_taken_multiplier()` returns 1.5 (VULNERABLE)
  - When: `_process_hit()` called
  - Then: `final_damage = floor(15 × 1.5) = 22`; `take_damage(22)` called

- **AC-3**: STUNNED target bonus
  - Given: HitData `damage = 15`; target lifecycle = STUNNED; no other modifiers
  - When: `_process_hit()` called
  - Then: `final_damage = floor(15 × 1.25) = 18`; `take_damage(18)` called

- **AC-4**: Vulnerable + Resistant (multiplicative interaction)
  - Given: HitData `damage = 15`; target has both VULNERABLE (1.5) and RESISTANT (0.5) — combined multiplier = 0.75
  - When: `_process_hit()` called
  - Then: `final_damage = floor(15 × 0.75) = floor(11.25) = 11`

- **AC-5**: Minimum 1 damage
  - Given: HitData `damage = 1`; target has RESISTANT (0.5); `floor(1 × 0.5) = 0`
  - When: `_process_hit()` called
  - Then: `final_damage = maxi(0, 1) = 1`; `take_damage(1)` called

- **AC-6**: Dead target guard
  - Given: Target entity lifecycle = DYING
  - When: `_process_hit()` called
  - Then: Function returns immediately; `take_damage` NOT called; `damage_dealt` NOT emitted

- **AC-7**: Crit roll (deterministic test)
  - Given: HitData `damage = 10, crit_chance = 1.0` (guaranteed crit)
  - When: `_process_hit()` called
  - Then: `final_damage = floor(10 × 1.5) = 15`; `damage_dealt` emits with `is_crit = true`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/damage_pipeline_test.gd` — must exist and pass
**Status**: [x] `tests/unit/combat/damage_pipeline_test.gd` — 8 test cases

---

## Dependencies

- Depends on: Entity Framework epic (complete) — EntityBase, HealthComponent, StatusEffectComponent (placeholder with `get_damage_taken_multiplier()` returning 1.0), lifecycle state enum
- Depends on: Collision/Hitbox story-002 (Hit Detection) — `hit_received` signal and HitData structure must exist
- Unlocks: Story 002 (Death Processing — called from `_process_hit()` after HP check)
- Unlocks: Story 003 (Combat Feedback — called from `_process_hit()`)
- Unlocks: Story 004 (DoT Damage — shares constants and health-write path)
- Unlocks (cross-epic): Card Hand System story-002 (try_play_card calls execute_card which calls _process_hit chain)
