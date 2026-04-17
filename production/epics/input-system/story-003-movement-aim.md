# Story 003: Movement Vector and Aim Direction

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/input-system.md`
**Requirements**: `TR-IN-003` (8-directional movement with diagonal normalization), `TR-IN-004` (Gamepad dead zone remapping)

**ADR Governing Implementation**: ADR-0005: Input Buffering and Action Map
**ADR Decision Summary**: `get_movement_vector()` returns a normalized Vector2 for movement. `get_aim_direction()` returns world-space aim from mouse position (KB/M) or right stick after dead zone remap (gamepad). Dead zone remap follows formula F.1. Aim is snapped to 8 directions for animation selection. All methods are query-only — they read instantaneous state, they do not buffer.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (SDL3 gamepad backend; verify `Input.get_vector()` axis mappings with new backend)
**Engine Notes**: `Input.get_vector(negative_x, positive_x, negative_y, positive_y)` returns a Vector2 from four named actions. This is the correct API for both left stick movement and right stick aim in Godot 4.x. `get_viewport().get_mouse_position()` returns screen-space coordinates — convert to world space via `get_viewport().get_canvas_transform().affine_inverse()` or equivalent if the camera is offset. Verify this works correctly with Godot 4.6 viewport transform after the pixel-snap rules in ADR-0006.

**Control Manifest Rules (Foundation)**:
- Required: Camera position must be rounded to integer pixels (ADR-0006) — mouse-to-world conversion must account for this
- Required: Use `StringName` (`&"action_name"`) for action names in hot paths — source: ADR-0005
- Required: `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` are enabled — world-space mouse position may need rounding — source: ADR-0006
- Forbidden: Never use real-time (seconds) for gameplay timing — source: ADR-0005

---

## Acceptance Criteria

- [ ] `get_movement_vector() -> Vector2` returns a Vector2 with `length() <= 1.0` in all cases
- [ ] KB/M diagonal input (e.g. W+D held) returns a vector of length exactly 1.0, not 1.414
- [ ] Gamepad left stick within inner dead zone returns `Vector2.ZERO`
- [ ] Gamepad left stick at raw magnitude 0.55 with `INNER_DEAD_ZONE = 0.15` and `OUTER_DEAD_ZONE = 0.95` returns remapped magnitude 0.50 (per formula F.1)
- [ ] `get_aim_direction() -> Vector2` returns a normalised Vector2 pointing from player toward mouse (KB/M mode)
- [ ] `get_aim_direction()` returns current facing direction when right stick is inside dead zone (gamepad mode)
- [ ] `get_aim_angle() -> float` returns the angle in radians corresponding to `get_aim_direction()`
- [ ] `get_snapped_aim_index() -> int` returns an integer 0–7 (N=0, NE=1, E=2, SE=3, S=4, SW=5, W=6, NW=7) using formula F.4
- [ ] `get_facing_direction() -> Vector2` returns the last known non-zero facing direction; defaults to `Vector2.RIGHT` before any input
- [ ] KB/M mode: WASD keys are binary (0 or 1 per axis); no analog contribution from keyboard
- [ ] Gamepad mode: left stick magnitude is preserved after dead zone remap (partial deflection produces partial speed)
- [ ] All constants (`INNER_DEAD_ZONE`, `OUTER_DEAD_ZONE`, `AIM_SNAP_DIRECTIONS`) are exported or named constants — no magic numbers

---

## Formulas

### F.1 — Gamepad Dead Zone Remap (from GDD)

**Named expression:**

```
if raw < INNER_DEAD_ZONE:
    magnitude = 0.0
elif raw > OUTER_DEAD_ZONE:
    magnitude = 1.0
else:
    magnitude = (raw - INNER_DEAD_ZONE) / (OUTER_DEAD_ZONE - INNER_DEAD_ZONE)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `raw` | float | 0.0 – 1.0 | Raw stick magnitude from `Input.get_vector().length()` |
| `INNER_DEAD_ZONE` | float | 0.05 – 0.30 | Stick magnitude below this treated as zero (default: 0.15) |
| `OUTER_DEAD_ZONE` | float | 0.85 – 1.00 | Stick magnitude above this treated as 1.0 (default: 0.95) |
| `magnitude` | float | 0.0 – 1.0 | Remapped magnitude, clamped to [0, 1] |

**Output range**: 0.0 to 1.0, clamped. Values below inner dead zone return exactly 0.0 (eliminates stick drift). Values above outer dead zone return exactly 1.0 (full deflection is reachable).

**Worked example**:
- `raw = 0.55`, `INNER_DEAD_ZONE = 0.15`, `OUTER_DEAD_ZONE = 0.95`
- `magnitude = (0.55 - 0.15) / (0.95 - 0.15) = 0.40 / 0.80 = 0.50`

---

### F.2 — Movement Vector Normalization (from GDD)

**Named expression:**

```
raw_vector = Vector2(input_x, input_y)
if raw_vector.length() > 1.0:
    move_dir = raw_vector.normalized()
else:
    move_dir = raw_vector
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `input_x` | float | -1.0 – 1.0 | Horizontal axis value (-1 left, +1 right) |
| `input_y` | float | -1.0 – 1.0 | Vertical axis value (-1 up, +1 down) |
| `raw_vector` | Vector2 | length 0.0 – 1.414 | Raw combined input vector before normalization |
| `move_dir` | Vector2 | length 0.0 – 1.0 | Output movement direction, never exceeds length 1.0 |

**Output range**: Vector2 with length in [0, 1]. KB/M diagonal inputs produce length exactly 1.0 after normalization. Gamepad partial inputs produce length < 1.0 (analog speed preserved).

**Worked examples**:
- KB/M diagonal: `input_x = 1`, `input_y = -1` → `raw_vector = (1, -1)`, length 1.414 → `move_dir = (0.707, -0.707)`, length 1.0
- Gamepad partial: `input_x = 0.3`, `input_y = 0.0` → `raw_vector = (0.3, 0.0)`, length 0.3 → `move_dir = (0.3, 0.0)` (no normalization)

---

### F.4 — Aim Direction 8-Way Snap (from GDD)

**Named expression:**

```
aim_angle = atan2(target_y - player_y, target_x - player_x)
SNAP_SIZE  = PI / 4  (= 0.7854 radians = 45 degrees)
snapped_index = int(round(aim_angle / SNAP_SIZE)) % 8
snapped_angle = snapped_index * SNAP_SIZE
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `aim_angle` | float | -PI – PI | Raw aim angle in radians from `atan2()` |
| `SNAP_SIZE` | float | fixed: PI/4 | Angular size of each snap sector in radians |
| `snapped_index` | int | 0 – 7 | Nearest direction index (0=E, 2=N, 4=W, 6=S — see note) |
| `snapped_angle` | float | 0 – 2*PI | Snapped angle in radians for direction vector reconstruction |

**Output range**: `snapped_index` is always 0–7 (modulo 8 guarantees this). Negative `aim_angle` values handled correctly by `round()` before modulo.

**Worked example** (mouse slightly above-right of player):
- `aim_angle = 0.35 radians` (~20 degrees east of right)
- `snapped_index = round(0.35 / 0.785) % 8 = round(0.446) % 8 = 0`
- Result: direction index 0 (East)

> **Index mapping note**: The index mapping depends on the coordinate convention. In Godot 2D, Y increases downward. Document the index-to-direction table explicitly in code as a constant to avoid silent bugs: `const SNAP_DIRECTIONS: Array[Vector2] = [Vector2.RIGHT, ...]`.

---

## Implementation Notes

These methods are added to the `InputManager` autoload (created in Story 002). They are stateless queries — they read from `Input` singleton and `_active_device` each call.

### `get_movement_vector()`

1. Read left stick via `Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")` with deadzone set to 0.0 (InputMap deadzone must be 0 — dead zone is applied manually below).
2. For KEYBOARD_MOUSE device: the result is already binary (-1, 0, or 1 per axis). Apply normalization formula F.2.
3. For GAMEPAD device: apply dead zone remap (F.1) to the vector's magnitude, preserving direction. Then apply normalization F.2 (redundant for gamepad since magnitude <= 1.0 after remap, but harmless and keeps code consistent).
4. If `_input_mode == Enums.InputMode.UI`, return `Vector2.ZERO`.

### `get_aim_direction()`

1. For KEYBOARD_MOUSE: obtain mouse screen position via `get_viewport().get_mouse_position()`. Convert to world space. Compute direction from player's world position to mouse world position. Normalize. Store as `_last_aim_direction`.
2. For GAMEPAD: read right stick via `Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")` with deadzone 0.0. Apply dead zone remap (F.1) to magnitude. If remapped magnitude < 0.01, return `get_facing_direction()` (stick at rest fallback). Otherwise normalize and store as `_last_aim_direction`.
3. Return `_last_aim_direction`.

### `get_facing_direction()`

Facing direction is updated whenever a non-zero movement or aim input is received. Defaults to `Vector2.RIGHT`. Never returns `Vector2.ZERO`.

### `_apply_dead_zone(stick: Vector2) -> Vector2`

Private helper. Computes raw magnitude, applies F.1, reconstructs the vector:
```gdscript
func _apply_dead_zone(stick: Vector2) -> Vector2:
    var raw: float = stick.length()
    if raw < INNER_DEAD_ZONE:
        return Vector2.ZERO
    elif raw > OUTER_DEAD_ZONE:
        return stick.normalized()
    var remapped: float = (raw - INNER_DEAD_ZONE) / (OUTER_DEAD_ZONE - INNER_DEAD_ZONE)
    return stick.normalized() * remapped
```

---

## Out of Scope

- Story 002: Buffer logic (prerequisite — InputManager scaffold must exist)
- Story 004: Device detection and `_active_device` tracking (the branch on `_active_device` in `get_aim_direction()` depends on Story 004 setting this field correctly; for Story 003 it can default to KEYBOARD_MOUSE)
- Aim cursor / visual indicator for gamepad (Presentation layer — future story)
- Runtime dead zone configuration UI (settings menu — future story)

---

## QA Test Cases

### TC-MOV-001: KB/M diagonal normalized to length 1.0

**Given** KEYBOARD_MOUSE device mode
**When** `move_right` and `move_up` are both held (W+D equivalent)
**Then** `get_movement_vector().length()` is approximately 1.0 (within float epsilon)

---

### TC-MOV-002: Gamepad stick below inner dead zone returns zero

**Given** GAMEPAD device mode and `INNER_DEAD_ZONE = 0.15`
**When** left stick raw magnitude is 0.10
**Then** `get_movement_vector()` returns `Vector2.ZERO`

---

### TC-MOV-003: Dead zone remap formula produces correct output

**Given** GAMEPAD device mode, `INNER_DEAD_ZONE = 0.15`, `OUTER_DEAD_ZONE = 0.95`
**When** `_apply_dead_zone()` is called with a stick vector of magnitude 0.55
**Then** the returned vector has magnitude 0.50 (within float epsilon)

---

### TC-MOV-004: Gamepad partial stick preserves analog magnitude

**Given** GAMEPAD device mode and raw stick magnitude 0.60
**When** `get_movement_vector()` is read
**Then** the returned vector length is between 0.0 and 1.0 exclusive, not snapped to 0 or 1

---

### TC-AIM-001: KB/M aim points toward mouse

**Given** KEYBOARD_MOUSE device and player at world position (100, 100)
**When** mouse world position is (200, 100) (directly right)
**And** `get_aim_direction()` is called
**Then** the returned vector is approximately `Vector2.RIGHT` (1.0, 0.0)

---

### TC-AIM-002: Gamepad aim falls back to facing direction at rest

**Given** GAMEPAD device and right stick raw magnitude < INNER_DEAD_ZONE
**When** `get_aim_direction()` is called
**Then** the returned value equals `get_facing_direction()`

---

### TC-AIM-003: 8-way snap produces correct index

**Given** aim angle of 0.35 radians (~20 degrees)
**When** `get_snapped_aim_index()` is called
**Then** the result is 0 (East direction)

---

### TC-AIM-004: UI mode returns zero movement

**Given** input mode is `Enums.InputMode.UI`
**When** `get_movement_vector()` is called
**Then** the result is `Vector2.ZERO` regardless of held keys

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit tests (GdUnit4) — BLOCKING gate
**Location**: `tests/unit/input/movement_aim_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (action map — action names must exist), Story 002 (InputManager autoload scaffold and `_active_device` field)
- Unlocks: Story 004 (device-detection — completes InputManager public API)
