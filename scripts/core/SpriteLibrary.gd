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

static func get_actor(id: String) -> Texture2D:
	return null if id.is_empty() else _load(ACTOR_DIR + id + ".png")

static func get_tile(name: String) -> Texture2D:
	return _load(TILE_DIR + name + ".png")

static func get_item(id: String) -> Texture2D:
	return _load(ITEM_DIR + id + ".png")
