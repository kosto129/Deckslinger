## Defines what this entity can hit others with.
## Tracks already-hit targets per action to enforce single-hit rule.
## Source: GDD collision-hitbox-system.md, ADR-0008
class_name HitboxComponent
extends Area2D


var _hit_data_template: HitData = null
var _already_hit: Dictionary = {}


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


## Enables the hitbox with the given hit data template. Clears hit tracking.
func enable(hit_data_template: HitData) -> void:
	_hit_data_template = hit_data_template
	_already_hit.clear()
	monitoring = true


## Disables the hitbox. Stops detecting overlaps.
func disable() -> void:
	monitoring = false


## Returns whether the hitbox is actively detecting.
func is_active() -> bool:
	return monitoring


## Clears the already-hit tracking. Called on action_completed.
func clear_hit_targets() -> void:
	_already_hit.clear()


func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return

	var hurtbox: HurtboxComponent = area as HurtboxComponent
	var target: EntityBase = hurtbox.get_parent() as EntityBase
	if target == null or _already_hit.has(target):
		return

	_already_hit[target] = true

	var hit_data := HitData.new()
	if _hit_data_template:
		hit_data.source_entity = _hit_data_template.source_entity
		hit_data.damage = _hit_data_template.damage
		hit_data.effect_source = _hit_data_template.effect_source
		hit_data.shake_intensity = _hit_data_template.shake_intensity
		hit_data.status_effects = _hit_data_template.status_effects.duplicate()
		hit_data.knockback_force = _hit_data_template.knockback_force
		hit_data.crit_chance = _hit_data_template.crit_chance

	hit_data.target_entity = target
	hit_data.hit_position = global_position
	if hit_data.source_entity and is_instance_valid(hit_data.source_entity):
		hit_data.knockback_direction = (target.global_position - hit_data.source_entity.global_position).normalized()

	hurtbox.receive_hit(hit_data)
