## Defines all static data for a single card.
## Authored as .tres files in assets/data/cards/.
## Source: GDD card-data-system.md (S.1), ADR-0004
class_name CardData
extends Resource


@export var card_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var card_type: Enums.CardType = Enums.CardType.ATTACK
@export var archetype: Enums.CardArchetype = Enums.CardArchetype.NEUTRAL
@export var rarity: Enums.CardRarity = Enums.CardRarity.COMMON
@export var effects: Array[CardEffect] = []
@export var targeting: Enums.TargetingMode = Enums.TargetingMode.DIRECTIONAL
@export_range(0, 300) var cooldown_frames: int = 0
@export var animation_key: StringName = &""
@export_range(0, 60) var windup_frames: int = 12
@export_range(1, 30) var active_frames: int = 4
@export_range(0, 60) var recovery_frames: int = 8
@export var card_art: Texture2D = null
@export var card_color: Color = Color.WHITE
@export var sfx_play: AudioStream = null
@export var sfx_impact: AudioStream = null
@export_range(0.0, 10.0) var shake_intensity: float = 0.0
@export var upgraded: bool = false
@export var upgrade_card_id: StringName = &""
@export var tags: Array[StringName] = []
@export_multiline var tooltip_extra: String = ""
