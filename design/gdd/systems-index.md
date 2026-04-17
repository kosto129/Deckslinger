# Systems Index: Deckslinger

> **Status**: Draft
> **Created**: 2026-04-16
> **Last Updated**: 2026-04-16
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Deckslinger is a real-time action roguelike with deckbuilding. The core loop
requires systems that handle committal combat, a use-to-draw card hand, deck
management between encounters, procedural dungeon navigation, and a reward
pipeline that evolves the player's deck each run. The four design pillars
(Every Card Is a Commitment, Your Deck Is Your Identity, Adapt or Die, Earn
Everything) constrain every system: combat must be weighty, the deck must
define playstyle, the hand must always shift, and rewards must be earned.

24 systems span Foundation through Polish layers. 16 are required for the MVP
hypothesis test: "Is the core loop fun?"

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Entity Framework | Core | MVP | Designed | design/gdd/entity-framework.md | None |
| 2 | Input System | Core | MVP | Designed | design/gdd/input-system.md | None |
| 3 | Card Data System | Gameplay | MVP | Designed | design/gdd/card-data-system.md | None |
| 4 | Camera System | Core | MVP | Designed | design/gdd/camera-system.md | None |
| 5 | Animation State Machine | Core | MVP | Designed | design/gdd/animation-state-machine.md | Entity Framework |
| 6 | Collision/Hitbox System | Core | MVP | Designed | design/gdd/collision-hitbox-system.md | Entity Framework |
| 7 | Combat System | Gameplay | MVP | Designed | design/gdd/combat-system.md | Entity Framework, Input, Animation State Machine, Collision/Hitbox |
| 8 | Card Hand System | Gameplay | MVP | Designed | design/gdd/card-hand-system.md | Card Data, Input |
| 9 | Status Effect System | Gameplay | MVP | Designed | design/gdd/status-effect-system.md | Combat, Card Data |
| 10 | Enemy AI System | Gameplay | MVP | Designed | design/gdd/enemy-ai-system.md | Entity Framework, Combat, Animation State Machine |
| 11 | Deck Building System | Gameplay | MVP | Designed | design/gdd/deck-building-system.md | Card Data, Card Hand |
| 12 | Dungeon Generation System | Gameplay | MVP | Designed | design/gdd/dungeon-generation-system.md | Entity Framework |
| 13 | Reward System | Economy | MVP | Designed | design/gdd/reward-system.md | Card Data, Deck Building |
| 14 | Room Encounter System | Gameplay | MVP | Designed | design/gdd/room-encounter-system.md | Dungeon Generation, Combat, Enemy AI, Reward |
| 15 | Run State Manager | Persistence | MVP | Designed | design/gdd/run-state-manager.md | Deck Building, Dungeon Generation |
| 16 | Card Hand UI | UI | MVP | Designed | design/gdd/card-hand-ui.md | Card Hand System |
| 17 | Boss System | Gameplay | Vertical Slice | Not Started | — | Enemy AI, Combat, Animation State Machine |
| 18 | Combat HUD | UI | Vertical Slice | Not Started | — | Combat, Run State Manager |
| 19 | Reward Screen UI | UI | Vertical Slice | Not Started | — | Reward System, Deck Building |
| 20 | Dungeon Map UI | UI | Vertical Slice | Not Started | — | Dungeon Generation, Run State Manager |
| 21 | Menu System | UI | Alpha | Not Started | — | Run State Manager |
| 22 | Audio Manager | Audio | Alpha | Not Started | — | Combat, Card Hand, Animation State Machine |
| 23 | Save/Load System | Persistence | Full Vision | Not Started | — | Run State Manager, Card Data |
| 24 | Meta-Progression System | Progression | Full Vision | Not Started | — | Save/Load, Card Data, Run State Manager |

---

## Categories

| Category | Description |
|----------|-------------|
| **Core** | Foundation systems everything depends on |
| **Gameplay** | Systems that make the game fun — combat, cards, enemies, dungeons |
| **Economy** | Resource creation and consumption — rewards, loot tables |
| **Persistence** | Save state and run continuity |
| **UI** | Player-facing information and interaction |
| **Audio** | Sound and music systems |
| **Progression** | How the player grows across runs |

---

## Priority Tiers

| Tier | Definition | Target | Systems |
|------|------------|--------|---------|
| **MVP** | Required for core loop hypothesis test: "Is the core loop fun?" | 3-4 weeks | 16 systems |
| **Vertical Slice** | Complete floor experience with boss and full UI | 6-8 weeks | 4 systems |
| **Alpha** | All features present, placeholder content OK | 3-4 months | 2 systems |
| **Full Vision** | Polish, meta-progression, persistence | 6-9 months | 2 systems |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Entity Framework** — base object model for player, enemies, projectiles
2. **Input System** — KB/M + gamepad handling, action mapping, input buffering
3. **Card Data System** — data-driven card definitions as Godot Resources
4. **Camera System** — integer-pixel snapping, room framing, viewport management

### Core Layer (depends on Foundation)

5. **Animation State Machine** — depends on: Entity Framework
   Commitment animation states (idle→windup→active→recovery), hit-stop, frame holds
6. **Collision/Hitbox System** — depends on: Entity Framework
   Per-frame hitbox/hurtbox detection for committal combat
7. **Combat System** — depends on: Entity Framework, Input, Animation State Machine, Collision
   Damage calculation, health, death, the mechanical weight of every action
8. **Card Hand System** — depends on: Card Data, Input
   Use-to-draw cycling, hand management, card play execution

### Feature Layer (depends on Core)

9. **Status Effect System** — depends on: Combat, Card Data
   Buffs, debuffs, DoT, stun, bind. Enables card synergies.
10. **Enemy AI System** — depends on: Entity Framework, Combat, Animation State Machine
    Behavior patterns, telegraphed attacks, threat tiers (melee/ranged/elite)
11. **Deck Building System** — depends on: Card Data, Card Hand
    Card drafting, removal (trimming), upgrades between encounters
12. **Dungeon Generation System** — depends on: Entity Framework
    Procedural floor layout from hand-crafted room pool, branching paths
13. **Reward System** — depends on: Card Data, Deck Building
    Loot tables, card draft options, rarity weighting, currency
14. **Room Encounter System** — depends on: Dungeon Generation, Combat, Enemy AI, Reward
    Encounter setup, enemy spawning, room clearing, reward triggers
15. **Run State Manager** — depends on: Deck Building, Dungeon Generation
    Current run tracking: deck, floor progress, HP, currency
16. **Boss System** — depends on: Enemy AI, Combat, Animation State Machine
    Multi-phase encounters, tell limbs, phase transitions

### Presentation Layer (depends on Features)

17. **Card Hand UI** — depends on: Card Hand System
    Card arc, hover magnification, play/draw animations, archetype glow
18. **Combat HUD** — depends on: Combat, Run State Manager
    HP corner bracket, deck/discard count, damage numbers, status icons
19. **Reward Screen UI** — depends on: Reward System, Deck Building
    Card draft presentation, hover-shifts-temperature, deck trim interface
20. **Dungeon Map UI** — depends on: Dungeon Generation, Run State Manager
    Room/path selection visual interface
21. **Menu System** — depends on: Run State Manager
    Main menu, pause, death screen, run-end stats

### Polish Layer

22. **Audio Manager** — depends on: Combat, Card Hand, Animation State Machine
    SFX for card abilities, music per floor, hit-stop audio sync
23. **Save/Load System** — depends on: Run State Manager, Card Data
    Mid-run persistence, settings, meta-progression state
24. **Meta-Progression System** — depends on: Save/Load, Card Data, Run State Manager
    Persistent unlocks, card pool expansion, character unlocks

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | Entity Framework | MVP | Foundation | S |
| 2 | Input System | MVP | Foundation | S |
| 3 | Card Data System | MVP | Foundation | M |
| 4 | Camera System | MVP | Foundation | S |
| 5 | Animation State Machine | MVP | Core | M |
| 6 | Collision/Hitbox System | MVP | Core | M |
| 7 | Combat System | MVP | Core | L |
| 8 | Card Hand System | MVP | Core | L |
| 9 | Status Effect System | MVP | Feature | M |
| 10 | Enemy AI System | MVP | Feature | M |
| 11 | Deck Building System | MVP | Feature | M |
| 12 | Dungeon Generation System | MVP | Feature | M |
| 13 | Reward System | MVP | Feature | S |
| 14 | Room Encounter System | MVP | Feature | M |
| 15 | Run State Manager | MVP | Feature | S |
| 16 | Card Hand UI | MVP | Presentation | M |
| 17 | Boss System | VS | Feature | M |
| 18 | Combat HUD | VS | Presentation | S |
| 19 | Reward Screen UI | VS | Presentation | S |
| 20 | Dungeon Map UI | VS | Presentation | S |
| 21 | Menu System | Alpha | Presentation | S |
| 22 | Audio Manager | Alpha | Polish | M |
| 23 | Save/Load System | FV | Polish | M |
| 24 | Meta-Progression System | FV | Polish | M |

Effort: S = 1 session, M = 2-3 sessions, L = 4+ sessions

---

## Circular Dependencies

None found. All dependency chains are one-directional.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Card Hand System | Design | Can use-to-draw feel fluid in weighty real-time combat? The #1 design risk. Hand size (3 vs 4) unknown. | Prototype first alongside Combat System. Test both hand sizes. |
| Combat System | Design + Technical | Commitment-based combat needs precise animation timing and feel tuning. Art-dependent. | Prototype alongside Card Hand. Iterate on feel before locking GDD. |
| Card Data System | Scope | 25 cards with interactions can produce degenerate combos. Data architecture must be extensible from day one. | Design data schema carefully. Start with 10 simple cards, expand. Balance is iterative. |
| Status Effect System | Design | Effect stacking, interaction rules, and card synergies create combinatorial complexity. | Keep MVP to 3-4 effect types. Expand post-MVP. Define stacking rules early. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 24 |
| Design docs started | 16 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 16/16 |
| Vertical Slice systems designed | 0/4 |

---

## Next Steps

- [ ] Design MVP Foundation systems first (Entity Framework, Input, Card Data, Camera)
- [ ] Run `/design-system [system-name]` for each system in design order
- [ ] Run `/design-review` on each completed GDD
- [ ] Prototype Card Hand + Combat together early (highest risk)
- [ ] Run `/review-all-gdds` when all MVP GDDs are complete
- [ ] Run `/gate-check pre-production` when MVP systems are designed
