extends SceneTree
## Checks an exported build, which the smoke test (run from source) cannot see.
## An export stores .tres files as .tres.remap, so code that lists folders with
## DirAccess finds data in the editor and nothing at all in the shipped game.
## Export a pack with the same preset, then run (exit code 1 on failure):
##   godot --headless --export-pack "Web" /tmp/game.pck
##   godot --headless --main-pack /tmp/game.pck -s "$PWD/tests/export_check.gd"

var failures: int = 0

func _initialize() -> void:
	await process_frame
	var items: int = root.get_node("ItemDatabase").items.size()
	var monster_db = root.get_node("MonsterDatabase")
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	var classes: int = menu._load_classes().size()
	menu.free()
	_check(items > 0, "items loaded (%d)" % items)
	_check(monster_db.monsters.size() > 0, "monsters loaded (%d)" % monster_db.monsters.size())
	_check(classes > 0, "classes offered on the class screen (%d)" % classes)
	_check(monster_db.get_boss_for_floor(10) != null, "boss for floor 10")
	_check(monster_db.get_boss_for_floor(20) != null, "boss for floor 20")
	_check(not monster_db.get_monsters_for_floor(1).is_empty(), "monsters for floor 1")
	print("== export check: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
	print("  %s  %s" % ["PASS" if cond else "FAIL", msg])
