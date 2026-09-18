extends Node
## Holds the mutable state of the currently active dungeon floor: tile grid,
## actor occupancy, and ground loot. Autoloaded as "DungeonState".
## Actor/UI code reads and mutates this singleton rather than passing the
## floor around explicitly.

enum Tile { WALL, FLOOR, DOOR, STAIRS_DOWN }

signal changed

var grid: Dictionary = {}       # Vector2i -> Tile
var width: int = 0
var height: int = 0
var stairs_pos: Vector2i = Vector2i.ZERO

var actors_at: Dictionary = {}  # Vector2i -> Actor
var items_at: Dictionary = {}   # Vector2i -> ItemData
var gold_at: Dictionary = {}    # Vector2i -> int

func clear() -> void:
	grid.clear()
	actors_at.clear()
	items_at.clear()
	gold_at.clear()
	width = 0
	height = 0

func is_walkable(pos: Vector2i) -> bool:
	var t: int = grid.get(pos, Tile.WALL)
	return t == Tile.FLOOR or t == Tile.DOOR or t == Tile.STAIRS_DOWN

func is_stairs(pos: Vector2i) -> bool:
	return grid.get(pos, Tile.WALL) == Tile.STAIRS_DOWN

func get_actor_at(pos: Vector2i):
	return actors_at.get(pos, null)

func set_actor_at(pos: Vector2i, actor) -> void:
	actors_at[pos] = actor

func clear_actor_at(pos: Vector2i) -> void:
	actors_at.erase(pos)

func move_actor(actor, from_pos: Vector2i, to_pos: Vector2i) -> void:
	actors_at.erase(from_pos)
	actors_at[to_pos] = actor
	actor.move_to_grid(to_pos)

func place_item(pos: Vector2i, item: ItemData) -> void:
	items_at[pos] = item
	changed.emit()

func take_item_at(pos: Vector2i) -> ItemData:
	if items_at.has(pos):
		var it: ItemData = items_at[pos]
		items_at.erase(pos)
		changed.emit()
		return it
	return null

func place_gold(pos: Vector2i, amount: int) -> void:
	gold_at[pos] = amount
	changed.emit()

func take_gold_at(pos: Vector2i) -> int:
	if gold_at.has(pos):
		var g: int = gold_at[pos]
		gold_at.erase(pos)
		changed.emit()
		return g
	return 0
