extends Node
## Loads every ItemData resource under res://resources/items/ at startup and
## indexes it by id. Autoloaded as "ItemDatabase". Must load before any scene
## that spawns loot (autoload order in project.godot handles this).

var items: Dictionary = {}  # id -> ItemData

func _ready() -> void:
	_load_items()

func _load_items() -> void:
	var dir := DirAccess.open("res://resources/items")
	if dir == null:
		push_warning("ItemDatabase: res://resources/items not found")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load("res://resources/items/%s" % file_name) as ItemData
			if res:
				items[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

func get_item(id: String) -> ItemData:
	return items.get(id, null)

func get_all_ids() -> Array:
	return items.keys()
