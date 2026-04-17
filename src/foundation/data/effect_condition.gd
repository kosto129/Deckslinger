## Defines a condition that must be true for a CardEffect to fire.
## All conditions on an effect are AND-evaluated.
## Source: GDD card-data-system.md (E.3), ADR-0004
class_name EffectCondition
extends Resource


enum ConditionType {
	HP_BELOW_PERCENT,
	HP_ABOVE_PERCENT,
	HAS_STATUS,
	NOT_HAS_STATUS,
	ENEMY_COUNT_ABOVE,
	ENEMY_COUNT_BELOW,
}

@export var condition_type: ConditionType = ConditionType.HP_BELOW_PERCENT
@export var threshold: float = 0.0
@export var status_id: StringName = &""
