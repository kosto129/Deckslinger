# Cross-GDD Review Report

**Date**: 2026-04-16
**GDDs Reviewed**: 16 (all MVP systems)
**Systems Covered**: Entity Framework, Input System, Card Data System, Camera System, Animation State Machine, Collision/Hitbox System, Combat System, Card Hand System, Status Effect System, Enemy AI System, Deck Building System, Dungeon Generation System, Reward System, Room Encounter System, Run State Manager, Card Hand UI

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **C-01: Card Data missing `active_frames` field**
- `animation-state-machine.md`: Expects `CardData.active_frames` — API is `play_action(animation_key, windup, active, recovery)`
- `card-data-system.md`: Schema defines `windup_frames` and `recovery_frames` but NO `active_frames` field
- `animation-state-machine.md` line 101 even acknowledges this: "CardData.active_frames (inferred from animation)" — but "inferred" is undefined. No system provides this value.
- **Impact**: Animation State Machine cannot construct the 3-phase action sequence from CardData alone. The ACTIVE phase duration is unspecified.
- **Resolution**: Add `active_frames` (int) to CardData schema with default range 2–12 frames. Update commitment budget formula F.3 in card-data-system.md to include it.

🔴 **C-02: Camera System dependency directions inverted**
- `camera-system.md`: Lists "Upstream: None" and all data sources as "Downstream (reads/listens)"
- Camera reads FROM Input System, listens TO Combat System, reads FROM Entity Framework and Dungeon Generation
- The description text confirms: "The Camera System is a consumer of data — it reads positions and responds to signals"
- All "Downstream" entries should be labeled "Upstream" — Camera depends on these systems, not the other way around
- **Impact**: Dependency graph is wrong for Camera. Any tooling or architecture that reads the dependency table will miscategorize Camera as a root system.
- **Resolution**: Flip all "Downstream (reads/listens)" rows to "Upstream" in camera-system.md. Remove "Upstream: None" row.

### Warnings (should resolve, but won't block)

⚠️ **C-03: `PLAYER_MAX_HP` dual ownership**
- `combat-system.md` Tuning Knobs: `PLAYER_MAX_HP = 100` (60–200)
- `run-state-manager.md` Tuning Knobs: `PLAYER_MAX_HP = 100` (60–200, "Shared with Combat System")
- Run State Manager acknowledges the sharing, but two systems both defining the same tuning knob creates ambiguity about which is authoritative.
- **Resolution**: Remove from one. Recommended: Combat System owns it (combat is the domain where HP matters), Run State Manager reads it.

⚠️ **C-04: `MIN_DECK_SIZE` / `MAX_DECK_SIZE` dual ownership**
- `card-data-system.md` Tuning Knobs: `MIN_DECK_SIZE = 6`, `MAX_DECK_SIZE = 30`
- `deck-building-system.md` Tuning Knobs: `MIN_DECK_SIZE = 6`, `MAX_DECK_SIZE = 30`
- `card-hand-system.md` references "MIN_DECK_SIZE from Card Data System"
- `run-state-manager.md` references "MIN_DECK_SIZE enforcement in Deck Building System"
- Two downstream systems attribute ownership to different sources.
- **Resolution**: Single owner. Recommended: Deck Building System owns it (deck modification is its domain). Card Data System references it.

⚠️ **C-05: `DRAFT_CHOICES` dual ownership**
- `deck-building-system.md` Tuning Knobs: `DRAFT_CHOICES = 3`
- `reward-system.md` Tuning Knobs: `DRAFT_CHOICES = 3` ("Shared with Deck Building System")
- **Resolution**: Deck Building owns it. Reward System references it.

⚠️ **C-06: `STARTER_DECK_SIZE` inconsistency with game concept**
- `game-concept.md`: "First run uses a curated starter deck (5-6 simple cards)"
- `card-data-system.md`: STARTER_DECK_SIZE = 8, starter deck has 8 cards per archetype
- `deck-building-system.md`: STARTER_DECK_SIZE = 8
- The game concept's "5-6" is a stale pre-design estimate. Card Data's 8 is the designed value.
- **Resolution**: Update game-concept.md onboarding section to match the designed value of 8.

⚠️ **C-07: Animation State Machine does not list Card Data as upstream dependency**
- `card-data-system.md`: Lists Animation State Machine as downstream ("reads animation_key")
- `animation-state-machine.md`: Does not list Card Data System in its dependency table
- Card Data provides `animation_key`, `windup_frames`, and (missing) `active_frames` to Animation — this is an upstream dependency for Animation.
- **Resolution**: Add Card Data System as upstream (Soft) dependency in animation-state-machine.md.

⚠️ **C-08: `REST_HEAL_PERCENT` vs `FLOOR_HEAL_PERCENT` naming confusion**
- `dungeon-generation-system.md`: Defines `REST_HEAL_PERCENT = 0.30` (heal at rest rooms)
- `combat-system.md`: Defines `FLOOR_HEAL_PERCENT = 0.30` (heal between floors)
- `run-state-manager.md`: References both, correctly distinguishing them
- These are intentionally different (rest rooms vs floor transitions) but both default to 0.30 and have similar names, risking confusion during implementation.
- **Resolution**: No change required, but implementers should note these are distinct knobs owned by different systems.

⚠️ **C-09: `STARTER_DECK_SIZE` owned by both Card Data and Deck Building**
- `card-data-system.md` Tuning Knobs: `STARTER_DECK_SIZE = 8`
- `deck-building-system.md` Tuning Knobs: `STARTER_DECK_SIZE = 8`
- Same dual-ownership pattern as C-04.
- **Resolution**: Card Data System owns it (card content domain). Deck Building references it.

---

## Game Design Issues

### Warnings

⚠️ **D-01: Currency has no sinks in MVP**
- Sources: Combat rooms (10), Elite rooms (×2), Boss rooms (×3), per-floor bonus (+5)
- Sinks: Shop (placeholder in MVP), Trim cost (free in MVP), Upgrade cost (free in MVP)
- By the end of a Floor 1 run (~8 rooms): player accumulates ~120+ currency with nothing to spend it on.
- This is explicitly acknowledged as MVP scope (shop is future), but currency accumulation with no outlet may confuse playtesters.
- **Recommendation**: Either defer currency tracking to post-MVP, or add a minimal sink (e.g., reroll draft choices for 10 currency) to give the resource meaning during MVP testing.

⚠️ **D-02: Minimum deck trimming may be a dominant strategy**
- `MIN_DECK_SIZE = 6` with `HAND_SIZE = 4` means the player sees 66% of their deck in the opening hand
- A 6-card deck cycles every 2 card plays — extreme consistency
- Combined with rarity limits (3 Rare + 1 Legendary in 6 cards = 66% high-rarity), this could be overwhelmingly powerful
- Pillar 3 (Adapt or Die) pushes against this IF enemy variety is sufficient, but the current 3 standard + 2 elite enemy types may not provide enough variety to punish narrow decks
- **Recommendation**: Monitor during prototyping. If minimum decks dominate, options include: raise MIN_DECK_SIZE to 8, add floor-specific card requirements, or introduce enemy resistances that punish mono-archetype decks.

⚠️ **D-03: Compounding difficulty scaling across floors**
- Enemy count: linear (+0.5/floor) — Floor 3 = 4 enemies per room
- Enemy HP: linear (+15%/floor) — Floor 3 = 1.3× HP
- Combined effect: Floor 3 rooms have ~73% more total enemy HP than Floor 1
- Player deck improvement is non-linear (depends on draft luck and trim decisions)
- The curves are reasonable individually but compound multiplicatively
- **Recommendation**: Playtest the Floor 2-3 transition carefully. If difficulty spikes, reduce one scaling factor.

⚠️ **D-04: Hit-stop during multi-enemy combat may feel sluggish**
- With 4-6 enemies in later rooms, rapid hits trigger frequent hit-stops (2-8 frames each)
- AoE cards hitting multiple enemies generate a hit per target — if each triggers hit-stop, combat pauses repeatedly
- Hit-stop stacking uses "longer wins" not "additive," which helps, but rapid sequential hits from separate actions could still create a stuttering feel
- **Recommendation**: Consider a per-frame hit-stop cooldown (no new hit-stop within N frames of the last one ending) for targets other than the player.

---

## Cross-System Scenario Issues

### Scenarios Walked: 4

1. **Card play → damage → draw** (Combat + Card Hand + Animation + Collision)
2. **Room clear → reward → deck modification** (Room Encounter + Reward + Deck Building)
3. **Stun during card windup** (Status Effect + Animation + Card Hand + Combat)
4. **Player death mid-encounter** (Combat + Entity Framework + Room Encounter + Run State)

### Blockers

🔴 **S-01: Card play cannot provide active_frames to Animation State Machine**
- Scenario: Card play → damage → draw
- Step 4: Combat System calls `AnimationComponent.play_action(animation_key, windup, active, recovery)`
- `active` parameter has no source — CardData has `windup_frames` and `recovery_frames` but not `active_frames`
- Animation State Machine says it's "inferred from animation" but no inference mechanism is defined
- **Impact**: The entire combat loop is broken at the animation layer. Cards cannot play.
- **Resolution**: Same as C-01 — add `active_frames` to CardData schema.

### Warnings

⚠️ **S-02: Card consumed on stun during windup — potential frustration**
- Scenario: Stun during card windup
- Step: Player plays card → enters WINDUP → enemy stun hits → Animation cancels action
- animation-state-machine.md: "The action is cancelled. Entity transitions to STUNNED."
- card-hand-system.md: Card was already removed from hand and added to discard (step CP.2.a happens on play, before windup)
- Result: Player loses the card (to discard) but gets no effect. The card is not refunded.
- This is mechanically consistent with "every card is a commitment" (Pillar 1), but losing a rare/powerful card to an interrupting stun with no counterplay could feel unfair
- **Recommendation**: Clearly document this as intended behavior. Consider: should stunned-during-windup return the card to hand instead of discard? This is a design decision, not a bug.

⚠️ **S-03: Room clear delay + reward generation ordering**
- Scenario: Room clear → reward → deck modification
- room-encounter-system.md: After last enemy despawns, wait `CLEAR_DELAY` (30 frames), then generate reward
- reward-system.md: `generate_reward()` needs floor_number and room_type from Dungeon Generation
- run-state-manager.md: `rooms_cleared` is incremented on room clear
- No explicit ordering between "increment rooms_cleared" and "generate reward" — both trigger on room clear
- **Impact**: Minor — if reward generation reads rooms_cleared for any purpose, it could get pre-increment or post-increment value. Currently reward doesn't use rooms_cleared, so no actual bug.
- **Recommendation**: Document the ordering: increment rooms_cleared BEFORE generating reward.

### Info

ℹ️ **S-04: Player death during enemy attack — both die simultaneously**
- Scenario: Player and enemy trade hits in same frame
- combat-system.md: "Simultaneous death is valid — if both entities die, room clears and player death takes priority (run ends)"
- This is explicitly handled. Room clear reward does NOT trigger (player died). Run ends.
- No issue — just confirming this edge case is covered.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `card-data-system.md` | Missing `active_frames` field (C-01) | Consistency | Blocking |
| `camera-system.md` | Dependency direction labels inverted (C-02) | Consistency | Blocking |
| `animation-state-machine.md` | Missing Card Data upstream dep (C-07) | Consistency | Warning |
| `combat-system.md` | PLAYER_MAX_HP dual ownership (C-03) | Consistency | Warning |
| `game-concept.md` | Stale starter deck size reference (C-06) | Consistency | Warning |

---

## Verdict: CONCERNS

No game-design-level blockers. Two consistency blockers (C-01, C-02) that are straightforward fixes — adding a missing field and correcting table labels. All other issues are warnings that should be resolved but don't prevent architecture from beginning.

### Required actions before architecture:
1. Add `active_frames` (int, range 2–12) to CardData schema in `card-data-system.md`
2. Fix dependency table directions in `camera-system.md`

### Recommended (non-blocking) cleanup:
3. Resolve tuning knob dual-ownership (C-03, C-04, C-05, C-09) — pick one owner per knob
4. Add Card Data as upstream dep in `animation-state-machine.md`
5. Update game-concept.md starter deck reference
