## Runtime-only hit data packet. Never saved to disk.
## Created by HitboxComponent on overlap, consumed by CombatSystem.
## Source: GDD collision-hitbox-system.md, ADR-0004, ADR-0008
class_name HitData
extends RefCounted


var source_entity: EntityBase
var target_entity: EntityBase
var damage: int = 0
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_force: float = 0.0
var hit_position: Vector2 = Vector2.ZERO
var effect_source: StringName = &""
var shake_intensity: float = 0.0
var status_effects: Array[StringName] = []
var crit_chance: float = 0.0
