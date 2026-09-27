extends Node2D
## Light and fog over the whole floor, drawn after the tiles and actors and
## multiplied into them. It is one pixel per tile, stretched over the map with
## smooth filtering, so light fades across tiles instead of stepping at their
## edges: warm near the player, dimmer toward the edge of sight, a cold dim
## for places only remembered, and black where nobody has been. Candles and
## other glowing decor warm the tiles around them. Looks only: what the player
## can see is still decided by DungeonState.visible_tiles.

## Drawn over actors, under damage numbers (z 10).
const Z: int = 5
const NEAR := Color(1.0, 0.95, 0.86)
const FAR := Color(0.44, 0.43, 0.56)
const REMEMBERED := Color(0.25, 0.26, 0.37)
const UNSEEN := Color(0, 0, 0)
const WARM := Color(1.0, 0.8, 0.52)
const STAIRS_GLOW := Color(0.62, 0.72, 1.0)
const LIGHT_RADIUS: float = 2.6
## How much the whole light breathes, like a flame (fraction of brightness).
const FLICKER: float = 0.035
## Past the map edge everything is dark too; this much margin covers any view.
const OUTSIDE: float = 4000.0

## The last light map built, one pixel per tile.
var light_map: Image
var _tex: ImageTexture
var _size := Vector2i.ZERO
var _time: float = 0.0

func _ready() -> void:
	z_index = Z
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat

func _process(delta: float) -> void:
	_time += delta
	var f: float = 1.0 - FLICKER * (0.5 + 0.5 * sin(_time * 7.1) * sin(_time * 2.3 + 1.0))
	modulate = Color(f, f, f)

## Rebuilds the light map from the current field of view.
func refresh() -> void:
	var w: int = DungeonState.width
	var h: int = DungeonState.height
	if w <= 0 or h <= 0:
		return
	var origin := Vector2(DungeonState.fov_origin)
	var lights: Array = _light_sources()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var pos := Vector2i(x, y)
			img.set_pixel(x, y, _light_at(pos, origin, lights))
	light_map = img
	if _tex == null or _size != Vector2i(w, h):
		_tex = ImageTexture.create_from_image(img)
		_size = Vector2i(w, h)
	else:
		_tex.update(img)
	queue_redraw()

func _light_at(pos: Vector2i, origin: Vector2, lights: Array) -> Color:
	if DungeonState.visible_tiles.has(pos):
		var t: float = clampf(Vector2(pos).distance_to(origin) / float(Constants.VISION_RADIUS), 0.0, 1.0)
		var c: Color = NEAR.lerp(FAR, pow(t, 1.4))
		for light in lights:
			var k: float = 1.0 - Vector2(pos).distance_to(Vector2(light[0])) / LIGHT_RADIUS
			if k > 0.0:
				var lit: Color = light[1]
				c = c.lerp(Color(maxf(c.r, lit.r), maxf(c.g, lit.g), maxf(c.b, lit.b)), k * 0.85)
		return c
	if DungeonState.explored.has(pos):
		return REMEMBERED
	return UNSEEN

## [pos, color] of every visible thing that glows.
func _light_sources() -> Array:
	var out: Array = []
	for pos in DungeonState.visible_tiles.keys():
		match DungeonState.tile_at(pos):
			DungeonState.Tile.ALTAR:
				out.append([pos, WARM])
			DungeonState.Tile.STAIRS_DOWN:
				out.append([pos, STAIRS_GLOW])
			_:
				if TileAtlas.LIGHTS.has(DungeonRenderer.decor_at(pos)):
					out.append([pos, WARM])
	return out

func _draw() -> void:
	if _tex == null:
		return
	var ts: int = Constants.TILE_SIZE
	var map := Rect2(0, 0, _size.x * ts, _size.y * ts)
	draw_texture_rect(_tex, map, false)
	# black past the edges, so the background there matches unexplored ground
	draw_rect(Rect2(-OUTSIDE, -OUTSIDE, map.size.x + OUTSIDE * 2, OUTSIDE), UNSEEN)
	draw_rect(Rect2(-OUTSIDE, map.end.y, map.size.x + OUTSIDE * 2, OUTSIDE), UNSEEN)
	draw_rect(Rect2(-OUTSIDE, 0, OUTSIDE, map.size.y), UNSEEN)
	draw_rect(Rect2(map.end.x, 0, OUTSIDE, map.size.y), UNSEEN)
