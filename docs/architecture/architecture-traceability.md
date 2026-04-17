# Architecture Traceability Index

**Last Updated**: 2026-04-17
**Engine**: Godot 4.6 (GDScript)

## Coverage Summary

- **Total requirements**: 62
- **Covered**: 42 (68%)
- **Partial**: 5 (8%)
- **Gaps**: 15 (24%)
- **Foundation + Core**: 42/42 (100%)
- **Feature + Presentation**: 0/20 fully covered (deferred by design)

## Known Gaps

All gaps are in Feature and Presentation layers — deferred to implementation phase:

| TR-ID | System | Gap | Suggested Resolution |
|-------|--------|-----|---------------------|
| TR-SE-002 | Status Effects | Stacking rules implementation | Resolve in story-level design |
| TR-SE-003 | Status Effects | Per-frame tick processing | Resolve in story-level design |
| TR-EA-003 | Enemy AI | Weighted attack selection | ADR-0010 or story-level |
| TR-EA-004 | Enemy AI | Separation force | Story-level implementation |
| TR-DB-001–003 | Deck Building | Draft pool, size limits, rarity caps | Story-level (follows ADR-0004 data patterns) |
| TR-DG-001–002, 004 | Dungeon Gen | DAG graph, placement rules, seeding | ADR-0011 or story-level |
| TR-RW-001 | Reward | Tiered rewards | Story-level (follows ADR-0004 data patterns) |
| TR-RE-001–002 | Room Encounter | State machine, wave spawning | Story-level |
| TR-RS-003 | Run State | Run seed | Story-level |
| TR-UI-001–004 | Card Hand UI | Layout, animations, indicators, VFX | ADR-0013 or story-level |
