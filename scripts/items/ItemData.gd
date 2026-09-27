class_name ItemData
extends Resource
## Data-driven definition for a single item type (equipment, potion, scroll, gold).
## Instances live as .tres files under res://resources/items/.

## New types go at the end: .tres files store the enum as its number.
enum ItemType { WEAPON, ARMOR, POTION, SCROLL, GOLD, MISC, HEAD, AMULET, RING, BOOTS, FOOD }

## The body slot each kind of equipment is worn in (see GameState.EQUIP_SLOTS).
const EQUIP_SLOT_OF := {
	ItemType.HEAD: "head", ItemType.WEAPON: "weapon", ItemType.ARMOR: "armor",
	ItemType.AMULET: "amulet", ItemType.RING: "ring", ItemType.BOOTS: "boots",
}

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
## Equipment: attack bonus. Potion: HP restored. Scroll: effect magnitude.
## Food: hunger taken away, in turns.
@export var value_a: int = 0
## Equipment: defense bonus. Elixir: permanent max HP gain.
@export var value_b: int = 0
## Equipment: max HP while worn.
@export var bonus_hp: int = 0
@export var gold_value: int = 10
## How often this turns up as floor loot, against other items of its kind
## (gear, or everything else). 10 is ordinary; rarer things are lower.
@export var loot_weight: int = 10

## The slot this item is worn in, or "" if it is not equipment.
func equip_slot() -> String:
	return EQUIP_SLOT_OF.get(item_type, "")

func is_equipment() -> bool:
	return equip_slot() != ""

## Gold and food are never a mystery: they need no identifying.
func is_always_known() -> bool:
	return item_type == ItemType.GOLD or item_type == ItemType.FOOD

func get_display_name(identified: bool) -> String:
	if identified or is_always_known():
		return identified_name
	return unidentified_name

func get_display_description(identified: bool) -> String:
	if identified or is_always_known():
		return identified_description
	return description
