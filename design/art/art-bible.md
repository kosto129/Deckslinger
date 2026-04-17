# Art Bible: Deckslinger

*Created: 2026-04-16*
*Status: Complete*

---

## 1. Visual Identity Statement

**One-Line Visual Rule:**
> "Every frame must carry the weight of the action and the flux of the hand —
> ground the player, but never let them feel safe."

This encodes the game's core tension: committal, heavy combat (the weight)
colliding with a constantly shifting card hand (the flux). The visual identity
lives in that collision — it is not a pure action game aesthetic or a pure card
game aesthetic, but both held in tension.

### Supporting Principles

**Principle 1 — The Body Tells the Truth** *(serves Pillar 1: Every Card Is a Commitment)*

Combat silhouettes are the primary communication channel. Every animation state —
windup, active, recovery — must read as a distinct silhouette shape from 4+ tiles
away in 32x32 pixel art. No two animation states for the same character can share
a silhouette profile.

*Design test*: When the player's recovery frame looks similar to their windup —
this principle says hold more contrast between animation keyframes, even at the
cost of smooth interpolation. Commitment must be visible.

**Principle 2 — The Hand Has a Personality** *(serves Pillar 2: Your Deck Is Your Identity)*

Cards belonging to the same archetype share a color temperature and a dominant
shape in their icon. A fire-aggression deck runs warm reds and jagged diagonals.
A defensive-parry deck runs cool blues and interlocking horizontals. A player
should be able to glance at their current hand and immediately perceive whether
it matches their intended playstyle — not read the text, perceive the gestalt.

*Design test*: When two cards in the same archetype need to feel visually distinct —
this principle says vary the energy level (one stroke vs. many) while preserving
the color temperature and geometry. Distinction within coherence, not chaos.

**Principle 3 — Rarity Earns a Different Visual Register** *(serves Pillar 4: Earn Everything)*

Common cards use the same flat pixel art style as the environment. Uncommon cards
introduce one layer of visual complexity: animated icon, a border material that
catches light, a subtle particle. Rare cards break the visual register entirely —
they feel like objects from outside the world's normal physics. The visual
hierarchy is not about color alone; it's about the card appearing to exist at a
different depth or energy level than common cards.

*Design test*: When a rare card looks impressive but still feels like a "fancier
version" of a common card — reject it. Rare cards must feel qualitatively
different, not quantitatively shinier.

### What This Identity Rules Out

- Decorative particle effects that fire during combat and obscure the combat frame
- Card icons that require reading text to understand at combat speed
- Environment art so detailed it competes visually with character silhouettes
- A uniform rarity presentation where rare = "same art, gold border"

---

## 2. Mood & Atmosphere

### System Principles

Mood is not decoration — it is information. Each game state uses a distinct
visual register so the player never needs to read a label to know where they
are. State transitions must be legible from lighting shift and palette shift
alone. The visual identity rule governs all states: ground the player (enough
visual stability to read the fight), but never let them feel safe.

### Game State Mood Targets

#### Dungeon Exploration (Moving between rooms, choosing paths)

**Primary emotion:** Focused unease — the player is in control but the dungeon
resists them. Not terror; calculated dread.

- **Lighting**: Cool mid-tone (desaturated teal-grey, ~5500K). Medium-low
  contrast. Soft shadows with edges that bleed slightly. Overhead ambient with
  shallow rim lighting from one lateral edge.
- **Atmosphere**: Oppressive, deliberate, watchful, close, strained
- **Energy**: 3/10 — slow pulse. The dungeon is patient.
- **Signature element**: Doorways to unvisited rooms are lit from within by a
  single warm light source (warm amber, ~2700K) against the cool hallway. This
  is the only warm color in exploration state — both invitation and threat.

#### Active Combat (Fighting enemies in a room)

**Primary emotion:** Pressured clarity — adrenaline that sharpens rather than
overwhelms. The player feels capable and endangered simultaneously.

- **Lighting**: Warm-shifted from exploration baseline (amber-orange mid-tones).
  Enemy abilities introduce cool/cyan contrast spikes. High contrast, hard
  shadows. Strong silhouette separation. Top-down with environmental bounce from
  floor tiles — combat creates its own light.
- **Atmosphere**: Kinetic, sharp, volatile, lucid, unforgiving
- **Energy**: 8/10 — constant motion, no moment of rest.
- **Signature element**: Card hand UI glows with low-intensity archetype color
  (warm red for aggression, cool blue for defensive). In combat, the hand is
  always in peripheral vision — its ambient glow is the only constant. Grounds
  the player without letting them feel safe.

#### Boss Encounter (High-stakes fight, end of floor)

**Primary emotion:** Sovereign dread — the enemy is larger than the world
you've been in. The player is small, outmatched, but the deck is the answer.

- **Lighting**: Split palette. Player's side holds combat warm-amber; the boss
  occupies deep violet-red (~3000K, heavily desaturated). The two palettes do
  not blend cleanly — visible seam of tension at center screen. Maximum
  contrast. Near-silhouette on boss during windup. When boss attacks, the room
  color-shifts toward their palette. Light radiates FROM the boss.
- **Atmosphere**: Monumental, suffocating, relentless, legible, earned
- **Energy**: 9/10 with structured beats. Phase transitions drop to 5/10 (held
  breath before next phase).
- **Signature element**: Floor beneath the boss emits a slow radial pulse in
  their palette color (shader-based light ripple on tiles). Pulse accelerates as
  boss HP decreases. When boss dies, pulse stops and lighting returns to
  exploration baseline in under one second — sudden silence.

#### Card Draft / Reward Screen (Choosing new cards between rooms)

**Primary emotion:** Tense deliberation — the player has stopped moving but not
stopped fighting. They are fighting their own indecision.

- **Lighting**: Neutral (5000-5500K). Neither warm nor cool. Low contrast, flat
  even lighting across all card options. Background desaturates to near-greyscale
  so cards become the dominant visual element.
- **Atmosphere**: Still, deliberate, suspended, weighted, exposed
- **Energy**: 2/10 — the run is holding its breath.
- **Signature element**: When a card is hovered, the room shifts subtly toward
  that card's archetype color temperature. Hovering aggression warms the screen;
  hovering defense cools it. The player sees what their run would feel like.

#### Deck Management (Trimming or reviewing the deck)

**Primary emotion:** Calculated ownership — the player examining their own
identity. A craftsperson inspecting their tools.

- **Lighting**: Warm-neutral (4000K), slightly amber. The closest thing to
  "safety" in the game's visual vocabulary — still a hard dungeon light, just
  not hostile. Single light source above and slightly forward — a lantern over a
  workbench.
- **Atmosphere**: Intimate, honest, methodical, clear-eyed, purposeful
- **Energy**: 2/10.
- **Signature element**: Cards the player removes animate with a brief downward
  "drop" — they fall below the visible frame. The remaining cards shift closer
  together. Trimming reads as loss and as precision simultaneously (Pillar 4:
  Earn Everything made visual).

#### Death / Defeat

**Primary emotion:** Earned failure — not punishment, acknowledgment. The
player should feel the weight of what they built, not shame for losing.

- **Lighting**: Complete desaturation over 1.5 seconds. Contrast collapses to
  near-zero. Light source extinguishes. Final frame: character illuminated only
  by faint cool ground-level ambient — a last pool of light shrinking to nothing.
- **Atmosphere**: Hollow, deliberate, final, respectful, suspended
- **Energy**: 0/10 — total stillness after the kinetic peak of combat.
- **Signature element**: The card hand UI is the last element to disappear.
  Environment desaturates first, then character, then enemies. The hand holds
  for ~0.5 seconds longer than everything else. The deck outlives the run
  (Pillar 2: Your Deck Is Your Identity).

#### Hub / Menu (Between runs)

**Primary emotion:** Earned rest with forward tension — the player has stopped
but the game hasn't. The world between runs is alive, not frozen.

- **Lighting**: Warm amber, highest saturation in any state (~2500K). Multiple
  warm point sources at human height — firelight, lantern, candle. Medium-low
  contrast, soft shadows, readable NPC faces.
- **Atmosphere**: Breathing, expectant, lived-in, charged, quiet
- **Energy**: 3/10 — not low energy, restrained energy. A room before the fight.
- **Signature element**: Ambient animation (dust motes in lantern beams, cloth
  swaying, candle flame cycling). The dungeon entrance is always visible in the
  background, always in shadow. You are never fully safe here.

### State Transition Rules

| Transition | Visual Treatment |
|---|---|
| Exploration → Combat | Hard cut, <0.3s. Room locks and lighting shifts immediately. |
| Combat → Boss | Environmental fade + palette swap over 2s during boss intro. |
| Combat → Reward Screen | Camera pulls back, background desaturates, cards rise into frame. |
| Reward → Exploration | Cards settle/exit, background resaturates, ambient returns. |
| Exploration → Deck Mgmt | Overlay approach — foreground dims, card spread rises. |
| Any Combat → Death | Desaturation cascade over 1.5s. |
| Death → Hub | Fade through black. Hub fades in warm — contrast with death's cold is intentional. |
| Hub → New Run | Hub warms to peak saturation, then hard cut to exploration cool — warmth is taken from you. |

### Cross-State Invariants

1. **Card archetype colors are never overridden by environment mood.** A fire
   card reads red in the hub, in the dungeon, in boss light. The hand is always
   the player's stable reference.
2. **Character silhouette contrast is always high relative to background.** No
   state's lighting is allowed to flatten the player into the environment.
3. **Rarity visual register holds across all states.** A rare card that breaks
   the register does so in the boss room as well as the reward screen.

---

## 3. Shape Language

### Character Silhouette Philosophy

**Core rule: one dominant protrusion per animation state.**

At 32x32, silhouette readability requires each keyframe to have a single shape
extending clearly beyond the character's resting mass.

- **Idle**: Vertical stack, wide at shoulders, narrow at feet. A "waiting coil" —
  compressed downward, weight in the legs. Not relaxed; loaded.
- **Windup**: Dominant protrusion is the weapon arm pulling back/outward. Silhouette
  breaks from vertical into a strong diagonal. This is the commitment read.
- **Active frame**: Opposite diagonal — weapon creates horizontal thrust or arc.
  Center of mass shifts against attack direction (recoil built into active frame).
- **Recovery**: Silhouette collapses toward vertical, weapon arm low and trailing.
  Distinct from idle because asymmetry is low, not neutral.

**Archetype influence on silhouette** (Pillar 2: Your Deck Is Your Identity):
Aggression-heavy decks produce a forward-leaning idle (center of mass over front
foot). Defensive decks produce a wider torso (shield-posture reading). The
silhouette communicates playstyle without card text.

**Player character identifier**: One permanent, non-animated asymmetry (e.g.,
high-left shoulder) that enemies never share. In chaotic frames, the player is
always findable. This serves Pillar 1: if you can't locate your character,
commitment-based combat becomes unreadable panic.

### Environment Geometry

**Angular dominates. Organic is the exception and the danger signal.**

Dungeon architecture uses hard geometry: perpendicular walls, 45-degree
diagonals, no curves in structural elements. Hard geometry creates clear threat
corridors — the player reads attack angles from geometry alone.

Emotional logic: angular geometry communicates a constructed trap. This dungeon
was built by something that wanted you to fail in predictable ways.

**Organic shapes appear exactly twice:** on background flora/fungal dressing, and
on specific enemy types that signal "this enemy behaves differently." A round,
swollen enemy in an angular dungeon reads immediately as biological-threat.

**Per-state geometry:**
- **Exploration corridors**: Long rectangles with visible endpoints. You see the
  hall; you don't see what's behind the door.
- **Combat rooms**: Asymmetric rectangles (not square). Player starts at one edge;
  enemies from opposite wall and both short walls. Asymmetry prevents equidistant
  positioning — you're always closer to one threat (Pillar 3: Adapt or Die).
- **Boss arena**: Wide, near-square, significant empty floor. Boss needs visual
  breathing room to feel monumental. Architectural ornamentation escalates.

### UI Shape Grammar

**The UI is distinct from the world but speaks the same angular dialect.**

**Card shape**: Slightly taller than wide (2:3 playing card proportion). Border
uses a chamfered rectangle — 45-degree cuts at all four corners, NOT rounded.
Rounded corners communicate safety. Chamfered corners communicate precision,
industrial intent, and danger. Every time the player looks at their hand, the
card shape reinforces: this is a weapon, not a gift.

Rarity through shape:
- Common: plain chamfered border, flat fill
- Uncommon: border has subtle inward bevel (shadow edge)
- Rare: border introduces one curve or protrusion that breaks the rectangle
- Legendary: card doesn't quite fit in a normal hand

**Hand layout**: Cards displayed in a slight convex arc (like a physical card
fan). At 3 cards the arc is nearly flat; at 4 cards it becomes perceptible. A
smaller hand reads as more controlled; a full hand reads as reaching capacity.

**HUD frame**: Corner-bracket approach — health and deck count in opposing
corners (top-left, bottom-right), connected by the card hand arc at
center-bottom. No full frames or boxes; only corner brackets made of two
90-degree lines. Minimizes screen real estate, keeps combat area clean, echoes
dungeon architecture's perpendicular geometry.

### Hero Shapes vs. Supporting Shapes

**Hierarchy: Player Character > Card Hand > Active Enemy > Environment >
Inactive Enemies > HUD.**

Enforced through shape complexity, not just color or size.

**Hero shapes** (draw the eye):
- Player character: highest shape complexity, most articulated silhouette
- Active cards: expand slightly with a shape-echo (second chamfered rectangle at
  low opacity behind)
- Currently attacking enemy: windup protrusion becomes the most distinct shape
  on screen at the moment the player needs to respond

**Supporting shapes** (recede):
- Environment tiles: high repetition, grouped and dismissed by Gestalt similarity
- Inactive enemies: narrower, more symmetric idle than player (symmetry = lower
  energy/threat)
- HUD corner brackets: negative space reads as framing, not objects

**Underlying principle: shape complexity is attention.** Every element earns the
complexity it uses. The dungeon floor earns near-zero. The rare card earns
geometry-breaking complexity.

---

## 4. Color System

### Primary Palette

Seven colors anchoring every state and semantic use. Every other color in the
game is a derivation, shift, or desaturation of this foundation.

| Swatch | Hex | Role |
|--------|-----|------|
| **Dungeon Stone** | `#2A2D35` | World's default dark. Floor tiles, background fills, visual silence. |
| **Lantern Amber** | `#E8922A` | Warmest thing in the world. Hub light, doorway glow, NPC presence. Safety that cannot last. |
| **Combat Ember** | `#C4581A` | Active combat ambient, fire archetype root hue. Deeper and more urgent than amber. |
| **Dungeon Teal** | `#4A7B8C` | Exploration ambient, the world at rest. Not safe — watching. |
| **Boss Violet** | `#6B2D5E` | Used only in boss context. Its presence signals something fundamentally wrong. |
| **Hand White** | `#F0EDE6` | Slightly warm (not pure white). Card backgrounds, text, UI surfaces. |
| **Void** | `#111318` | Death frames, deep shadow. The bottom of the value range. |

**Reserved from decorative use:** Pure cyan, pure red, pure gold. These carry
gameplay meaning only and must not appear in environment or UI chrome.

### Card Archetype Palettes

Five archetypes. No two share a dominant hue within 30 degrees on the color wheel.

#### Aggression (Fire / Strike)
- **Temperature**: Hot (2700-3200K)
- **Hue**: Combat Ember `#C4581A` + Harsh Red spike `#E03A1E`
- **Shape**: Jagged diagonals, radial burst, acute angles pointing outward
- **Signal**: Forward momentum, irreversibility. Burns bright, leaves you open.
- **Muted**: `#7A3510`

#### Defense (Parry / Guard)
- **Temperature**: Cool (6500-7500K)
- **Hue**: Steel Blue `#2E6A9E` + Pale Steel `#8AB4CC`
- **Shape**: Interlocking horizontals, shield forms, outward-facing convex curves
- **Signal**: Holding ground, time bought, cost deferred. Closes space.
- **Muted**: `#1A3E5E`

#### Mobility (Dash / Reposition)
- **Temperature**: Neutral-warm (4500K), high value contrast
- **Hue**: Kinetic Gold `#C8A82A`
- **Shape**: Directional arrows, trailing motion lines, asymmetric directional forms
- **Signal**: Speed, optionality. Commits to motion, not position. Gold = value spent.
- **Muted**: `#7A6518`

#### Control (Stun / Bind / Debuff)
- **Temperature**: Cold-neutral (8000K+ — beyond sky, unnatural)
- **Hue**: Deep Slate `#2A4E6B` + Icy Slate `#6B9EBA`
- **Shape**: Concentric rings, contained geometric forms, crossed lines enclosing space
- **Signal**: Suppression, enemy losing options. Calculating and precise.
- **Muted**: `#1A2E3E`
- **Distinction from Defense**: Defense is warmer blue, outward-facing (protects
  player). Control is colder blue-slate, inward-facing (constrains enemy). ~30
  degree hue shift + opposite shape direction.

#### Recovery (Heal / Restore / Draw)
- **Temperature**: Neutral green-warm (4000-4500K)
- **Hue**: Forest Green `#3E7A4E` + Life Green `#7AC48A`
- **Shape**: Upward-facing curves, radial forms opening upward, continuous loops
- **Signal**: Reclaiming something spent. Green does not otherwise appear in this
  world — its rarity of hue makes it immediately readable as restoration.
- **Muted**: `#264A30`

### Semantic Color Usage

| Use | Color | Hex | Why This Color |
|-----|-------|-----|----------------|
| **Incoming damage** | Harsh Red | `#E03A1E` | The world's temperature turned hostile |
| **Player dealing damage** | Combat Ember + white flash | `#C4581A` | Your hit uses your palette — your power expressed |
| **Healing** | Life Green | `#7AC48A` | Absent from environment; appearance is always signal |
| **Buff / positive status** | Kinetic Gold | `#C8A82A` | Value gained; expands option space |
| **Debuff on player** | Icy Slate | `#6B9EBA` | Control archetype applied to you — you're being constrained |
| **Enemy buff** | Boss Violet pulse | `#6B2D5E` | Enemy borrowing boss-level authority |
| **Interactable / pickup** | Lantern Amber | `#E8922A` | The warm signal in a cool-dominant frame |
| **Card playable** | Hand White | `#F0EDE6` | Full presence, full authority |
| **Card unplayable** | Hand White darkened | `#706D68` | Same hue, drained. Not threat — diminished. |
| **Critical HP** | Harsh Red pulse | `#E03A1E` | At critical HP, every second IS incoming damage |
| **New card added** | Kinetic Gold flash | `#C8A82A` | Resource gained, consistent with buff logic |
| **Card trimmed** | Void fade | `#111318` | The card simply stops existing. Loss, not punishment. |

### Rarity Color Language

Each rarity tier adds a new visual behavior, not more intensity of the same.

| Tier | Color Signal | Visual Register |
|------|-------------|-----------------|
| **Common** | Hand White `#F0EDE6` (no rarity color) | Flat pixel art, no animation. Belongs to the world. |
| **Uncommon** | Steel highlight `#A8C4D4` | Animated border shimmer (slow 1-2px). Has history. |
| **Rare** | Kinetic Gold `#C8A82A` + `#F0E06A` | Animated border + 2-4 orbiting gold particles. Earned at cost. |
| **Legendary** | Boss Violet `#6B2D5E` + white inner glow | Dimensional illusion — feels 3D in a 2D world. Particle field. Boss's authority captured and wielded by the player. |

**Escalation rule**: Common→Uncommon adds animation. Uncommon→Rare adds
particles. Rare→Legendary adds dimensional illusion. A Legendary that is merely
"a shinier Rare" fails the Principle 3 design test.

### Colorblind Safety

**High-risk pairings and backup cues:**

1. **Healing (green) vs. Buff (gold)** — Deuteranopia risk. Backup: healing VFX
   rises upward; buff VFX expands radially. Shape direction distinguishes them.

2. **Enemy damage (red) vs. Enemy buff (violet)** — Protanopia risk. Backup:
   damage is a fast directional flash (0.1s toward player); buff is a slow radial
   pulse (0.5s+ outward). Duration and direction distinguish.

3. **Playable vs. unplayable cards** — Low-vision risk. Backup: unplayable card
   icons desaturate to ~20% saturation in addition to background darkening.

4. **Defense (blue) vs. Control (blue-slate)** — Tritanopia risk (low). Backup:
   shape language is the primary distinguisher by design (outward curves vs.
   inward rings).

**Colorblind-safe by design**: Rarity uses value/chroma progression readable
without hue discrimination. All interactables pulse (animation is
colorblind-invariant). All status effect icons use shape, not just color badges.

**Implementation note**: Full symbol-overlay colorblind mode recommended for
Vertical Slice milestone. Not required for MVP — backup cues above cover
critical failure modes.

---

## 5. Character Design Direction

### Player Character Visual Archetype

**Identity: The Committed Fighter** — a scrapper with formal training gone
wrong. Mid-weight, carries their deck visibly on their right hip (4x6px
rectangular shape clipped to belt).

**Proportions at 32x32:**
- Head: 6x6px (slightly oversized for readability)
- Torso: 8px wide, 10px tall
- Legs: 8px total height, wide stance at idle
- Total height: ~24px (4px breathing room above/below)
- Silhouette fits 20px wide bounding box at idle

**Permanent asymmetric identifier:** Pronounced left shoulder guard — 1-2px
higher than right shoulder with slight outward angle. Present in every
animation state. Enemies never share this silhouette feature. Verification:
at 50% zoom on a busy combat frame, can you spot the left shoulder? If not,
the frame fails.

**Deck integration:** Deck on right hip shifts subtly on windup (rotation
forward) and recovery (rotation back). The deck is alive, not a prop.

**Expression through posture** (faces unreadable at 32x32):
- Idle: Weight low, slight forward lean. "Waiting to act."
- Windup: Head tucks toward attack direction, shoulder drops
- Active: Center of mass commits forward past midpoint — irreversible
- Recovery: Posture opens up and back. Not relaxed — exposed.

### Enemy Distinguishing Rules

Players must classify an enemy in under one second at 4-8 tile range.
Classification drives card selection.

**Melee enemies** — low, wide, forward-leaning:
- Height: 20-22px. Wider per-pixel than player.
- Idle protrusion: weapon/claw pointing forward (horizontal)
- Near-symmetric at idle (symmetry = lower energy in shape vocabulary)
- Windup telegraph: forward protrusion retracts behind body silhouette
- Color: Dungeon Stone dominant, one material accent. No warm palette.
- Naming: `char_enemy_melee_[variant]_[state].png`

**Ranged enemies** — tall, narrow, rearward-weighted:
- Height: 24-26px. Narrower than melee.
- Idle protrusion: weapon/appendage pointing upward or diagonal-up
- One cool element (Dungeon Teal touch — cape edge, lens, crystalline limb)
- Windup telegraph: upward protrusion rotates toward player, locks horizontal
- Naming: `char_enemy_ranged_[variant]_[state].png`

**Elite enemies** — player-height or taller, break one rule:
- Break one visual rule from base tier (e.g., wrong-feeling version of
  player's shoulder identifier — massive right shoulder instead of left)
- One element from outside floor's enemy palette (violet pulse, gold accent)
- 2-4px taller than base tier
- One permanent animation element not on standard enemies (idle sway, particle trail)
- +2 frames per animation state over standard enemies
- Naming: `char_enemy_elite_[variant]_[state].png`

**Boss enemies** — break the 32x32 constraint:
- 64x64 minimum (4x4 tile footprint)
- Competing protrusions (multiple, overwhelming before becoming legible)
- Boss Violet present somewhere in every boss sprite
- At least one organic shape element (organic = danger, Section 3)
- Phase transitions: one visual element changes permanently per phase
- "Tell limb": single appendage for windup reads, largest protrusion + highest contrast
- Naming: `char_boss_[name]_[phase]_[state].png`

### Expression and Pose Style

**Stiff with purpose, not smooth with fidelity.** Every frame is a pose, not
an in-between. Animation should feel like a flick-book by a skilled
illustrator.

**Frame counts:**

| State | Player | Std Enemy | Elite | Boss |
|-------|--------|-----------|-------|------|
| Idle | 4 | 2 | 4 | 6 |
| Walk/Move | 6 | 4 | 4 | 6 |
| Windup | 3 | 2 | 3 | 4 |
| Active (hit) | 2 | 2 | 2 | 3 |
| Recovery | 3 | 2 | 3 | 4 |
| Death | 5 | 3 | 4 | 8 |
| Hurt | 2 | 2 | 2 | 2 |

**Keyframe priority:** If budget forces cuts, cut from the middle of
transitions, never start or end poses. The active frame is held for 3-8 ticks
during hit-stop — must read as peak force at any duration.

### LOD Philosophy

**Design for 2x nearest-neighbor as canonical viewing size** (32x32 renders at
64x64-96x96 display pixels).

**Survives at game camera**: Silhouette shape, dominant color block (1-2 fields),
one accent color point, animation keyframes, large directional movement (8+ px).

**Wasted at game camera**: Face detail below 4px, dithered texture in areas
under 6px, sub-pixel line detail, color gradients below 3 steps, rear-facing
detail on sprites that never face camera.

**Thumbnail test:** View sprite at 1x (32x32 display pixels). Is the silhouette
distinct? Is the dominant protrusion legible? Can you classify enemy tier from
silhouette alone? If any answer is no, redesign — don't add detail.

---

## 6. Environment Design Language

### Architectural Style

**The dungeon is engineered, not grown.** Its builder was intelligent,
methodical, and hostile. Architecturally it reads as a fortified administrative
complex — corridors sized for moving things, not people; rooms sized for
processes, not comfort. No decorative columns or status iconography. The
builder wanted it functional at killing.

**Geometry rules:**
- Walls meet at 90 degrees. Alcoves are 45-degree cuts, never curved.
- Load-bearing logic is visible. Angular arches over doorways only where
  ceiling span demands it. Heavy arch = large space on the other side.
- The dungeon has been repaired badly. Lighter stone fill in cracked sections
  — structurally correct but visually jarring. Something maintains this place
  with priorities beyond aesthetics.
- Drainage channels run along floor edges on deeper floors. They imply what
  has been cleaned.

**Emotional logic:** The player should feel they are being routed. The
architecture steers them, not serves them.

### Texture Philosophy

**Low information density per tile, high readability at zoom.** Any tile detail
above 4-5 distinct value zones competes with character silhouettes. Tile
texture informs material, not story.

**Tile construction rules:**
- Floor tiles: 2-3 value zones. Primary tone, grout line (2px max), optional
  directional highlight.
- Wall tiles: 3-4 value zones. Base block, mortar recession, top-edge
  highlight, optional single crack per 3-tile span (2px diagonal, not organic).
- 3-5 unique variants per material. Variant selection follows defined noise
  pattern (clusters of 3-6 same-variant tiles), never pure random.
- Painted, not patterned. Each variant is individually authored pixel art.

**Three materials for MVP:**

| Material | Where | Values | Character |
|----------|-------|--------|-----------|
| Dungeon Stone | Standard floors/walls | `#2A2D35`, `#3E424F`, `#56606E` | Cut block, tight mortar, angular stress |
| Reinforced Stone | Boss arena, structural | `#1E2028`, `#2E333F`, iron-grey `#4A4E58` | Larger blocks, iron banding, no cracks |
| Worn Flagstone | Corridors only | `#252830`, `#3A3E4A`, `#4E535F` | Wide slabs, directional wear from transit |

### Prop Density

**Every prop must: communicate room function, serve as scale reference, or mark
a tactical landmark. Props serving none of these are cut.**

- **Corridors**: 1-2 props, wall-mounted only (torch sconce, empty bracket,
  single shattered crate). Floor stays clear.
- **Combat rooms**: 3-5 perimeter only. Zero props in central 60% of floor.
  Combat reads instantly on entry. Allowed: broken weapon rack, stacked crates
  against wall, wall-mounted chains.
- **Boss arena**: No loose objects. Architectural features only: wide arch
  framing entrance, inlaid angular floor pattern (containment diagram), iron
  anchor points in floor.
- **Hub**: Densest in game (8-12 props). Lived-in, functional (workbench,
  bookshelf, cooking apparatus). Visual warmth through density — contrast
  with dungeon sparsity is intentional.

### Environmental Storytelling

Three stories, readable at different engagement depths:

**Story 1 — Operational history** (first pass, no investment):
Drainage channels, iron anchor points at regular intervals, numbered markings
on doorway lintels (1-3px symbols, consistent per floor), badly-matched repair
stone. Something administered this place.

**Story 2 — Who came before** (engaged players who pause):
Scorch marks that match no current enemy. A single abandoned card (face-down,
shattered — rare prop, one per run max). Broken equipment from a different
style. Dried blood on walls, not floors (floors are cleaned).

**Story 3 — What the dungeon is for** (repeated runs, pattern recognition):
Boss arena containment diagram is the same symbol every floor, scaled
differently. Drainage channels slope toward a shared direction. Numbered
doorway markings follow a decodable system. The dungeon was organized by
function. Procedural room selection preserves this — curated pool with marking
system embedded.

**What the dungeon does NOT communicate:** Romance, beauty, or wonder. Overt
evil (no skulls, no theatrical malice). The player's importance (the dungeon
doesn't know they're there).

---

## 7. UI/HUD Visual Direction

### Diegetic vs. Screen-Space

**Hybrid — Grounded Screen-Space.** HUD is not in the game world but shares
its visual register (Dungeon Stone fills, Hand White values, angular geometry).
Feels "of" the dungeon without being "in" it.

The card hand is the one exception: cards launch into combat space on play
(briefly enters the world), then resolve back to screen-space. The hand is
never obscured by enemies, VFX, or environment — it occupies the highest
screen-space z-layer above all in-world effects.

**HUD layout:**
- Top-left: HP corner bracket
- Bottom-right: Deck count + discard count corner bracket
- Center-bottom: Card hand arc
- No additional HUD elements without a readability gate review

### Typography

**Humanist condensed sans-serif (vector, NOT pixel font).** Zero-flourish,
slightly angular to echo chamfered card geometry. Vector for variable display
scale — pixel fonts produce jagged letterforms at non-integer scales.

| Level | Use | Style | Size |
|-------|-----|-------|------|
| Display | Boss names, screen titles | Condensed bold, all-caps, +0.05em spacing | 28-36px |
| Card Name | Card face text | Condensed medium, title case | 11-12px |
| Body/Rules | Card effect text, descriptions | Condensed regular, sentence case | 10px min |
| HUD Numeric | HP, deck count, damage numbers | Tabular monospaced figures, bold | 10-14px |

**HUD Numeric uses tabular figures** — all numerals same width. Prevents HP
readout width-jitter during combat.

**Damage numbers**: Float upward from hit point. Color per semantic system
(Combat Ember for player damage, Harsh Red for incoming, Life Green for heal).
Scale up 1.15x on appear, float and fade. Crits: 1.4x scale + white flash.

**Contrast**: All text WCAG AA minimum (4.5:1 against background).

### Iconography Style

**Outlined pixel icons with flat archetype fill. No illustration, no gradient.**

1. **Silhouette test**: Cover the fill. Outline alone must communicate concept.
2. **Two-color max**: Void outline (`#111318`) + one archetype fill. Third
   value (highlight dot) allowed for Uncommon+ rarity only.
3. **45-degree diagonals only** for non-cardinal lines at 16x16. No 30/60-degree
   angles (aliased noise at this scale).
4. **Shape vocabulary per archetype**: Aggression = acute outward angles.
   Defense = horizontal mass, vertical symmetry. Mobility = directional arrow.
   Control = enclosed concentric forms. Recovery = upward-opening curves.
5. **Icon scale**: 60-70% of card face area. At 32x32 card, icon renders at
   20x20 centered with 6px clear edge.
6. **Status effect icons**: 8x8 for HUD bars. Shape-only at this scale (text
   not viable). Colorblind-safe backup per Section 4.

**Forbidden:** Gradient fills, illustrated detail, text within icons, icons
sharing outline silhouette across archetypes.

### UI Animation Feel

**Weight = overshoot and settle. Flux = fast onset and extended trail.**

**Card enter (deal into hand):** Each card travels along short arc from
off-screen below. 80ms per card, staggered 60ms. Fast onset (20% duration),
slow settle with 2-3px overshoot then 20ms snap-back. Cards feel like they
have mass.

**Card exit (play):** Fast linear toward enemy, 60ms. No overshoot — committed.
Card doesn't float or drift; it goes. Gap remains in hand arc after play
(cost is visible). Remaining cards don't re-center until VFX resolves.

**Card exit (discard):** Downward to discard position, 100ms simultaneous,
ease-out. No drama — administrative. Distinction from play: toward enemy =
commitment; downward = cycling.

**Card hover:** Rises 6px above arc baseline, 50ms ease-out. Scales 1.15x.
Adjacent cards shift 8px away (focus pull). Archetype ambient glow activates.
No bounce — hover is decision, not commitment.

**Reward screen:** Cards rise from below, 200ms staggered 120ms, 4px overshoot.
Background desaturates simultaneously. On hover, room shifts toward archetype
color temperature (300ms lerp — state-gated, never bleeds into combat).

**Menu navigation:** Items slide from right, staggered 40ms. Selected item
shifts right 8px with bracket indicator. No scale change — menus aren't combat.

**Death screen:** No animation beyond desaturation cascade. Cards exit downward
individually, staggered 100ms — the slowest card exit in the game.

**System-wide rules:**
- No looping idle animations on UI chrome during combat (motion = information)
- Rarity particles are the sole exception (on cards, not chrome)
- All UI animation is interruptible — never gates input behind motion
- No animation exceeds 300ms unless it's a deliberate dramatic beat

---

## 8. Asset Standards

### Sprite Specifications

**Format:** Single-row PNG strips, one file per animation state. Horizontal,
left-to-right frame order. RGBA 8-bit. Fully transparent background. No
padding between frames or at edges. Frame 0 = start frame.

**Entity dimensions:**

| Entity | Canvas/Frame | Tile Footprint | Notes |
|--------|-------------|----------------|-------|
| Player | 32x32 | 2x2 tiles | Highest silhouette complexity |
| Standard Enemy | 32x32 | 2x2 tiles | Matches player footprint |
| Elite Enemy | 32x48 | 2x3 tiles | Taller = threat escalation |
| Boss | 64x64 | 4x4 tiles | Monumental; separate SpriteFrames resource |

**Player animation strips:**

| State | Frames | Strip Size |
|-------|--------|-----------|
| `idle` | 4 | 128x32 |
| `walk` | 6 | 192x32 |
| `windup` | 3 | 96x32 |
| `active` | 2 | 64x32 |
| `recovery` | 3 | 96x32 |
| `death` | 5 | 160x32 |
| `hurt` | 2 | 64x32 |

**Playback reference:**

| State | Loop | FPS |
|-------|------|-----|
| `idle` | Loop | 8 |
| `walk` | Loop | 10 |
| `windup` | Play-once, hold last | 12 |
| `active` | Play-once | 12 |
| `recovery` | Play-once, return to idle | 10 |
| `death` | Play-once, hold last | 8 |
| `hurt` | Play-once, return to idle | 12 |

Bosses additionally require: `phase_transition` (min 6 frames) and
`idle_phase2` (distinct silhouette from phase 1 idle).

### Tile Specifications

- Canvas: 16x16 pixels per tile
- RGBA 8-bit, fully transparent background
- Delivered as single PNG atlas, rows of 8 tiles
- One atlas per material (do not mix materials)

**Materials and variants:**

| Material | Variants | Autotile | Usage |
|----------|----------|----------|-------|
| Dungeon Stone | 4 | Terrain bitmask (47-tile or 16-tile minimal) | Primary floor/wall |
| Reinforced Stone | 3 | Terrain bitmask | Structural, boss arena |
| Worn Flagstone | 3 | Terrain bitmask | Corridors, older rooms |

**Atlas layout** (top-to-bottom rows):
1. Base terrain tiles (autotile bitmask set)
2. Variant 1 surface noise overlays (transparent, layered)
3. Variant 2 surface noise overlays
4. Decorative dressing (cracks, stains — non-autotile)
5. Animated tile frames (4-frame min, left-to-right)

All tile colors derived from Section 4 primary palette. No hues outside the
color system.

### Card Art Specifications

**Card frame:** 40x56 pixels. Chamfered rectangle border (45-degree corner
cuts). 2px border thickness. Interior usable area: 36x52.

**Icon area:** 24x24, centered horizontally, 4px from interior top. 24px
vertical space below for name/cost (authored by UI programmer).

**Icon rules:** Must read archetype from silhouette at 24x24. Must read at
12x12 (deck viewer). Max 3 hues, dominant must match archetype color. No text
or numerals in icon.

**Rarity borders** (separate overlay PNGs over base frame):

| Rarity | Border | Animation | Particles |
|--------|--------|-----------|-----------|
| Common | Hand White, flat | None — static | None |
| Uncommon | Steel `#A8C4D4` | 2-frame shimmer, 1.5s cycle | None |
| Rare | Kinetic Gold | 4-frame shimmer, 1.0s cycle | 2-4 orbiting (CPUParticles2D) |
| Legendary | Boss Violet + 1px white inner glow | 6-frame shimmer, 0.8s cycle | Full particle field |

**Export format:**
- `card_frame_[rarity].png` — 40x56 static
- `card_icon_[name].png` — 24x24 static
- `card_border_[rarity]_shimmer.png` — single-row strip
- Source: `.ase` files in `assets/source/card/`

### VFX Specifications

**Particle vs. sprite decision:**

| Effect | System | Rationale |
|--------|--------|-----------|
| Hit impact (melee/ranged) | CPUParticles2D | Trivial emitter, no unique shape |
| Status application | CPUParticles2D | Radial burst |
| Healing pulse | CPUParticles2D | Upward particles (colorblind backup) |
| Card hand ambient glow | CPUParticles2D | Low-emission continuous, always-on |
| Boss floor pulse | Shader on tile layer | Delegated to technical-artist |
| Death desaturation | Shader / CanvasLayer | Delegated to technical-artist |
| Card ability effects (slash, fireball, dash trail) | Animated sprite | Shape is load-bearing |
| Rarity particles | CPUParticles2D | Simple orbit/field |

**CPUParticles2D budget:**

| Context | Max Emitters | Max Particles/Emitter |
|---------|-------------|----------------------|
| Combat | 6 | 40 |
| Card hand ambient (counts as 1) | 1 of 6 | 12 |
| Reward/draft screen | 4 | 20 |
| Hub/menu | 2 | 30 |

Effective combat VFX budget = 5 emitters (hand ambient always costs 1).
Programmer enforces via emitter pool — new emitters wait, never exceed cap.

**Animated sprite VFX:** Same strip format as characters. Canvas must be
multiple of 16x16. 4-12 frames. Play-once (no looping VFX in combat). 12 fps.

### File Format and Naming

**Formats:** PNG (RGBA 8-bit) for all deliverables. Aseprite (.ase) for source.
No JPEG, no indexed PNG, no WebP.

Source files: `assets/source/[category]/`
Final exports: `assets/art/[category]/`

**Naming pattern:** `[category]_[name]_[state].[ext]` — all snake_case.

| Prefix | Type |
|--------|------|
| `char_` | Player and enemy sprites |
| `env_` | Tiles and tilesets |
| `card_` | Card frames, icons, borders |
| `ui_` | HUD elements, buttons |
| `vfx_` | VFX animated strips |

Examples:
```
char_player_idle.png
char_enemy_melee_grunt_idle.png
char_boss_floor1_phase_transition.png
env_dungeon_stone_tileset.png
card_frame_rare.png
card_icon_strike.png
card_border_uncommon_shimmer.png
ui_hud_health_bracket.png
vfx_hit_impact_slash.png
```

### Resolution and Scaling

**Base viewport:** 384x216 (Godot 4.6)

| Display | Scale | Notes |
|---------|-------|-------|
| 1080p | 5x (integer) | Primary target |
| 4K | 10x (integer) | Clean |
| 1440p | Letterbox at 6x (2304x1296) | Black bars, never stretch |
| 720p | Letterbox at 3x (1152x648) | Black bars |

**Godot project settings:**
```
Viewport Width:  384
Viewport Height: 216
Stretch Mode:    viewport
Stretch Aspect:  keep
```

**Pixel-perfect rules:**
1. Integer scale only. Never fractional viewport scaling.
2. Letterbox at non-integer resolutions. Never stretch to fill.
3. **Nearest-neighbor mandatory** — every texture: Filter = Nearest, Mipmaps = Off.
4. Camera snaps to integer pixel positions (floor() per frame).
5. No fractional sprite scaling. UI hover magnification uses integer steps
   only (1x, 2x). Exception: card hover at 1.15x is the sole allowed
   non-integer scale (within UI layer only, not gameplay sprites).

---

## 9. Reference Direction

Five references, each pulling from a distinct visual dimension. No two point
in the same direction.

### 1. Hades (Supergiant Games)

**Draw from:** Combat room ground plane treatment. Dark, low-value floor that
never competes with character reads. 2-3 zone value floor with accent detail
confined to room edges, never center. Apply this discipline to Dungeon Stone
tiles.

**Diverge from:** Hades's decorative warmth — saturated gold, burgundy, teal
that communicates Mediterranean mythology and beauty. Deckslinger's dungeon
communicates administrative hostility. No warmth, no decoration for its own
sake. Hades makes beautiful dungeons. Deckslinger makes functional ones.

### 2. Slay the Spire (MegaCrit)

**Draw from:** Card icon legibility at small scale. Every icon reads intent
from silhouette alone — strike is a sword diagonal, defend is a shield wall.
High shape contrast against flat-fill interior, single accent value. Icon
language does classification before text. Apply to Deckslinger's 24x24 icons:
silhouette-first authoring, then color, never illustration.

**Diverge from:** Painterly illustrative card art and rounded-rectangle card
proportions. At 40x56 there is no room for illustration. Deckslinger uses
outlined pixel icons and chamfered corners that signal danger, not soft game
feel.

### 3. Darkest Dungeon (Red Hook Studios)

**Draw from:** Held-pose animation methodology. Very low frame count, each
pose held for enough ticks that the player reads full weight and commitment.
Active attack frame held through hit-stop — 2-3 frames feel definitive.
Directly supports Deckslinger's "stiff with purpose, not smooth with fidelity"
direction.

**Diverge from:** Gothic horror visual register — crumbling organic
architecture, tentacles, religious iconography, body horror. Deckslinger's
dungeon is angular and administrative. No organic architecture, no symbolic
decoration. Also diverge from full-screen character portraiture — Deckslinger
operates at 32x32 with silhouette-only expression.

### 4. Risk of Rain 2 (Hopoo Games)

**Draw from:** Silhouette readability under particle chaos. Each character
maintains one highly distinctive geometric feature that no other shares —
readable even when surrounded by VFX. This is the design source for
Deckslinger's permanent asymmetric identifier and the "one dominant
protrusion" rule. Study how Hopoo maintains that one feature across every
animation state.

**Diverge from:** Scale and particle density. Risk of Rain 2 uses visual
density as spectacle. Deckslinger uses visual economy as readability. Every
particle must earn its slot within the 6-emitter budget. Any reference must be
filtered through that constraint.

### 5. Mark Ferrari (Sierra On-Line era pixel art)

**Draw from:** Limited-hue environmental lighting through palette cycling.
2-3 contiguous hue steps imply a light source rather than blending across
the full spectrum. Apply to Deckslinger's state-transition lighting — the
cool-to-warm shift between exploration and combat should read as a discrete
temperature step, not a gradient. Palette discipline forces legibility.

**Diverge from:** The nostalgia register that pixel art often activates.
Deckslinger's pixel art must not signal nostalgia or charm. The same palette
economy is a technical tool, not a stylistic homage. The dungeon does not
invite warmth toward itself.
