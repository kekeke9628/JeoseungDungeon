class_name DungeonGenerator
extends RefCounted
## Room-and-corridor procedural generator. Rooms are placed by rejection
## sampling, then chained with L-shaped corridors in placement order, so every
## room is guaranteed reachable from the first one.

const MIN_ROOM_SIZE: int = 4
const MAX_ROOM_SIZE: int = 7
const MAX_PLACEMENT_ATTEMPTS: int = 300

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

	var start_pos: Vector2i = _center(rooms[0])
	var stairs_pos: Vector2i = _center(rooms[rooms.size() - 1])
	grid[stairs_pos] = DungeonState.Tile.STAIRS_DOWN
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
