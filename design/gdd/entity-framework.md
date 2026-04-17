# Entity Framework

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: All (foundation infrastructure)

## Summary

The Entity Framework defines the base object model for all game-world objects
in Deckslinger — the player character, enemies, bosses, projectiles, and
interactive props. It provides a composition-based architecture using Godot's
node/scene system, establishing the contracts that Combat, Animation,
Collision, Enemy AI, and Dungeon Generation all build on. It owns no gameplay
logic itself; it defines the shared structure that gameplay systems attach to.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

The Entity Framework is the foundational data layer for every object that
exists in the game world. It defines what a "game entity" is: a scene composed
of typed component nodes (health, hitbox, animation, movement) that gameplay
systems can query and interact with. The player never sees or interacts with
the Entity Framework directly — they interact with combat, cards, and enemies,
all of which are built on top of it. The framework's job is to guarantee that
any system asking "what entities are in this room?" or "does this entity have
health?" gets a reliable, typed answer. Without it, every gameplay system
would need to know the internal structure of every other system's objects,
creating brittle coupling that breaks as the game grows.

## Player Fantasy

This system has no direct player fantasy — players never engage with the
Entity Framework consciously. Its contribution is felt through what it
enables: distinct enemy silhouettes that read instantly (Pillar 3: Adapt or
Die), responsive character actions that commit and resolve cleanly (Pillar 1:
Every Card Is a Commitment), and a world populated with objects that behave
consistently and predictably. When the Entity Framework works, the player
never thinks about it. When it fails, every system built on top of it feels
broken.

## Detailed Design

### Core Rules

**C.1 — Composition Model**

An entity is a Godot scene rooted at an `EntityBase` node
(`class_name EntityBase extends Node2D`). `EntityBase` owns exactly two
things: the entity's `EntityType` enum value and its current
`EntityLifecycleState`. Everything else is a component.

Entity types:

| EntityType | Sprite Canvas | Description |
|---|---|---|
| `PLAYER` | 32x32 | The player character. Exactly one per room. |
| `STANDARD_ENEMY` | 32x32 | Melee or ranged enemies with telegraphed attacks. |
| `ELITE_ENEMY` | 32x48 | Enhanced enemies that break one visual rule. |
| `BOSS` | 64x64 + protrusions | Multi-phase encounter entities. |
| `PROJECTILE` | Varies (8x8 to 16x16) | Card-spawned traveling objects. No health, no AI. |
| `PROP` | Varies | Interactive dungeon objects (chests, interactables). |

**C.2 — Base Component Set**

Components are child nodes of `EntityBase`. Each has a `class_name`. Systems
locate components via typed `get_node_or_null()`. A missing component means
the entity does not support that behavior — legal state, not an error.

| Component | class_name | Required For | Description |
|---|---|---|---|
| Health | `HealthComponent` | PLAYER, all enemies, PROP (optional) | Current HP, max HP. Exposes take_damage(), heal(). Emits on change/death. |
| Hitbox | `HitboxComponent` | All combat participants | What this entity can hit others with. |
| Hurtbox | `HurtboxComponent` | All combat participants | Where this entity can be hit. |
| Movement | `MovementComponent` | PLAYER, all enemies | Velocity, facing direction, movement constraints. |
| Animation | `AnimationComponent` | PLAYER, all enemies | Animation state machine reference. Receives state change requests. |
| AI Behavior | `AIBehaviorComponent` | All enemies | Attachment point for behavior trees or state machines. |
| Status Effects | `StatusEffectComponent` | PLAYER, all enemies | Hosts active status effects. Ticked each physics frame. |
| Faction | `FactionComponent` | All entities with health | Tags entity as PLAYER, ENEMY, or NEUTRAL for target filtering. |

No component is hardcoded mandatory at `EntityBase` level. Validation happens
in each entity's `_ready()` via assertion (debug builds only).

**C.3 — Entity Creation and Destruction**

Creation (by Dungeon Generation or card effects):
1. Instantiate packed scene
2. Set spawn position
3. Call `entity.activate()` when entity should become interactive

Destruction (two-step):
1. `entity.die()` — triggers DYING state. Death animation plays.
   Non-interactive but still in scene tree.
2. `entity.despawn()` — called by entity itself after death behavior
   completes. Removes via `queue_free()`. Room Encounter System listens
   to `despawned` signal for enemy counts and reward triggers.

Projectiles skip DYING — call `despawn()` directly on collision or timeout.

### States and Transitions

**Entity Lifecycle State Machine**

| State | Description | Entry | Exit |
|---|---|---|---|
| `INACTIVE` | Instantiated but not placed. Invisible, no physics/AI. | Initial state | `activate()` called |
| `SPAWNING` | Visible, spawn animation plays. Hurtbox off, hitbox off. | `activate()` | Spawn animation complete signal |
| `ACTIVE` | Normal operation. All components tick. | Spawn complete | HP reaches 0 or `die()` called |
| `STUNNED` | Movement/AI paused. Hurtbox remains on. Stun animation plays. | Stun status applied | Stun timer expires or cleared |
| `DYING` | Death animation plays. All boxes off, AI off. Still in scene. | HP = 0 | Death animation complete |
| `DEAD` | Terminal. Exists only in frame between DYING and queue_free. | DYING complete | queue_free() |

Valid transitions:
```
INACTIVE  -> SPAWNING  (activate())
SPAWNING  -> ACTIVE    (spawn animation complete)
ACTIVE    -> STUNNED   (stun status applied)
ACTIVE    -> DYING     (HP = 0 or die() called)
STUNNED   -> ACTIVE    (stun cleared)
STUNNED   -> DYING     (HP = 0 while stunned)
DYING     -> DEAD      (death animation complete)
```

Illegal transitions (logged as errors in debug): Any -> INACTIVE, DEAD -> any,
DYING -> STUNNED. EntityBase owns state machine privately. External systems
read via `get_lifecycle_state()`, trigger via public methods only.

### Interactions with Other Systems

**Animation State Machine:**
- Subscribes to `lifecycle_state_changed(old_state, new_state)` signal
- Reads `MovementComponent` facing/velocity for locomotion
- AnimationComponent maps lifecycle states to animation playback

**Collision/Hitbox System:**
- Reads `HitboxComponent` and `HurtboxComponent` directly (not through EntityBase)
- `HitboxComponent` owns valid target factions (set at creation, immutable)
- On valid collision: `hurtbox.receive_hit(hit_data: HitData)`
- HurtboxComponent internally calls `health_component.take_damage()`

**Combat System:**
- Reads/writes through `HealthComponent`:
  - `take_damage(amount: int, source: EntityBase) -> void`
  - `heal(amount: int) -> void`
  - `get_current_hp() -> int`, `get_max_hp() -> int`, `get_hp_fraction() -> float`
- Signals: `health_changed(old_hp, new_hp, source)`, `died(entity)`

**Enemy AI System:**
- Attaches to `AIBehaviorComponent`:
  - `set_behavior(behavior: AIBehavior) -> void`
  - `get_target() -> EntityBase`
  - `is_active() -> bool` (false when STUNNED or DYING)
- Reads MovementComponent for execution, AnimationComponent for timing

**Dungeon Generation:**
- Reads `entity_type` (read-only, set at scene definition)
- Calls `activate()` when room is entered
- Listens to `despawned(entity)` signal for cleanup tracking
- Never reads health or AI state

**Status Effect System:**
- Attaches to `StatusEffectComponent`:
  - `apply_effect(effect: StatusEffect) -> void`
  - `remove_effect(effect_id: StringName) -> void`
  - `has_effect(effect_id: StringName) -> bool`
  - `get_active_effects() -> Array[StatusEffect]`
- Stun specifically calls `entity.set_stunned(true)` on EntityBase

## Formulas

The Entity Framework has no gameplay math. It defines structural contracts,
not calculations. Damage, health scaling, and spawn curves belong to Combat,
Enemy AI, and Dungeon Generation respectively.

**Cross-system constants** (canvas sizes constrain Collision and Animation):

| Entity Type | Sprite Canvas | Collision Footprint | Rationale |
|---|---|---|---|
| PLAYER | 32x32 px | 16x16 px (centered, lower half) | 50% ratio — arms/weapons extend beyond hittable body |
| STANDARD_ENEMY | 32x32 px | 16x16 px (centered, lower half) | Matches player for perceived fairness |
| ELITE_ENEMY | 32x48 px | 16x20 px (centered, lower half) | Larger body, taller footprint for wider threat |
| BOSS | 64x64 px | 32x32 px (body only) | Protrusions are visual, not hittable by default |
| PROJECTILE | 8x8 to 16x16 px | Matches sprite bounds | Small = generous to player |
| PROP | Art-defined | Art-defined | Set per prop in scene |

Collision footprint is always smaller than sprite canvas — pixel art characters
have visual mass that extends beyond the gameplay-relevant body. The ~50% ratio
ensures the player never feels hit by pixels they shouldn't have been hit by.

## Edge Cases

- **If `take_damage()` during SPAWNING**: Ignore. Entities are invulnerable
  during spawn animation. Prevents spawn-camping.
- **If `take_damage()` during DYING**: Ignore. Entity is already dying.
- **If `die()` on entity with no HealthComponent** (e.g., prop): Transition
  directly to DYING. Props can be destroyed without health tracking.
- **If two `take_damage()` calls in the same physics frame**: Process
  sequentially. First may trigger death; second is ignored (now DYING).
- **If status effect applied during INACTIVE or SPAWNING**: Reject. Status
  effects only apply to ACTIVE or STUNNED entities.
- **If player entity despawns while enemies remain**: Run-ending event
  (death). Room Encounter System handles consequence; Entity Framework emits
  `despawned` signal as usual.
- **If BOSS phase transition triggers while STUNNED**: Clear stun, return to
  ACTIVE, then execute phase transition. Bosses cannot be stun-locked through
  phase boundaries.
- **If death animation exceeds `death_animation_timeout`**: Force-despawn.
  Safety valve prevents stuck entities blocking room completion.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | None | Root dependency | — |
| Downstream | Animation State Machine | `lifecycle_state_changed` signal | Hard |
| Downstream | Collision/Hitbox System | HitboxComponent, HurtboxComponent nodes | Hard |
| Downstream | Combat System | HealthComponent methods and signals | Hard |
| Downstream | Enemy AI System | AIBehaviorComponent, MovementComponent | Hard |
| Downstream | Dungeon Generation | activate(), despawned signal, entity_type | Hard |
| Downstream | Status Effect System | StatusEffectComponent, set_stunned() | Hard |

All downstream dependencies are hard — these systems cannot function without
the Entity Framework's contracts.

## Tuning Knobs

| Knob | Default | Range | Effect |
|------|---------|-------|--------|
| `spawn_invulnerability_frames` | 30 (0.5s @ 60fps) | 0–120 | Duration of SPAWNING invulnerability. Too low = spawn camping. Too high = player waits. |
| `death_animation_timeout` | 180 (3.0s @ 60fps) | 60–600 | Max frames before force-despawn if death animation hangs. Safety valve. |
| `stun_max_duration` | 300 (5.0s @ 60fps) | 0–600 | Hard cap on any stun duration. Prevents infinite stun-lock exploits. |

## Acceptance Criteria

1. **GIVEN** entity in INACTIVE, **WHEN** `activate()` called, **THEN**
   transitions to SPAWNING and becomes visible within 1 frame.
2. **GIVEN** entity in SPAWNING, **WHEN** `take_damage()` called, **THEN**
   damage ignored, HP unchanged.
3. **GIVEN** entity in ACTIVE with 10 HP, **WHEN** `take_damage(10)` called,
   **THEN** HP = 0, `died` signal emits, transitions to DYING.
4. **GIVEN** entity in DYING, **WHEN** death animation completes, **THEN**
   `despawned` signal emits, entity removed via queue_free().
5. **GIVEN** entity missing HealthComponent, **WHEN** `die()` called, **THEN**
   transitions to DYING without error.
6. **GIVEN** BOSS in STUNNED, **WHEN** phase transition triggers, **THEN**
   stun cleared, returns to ACTIVE, then executes phase transition.
7. **GIVEN** two entities of different factions, **WHEN** hitbox overlaps
   hurtbox, **THEN** damage applied only if factions are hostile.
8. **GIVEN** any entity, **WHEN** `get_lifecycle_state()` called, **THEN**
   returned state matches actual component active/inactive behavior.
9. **GIVEN** entity in DYING for > `death_animation_timeout` frames, **WHEN**
   timeout expires, **THEN** force-despawn triggers.
10. **GIVEN** entity in ACTIVE, **WHEN** stun effect applied, **THEN**
    transitions to STUNNED, movement/AI stop, hurtbox remains on.

## Open Questions

- **Component discovery pattern**: Should systems use `get_node_or_null()` with
  a known path, or should EntityBase expose typed getters (e.g.,
  `get_health_component()`)? Typed getters are safer but add coupling to
  EntityBase. → Becomes an ADR decision.
- **Entity pooling**: Should frequently spawned entities (projectiles, standard
  enemies) use object pooling instead of instantiate/queue_free? Performance
  profiling during prototype will determine. → Defer to prototype findings.
- **Multi-scene bosses**: Boss protrusions (tell limbs) may need to be separate
  scenes parented to the boss EntityBase. Exact composition TBD in Boss System
  GDD.
