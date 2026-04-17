# Story 002: Death Processing

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-CO-003`

**ADR Governing Implementation**: ADR-0009: Damage Pipeline and Health Authority
**ADR Decision Summary**: On HP reaching 0, `_process_death()` is called: `entity.die()` transitions lifecycle to DYING, `entity_killed` signal emits with kill credit, death hit-stop bonus applied (`normal_hitstop + DEATH_HITSTOP_BONUS`). Dead entities ignore all further damage (guard in `_process_hit()`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No engine-specific API risk. Entity lifecycle transitions are pure GDScript.

**Control Manifest Rules (Core)**:
- Required: Death processing — `entity.die()` → DYING lifecycle → death animation → `despawn()` (death animation completion handled by AnimationComponent; despawn handled by EntityBase)
- Required: Killing blows get extended hit-stop — `death_hitstop = normal_hitstop + DEATH_HITSTOP_BONUS`

---

## Acceptance Criteria

- [ ] `_process_death(entity: EntityBase, killer: EntityBase, shake_intensity: float) -> void` exists on CombatSystem
- [ ] Calculates `death_hitstop = _calculate_hitstop(shake_intensity) + DEATH_HITSTOP_BONUS` (where `DEATH_HITSTOP_BONUS = 3`)
- [ ] Applies death hit-stop to the killer's AnimationComponent: `killer.get_animation().apply_hitstop(death_hitstop)` (if killer is non-null and has AnimationComponent)
- [ ] Calls `entity.die()` to transition dying entity's lifecycle to DYING
- [ ] Emits `entity_killed(entity: EntityBase, killer: EntityBase)` signal
- [ ] Guard in `_process_hit()`: if `not health.is_alive()` after `take_damage()`, call `_process_death()` exactly once
- [ ] Guard: if entity is already DYING or DEAD when `_process_hit()` is called, return without processing (prevents double-death)
- [ ] Kill credit: `killer` parameter passed through from `hit_data.source_entity`; may be null for DoT deaths
- [ ] `entity_killed` signal typed: `signal entity_killed(entity: EntityBase, killer: EntityBase)`
- [ ] Death hit-stop formula: `_calculate_hitstop(shake_intensity)` = `clampi(ceili(shake_intensity * 2.0), MIN_HITSTOP_FRAMES, MAX_HITSTOP_FRAMES)` if `shake_intensity > 0`, else 0

---

## Implementation Notes

From ADR-0009 and GDD D.1–D.3:

```gdscript
func _process_death(entity: EntityBase, killer: EntityBase, shake_intensity: float) -> void:
    # Extended hit-stop on killing blow — killer feels the finality
    var death_hitstop: int = _calculate_hitstop(shake_intensity) + DEATH_HITSTOP_BONUS
    if killer != null:
        var killer_anim: AnimationComponent = killer.get_animation()
        if killer_anim:
            killer_anim.apply_hitstop(death_hitstop)

    # Trigger death sequence — lifecycle → DYING → death animation → DEAD (via EntityBase)
    entity.die()

    # Emit kill credit signal
    entity_killed.emit(entity, killer)

func _calculate_hitstop(shake_intensity: float) -> int:
    if shake_intensity <= 0.0:
        return 0
    return clampi(ceili(shake_intensity * 2.0), MIN_HITSTOP_FRAMES, MAX_HITSTOP_FRAMES)
```

Formula reference (GDD F.2 — Death Hit-Stop Duration):
- `shake_intensity = 3.0`: `normal_hitstop = clamp(ceil(6), 2, 8) = 6`; `death_hitstop = 6 + 3 = 9 frames (150ms)`
- `shake_intensity = 1.0`: `normal_hitstop = clamp(ceil(2), 2, 8) = 2`; `death_hitstop = 2 + 3 = 5 frames`

Kill credit is tracked via the `killer` parameter from `HitData.source_entity`. For DoT deaths (`apply_dot_tick()`), `killer = null` — no hit credit. The `entity_killed` signal carries null in that case, which downstream systems (Room Encounter, Run State) must handle.

Note: The full death sequence (death animation completion → `entity.despawn()`) is driven by AnimationComponent emitting `death_completed` → EntityBase calling `despawn()`. CombatSystem only initiates the sequence via `entity.die()`.

---

## Out of Scope

- Story 001: Damage calculation (this story runs after HP reaches 0)
- Story 003: Screen shake and damage numbers on killing blow
- AnimationComponent death animation and `death_completed` signal
- Room Encounter System: enemy count tracking after `entity_killed` signal
- Run State Manager: player death run-end logic (downstream of `entity_killed`)

---

## QA Test Cases

- **AC-1**: Normal kill sequence
  - Given: Entity at 5 HP; HitData `damage = 10, shake_intensity = 2.0`
  - When: `_process_hit()` called
  - Then: `take_damage(10)` reduces HP to 0 (clamped); `entity.die()` called; `entity_killed(entity, killer)` emits

- **AC-2**: Death hit-stop bonus applied to killer
  - Given: Entity dying from hit with `shake_intensity = 3.0`; killer has AnimationComponent
  - When: `_process_death()` called
  - Then: `normal_hitstop = 6`; `death_hitstop = 9`; `killer.get_animation().apply_hitstop(9)` called

- **AC-3**: Zero shake_intensity — death hitstop is bonus only
  - Given: `shake_intensity = 0.0`
  - When: `_calculate_hitstop(0.0)` called
  - Then: Returns 0; `death_hitstop = 0 + 3 = 3` (DEATH_HITSTOP_BONUS only)

- **AC-4**: Double-death guard
  - Given: Entity already in DYING lifecycle state
  - When: `_process_hit()` called with lethal damage
  - Then: Guard fires — function returns immediately; `entity.die()` NOT called again; `entity_killed` NOT emitted twice

- **AC-5**: Null killer (DoT death)
  - Given: Entity dies from a DoT tick (`apply_dot_tick()`) — `killer = null`
  - When: `_process_death(entity, null, 0.0)` called
  - Then: No crash; `entity_killed(entity, null)` emits with null killer; no hit-stop applied (no killer to freeze)

- **AC-6**: Kill credit in signal
  - Given: Player entity kills enemy entity
  - When: `entity_killed` fires
  - Then: Signal parameters: `entity = enemy_entity`, `killer = player_entity`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/death_processing_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — EntityBase `die()` method, lifecycle DYING/DEAD states, AnimationComponent getter
- Depends on: Story 001 (Damage Pipeline) — `_process_death()` is called from within `_process_hit()` after HP check
- Depends on: Animation State Machine story-003 (Hit-Stop) — `apply_hitstop()` must exist on AnimationComponent
- Unlocks: Story 003 (Combat Feedback — death hit-stop is separate from normal hit-stop; this story handles killer side only)
- Unlocks (cross-epic): Room Encounter System (subscribes to `entity_killed`); Run State Manager (subscribes to `entity_killed` for player death)
