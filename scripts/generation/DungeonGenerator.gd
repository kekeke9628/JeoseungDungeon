class_name DungeonGenerator
extends RefCounted
## Room-and-corridor procedural generator. Rooms are placed by rejection
## sampling, then chained with L-shaped corridors in placement order, so every
## room is guaranteed reachable from the first one.

const MIN_ROOM_SIZE: int = 4
const MAX_ROOM_SIZE: int = 7
const MAX_PLACEMENT_ATTEMPTS: int = 300
const DOOR_CHANCE: float = 0.6

## Returns {"grid": Dictionary, "rooms": Array[Rect2i], "start_pos": Vector2i, "stairs_pos": Vector2i}
static func generate(width: int, height: int, floor_num: int) -> Dictionary:
	var grid: Dictionary = {}
	for x in range(width):
		for y in range(height):
			grid[Vector2i(x, y)] = DungeonState.Tile.WALL

	var rooms: Array[Rect2i] = []
	var target_rooms: int = 6 + mini(floor_num, 4)
	var attempts: int = 0
	while rooms.size() < target_rooms and attempts < MAX_PLACEMENT_ATTEMPTS:
		attempts += 1
		var w: int = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var h: int = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var x: int = randi_range(1, width - w - 1)
		var y: int = randi_range(1, height - h - 1)
		var rect := Rect2i(x, y, w, h)
		if _overlaps_any(rect, rooms):
			continue
		_carve_room(grid, rect)
		if not rooms.is_empty():
			_carve_corridor(grid, _center(rooms[rooms.size() - 1]), _center(rect))
		rooms.append(rect)

	_place_doors(grid, rooms)
	var start_pos: Vector2i = _center(rooms[0])
	var stairs_pos: Vector2i = _center(rooms[rooms.size() - 1])
	grid[stairs_pos] = DungeonState.Tile.STAIRS_DOWN
	_place_traps(grid, rooms, floor_num, start_pos)
	return {"grid": grid, "rooms": rooms, "start_pos": start_pos, "stairs_pos": stairs_pos}

static func _center(rect: Rect2i) -> Vector2i:
	return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)

static func _overlaps_any(rect: Rect2i, rooms: Array[Rect2i]) -> bool:
	var padded := rect.grow(1)
	for r in rooms:
		if padded.intersects(r):
			return true
	return false

static func _carve_room(grid: Dictionary, rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			grid[Vector2i(x, y)] = DungeonState.Tile.FLOOR

static func _carve_corridor(grid: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var cur := from
	var horizontal_first: bool = randf() < 0.5
	if horizontal_first:
		cur = _carve_axis(grid, cur, to.x, true)
		_carve_axis(grid, cur, to.y, false)
	else:
		cur = _carve_axis(grid, cur, to.y, false)
		_carve_axis(grid, cur, to.x, true)

static func _carve_axis(grid: Dictionary, start: Vector2i, target: int, is_x: bool) -> Vector2i:
	var cur := start
	while (cur.x if is_x else cur.y) != target:
		if is_x:
			cur.x += signi(target - cur.x)
		else:
			cur.y += signi(target - cur.y)
		if grid.get(cur, DungeonState.Tile.WALL) == DungeonState.Tile.WALL:
			grid[cur] = DungeonState.Tile.FLOOR
	return cur

## Puts doors in 1-wide wall openings on room perimeters, where a corridor
## meets a room.
static func _place_doors(grid: Dictionary, rooms: Array[Rect2i]) -> void:
	for r in rooms:
		var candidates: Array[Vector2i] = []
		for y in range(r.position.y, r.position.y + r.size.y):
			_try_door(grid, Vector2i(r.position.x - 1, y), Vector2i(-1, 0), candidates)
			_try_door(grid, Vector2i(r.position.x + r.size.x, y), Vector2i(1, 0), candidates)
		for x in range(r.position.x, r.position.x + r.size.x):
			_try_door(grid, Vector2i(x, r.position.y - 1), Vector2i(0, -1), candidates)
			_try_door(grid, Vector2i(x, r.position.y + r.size.y), Vector2i(0, 1), candidates)
		for c in candidates:
			if randf() < DOOR_CHANCE:
				grid[c] = DungeonState.Tile.DOOR

static func _try_door(grid: Dictionary, pos: Vector2i, outward: Vector2i, out: Array[Vector2i]) -> void:
	var floor_tile: int = DungeonState.Tile.FLOOR
	var wall_tile: int = DungeonState.Tile.WALL
	if grid.get(pos, wall_tile) != floor_tile or grid.get(pos + outward, wall_tile) != floor_tile:
		return
	var lateral := Vector2i(outward.y, outward.x)
	if grid.get(pos + lateral, wall_tile) == wall_tile and grid.get(pos - lateral, wall_tile) == wall_tile:
		out.append(pos)

static func _place_traps(grid: Dictionary, rooms: Array[Rect2i], floor_num: int, start_pos: Vector2i) -> void:
	var count: int = 1 + floor_num / 5
	for i in range(count):
		var r: Rect2i = rooms[randi() % rooms.size()]
		var pos := Vector2i(
			randi_range(r.position.x, r.position.x + r.size.x - 1),
			randi_range(r.position.y, r.position.y + r.size.y - 1))
		if pos != start_pos and grid.get(pos) == DungeonState.Tile.FLOOR:
			grid[pos] = DungeonState.Tile.TRAP
