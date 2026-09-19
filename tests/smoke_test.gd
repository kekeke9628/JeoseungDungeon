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
	SettingsManager.settings_path = "user://test_settings.cfg"
	SettingsManager.tutorial_seen = true
	SaveManager.save_path = "user://test_save.json"
	IAPManager.store_path = "user://test_purchases.json"
	StatsManager.stats_path = "user://test_stats.json"
	IAPManager.reset_for_tests()
	await _run()
	SaveManager.delete_save()
	IAPManager.reset_for_tests()
	StatsManager.reset_for_tests()
	print("== %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _new_game(class_id: String, continuing: bool = false) -> void:
	if game != null:
		game.queue_free()
		await get_tree().process_frame
	GameState.selected_class_id = class_id
	GameState.pending_continue = continuing
	game = load("res://scenes/Game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

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

func _clear_monsters() -> Array:
	var saved: Array = TurnManager.monsters.duplicate()
	TurnManager.monsters.clear()
	return saved

func _run() -> void:
	await _test_content()
	await _test_classes()
	await _test_generation()
	await _test_items()
	await _test_vision_doors_traps()
	await _test_random_play()
	await _test_progression()
	await _test_save_load()
	await _test_iap()
	await _test_stats()
	await _test_tap_to_move()
	await _test_status_effects()
	await _test_review_regressions()
	await _test_boss_summon()
	await _test_polish()

func _test_content() -> void:
	print("[content]")
	check(ItemDatabase.items.size() == 17, "17 items loaded (got %d)" % ItemDatabase.items.size())
	check(MonsterDatabase.monsters.size() == 17, "17 monsters loaded (got %d)" % MonsterDatabase.monsters.size())
	check(MonsterDatabase.get_boss_for_floor(10) != null, "boss on floor 10")
	check(MonsterDatabase.get_boss_for_floor(20) != null, "boss on floor 20")
	for f in range(1, 20):
		var boss_floor: bool = MonsterDatabase.get_boss_for_floor(f) != null
		var pool_floor: int = f - 1 if boss_floor else f
		check(MonsterDatabase.get_monsters_for_floor(pool_floor).size() > 0, "monster pool non-empty for floor %d" % f)
	check(MonsterDatabase.get_monsters_for_floor(19).size() > 0, "monster pool non-empty for floor 19")

func _test_classes() -> void:
	print("[classes]")
	var expected := {"mudang": 7, "hwarang": 9, "dosa": 6}
	for id in ["mudang", "hwarang", "dosa"]:
		await _new_game(id)
		var p: Player = game.player
		check(is_instance_valid(p) and p.is_alive, "%s spawns" % id)
		check(GameState.equipped_weapon != null, "%s has weapon equipped" % id)
		check(p.stats.attack_max == expected[id], "%s attack_max %d (want %d)" % [id, p.stats.attack_max, expected[id]])
		check(GameState.player_class.skill_id != "", "%s has a skill" % id)

func _test_generation() -> void:
	print("[generation x60]")
	var all_connected := true
	var doors := 0
	var traps := 0
	for i in range(60):
		var r: Dictionary = DungeonGenerator.generate(Constants.GRID_WIDTH, Constants.GRID_HEIGHT, 1 + i % 20)
		DungeonState.grid = r.grid
		if not _reachable(r.start_pos, r.stairs_pos):
			all_connected = false
		for pos in r.grid.keys():
			if r.grid[pos] == DungeonState.Tile.DOOR:
				doors += 1
			elif r.grid[pos] == DungeonState.Tile.TRAP:
				traps += 1
	check(all_connected, "start always reaches stairs (doors/traps walkable)")
	check(doors > 0, "doors are generated (%d)" % doors)
	check(traps > 0, "traps are generated (%d)" % traps)

func _adjacent_free_tile(pos: Vector2i) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = pos + d
		if DungeonState.tile_at(n) == DungeonState.Tile.FLOOR and DungeonState.get_actor_at(n) == null:
			return n
	return Vector2i(-1, -1)

func _test_items() -> void:
	print("[items and skills]")
	await _new_game("mudang")
	_god_mode()
	var p: Player = game.player
	var children_before: int = game.world.get_child_count()
	p.take_damage(1)
	check(game.world.get_child_count() == children_before + 1, "damage popup is spawned")
	var saved: Array = _clear_monsters()
	check(not ItemEffects.use_item(ItemDatabase.get_item("talisman"), p), "talisman with no target consumes nothing")
	TurnManager.monsters.append_array(saved)
	p.current_hp = 10
	check(ItemEffects.use_item(ItemDatabase.get_item("flower_wine"), p) and p.current_hp == 25, "potion heals 15")
	var max_before: int = p.stats.max_hp
	GameState.add_item(ItemDatabase.get_item("elixir"))
	ItemEffects.use_item(ItemDatabase.get_item("elixir"), p)
	check(p.stats.max_hp == max_before + 8, "elixir raises max hp by 8")
	var atk_before: int = p.stats.attack_max
	GameState.add_item(ItemDatabase.get_item("rusty_sword"))
	ItemEffects.use_item(ItemDatabase.get_item("rusty_sword"), p)
	check(p.stats.attack_max == atk_before - 2 + 3, "weapon swap adjusts attack")
	GameState.add_item(ItemDatabase.get_item("dragon_armor"))
	ItemEffects.use_item(ItemDatabase.get_item("dragon_armor"), p)
	check(p.stats.defense == 6, "armor applied")
	var old_pos: Vector2i = p.grid_pos
	GameState.add_item(ItemDatabase.get_item("teleport_talisman"))
	check(ItemEffects.use_item(ItemDatabase.get_item("teleport_talisman"), p) and p.grid_pos != old_pos, "teleport moves the player")
	check(DungeonState.actors_at.get(p.grid_pos) == p, "teleport keeps actor map in sync")
	GameState.add_item(ItemDatabase.get_item("clairvoyance_talisman"))
	ItemEffects.use_item(ItemDatabase.get_item("clairvoyance_talisman"), p)
	check(DungeonState.explored.size() == DungeonState.grid.size(), "clairvoyance reveals whole floor")

	p.current_hp = 10
	game._on_skill_pressed()
	check(p.current_hp > 10, "mudang skill heals")
	var turns: int = GameState.turn_count
	game._on_skill_pressed()
	check(GameState.turn_count == turns, "skill on cooldown does not consume a turn")

	await _new_game("hwarang")
	saved = _clear_monsters()
	var spot: Vector2i = _adjacent_free_tile(game.player.grid_pos)
	game._spawn_monster_at(MonsterDatabase.get_monster("mongdal"), spot)
	var target = DungeonState.get_actor_at(spot)
	game._on_skill_pressed()
	check(not is_instance_valid(target) or not target.is_alive, "hwarang ilseom kills adjacent target")
	check(GameState.skill_cooldown_left > 0, "hwarang skill enters cooldown")

	await _new_game("dosa")
	_clear_monsters()
	spot = _adjacent_free_tile(game.player.grid_pos)
	game._spawn_monster_at(MonsterDatabase.get_monster("mongdal"), spot)
	target = DungeonState.get_actor_at(spot)
	game._on_skill_pressed()
	check(not is_instance_valid(target) or not target.is_alive, "dosa noejeon kills nearby target")

func _test_vision_doors_traps() -> void:
	print("[vision / doors / traps]")
	await _new_game("mudang")
	var p: Player = game.player
	check(DungeonState.visible_tiles.has(p.grid_pos), "player tile is visible")
	check(DungeonState.explored.size() > 0 and DungeonState.explored.size() < DungeonState.grid.size(), "only part of the floor explored at start")
	var hidden_ok := true
	for m in TurnManager.monsters:
		if m.visible != DungeonState.visible_tiles.has(m.grid_pos):
			hidden_ok = false
	check(hidden_ok, "monster visibility matches fov")

	var saved_grid: Dictionary = DungeonState.grid.duplicate()
	DungeonState.grid = {}
	for x in range(0, 5):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
	DungeonState.grid[Vector2i(2, 0)] = DungeonState.Tile.DOOR
	check(not DungeonState.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0)), "closed door blocks sight")
	DungeonState.grid[Vector2i(2, 0)] = DungeonState.Tile.FLOOR
	check(DungeonState.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0)), "open door lets sight through")
	DungeonState.grid = saved_grid

	_clear_monsters()
	DungeonState.actors_at.clear()
	DungeonState.actors_at[p.grid_pos] = p
	DungeonState.items_at.clear()
	DungeonState.gold_at.clear()
	var dir := Vector2i(-1, 0)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if DungeonState.tile_at(p.grid_pos + d) == DungeonState.Tile.FLOOR:
			dir = d
			break
	var door_pos: Vector2i = p.grid_pos + dir
	DungeonState.grid[door_pos] = DungeonState.Tile.DOOR
	p.try_move(dir)
	check(DungeonState.tile_at(door_pos) == DungeonState.Tile.FLOOR, "stepping onto a door opens it")

	var trap_dir := Vector2i.ZERO
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if DungeonState.tile_at(p.grid_pos + d) == DungeonState.Tile.FLOOR:
			trap_dir = d
			break
	var trap_pos: Vector2i = p.grid_pos + trap_dir
	DungeonState.grid[trap_pos] = DungeonState.Tile.TRAP
	var hp_before: int = p.current_hp
	p.try_move(trap_dir)
	check(DungeonState.tile_at(trap_pos) == DungeonState.Tile.TRAP_SPENT, "trap is spent after triggering")
	check(p.current_hp < hp_before or p.grid_pos != trap_pos, "trap hurt or teleported the player")

func _test_random_play() -> void:
	print("[random play x600]")
	await _new_game("hwarang")
	_god_mode()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var start_turns: int = GameState.turn_count
	var vision_ok := true
	for i in range(600):
		game._on_direction_pressed(dirs[randi() % 4])
		if i % 50 == 0:
			game._on_wait_pressed()
		if game._ended:
			break
		for m in TurnManager.monsters:
			if is_instance_valid(m) and m.visible != DungeonState.visible_tiles.has(m.grid_pos):
				vision_ok = false
	check(GameState.turn_count > start_turns, "turns advanced (%d)" % (GameState.turn_count - start_turns))
	check(not game._ended, "player survived random play in god mode")
	check(vision_ok, "monster visibility tracks fov during play")

func _find_boss():
	for m in TurnManager.monsters:
		if is_instance_valid(m) and m.data.is_boss:
			return m
	return null

func _test_progression() -> void:
	print("[floor descent 1->20 and bosses]")
	await _new_game("mudang")
	for f in range(1, 20):
		game._load_floor(f)
		_god_mode()
		if f == 10:
			var mid_boss = _find_boss()
			check(mid_boss != null, "mid boss present on floor 10")
			if mid_boss != null:
				mid_boss.take_damage(99999)
			check(not game._ended, "killing the floor-10 boss does not end the game")
		DungeonState.move_actor(game.player, game.player.grid_pos, DungeonState.stairs_pos)
		game._after_player_action()
		if GameState.current_floor != f + 1:
			check(false, "stairs %d -> %d (stuck at %d)" % [f, f + 1, GameState.current_floor])
	check(GameState.current_floor == 20, "reached final floor")
	var boss = _find_boss()
	check(boss != null, "final boss present on floor 20")
	var victory := [false]
	GameState.game_over.connect(func(v): victory[0] = v)
	if boss != null:
		boss.take_damage(99999)
	await get_tree().process_frame
	check(victory[0], "killing the final boss emits victory")
	check(game.game_over_screen.visible, "game over screen shown")
	check(not SaveManager.has_save(), "save deleted when the run ends")

	print("[death]")
	await _new_game("dosa")
	var defeat := [null]
	GameState.game_over.connect(func(v): defeat[0] = v)
	game.player.take_damage(999999)
	check(defeat[0] == false, "player death emits defeat")
	check(not SaveManager.has_save(), "save deleted on death")

func _test_save_load() -> void:
	print("[save / load]")
	await _new_game("dosa")
	game._load_floor(5)
	GameState.add_gold(77)
	GameState.add_xp(30)
	GameState.skill_cooldown_left = 4
	game.player.current_hp = 11
	GameState.identify("talisman")
	game.player.apply_status("poison", 3)
	SaveManager.save_run(game.player)
	check(SaveManager.has_save(), "save file written")
	var inv_count: int = GameState.inventory.size()
	var level: int = GameState.player_level
	var gold: int = GameState.gold
	var max_hp: int = game.player.stats.max_hp
	await _new_game("mudang", true)
	check(GameState.player_class.id == "dosa", "continue restores the saved class (got %s)" % GameState.player_class.id)
	check(GameState.current_floor == 5, "continue restores floor (got %d)" % GameState.current_floor)
	check(GameState.gold == gold, "continue restores gold")
	check(GameState.player_level == level, "continue restores level")
	check(GameState.inventory.size() == inv_count, "continue restores inventory")
	check(game.player.stats.max_hp == max_hp, "continue restores max hp")
	check(game.player.current_hp == 11, "continue restores current hp")
	check(GameState.skill_cooldown_left == 4, "continue restores skill cooldown")
	check(GameState.is_identified("talisman"), "continue restores identification")
	check(game.player.has_status("poison") and int(game.player.statuses["poison"]) == 3, "continue restores status effects")
	SaveManager.delete_save()
	check(not SaveManager.has_save(), "delete_save removes the file")

func _wine_count() -> int:
	for e in GameState.inventory:
		if e.item_data.id == "flower_wine":
			return e.quantity
	return 0

func _test_iap() -> void:
	print("[iap / revive]")
	IAPManager.reset_for_tests()
	check(IAPManager.revive_tokens == 0 and not IAPManager.supporter, "fresh purchase state")
	IAPManager.purchase("revive_token")
	check(IAPManager.revive_tokens == 1, "consumable purchase grants a token")
	IAPManager.purchase("supporter_pack")
	check(IAPManager.supporter, "supporter pack purchase sets flag")
	var reasons: Array[String] = []
	IAPManager.purchase_failed.connect(func(_p, r): reasons.append(r))
	IAPManager.purchase("supporter_pack")
	IAPManager.purchase("bogus")
	check(reasons.size() == 2, "duplicate and unknown purchases fail (%d)" % reasons.size())
	IAPManager.supporter = false
	IAPManager.revive_tokens = 0
	IAPManager.load_state()
	check(IAPManager.supporter and IAPManager.revive_tokens == 1, "purchases persist across reload")

	await _new_game("mudang")
	check(_wine_count() == 4, "supporter starts with 2 bonus wine (got %d)" % _wine_count())

	game.player.take_damage(999999)
	check(game._ended and not game.player.is_alive, "player dies")
	check(game.game_over_screen.visible, "game over screen shown on death")
	game._on_revive()
	check(game.player.is_alive and not game._ended, "revive brings the player back")
	check(game.player.current_hp == int(game.player.stats.max_hp * 0.5), "revive restores half hp (%d)" % game.player.current_hp)
	check(IAPManager.revive_tokens == 0, "revive consumes a token")
	check(not game.game_over_screen.visible, "game over screen hidden after revive")
	check(SaveManager.has_save(), "revive re-saves the run")
	game.player.take_damage(999999)
	game._on_revive()
	check(not game.player.is_alive and game._ended, "no token means no second revive")
	IAPManager.reset_for_tests()

func _test_stats() -> void:
	print("[stats]")
	StatsManager.reset_for_tests()
	IAPManager.reset_for_tests()
	await _new_game("hwarang")
	_clear_monsters()
	var spot: Vector2i = _adjacent_free_tile(game.player.grid_pos)
	game._spawn_monster_at(MonsterDatabase.get_monster("mongdal"), spot)
	DungeonState.get_actor_at(spot).take_damage(9999)
	check(StatsManager.kills == 1, "kill is counted")
	game.player.take_damage(999999)
	check(StatsManager.total_runs == 1 and StatsManager.wins == 0, "defeat recorded once")
	check(StatsManager.best_floor == 1, "best floor recorded")
	# _on_restart() also changes scene, which would free this test node; call the recording step only.
	game._finish_run(false)
	check(StatsManager.total_runs == 1, "finishing twice does not double-record")
	IAPManager.revive_tokens = 1
	await _new_game("dosa")
	game.player.take_damage(999999)
	check(StatsManager.total_runs == 1, "revivable defeat is not recorded yet")
	game._on_revive()
	check(StatsManager.total_runs == 1 and game.player.is_alive, "revive keeps the run open")
	GameState.game_over.emit(true)
	check(StatsManager.total_runs == 2 and StatsManager.wins == 1, "victory recorded")
	check(StatsManager.class_wins.get("도사", 0) == 1, "class win recorded by name")
	var runs: int = StatsManager.total_runs
	StatsManager.total_runs = 0
	StatsManager.load_stats()
	check(StatsManager.total_runs == runs, "records persist across reload")
	IAPManager.reset_for_tests()

func _test_tap_to_move() -> void:
	print("[tap to move]")
	await _new_game("mudang")
	var p: Player = game.player
	_clear_monsters()
	DungeonState.actors_at.clear()
	DungeonState.actors_at[p.grid_pos] = p
	DungeonState.reveal_all()
	check(Pathfinder.find_path(p.grid_pos, p.grid_pos).is_empty(), "no path to own tile")
	var target := Vector2i(-1, -1)
	for pos in DungeonState.grid.keys():
		if DungeonState.tile_at(pos) == DungeonState.Tile.FLOOR and pos != p.grid_pos:
			var d: int = absi(pos.x - p.grid_pos.x) + absi(pos.y - p.grid_pos.y)
			if d >= 6 and not Pathfinder.find_path(p.grid_pos, pos).is_empty():
				target = pos
				break
	check(target.x >= 0, "found a distant reachable tile")
	var trap_free: bool = true
	for step in Pathfinder.find_path(p.grid_pos, target):
		var tile: int = DungeonState.tile_at(step)
		if tile == DungeonState.Tile.TRAP or tile == DungeonState.Tile.STAIRS_DOWN:
			trap_free = false
	if trap_free:
		_god_mode()
		await game._on_map_tapped(target)
		check(p.grid_pos == target, "tap walks the player to the tile (at %s, want %s)" % [p.grid_pos, target])
	check(Pathfinder.find_path(p.grid_pos, Vector2i(-50, -50)).is_empty(), "unreachable tile gives no path")
	var turns: int = GameState.turn_count
	await game._on_map_tapped(p.grid_pos)
	check(GameState.turn_count == turns + 1, "tapping your own tile waits a turn")

func _test_status_effects() -> void:
	print("[status effects]")
	await _new_game("mudang")
	var p: Player = game.player
	_clear_monsters()
	p.stats.max_hp = 500
	p.current_hp = 500
	p.apply_status("poison", 3)
	check(p.has_status("poison") and p.status_text() != "", "poison applied and shown")
	var hp: int = p.current_hp
	game._on_wait_pressed()
	check(p.current_hp < hp, "poison deals damage on turn end")
	check(int(p.statuses["poison"]) == 2, "poison counts down")
	GameState.add_item(ItemDatabase.get_item("antidote_herb"))
	ItemEffects.use_item(ItemDatabase.get_item("antidote_herb"), p)
	check(not p.has_status("poison"), "antidote herb cures poison")
	p.apply_status("stun", 1)
	var turns: int = GameState.turn_count
	game._on_direction_pressed(Vector2i(1, 0))
	check(GameState.turn_count == turns + 1, "stunned input consumes exactly one turn")
	check(not p.has_status("stun"), "stun wears off")
	check(MonsterDatabase.get_monster("mulgwisin").special == "poison", "monster special loaded from data")
	var spot: Vector2i = _adjacent_free_tile(p.grid_pos)
	game._spawn_monster_at(MonsterDatabase.get_monster("mulgwisin"), spot)
	var mon = DungeonState.get_actor_at(spot)
	mon.data = mon.data.duplicate()
	mon.data.special_chance = 1.0
	mon._try_special(p)
	check(p.has_status("poison"), "monster special applies poison to the player")
	p.cure_status("poison")

func _monster_children() -> int:
	var n: int = 0
	for c in game.world.get_children():
		if c is Monster:
			n += 1
	return n

func _test_review_regressions() -> void:
	print("[review regressions]")
	IAPManager.reset_for_tests()
	await _new_game("hwarang")
	game._load_floor(2)
	await get_tree().process_frame
	check(_monster_children() == TurnManager.monsters.size(), "old floor monsters are freed (%d nodes vs %d tracked)" % [_monster_children(), TurnManager.monsters.size()])

	# a second game over after victory must not replace the result or offer a revive
	IAPManager.revive_tokens = 1
	GameState.game_over.emit(true)
	GameState.game_over.emit(false)
	check(not game.game_over_screen._revive_btn.visible, "defeat after victory does not offer revive")
	IAPManager.reset_for_tests()

	# a revivable defeat keeps the save until the run is finished
	await _new_game("dosa")
	IAPManager.revive_tokens = 1
	game.player.take_damage(999999)
	check(SaveManager.has_save(), "save survives a revivable defeat")
	game._finish_run(false)
	check(not SaveManager.has_save(), "finishing the run deletes the save")
	IAPManager.reset_for_tests()

	# any other action cancels an in-flight tap walk
	await _new_game("mudang")
	var before: int = game._walk_token
	game._on_wait_pressed()
	check(game._walk_token == before + 1, "actions bump the walk token")

func _test_boss_summon() -> void:
	print("[boss summon]")
	await _new_game("hwarang")
	game._load_floor(10)
	_god_mode()
	var boss = _find_boss()
	check(boss != null and boss.data.summon_fraction > 0.0, "floor-10 boss can summon")
	var before: int = TurnManager.monsters.size()
	boss.take_damage(int(boss.stats.max_hp * 0.3))
	check(TurnManager.monsters.size() == before, "no summon while above the threshold")
	boss.take_damage(int(boss.stats.max_hp * 0.3))
	check(TurnManager.monsters.size() == before + boss.data.summon_count, "boss summons minions at the threshold (%d -> %d)" % [before, TurnManager.monsters.size()])
	var after: int = TurnManager.monsters.size()
	boss.take_damage(1)
	check(TurnManager.monsters.size() == after, "boss only summons once")

func _test_polish() -> void:
	print("[polish]")
	await _new_game("mudang")
	var lines: Array[String] = []
	MessageBus.message_logged.connect(func(text): lines.append(text))
	_clear_monsters()
	DungeonState.actors_at.clear()
	DungeonState.actors_at[game.player.grid_pos] = game.player
	var spot: Vector2i = _adjacent_free_tile(game.player.grid_pos)
	game._spawn_monster_at(MonsterDatabase.get_monster("mongdal"), spot)
	game._refresh_vision()
	var appeared: bool = lines.any(func(l): return l.contains("나타났다"))
	check(appeared, "a newly seen monster is announced")
	var announced: int = lines.size()
	game._refresh_vision()
	check(lines.size() == announced, "a monster is announced only once")

	GameState.last_attacker = "도깨비"
	game.game_over_screen.show_result(false, 3, 2, 50, 0, GameState.last_attacker)
	check(game.game_over_screen._detail.text.contains("도깨비에게 쓰러졌다"), "game over screen names the killer")
	game.game_over_screen.show_result(false, 3, 2, 50, 0, "독")
	check(game.game_over_screen._detail.text.contains("독에 쓰러졌다"), "poison death is described")
	game._fade_in()
	check(game._fade.modulate.a == 1.0, "floor fade starts opaque")
