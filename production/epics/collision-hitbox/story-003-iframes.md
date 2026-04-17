# Story 003: Invincibility Frames

> **Epic**: Collision/Hitbox System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/collision-hitbox-system.md`
**Requirement**: `TR-CH-005`, `TR-CH-006`

**ADR Governing Implementation**: ADR-0008: Collision Layer Strategy
**ADR Decision Summary**: HurtboxComponent tracks `_iframes_remaining` as a physics frame counter. Timer pauses during hit-stop (`_frozen` flag). Visual flicker toggles sprite visibility every `FLICKER_INTERVAL` frames. Dodge i-frames implemented by disabling hurtbox entirely via `set_enabled(false)`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Node.visible` property on the entity's Sprite2D/AnimatedSprite2D unchanged. No post-cutoff risk.

**Control Manifest Rules (Core)**:
- Required: I-frames are frame-counted on HurtboxComponent — 20 frames default; timer pauses during hit-stop
- Required: All gameplay timers count physics frames, not real-time seconds

---

## Acceptance Criteria

- [ ] `HurtboxComponent` has `const IFRAMES_DURATION: int = 20` and `const FLICKER_INTERVAL: int = 3`
- [ ] `receive_hit(hit_data: HitData) -> void`: if `_iframes_remaining > 0`, discard hit and return without emitting `hit_received`
- [ ] On valid hit: emit `hit_received(hit_data)`, then set `_iframes_remaining = IFRAMES_DURATION`
- [ ] `_physics_process`: if `_frozen` is false, decrement `_iframes_remaining` by 1 each frame (minimum 0); call `_update_flicker()`
- [ ] `_frozen: bool` flag: when true, `_iframes_remaining` does NOT decrement (hit-stop integration)
- [ ] `set_invincible(frames: int) -> void` sets `_iframes_remaining = frames` directly (for external systems, e.g., spawn invulnerability)
- [ ] `is_invincible() -> bool` returns `_iframes_remaining > 0`
- [ ] `set_enabled(enabled: bool) -> void` disables/re-enables the hurtbox collision shape for dodge i-frames (full invulnerability — no flickering during dodge)
- [ ] `_update_flicker()`: if `_iframes_remaining > 0`, set entity sprite `visible = ((_iframes_remaining / FLICKER_INTERVAL) % 2 == 0)`; if `_iframes_remaining == 0`, set `visible = true`
- [ ] Hit-stop: HurtboxComponent listens for `hitstop_started`/`hitstop_ended` from AnimationComponent and sets `_frozen` accordingly
- [ ] I-frame timer pauses during hit-stop frames (timer does not count down while frozen)

---

## Implementation Notes

From GDD F.1 (I-Frame Timer): Per physics frame, if NOT in hit-stop, decrement counter. `is_invincible = iframes_remaining > 0`. The timer pauses during hit-stop — those freeze frames do not "use up" invincibility.

From GDD F.2 (Flicker Timing): `is_visible = (iframes_remaining / FLICKER_INTERVAL) % 2 == 0`. With `FLICKER_INTERVAL = 3` and starting at 20: frames 20–18 visible (20/3=6, even), 17–15 hidden (17/3=5, odd), etc.

```gdscript
class_name HurtboxComponent extends Area2D

const IFRAMES_DURATION: int = 20
const FLICKER_INTERVAL: int = 3

var _iframes_remaining: int = 0
var _frozen: bool = false

signal hit_received(hit_data: HitData)

func receive_hit(hit_data: HitData) -> void:
    if _iframes_remaining > 0:
        return  # invincible — discard hit
    hit_received.emit(hit_data)
    _iframes_remaining = IFRAMES_DURATION

func _physics_process(_delta: float) -> void:
    if _frozen:
        return
    if _iframes_remaining > 0:
        _iframes_remaining -= 1
        _update_flicker()
    elif _iframes_remaining == 0:
        _ensure_visible()

func _update_flicker() -> void:
    var sprite: AnimatedSprite2D = _get_entity_sprite()
    if sprite == null:
        return
    sprite.visible = (_iframes_remaining / FLICKER_INTERVAL) % 2 == 0

func _ensure_visible() -> void:
    var sprite: AnimatedSprite2D = _get_entity_sprite()
    if sprite:
        sprite.visible = true

func set_invincible(frames: int) -> void:
    _iframes_remaining = frames

func is_invincible() -> bool:
    return _iframes_remaining > 0

func set_enabled(enabled: bool) -> void:
    # Disables collision shape entirely — used for dodge i-frames
    var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
    if shape:
        shape.disabled = not enabled
```

Dodge i-frames use `set_enabled(false)` to disable the collision shape entirely. This means no `area_entered` event fires at all during the dodge window — more reliable than i-frame counting for a time-limited full invulnerability.

---

## Out of Scope

- Story 001: Collision layer configuration
- Story 002: HitData creation and single-hit tracking (this story adds the guard inside `receive_hit()`)
- Dodge action logic — the dodge action (in Movement/Input System) calls `hurtbox.set_enabled(false)` and re-enables after `DODGE_IFRAMES` frames; this story only implements the `set_enabled()` method

---

## QA Test Cases

- **AC-1**: I-frames block follow-up hits
  - Given: Entity just received a hit; `_iframes_remaining = 20`
  - When: `receive_hit()` called again on frame 5 (15 frames remaining)
  - Then: Hit is discarded — `hit_received` does NOT emit; `_iframes_remaining` unchanged

- **AC-2**: I-frames expire correctly
  - Given: Entity receives hit; `_iframes_remaining = 20`
  - When: 20 physics frames elapse (no hit-stop)
  - Then: `_iframes_remaining == 0`; `is_invincible()` returns false
  - When: Next `receive_hit()` call
  - Then: `hit_received` emits normally

- **AC-3**: Hit-stop pauses i-frame timer
  - Given: Entity took hit; `_iframes_remaining = 10`; `_frozen` set to true (hit-stop begins)
  - When: 3 physics frames elapse
  - Then: `_iframes_remaining` still equals 10
  - When: `_frozen` set to false (hit-stop ends); 3 more frames elapse
  - Then: `_iframes_remaining` equals 7

- **AC-4**: Flicker pattern correct
  - Given: `_iframes_remaining = 17`, `FLICKER_INTERVAL = 3`
  - When: `_update_flicker()` called
  - Then: `17 / 3 = 5` (integer division), `5 % 2 = 1` (odd) → `visible = false`
  - Given: `_iframes_remaining = 18`
  - When: `_update_flicker()` called
  - Then: `18 / 3 = 6` (even) → `visible = true`

- **AC-5**: set_enabled(false) prevents area_entered
  - Given: HurtboxComponent with `set_enabled(false)` called (CollisionShape2D disabled)
  - When: Enemy hitbox sweeps through position
  - Then: No `area_entered` fires on the hurtbox — full invulnerability, no hit delivered

- **AC-6**: Sprite visible restored after i-frames
  - Given: Entity in i-frames (flickering)
  - When: `_iframes_remaining` reaches 0
  - Then: Sprite `visible` set to true; no more flickering

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/iframes_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Entity Framework epic (complete) — EntityBase, component structure, entity sprite reference
- Depends on: Story 001 (Collision Layer Configuration) — correct layers required for hit detection
- Depends on: Story 002 (Hit Detection) — `receive_hit()` defined in story-002; this story adds the i-frame guard to it
- Depends on: Animation State Machine story-003 (Hit-Stop) — `hitstop_started`/`hitstop_ended` signals required to set `_frozen`
- Unlocks (cross-epic): Combat System story-001 (CombatSystem calls `hit_received` signal after i-frame filtering)
