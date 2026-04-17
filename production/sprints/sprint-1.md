# Sprint 1 — Foundation Layer

**Start Date**: 2026-04-17
**End Date**: 2026-05-01 (2 weeks)
**Sprint Goal**: Build all Foundation infrastructure so Core layer implementation can begin in Sprint 2.

## Capacity

- Total days: 10 (2 weeks, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

## Tasks

### Must Have (Critical Path)

| ID | Task | Epic | Est. Days | Dependencies | Type |
|----|------|------|-----------|-------------|------|
| 1-1 | Shared Enums Autoload | entity-framework | 0.5 | None | Config/Data |
| 1-2 | EntityBase Lifecycle State Machine | entity-framework | 1.0 | 1-1 | Logic |
| 1-3 | Component Scripts (8 stubs) | entity-framework | 1.0 | 1-1, 1-2 | Logic |
| 2-1 | Action Map Configuration | input-system | 0.5 | 1-1 | Config/Data |
| 2-2 | Input Buffer | input-system | 1.0 | 2-1 | Logic |
| 3-1 | CardData + CardEffect Resources | card-data-system | 1.0 | 1-1 | Logic |
| 3-2 | CardRegistry Autoload | card-data-system | 1.0 | 3-1 | Logic |
| 4-1 | Viewport Setup (Project Settings) | camera-system | 0.25 | None | Config/Data |
| 5-1 | Main.tscn Scene Structure | scene-management | 0.5 | 1-2, 1-3 | Integration |
| 5-2 | Room Transitions (SceneManager) | scene-management | 1.0 | 5-1, 4-1 | Integration |

**Must Have total: 7.75 days** (within 8-day capacity)

### Should Have

| ID | Task | Epic | Est. Days | Dependencies | Type |
|----|------|------|-----------|-------------|------|
| 1-4 | Entity Scene Templates | entity-framework | 0.5 | 1-2, 1-3 | Integration |
| 2-3 | Movement Vector + Aim Direction | input-system | 1.0 | 2-1, 2-2 | Logic |
| 3-3 | Starter Card .tres Files (10 cards) | card-data-system | 0.5 | 3-2 | Config/Data |
| 4-2 | Player Follow + Look-Ahead | camera-system | 1.0 | 4-1, 5-1 | Logic |
| 4-3 | Room Clamping | camera-system | 0.5 | 4-2 | Logic |
| 5-3 | Game Manager State Machine | scene-management | 0.5 | 5-2 | Logic |

**Should Have total: 4.0 days** (overflow into buffer if Must Have finishes on time)

### Nice to Have

| ID | Task | Epic | Est. Days | Dependencies | Type |
|----|------|------|-----------|-------------|------|
| 1-5 | Lifecycle Edge Cases | entity-framework | 1.0 | 1-2, 1-3 | Logic |
| 2-4 | Device Detection + Mode Switching | input-system | 0.5 | 2-1, 2-2, 2-3 | Integration |
| 3-4 | Description Variable Substitution | card-data-system | 0.5 | 3-2 | Logic |
| 4-4 | Shake + Freeze | camera-system | 0.5 | 4-2 | Logic |

**Nice to Have total: 2.5 days**

## Implementation Order (Critical Path)

```
Day 1:   1-1 Enums (0.5d) → 4-1 Viewport (0.25d) → 2-1 Action Map (0.5d)
Day 2:   1-2 EntityBase Lifecycle (1.0d)
Day 3:   1-3 Component Scripts (1.0d)
Day 4:   3-1 CardData Resources (1.0d)
Day 5:   2-2 Input Buffer (1.0d)
Day 6:   3-2 CardRegistry (1.0d)
Day 7:   5-1 Main Scene (0.5d) → 5-2 Room Transitions (start)
Day 8:   5-2 Room Transitions (finish, 1.0d total)
Day 9-10: Should Have stories (buffer permitting)
```

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| GdUnit4 setup takes longer than expected | Medium | Low | Example test already exists; framework is well-documented |
| Input buffer tuning feels wrong at 8 frames | Low | Medium | Tuning knob — adjust after playtesting in Sprint 2 |
| Room transition causes signal cleanup errors | Medium | Medium | Use is_instance_valid() guards per ADR-0003 |

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and merged
- [ ] All Logic stories have passing unit tests in `tests/unit/`
- [ ] Smoke check: game launches, entities can be instantiated, input responds
- [ ] No errors in Godot output log during basic operation
- [ ] Code reviewed
- [ ] Ready for Core layer implementation in Sprint 2

> **No QA Plan**: Sprint 1 is infrastructure-only (no player-facing features). A formal QA plan
> will be created for Sprint 2 when gameplay systems are implemented. Run `/qa-plan sprint`
> before Sprint 2 begins.
