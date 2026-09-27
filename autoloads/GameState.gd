extends Node
## Persistent run state: floor progress, inventory, gold, identification
## knowledge, leveling. Autoloaded as "GameState". Reset at the start of each run.

signal game_over(victory: bool)
signal inventory_changed
signal gold_changed(new_gold: int)
signal level_changed(new_level: int, xp: int, xp_to_next: int)
signal leveled_up(new_level: int)
signal skill_changed
## Something was put on or taken off (or the whole outfit was reset or loaded).
signal equipment_changed

## Body slots, in the order the paper doll lists them.
const EQUIP_SLOTS: Array[String] = ["head", "weapon", "armor", "amulet", "ring", "boots"]

var current_floor: int = 1
var gold: int = 0
var player_class: CharacterClassData
var player_level: int = 1
var player_xp: int = 0
var player_xp_to_next: int = 20
var turn_count: int = 0
var skill_cooldown_left: int = 0
## Turns since the player last ate their fill (see Player.HUNGRY). 0 is full.
var hunger: int = 0
## What last hurt the player, shown on the game-over screen.
var last_attacker: String = ""

## Set by the menu before Game.tscn loads; survive reset_run().
var selected_class_id: String = "mudang"
var pending_continue: bool = false

## slot name -> ItemData worn there. Empty slots have no key.
var equipped: Dictionary = {}
## Shorthands kept for the two original slots.
var equipped_weapon: ItemData:
	get:
		return equipped.get("weapon")
	set(value):
		_set_equipped("weapon", value)
var equipped_armor: ItemData:
	get:
		return equipped.get("armor")
	set(value):
		_set_equipped("armor", value)

## Array of {"item_data": ItemData, "quantity": int}
var inventory: Array[Dictionary] = []
## item.id -> bool. Identifying one instance of a type identifies all of that type.
var identified_types: Dictionary = {}

func reset_run() -> void:
	current_floor = 1
	gold = 0
	player_level = 1
	player_xp = 0
	player_xp_to_next = 20
	turn_count = 0
	skill_cooldown_left = 0
	hunger = 0
	last_attacker = ""
	equipped.clear()
	equipment_changed.emit()
	inventory.clear()
	identified_types.clear()

func is_identified(item_id: String) -> bool:
	return identified_types.get(item_id, false)

func identify(item_id: String) -> void:
	identified_types[item_id] = true

func add_item(item: ItemData) -> void:
	if item.stackable:
		for entry in inventory:
			if entry.item_data == item:
				entry.quantity += 1
				inventory_changed.emit()
				return
	inventory.append({"item_data": item, "quantity": 1})
	inventory_changed.emit()

func remove_item(item: ItemData) -> void:
	for i in range(inventory.size()):
		if inventory[i].item_data == item:
			inventory[i].quantity -= 1
			if inventory[i].quantity <= 0:
				inventory.remove_at(i)
			inventory_changed.emit()
			return

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func add_xp(amount: int) -> void:
	player_xp += amount
	while player_xp >= player_xp_to_next:
		player_xp -= player_xp_to_next
		player_level += 1
		player_xp_to_next = int(player_xp_to_next * 1.4)
		leveled_up.emit(player_level)
	level_changed.emit(player_level, player_xp, player_xp_to_next)

func _set_equipped(slot: String, item: ItemData) -> void:
	if item == null:
		equipped.erase(slot)
	else:
		equipped[slot] = item
