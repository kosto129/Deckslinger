# Story 003: GameManager State Machine

> **Epic**: Scene Management
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: N/A (architectural infrastructure)
**Requirement**: Governed by ADR-0003: Scene Management and Room Transitions

**ADR Governing Implementation**: ADR-0003: Scene Management and Room Transitions
**ADR Decision Summary**: GameManager is an autoload that manages the top-level game flow state machine: MENU → RUN → DEATH/VICTORY → MENU. `start_run()` initializes run state and loads the first room. `end_run()` tears down run state. RunStateManager is the single source of truth for persistent run data.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoloads, enum state machines, signal connections via callable — all standard GDScript in Godot 4.6. No post-cutoff API risk.

**Control Manifest Rules (Foundation)**:
- Required: RunStateManager is the single source of truth for run persistence.
- Required: Rooms are disposable — all persistent state lives in RunStateManager.
- Required: Use Callable-based signal connections. Type all signal parameters.
- Required: Signals use past tense for events, present tense for requests.
- Forbidden: Never persist room-specific state across room transitions.

---

## Acceptance Criteria

- [ ] `src/core/game_manager.gd` exists with `class_name GameManager`, registered as autoload "GameManager"
- [ ] `GameState` enum defined: `MENU`, `RUN`, `DEATH`, `VICTORY`
- [ ] Initial state on autoload ready: `MENU`
- [ ] `start_run() -> void` transitions state from `MENU` to `RUN`, initializes RunStateManager, loads first room via SceneManager
- [ ] `end_run(outcome: Enums.RunOutcome) -> void` transitions state from `RUN` to `DEATH` or `VICTORY` based on outcome, then transitions to `MENU`
- [ ] `MENU → RUN` transition: `run_started` signal emitted after state changes and first room is loading
- [ ] `RUN → DEATH` transition: `run_ended(RunOutcome.DEATH)` signal emitted
- [ ] `RUN → VICTORY` transition: `run_ended(RunOutcome.VICTORY)` signal emitted
- [ ] `DEATH/VICTORY → MENU` transition: `returned_to_menu` signal emitted
- [ ] Calling `start_run()` from a state other than `MENU` logs an error and returns without changing state
- [ ] Calling `end_run()` from a state other than `RUN` logs an error and returns without changing state
- [ ] `get_state() -> GameState` query method returns current state
- [ ] All tuning constants (e.g., initial player HP, starting deck ID) are exported or defined in RunStateManager, not hardcoded in GameManager

---

## State Machine

```
MENU ──start_run()──► RUN ──end_run(DEATH)──► DEATH ──(auto)──► MENU
                       │
                       └──end_run(VICTORY)──► VICTORY ──(auto)──► MENU
```

Invalid transitions (e.g., `start_run()` while in `RUN`, `end_run()` while in `MENU`) log an error using `push_error()` and return without modifying state.

---

## Signals

```gdscript
signal run_started()
signal run_ended(outcome: Enums.RunOutcome)
signal returned_to_menu()
```

All parameters are typed. `Enums.RunOutcome` is defined in the shared Enums autoload (Entity Framework / Story 001).

---

## Lifecycle Methods

**`start_run() -> void`**

1. Guard: if `_state != GameState.MENU`, push_error and return.
2. Set `_state = GameState.RUN`.
3. Initialize RunStateManager: reset HP to starting value, set starting deck, reset currency to 0, set floor to 1.
4. Load the first room: call `SceneManager.transition_to_room(first_room_scene, first_spawn_pos)`.
5. Emit `run_started`.

**`end_run(outcome: Enums.RunOutcome) -> void`**

1. Guard: if `_state != GameState.RUN`, push_error and return.
2. Set `_state = GameState.DEATH` or `GameState.VICTORY` based on outcome.
3. Emit `run_ended(outcome)`.
4. Call `_cleanup_run()`.
5. Set `_state = GameState.MENU`.
6. Emit `returned_to_menu`.

**`_cleanup_run() -> void`** (private)

1. Clear any remaining room from RoomContainer (call `SceneManager` cleanup helper or directly queue_free the room child).
2. Reset RunStateManager to default state.
3. Clear any transient combat state (via relevant system signals or direct calls).

---

## Implementation Notes

GameManager does not directly manage UI navigation (show/hide menus, load UI
scenes). It emits signals; UI systems observe those signals and respond. This
keeps GameManager free of UI dependencies.

The first room PackedScene and player spawn position for `start_run()` come from
Dungeon Generation. For MVP (before Dungeon Generation is complete), GameManager
can hard-reference a test room PackedScene via an exported variable:
`@export var first_room_scene: PackedScene`. This exported variable is replaced
by Dungeon Generation integration in a later epic.

`RunStateManager` is a separate autoload responsible for HP, deck, currency, and
floor data. GameManager calls `RunStateManager.initialize_run()` and
`RunStateManager.reset()` — it does not directly set individual fields.

The DEATH and VICTORY states are transient: GameManager passes through them
immediately (in the same call to `end_run`) without awaiting any external event.
The signals emitted during those states give downstream systems (death screen,
victory screen) time to observe the transition. If a future story needs
GameManager to hold in DEATH/VICTORY state (e.g., awaiting player input to
continue), that logic is added then.

---

## Out of Scope

- Story 001: Main.tscn structure (prerequisite)
- Story 002: SceneManager room transitions (called by `start_run()`)
- Dungeon Generation: first room selection and floor layout
- UI epics: death screen, victory screen, main menu — these observe GameManager signals
- RunStateManager: its full implementation is in the Run State epic (uses Enums and basic structure here)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit tests — must pass in GdUnit4
**Test file**: `tests/unit/scene_management/game_manager_test.gd`
**Status**: [ ] Not yet created

### QA Test Cases

| ID | Scenario | Input | Expected Output | Pass Condition |
|----|----------|-------|-----------------|----------------|
| TC-GM-001 | Initial state | GameManager autoload initializes | `get_state() == GameState.MENU` | `get_state() == MENU` |
| TC-GM-002 | start_run from MENU | Call `start_run()` | State becomes `RUN`, `run_started` emitted | `get_state() == RUN` and signal received |
| TC-GM-003 | start_run from RUN (invalid) | Call `start_run()` while in `RUN` | Error logged, state remains `RUN` | `get_state() == RUN`, no `run_started` |
| TC-GM-004 | end_run DEATH outcome | Call `end_run(DEATH)` from `RUN` | `run_ended(DEATH)` emitted, then `returned_to_menu`, state ends at `MENU` | `get_state() == MENU` after call |
| TC-GM-005 | end_run VICTORY outcome | Call `end_run(VICTORY)` from `RUN` | `run_ended(VICTORY)` emitted, then `returned_to_menu`, state ends at `MENU` | `get_state() == MENU` after call |
| TC-GM-006 | end_run from MENU (invalid) | Call `end_run(DEATH)` while in `MENU` | Error logged, state remains `MENU` | `get_state() == MENU`, no `run_ended` |
| TC-GM-007 | RunState initialized on start | Call `start_run()` | RunStateManager has default HP, deck, currency=0, floor=1 | RunStateManager fields match expected defaults |
| TC-GM-008 | RunState cleared on end | Call `start_run()` then `end_run(DEATH)` | RunStateManager reset to defaults | RunStateManager fields reset |

---

## Dependencies

- Depends on: Story 002 (SceneManager — `start_run()` calls `transition_to_room`)
- Depends on: Entity Framework / Story 001 (Enums autoload — `RunOutcome` enum)
- Unlocks: All gameplay epics (require a run to be active to function), UI epics (observe GameManager signals for menu flow)
