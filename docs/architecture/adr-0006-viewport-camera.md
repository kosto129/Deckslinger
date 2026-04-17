# ADR-0006: Viewport and Camera Pipeline

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering |
| **Knowledge Risk** | LOW — Camera2D, SubViewport, 2D rendering pipeline unchanged |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None for 2D camera. Glow-before-tonemapping change (4.6) does not affect 2D pixel art. |
| **Verification Required** | Verify `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` still work as expected in 4.6 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Scene Management — camera persists across rooms, room bounds provided) |
| **Enables** | None directly — camera is consumed by all visual systems |
| **Blocks** | Any visual gameplay testing |
| **Ordering Note** | Should be implemented early for visual debugging of all other systems |

## Context

### Problem Statement
Deckslinger is a pixel art game at 384×216 native resolution. Pixel art requires integer-scaled rendering to avoid shimmer, sub-pixel artifacts, and blurry sprites. The camera must follow the player smoothly, look ahead in the aim direction, clamp to room boundaries, support screen shake for combat feel, and freeze during hit-stop — all while maintaining pixel-perfect output.

## Decision

**Render to a 384×216 SubViewport with integer scaling. A CameraController script on a Camera2D node handles follow, look-ahead, shake, room clamping, and pixel snapping.**

### Viewport Setup (Project Settings)

```
display/window/size/viewport_width = 384
display/window/size/viewport_height = 216
display/window/stretch/mode = "canvas_items"
display/window/stretch/aspect = "keep"
rendering/2d/snap/snap_2d_transforms_to_pixel = true
rendering/2d/snap/snap_2d_vertices_to_pixel = true
```

### Camera Processing Order

```
_physics_process(delta):
  1. Calculate target position: player_pos + (aim_dir * LOOK_AHEAD_DISTANCE)
  2. Lerp toward target: camera_pos = lerp(camera_pos, target, FOLLOW_WEIGHT)
  3. Apply shake offset: camera_pos += random_dir * shake_intensity
  4. Clamp to room bounds: clamp(camera_pos, bounds_min, bounds_max)
  5. Pixel snap: camera_pos = Vector2(round(x), round(y))
  6. Decay shake: shake_intensity *= SHAKE_DECAY
```

### Shake API

```gdscript
# Called by CombatSystem via signal
func request_shake(intensity: float) -> void:
    shake_intensity = maxf(shake_intensity, min(intensity, MAX_SHAKE_INTENSITY))

# Called by CombatSystem for hit-freeze
func set_frozen(frozen: bool) -> void:
    _frozen = frozen  # skips lerp and shake decay while frozen
```

## Alternatives Considered

### Alternative 1: Viewport Scaling Without SubViewport
- **Description**: Render at display resolution, manually scale sprites
- **Rejection Reason**: Sub-pixel rendering inevitable. Pixel art looks blurry or shimmery.

### Alternative 2: Smooth Camera Without Pixel Snap
- **Description**: Camera moves at sub-pixel precision for smoother feel
- **Rejection Reason**: Causes pixel crawl/shimmer on all sprites. Pixel-perfect is non-negotiable for the art style.

## Consequences

### Positive
- Pixel-perfect rendering guaranteed by engine-level snapping
- Camera feel is tunable via 10 knobs (all defined in Camera GDD)
- Shake and freeze integrate cleanly with combat feel

### Negative
- Camera movement is slightly "chunky" due to integer snapping — acceptable for pixel art aesthetic
- Letterboxing on non-16:9 displays

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| camera-system.md | V.1 — Native Resolution | 384×216 viewport with canvas_items stretch |
| camera-system.md | V.2 — Integer Scaling | Snap settings + keep aspect = integer scale with letterbox |
| camera-system.md | T.1–T.3 — Player Tracking | Lerp follow + look-ahead + pixel snap |
| camera-system.md | RC.1 — Room Bounds | Clamp after all position calculations |
| camera-system.md | SS.1–SS.3 — Screen Shake | Shake with decay, max intensity cap, integer-snapped offset |
| camera-system.md | HF.1 — Frame Pause | set_frozen() holds camera position during hit-stop |

## Performance Implications
- **CPU**: One lerp + clamp + snap per frame. <0.01ms.
- **Memory**: Negligible.
- **Rendering**: 384×216 pixel viewport is trivially small. GPU-bound scenarios impossible.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. At 1080p: viewport renders at 5× scale with zero letterbox
2. At 1440p: viewport renders at 6× scale with centered letterbox bars
3. All sprites remain pixel-aligned during camera movement (no shimmer)
4. Screen shake does not reveal area outside room bounds
5. Camera position after all calculations is always integer-valued

## Related Decisions
- ADR-0003: Scene Management (room bounds provided on transition)
- ADR-0007: Animation (hit-stop freezes camera)
