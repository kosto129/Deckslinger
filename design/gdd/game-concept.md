# Game Concept: Deckslinger

*Created: 2026-04-16*
*Status: Draft*

---

## Elevator Pitch

> It's a real-time action roguelike where your combat abilities are cards drawn
> from a deck — fight with weighty, committal combat while your available moves
> constantly shift, forcing you to improvise with whatever hand fate deals you.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Action RPG Roguelike with Deckbuilding |
| **Platform** | PC (Steam / Epic) |
| **Target Audience** | Challenge-driven players who love both Hades and Slay the Spire (see Player Profile) |
| **Player Count** | Single-player |
| **Session Length** | 30-60 minutes per run |
| **Monetization** | Premium (paid upfront) |
| **Estimated Scope** | Large (6-9 months full vision, solo) |
| **Comparable Titles** | Hades, Slay the Spire, Ravenswatch |

---

## Core Fantasy

You are a fighter whose power is drawn from a living deck of abilities. Every
card you play reshapes what you can do next. In a world where others rely on
brute force or memorized combos, you thrive on chaos — reading the battlefield,
playing the right card at the right moment, and turning an imperfect hand into
a flawless victory.

The fantasy is **masterful improvisation under pressure**. You don't win because
you found the best build. You win because you can make ANY hand work.

---

## Unique Hook

Like Hades, AND ALSO your combat abilities cycle through a card hand — you're
never executing the same rotation twice, because what you CAN do changes every
time you act. The deckbuilding roguelike's strategic depth lives inside real-time
action combat.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 4 | Weighty impact feedback, screen shake, hit-stop on card abilities |
| **Fantasy** (make-believe, role-playing) | 5 | Living deck identity, character who channels cards as combat arts |
| **Narrative** (drama, story arc) | 6 | Hades-style story fragments revealed through repeated runs |
| **Challenge** (obstacle course, mastery) | 1 | Committal combat, hand management under pressure, boss tests |
| **Fellowship** (social connection) | N/A | Single-player first; co-op is a future consideration |
| **Discovery** (exploration, secrets) | 2 | Card synergy discovery, rare card drops, hidden interactions |
| **Expression** (self-expression, creativity) | 3 | Deck building as identity, multiple viable strategies per run |
| **Submission** (relaxation, comfort zone) | N/A | This game demands attention — not a comfort game |

### Key Dynamics (Emergent player behaviors)

- Players will theory-craft deck compositions to maximize synergy consistency
- Players will make agonizing "play this okay card to draw something better"
  decisions mid-combat
- Players will learn enemy telegraphs and hold specific cards in hand for the
  right moment — reading the fight like a poker hand
- Players will discover unintended card interactions and share them with the
  community
- Players will intentionally trim their deck aggressively to increase draw
  consistency — "smaller deck, bigger plays"

### Core Mechanics (Systems we build)

1. **Real-time committal combat** — weighty animations with recovery frames,
   positioning matters, every action locks you in
2. **Card hand system (use-to-draw)** — hand of 3-4 ability cards, playing one
   draws the next from your deck, hand always shifting
3. **Deck building between encounters** — draft new cards, remove weak cards,
   upgrade existing cards at reward screens
4. **Procedural dungeon with branching paths** — choose your route through
   rooms with risk/reward trade-offs
5. **Boss encounters** — skill-check fights that test your deck composition and
   improvisation ability

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Deck building, path choices, card play decisions — your run is YOUR build | Core |
| **Competence** (mastery, skill growth) | Weighty combat rewards execution skill; deck trimming rewards game knowledge; bosses test both | Core |
| **Relatedness** (connection, belonging) | Story characters between runs, Hades-style NPC relationships, community theory-crafting | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — Chase rare cards,
  unlock new characters, complete the card collection, beat harder difficulties
- [x] **Explorers** (discovery, understanding systems, finding secrets) — Discover
  card synergies, find hidden interactions, map out optimal deck strategies
- [ ] **Socializers** (relationships, cooperation, community) — Limited; community
  sharing of builds and discoveries is secondary
- [x] **Killers/Competitors** (domination, PvP, leaderboards) — Speedruns,
  leaderboards, mastery of the skill ceiling. No PvP but strong competitive appeal

### Flow State Design

- **Onboarding curve**: First run uses a curated starter deck (5-6 simple cards)
  with tutorial prompts. Teaches: move, play a card, draw happens automatically,
  read enemy telegraph, choose the right card. By room 3, training wheels off.
- **Difficulty scaling**: Enemy count and complexity increases per floor. Card
  pool expands as you unlock — more options means more decision complexity,
  not just more power.
- **Feedback clarity**: Hit-stop and screen shake on impactful cards. Deck
  viewer shows your full build at any time. Post-run stats show which cards
  you played most, damage dealt per card, cards drawn but never played.
- **Recovery from failure**: Death ends the run but keeps meta-currency. Restart
  is immediate — under 5 seconds from death to new run. Failure is educational:
  "my deck had no answer for that attack pattern — next time I draft differently."

---

## Core Loop

### Moment-to-Moment (30 seconds)
You're in a room. Enemies approach with telegraphed attacks. You hold a hand of
3-4 ability cards. Combat is real-time but every action **commits you** —
animation locks, recovery frames, positioning consequences. You read an enemy
telegraph, pick the right card from your hand, and execute. The card resolves,
a new one draws from your deck. Your hand just changed. The next enemy is
already moving. You adapt.

Core satisfaction: "I had three options. I read the situation. I picked the right
one. It landed."

### Short-Term (5-15 minutes)
Clear a room. Get a reward: a new card to add to your deck, a card upgrade, or
currency. Choose your next room from a branching path — harder rooms offer rarer
cards. Between encounters, you can **trim your deck** (remove weak cards to
increase draw consistency). The "one more room" pull is constant because every
room reshapes your build.

### Session-Level (30-60 minutes)
A full run is a multi-floor dungeon. Each floor escalates with a boss at the end.
Bosses demand specific card strategies — you've been building toward them the
whole run. Runs end in death or victory. Either way, you earn **meta-currency**
and unlock story fragments. A run is a complete arc: start weak, build your deck,
peak in power, face the final test.

### Long-Term Progression
- **Unlock new card pools** — expands what can appear in runs
- **New characters/starting decks** — each plays fundamentally differently
- **Rare card drops** — powerful cards with low appearance rates that change how
  a run plays (the FFXI rare drop philosophy)
- **Story revealed through runs** (Hades-style) — narrative progression tied to
  repeated play, not a separate mode

### Retention Hooks
- **Curiosity**: "I haven't seen that rare card yet. I wonder what it does with
  my favorite combo."
- **Investment**: Unlocked card pools, character progress, story threads to follow
- **Social**: Build sharing, community discovery of synergies, leaderboard competition
- **Mastery**: "I can beat Floor 1 consistently now. Time to push Floor 2 with a
  lean deck."

---

## Game Pillars

### Pillar 1: Every Card Is a Commitment
Every action has weight — animation locks, recovery, positioning consequences.
There is no spamming, no mindless rotation. Playing a card means choosing NOT to
play the others in your hand, and choosing to change your future options. The
strategic cost of every action is what makes the right call feel brilliant.

*Design test*: "Should we add a cancel/dodge-out-of-anything mechanic?" — **No.**
Commitment IS the game. Add recovery windows, not escape hatches.

### Pillar 2: Your Deck Is Your Identity
How you build your deck across a run defines your playstyle more than character
stats or gear ever could. Two players with the same character will play completely
differently based on what they drafted. Deck building is the primary expression
of mastery — knowing what to take, what to skip, and what to cut.

*Design test*: "Should we add a powerful passive stat system?" — **Only if it
changes which cards are good**, never as a substitute for card-based power.

### Pillar 3: Adapt or Die
Your hand is always changing. Enemy compositions are always different. No run
plays the same. The best players aren't the ones who found the best build —
they're the ones who can make ANY hand work. Mastery is improvisation under
pressure.

*Design test*: "Should we let players lock a card in hand permanently?" — **No.**
The hand must flow. Consistency comes from deck building, not hand freezing.

### Pillar 4: Earn Everything
Nothing is given. Rare cards are rare. Unlocks require investment. Victories feel
earned because the game respected your time and skill, not because it handed you
a power spike. The reward means something because it cost something.

*Design test*: "Should we add a pity timer for rare drops?" — **Soft pity only**
(increased odds over time), never a guaranteed handout.

### Anti-Pillars (What This Game Is NOT)

- **NOT an idle/autopilot game**: If a player can win by mashing whatever card is
  available without reading the situation, the design has failed. Every room should
  demand attention.
- **NOT a content treadmill**: We don't need 200 cards at launch. 40 cards with
  deep interactions beat 200 shallow ones. Depth over breadth.
- **NOT a random encounter slog**: Encounters are hand-placed in rooms you choose
  to enter. You are never ambushed by filler fights. Every fight is there for a reason.

---

## Visual Identity Anchor

**One-Line Visual Rule:**
> "Every frame must carry the weight of the action and the flux of the hand —
> ground the player, but never let them feel safe."

**Supporting Principles:**
1. **The Body Tells the Truth** — every animation state reads as a distinct
   silhouette. Commitment is visible. *(Pillar 1)*
2. **The Hand Has a Personality** — card archetypes share color temperature
   and icon shape. Gestalt over text. *(Pillar 2)*
3. **Rarity Earns a Different Visual Register** — each rarity tier adds a new
   visual behavior, not more intensity. *(Pillar 4)*

**Color Philosophy:** 7-color primary palette anchored to emotional states
(Dungeon Stone, Lantern Amber, Combat Ember, Dungeon Teal, Boss Violet, Hand
White, Void). 5 card archetype palettes with 30-degree minimum hue separation.

Full art bible: `design/art/art-bible.md`

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Hades | Fluid action roguelike loop, narrative through repetition, NPC relationships | Combat is committal not fluid; abilities come from a card hand, not a fixed kit | Proves action roguelike + story works at massive scale (6M+) |
| Slay the Spire | Deckbuilding roguelike loop, card synergy depth, deck trimming as skill expression | Real-time action execution instead of turn-based; hand cycles during combat, not between turns | Proves deckbuilding roguelike is a dominant genre (10M+) |
| Ravenswatch | Action roguelike with character identity, cooperative roguelike design | Single-player focus; card hand replaces fixed ability loadout | Validates action roguelike character variety appeal |
| FFXI | Rare drop philosophy, earned rewards, community-driven discovery | Single-player context; rarity applied to cards not gear | The emotional model for how loot should feel |
| Dark Souls | Weighty committal combat, every action matters, death as teacher | Roguelike structure instead of checkpoint; card hand instead of fixed moveset | The gold standard for "combat weight" feel |

**Non-game inspirations**: Poker (reading the hand, playing odds, knowing when to
hold and when to act), jazz improvisation (mastery expressed through adaptation
to the moment, not rehearsed performance).

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-35 |
| **Gaming experience** | Mid-core to Hardcore |
| **Time availability** | 30-60 minute sessions, can pick up and put down between runs |
| **Platform preference** | PC (Steam) |
| **Current games they play** | Hades, Slay the Spire, Dead Cells, Risk of Rain 2, Balatro |
| **What they're looking for** | The action-deckbuilder hybrid that doesn't exist yet — tactical depth without sacrificing real-time combat feel |
| **What would turn them away** | Shallow combat, excessive RNG with no skill expression, pay-to-win, excessive grinding with no skill shortcut |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 (user preference; excellent 2D pipeline, clean Steam export) |
| **Key Technical Challenges** | Card system architecture (data-driven, extensible); real-time combat with animation commitment; hand UI that doesn't obstruct action gameplay |
| **Art Style** | Pixel art (32x32 characters) or stylized 2D — must prioritize visual clarity for card/combat readability |
| **Art Pipeline Complexity** | Low-Medium (pixel art or simple 2D; card icons can be symbolic) |
| **Audio Needs** | Moderate — impactful SFX for card abilities is critical for weight feel; music per floor |
| **Networking** | None (single-player) |
| **Content Volume** | MVP: 1 floor, 25 cards, 4 enemy types, 1 boss. Full: 5+ floors, 100+ cards, 4+ characters |
| **Procedural Systems** | Room layout selection from hand-crafted pool; card draft randomization; enemy composition per room |

---

## Risks and Open Questions

### Design Risks
- **Core loop pacing**: Can use-to-draw hand cycling feel fluid in weighty
  real-time combat, or does it create awkward pauses where the player reads
  cards instead of fighting? This is the #1 risk and must be prototyped first.
- **Card balance**: Even 25 cards with status effects and synergies can produce
  degenerate combos. Needs iterative playtesting.
- **Hand size tension**: 3 cards may feel too constrained; 5 may feel overwhelming
  in real-time. Sweet spot must be found through prototyping.

### Technical Risks
- **Card interaction complexity**: Status effects, buffs, synergies need a clean
  extensible system. Data-driven card definitions are essential from day one.
- **Combat feel**: Weighty committal combat requires careful animation timing,
  hit-stop, and recovery frame tuning — this is art-dependent and hard to get
  right without iteration.
- **Hand UI in action context**: The card hand must be readable at a glance during
  fast combat. UI design is a core challenge, not an afterthought.

### Market Risks
- **Genre hybrid communication**: "Action deckbuilder" is an unusual pitch. Store
  page and marketing must immediately convey the hybrid — screenshots and GIFs
  need to show both the action AND the hand simultaneously.
- **Comparison trap**: Will be compared to both Hades and Slay the Spire. Must
  stand on its own merits, not just as "X meets Y."

### Scope Risks
- **Weeks timeline for MVP is aggressive**: Even a focused MVP has real-time
  combat, card system, enemy AI, room generation, and a boss. Ruthless
  prioritization required.
- **Card content pipeline**: Each new card needs design, implementation, VFX,
  SFX, and balance testing. The per-card cost must be low or content will bottleneck.

### Open Questions
- **Hand size**: 3 or 4 cards in hand? Prototype both and test which creates
  better decision tension without overwhelming real-time play.
- **Draw visibility**: Should the player see the next card they'll draw? Adds
  strategy but also UI complexity. Prototype with and without.
- **Deck size sweet spot**: What's the ideal deck size for a full run? Too small
  = predictable. Too large = inconsistent. Needs playtesting.
- **Discard vs. reshuffle**: When the draw pile empties, reshuffle the discard?
  Or are played cards gone until a rest point? Major design lever.

---

## MVP Definition

**Core hypothesis**: "Real-time weighty combat with a use-to-draw card hand
creates a compelling moment-to-moment decision loop that players want to repeat."

**Required for MVP**:
1. Real-time combat with commitment-based animations and a 3-4 card hand
2. Use-to-draw cycling with a buildable/trimmable deck
3. One full dungeon run (8-10 rooms with branching paths → 1 boss)
4. At least 25 cards with meaningful interactions between them
5. 4-5 enemy types with distinct telegraphed attack patterns
6. Card draft and deck trim screens between encounters

**Explicitly NOT in MVP** (defer to later):
- Multiple characters or starting decks
- Meta-progression or persistent unlocks
- Story, NPCs, or narrative systems
- Audio beyond placeholder SFX
- Multiple dungeon floors
- Rare card drop system
- Leaderboards or daily challenges

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 floor, 25 cards, 4 enemies, 1 boss | Core combat + hand + deck building | 3-4 weeks |
| **Vertical Slice** | 2 floors, 40 cards, 6 enemies, 2 bosses | + meta-currency, 1 unlock track | 6-8 weeks |
| **Alpha** | 3 floors, 60 cards, 2 characters, 4 bosses | + story fragments, rare cards, full progression | 3-4 months |
| **Full Vision** | 5+ floors, 100+ cards, 4+ characters, narrative | + Hades-style story, daily challenges, leaderboards | 6-9 months |

---

## Next Steps

- [ ] Configure the engine with `/setup-engine`
- [ ] Create the visual identity specification with `/art-bible`
- [ ] Validate concept completeness with `/design-review design/gdd/game-concept.md`
- [ ] Discuss vision with the `creative-director` agent for pillar refinement
- [ ] Decompose the concept into individual systems with `/map-systems`
- [ ] Author per-system GDDs with `/design-system`
- [ ] Plan the technical architecture with `/create-architecture`
- [ ] Record key architectural decisions with `/architecture-decision`
- [ ] Validate readiness to advance with `/gate-check`
- [ ] Prototype the riskiest system with `/prototype core-combat-hand`
- [ ] Run `/playtest-report` after the prototype to validate the core hypothesis
- [ ] If validated, plan the first sprint with `/sprint-plan new`
