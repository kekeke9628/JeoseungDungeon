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
	for f in [5, 10, 15, 20]:
		_check(monster_db.get_boss_for_floor(f) != null, "boss for floor %d" % f)
	_check(not monster_db.get_monsters_for_floor(1).is_empty(), "monsters for floor 1")
	# the art is looked up by path at run time, so check it made it into the build
	var sprites = load("res://scripts/core/SpriteLibrary.gd")
	var ui = load("res://scripts/ui/UITheme.gd")
	var atlases: int = 0
	for band in ["path", "river", "gate", "palace"]:
		if sprites.get_tile_atlas(band) != null:
			atlases += 1
	_check(atlases == 4, "tile atlases load (%d/4)" % atlases)
	_check(sprites.get_actor_frames("yeomra").size() == 2, "character idle frames load")
	for boss in ["eodukssini", "udu_nachal"]:
		_check(sprites.get_actor_frames(boss).size() == 2, "%s frames load" % boss)
	_check(sprites.get_actor_frames("hwarang_bare").size() == 2, "bare hero bodies load")
	_check(sprites.get_gear_frames("satgat").size() == 2, "worn-gear layers load")
	_check(ui.icon("attack") != null, "button icons load")
	_check(ui.panel_box() is StyleBoxTexture, "panel skin loads")
	print("== export check: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
	print("  %s  %s" % ["PASS" if cond else "FAIL", msg])
