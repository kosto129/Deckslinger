## Shared enums autoload — all cross-system enums live here.
## Accessed via Enums.EntityType.PLAYER syntax from any script.
## Source: ADR-0004 (Data Resource Architecture)
class_name Enums
extends Node


enum EntityType { PLAYER, STANDARD_ENEMY, ELITE_ENEMY, BOSS, PROJECTILE, PROP }

enum LifecycleState { INACTIVE, SPAWNING, ACTIVE, STUNNED, DYING, DEAD }

enum CardArchetype { GUNSLINGER, DRIFTER, OUTLAW, NEUTRAL }

enum CardRarity { COMMON, UNCOMMON, RARE, LEGENDARY }

enum CardType { ATTACK, SKILL, POWER }

enum EffectType { DAMAGE, HEAL, APPLY_STATUS, MOVE_SELF, SPAWN_PROJECTILE, AOE_DAMAGE, SHIELD, DRAW_CARDS, DISCARD }

enum TargetingMode { SELF, DIRECTIONAL, AIMED, AOE_SELF, NONE }

enum EffectCategory { BUFF, DEBUFF, DOT, CONTROL }

enum StackingRule { REFRESH, INTENSITY, INDEPENDENT, NONE }

enum InputMode { GAMEPLAY, UI }

enum InputDevice { KEYBOARD_MOUSE, GAMEPAD }

enum RoomType { COMBAT, ELITE, REST, REWARD, SHOP, BOSS, ENTRY }

enum RunOutcome { DEATH, VICTORY }
