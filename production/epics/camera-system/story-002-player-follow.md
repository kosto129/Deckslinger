# Story 002: Player Follow

> **Epic**: Camera System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-CM-002` (Exponential follow with pixel snapping)

**ADR Governing Implementation**: ADR-0006: Viewport and Camera Pipeline
**ADR Decision Summary**: CameraController on a Camera2D node lerps toward the player each physics frame using exponential interpolation. Look-ahead offsets the target in the smoothed aim direction. All position calculations end with integer pixel snap via `Vector2(round(x), round(y))`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Camera2D, lerp, and Vector2.round() are unchanged in Godot 4.6. Physics processing via `_physics_process(delta)` is standard.

**Control Manifest Rules (Foundation)**:
- Required: Camera position must be rounded to integer pixels after ALL calculations (follow + look-ahead + shake + clamp). Use `Vector2(round(x), round(y))`.
- Required: All gameplay timers count physics frames, not real-time seconds.
- Required: Buffer, animation, and camera timers freeze during hit-stop (`_frozen` flag).
- Forbidden: Never render at fractional pixel scale.

---

## Acceptance Criteria

- [ ] `src/foundation/camera_controller.gd` exists with `class_name CameraController`
- [ ] Script attaches to a `Camera2D` node in the scene
- [ ] Camera follows player using exponential lerp: `lerp(camera_pos, target_pos, FOLLOW_WEIGHT)` per physics frame
- [ ] If camera lags more than `MAX_FOLLOW_DISTANCE` pixels from target, it snaps to within that distance immediately
- [ ] Look-ahead offsets target by `aim_direction * LOOK_AHEAD_DISTANCE` using smoothed aim direction
- [ ] Look-ahead is suppressed for `LOOK_AHEAD_DELAY` frames after room entry or player teleport
- [ ] After all calculations, final position is always integer-valued: `Vector2(round(x), round(y))`
- [ ] Camera holds position (no lerp, no look-ahead update) when `_frozen` is `true`
- [ ] All tuning constants are named exports, not inline magic numbers

---

## Formulas

**F.1 — Camera Follow (Exponential Interpolation)**

```
new_camera_pos = camera_pos.lerp(target_pos, 1.0 - pow(1.0 - FOLLOW_WEIGHT, delta * 60.0))
```

Simplified at fixed 60 fps:
```
new_camera_pos = camera_pos + (target_pos - camera_pos) * FOLLOW_WEIGHT
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `camera_pos` | Vector2 | unbounded (pixels) | Current camera center position before this frame's update |
| `target_pos` | Vector2 | unbounded (pixels) | Desired position: `player_pos + (aim_dir * LOOK_AHEAD_DISTANCE)` |
| `FOLLOW_WEIGHT` | float | 0.03–0.20 | Lerp weight per physics frame. Default: 0.08 |
| `delta` | float | ~0.0167 at 60 fps | Physics frame delta time |
| `new_camera_pos` | Vector2 | unbounded (pixels) | Updated camera position before pixel snap |

Output range: Unbounded before clamping. Converges on `target_pos` over ~30 frames at default weight.

Worked example:
```
camera_pos = (100, 50), target_pos = (120, 50), FOLLOW_WEIGHT = 0.08
new_x = 100 + (120 - 100) * 0.08 = 101.6  →  pixel snap → 102
Frame 2: 102 + (120 - 102) * 0.08 = 103.44  →  pixel snap → 103
Camera reaches 120 in approximately 30 frames (0.5s at 60 fps)
```

**F.2 — Look-Ahead Target Offset**

```
target_pos = player_pos + (smoothed_aim_dir * LOOK_AHEAD_DISTANCE)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `player_pos` | Vector2 | room bounds (pixels) | Current player world position |
| `smoothed_aim_dir` | Vector2 | normalized, length 0–1 | Aim direction smoothed via separate lerp to prevent camera jerk |
| `LOOK_AHEAD_DISTANCE` | float | 0–48 px | Offset distance in pixels. Default: 24 px (1.5 tiles) |
| `target_pos` | Vector2 | unbounded (pixels) | Camera follow target before clamping |

Aim direction smoothing:
```
smoothed_aim_dir = smoothed_aim_dir.lerp(raw_aim_dir, LOOK_AHEAD_SMOOTH)
```
Default `LOOK_AHEAD_SMOOTH` = 0.12.

**F.3 — Max Follow Distance Catch-Up**

```
if camera_pos.distance_to(target_pos) > MAX_FOLLOW_DISTANCE:
    camera_pos = target_pos + (camera_pos - target_pos).normalized() * MAX_FOLLOW_DISTANCE
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `MAX_FOLLOW_DISTANCE` | float | 24–96 px | Maximum lag distance before snap. Default: 48 px (3 tiles) |

**F.4 — Pixel Snap (Final Step)**

```
final_pos = Vector2(round(camera_pos.x), round(camera_pos.y))
```

Applied after follow lerp, look-ahead offset, and (in story 003) room clamping. Applied before (in story 004) shake offset. See ADR-0006 processing order.

---

## Implementation Notes

Processing order per `_physics_process(delta)` (full sequence — implement incrementally across stories):

```
1. Calculate target: player_pos + (smoothed_aim_dir * LOOK_AHEAD_DISTANCE)
2. Lerp toward target (with max-distance catch-up)
3. Apply shake offset [Story 004]
4. Clamp to room bounds [Story 003]
5. Pixel snap: Vector2(round(x), round(y))
6. Decay shake [Story 004]
```

This story implements steps 1, 2, and 5. Steps 3, 4, and 6 are stubs returning unmodified values until their stories are complete.

Look-ahead is suppressed by a frame counter initialized to `LOOK_AHEAD_DELAY` on room entry or teleport detection. Counter decrements each physics frame; when it reaches zero, look-ahead re-enables.

Teleport detection: if `player_pos` delta from previous frame exceeds `MAX_FOLLOW_DISTANCE`, treat as teleport — snap camera immediately and reset look-ahead delay counter.

The `set_frozen(frozen: bool)` public method sets the `_frozen` flag. When frozen, `_physics_process` returns immediately without updating any camera state.

---

## Out of Scope

- Story 001: Viewport Project Settings (prerequisite)
- Story 003: Room boundary clamping (clamp step is a stub in this story)
- Story 004: Screen shake and hit-freeze (shake offset and decay are stubs)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit tests — must pass in GdUnit4
**Test file**: `tests/unit/camera/camera_follow_test.gd`
**Status**: [ ] Not yet created

### QA Test Cases

| ID | Scenario | Input | Expected Output | Pass Condition |
|----|----------|-------|-----------------|----------------|
| TC-CF-001 | Lerp convergence | `camera_pos=(100,50)`, `target_pos=(120,50)`, `FOLLOW_WEIGHT=0.08` | After 1 frame: x rounds to 102 | `final_pos.x == 102` |
| TC-CF-002 | Pixel snap enforced | Any calculation producing x=101.6, y=49.3 | `Vector2(102, 49)` | `final_pos == Vector2(102, 49)` |
| TC-CF-003 | Max distance catch-up | Camera at (0,0), target at (200,0), `MAX_FOLLOW_DISTANCE=48` | Camera snaps to (152, 0) immediately | `camera_pos.x == 152` |
| TC-CF-004 | Freeze holds position | `camera_pos=(100,50)`, `set_frozen(true)`, player moves to (200,50) | Camera stays at (100,50) | `final_pos == Vector2(100, 50)` |
| TC-CF-005 | Look-ahead offset | `player_pos=(100,50)`, `aim_dir=(1,0)`, `LOOK_AHEAD_DISTANCE=24` | `target_pos.x == 124` | `target_pos.x == 124` |
| TC-CF-006 | Look-ahead suppressed on entry | Look-ahead delay = 15, frame 1 after room entry | Look-ahead offset is zero | `target_pos == player_pos` |
| TC-CF-007 | Look-ahead activates after delay | Frame 16 after room entry | Look-ahead offset applied normally | `target_pos != player_pos` when aim != zero |
| TC-CF-008 | No overshoot | Camera lerping toward target over 60 frames | Camera never passes target position | `abs(camera_pos.x - target_pos.x)` monotonically decreasing |

---

## Dependencies

- Depends on: Story 001 (viewport must be configured before camera testing is meaningful)
- Unlocks: Story 003 (room clamping requires camera follow to be in place), Story 004 (shake/freeze extend the same `_physics_process` pipeline)
