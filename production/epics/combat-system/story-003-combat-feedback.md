# Story 003: Combat Feedback

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-CO-004`, `TR-CO-005`

**ADR Governing Implementation**: ADR-0009: Damage Pipeline and Health Authority; ADR-0007: Animation Commitment and Hit-Stop
**ADR Decision Summary**: Combat feedback is orchestrated by CombatSystem after damage is applied. Hit-stop applies to both attacker AND target AnimationComponents, plus freezes InputManager and CameraController. Screen shake requested via `combat_shake_requested` signal (Camera System owns the implementation). Damage numbers spawned at `HitData.hit_position` with stacking offset.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff API risk. Label and Tween APIs for damage numbers are stable. `Vector2` arithmetic unchanged.

**Control Manifest Rules (Core)**:
- Required: Hit-stop freezes ALL gameplay systems simultaneously — AnimationComponent (both attacker and target), InputManager, CameraController
- Forbidden: Never check faction in code after overlap detection (not applicable here but noted for context)

---

## Acceptance Criteria

- [ ] `_trigger_combat_feedback(hit_data: HitData, final_damage: int, is_crit: bool) -> void` orchestrates all feedback after damage is applied
- [ ] Hit-stop: applies to attacker (`hit_data.source_entity.get_animation().apply_hitstop(frames)`) if source is non-null and has AnimationComponent
- [ ] Hit-stop: applies to target (`hit_data.target_entity.get_animation().apply_hitstop(frames)`) if target has AnimationComponent
- [ ] Hit-stop frames calculated via `_calculate_hitstop(hit_data.shake_intensity)` from story-002
- [ ] `InputManager.set_frozen(true)` called when hit-stop begins (AnimationComponent handles the timing via its own `hitstop_started` signal — CombatSystem does not need to call this directly; verified that double-freeze is harmless)
- [ ] `combat_shake_requested(intensity: float)` signal emits with `hit_data.shake_intensity`
- [ ] Damage number spawned at `hit_data.hit_position` with value `final_damage`
- [ ] Damage number color: white for normal hits, yellow for crits, red when target is the player entity
- [ ] Stacking offset: `display_position = hit_position + Vector2(0, -stack_index * STACK_OFFSET)` where `STACK_OFFSET = 8` px
- [ ] Stack tracking: counts damage numbers spawned within 5 frames at positions within 16px of each other; increments `stack_index`
- [ ] `hit_stop_triggered(duration_frames: int)` signal emits after applying hit-stop
- [ ] If `shake_intensity == 0.0`, no hit-stop is triggered (0 frames)

---

## Implementation Notes

From GDD HSO.1 (Hit-Stop Triggering) and DN.1–DN.2 (Damage Numbers):

Hit-stop orchestration:
```gdscript
func _trigger_combat_feedback(hit_data: HitData, final_damage: int, is_crit: bool) -> void:
    # Hit-stop
    var hitstop_frames: int = _calculate_hitstop(hit_data.shake_intensity)
    if hitstop_frames > 0:
        if hit_data.source_entity:
            var src_anim: AnimationComponent = hit_data.source_entity.get_animation()
            if src_anim:
                src_anim.apply_hitstop(hitstop_frames)
        var tgt_anim: AnimationComponent = hit_data.target_entity.get_animation()
        if tgt_anim:
            tgt_anim.apply_hitstop(hitstop_frames)
        hit_stop_triggered.emit(hitstop_frames)

    # Screen shake
    if hit_data.shake_intensity > 0.0:
        combat_shake_requested.emit(hit_data.shake_intensity)

    # Damage numbers
    _spawn_damage_number(hit_data.hit_position, final_damage, is_crit, hit_data.target_entity)
```

Damage number spawning:
```gdscript
const STACK_OFFSET: int = 8
const STACK_TIME_WINDOW: int = 5   # frames
const STACK_DISTANCE: float = 16.0

var _recent_damage_numbers: Array[Dictionary] = []  # [{position, frame_spawned}]

func _spawn_damage_number(pos: Vector2, amount: int, is_crit: bool, target: EntityBase) -> void:
    # Calculate stack index
    var current_frame: int = Engine.get_process_frames()  # physics frame count
    var stack_index: int = 0
    for entry in _recent_damage_numbers:
        if current_frame - entry.frame_spawned <= STACK_TIME_WINDOW:
            if entry.position.distance_to(pos) <= STACK_DISTANCE:
                stack_index += 1
    var display_pos: Vector2 = pos + Vector2(0, -stack_index * STACK_OFFSET)
    _recent_damage_numbers.append({position = pos, frame_spawned = current_frame})

    # Color selection
    var color: Color = Color.WHITE
    if is_crit:
        color = Color.YELLOW
    elif target == _player_entity:
        color = Color.RED

    # Instantiate damage number label (scene or Label node)
    # Float upward 16px over 30 frames, fade out over 15 frames
    # (implementation detail — use Tween on a Label or a dedicated DamageNumber scene)
```

Formula F.3 (Damage Number Position Offset): `display_position = hit_position + Vector2(0, -stack_index * STACK_OFFSET)`.

Note: The actual damage number visual (Label + Tween animation) is a Presentation Layer concern. CombatSystem spawns the node and sets position, text, and color. The animation (float upward, fade) is handled by the damage number scene's own script.

---

## Out of Scope

- Story 001: Damage calculation
- Story 002: Death processing and death hit-stop bonus
- Story 004: DoT feedback (separate spawn path with different color/size)
- Camera System: Screen shake implementation (this story only emits `combat_shake_requested`)
- Damage number scene/script visual animation (Presentation layer)

---

## QA Test Cases

This is a Visual/Feel story. Automated tests verify orchestration logic; visual quality requires lead sign-off via screenshot.

- **Lead sign-off required**: Screenshot showing normal hit (white number), crit hit (yellow), player taking damage (red), with correct stacking offset for rapid hits
- **Lead sign-off required**: Screenshot confirming hit-stop pause is visible (attacker and target both freeze for ~6 frames on medium hit)

Logic assertions (automatable):
- **AC-1**: Hit-stop applied to both combatants
  - Given: HitData with `shake_intensity = 3.0`, attacker and target both have AnimationComponent
  - When: `_trigger_combat_feedback()` called
  - Then: Both attacker and target AnimationComponent `apply_hitstop(6)` called; `hit_stop_triggered(6)` emits

- **AC-2**: Zero shake — no hit-stop
  - Given: HitData with `shake_intensity = 0.0`
  - When: `_trigger_combat_feedback()` called
  - Then: Neither `apply_hitstop()` nor `hit_stop_triggered` called/emitted

- **AC-3**: Screen shake signal
  - Given: HitData with `shake_intensity = 2.5`
  - When: `_trigger_combat_feedback()` called
  - Then: `combat_shake_requested(2.5)` signal emits

- **AC-4**: Damage number stacking offset
  - Given: Two hits at position (100, 80) within 5 frames
  - When: Second `_spawn_damage_number()` called
  - Then: First number spawns at (100, 80); second at (100, 72) (offset by 8px upward)

- **AC-5**: Null source entity (DoT, projectile off-screen)
  - Given: HitData with `source_entity = null`, `shake_intensity = 2.0`
  - When: `_trigger_combat_feedback()` called
  - Then: No crash; only target AnimationComponent frozen; shake signal still emits

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: Screenshot at `production/qa/evidence/combat-feedback.png` + lead sign-off
**Automated logic assertions**: `tests/unit/combat/combat_feedback_test.gd` (AC-1 through AC-5)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — EntityBase component getters, player entity reference
- Depends on: Story 001 (Damage Pipeline) — `_trigger_combat_feedback()` is called from `_process_hit()`; `_calculate_hitstop()` defined in story-002
- Depends on: Story 002 (Death Processing) — `_calculate_hitstop()` helper defined there; shared by both stories
- Depends on: Animation State Machine story-003 (Hit-Stop) — `apply_hitstop()` must exist
- Unlocks: Combat System as a fully playable system (all three feedback signals wired)
- Unlocks (cross-epic): Camera System screen shake (subscribes to `combat_shake_requested`)
