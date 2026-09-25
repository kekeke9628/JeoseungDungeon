extends Node
## Loads every MonsterData resource under res://resources/monsters/ at startup
## and indexes it by id. Autoloaded as "MonsterDatabase".

var monsters: Dictionary = {}  # id -> MonsterData

func _ready() -> void:
	_load_monsters()

## ResourceLoader.list_directory, not DirAccess: in an exported build the .tres
## files are stored as .tres.remap, so a DirAccess listing finds none of them.
func _load_monsters() -> void:
	for file_name in ResourceLoader.list_directory("res://resources/monsters"):
		if file_name.ends_with(".tres"):
			var res := load("res://resources/monsters/%s" % file_name) as MonsterData
			if res:
				monsters[res.id] = res
	if monsters.is_empty():
		push_warning("MonsterDatabase: no monsters found in res://resources/monsters")

func get_monster(id: String) -> MonsterData:
	return monsters.get(id, null)

func get_monsters_for_floor(floor_num: int) -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for m in monsters.values():
		if not m.is_boss and floor_num >= m.min_floor and floor_num <= m.max_floor:
			result.append(m)
	return result

func get_boss_for_floor(floor_num: int) -> MonsterData:
	for m in monsters.values():
		if m.is_boss and floor_num >= m.min_floor and floor_num <= m.max_floor:
			return m
	return null
