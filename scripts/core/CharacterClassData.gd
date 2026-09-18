class_name CharacterClassData
extends Resource
## Data-driven definition for a playable class. Instances live as .tres files
## under res://resources/classes/.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var stats: ActorStats
@export var starting_item_ids: Array[String] = []
@export var color: Color = Color.WHITE
@export var glyph: String = "@"
