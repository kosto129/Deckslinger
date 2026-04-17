# Story 003: Room Clamping

> **Epic**: Camera System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-CM-003` (Room boundary clamping)

**ADR Governing Implementation**: ADR-0006: Viewport and Camera Pipeline
**ADR Decision Summary**: After follow + look-ahead, clamp the camera center so the viewport never reveals area outside room bounds. Small rooms (≤ 384×216) lock camera to room center. Room bounds are provided via `set_room_bounds(bounds: Rect2)` called by SceneManager on each room transition.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Rect2`, `Vector2.clamp()`, and `clampf()` are standard and unchanged. No post-cutoff API risk.

**Control Manifest Rules (Foundation)**:
- Required: Camera position must be rounded to integer pixels after ALL calculations (follow + look-ahead + shake + clamp).
- Required: Room transitions use fade-to-black. Camera snaps to new room bounds on transition (no lerp across rooms).
- Forbidden: Never render at fractional pixel scale.

---

## Acceptance Criteria

- [ ] `set_room_bounds(bounds: Rect2) -> void` is callable on CameraController
- [ ] Camera x is clamped: `clampf(cam_x, room_left + 192, room_right - 192)`
- [ ] Camera y is clamped: `clampf(cam_y, room_top + 108, room_bottom - 108)`
- [ ] Clamping is applied after follow lerp and look-ahead, before pixel snap
- [ ] Room with width ≤ 384 or height ≤ 216 locks camera to room center on that axis — no tracking or look-ahead effect on the locked axis
- [ ] Room exactly 384×216: camera locked to room center (192, 108) — no movement regardless of player position
- [ ] `snap_to_target() -> void` instantly repositions camera to clamped player position (no lerp) — called by SceneManager on room entry

---

## Formulas

**F.4 — Room Bound Clamping**

```
clamped_x = clampf(cam_x, room_left + HALF_VP_W, room_right - HALF_VP_W)
clamped_y = clampf(cam_y, room_top  + HALF_VP_H, room_bottom - HALF_VP_H)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `cam_x` | float | unbounded (pixels) | Desired camera center x after follow + look-ahead |
| `cam_y` | float | unbounded (pixels) | Desired camera center y after follow + look-ahead |
| `room_left` | float | pixels | Left edge of room bounding box (Rect2.position.x) |
| `room_right` | float | pixels | Right edge: `room_left + room_width` |
| `room_top` | float | pixels | Top edge of room bounding box (Rect2.position.y) |
| `room_bottom` | float | pixels | Bottom edge: `room_top + room_height` |
| `HALF_VP_W` | int | 192 (constant) | Half viewport width — half of 384 px |
| `HALF_VP_H` | int | 108 (constant) | Half viewport height — half of 216 px |
| `clamped_x` | float | `[room_left+192, room_right-192]` | Camera center x guaranteed within bounds |
| `clamped_y` | float | `[room_top+108, room_bottom-108]` | Camera center y guaranteed within bounds |

Output range: Always within `[room_edge + HALF_VP, room_opposite_edge - HALF_VP]` on each axis. If the room is exactly one viewport wide on an axis, min == max and the camera is locked to that coordinate.

Worked example (768×216 room, player at x=100):
```
room_left=0, room_right=768
clampf(100, 0+192, 768-192) = clampf(100, 192, 576) = 192
Camera pushed to x=192 so viewport left edge aligns with room left edge.
```

Worked example (384×216 room — one screen):
```
room_left=0, room_right=384
clampf(any_value, 0+192, 384-192) = clampf(any_value, 192, 192) = 192
Camera x is always 192. Locked to center.
```

**Small room detection:**

```
var room_is_small_x: bool = room_bounds.size.x <= VIEWPORT_W  # <= 384
var room_is_small_y: bool = room_bounds.size.y <= VIEWPORT_H  # <= 216
```

When `room_is_small_x` is true, the clamp formula reduces to a constant on x. The same clamp formula handles this naturally — no special branching required. Look-ahead suppression is emergent behavior: with clamp min == clamp max, look-ahead is absorbed into zero-effect territory. However, explicitly document this in code comments so maintainers do not add redundant guards.

---

## Implementation Notes

`set_room_bounds(bounds: Rect2)` stores the Rect2 and is called by SceneManager during `transition_to_room()` before `snap_to_target()`.

`snap_to_target()` bypasses the lerp for one frame: sets `camera_pos` directly to the player-centered, clamped, pixel-snapped position. Sets the look-ahead delay counter to `LOOK_AHEAD_DELAY`. Called by SceneManager after player is repositioned and before fade-in.

Clamping step sits at position 4 in the processing order defined in ADR-0006:
```
1. Calculate target: player_pos + (smoothed_aim_dir * LOOK_AHEAD_DISTANCE)
2. Lerp toward target
3. Apply shake offset [Story 004]
4. Clamp to room bounds  ← this story
5. Pixel snap
6. Decay shake [Story 004]
```

The shake offset (step 3) is applied before clamping (step 4), which means shake is also clamped to room bounds. This is intentional per GDD rule SS.3.

---

## Out of Scope

- Story 002: Player follow lerp (prerequisite — clamping extends that pipeline)
- Story 004: Shake clamp behavior is automatic because shake is applied before this clamp step
- Scene Management epic: `transition_to_room()` orchestration lives in SceneManager (story-002-room-transitions.md)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit tests — must pass in GdUnit4
**Test file**: `tests/unit/camera/camera_clamping_test.gd`
**Status**: [ ] Not yet created

### QA Test Cases

| ID | Scenario | Input | Expected Output | Pass Condition |
|----|----------|-------|-----------------|----------------|
| TC-RC-001 | Player at left edge of wide room | Room: 768×216, `cam_x=50` | `clamped_x == 192` | `final_pos.x == 192` |
| TC-RC-002 | Player at right edge of wide room | Room: 768×216, `cam_x=700` | `clamped_x == 576` | `final_pos.x == 576` |
| TC-RC-003 | Player in center of wide room | Room: 768×216, `cam_x=384` | `clamped_x == 384` (no clamp) | `final_pos.x == 384` |
| TC-RC-004 | One-screen room x-axis | Room: 384×216, any `cam_x` | `clamped_x == 192` always | `final_pos.x == 192` |
| TC-RC-005 | One-screen room y-axis | Room: 384×216, any `cam_y` | `clamped_y == 108` always | `final_pos.y == 108` |
| TC-RC-006 | Tall room clamping | Room: 384×432, `cam_y=50` | `clamped_y == 108` | `final_pos.y == 108` |
| TC-RC-007 | Look-ahead at room edge | Room: 768×216, player at x=10, aim right, look-ahead=24 | Target x=34, clamped to 192 | `final_pos.x == 192` |
| TC-RC-008 | snap_to_target repositions instantly | Player at (300, 200), new room 768×432 | `final_pos == Vector2(300, 200)` (clamped, snapped) | No lerp frames — instant |

---

## Dependencies

- Depends on: Story 002 (player follow pipeline — clamping is inserted into the same `_physics_process` chain)
- Depends on: Scene Management / Story 001 (Main.tscn must exist before set_room_bounds is called in integration)
- Unlocks: Story 004 (shake clamp is automatic once this step exists), Scene Management / Story 002 (transition calls `set_room_bounds` and `snap_to_target`)
