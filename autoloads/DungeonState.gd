extends Node
## Holds the mutable state of the currently active dungeon floor: tile grid,
## actor occupancy, ground loot, and the player's field of view. Autoloaded
## as "DungeonState".

enum Tile { WALL, FLOOR, DOOR, STAIRS_DOWN, TRAP, TRAP_SPENT, WELL, ALTAR }

signal changed

var grid: Dictionary = {}          # Vector2i -> Tile
var width: int = 0
var height: int = 0
var stairs_pos: Vector2i = Vector2i.ZERO

var actors_at: Dictionary = {}     # Vector2i -> Actor
var items_at: Dictionary = {}      # Vector2i -> ItemData
var gold_at: Dictionary = {}       # Vector2i -> int

var explored: Dictionary = {}      # Vector2i -> true, ever seen this floor
var visible_tiles: Dictionary = {} # Vector2i -> true, currently in sight
var spotted_traps: Dictionary = {} # Vector2i -> true, armed traps the player has noticed

func clear() -> void:
	grid.clear()
	actors_at.clear()
	items_at.clear()
	gold_at.clear()
	explored.clear()
	visible_tiles.clear()
	spotted_traps.clear()
	width = 0
	height = 0

func tile_at(pos: Vector2i) -> int:
	return grid.get(pos, Tile.WALL)

func set_tile(pos: Vector2i, tile: int) -> void:
	grid[pos] = tile
	changed.emit()

func is_walkable(pos: Vector2i) -> bool:
	var t: int = tile_at(pos)
	return t != Tile.WALL

func is_stairs(pos: Vector2i) -> bool:
	return tile_at(pos) == Tile.STAIRS_DOWN

## Closed doors and walls block sight; a door opens once anyone steps on it.
func blocks_sight(pos: Vector2i) -> bool:
	var t: int = tile_at(pos)
	return t == Tile.WALL or t == Tile.DOOR

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
	if tile_at(to_pos) == Tile.DOOR:
		AudioManager.play("door")
		set_tile(to_pos, Tile.FLOOR)

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

## Picks a random unoccupied plain floor tile, or Vector2i(-1, -1) if none.
func random_free_floor_tile() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for pos in grid.keys():
		if grid[pos] == Tile.FLOOR and not actors_at.has(pos):
			candidates.append(pos)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]

func reveal_all() -> void:
	for pos in grid.keys():
		explored[pos] = true
	changed.emit()

func compute_fov(origin: Vector2i, radius: int) -> void:
	visible_tiles.clear()
	visible_tiles[origin] = true
	explored[origin] = true
	var r2: int = radius * radius
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var t := origin + Vector2i(dx, dy)
			if not grid.has(t):
				continue
			if has_line_of_sight(origin, t):
				visible_tiles[t] = true
				explored[t] = true
	changed.emit()

## True if no sight-blocking tile lies strictly between a and b.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var points: Array[Vector2i] = _line(a, b)
	for i in range(1, points.size() - 1):
		if blocks_sight(points[i]):
			return false
	return true

func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err: int = dx + dy
	var x: int = a.x
	var y: int = a.y
	while true:
		pts.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return pts
