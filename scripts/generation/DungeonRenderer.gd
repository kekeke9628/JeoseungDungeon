extends Node2D
## Immediate-mode renderer for the tile grid and ground loot. Uses flat colors
## as placeholder art; swap for a TileMapLayer once real tiles exist.

var grid: Dictionary = {}
var width: int = 0
var height: int = 0

const COLOR_WALL := Color(0.10, 0.08, 0.13)
const COLOR_FLOOR := Color(0.24, 0.21, 0.28)
const COLOR_DOOR := Color(0.40, 0.30, 0.15)
const COLOR_STAIRS := Color(0.75, 0.60, 0.15)
const COLOR_GRID_LINE := Color(0, 0, 0, 0.15)
const COLOR_ITEM := Color(0.55, 0.80, 1.0)
const COLOR_GOLD := Color(1.0, 0.85, 0.2)

func set_grid(p_grid: Dictionary, p_width: int, p_height: int) -> void:
	grid = p_grid
	width = p_width
	height = p_height
	queue_redraw()

func _tile_color(tile: int) -> Color:
	match tile:
		DungeonState.Tile.FLOOR:
			return COLOR_FLOOR
		DungeonState.Tile.DOOR:
			return COLOR_DOOR
		DungeonState.Tile.STAIRS_DOWN:
			return COLOR_STAIRS
		_:
			return COLOR_WALL

func _draw() -> void:
	var ts: int = Constants.TILE_SIZE
	for x in range(width):
		for y in range(height):
			var rect := Rect2(x * ts, y * ts, ts, ts)
			draw_rect(rect, _tile_color(grid.get(Vector2i(x, y), DungeonState.Tile.WALL)), true)
			draw_rect(rect, COLOR_GRID_LINE, false, 1.0)
	var half: float = ts * 0.5
	for pos in DungeonState.items_at.keys():
		draw_circle(Vector2(pos.x * ts + half, pos.y * ts + half), ts * 0.2, COLOR_ITEM)
	for pos in DungeonState.gold_at.keys():
		draw_circle(Vector2(pos.x * ts + half, pos.y * ts + half), ts * 0.15, COLOR_GOLD)
