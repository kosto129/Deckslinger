## Defines a single effect that a card produces when played.
## Nested inside CardData.effects as Array[CardEffect].
## Source: GDD card-data-system.md (E.1), ADR-0004
class_name CardEffect
extends Resource


@export var effect_type: Enums.EffectType = Enums.EffectType.DAMAGE
@export var value: float = 0.0
@export var secondary_value: float = 0.0
## NONE means inherit targeting from parent CardData.
@export var target_override: Enums.TargetingMode = Enums.TargetingMode.NONE
@export var status_effect_id: StringName = &""
@export_range(0, 600) var status_duration_frames: int = 0
@export var vfx_key: StringName = &""
@export var conditions: Array[EffectCondition] = []
