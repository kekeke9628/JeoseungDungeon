extends Node
## Headless smoke test. Run:
##   Godot --headless --path . res://tests/SmokeTest.tscn
## Exits with code 1 if any check fails.

var failures: int = 0
var game: Node2D


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		print("  FAIL  ", msg)

func _ready() -> void:
	seed(12345)
	game = load("res://scenes/Game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await _run()
	print("== %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _reachable(from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if not seen.has(n) and DungeonState.is_walkable(n):
				seen[n] = true
				queue.append(n)
	return false

func _god_mode() -> void:
	game.player.stats.max_hp = 99999
	game.player.current_hp = 99999

func _run() -> void:
	print("[content]")
	check(ItemDatabase.items.size() == 8, "8 items loaded (got %d)" % ItemDatabase.items.size())
	check(MonsterDatabase.monsters.size() == 8, "8 monsters loaded (got %d)" % MonsterDatabase.monsters.size())
	check(MonsterDatabase.get_boss_for_floor(8) != null, "boss registered for floor 8")
	for f in range(1, 8):
		check(MonsterDatabase.get_monsters_for_floor(f).size() > 0, "monster pool non-empty on floor %d" % f)

	print("[start state]")
	check(is_instance_valid(game.player), "player spawned")
	check(GameState.equipped_weapon != null and GameState.equipped_weapon.id == "spirit_dagger", "starting dagger equipped")
	check(game.player.stats.attack_max == 7, "dagger bonus applied to attack (max=%d)" % game.player.stats.attack_max)

	print("[generation x50]")
	var all_connected := true
	for i in range(50):
		var r: Dictionary = DungeonGenerator.generate(Constants.GRID_WIDTH, Constants.GRID_HEIGHT, 1 + i % 8)
		DungeonState.grid = r.grid
		if not _reachable(r.start_pos, r.stairs_pos):
			all_connected = false
	check(all_connected, "start always reaches stairs")
	game._load_floor(1)

	print("[inventory / items]")
	_god_mode()
	var talisman: ItemData = ItemDatabase.get_item("talisman")
	var saved_monsters: Array = TurnManager.monsters.duplicate()
	TurnManager.monsters.clear()
	check(ItemEffects.use_item(talisman, game.player) == false, "talisman with no target consumes nothing")
	TurnManager.monsters.append_array(saved_monsters)
	game.player.current_hp = 10
	var wine: ItemData = ItemDatabase.get_item("flower_wine")
	check(ItemEffects.use_item(wine, game.player), "potion used")
	check(game.player.current_hp == 25, "potion healed 15 (hp=%d)" % game.player.current_hp)
	GameState.add_item(ItemDatabase.get_item("rusty_sword"))
	var before_max: int = game.player.stats.attack_max
	ItemEffects.use_item(ItemDatabase.get_item("rusty_sword"), game.player)
	check(game.player.stats.attack_max == before_max - 2 + 3, "weapon swap adjusts attack (%d)" % game.player.stats.attack_max)
	check(GameState.inventory.any(func(e): return e.item_data.id == "spirit_dagger"), "old weapon returned to bag")
	GameState.add_item(ItemDatabase.get_item("soul_armor"))
	ItemEffects.use_item(ItemDatabase.get_item("soul_armor"), game.player)
	check(game.player.stats.defense == 2, "armor applied")
	GameState.add_item(ItemDatabase.get_item("ledger_fragment"))
	GameState.add_item(ItemDatabase.get_item("hemp_garment"))
	check(ItemEffects.use_item(ItemDatabase.get_item("ledger_fragment"), game.player), "identify scroll used")

	print("[random play x600]")
	_god_mode()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var start_turns: int = GameState.turn_count
	for i in range(600):
		game._on_direction_pressed(dirs[randi() % 4])
		if i % 50 == 0:
			game._on_wait_pressed()
		if game._ended:
			break
	check(GameState.turn_count > start_turns, "turns advanced (%d)" % (GameState.turn_count - start_turns))
	check(not game._ended, "player survived random play in god mode")

	print("[floor descent 1->8]")
	for f in range(1, 8):
		game._load_floor(f)
		_god_mode()
		DungeonState.move_actor(game.player, game.player.grid_pos, DungeonState.stairs_pos)
		game._after_player_action()
		check(GameState.current_floor == f + 1, "stepping on stairs: floor %d -> %d" % [f, GameState.current_floor])
	check(GameState.current_floor == 8, "reached boss floor")

	print("[boss]")
	var boss = null
	for m in TurnManager.monsters:
		if is_instance_valid(m) and m.data.is_boss:
			boss = m
	check(boss != null, "boss present on floor 8")
	var victory := [false]
	GameState.game_over.connect(func(v): victory[0] = v)
	if boss != null:
		boss.take_damage(99999)
	await get_tree().process_frame
	check(victory[0], "killing boss emits victory")
	check(game.game_over_screen.visible, "game over screen shown")

	print("[death]")
	game._ended = false
	game._load_floor(3)
	game.player.is_alive = true
	var defeat := [null]
	GameState.game_over.connect(func(v): defeat[0] = v)
	game.player.take_damage(999999)
	check(defeat[0] == false, "player death emits defeat")
