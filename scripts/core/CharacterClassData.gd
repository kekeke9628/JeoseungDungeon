class_name CharacterClassData
extends Resource
## Data-driven definition for a playable class. Instances live as .tres files
## under res://resources/classes/.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var stats: ActorStats
@export var starting_item_ids: Array[String] = []
## Subset of starting_item_ids that begins the run already equipped.
@export var starting_equip_ids: Array[String] = []
@export var skill_id: String = ''
@export var skill_name: String = ''
@export var skill_description: String = ''
## Turns before the skill can be used again.
@export var skill_cooldown: int = 10
@export var color: Color = Color.WHITE
@export var glyph: String = "@"
