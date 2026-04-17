# Status Effect System

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 2 (Your Deck Is Your Identity), Pillar 3 (Adapt or Die)

## Summary

The Status Effect System manages buffs, debuffs, and damage-over-time effects
applied to entities during combat. It hosts active effects on each entity's
StatusEffectComponent, ticks their timers and periodic damage, handles stacking
rules, and provides the modifier interface that the Combat System queries for
damage calculation.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Combat System, Card Data System`

## Overview

The Status Effect System is the glue that turns individual card plays into
strategic combos. A Drifter card that applies SLOW to an enemy is useful alone
but becomes powerful when followed by a Gunslinger card that deals bonus damage
to slowed targets. The system manages a registry of defined status effects
(each with type, duration, tick behavior, and stacking rules), applies them
to entities via the StatusEffectComponent (defined in Entity Framework), ticks
active effects each physics frame, removes expired effects, and exposes query
methods so the Combat System can read active modifiers. It does not decide when
effects are applied — that comes from card effects (via Combat System) and
enemy attacks. It only manages the lifecycle of effects once they exist.

## Player Fantasy

Status effects are the player's toolkit for controlling the battlefield. When
an enemy glows red with BURN, the player knows damage is ticking away. When an
enemy slows to a crawl with SLOW, the player feels the space they've created.
When the player stacks VULNERABLE on a boss and then lands a crit, the damage
number explodes. Status effects are visible, readable, and consequential —
never invisible modifiers that the player can't perceive. Each effect has a
distinct visual indicator (icon + color tint on the affected entity) so the
player always knows the battlefield state at a glance.

## Detailed Rules

### Status Effect Registry

**SR.1 — StatusEffectData Resource**

Each status effect type is a Godot Resource (`class_name StatusEffectData extends Resource`):

| Field | Type | Description |
|-------|------|-------------|
| `effect_id` | `StringName` | Unique identifier (e.g., `"burn"`, `"slow"`) |
| `display_name` | `String` | Player-facing name |
| `description` | `String` | Rules text |
| `effect_category` | `EffectCategory` enum | BUFF, DEBUFF, DOT, CONTROL |
| `stacking_rule` | `StackingRule` enum | REFRESH, INTENSITY, INDEPENDENT, NONE |
| `max_stacks` | `int` | Max stack count (for INTENSITY stacking) |
| `tick_interval_frames` | `int` | Frames between periodic ticks (0 = no periodic effect) |
| `tick_damage` | `int` | Damage per tick (for DOT effects) |
| `modifier_type` | `ModifierType` enum | VULNERABILITY, RESISTANCE, SPEED, DAMAGE, NONE |
| `modifier_value` | `float` | Modifier multiplier (e.g., 1.5 for VULNERABILITY) |
| `icon` | `Texture2D` | Status icon for HUD display (16×16 px) |
| `tint_color` | `Color` | Color tint applied to affected entity sprite |

**SR.2 — MVP Status Effects**

| effect_id | Category | Stacking | Tick | Modifier | Description |
|-----------|----------|----------|------|----------|-------------|
| `burn` | DOT | REFRESH | 30 frames (0.5s) | NONE | Deals `tick_damage` per tick. Duration refreshed on reapply. |
| `poison` | DOT | INTENSITY | 60 frames (1.0s) | NONE | Deals `tick_damage × stacks` per tick. Stacks add to damage, not duration. Max 5 stacks. |
| `slow` | DEBUFF | REFRESH | 0 | SPEED × 0.5 | Reduces movement speed by 50%. Duration refreshed on reapply. |
| `vulnerable` | DEBUFF | REFRESH | 0 | VULNERABILITY × 1.5 | Increases damage taken by 50% (read by Combat System). Duration refreshed. |
| `stun` | CONTROL | NONE | 0 | NONE | Prevents all actions. Triggers Entity Framework STUNNED state. Cannot stack. |
| `shield` | BUFF | REFRESH | 0 | NONE | Absorbs damage before HP. Shield HP tracked separately. Duration refreshed. |
| `haste` | BUFF | REFRESH | 0 | SPEED × 1.5 | Increases movement speed by 50%. Duration refreshed. |

### Stacking Rules

**STK.1 — Stacking Behaviors**

| StackingRule | Behavior | Example |
|-------------|----------|---------|
| `REFRESH` | Reapplying resets duration to max. Only one instance exists. | Burn: reapply refreshes timer but doesn't increase damage. |
| `INTENSITY` | Each application adds a stack (up to `max_stacks`). Duration is per-stack. Each stack has its own timer. | Poison: each stack adds tick_damage. Stack 1 may expire while stack 3 is still active. |
| `INDEPENDENT` | Each application is a separate instance with its own timer. | Reserved for future complex effects. |
| `NONE` | Cannot be reapplied while active. Second application is rejected. | Stun: cannot stun-stack. Must wait for stun to clear. |

**STK.2 — Stack Resolution**

For INTENSITY stacking:
- Each stack is tracked independently with its own remaining duration
- When a stack expires, it is removed. Other stacks continue.
- The effect's magnitude scales with current stack count
- New application adds a stack (if below max) and sets its duration

### Effect Lifecycle

**EL.1 — Application**

```
1. Source (Combat System) calls StatusEffectComponent.apply_effect(effect_id, duration_frames)
2. StatusEffectComponent looks up StatusEffectData from registry
3. Check stacking rules:
   a. REFRESH: reset duration, keep effect
   b. INTENSITY: add stack if below max, set stack duration
   c. INDEPENDENT: create new instance
   d. NONE: reject if already active
4. If new effect: emit effect_applied(effect_id)
5. Visual: apply tint_color to entity sprite, show icon in HUD
```

**EL.2 — Ticking**

Each physics frame, StatusEffectComponent iterates active effects:

```
For each active effect:
  1. Decrement duration (or per-stack durations for INTENSITY)
  2. If tick_interval_frames > 0 and interval has elapsed:
     a. Apply tick effect (DOT: call CombatSystem.apply_dot_tick())
     b. Reset tick counter
  3. If duration <= 0 (or all stacks expired for INTENSITY):
     a. Remove effect
     b. Emit effect_expired(effect_id)
     c. Remove visual indicators
```

**EL.3 — Removal**

Effects are removed when:
- Duration expires naturally
- Explicitly cleansed (by a card effect or encounter end)
- Entity dies (all effects cleared)
- Entity enters DYING lifecycle state

**EL.4 — Encounter Boundary**

All status effects are cleared at encounter end. No effects persist between
rooms. This keeps each encounter self-contained.

### Modifier Interface

**MI.1 — Combat System Queries**

The Combat System queries StatusEffectComponent for active modifiers during
damage calculation:

```gdscript
func get_damage_taken_multiplier() -> float  # combines VULNERABILITY/RESISTANCE
func get_speed_multiplier() -> float          # combines SPEED modifiers
func get_damage_dealt_multiplier() -> float   # combines DAMAGE modifiers
func has_effect(effect_id: StringName) -> bool
func get_stack_count(effect_id: StringName) -> int
func get_active_effects() -> Array[StatusEffectInstance]
```

Multiple modifiers of the same type stack multiplicatively:
```
If entity has VULNERABLE (×1.5) and another VULNERABLE-type effect (×1.25):
  total = 1.5 * 1.25 = 1.875
```

In MVP, only one instance of each modifier type exists at a time (no
overlapping vulnerability sources), but the system supports multiplicative
stacking for future extensibility.

### Shield Mechanic

**SH.1 — Shield Behavior**

Shield is a special buff that absorbs damage:

```
1. Damage hits entity with active shield
2. Combat System checks: has_effect("shield")?
3. If yes: subtract damage from shield HP first
   remaining_damage = max(damage - shield_hp, 0)
   shield_hp = max(shield_hp - damage, 0)
4. If shield_hp reaches 0: shield effect is removed (broken)
5. Remaining damage (if any) applies to entity HP normally
```

Shield HP is tracked as a separate value on the StatusEffectComponent, not
as part of HealthComponent. Shield does not stack — reapplication refreshes
duration and sets shield HP to the new value (does not add).

### Stun Integration

**SI.1 — Stun Application**

When `stun` effect is applied:
1. StatusEffectComponent applies the effect
2. StatusEffectComponent calls `entity.set_stunned(true)` (Entity Framework)
3. Entity lifecycle transitions to STUNNED
4. Animation State Machine plays STUNNED animation

When `stun` expires:
1. StatusEffectComponent removes the effect
2. StatusEffectComponent calls `entity.set_stunned(false)`
3. Entity lifecycle transitions back to ACTIVE
4. Animation State Machine returns to IDLE

Stun cannot be reapplied while active (NONE stacking rule). The entity must
fully recover from stun before being stunned again. This prevents stun-lock.

## Formulas

**F.1 — DoT Total Damage**

```
Variables:
  tick_damage      = base damage per tick
  stacks           = current stack count (1 for non-INTENSITY)
  tick_interval    = frames between ticks
  total_duration   = total effect duration in frames
  vulnerability    = target's damage taken multiplier

Output:
  damage_per_tick  = damage dealt each tick
  total_ticks      = number of ticks over full duration
  total_damage     = cumulative damage

Formula:
  damage_per_tick = max(floor(tick_damage * stacks * vulnerability), 1)
  total_ticks = floor(total_duration / tick_interval)
  total_damage = damage_per_tick * total_ticks

Example (Burn: 3/tick, 30-frame interval, 180-frame duration, no modifiers):
  damage_per_tick = max(floor(3 * 1 * 1.0), 1) = 3
  total_ticks = floor(180 / 30) = 6
  total_damage = 3 * 6 = 18

Example (Poison: 2/tick, 3 stacks, 60-frame interval, 300 frames):
  damage_per_tick = max(floor(2 * 3 * 1.0), 1) = 6
  total_ticks = floor(300 / 60) = 5
  total_damage = 6 * 5 = 30
```

**F.2 — Speed Modifier Calculation**

```
Variables:
  base_speed        = entity's base movement speed
  speed_multipliers = array of all active SPEED modifiers

Output:
  final_speed = modified movement speed

Formula:
  combined_mult = product of all speed_multipliers
  combined_mult = clamp(combined_mult, MIN_SPEED_MULT, MAX_SPEED_MULT)
  final_speed = base_speed * combined_mult

Example (SLOW active: ×0.5):
  combined_mult = 0.5
  final_speed = base_speed * 0.5

Example (SLOW + HASTE: ×0.5 × 1.5):
  combined_mult = 0.75
  final_speed = base_speed * 0.75  (net 25% slow)
```

**F.3 — Shield Damage Absorption**

```
Variables:
  incoming_damage = damage from Combat System (after all modifiers)
  shield_hp       = current shield HP

Output:
  absorbed        = damage absorbed by shield
  remaining       = damage passed through to HP
  new_shield_hp   = updated shield HP

Formula:
  absorbed = min(incoming_damage, shield_hp)
  remaining = incoming_damage - absorbed
  new_shield_hp = shield_hp - absorbed

Example (15 damage, 10 shield):
  absorbed = min(15, 10) = 10
  remaining = 15 - 10 = 5  → 5 damage to HP
  new_shield_hp = 10 - 10 = 0  → shield breaks

Example (8 damage, 20 shield):
  absorbed = min(8, 20) = 8
  remaining = 8 - 8 = 0  → no HP damage
  new_shield_hp = 20 - 8 = 12  → shield holds
```

## Edge Cases

- **VULNERABLE + RESISTANT on same entity**: Both modifiers apply
  multiplicatively. `1.5 * 0.5 = 0.75` — net 25% damage reduction.
  Resistance wins slightly. Neither cancels the other.

- **Stun applied to entity already stunned**: Rejected (NONE stacking rule).
  The existing stun continues. No duration extension. Prevents stun-lock.

- **Burn applied to entity with 1 HP**: Burn applies. First tick deals
  minimum 1 damage. Entity dies. Burn source gets kill credit (via DoT
  damage pipeline).

- **Shield breaks from overkill damage**: Remaining damage after shield
  absorption hits HP. Shield break does not grant i-frames — the HP damage
  and shield break happen in the same frame.

- **Effect applied during SPAWNING**: Rejected (per Entity Framework rules).
  Effects only apply to ACTIVE or STUNNED entities.

- **Effect applied during DYING**: Rejected. Dying entities cannot receive
  new effects. Existing effects are cleared when DYING begins.

- **Poison at max stacks, reapplied**: New stack is not added. Each existing
  stack's duration is unchanged. The application is silently rejected. This
  caps poison damage output.

- **All effects cleared mid-tick**: If encounter ends during a tick interval,
  the partial tick does not fire. Effects are simply removed. No fractional
  tick damage.

- **Multiple DOT effects active simultaneously**: Each ticks independently on
  its own timer. Burn at 30-frame interval and Poison at 60-frame interval can
  both deal damage in the same frame — both process.

- **Speed modifier reduces speed below movement threshold**: Speed is clamped
  to `MIN_SPEED_MULT` (default 0.1×). Entities can be dramatically slowed but
  never completely immobilized by speed modifiers alone. Stun is the only
  full immobilization.

- **Effect with 0 duration applied**: Immediately expires. `effect_applied`
  and `effect_expired` both fire in the same frame. Any instant effect (like
  a one-frame damage spike) would use the card effect system directly, not
  a 0-duration status effect.

## Dependencies

| Direction | System | Interface | Hard/Soft |
|-----------|--------|-----------|-----------|
| Upstream | Entity Framework | `StatusEffectComponent` node, lifecycle state gating | Hard |
| Upstream | Combat System | `apply_dot_tick()` for periodic damage, modifier queries | Hard |
| Upstream | Card Data System | `CardEffect.status_effect_id` and `status_duration_frames` for application | Hard |
| Downstream | Combat System | `get_damage_taken_multiplier()`, `has_effect()` for damage modifiers | Hard |
| Downstream | Entity Framework | `set_stunned()` for stun control integration | Hard |
| Downstream | Movement (Entity Framework) | `get_speed_multiplier()` for movement speed modification | Hard |
| Downstream | Combat HUD | Active effect icons/durations for status display | Soft |

Public API (on StatusEffectComponent):

```gdscript
# Application
func apply_effect(effect_id: StringName, duration_frames: int) -> bool
func remove_effect(effect_id: StringName) -> void
func clear_all_effects() -> void

# Queries
func has_effect(effect_id: StringName) -> bool
func get_stack_count(effect_id: StringName) -> int
func get_remaining_duration(effect_id: StringName) -> int
func get_active_effects() -> Array[StatusEffectInstance]

# Modifier queries (for Combat System)
func get_damage_taken_multiplier() -> float
func get_damage_dealt_multiplier() -> float
func get_speed_multiplier() -> float

# Shield
func get_shield_hp() -> int
func absorb_damage(amount: int) -> int  # returns remaining damage after absorption

# Signals
signal effect_applied(effect_id: StringName, duration: int)
signal effect_expired(effect_id: StringName)
signal effect_stack_changed(effect_id: StringName, new_count: int)
signal shield_broken()
```

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|------|---------|------------|--------|
| `BURN_TICK_DAMAGE` | 3 | 1–8 | Damage per burn tick. Higher = burn is primary damage, not supplemental. |
| `BURN_TICK_INTERVAL` | 30 frames (0.5s) | 15–60 | Frequency of burn ticks. Lower = faster damage, more aggressive. |
| `POISON_TICK_DAMAGE` | 2 | 1–5 | Base damage per poison tick per stack. Scales with stacks. |
| `POISON_TICK_INTERVAL` | 60 frames (1.0s) | 30–90 | Poison ticks slower than burn but stacks harder. |
| `POISON_MAX_STACKS` | 5 | 3–8 | Maximum poison stacks. Higher = more damage ceiling for poison builds. |
| `SLOW_MULTIPLIER` | 0.5 | 0.3–0.7 | Speed multiplier for SLOW. Lower = more impactful slow. |
| `HASTE_MULTIPLIER` | 1.5 | 1.2–2.0 | Speed multiplier for HASTE. Higher = faster movement. |
| `STUN_MAX_DURATION` | 120 frames (2.0s) | 60–180 | Hard cap on stun duration per application (Entity Framework also caps at 300). |
| `MIN_SPEED_MULT` | 0.1 | 0.05–0.25 | Floor for speed modifiers. Prevents full immobilization via speed debuffs. |
| `MAX_SPEED_MULT` | 3.0 | 2.0–5.0 | Ceiling for speed modifiers. Prevents absurd movement speed. |

## Acceptance Criteria

1. **GIVEN** burn applied with 180-frame duration, **WHEN** 30 frames elapse,
   **THEN** first tick deals `BURN_TICK_DAMAGE` to target via Combat System.

2. **GIVEN** burn active, **WHEN** burn reapplied (REFRESH), **THEN** duration
   resets to new duration, damage rate unchanged, one instance remains.

3. **GIVEN** poison at 3 stacks, **WHEN** tick occurs, **THEN** damage =
   `POISON_TICK_DAMAGE × 3`.

4. **GIVEN** poison at `POISON_MAX_STACKS`, **WHEN** poison reapplied, **THEN**
   new stack rejected, existing stacks unaffected.

5. **GIVEN** entity with VULNERABLE, **WHEN** Combat System queries
   `get_damage_taken_multiplier()`, **THEN** returns 1.5.

6. **GIVEN** entity with SLOW, **WHEN** `get_speed_multiplier()` queried,
   **THEN** returns 0.5.

7. **GIVEN** stun applied to already-stunned entity, **WHEN** stacking rule
   checked, **THEN** application rejected, existing stun unaffected.

8. **GIVEN** 20 shield HP, 15 damage incoming, **WHEN** shield absorbs,
   **THEN** 15 absorbed, 0 to HP, shield_hp = 5.

9. **GIVEN** 10 shield HP, 25 damage incoming, **WHEN** shield absorbs,
   **THEN** 10 absorbed, 15 to HP, shield breaks, `shield_broken` fires.

10. **GIVEN** encounter ends, **WHEN** effects cleared, **THEN** all active
    effects removed, no residual ticks, entity returns to unmodified state.

11. **GIVEN** SLOW + HASTE active on same entity, **WHEN** speed calculated,
    **THEN** multiplier = 0.5 × 1.5 = 0.75 (net 25% slow).

12. **GIVEN** effect applied to entity in SPAWNING state, **WHEN** application
    attempted, **THEN** rejected, no effect applied.
