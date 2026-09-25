extends Node
## Loads every ItemData resource under res://resources/items/ at startup and
## indexes it by id. Autoloaded as "ItemDatabase". Must load before any scene
## that spawns loot (autoload order in project.godot handles this).

var items: Dictionary = {}  # id -> ItemData

func _ready() -> void:
	_load_items()

## ResourceLoader.list_directory, not DirAccess: in an exported build the .tres
## files are stored as .tres.remap, so a DirAccess listing finds none of them.
func _load_items() -> void:
	for file_name in ResourceLoader.list_directory("res://resources/items"):
		if file_name.ends_with(".tres"):
			var res := load("res://resources/items/%s" % file_name) as ItemData
			if res:
				items[res.id] = res
	if items.is_empty():
		push_warning("ItemDatabase: no items found in res://resources/items")

func get_item(id: String) -> ItemData:
	return items.get(id, null)

func get_all_ids() -> Array:
	return items.keys()
