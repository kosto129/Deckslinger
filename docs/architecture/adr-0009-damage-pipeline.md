# ADR-0009: Damage Pipeline and Health Authority

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Combat |
| **Knowledge Risk** | LOW — no engine APIs specific to damage systems; uses signals and basic math |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Entity Composition — HealthComponent), ADR-0004 (Data Resources — CardData effects), ADR-0007 (Animation — active_started signal), ADR-0008 (Collision — HitData delivery) |
| **Enables** | All Feature layer systems (Status Effects, Enemy AI, Reward, Room Encounter) |
| **Blocks** | Core gameplay loop — nothing works without damage |
| **Ordering Note** | Last Core ADR — depends on all Foundation and Core ADRs above |

## Context

### Problem Statement
When a hitbox collides with a hurtbox, we need a pipeline that: reads base damage from the source (card or enemy attack), applies multiplicative modifiers (vulnerability, resistance, stun bonus, crits), subtracts from target HP, triggers combat feedback (hit-stop, screen shake, damage numbers), checks for death, and emits signals for downstream systems. This pipeline must handle both direct hits and DoT ticks, with DoT skipping the feedback effects.

### Requirements
- Multiplicative modifier chain: base × vulnerability × resistance × stun_bonus × crit
- Minimum 1 damage on any resolved DAMAGE effect
- HealthComponent is the sole authority on entity HP
- Hit-stop orchestrated across Animation + Camera + Input
- Damage numbers spawned at hit position with stacking offset
- Kill credit tracked (source entity of lethal damage)
- DoT uses same math but skips hit-stop/shake/knockback

## Decision

**A `CombatSystem` node (instantiated per encounter) processes all damage through a single pipeline. It receives HitData from collision, applies modifiers from StatusEffectComponent, writes to HealthComponent, and orchestrates feedback by emitting signals.**

### Damage Pipeline

```gdscript
class_name CombatSystem extends Node

func _process_hit(hit_data: HitData) -> void:
    var target: EntityBase = hit_data.target_entity
    var health: HealthComponent = target.get_health()
    if not health or not health.is_alive():
        return

    # 1. Read modifiers from target's StatusEffectComponent
    var status: StatusEffectComponent = target.get_status_effects()
    var vuln: float = status.get_damage_taken_multiplier() if status else 1.0

    # 2. Stun bonus
    var stun_bonus: float = STUN_DAMAGE_BONUS if target.get_lifecycle_state() == Enums.LifecycleState.STUNNED else 1.0

    # 3. Crit roll (if source has crit chance)
    var is_crit: bool = randf() < hit_data.crit_chance
    var crit_mult: float = CRIT_MULTIPLIER if is_crit else 1.0

    # 4. Calculate final damage
    var final_damage: int = maxi(floori(hit_data.damage * vuln * stun_bonus * crit_mult), 1)

    # 5. Shield absorption
    if status and status.get_shield_hp() > 0:
        final_damage = status.absorb_damage(final_damage)
        if final_damage <= 0:
            return  # fully absorbed

    # 6. Apply damage
    health.take_damage(final_damage, hit_data.source_entity)

    # 7. Combat feedback
    _trigger_hit_stop(hit_data)
    _request_screen_shake(hit_data.shake_intensity)
    _spawn_damage_number(hit_data.hit_position, final_damage, is_crit)
    _apply_knockback(target, hit_data)
    _apply_hit_react(target)

    # 8. Emit signal
    damage_dealt.emit(hit_data.source_entity, target, final_damage, is_crit)

    # 9. Check death
    if not health.is_alive():
        _process_death(target, hit_data.source_entity, hit_data.shake_intensity)
```

### Death Processing

```gdscript
func _process_death(entity: EntityBase, killer: EntityBase, shake: float) -> void:
    # Extended hit-stop on killing blow
    var death_hitstop: int = _calculate_hitstop(shake) + DEATH_HITSTOP_BONUS
    _apply_hitstop_to(killer, death_hitstop)

    entity.die()  # EntityBase lifecycle → DYING
    entity_killed.emit(entity, killer)
```

### DoT Damage (separate entry point)

```gdscript
func apply_dot_tick(target: EntityBase, damage: int, source_status: StringName) -> void:
    var health: HealthComponent = target.get_health()
    if not health or not health.is_alive():
        return

    var status: StatusEffectComponent = target.get_status_effects()
    var vuln: float = status.get_damage_taken_multiplier() if status else 1.0
    var final_damage: int = maxi(floori(damage * vuln), 1)

    health.take_damage(final_damage, null)  # null source for DoT

    # DoT feedback: damage number only (no hit-stop, no shake, no knockback)
    _spawn_damage_number(target.global_position, final_damage, false, true)  # is_dot=true

    damage_dealt.emit(null, target, final_damage, false)

    if not health.is_alive():
        entity.die()
        entity_killed.emit(target, null)  # no killer for DoT deaths
```

### HealthComponent (sole HP authority)

```gdscript
class_name HealthComponent extends Node

@export var max_hp: int = 100
var _current_hp: int

signal health_changed(old_hp: int, new_hp: int, source: EntityBase)
signal died(entity: EntityBase)

func take_damage(amount: int, source: EntityBase) -> void:
    if amount <= 0: return
    var old_hp: int = _current_hp
    _current_hp = maxi(_current_hp - amount, 0)
    health_changed.emit(old_hp, _current_hp, source)
    if _current_hp <= 0:
        died.emit(get_parent() as EntityBase)

func heal(amount: int) -> void:
    if amount <= 0: return
    var old_hp: int = _current_hp
    _current_hp = mini(_current_hp + amount, max_hp)
    if _current_hp != old_hp:
        health_changed.emit(old_hp, _current_hp, null)

func get_current_hp() -> int: return _current_hp
func get_max_hp() -> int: return max_hp
func get_hp_fraction() -> float: return float(_current_hp) / float(max_hp)
func is_alive() -> bool: return _current_hp > 0
```

### Hit-Stop Orchestration

```gdscript
func _trigger_hit_stop(hit_data: HitData) -> void:
    var frames: int = _calculate_hitstop(hit_data.shake_intensity)
    if frames <= 0: return

    # Freeze both attacker and target
    hit_data.source_entity.get_animation().apply_hitstop(frames)
    hit_data.target_entity.get_animation().apply_hitstop(frames)

    # Freeze global systems
    InputManager.set_frozen(true)
    camera.set_frozen(true)
    hit_stop_triggered.emit(frames)

    # Unfreeze after duration (handled by AnimationComponent countdown)

func _calculate_hitstop(shake_intensity: float) -> int:
    if shake_intensity <= 0.0: return 0
    return clampi(ceili(shake_intensity * 2.0), MIN_HITSTOP_FRAMES, MAX_HITSTOP_FRAMES)
```

## Alternatives Considered

### Alternative 1: Damage Calculated in HitboxComponent
- **Description**: Each hitbox calculates its own damage on collision
- **Pros**: Self-contained, no central system needed
- **Cons**: No single point for modifiers (vulnerability, resistance). Each hitbox must independently query status effects. Duplicated logic.
- **Rejection Reason**: Central pipeline ensures modifiers are always applied consistently. Single point of truth for damage math.

### Alternative 2: Additive Modifiers Instead of Multiplicative
- **Description**: final_damage = base + vulnerability_bonus + stun_bonus + crit_bonus
- **Pros**: More predictable scaling, easier to reason about
- **Cons**: Less interesting interactions — multipliers compound in satisfying ways (vulnerable + crit = big spike). Additive is flatter.
- **Rejection Reason**: Multiplicative creates more dramatic combat moments, which is what Pillar 1 (commitment) rewards.

## Consequences

### Positive
- Single pipeline for all damage — easy to add new modifiers or log all damage events
- HealthComponent is the sole HP authority — no system can silently modify HP
- Hit-stop and shake scale naturally with damage magnitude (stronger hits feel heavier)
- DoT shares the math but skips feedback — clean separation

### Negative
- Central CombatSystem is a dependency bottleneck — many systems connect to it
- Multiplicative modifiers can produce spike damage that trivializes encounters if modifiers stack. Mitigated by capping active modifiers per type.

### Risks
- **Simultaneous death**: Player and enemy kill each other in the same frame. Per Combat GDD: both deaths process, player death takes priority (run ends). Mitigation: process player death last, check `health.is_alive()` before processing each hit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | DP.1 — Damage Resolution Flow | 9-step pipeline from HitData to HP change |
| combat-system.md | DP.2 — Damage Modifiers | Multiplicative chain: vuln × resist × stun × crit |
| combat-system.md | HM.1 — HealthComponent Contract | HealthComponent API matches GDD specification exactly |
| combat-system.md | D.1 — Death Sequence | entity.die() + entity_killed signal + extended hit-stop |
| combat-system.md | HSO.1 — Hit-Stop Triggering | Both attacker and target frozen + global systems frozen |
| combat-system.md | HSO.2 — Death Hit-Stop | DEATH_HITSTOP_BONUS added to killing blow |
| combat-system.md | DN.1 — Damage Numbers | Spawned at hit position with color coding |
| combat-system.md | SED.1 — DoT Damage | apply_dot_tick() shares math, skips feedback |
| status-effect-system.md | SH.1 — Shield Behavior | Shield absorption before HP in damage pipeline |

## Performance Implications
- **CPU**: One damage calculation per hit. Modifier lookups are O(1) queries. Max ~10 hits per frame in worst case. <0.1ms total.
- **Memory**: CombatSystem holds no persistent data beyond tuning constants. Negligible.

## Migration Plan
No existing code — greenfield implementation.

## Validation Criteria
1. base_damage=15, no modifiers → target loses 15 HP
2. base_damage=15, target VULNERABLE (1.5×) + STUNNED (1.25×) → floor(15 × 1.5 × 1.25) = 28 damage
3. base_damage=15, target has 10 shield → shield absorbs 10, HP takes 5
4. Killing blow triggers extended hit-stop (normal + DEATH_HITSTOP_BONUS frames)
5. DoT tick of 3 damage with no modifiers → target loses 3 HP, no hit-stop, no shake
6. Entity at 0 HP → died signal emits, entity.die() called, entity_killed emits

## Related Decisions
- ADR-0001: Entity Composition (HealthComponent as child node)
- ADR-0007: Animation (hit-stop freeze, action phase signals)
- ADR-0008: Collision (HitData delivery from hit detection)
