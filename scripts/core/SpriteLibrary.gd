class_name SpriteLibrary
## Cached lookup for generated pixel art under res://assets/sprites/.
## Every getter returns null when the file is missing so callers can fall
## back to flat-color placeholders.

const ACTOR_DIR: String = "res://assets/sprites/actors/"
const TILE_DIR: String = "res://assets/sprites/tiles/"
const ITEM_DIR: String = "res://assets/sprites/items/"

static var _cache: Dictionary = {}

static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_cache[path] = tex
	return tex

## A character's idle frames. Its PNG is a strip of square frames side by
## side; empty if there is no art for id.
static func get_actor_frames(id: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if id.is_empty():
		return out
	var key: String = "frames:" + id
	if _cache.has(key):
		out.assign(_cache[key])
		return out
	var strip: Texture2D = _load(ACTOR_DIR + id + ".png")
	if strip != null:
		var side: int = strip.get_height()
		for i in range(maxi(1, strip.get_width() / side)):
			var frame := AtlasTexture.new()
			frame.atlas = strip
			frame.region = Rect2(i * side, 0, side, side)
			out.append(frame)
	_cache[key] = out
	return out.duplicate()

## A character's first idle frame, or null without art.
static func get_actor(id: String) -> Texture2D:
	var frames: Array[Texture2D] = get_actor_frames(id)
	return frames[0] if not frames.is_empty() else null

## The tile atlas of a depth band (see TileAtlas).
static func get_tile_atlas(band: String) -> Texture2D:
	return _load(TILE_DIR + band + ".png")

static func get_item(id: String) -> Texture2D:
	return _load(ITEM_DIR + id + ".png")
