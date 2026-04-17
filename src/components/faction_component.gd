## Tags an entity's faction for target filtering in combat.
## Source: GDD entity-framework.md (C.2), ADR-0001
class_name FactionComponent
extends Node


enum Faction { PLAYER, ENEMY, NEUTRAL }

@export var faction: Faction = Faction.NEUTRAL


func is_hostile_to(other: FactionComponent) -> bool:
	if faction == Faction.NEUTRAL or other.faction == Faction.NEUTRAL:
		return false
	return faction != other.faction
