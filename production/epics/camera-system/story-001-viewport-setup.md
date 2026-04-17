# Story 001: Viewport Setup

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-CM-001` (384×216 SubViewport with integer scaling)

**ADR Governing Implementation**: ADR-0006: Viewport and Camera Pipeline
**ADR Decision Summary**: Render to 384×216 with `canvas_items` stretch mode, `keep` aspect ratio, and engine-level pixel snapping enabled in Project Settings. Integer scale with letterbox on non-16:9 displays.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` are verified present in Godot 4.6. Glow-before-tonemapping change (4.6) does not affect 2D pixel art. Confirm both snap settings behave as expected after first in-engine test.

**Control Manifest Rules (Foundation)**:
- Required: Render to 384×216 with `canvas_items` stretch mode and `keep` aspect. Enable `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` in Project Settings.
- Forbidden: Never render at fractional pixel scale — integer scaling only, letterbox the remainder.

---

## Acceptance Criteria

- [x] `display/window/size/viewport_width` = 384 in `project.godot`
- [x] `display/window/size/viewport_height` = 216 in `project.godot`
- [x] `display/window/stretch/mode` = `"canvas_items"` in `project.godot`
- [x] `display/window/stretch/aspect` = `"keep"` in `project.godot`
- [x] `rendering/2d/snap/snap_2d_transforms_to_pixel` = `true` in `project.godot`
- [x] `rendering/2d/snap/snap_2d_vertices_to_pixel` = `true` in `project.godot`
- [ ] At 1920×1080: game renders at 384×216 scaled 5× with zero letterbox bars
- [ ] At 2560×1440: game renders at 384×216 scaled 6× with 128px horizontal and 72px vertical black letterbox bars
- [ ] All sprites remain pixel-aligned — no sub-pixel shimmer visible on static scene

---

## Implementation Notes

All six settings are configured directly in `project.godot` under the appropriate
section headers. No code changes are required for this story — this is a pure
Project Settings configuration task.

Integer scale formula (for reference, not implemented in code here):

```
scale_factor = floor(min(display_width / 384, display_height / 216))
scale_factor = max(scale_factor, 1)  # minimum 1x
```

| Display     | Scale | Rendered Size | Letterbox               |
|-------------|-------|---------------|-------------------------|
| 1920×1080   | 5x    | 1920×1080     | None                    |
| 2560×1440   | 6x    | 2304×1296     | 128px H / 72px V        |
| 3840×2160   | 10x   | 3840×2160     | None                    |
| 1280×720    | 3x    | 1152×648      | 64px H / 36px V         |

After configuring settings, open Godot with the project, run a placeholder scene,
and verify rendering at each relevant resolution.

---

## Out of Scope

- Story 002: CameraController script (player follow, look-ahead, pixel snap)
- Story 003: Room boundary clamping logic
- Story 004: Screen shake and hit-freeze

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check — game renders at correct resolution with integer scaling
**Status**: [x] Settings configured in project.godot — visual verification requires in-engine test

Manual verification steps:
1. Launch game at 1920×1080 — confirm 5× scale, no letterbox.
2. Launch game at 2560×1440 — confirm 6× scale, centered black bars.
3. Place a 16×16 pixel sprite in a test scene, run game, confirm zero shimmer during movement.

---

## Dependencies

- Depends on: None (first camera story — pure Project Settings)
- Unlocks: Story 002 (player follow requires viewport to be configured first)
