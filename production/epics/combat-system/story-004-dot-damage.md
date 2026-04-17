# Story 004: DoT Damage

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-CO-006`

**ADR Governing Implementation**: ADR-0009: Damage Pipeline and Health Authority
**ADR Decision Summary**: `apply_dot_tick()` is a separate entry point on CombatSystem for Damage over Time. It uses the same multiplicative math (base × vuln) but skips hit-stop, screen shake, and knockback. It does spawn damage numbers (smaller, different color). It can kill entities and triggers death processing. `damage_dealt` signal emits with null source.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No engine-specific API risk.

**Control Manifest Rules (Core)**:
- Required: All damage flows through CombatSystem's pipeline — `apply_dot_tick()` for DoT; no system bypasses the pipeline
- Required: HealthComponent is the sole authority on entity HP — `apply_dot_tick()` calls `health.take_damage()`

---

## Acceptance Criteria

- [ ] `apply_dot_tick(target: EntityBase, damage: int, source_status: StringName) -> void` exists on CombatSystem
- [ ] Guard: if target has no HealthComponent, or not alive, or lifecycle is DYING/DEAD — return without processing
- [ ] Applies vulnerability multiplier from target's StatusEffectComponent: `vuln = status.get_damage_taken_multiplier()`; default 1.0 if no component
- [ ] No stun bonus applied to DoT (DoT is background damage, not a committed hit)
- [ ] No crit roll for DoT
- [ ] `final_damage = maxi(floori(damage * vuln), 1)`
- [ ] `HealthComponent.take_damage(final_damage, null)` called (null source for DoT — no entity kill credit except status source)
- [ ] Does NOT call `apply_hitstop()` on any entity
- [ ] Does NOT emit `combat_shake_requested`
- [ ] Does NOT apply knockback
- [ ] DOES spawn damage number: smaller font (8px vs 10px for normal), orange color for burn, green for poison — determined by `source_status` StringName
- [ ] `damage_dealt(null, target, final_damage, false)` signal emits
- [ ] If `health.is_alive() == false` after `take_damage()`: calls `_process_death(target, null, 0.0)` — DoT CAN kill, triggers death processing with null killer
- [ ] DoT damage number spawns at `target.global_position` (not a precise hit_position)

---

## Implementation Notes

From ADR-0009 and GDD SED.1 (DoT Damage):

```gdscript
func apply_dot_tick(target: EntityBase, damage: int, source_status: StringName) -> void:
    var health: HealthComponent = target.get_health()
    if not health or not health.is_alive():
        return
    if target.get_lifecycle_state() in [Enums.LifecycleState.DYING, Enums.LifecycleState.DEAD]:
        return

    var status: StatusEffectComponent = target.get_status_effects()
    var vuln: float = status.get_damage_taken_multiplier() if status else 1.0
    var final_damage: int = maxi(floori(damage * vuln), 1)

    health.take_damage(final_damage, null)  # null source — DoT has no entity killer

    # DoT feedback: damage number only, no hit-stop/shake/knockback
    _spawn_dot_damage_number(target.global_position, final_damage, source_status)

    damage_dealt.emit(null, target, final_damage, false)

    # DoT can kill
    if not health.is_alive():
        _process_death(target, null, 0.0)

func _spawn_dot_damage_number(pos: Vector2, amount: int, source_status: StringName) -> void:
    var color: Color = Color.ORANGE  # default: burn
    if source_status == &"poison":
        color = Color.GREEN
    # Spawn smaller label at target position
    # Font size 8px (normal is 8px too; DoT uses different color, not necessarily smaller)
    # Float and fade same as normal damage numbers
```

Formula reference (GDD F.4 — DoT Damage Per Tick):
- `damage_per_tick = max(floor(dot_base_damage * vulnerability * resistance), 1)`
- Example: burn 3 dmg/tick on VULNERABLE target: `floor(3 × 1.5) = 4`; on RESISTANT: `floor(3 × 0.5) = 1` (minimum)

Note: Resistance and vulnerability are both encoded in `get_damage_taken_multiplier()` — the StatusEffectComponent returns a combined multiplier. The DoT formula in the GDD shows them separately but the implementation uses the combined getter.

---

## Out of Scope

- Story 001: Direct hit damage pipeline (separate entry point)
- Story 002: Death processing implementation (reused here, not re-implemented)
- Story 003: Normal combat feedback (DoT explicitly skips these)
- Status Effect System: The tick scheduling (interval, duration) lives in StatusEffectSystem — `apply_dot_tick()` is called BY StatusEffectSystem, not the reverse

---

## QA Test Cases

- **AC-1**: DoT damage math — no modifiers
  - Given: `apply_dot_tick(target, 3, &"burn")` called; target has no status effects
  - When: Function processes
  - Then: `take_damage(3, null)` called; `damage_dealt(null, target, 3, false)` emits

- **AC-2**: DoT with vulnerable target
  - Given: `apply_dot_tick(target, 3, &"burn")`; target `get_damage_taken_multiplier()` returns 1.5
  - When: Function processes
  - Then: `final_damage = floor(3 × 1.5) = 4`; `take_damage(4, null)` called

- **AC-3**: Minimum 1 damage
  - Given: `apply_dot_tick(target, 1, &"poison")`; target `get_damage_taken_multiplier()` returns 0.5
  - When: `floor(1 × 0.5) = 0`
  - Then: `final_damage = maxi(0, 1) = 1`; `take_damage(1)` called

- **AC-4**: No hit-stop on DoT
  - Given: `apply_dot_tick()` called
  - When: Function completes
  - Then: No AnimationComponent `apply_hitstop()` calls; `hit_stop_triggered` NOT emitted; `combat_shake_requested` NOT emitted

- **AC-5**: DoT kills entity
  - Given: Target at 2 HP; `apply_dot_tick(target, 5, &"burn")`
  - When: Function processes
  - Then: `take_damage(5)` brings HP to 0; `_process_death(target, null, 0.0)` called; `entity_killed(target, null)` emits

- **AC-6**: Dead target guard
  - Given: Target lifecycle = DYING
  - When: `apply_dot_tick()` called
  - Then: Function returns immediately; `take_damage` NOT called

- **AC-7**: DoT damage number color by status
  - Given: `source_status = &"burn"`
  - When: Damage number spawned
  - Then: Color is orange (not white, yellow, or red)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/dot_damage_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — EntityBase, HealthComponent, StatusEffectComponent (placeholder)
- Depends on: Story 001 (Damage Pipeline) — `damage_dealt` signal and CombatSystem class structure established there
- Depends on: Story 002 (Death Processing) — `_process_death()` called from `apply_dot_tick()` on kill; must exist
- Depends on: Story 003 (Combat Feedback) — `_spawn_dot_damage_number()` can share infrastructure with `_spawn_damage_number()`
- Unlocks (cross-epic): Status Effect System (calls `apply_dot_tick()` on each tick interval)
