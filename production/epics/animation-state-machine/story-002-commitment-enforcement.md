# Story 002: Commitment Enforcement

> **Epic**: Animation State Machine
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/animation-state-machine.md`
**Requirement**: `TR-AS-002`, `TR-AS-004`

**ADR Governing Implementation**: ADR-0007: Animation Commitment and Hit-Stop
**ADR Decision Summary**: WINDUP, ACTIVE, and RECOVERY cannot be cancelled by player input. Only death or stun can interrupt. Facing direction locks at WINDUP start. Stun during WINDUP cancels the action (effect never resolves).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No engine API risk. Logic is pure GDScript frame counting.

**Control Manifest Rules (Core)**:
- Required: Facing direction locks at WINDUP start — visual direction does not change during committed sequence
- Forbidden: Never allow player input to cancel WINDUP, ACTIVE, or RECOVERY — commitment is the core design

---

## Acceptance Criteria

- [ ] During WINDUP, ACTIVE, or RECOVERY: `play_action()` calls are rejected (returns without changing state)
- [ ] During WINDUP, ACTIVE, or RECOVERY: `play_hit_react()` calls are rejected
- [ ] `_locked_facing: Vector2` is set to current facing direction at the moment WINDUP begins
- [ ] `_locked_facing` is used for all animation direction resolution during WINDUP/ACTIVE/RECOVERY
- [ ] `set_facing_direction()` updates `_locked_facing` only if NOT in WINDUP/ACTIVE/RECOVERY
- [ ] `get_facing_direction() -> Vector2` returns `_locked_facing` during committed phases; live direction otherwise
- [ ] `play_stun()` called during WINDUP: entity enters STUNNED, `_phase_timer` is cleared, `action_completed` does NOT emit, no effect resolves
- [ ] `play_stun()` called during ACTIVE: entity enters STUNNED, phase timer clears, RECOVERY is skipped (active effect already resolved — damage dealt on ACTIVE entry)
- [ ] `play_stun()` called during RECOVERY: entity enters STUNNED, recovery is skipped
- [ ] `play_death()` (lifecycle → DYING) called during WINDUP: entity enters DYING, action cancelled, `action_completed` does NOT emit
- [ ] `play_death()` called during ACTIVE: entity enters DYING, active effect already resolved, remaining frames skipped
- [ ] `clear_stun()` transitions STUNNED → IDLE and re-enables full state machine

---

## Implementation Notes

From GDD AS.2 (Valid Transitions): WINDUP, ACTIVE, and RECOVERY are non-interruptible by player input. The only valid interrupts are death (→ DYING) and stun (→ STUNNED). Stun during WINDUP is the key mechanic — it punishes telegraphed attacks from enemies landing on the player mid-windup.

Direction locking is enforced by capturing facing at `play_action()` call time and freezing it in `_locked_facing`. The AnimatedSprite2D always reads from `get_facing_direction()` — which returns locked direction during action phases.

```gdscript
var _locked_facing: Vector2 = Vector2.RIGHT
var _live_facing: Vector2 = Vector2.RIGHT

func set_facing_direction(direction: Vector2) -> void:
    _live_facing = direction
    if _state not in [AnimState.WINDUP, AnimState.ACTIVE, AnimState.RECOVERY]:
        _locked_facing = direction

func get_facing_direction() -> Vector2:
    return _locked_facing  # always returns locked during action; live otherwise since _locked_facing == _live_facing when not in action

func play_stun() -> void:
    # Stun interrupts any state including committed phases
    _phase_timer = 0
    _current_action_key = &""
    _enter_state(AnimState.STUNNED)
    # action_completed is NOT emitted — effect was cancelled

func play_death() -> void:
    _phase_timer = 0
    _current_action_key = &""
    _enter_state(AnimState.DYING)
    # action_completed is NOT emitted
```

Edge case note: When stun is applied during ACTIVE, the `active_started` signal already fired (and damage was already dealt by the Combat System). The stun does not undo damage — it only prevents RECOVERY from completing. This is mechanically correct per GDD edge case "Stun applied during ACTIVE."

---

## Out of Scope

- Story 001: Core state machine and phase timers
- Story 003: Hit-stop freeze (a separate interrupt mechanism, not a cancellation)
- Story 004: AnimatedSprite2D playback of correct directional variant

---

## QA Test Cases

- **AC-1**: Input cannot cancel commitment
  - Given: Entity is in WINDUP phase (play_action called)
  - When: `play_action()` called again (simulating player mashing)
  - Then: Second call is silently rejected; `_state` remains WINDUP; phase timer continues uninterrupted

- **AC-2**: Direction locks at WINDUP start
  - Given: Entity facing East, IDLE state
  - When: `play_action(&"attack_e", 8, 3, 6)` called, then `set_facing_direction(Vector2.LEFT)` called
  - Then: `get_facing_direction()` returns `(1, 0)` (East) throughout WINDUP, ACTIVE, RECOVERY
  - When: `action_completed` fires and entity returns to IDLE
  - Then: `get_facing_direction()` returns `(-1, 0)` (West) — direction updates freely

- **AC-3**: Stun during WINDUP cancels action
  - Given: Entity in WINDUP, 4 frames remaining
  - When: `play_stun()` called
  - Then: State transitions to STUNNED; `_phase_timer = 0`; `action_completed` signal does NOT emit; `active_started` signal does NOT emit

- **AC-4**: Stun during RECOVERY skips remaining recovery
  - Given: Entity in RECOVERY, 8 frames remaining
  - When: `play_stun()` called
  - Then: State transitions to STUNNED; `_phase_timer = 0`; `action_completed` does NOT emit

- **AC-5**: Death during WINDUP cancels action
  - Given: Entity in WINDUP
  - When: `play_death()` called
  - Then: State transitions to DYING; `action_completed` does NOT emit; entity lifecycle continues to DEAD after death animation

- **AC-6**: Death during ACTIVE — effect already resolved
  - Given: Entity in ACTIVE (active_started already emitted, damage dealt)
  - When: `play_death()` called
  - Then: State transitions to DYING; remaining active frames are skipped; entity enters death animation
  - Note: No signal ordering issue — damage was dealt when `active_started` fired, before `play_death()` was called

- **AC-7**: clear_stun returns to IDLE
  - Given: Entity in STUNNED
  - When: `clear_stun()` called
  - Then: State transitions to IDLE; full state machine resumes; `play_action()` is now accepted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/commitment_enforcement_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (State Machine Core) — commitment enforcement is a behaviour of the core state machine
- Unlocks: Story 004 (Sprite Integration — direction lock drives sprite selection)
- Unlocks (cross-epic): Card Hand System story-002 (play validation checks `is_in_action()`); Combat System story-001 (stun bonus requires STUNNED state detection)
