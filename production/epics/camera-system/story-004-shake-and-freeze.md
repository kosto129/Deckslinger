# Story 004: Shake and Freeze

> **Epic**: Camera System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirements**: `TR-CM-004` (Screen shake with per-frame decay), `TR-CM-005` (Hit-freeze camera position hold)

**ADR Governing Implementation**: ADR-0006: Viewport and Camera Pipeline
**ADR Decision Summary**: `request_shake(intensity)` takes the max of current and new intensity (no additive stacking). Shake offset uses a random direction, is rounded to integer pixels, and is clamped to room bounds (automatic via step ordering). `set_frozen(frozen)` holds camera position and pauses shake decay during hit-stop frames.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `randf_range()`, `Vector2.from_angle()`, and `maxf()` are standard GDScript. No post-cutoff API risk.

**Control Manifest Rules (Foundation)**:
- Required: Camera position must be rounded to integer pixels after ALL calculations (follow + look-ahead + shake + clamp).
- Required: Buffer, animation, and camera timers freeze during hit-stop (`_frozen` flag).
- Required: All gameplay timers count physics frames, not real-time seconds.
- Forbidden: Never render at fractional pixel scale.

---

## Acceptance Criteria

- [ ] `request_shake(intensity: float) -> void` is callable on CameraController
- [ ] Calling `request_shake` sets `shake_intensity = maxf(shake_intensity, minf(intensity, MAX_SHAKE_INTENSITY))`
- [ ] Shake offset is a random-direction vector of length `shake_intensity`, rounded to integer pixels, applied before room clamp
- [ ] Each physics frame (when not frozen): `shake_intensity *= SHAKE_DECAY`
- [ ] When `shake_intensity < SHAKE_MIN_THRESHOLD`, it snaps to `0.0`
- [ ] A 3 px shake with `SHAKE_DECAY=0.7` decays to zero by frame 7 (below 0.5 threshold)
- [ ] Two simultaneous `request_shake` calls in the same frame use the higher intensity, not the sum
- [ ] `set_frozen(true)` suspends shake decay — intensity is unchanged until `set_frozen(false)`
- [ ] Shake never pushes camera outside room bounds (ensured by clamp step order: shake applied before clamp)
- [ ] `MAX_SHAKE_INTENSITY` caps the intensity accepted by `request_shake`
- [ ] Shake is cleared (`shake_intensity = 0.0`) when `set_room_bounds` is called (room transition resets shake)

---

## Formulas

**F.2 — Shake Decay**

```
shake_intensity = shake_intensity * SHAKE_DECAY
if shake_intensity < SHAKE_MIN_THRESHOLD:
    shake_intensity = 0.0
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `shake_intensity` | float | 0.0–`MAX_SHAKE_INTENSITY` | Current shake magnitude in pixels |
| `SHAKE_DECAY` | float | 0.5–0.9 | Per-frame multiplier. Default: 0.7 |
| `SHAKE_MIN_THRESHOLD` | float | 0.1–1.0 px | Below this, snap to zero. Default: 0.5 |
| `MAX_SHAKE_INTENSITY` | float | 3–12 px | Hard cap. Default: 6 px |
| `new_intensity` | float | 0.0–`MAX_SHAKE_INTENSITY` | Updated shake magnitude after this frame's decay |

Output range: Always `[0.0, MAX_SHAKE_INTENSITY]`. Converges to exactly 0.0 (no infinite decay).

Worked example (3 px shake, SHAKE_DECAY=0.7, SHAKE_MIN_THRESHOLD=0.5):
```
Frame 0: 3.000  (triggered)
Frame 1: 3.000 * 0.7 = 2.100
Frame 2: 2.100 * 0.7 = 1.470
Frame 3: 1.470 * 0.7 = 1.029
Frame 4: 1.029 * 0.7 = 0.720
Frame 5: 0.720 * 0.7 = 0.504
Frame 6: 0.504 * 0.7 = 0.353  →  below 0.5 threshold  →  0.0
Total duration: 6 decay frames (100ms @ 60 fps)
```

**Shake Offset Application**

```
var shake_angle: float = randf_range(0.0, TAU)
var shake_offset: Vector2 = Vector2.from_angle(shake_angle) * shake_intensity
shake_offset = Vector2(round(shake_offset.x), round(shake_offset.y))
camera_pos += shake_offset
```

Applied at step 3 in the processing order, before room clamp at step 4. Room clamp absorbs any out-of-bounds shake automatically.

**Freeze Behavior**

```
func set_frozen(frozen: bool) -> void:
    _frozen = frozen

# In _physics_process:
if _frozen:
    return  # skip lerp update, shake decay, and position update
```

When frozen, `shake_intensity` retains its current value. When unfrozen, decay resumes from the held intensity — shake duration is effectively extended by the number of frozen frames.

**Shake Trigger (max-wins rule)**

```
func request_shake(intensity: float) -> void:
    shake_intensity = maxf(shake_intensity, minf(intensity, MAX_SHAKE_INTENSITY))
```

Two shakes triggered in the same frame: the higher intensity wins. The lower-intensity shake is discarded. This prevents earthquake accumulation during rapid-hit combos.

---

## Implementation Notes

This story completes the processing pipeline defined in ADR-0006:

```
_physics_process(delta):
  if _frozen:
      return
  1. Calculate target: player_pos + (smoothed_aim_dir * LOOK_AHEAD_DISTANCE)  [Story 002]
  2. Lerp toward target (with max-distance catch-up)                           [Story 002]
  3. Apply shake offset: camera_pos += random_dir * shake_intensity            [THIS STORY]
  4. Clamp to room bounds                                                       [Story 003]
  5. Pixel snap: Vector2(round(x), round(y))                                   [Story 002]
  6. Decay shake: shake_intensity *= SHAKE_DECAY                               [THIS STORY]
```

The freeze check (`if _frozen: return`) must be at the top, before step 1. This means frozen state also suspends look-ahead smoothing, aim direction updates, and all camera lerping — a full position hold.

Shake is cleared in `set_room_bounds()` to ensure rooms always start with zero shake intensity, preventing shake from a previous room continuing into a new one.

Integration with Combat System: CombatSystem emits `combat_shake_requested(intensity: float)` signal. CameraController connects to this signal in `_ready()` and calls `request_shake()` in response. CameraController does not decide when to shake — it only processes requests.

---

## Out of Scope

- Story 003: Room clamping (prerequisite — shake is clamped via step ordering, not special logic)
- Combat System: deciding when to emit `combat_shake_requested` (separate epic)
- ADR-0007 (Animation): hit-stop freeze coordination — CombatSystem calls `set_frozen()` on the camera; this story implements the camera's side of that contract

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit tests — must pass in GdUnit4
**Test file**: `tests/unit/camera/camera_shake_test.gd`
**Status**: [ ] Not yet created

### QA Test Cases

| ID | Scenario | Input | Expected Output | Pass Condition |
|----|----------|-------|-----------------|----------------|
| TC-SS-001 | Single shake decays to zero | `request_shake(3.0)`, DECAY=0.7, THRESHOLD=0.5 | Zero by frame 7 | `shake_intensity == 0.0` after 7 frames |
| TC-SS-002 | Max intensity cap | `request_shake(20.0)`, `MAX_SHAKE_INTENSITY=6` | `shake_intensity == 6.0` | `shake_intensity == 6.0` |
| TC-SS-003 | Two shakes, higher wins | `request_shake(2.0)` then `request_shake(4.0)` same frame | `shake_intensity == 4.0` | `shake_intensity == 4.0` |
| TC-SS-004 | Two shakes, lower ignored | `request_shake(4.0)` then `request_shake(2.0)` same frame | `shake_intensity == 4.0` | `shake_intensity == 4.0` |
| TC-SS-005 | Freeze pauses decay | `request_shake(3.0)`, `set_frozen(true)`, advance 10 frames | `shake_intensity == 3.0` after 10 frames | `shake_intensity == 3.0` |
| TC-SS-006 | Decay resumes after unfreeze | Continue TC-SS-005, `set_frozen(false)`, advance 7 frames | Decay resumes from 3.0, reaches zero | `shake_intensity == 0.0` after 7 more frames |
| TC-SS-007 | Room transition clears shake | `request_shake(5.0)`, call `set_room_bounds(any_rect)` | `shake_intensity == 0.0` | `shake_intensity == 0.0` |
| TC-SS-008 | Shake offset is integer-valued | Advance one frame with `shake_intensity=3.0` | Shake offset has integer x and y components | `offset.x == round(offset.x)` and `offset.y == round(offset.y)` |
| TC-SS-009 | Freeze holds camera position | Camera at (100, 50), `set_frozen(true)`, player moves to (200, 50) | Camera remains at (100, 50) | `final_pos == Vector2(100, 50)` |

---

## Dependencies

- Depends on: Story 002 (player follow pipeline — shake is step 3 in the same `_physics_process`)
- Depends on: Story 003 (room clamping — shake is absorbed by the clamp in step 4)
- Unlocks: Camera System epic complete. Unblocks Combat System (can now emit shake/freeze signals with a working receiver), Scene Management / Story 002 (transition calls `set_room_bounds` which clears shake)
