extends Node2D
## Immediate-mode renderer for the tile grid and ground loot with fog of war:
## unexplored tiles are hidden, remembered tiles are dimmed, tiles in sight
## are drawn at full brightness. Flat colors stand in for real tile art.

var grid: Dictionary = {}
var width: int = 0
var height: int = 0

const COLOR_WALL := Color(0.10, 0.08, 0.13)
const COLOR_FLOOR := Color(0.24, 0.21, 0.28)
const COLOR_DOOR := Color(0.45, 0.30, 0.12)
const COLOR_STAIRS := Color(0.75, 0.60, 0.15)
const COLOR_TRAP_SPENT := Color(0.45, 0.12, 0.12)
const COLOR_GRID_LINE := Color(0, 0, 0, 0.15)
const COLOR_ITEM := Color(0.55, 0.80, 1.0)
const COLOR_GOLD := Color(1.0, 0.85, 0.2)
const REMEMBERED_DIM: float = 0.55

func set_grid(p_grid: Dictionary, p_width: int, p_height: int) -> void:
	grid = p_grid
	width = p_width
	height = p_height
	queue_redraw()

func _tile_color(tile: int) -> Color:
	match tile:
		DungeonState.Tile.DOOR:
			return COLOR_DOOR
		DungeonState.Tile.STAIRS_DOWN:
			return COLOR_STAIRS
		DungeonState.Tile.TRAP_SPENT:
			return COLOR_TRAP_SPENT
		DungeonState.Tile.WALL:
			return COLOR_WALL
		_:
			return COLOR_FLOOR  # FLOOR and hidden TRAP look identical

func _draw() -> void:
	var ts: int = Constants.TILE_SIZE
	for x in range(width):
		for y in range(height):
			var pos := Vector2i(x, y)
			if not DungeonState.explored.has(pos):
				continue
			var color: Color = _tile_color(grid.get(pos, DungeonState.Tile.WALL))
			if not DungeonState.visible_tiles.has(pos):
				color = color.darkened(REMEMBERED_DIM)
			var rect := Rect2(x * ts, y * ts, ts, ts)
			draw_rect(rect, color, true)
			draw_rect(rect, COLOR_GRID_LINE, false, 1.0)
	var half: float = ts * 0.5
	for pos in DungeonState.items_at.keys():
		if DungeonState.visible_tiles.has(pos):
			draw_circle(Vector2(pos.x * ts + half, pos.y * ts + half), ts * 0.2, COLOR_ITEM)
	for pos in DungeonState.gold_at.keys():
		if DungeonState.visible_tiles.has(pos):
			draw_circle(Vector2(pos.x * ts + half, pos.y * ts + half), ts * 0.15, COLOR_GOLD)
