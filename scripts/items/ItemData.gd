class_name ItemData
extends Resource
## Data-driven definition for a single item type (weapon, armor, potion, scroll, gold).
## Instances live as .tres files under res://resources/items/.

enum ItemType { WEAPON, ARMOR, POTION, SCROLL, GOLD, MISC }

@export var id: String = ""
@export var item_type: ItemType = ItemType.MISC
@export var identified_name: String = ""
@export var unidentified_name: String = ""
@export var description: String = ""
@export var identified_description: String = ""
@export var stackable: bool = false
## Shallowest floor on which this item can appear as random floor loot.
@export var min_floor: int = 1
@export var is_cursed: bool = false

@export_group("Effect Values")
## Weapon: bonus damage added to attack roll. Potion: HP restored. Scroll: effect magnitude.
@export var value_a: int = 0
## Armor: defense bonus.
@export var value_b: int = 0
@export var gold_value: int = 10

func get_display_name(identified: bool) -> String:
	if identified or item_type == ItemType.GOLD:
		return identified_name
	return unidentified_name

func get_display_description(identified: bool) -> String:
	if identified:
		return identified_description
	return description
