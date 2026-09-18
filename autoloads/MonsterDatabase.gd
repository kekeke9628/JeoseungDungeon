extends Node
## Loads every MonsterData resource under res://resources/monsters/ at startup
## and indexes it by id. Autoloaded as "MonsterDatabase".

var monsters: Dictionary = {}  # id -> MonsterData

func _ready() -> void:
	_load_monsters()

func _load_monsters() -> void:
	var dir := DirAccess.open("res://resources/monsters")
	if dir == null:
		push_warning("MonsterDatabase: res://resources/monsters not found")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load("res://resources/monsters/%s" % file_name) as MonsterData
			if res:
				monsters[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

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
