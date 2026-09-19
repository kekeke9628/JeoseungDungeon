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
