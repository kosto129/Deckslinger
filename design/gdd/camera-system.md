# Camera System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (Every Card Is a Commitment), Pillar 3 (Adapt or Die)

## Summary

The Camera System manages viewport rendering, player tracking, room framing,
screen shake, and pixel-perfect display for a 2D pixel art action game at
384x216 native resolution. It ensures every frame is sharp, responsive, and
readable during fast combat.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

The Camera System controls what the player sees and how the game world is
presented on screen. It operates at 384x216 native resolution (24:1 tiles
wide × 13.5 tiles tall at 16x16), integer-scaled to the display resolution
to prevent sub-pixel artifacts. The camera tracks the player with smoothed
interpolation, looks ahead in the aim direction to give combat awareness,
clamps to room boundaries so the player never sees outside the playable area,
and provides screen shake and hit-freeze camera effects that reinforce the
weight of committal combat. Room transitions use hard cuts (no scrolling) to
maintain the room-based dungeon structure's clarity. The system is purely
presentational — it never affects gameplay logic, collision, or entity
positions.

## Player Fantasy

The camera is invisible when it works. The player feels like they can always
see what matters — the enemies ahead, the space behind them for retreat, the
card they're about to play. During a heavy hit, the screen shakes with
authority and then settles. During a boss encounter in an oversized room, the
camera pulls back just enough to show the threat without losing the player.
The camera earns trust: the player is never killed by something they couldn't
see, and never disoriented by erratic movement.

## Detailed Rules

### Viewport Configuration

**V.1 — Native Resolution**

| Property | Value | Rationale |
|----------|-------|-----------|
| Native resolution | 384×216 px | 16:9 aspect, fits 24×13.5 tiles at 16px. Clean integer scaling to 1080p (5x), 1440p (6.67x — needs handling), 4K (10x). |
| Stretch mode | `canvas_items` | Godot's 2D scaling mode. Renders at native, stretches to window. |
| Stretch aspect | `keep` | Letterbox if window aspect doesn't match. No distortion. |
| Snap 2D transforms | `true` | Forces all 2D rendering to integer pixel positions. Prevents shimmer. |
| Snap 2D vertices | `true` | Ensures sprite vertices land on pixel boundaries. |

**V.2 — Integer Scaling**

The viewport is displayed at the largest integer multiple that fits the
display resolution:

```
scale_factor = floor(min(display_width / 384, display_height / 216))
```

| Display | Scale | Rendered Size | Letterbox |
|---------|-------|---------------|-----------|
| 1920×1080 | 5x | 1920×1080 | None |
| 2560×1440 | 6x | 2304×1296 | 128px horizontal, 72px vertical |
| 3840×2160 | 10x | 3840×2160 | None |
| 1280×720 | 3x | 1152×648 | 64px horizontal, 36px vertical |

Non-integer remainders are filled with black letterbox bars. The game never
renders at a fractional scale.

**V.3 — Sub-Viewport Architecture**

The game renders to a `SubViewport` at 384×216. A `TextureRect` or
`SubViewportContainer` in the main viewport displays the result at integer
scale. UI elements that need crisp text at high resolution (damage numbers,
card text) render in a separate overlay viewport at display resolution, not
at native resolution.

### Player Tracking

**T.1 — Smoothed Follow**

The camera follows the player using exponential interpolation (lerp) each
physics frame. This creates smooth motion without overshoot.

```
camera_pos = lerp(camera_pos, target_pos, FOLLOW_WEIGHT)
```

`FOLLOW_WEIGHT` controls responsiveness. Higher = snappier, lower = more
drift. The camera never falls more than `MAX_FOLLOW_DISTANCE` pixels behind
the player — if it does, it snaps to within that radius.

**T.2 — Look-Ahead**

The camera target is offset from the player position in the aim direction,
giving the player visibility in the direction they're facing/attacking.

```
target_pos = player_pos + (aim_direction * LOOK_AHEAD_DISTANCE)
```

Look-ahead uses the smoothed aim direction (not raw), to prevent the camera
from jerking when the player flicks their mouse. Aim direction smoothing uses
a separate, faster lerp weight than camera follow.

**T.3 — Pixel Snapping**

After all position calculations (follow + look-ahead + shake), the final
camera position is rounded to integer pixel coordinates:

```
final_pos = Vector2(round(camera_pos.x), round(camera_pos.y))
```

This prevents sub-pixel jitter in the rendered output. All sprites snap to
integer positions through Godot's snap settings, and the camera must do the
same.

### Room Clamping

**RC.1 — Room Bounds**

Each room defines a bounding rectangle. The camera clamps so that the viewport
never shows area outside the room bounds.

```
clamped_x = clamp(camera_x, room_left + half_viewport_w, room_right - half_viewport_w)
clamped_y = clamp(camera_y, room_top + half_viewport_h, room_bottom - half_viewport_h)
```

Where `half_viewport_w = 192` and `half_viewport_h = 108` (half of 384×216).

**RC.2 — Small Rooms**

If a room is smaller than or equal to the viewport size (384×216 or less),
the camera locks to the room center. No tracking, no look-ahead. The entire
room is visible at once.

Standard room size: 384×216 (1 screen). Rooms can be multiples: 768×216
(2 screens wide), 384×432 (2 screens tall), etc.

**RC.3 — Boss Rooms**

Boss rooms are larger than standard (typically 2-3 screens). The camera tracks
the player normally within the room bounds. No special zoom-out behavior —
the player sees one screen's worth of the boss arena at a time, maintaining
pixel scale consistency. Boss visual design must account for this (bosses must
telegraph from within one screen's distance).

### Room Transitions

**RT.1 — Hard Cut**

When the player moves to a new room, the camera performs a hard cut:

1. Screen fades to black over `TRANSITION_FADE_OUT` frames
2. New room is loaded / player is repositioned
3. Camera snaps to new room's initial position (player-centered, clamped)
4. Screen fades from black over `TRANSITION_FADE_IN` frames

No scrolling transitions. Hard cuts reinforce the room-based structure and
prevent the player from seeing between rooms. Total transition time:
`TRANSITION_FADE_OUT + TRANSITION_FADE_IN` frames.

**RT.2 — Initial Camera Position**

On room entry, the camera starts centered on the player's spawn point, clamped
to room bounds. Look-ahead is suppressed for `LOOK_AHEAD_DELAY` frames after
room entry to prevent the camera from immediately pulling away from the
player's starting position.

### Screen Shake

**SS.1 — Shake Model**

Screen shake offsets the camera position by a random vector that decays over
time. Shake is applied after follow/look-ahead calculation but before pixel
snapping.

```
shake_offset = random_direction * shake_intensity
camera_pos = camera_pos + shake_offset
```

Shake intensity decays each frame:
```
shake_intensity = shake_intensity * SHAKE_DECAY
if shake_intensity < SHAKE_MIN_THRESHOLD:
    shake_intensity = 0.0
```

**SS.2 — Shake Triggers**

Shake is triggered by gameplay events via signal. The Camera System does not
decide when to shake — it receives requests.

| Event | Intensity (px) | Duration Approx |
|-------|----------------|-----------------|
| Player hit | 3 | 6 frames |
| Enemy killed | 2 | 4 frames |
| Card ability impact | 1–4 (per card data) | 3–8 frames |
| Boss phase transition | 5 | 10 frames |
| Dodge near-miss (juice) | 1 | 2 frames |

If a new shake is triggered while one is active, use the higher intensity
(don't stack additively — prevents earthquake effects from rapid hits).

**SS.3 — Shake and Pixel Integrity**

Shake offset is rounded to integer pixels before application. Maximum shake
intensity is capped at `MAX_SHAKE_INTENSITY` to prevent the camera from
showing outside room bounds. If shake would push the camera outside room
bounds, clamp the shaken position to room bounds.

### Hit Freeze (Camera Component)

**HF.1 — Frame Pause**

On significant combat impacts, the game pauses for a few frames (hit-stop).
This is owned by the Combat System, but the Camera System must:

- Hold its current position during the freeze (no lerp updates)
- Resume smoothly from the held position when freeze ends
- Not count freeze frames toward buffer expiry or shake decay

## Formulas

**F.1 — Camera Follow (Exponential Interpolation)**

```
Variables:
  camera_pos    = current camera position (Vector2, pixels)
  target_pos    = desired position (player_pos + look_ahead offset)
  FOLLOW_WEIGHT = interpolation weight per physics frame (default: 0.08)
  delta         = physics frame delta (1/60 at 60fps)

Output:
  new_camera_pos = updated camera position

Formula:
  new_camera_pos = camera_pos.lerp(target_pos, 1.0 - pow(1.0 - FOLLOW_WEIGHT, delta * 60.0))

Simplified at fixed 60fps:
  new_camera_pos = camera_pos + (target_pos - camera_pos) * FOLLOW_WEIGHT

Example:
  camera_pos = (100, 50), target_pos = (120, 50), FOLLOW_WEIGHT = 0.08
  new_camera_pos.x = 100 + (120 - 100) * 0.08 = 100 + 1.6 = 101.6
  After pixel snap: (102, 50)
  Next frame: 102 + (120 - 102) * 0.08 = 102 + 1.44 → (103, 50)
  Camera converges on target over ~30 frames (0.5s)
```

**F.2 — Shake Decay**

```
Variables:
  shake_intensity   = current shake magnitude (pixels)
  SHAKE_DECAY       = decay multiplier per frame (default: 0.7)
  SHAKE_MIN_THRESHOLD = below this, snap to zero (default: 0.5)

Output:
  new_intensity = updated shake magnitude

Formula:
  new_intensity = shake_intensity * SHAKE_DECAY
  if new_intensity < SHAKE_MIN_THRESHOLD:
      new_intensity = 0.0

Example (3px shake):
  Frame 0: 3.0
  Frame 1: 3.0 * 0.7 = 2.1
  Frame 2: 2.1 * 0.7 = 1.47
  Frame 3: 1.47 * 0.7 = 1.029
  Frame 4: 1.029 * 0.7 = 0.72
  Frame 5: 0.72 * 0.7 = 0.504
  Frame 6: 0.504 * 0.7 = 0.353 → below threshold → 0.0
  Total duration: 6 frames (100ms @ 60fps)
```

**F.3 — Integer Scale Factor**

```
Variables:
  display_w = display/window width in pixels
  display_h = display/window height in pixels
  native_w  = 384
  native_h  = 216

Output:
  scale = integer scale factor

Formula:
  scale = floor(min(display_w / native_w, display_h / native_h))
  scale = max(scale, 1)  # minimum 1x

Example (1440p):
  floor(min(2560/384, 1440/216)) = floor(min(6.67, 6.67)) = 6
  Rendered: 384*6 = 2304 x 216*6 = 1296
  Letterbox: (2560-2304)/2 = 128px each side, (1440-1296)/2 = 72px top/bottom
```

**F.4 — Room Bound Clamping**

```
Variables:
  cam_x, cam_y    = desired camera center position
  room_left       = room bounding box left edge (px)
  room_right      = room bounding box right edge (px)
  room_top        = room bounding box top edge (px)
  room_bottom     = room bounding box bottom edge (px)
  HALF_VP_W       = 192 (half viewport width)
  HALF_VP_H       = 108 (half viewport height)

Output:
  clamped_x, clamped_y = camera center position within bounds

Formula:
  clamped_x = clamp(cam_x, room_left + HALF_VP_W, room_right - HALF_VP_W)
  clamped_y = clamp(cam_y, room_top + HALF_VP_H, room_bottom - HALF_VP_H)

Example (768x216 room, player at x=100):
  room_left = 0, room_right = 768
  clamp(100, 0 + 192, 768 - 192) = clamp(100, 192, 576) = 192
  Camera pushed right so viewport doesn't show past room left edge.
```

## Edge Cases

- **Room exactly 384×216 (one screen)**: Camera locks to room center
  (192, 108). No tracking, no look-ahead, no shake-induced room peek.
  Shake is still applied but clamped to room bounds (effectively no
  visible shake movement if room = viewport).

- **Player at room corner with look-ahead pushing camera out of bounds**:
  Room clamping overrides look-ahead. Player still sees look-ahead effect
  until hitting the boundary, then camera holds at the boundary. No jarring
  snap — the lerp naturally settles at the clamped position.

- **Screen shake during room transition fade**: Shake is cleared when room
  transition begins. New room starts with zero shake. Prevents visual
  discontinuity.

- **Hit freeze occurs mid-shake**: Shake decay pauses during hit freeze
  frames. When freeze ends, shake resumes decaying from where it was. This
  preserves shake duration regardless of freeze timing.

- **Window resize during gameplay**: Integer scale factor is recalculated.
  Viewport remains 384×216 — only the display scale changes. Letterbox bars
  adjust. No gameplay impact.

- **Look-ahead with zero aim direction** (game start, before first input):
  Look-ahead offset is zero. Camera centers on player. Once aim direction is
  established (first mouse move or stick deflection), look-ahead activates.

- **Player teleports (spawn, debug, room warp)**: Camera detects position
  delta exceeding `MAX_FOLLOW_DISTANCE` and snaps to the new position
  immediately (no slow lerp from old position). Look-ahead is suppressed
  for `LOOK_AHEAD_DELAY` frames.

- **Two shakes triggered in the same frame**: Higher intensity wins (per
  SS.2). They do not add. The higher-intensity shake's direction is used.

- **Boss larger than viewport**: Boss is designed so that combat-relevant
  parts (hitboxes, attack origins, telegraphs) are within one screen of the
  player. The camera does not zoom out to show the full boss — pixel scale
  consistency is more important. Boss extremities may be off-screen; this is
  acceptable and intended (creates sense of scale).

- **Extremely fast player movement (dash)**: `MAX_FOLLOW_DISTANCE` catch-up
  prevents the camera from lagging behind. During a fast dash, the camera
  moves faster than normal lerp would allow, maintaining the player within
  the center area of the screen.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Input System | `get_aim_direction()` for look-ahead offset | Soft |
| Upstream | Combat System | `screen_shake_requested(intensity)` signal | Soft |
| Upstream | Combat System | `hit_freeze_started` / `hit_freeze_ended` signals | Soft |
| Upstream | Dungeon Generation | Room bounds rectangle for clamping | Hard |
| Upstream | Entity Framework | Player entity position for tracking | Hard |
| Upstream | Room Encounter System | Room transition trigger for camera cut | Soft |

The Camera System is a consumer of data — it reads positions and responds to
signals. No other system depends on the Camera System for gameplay logic. UI
overlay viewport positioning is the only downstream consumer.

Public API:

```gdscript
# Shake (called by combat events or card effects)
func request_shake(intensity: float) -> void

# Room management (called by dungeon/room systems)
func set_room_bounds(bounds: Rect2) -> void
func transition_to_room(new_bounds: Rect2, player_spawn: Vector2) -> void

# Freeze support (called by combat system)
func set_frozen(frozen: bool) -> void

# State queries
func get_viewport_rect() -> Rect2  # world-space rectangle visible on screen
func is_transitioning() -> bool
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `FOLLOW_WEIGHT` | 0.08 | 0.03–0.20 | Camera tracking speed. Low = floaty/cinematic. High = snappy/responsive. 0.08 balances smooth feel with combat readability. |
| `LOOK_AHEAD_DISTANCE` | 24 px (1.5 tiles) | 0–48 px | How far ahead the camera looks. Too high = player at edge of screen. Too low = no benefit. |
| `LOOK_AHEAD_SMOOTH` | 0.12 | 0.05–0.25 | Smoothing for aim direction changes to prevent camera jerk. |
| `LOOK_AHEAD_DELAY` | 15 frames (0.25s) | 0–30 frames | Frames after room entry before look-ahead activates. Prevents camera pulling away from spawn. |
| `MAX_FOLLOW_DISTANCE` | 48 px (3 tiles) | 24–96 px | If camera is further than this from target, snap closer. Prevents lag during fast movement. |
| `SHAKE_DECAY` | 0.7 | 0.5–0.9 | Per-frame shake decay. Low = shake dies fast. High = shake lingers. 0.7 gives punchy-but-brief feel. |
| `SHAKE_MIN_THRESHOLD` | 0.5 px | 0.1–1.0 | Below this intensity, shake snaps to zero. Prevents long sub-pixel vibrations. |
| `MAX_SHAKE_INTENSITY` | 6 px | 3–12 px | Hard cap on shake magnitude. Prevents camera from showing outside room. |
| `TRANSITION_FADE_OUT` | 8 frames (~133ms) | 4–15 frames | Fade to black duration. |
| `TRANSITION_FADE_IN` | 10 frames (~167ms) | 4–15 frames | Fade from black duration. Slightly longer than out for a "reveal" feel. |

## Acceptance Criteria

1. **GIVEN** a 1920×1080 display, **WHEN** game launches, **THEN** viewport
   renders at 384×216 scaled 5x with zero letterbox.

2. **GIVEN** a 2560×1440 display, **WHEN** game launches, **THEN** viewport
   renders at 384×216 scaled 6x with centered letterbox bars.

3. **GIVEN** player moving right in a multi-screen room, **WHEN** camera
   follows, **THEN** camera converges on player position smoothly without
   overshoot and all sprites remain pixel-aligned.

4. **GIVEN** player aiming right, **WHEN** look-ahead is active, **THEN**
   camera target is offset 24px right of player position, clamped to room
   bounds.

5. **GIVEN** a room exactly 384×216, **WHEN** player moves within the room,
   **THEN** camera remains locked to room center (192, 108), no tracking.

6. **GIVEN** player at the left edge of a 768×216 room, **WHEN** camera
   calculates position, **THEN** camera x is clamped to 192 (room_left +
   half viewport width).

7. **GIVEN** a 3px screen shake triggered, **WHEN** 6 frames pass with
   `SHAKE_DECAY = 0.7`, **THEN** shake intensity reaches below threshold
   and snaps to zero.

8. **GIVEN** two shakes triggered in the same frame (intensity 2 and 4),
   **WHEN** shake is applied, **THEN** intensity is 4 (max, not additive).

9. **GIVEN** room transition triggered, **WHEN** player enters new room,
   **THEN** screen fades to black, camera snaps to new position, screen
   fades in. No frame shows outside either room.

10. **GIVEN** hit freeze active, **WHEN** camera position is updated, **THEN**
    camera holds position (no lerp), shake decay pauses.

11. **GIVEN** player dashes quickly, **WHEN** camera lags beyond
    `MAX_FOLLOW_DISTANCE`, **THEN** camera snaps to within that distance
    immediately.

12. **GIVEN** screen shake active near room edge, **WHEN** shake offset would
    push camera outside room bounds, **THEN** camera is clamped to room bounds.
