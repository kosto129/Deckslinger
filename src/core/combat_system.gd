## Processes all combat damage through a multiplicative modifier pipeline.
## Sole authority for calling HealthComponent.take_damage().
## Source: GDD combat-system.md, ADR-0009
class_name CombatSystem
extends Node


const STUN_DAMAGE_BONUS: float = 1.25
const CRIT_MULTIPLIER: float = 1.5
const MIN_HITSTOP_FRAMES: int = 2
const MAX_HITSTOP_FRAMES: int = 8
const DEATH_HITSTOP_BONUS: int = 3

signal damage_dealt(source: EntityBase, target: EntityBase, amount: int, is_crit: bool)
signal entity_killed(entity: EntityBase, killer: EntityBase)
signal combat_shake_requested(intensity: float)
signal hit_stop_triggered(duration_frames: int)


## Processes a hit through the damage pipeline.
## Formula: final_damage = max(floor(base * vuln * stun_bonus * crit_mult), 1)
func process_hit(hit_data: HitData) -> void:
	var target: EntityBase = hit_data.target_entity
	if target == null:
		return

	# Guard: dead or dying targets
	var state := target.get_lifecycle_state()
	if state == Enums.LifecycleState.DYING or state == Enums.LifecycleState.DEAD:
		return

	var health: HealthComponent = target.get_health()
	if health == null or not health.is_alive():
		return

	# Status modifiers (vulnerability/resistance combined)
	var status: StatusEffectComponent = target.get_status_effects()
	var vuln: float = status.get_damage_taken_multiplier() if status else 1.0

	# Stun bonus
	var stun_bonus: float = STUN_DAMAGE_BONUS if state == Enums.LifecycleState.STUNNED else 1.0

	# Crit roll
	var is_crit: bool = randf() < hit_data.crit_chance
	var crit_mult: float = CRIT_MULTIPLIER if is_crit else 1.0

	# Final damage calculation
	var final_damage: int = maxi(floori(hit_data.damage * vuln * stun_bonus * crit_mult), 1)

	# Apply to health (sole HP modification path)
	health.take_damage(final_damage, hit_data.source_entity)

	# Emit signal
	damage_dealt.emit(hit_data.source_entity, target, final_damage, is_crit)

	# Combat feedback
	_trigger_combat_feedback(hit_data, final_damage, is_crit)

	# Death check
	if not health.is_alive():
		_process_death(target, hit_data.source_entity, hit_data.shake_intensity)


## Connects to a hurtbox's hit_received signal to route hits through the pipeline.
func connect_hurtbox(hurtbox: HurtboxComponent) -> void:
	hurtbox.hit_received.connect(process_hit)


# -- Private --

func _trigger_combat_feedback(hit_data: HitData, _final_damage: int, _is_crit: bool) -> void:
	# Screen shake
	if hit_data.shake_intensity > 0.0:
		combat_shake_requested.emit(hit_data.shake_intensity)

	# Hit-stop
	var hitstop: int = clampi(int(hit_data.shake_intensity * 2), MIN_HITSTOP_FRAMES, MAX_HITSTOP_FRAMES)
	if hitstop > 0:
		hit_stop_triggered.emit(hitstop)


func _process_death(entity: EntityBase, killer: EntityBase, shake_intensity: float) -> void:
	entity.die()
	entity_killed.emit(entity, killer)

	# Extra feedback on kill
	if shake_intensity > 0.0:
		combat_shake_requested.emit(shake_intensity * 1.5)
	hit_stop_triggered.emit(MAX_HITSTOP_FRAMES + DEATH_HITSTOP_BONUS)
