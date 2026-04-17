# Story 004: Sprite Integration

> **Epic**: Animation State Machine
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/animation-state-machine.md`
**Requirement**: `TR-AS-004`, `TR-AS-005`

**ADR Governing Implementation**: ADR-0007: Animation Commitment and Hit-Stop
**ADR Decision Summary**: AnimatedSprite2D driven by state machine via SpriteFrames. Animation names follow `{state}_{direction}` pattern (e.g., `idle_e`, `run_nw`). Art runs at 12 fps (each drawn frame held for 5 physics frames at 60fps). Missing animation key falls back to IDLE with a warning.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: AnimatedSprite2D and SpriteFrames API unchanged in 4.4–4.6. `AnimatedSprite2D.play(animation_name)` and `AnimatedSprite2D.pause()` are stable.

**Control Manifest Rules (Core)**:
- Required: AnimationComponent drives AnimatedSprite2D via SpriteFrames — animation names follow `{state}_{direction}` pattern
- Forbidden: Never use AnimationPlayer or AnimationTree for gameplay timing

---

## Acceptance Criteria

- [ ] `AnimationComponent` holds `@onready var _sprite: AnimatedSprite2D` referencing the entity's AnimatedSprite2D child
- [ ] On state change, `_update_sprite()` is called and selects animation name as `{state_prefix}_{dir_suffix}`
- [ ] 8 direction suffixes: `e, ne, n, nw, w, sw, s, se` derived from `get_facing_direction()`
- [ ] State prefix mapping: `IDLE→"idle"`, `RUN→"run"`, `WINDUP→"windup"`, `ACTIVE→"active"`, `RECOVERY→"recovery"`, `HIT_REACT→"hit_react"`, `STUNNED→"stunned"`, `DYING→"dying"`, `SPAWNING→"spawning"`
- [ ] If the resolved animation name does not exist in SpriteFrames, falls back to `idle_{dir}` and logs a `push_warning()`
- [ ] Art fps is set to 12 on the SpriteFrames resource (each drawn frame held for 5 physics frames at 60fps)
- [ ] During hit-stop, `_sprite.pause()` is called; when hit-stop ends, `_sprite.play()` is called to resume
- [ ] During WINDUP/ACTIVE/RECOVERY, sprite direction is driven by `_locked_facing` (not live input direction)
- [ ] During IDLE/RUN, sprite direction updates each frame from live facing direction
- [ ] `spawn_completed` signal emits when SPAWNING animation reaches last frame
- [ ] `death_completed` signal emits when DYING animation reaches last frame

---

## Implementation Notes

From GDD AP.2 (Frame Rate): Art fps = 12 means each drawn art frame displays for `60 / 12 = 5` physics frames. This is set on the SpriteFrames resource in the editor, not in code. The timing contract is in physics frames; art frames are a visual concern only.

From GDD DA.1 (8-Direction Support): For MVP, 4 directions (E, NE, N, NW) can be drawn with horizontal flip providing W, SW, S, SE. The `_vector_to_dir_string()` function maps a normalized Vector2 to the nearest of 8 direction strings.

```gdscript
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _update_sprite() -> void:
    var anim_name: StringName = _get_animation_name(_state, get_facing_direction())
    if not _sprite.sprite_frames.has_animation(anim_name):
        push_warning("AnimationComponent: animation '%s' not found, falling back to idle" % anim_name)
        anim_name = _get_animation_name(AnimState.IDLE, get_facing_direction())
    if _sprite.animation != anim_name:
        _sprite.play(anim_name)

func _get_animation_name(state: AnimState, direction: Vector2) -> StringName:
    var state_prefix: String = _state_to_prefix(state)
    var dir_suffix: String = _vector_to_dir_string(direction)
    return StringName(state_prefix + "_" + dir_suffix)

func _vector_to_dir_string(dir: Vector2) -> String:
    # Snap to nearest of 8 directions
    var angle: float = dir.angle()  # radians, -PI to PI
    # Map angle to: e, ne, n, nw, w, sw, s, se
    ...
```

Signals for lifecycle:
```gdscript
signal spawn_completed()
signal death_completed()

# Connect to AnimatedSprite2D.animation_finished in _ready():
func _ready() -> void:
    _sprite.animation_finished.connect(_on_sprite_animation_finished)

func _on_sprite_animation_finished() -> void:
    if _state == AnimState.SPAWNING:
        spawn_completed.emit()
    elif _state == AnimState.DYING:
        death_completed.emit()
```

---

## Out of Scope

- Story 001: Phase timer logic
- Story 002: Direction locking logic (this story reads the locked direction; story-002 sets it)
- Story 003: Hit-stop timer logic (this story responds to `hitstop_started`/`hitstop_ended` signals)
- Art asset creation — placeholder sprites are acceptable for this story to pass

---

## QA Test Cases

This is a Visual/Feel story. Automated tests verify the logic layer; visual quality requires lead sign-off via screenshot.

- **Lead sign-off required**: Screenshot showing entity cycling through IDLE → WINDUP → ACTIVE → RECOVERY with correct directional sprite at 8 directions
- **Lead sign-off required**: Screenshot showing sprite flicker during i-frames (verified visually, not by automated test)

Logic assertions (automatable):
- **AC-1**: Animation name resolution
  - Given: State = WINDUP, facing East `(1, 0)`
  - When: `_get_animation_name()` called
  - Then: Returns `&"windup_e"`

- **AC-2**: Direction-during-action uses locked facing
  - Given: Entity in WINDUP, `_locked_facing = (1, 0)` (East)
  - When: `set_facing_direction(Vector2.LEFT)` called
  - Then: `_get_animation_name()` still uses East suffix `"_e"`

- **AC-3**: Fallback on missing animation
  - Given: SpriteFrames does not contain `"special_e"`
  - When: State machine transitions to WINDUP for a "special" animation
  - Then: `push_warning()` called; `_sprite.play("idle_e")` called instead; no crash

- **AC-4**: Sprite pauses during hit-stop
  - Given: `_sprite` is playing
  - When: `hitstop_started` signal received
  - Then: `_sprite.pause()` called — sprite stops advancing frames

- **AC-5**: spawn_completed fires after spawn animation
  - Given: Entity enters SPAWNING state
  - When: AnimatedSprite2D `animation_finished` fires
  - Then: `spawn_completed` emits exactly once

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: Screenshot at `production/qa/evidence/animation-sprite-integration.png` + lead sign-off
**Automated logic assertions**: `tests/unit/animation/sprite_integration_test.gd` (AC-1 through AC-5)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (State Machine Core — state changes drive `_update_sprite()`)
- Depends on: Story 002 (Commitment Enforcement — `_locked_facing` must exist before direction resolution)
- Depends on: Story 003 (Hit-Stop — `hitstop_started`/`hitstop_ended` signals must exist to pause/resume sprite)
- Unlocks: Card Hand UI (visual feedback for card play states); Combat HUD (entity animation states visible)
