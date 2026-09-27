class_name MonsterData
extends Resource
## Data-driven definition for a monster species. Instances live as .tres files
## under res://resources/monsters/.

enum AIType { WANDER, AGGRESSIVE, RANGED, AMBUSH }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var stats: ActorStats
@export var ai_type: AIType = AIType.AGGRESSIVE
@export var xp_reward: int = 5
@export var min_floor: int = 1
@export var max_floor: int = 8
@export var color: Color = Color.WHITE
## What sprays out when it is hit: blood by default, soul-stuff for spirits,
## sparks for things of metal.
@export var hit_color: Color = Color(0.72, 0.1, 0.14)
## Single-character glyph rendered as placeholder art until real sprites exist.
@export var glyph: String = "?"
@export var is_boss: bool = false
@export var loot_item_ids: Array[String] = []
@export var loot_chance: float = 0.3
## How many tiles away (Chebyshev distance) this monster notices the player.
@export var detect_radius: int = 5
## On-hit status applied to the player: "", "poison" or "stun".
@export var special: String = ""
@export var special_chance: float = 0.3
## Once, when HP falls to this fraction of max, summon summon_count minions (0 = never).
@export var summon_fraction: float = 0.0
@export var summon_count: int = 2
## A boss's signature move, warned a turn ahead so it can be dodged (after
## Shattered Pixel Dungeon's Goo pumping up): "" none, "slam" (swells up, then
## strikes every tile around it) or "charge" (lowers its horns, then rushes
## down a straight line). See Monster.
@export var boss_move: String = ""
## Turns of ordinary fighting between two signature moves.
@export var move_cooldown: int = 3
## How much harder the signature move lands than an ordinary blow.
@export var move_power: float = 2.0
## Below this share of its HP a boss is enraged (0 = never): its blows land
## harder, its signature move comes round sooner and a crash dazes it only
## briefly. See Monster.
@export var enrage_fraction: float = 0.0
