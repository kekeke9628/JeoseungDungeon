extends Node2D
## Immediate-mode renderer for the tile grid and ground loot with fog of war:
## unexplored tiles are hidden, remembered tiles are dimmed, tiles in sight
## are drawn at full brightness. Uses pixel-art textures when available and
## falls back to flat colors otherwise.

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
const REMEMBERED_MODULATE := Color(0.42, 0.42, 0.5)
const ICON_SCALE: float = 0.7

func set_grid(p_grid: Dictionary, p_width: int, p_height: int) -> void:
	grid = p_grid
	width = p_width
	height = p_height
	queue_redraw()

func _tile_name(tile: int) -> String:
	match tile:
		DungeonState.Tile.DOOR:
			return "door"
		DungeonState.Tile.STAIRS_DOWN:
			return "stairs"
		DungeonState.Tile.TRAP_SPENT:
			return "trap_spent"
		DungeonState.Tile.WALL:
			return "wall"
		DungeonState.Tile.WELL:
			return "well"
		DungeonState.Tile.ALTAR:
			return "altar"
		_:
			return "floor"  # FLOOR and hidden TRAP look identical

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
		DungeonState.Tile.WELL:
			return Color(0.25, 0.5, 0.85)
		DungeonState.Tile.ALTAR:
			return Color(0.85, 0.7, 0.3)
		_:
			return COLOR_FLOOR

func _draw() -> void:
	var ts: int = Constants.TILE_SIZE
	var tint: Color = FloorTheme.tint(GameState.current_floor)
	for x in range(width):
		for y in range(height):
			var pos := Vector2i(x, y)
			if not DungeonState.explored.has(pos):
				continue
			var tile: int = grid.get(pos, DungeonState.Tile.WALL)
			var rect := Rect2(x * ts, y * ts, ts, ts)
			var dimmed: bool = not DungeonState.visible_tiles.has(pos)
			var tex: Texture2D = SpriteLibrary.get_tile(_tile_name(tile))
			if tex != null:
				draw_texture_rect(tex, rect, false, (REMEMBERED_MODULATE if dimmed else Color.WHITE) * tint)
			else:
				var color: Color = _tile_color(tile)
				draw_rect(rect, color.darkened(REMEMBERED_DIM) if dimmed else color, true)
				draw_rect(rect, COLOR_GRID_LINE, false, 1.0)
	for pos in DungeonState.items_at.keys():
		if DungeonState.visible_tiles.has(pos):
			_draw_icon(pos, DungeonState.items_at[pos].id, COLOR_ITEM, 0.2)
	for pos in DungeonState.gold_at.keys():
		if DungeonState.visible_tiles.has(pos):
			_draw_icon(pos, "gold", COLOR_GOLD, 0.15)

func _draw_icon(pos: Vector2i, icon_id: String, fallback: Color, fallback_radius: float) -> void:
	var ts: int = Constants.TILE_SIZE
	var tex: Texture2D = SpriteLibrary.get_item(icon_id)
	if tex != null:
		var s: float = ts * ICON_SCALE
		draw_texture_rect(tex, Rect2(pos.x * ts + (ts - s) / 2.0, pos.y * ts + (ts - s) / 2.0, s, s), false)
	else:
		var half: float = ts * 0.5
		draw_circle(Vector2(pos.x * ts + half, pos.y * ts + half), ts * fallback_radius, fallback)
