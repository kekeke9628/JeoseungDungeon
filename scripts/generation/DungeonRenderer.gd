class_name DungeonRenderer
extends Node2D
## Draws the explored part of the floor from the depth band's tile atlas:
## walls in two parts (a brick face where open floor lies below, a dark top
## everywhere else), soft contact shadows at the foot of walls, scattered
## decor, and ground loot. Light and fog are drawn over all of it by
## LightOverlay; this only decides what each tile looks like.

## Item icons are 16px art drawn at 2x, the same pixel size as tiles and actors.
const ICON_PX: float = 32.0
## Seconds per frame of animated tiles and decor (candles, embers, water).
const ANIM_STEP: float = 0.4
## Percent of plain floor tiles that get a piece of decor.
const DECOR_CHANCE: int = 14
## Percent of wall faces that show the band's rarer face (a talisman, a stain...).
const SPECIAL_WALL_CHANCE: int = 8
## Lit edge where a wall top meets open floor, and the dark edge beside a face.
const RIM_COLOR := Color(0.85, 0.8, 0.95, 0.28)
const SIDE_SHADE := Color(0, 0, 0, 0.35)
## Shadow bands under a wall, from the wall down (screen px, alpha).
const WALL_SHADOW: Array[Vector2] = [Vector2(6, 0.32), Vector2(6, 0.18), Vector2(6, 0.08)]
const ITEM_SHADOW := Color(0, 0, 0, 0.3)
## Flat colors used only if the atlas is missing.
const FALLBACK_WALL := Color(0.10, 0.08, 0.13)
const FALLBACK_FLOOR := Color(0.24, 0.21, 0.28)
const FALLBACK_ITEM := Color(0.55, 0.80, 1.0)
const FALLBACK_GOLD := Color(1.0, 0.85, 0.2)

var grid: Dictionary = {}
var width: int = 0
var height: int = 0
var _frame: int = 0
var _anim_time: float = 0.0

func set_grid(p_grid: Dictionary, p_width: int, p_height: int) -> void:
	grid = p_grid
	width = p_width
	height = p_height
	queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	if _anim_time >= ANIM_STEP:
		_anim_time -= ANIM_STEP
		_frame = 1 - _frame
		queue_redraw()

## The band atlas is picked at draw time: set_grid runs before the new floor
## number is known, the redraw after the first field-of-view pass does not.
static func band_name() -> String:
	return TileAtlas.BANDS[FloorTheme.band(GameState.current_floor)]

## Stable per-tile dice for looks: the same tile always gets the same floor
## variant and decor, across redraws and save/continue. Never touches the RNG.
static func cell_hash(pos: Vector2i, salt: int) -> int:
	var floor_salt: int = (GameState.current_floor * 31 + salt) * 83492791
	var h: int = (pos.x * 73856093) ^ (pos.y * 19349663) ^ floor_salt
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7FFFFFFF

## The decor lying on pos ("" for none). Only plain floor gets any, and a
## hidden trap looks exactly like plain floor, decor included.
static func decor_at(pos: Vector2i) -> String:
	var tile: int = DungeonState.tile_at(pos)
	if tile != DungeonState.Tile.FLOOR and tile != DungeonState.Tile.TRAP:
		return ""
	if DungeonState.spotted_traps.has(pos) or cell_hash(pos, 1) % 100 >= DECOR_CHANCE:
		return ""
	var entries: Array = TileAtlas.DECOR[band_name()]
	var total: int = 0
	for e in entries:
		total += _decor_weight(e[0])
	var roll: int = cell_hash(pos, 2) % total
	for e in entries:
		roll -= _decor_weight(e[0])
		if roll < 0:
			return e[0]
	return ""

static func _decor_weight(decor_name: String) -> int:
	return 1 if TileAtlas.LIGHTS.has(decor_name) else 3

static func _decor_frames(decor_name: String) -> int:
	for e in TileAtlas.DECOR[band_name()]:
		if e[0] == decor_name:
			return e[1]
	return 1

func _is_wall(pos: Vector2i) -> bool:
	return grid.get(pos, DungeonState.Tile.WALL) == DungeonState.Tile.WALL

func _draw() -> void:
	var atlas: Texture2D = SpriteLibrary.get_tile_atlas(band_name())
	var ts: int = Constants.TILE_SIZE
	for x in range(width):
		for y in range(height):
			var pos := Vector2i(x, y)
			if not DungeonState.explored.has(pos):
				continue
			var rect := Rect2(x * ts, y * ts, ts, ts)
			if atlas == null:
				draw_rect(rect, FALLBACK_WALL if _is_wall(pos) else FALLBACK_FLOOR, true)
				continue
			_draw_tile(atlas, pos, rect)
	for pos in DungeonState.items_at.keys():
		if DungeonState.visible_tiles.has(pos):
			_draw_icon(pos, DungeonState.items_at[pos].id, FALLBACK_ITEM)
	for pos in DungeonState.gold_at.keys():
		if DungeonState.visible_tiles.has(pos):
			_draw_icon(pos, "gold", FALLBACK_GOLD)

func _draw_tile(atlas: Texture2D, pos: Vector2i, rect: Rect2) -> void:
	var tile: int = grid.get(pos, DungeonState.Tile.WALL)
	if tile == DungeonState.Tile.WALL:
		_draw_wall(atlas, pos, rect)
		return
	_blit(atlas, "floor_%d" % (cell_hash(pos, 0) % TileAtlas.FLOOR_VARIANTS), rect)
	match tile:
		DungeonState.Tile.DOOR:
			var across: bool = _is_wall(pos + Vector2i.LEFT) and _is_wall(pos + Vector2i.RIGHT)
			_blit(atlas, "door" if across else "door_side", rect)
		DungeonState.Tile.STAIRS_DOWN:
			_blit(atlas, "stairs", rect)
		DungeonState.Tile.TRAP_SPENT:
			_blit(atlas, "trap_spent", rect)
		DungeonState.Tile.WELL:
			_blit(atlas, "well_%d" % _frame, rect)
		DungeonState.Tile.ALTAR:
			_blit(atlas, "altar_%d" % _frame, rect)
		DungeonState.Tile.TRAP:
			if DungeonState.spotted_traps.has(pos):
				_blit(atlas, "trap_spotted", rect)
	var decor: String = decor_at(pos)
	if decor != "":
		_blit(atlas, "decor_%s_%d" % [decor, _frame % _decor_frames(decor)], rect)
	var hazard: String = DungeonState.hazards.get(pos, "")
	if hazard != "":
		_blit(atlas, "hazard_%s_%d" % [hazard, _frame], rect)
	_draw_contact_shadow(pos, rect)

## A wall shows its brick face where open floor lies below it, and its top
## (with a lit rim along any open side) everywhere else.
func _draw_wall(atlas: Texture2D, pos: Vector2i, rect: Rect2) -> void:
	var variant: int = cell_hash(pos, 3) % 2
	var edge: float = rect.size.x / TileAtlas.CELL  # one art pixel
	if not _is_wall(pos + Vector2i.DOWN):
		var special: bool = cell_hash(pos, 4) % 100 < SPECIAL_WALL_CHANCE
		_blit(atlas, "wall_face_special" if special else "wall_face_%d" % variant, rect)
		if not _is_wall(pos + Vector2i.LEFT):
			draw_rect(Rect2(rect.position, Vector2(edge, rect.size.y)), SIDE_SHADE)
		if not _is_wall(pos + Vector2i.RIGHT):
			draw_rect(Rect2(rect.end.x - edge, rect.position.y, edge, rect.size.y), SIDE_SHADE)
		if not _is_wall(pos + Vector2i.UP):
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, edge)), RIM_COLOR)
		return
	_blit(atlas, "wall_top_%d" % variant, rect)
	if not _is_wall(pos + Vector2i.UP):
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, edge)), RIM_COLOR)
	if not _is_wall(pos + Vector2i.LEFT):
		draw_rect(Rect2(rect.position, Vector2(edge, rect.size.y)), RIM_COLOR)
	if not _is_wall(pos + Vector2i.RIGHT):
		draw_rect(Rect2(rect.end.x - edge, rect.position.y, edge, rect.size.y), RIM_COLOR)

## Darkens the floor at the foot of a wall and along walls at its sides.
func _draw_contact_shadow(pos: Vector2i, rect: Rect2) -> void:
	if _is_wall(pos + Vector2i.UP):
		var y: float = rect.position.y
		for band in WALL_SHADOW:
			draw_rect(Rect2(rect.position.x, y, rect.size.x, band.x), Color(0, 0, 0, band.y))
			y += band.x
	if _is_wall(pos + Vector2i.LEFT):
		draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), Color(0, 0, 0, 0.16))
	if _is_wall(pos + Vector2i.RIGHT):
		draw_rect(Rect2(rect.end.x - 4, rect.position.y, 4, rect.size.y), Color(0, 0, 0, 0.1))

func _blit(atlas: Texture2D, tile_name: String, rect: Rect2) -> void:
	draw_texture_rect_region(atlas, rect, TileAtlas.region(tile_name))

func _draw_icon(pos: Vector2i, icon_id: String, fallback: Color) -> void:
	var ts: int = Constants.TILE_SIZE
	var center := Vector2(pos.x * ts + ts * 0.5, pos.y * ts + ts * 0.5)
	# a soft oval shadow so loot sits on the floor rather than floating on it
	draw_set_transform(center + Vector2(0, ICON_PX * 0.42), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, ICON_PX * 0.36, ITEM_SHADOW)
	draw_set_transform(Vector2.ZERO)
	var tex: Texture2D = SpriteLibrary.get_item(icon_id)
	if tex == null:
		draw_circle(center, ts * 0.18, fallback)
		return
	var size := Vector2(ICON_PX, ICON_PX)
	draw_texture_rect(tex, Rect2(center - size * 0.5, size), false)
