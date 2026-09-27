extends Node
## Headless smoke test. Run:
##   Godot --headless --path . res://tests/SmokeTest.tscn
## Exits with code 1 if any check fails.

## Long enough for every popup and death effect to finish and free itself
## (the longest, the soul wisps of a kill, live up to 1s).
const DUNGEON_FX_WAIT: float = 1.5

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
	Fx.hit_stop_enabled = false  # frames only pass when a test waits
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
	await _test_floor_theme()
	await _test_features()
	await _test_loot_and_sight()
	await _test_four_way_and_boss_stairs()
	await _test_equipment_slots()
	await _test_paper_doll()
	await _test_attack_and_motion()
	await _test_teleport_pickup()
	await _test_stairs_on_request()
	await _test_hunger()
	await _test_graphics()
	await _test_hit_feel()
	await _test_hazards()
	await _test_timed_effects()
	await _test_boss_moves()

func _test_content() -> void:
	print("[content]")
	check(ItemDatabase.items.size() == 37, "37 items loaded (got %d)" % ItemDatabase.items.size())
	for slot in GameState.EQUIP_SLOTS:
		var any_for_slot: bool = ItemDatabase.items.values().any(func(it): return it.equip_slot() == slot)
		check(any_for_slot, "some item fits the %s slot" % slot)
	check(MonsterDatabase.monsters.size() == 19, "19 monsters loaded (got %d)" % MonsterDatabase.monsters.size())
	for f in [5, 10, 15, 20]:
		check(MonsterDatabase.get_boss_for_floor(f) != null, "boss on floor %d" % f)
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
	var labels := func(): return game.world.get_children().filter(func(c): return c is Label).size()
	var labels_before: int = labels.call()
	var bursts_before: int = game.world.get_children().filter(func(c): return c is PixelBurst).size()
	p.take_damage(1)
	check(labels.call() == labels_before + 1, "damage popup is spawned")
	var bursts: int = game.world.get_children().filter(func(c): return c is PixelBurst).size()
	check(bursts == bursts_before + 1, "a hit sprays particles")
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

	_god_mode()
	var line: Array[Vector2i] = _find_straight_run(p.grid_pos)
	check(not line.is_empty(), "found a straight run of floor tiles for the monster trap test")
	if not line.is_empty():
		DungeonState.move_actor(p, p.grid_pos, line[0])
		var mon_trap: Vector2i = line[1]
		var mon_pos: Vector2i = line[2]
		DungeonState.grid[mon_trap] = DungeonState.Tile.TRAP
		game._spawn_monster_at(MonsterDatabase.get_monster("dokkaebi"), mon_pos)
		var mon = DungeonState.get_actor_at(mon_pos)
		var mon_hp: int = mon.current_hp
		game._on_wait_pressed()
		check(DungeonState.tile_at(mon_trap) == DungeonState.Tile.TRAP_SPENT, "a monster springs the trap it walks into")
		var mon_affected: bool = not is_instance_valid(mon) or not mon.is_alive or mon.current_hp < mon_hp or mon.grid_pos != mon_trap
		check(mon_affected, "the trap hurt or displaced the monster")

	var boss_data: MonsterData = MonsterDatabase.get_boss_for_floor(10)
	var boss_spot: Vector2i = DungeonState.random_free_floor_tile()
	check(boss_data != null and boss_spot.x >= 0, "found a spot to test a boss on a trap")
	if boss_data != null and boss_spot.x >= 0:
		game._spawn_monster_at(boss_data, boss_spot)
		var boss = DungeonState.get_actor_at(boss_spot)
		var boss_hp: int = boss.current_hp
		DungeonState.grid[boss_spot] = DungeonState.Tile.TRAP
		TrapSystem.trigger(boss, boss_spot)
		check(DungeonState.tile_at(boss_spot) == DungeonState.Tile.TRAP_SPENT, "a boss smashes the trap it steps on")
		check(boss.current_hp == boss_hp and boss.grid_pos == boss_spot, "a boss is unharmed and not displaced by a trap")

	var spot_run: Array[Vector2i] = _find_straight_run(p.grid_pos)
	check(not spot_run.is_empty(), "found floor tiles for the trap spotting test")
	if not spot_run.is_empty():
		DungeonState.move_actor(p, p.grid_pos, spot_run[0])
		var armed: Vector2i = spot_run[1]
		DungeonState.grid[armed] = DungeonState.Tile.TRAP
		check(not DungeonState.spotted_traps.has(armed), "an armed trap starts unnoticed")
		for i in range(80):
			game._refresh_vision()
			if DungeonState.spotted_traps.has(armed):
				break
		check(DungeonState.spotted_traps.has(armed), "waiting next to an armed trap eventually spots it")
		p.try_move(armed - p.grid_pos)
		check(not DungeonState.spotted_traps.has(armed), "a sprung trap stops being a spotted one")

	var saved_grid2: Dictionary = DungeonState.grid
	var saved_explored: Dictionary = DungeonState.explored
	var saved_actors: Dictionary = DungeonState.actors_at
	DungeonState.grid = {}
	DungeonState.explored = {}
	DungeonState.actors_at = {}
	DungeonState.spotted_traps.clear()
	for x in range(0, 3):
		for y in range(0, 3):
			DungeonState.grid[Vector2i(x, y)] = DungeonState.Tile.FLOOR
			DungeonState.explored[Vector2i(x, y)] = true
	check(Pathfinder.find_path(Vector2i(0, 1), Vector2i(2, 1)).has(Vector2i(1, 1)), "a path runs straight across open floor")
	DungeonState.grid[Vector2i(1, 1)] = DungeonState.Tile.TRAP
	DungeonState.spotted_traps[Vector2i(1, 1)] = true
	var around: Array[Vector2i] = Pathfinder.find_path(Vector2i(0, 1), Vector2i(2, 1))
	check(not around.is_empty() and not around.has(Vector2i(1, 1)), "tap-to-move walks around a spotted trap")
	DungeonState.grid = {}
	DungeonState.explored = {}
	DungeonState.spotted_traps.clear()
	for x in range(0, 3):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
		DungeonState.explored[Vector2i(x, 0)] = true
	DungeonState.grid[Vector2i(1, 0)] = DungeonState.Tile.TRAP
	DungeonState.spotted_traps[Vector2i(1, 0)] = true
	check(Pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0)).size() == 3, "a corridor with no way around still gives a path")
	DungeonState.spotted_traps.clear()
	TrapSystem.spot_all()
	check(DungeonState.spotted_traps.has(Vector2i(1, 0)), "clairvoyance reveals every armed trap")
	var route: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	check(game._route_hits_spotted_trap(route, 1), "auto-walk stops when a spotted trap lies ahead")
	check(not game._route_hits_spotted_trap(route, 2), "the tapped destination itself never blocks the walk")
	DungeonState.grid = saved_grid2
	DungeonState.explored = saved_explored
	DungeonState.actors_at = saved_actors
	DungeonState.spotted_traps.clear()

## Three free floor tiles in a row (player spot, middle, far), preferring ones
## near start_pos. Empty if the floor has none.
func _find_straight_run(start_pos: Vector2i) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_dist: int = 1 << 30
	for pos in DungeonState.grid.keys():
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var run: Array[Vector2i] = [pos, pos + d, pos + d * 2]
			var ok: bool = true
			for t in run:
				if DungeonState.tile_at(t) != DungeonState.Tile.FLOOR or DungeonState.get_actor_at(t) != null:
					ok = false
			if not ok:
				continue
			var dist: int = absi(pos.x - start_pos.x) + absi(pos.y - start_pos.y)
			if dist < best_dist:
				best_dist = dist
				best = run
	return best

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
		if f % 5 == 0:
			var mid_boss = _find_boss()
			check(mid_boss != null, "mid boss present on floor %d" % f)
			if mid_boss != null:
				mid_boss.take_damage(99999)
			check(not game._ended, "killing the floor-%d boss does not end the game" % f)
		DungeonState.move_actor(game.player, game.player.grid_pos, DungeonState.stairs_pos)
		game._after_player_action()
		game._on_descend_pressed()
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
	await _test_floor_restore()
	await _test_death_save()
	await _test_autosave()
	SaveManager.delete_save()
	check(not SaveManager.has_save(), "delete_save removes the file")

## The floor itself survives a restart: layout, explored map, loot, spotted
## traps, and every monster with its HP.
func _test_floor_restore() -> void:
	var p: Player = game.player
	var step: Vector2i = _adjacent_free_tile(p.grid_pos)
	if step.x >= 0:
		DungeonState.move_actor(p, p.grid_pos, step)
		game._refresh_vision()
	var loot_pos: Vector2i = DungeonState.random_free_floor_tile()
	DungeonState.place_item(loot_pos, ItemDatabase.get_item("talisman"))
	var gold_pos: Vector2i = DungeonState.random_free_floor_tile()
	DungeonState.place_gold(gold_pos, 42)
	var trap_pos: Vector2i = DungeonState.random_free_floor_tile()
	DungeonState.grid[trap_pos] = DungeonState.Tile.TRAP
	DungeonState.spotted_traps[trap_pos] = true
	for m in TurnManager.monsters:
		if m.current_hp > 1:
			m.current_hp -= 1
			break
	var grid_before: String = _grid_signature()
	var explored_before: int = DungeonState.explored.size()
	var pos_before: Vector2i = p.grid_pos
	var monsters_before: String = _monster_signature()
	SaveManager.save_run(p)
	await _new_game("mudang", true)
	check(_grid_signature() == grid_before, "continue restores the exact floor layout")
	check(game.player.grid_pos == pos_before, "continue puts the player back where they stood")
	check(DungeonState.explored.size() == explored_before, "continue restores the explored map")
	check(_monster_signature() == monsters_before, "continue restores every monster, position and hp")
	var loot = DungeonState.items_at.get(loot_pos)
	check(loot != null and loot.id == "talisman", "continue restores items on the ground")
	check(int(DungeonState.gold_at.get(gold_pos, 0)) == 42, "continue restores gold on the ground")
	check(DungeonState.spotted_traps.has(trap_pos), "continue remembers spotted traps")

	game._load_floor(10)
	_god_mode()
	var boss = _find_boss()
	boss.take_damage(boss.current_hp - maxi(1, int(boss.stats.max_hp * 0.3)))
	check(boss.has_summoned(), "boss summoned before saving")
	var boss_hp: int = boss.current_hp
	SaveManager.save_run(game.player)
	await _new_game("mudang", true)
	boss = _find_boss()
	check(boss != null and boss.has_summoned() and boss.current_hp == boss_hp, "a reloaded boss keeps its hp and does not summon twice")

	var data: Dictionary = SaveManager.load_data()
	data["floor_state"] = {"w": 3, "h": 1, "rows": ["0x0"], "seen": ["000"]}
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	await _new_game("mudang", true)
	var fallback_ok: bool = GameState.current_floor == 10 and DungeonState.width == Constants.GRID_WIDTH and DungeonState.is_walkable(game.player.grid_pos)
	check(fallback_ok, "a damaged floor snapshot falls back to a freshly generated floor")

## Dying while a revive is still possible is saved, so quitting on the death
## screen cannot hand the player a free life.
func _test_death_save() -> void:
	IAPManager.reset_for_tests()
	IAPManager.purchase("revive_token")
	await _new_game("hwarang")
	GameState.last_attacker = "도깨비"
	game.player.take_damage(99999)
	check(bool(SaveManager.load_data().get("dead", false)), "dying with a revive left writes the death to the save")
	await _new_game("hwarang", true)
	check(game._ended and not game.player.is_alive and game.game_over_screen.visible, "continuing a death save reopens the death screen")
	check(game.game_over_screen._detail.text.contains("도깨비"), "the reopened death screen still names the killer")
	game._on_revive()
	check(game.player.is_alive and not bool(SaveManager.load_data().get("dead", true)), "reviving clears the death from the save")
	IAPManager.reset_for_tests()

func _test_autosave() -> void:
	await _new_game("mudang")
	_clear_monsters()
	_god_mode()
	for i in range(game.AUTOSAVE_TURNS):
		game._on_wait_pressed()
	check(int(SaveManager.load_data().turns) == GameState.turn_count, "the run autosaves every few turns")
	game._on_wait_pressed()
	check(int(SaveManager.load_data().turns) < GameState.turn_count, "not every single turn writes the save")
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(int(SaveManager.load_data().turns) == GameState.turn_count, "backgrounding the app saves right away")

func _grid_signature() -> String:
	var out := ""
	for y in range(DungeonState.height):
		for x in range(DungeonState.width):
			out += str(DungeonState.tile_at(Vector2i(x, y)))
	return out

func _monster_signature() -> String:
	var parts: Array[String] = []
	for m in TurnManager.monsters:
		if is_instance_valid(m) and m.is_alive:
			parts.append("%s@%d,%d:%d" % [m.data.id, m.grid_pos.x, m.grid_pos.y, m.current_hp])
	parts.sort()
	return ",".join(parts)

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

	var mongdal: Monster = DungeonState.get_actor_at(spot)
	_god_mode()
	_clear_monsters()
	mongdal.current_hp = 1
	for i in range(20):
		if not mongdal.is_alive:
			break
		lines.clear()
		game.player.try_move(spot - game.player.grid_pos)
	var kill_lines: Array = lines.filter(func(l): return l.contains("물리쳤다"))
	check(kill_lines.size() == 1, "a melee kill is logged once (got %d)" % kill_lines.size())
	var hit_at: int = lines.find_custom(func(l): return l.contains("피해를 입혔다"))
	var kill_at: int = lines.find_custom(func(l): return l.contains("물리쳤다"))
	check(hit_at >= 0 and hit_at < kill_at, "the damage line comes before the kill line")

	GameState.last_attacker = "도깨비"
	game.game_over_screen.show_result(false, 3, 2, 50, 0, GameState.last_attacker)
	check(game.game_over_screen._detail.text.contains("도깨비에게 쓰러졌다"), "game over screen names the killer")
	game.game_over_screen.show_result(false, 3, 2, 50, 0, "독")
	check(game.game_over_screen._detail.text.contains("독에 쓰러졌다"), "poison death is described")
	game._fade_in()
	check(game._fade.modulate.a == 1.0, "floor fade starts opaque")

func _test_floor_theme() -> void:
	print("[floor theme]")
	check(FloorTheme.band_name(1) == "저승길" and FloorTheme.band_name(5) == "저승길", "floors 1-5 are the first band")
	check(FloorTheme.band_name(6) == "황천강" and FloorTheme.band_name(10) == "황천강", "floors 6-10 are the second band")
	check(FloorTheme.band_name(20) == "염라전", "floor 20 is the last band")
	check(TileAtlas.BANDS.size() == FloorTheme.NAMES.size(), "every band has its own tile set")
	var atlases_ok: bool = true
	for band in TileAtlas.BANDS:
		var atlas: Texture2D = SpriteLibrary.get_tile_atlas(band)
		var rows: int = ceili(TileAtlas.INDEX.size() / float(TileAtlas.COLS))
		var want := Vector2(TileAtlas.COLS, rows) * TileAtlas.CELL
		atlases_ok = atlases_ok and atlas != null and atlas.get_size() == want
	check(atlases_ok, "each band atlas matches the TileAtlas layout")
	check(FloorTheme.band_name(99) == "염라전" and FloorTheme.band_name(0) == "저승길", "out-of-range floors are clamped")

func _test_features() -> void:
	print("[wells and altars]")
	var wells := 0
	var altars := 0
	for i in range(80):
		var r: Dictionary = DungeonGenerator.generate(Constants.GRID_WIDTH, Constants.GRID_HEIGHT, 5)
		DungeonState.grid = r.grid
		for pos in r.grid.keys():
			if r.grid[pos] == DungeonState.Tile.WELL:
				wells += 1
			elif r.grid[pos] == DungeonState.Tile.ALTAR:
				altars += 1
		check(r.grid[r.start_pos] == DungeonState.Tile.FLOOR, "start tile stays plain floor") if i == 0 else null
	check(wells > 0 and altars > 0, "wells (%d) and altars (%d) are generated" % [wells, altars])
	var early: bool = false
	for i in range(40):
		var r1: Dictionary = DungeonGenerator.generate(Constants.GRID_WIDTH, Constants.GRID_HEIGHT, 1)
		for pos in r1.grid.keys():
			if r1.grid[pos] == DungeonState.Tile.WELL or r1.grid[pos] == DungeonState.Tile.ALTAR:
				early = true
	check(not early, "no wells or altars on floor 1")

	await _new_game("hwarang")
	var p: Player = game.player
	_clear_monsters()
	DungeonState.actors_at.clear()
	DungeonState.actors_at[p.grid_pos] = p
	var dir := Vector2i(1, 0)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if DungeonState.tile_at(p.grid_pos + d) == DungeonState.Tile.FLOOR:
			dir = d
			break
	var well_pos: Vector2i = p.grid_pos + dir
	DungeonState.grid[well_pos] = DungeonState.Tile.WELL
	p.try_move(dir)
	check(DungeonState.tile_at(well_pos) == DungeonState.Tile.WELL, "a well is not wasted at full hp")
	p.try_move(-dir)
	p.current_hp = 5
	p.try_move(dir)
	check(p.current_hp > 5 and DungeonState.tile_at(well_pos) == DungeonState.Tile.FLOOR, "a well heals and is used up")

	p.try_move(-dir)
	var altar_pos: Vector2i = p.grid_pos + dir
	DungeonState.grid[altar_pos] = DungeonState.Tile.ALTAR
	var before: int = p.stats.max_hp + p.stats.attack_max + p.stats.defense
	p.try_move(dir)
	var after: int = p.stats.max_hp + p.stats.attack_max + p.stats.defense
	check(after > before and DungeonState.tile_at(altar_pos) == DungeonState.Tile.FLOOR, "an altar grants a permanent boon and is used up")

func _test_loot_and_sight() -> void:
	print("[loot drops and talisman sight]")
	await _new_game("hwarang")
	_god_mode()
	_clear_monsters()
	var p: Player = game.player
	# a monster at (2, 0) on a talisman, the player right beside it at (3, 0)
	DungeonState.clear()
	for x in range(5):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(3, 0))
	var ground: ItemData = ItemDatabase.get_item("talisman")
	DungeonState.place_item(Vector2i(2, 0), ground)
	var mongdal: MonsterData = MonsterDatabase.get_monster("mongdal")
	var chance: float = mongdal.loot_chance
	mongdal.loot_chance = 1.0
	game._spawn_monster_at(mongdal, Vector2i(2, 0)).take_damage(9999)
	mongdal.loot_chance = chance
	var items: int = DungeonState.items_at.size()
	check(DungeonState.items_at.values().has(ground), "a drop keeps the item already on the tile")
	check(items == 2, "the drop lands beside it (%d items on the floor)" % items)
	check(not DungeonState.items_at.has(p.grid_pos), "the drop never lands under the player")

	# row 0 open floor, row 1 solid wall, row 2 open floor
	_clear_monsters()
	DungeonState.clear()
	for x in range(8):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
		DungeonState.grid[Vector2i(x, 1)] = DungeonState.Tile.WALL
		DungeonState.grid[Vector2i(x, 2)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(0, 0))
	var bulgasari: MonsterData = MonsterDatabase.get_monster("bulgasari")
	var full: int = bulgasari.stats.max_hp
	var hidden: Monster = game._spawn_monster_at(bulgasari, Vector2i(0, 2))
	game._refresh_vision()
	check(not hidden.visible, "a monster behind a wall is out of sight")
	GameState.add_item(ground)
	var used: bool = ItemEffects.use_item(ground, p)
	check(not used and hidden.current_hp == full, "a talisman ignores a monster out of sight")
	var seen: Monster = game._spawn_monster_at(bulgasari, Vector2i(4, 0))
	game._refresh_vision()
	used = ItemEffects.use_item(ground, p)
	check(used and seen.current_hp < full, "a talisman strikes the visible monster")
	check(hidden.current_hp == full, "the nearer hidden monster is left alone")

func _test_four_way_and_boss_stairs() -> void:
	print("[four-way monsters and boss stairs]")
	var lines: Array[String] = []
	var log_line := func(text): lines.append(text)
	MessageBus.message_logged.connect(log_line)
	await _new_game("hwarang")
	_god_mode()
	_clear_monsters()
	var p: Player = game.player
	DungeonState.clear()
	for x in range(6):
		for y in range(6):
			DungeonState.grid[Vector2i(x, y)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(2, 2))
	var dokkaebi_data: MonsterData = MonsterDatabase.get_monster("dokkaebi")
	var dokkaebi: Monster = game._spawn_monster_at(dokkaebi_data, Vector2i(3, 3))
	var hp: int = p.current_hp
	dokkaebi.take_ai_turn()
	var moved: Vector2i = dokkaebi.grid_pos - Vector2i(3, 3)
	var gap: Vector2i = dokkaebi.grid_pos - p.grid_pos
	var one_step: bool = absi(moved.x) + absi(moved.y) == 1
	check(p.current_hp == hp and one_step, "a diagonal monster steps instead of striking")
	check(absi(gap.x) + absi(gap.y) == 1, "the step puts it beside the player")
	lines.clear()
	dokkaebi.take_ai_turn()
	check(lines.any(func(l): return l.begins_with("도깨비")), "a monster beside the player attacks")
	DungeonState.move_actor(dokkaebi, dokkaebi.grid_pos, Vector2i(5, 5))
	dokkaebi.take_ai_turn()
	moved = dokkaebi.grid_pos - Vector2i(5, 5)
	check(absi(moved.x) + absi(moved.y) == 1, "a chasing monster steps up, down, left or right")

	await _new_game("hwarang")
	_god_mode()
	p = game.player
	game._load_floor(10)
	var stairs: Vector2i = DungeonState.stairs_pos
	var boss = _find_boss()
	DungeonState.move_actor(boss, stairs, _adjacent_free_tile(stairs))
	lines.clear()
	DungeonState.move_actor(p, p.grid_pos, stairs)
	game._after_player_action()
	check(GameState.current_floor == 10, "the stairs stay shut while the floor boss lives")
	var told: Array = lines.filter(func(l): return l.contains("길을 막고 있다"))
	check(told.size() == 1, "the player is told the boss blocks the way")
	game._after_player_action()
	told = lines.filter(func(l): return l.contains("길을 막고 있다"))
	check(told.size() == 1, "the warning is not repeated while standing on the stairs")
	game._on_descend_pressed()
	told = lines.filter(func(l): return l.contains("길을 막고 있다"))
	var refused: bool = GameState.current_floor == 10 and told.size() == 2
	check(refused, "pressing descend past a living boss is refused")
	boss.take_damage(99999)
	game._after_player_action()
	check(GameState.current_floor == 10, "killing the boss from the stairs leaves time for its drop")
	game._on_descend_pressed()
	check(GameState.current_floor == 11, "with the boss gone the stairs lead down")
	MessageBus.message_logged.disconnect(log_line)

func _make_gear(id: String, type: ItemData.ItemType, atk: int, def: int, hp: int) -> ItemData:
	var gear := ItemData.new()
	gear.id = id
	gear.item_type = type
	gear.identified_name = id
	gear.value_a = atk
	gear.value_b = def
	gear.bonus_hp = hp
	return gear

func _test_equipment_slots() -> void:
	print("[equipment slots]")
	await _new_game("hwarang")
	var p: Player = game.player
	var weapon: ItemData = GameState.equipped_weapon
	var worn_weapon = GameState.equipped.get("weapon")
	check(weapon != null and worn_weapon == weapon, "the weapon shorthand reads the weapon slot")
	var hat := _make_gear("test_hat", ItemData.ItemType.HEAD, 0, 2, 5)
	var hat2 := _make_gear("test_hat2", ItemData.ItemType.HEAD, 1, 0, 0)
	var defense: int = p.stats.defense
	var max_hp: int = p.stats.max_hp
	p.current_hp = 10
	GameState.add_item(hat)
	ItemEffects.use_item(hat, p)
	check(GameState.equipped.get("head") == hat, "a hat is worn in the head slot")
	var gained: bool = p.stats.defense == defense + 2 and p.stats.max_hp == max_hp + 5
	check(gained, "gear adds its defense and max HP")
	check(p.current_hp == 15, "gaining max HP also gains that much HP")
	var in_bag := func(it: ItemData) -> bool:
		return GameState.inventory.any(func(e): return e.item_data == it)
	check(not in_bag.call(hat), "a worn item leaves the bag")
	var attack: int = p.stats.attack_max
	GameState.add_item(hat2)
	ItemEffects.use_item(hat2, p)
	var head = GameState.equipped.get("head")
	check(head == hat2 and in_bag.call(hat), "a new hat sends the old one to the bag")
	var swapped: bool = p.stats.defense == defense and p.stats.max_hp == max_hp
	check(swapped and p.stats.attack_max == attack + 1, "swapping gear swaps the bonuses")
	check(p.current_hp == 10, "taking gear off and on can never be used to heal")
	var took_off: bool = ItemEffects.unequip("head", p)
	check(took_off and not GameState.equipped.has("head"), "gear can be taken off")
	check(p.stats.attack_max == attack and in_bag.call(hat2), "taken-off gear loses its bonus")
	check(not ItemEffects.unequip("head", p), "taking off an empty slot does nothing")

	# every slot survives a save and continue, without its bonus being added twice
	for id in ["satgat", "hemp_garment", "aengmagi_norigae", "eun_garakji", "jipsin"]:
		var gear: ItemData = ItemDatabase.get_item(id)
		GameState.add_item(gear)
		ItemEffects.use_item(gear, p)
	var worn: Dictionary = {}
	for slot in GameState.equipped.keys():
		worn[slot] = GameState.equipped[slot].id
	var stats: Array = [p.stats.attack_max, p.stats.defense, p.stats.max_hp]
	SaveManager.save_run(p)
	await _new_game("hwarang", true)
	var restored: Dictionary = {}
	for slot in GameState.equipped.keys():
		restored[slot] = GameState.equipped[slot].id
	check(restored == worn and worn.size() == 6, "continue restores all six slots (%s)" % restored)
	var p2: Player = game.player
	var stats2: Array = [p2.stats.attack_max, p2.stats.defense, p2.stats.max_hp]
	check(stats2 == stats, "continue does not add worn bonuses twice")

	# a save from before the paper doll only knew the weapon and armor
	var old_save: Dictionary = SaveManager.load_data()
	old_save.erase("equipped")
	old_save["weapon"] = "rusty_sword"
	old_save["armor"] = "hemp_garment"
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old_save))
	f = null
	await _new_game("hwarang", true)
	var old_weapon: ItemData = GameState.equipped_weapon
	var old_armor: ItemData = GameState.equipped_armor
	check(old_weapon != null and old_weapon.id == "rusty_sword", "an older save keeps its weapon")
	check(old_armor != null and old_armor.id == "hemp_garment", "an older save keeps its armor")
	check(GameState.equipped.size() == 2, "an older save fills only those two slots")
	SaveManager.delete_save()

func _test_paper_doll() -> void:
	print("[paper doll bag]")
	await _new_game("hwarang")
	_god_mode()
	_clear_monsters()
	var p: Player = game.player
	var bag: InventoryPanel = game.inventory_panel
	var hat: ItemData = ItemDatabase.get_item("satgat")
	GameState.add_item(hat)
	bag.show_panel()
	var turns: int = GameState.turn_count
	bag._on_bag_pressed(hat)
	check(bag._action.visible and bag._action.text == "장착", "a bag item offers to be worn")
	bag._on_action_pressed()
	check(GameState.equipped.get("head") == hat, "wearing from the bag puts it on")
	check(GameState.turn_count == turns + 1, "wearing takes a turn")
	var layers: int = p.layer_count()
	check(layers == 2, "the hat shows on the character, over the sword (%d)" % layers)
	var flying: bool = bag.get_children().any(func(c): return c is TextureRect)
	check(flying and bag._flying_slot == "head", "its icon flies from the bag to the slot")
	check(bag._doll.layers.size() == 2, "the figure waits for it to land")
	await get_tree().create_timer(0.5).timeout
	flying = bag.get_children().any(func(c): return c is TextureRect)
	check(not flying and bag._flying_slot == "", "and lands")
	check(bag._doll.layers.size() == 3, "then the bag's figure wears it too (body, sword, hat)")
	var head_icon: Texture2D = bag._slot_buttons["head"].icon
	check(bag._sel_slot == "head" and head_icon != null, "the doll shows where it went")
	check(bag._action.text == "벗기", "a worn slot offers to take it off")
	bag._on_action_pressed()
	check(not GameState.equipped.has("head"), "taking off from the doll works")
	check(p.layer_count() == 1 and bag._doll.layers.size() == 2, "and it leaves the character")
	check(GameState.turn_count == turns + 2, "taking off takes a turn")
	check(bag._sel_item == hat and bag._sel_slot == "", "what was taken off is selected in the bag")
	var wine: ItemData = ItemDatabase.get_item("flower_wine")
	GameState.add_item(wine)
	p.current_hp = 5
	bag._on_bag_pressed(wine)
	check(bag._action.text == "마시기", "a potion offers to be drunk")
	bag._on_action_pressed()
	check(p.current_hp > 5, "drinking from the bag heals")
	bag._on_slot_pressed("ring")
	var says_empty: bool = bag._detail.text.contains("비어")
	check(not bag._action.visible and says_empty, "an empty slot says it is empty")
	bag.hide_panel()

func _test_attack_and_motion() -> void:
	print("[attack button and motion]")
	var lines: Array[String] = []
	var log_line := func(text): lines.append(text)
	MessageBus.message_logged.connect(log_line)
	await _new_game("hwarang")
	_god_mode()
	_clear_monsters()
	var p: Player = game.player
	DungeonState.clear()
	for x in range(6):
		for y in range(6):
			DungeonState.grid[Vector2i(x, y)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(2, 2))
	var turns: int = GameState.turn_count
	game._on_attack_pressed()
	var told: bool = lines.any(func(l): return l.contains("곁에 없다"))
	check(GameState.turn_count == turns and told, "attacking with nobody beside spends no turn")

	# the weaker of two monsters beside the player is hit; one on the diagonal is not
	game._spawn_monster_at(MonsterDatabase.get_monster("bulgasari"), Vector2i(3, 2))
	var weak: Monster = game._spawn_monster_at(MonsterDatabase.get_monster("okjol"), Vector2i(2, 3))
	weak.current_hp = 10
	var diag: Monster = game._spawn_monster_at(MonsterDatabase.get_monster("yacha"), Vector2i(3, 3))
	diag.current_hp = 1
	lines.clear()
	game._on_attack_pressed()
	check(GameState.turn_count == turns + 1, "the attack button spends a turn")
	var hit := func(name: String) -> bool: return lines.any(func(l): return l.begins_with(name))
	check(hit.call("옥졸에"), "it strikes the weakest monster beside the player")
	check(not hit.call("야차에"), "a monster on the diagonal is not a target")
	MessageBus.message_logged.disconnect(log_line)

	# a one-tile step slides; a teleport snaps
	_clear_monsters()
	DungeonState.actors_at.clear()
	game._place_player(Vector2i(0, 0))
	DungeonState.move_actor(p, Vector2i(0, 0), Vector2i(1, 0))
	var target := Vector2(Constants.TILE_SIZE, 0)
	check(p.grid_pos == Vector2i(1, 0) and p.position != target, "a step starts sliding over")
	await get_tree().create_timer(0.25).timeout
	check(p.position == target and p.body.position == Vector2.ZERO, "the step lands on the tile")
	DungeonState.move_actor(p, Vector2i(1, 0), Vector2i(4, 4))
	var far := Vector2(4, 4) * Constants.TILE_SIZE
	check(p.position == far, "a teleport snaps straight there")
	p.play_attack(Vector2i(5, 4))
	# sample every frame of the motion: back first, then forward
	var first_back: int = -1
	var first_forward: int = -1
	for i in range(40):
		await get_tree().create_timer(0.008).timeout
		if p.body.position.x < 0.0 and first_back < 0:
			first_back = i
		if p.body.position.x > 0.0 and first_forward < 0:
			first_forward = i
	check(first_back >= 0, "an attack first winds up away from the target")
	check(first_forward > first_back, "then lunges toward it")
	await get_tree().create_timer(0.3).timeout
	check(p.body.position == Vector2.ZERO, "and comes back to rest")

	# a visible kill leaves a fading copy that cleans itself up
	var ghost: Monster = game._spawn_monster_at(MonsterDatabase.get_monster("mongdal"), Vector2i(4, 3))
	game._refresh_vision()
	var before: int = game.world.get_child_count()
	ghost.take_damage(9999)
	var fx_count := func() -> int:
		return game.world.get_children().filter(func(c): return c is TextureRect).size()
	check(fx_count.call() == 1, "a kill leaves a death effect")
	await get_tree().create_timer(DUNGEON_FX_WAIT).timeout
	check(fx_count.call() == 0 and game.world.get_child_count() < before, "the effect removes itself")

func _test_teleport_pickup() -> void:
	print("[teleport pickup]")
	await _new_game("mudang")
	_clear_monsters()
	var p: Player = game.player
	# only two floor tiles: the teleport can land only where the item lies
	DungeonState.clear()
	DungeonState.grid[Vector2i(0, 0)] = DungeonState.Tile.FLOOR
	DungeonState.grid[Vector2i(5, 5)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(0, 0))
	var wine: ItemData = ItemDatabase.get_item("flower_wine")
	DungeonState.place_item(Vector2i(5, 5), wine)
	var before: int = 0
	for e in GameState.inventory:
		if e.item_data == wine:
			before = e.quantity
	var talisman: ItemData = ItemDatabase.get_item("teleport_talisman")
	GameState.add_item(talisman)
	ItemEffects.use_item(talisman, p)
	var after: int = 0
	for e in GameState.inventory:
		if e.item_data == wine:
			after = e.quantity
	check(p.grid_pos == Vector2i(5, 5), "the teleport lands on the only free tile")
	var left_on_floor: bool = DungeonState.items_at.has(p.grid_pos)
	check(after == before + 1 and not left_on_floor, "what lies there is picked up")

func _test_stairs_on_request() -> void:
	print("[stairs on request]")
	var lines: Array[String] = []
	var log_line := func(text): lines.append(text)
	MessageBus.message_logged.connect(log_line)
	await _new_game("mudang")
	_clear_monsters()
	var p: Player = game.player
	# a corridor with the stairs in the middle: (0,0) .. (2,0)=stairs .. (4,0)
	DungeonState.clear()
	for x in range(5):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
	DungeonState.grid[Vector2i(2, 0)] = DungeonState.Tile.STAIRS_DOWN
	game._place_player(Vector2i(0, 0))
	game._on_direction_pressed(Vector2i(1, 0))
	game._on_direction_pressed(Vector2i(1, 0))
	var stayed: bool = GameState.current_floor == 1
	check(p.grid_pos == Vector2i(2, 0) and stayed, "stepping on the stairs does not go down")
	check(game.dpad.is_descend_visible(), "standing on the stairs shows the descend button")
	check(lines.any(func(l): return l.contains("[내려가기]")), "the player is told how to go down")
	game._on_direction_pressed(Vector2i(1, 0))
	check(not game.dpad.is_descend_visible(), "stepping off hides the descend button")
	game._on_descend_pressed()
	check(GameState.current_floor == 1, "descend does nothing off the stairs")
	game._on_direction_pressed(Vector2i(1, 0))
	await game._on_map_tapped(Vector2i(0, 0))
	stayed = GameState.current_floor == 1
	check(p.grid_pos == Vector2i(0, 0) and stayed, "a tapped walk passes over the stairs")
	await game._on_map_tapped(Vector2i(2, 0))
	var turns: int = GameState.turn_count
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	game._unhandled_input(enter)
	check(GameState.current_floor == 2, "Enter on the stairs goes down")
	check(GameState.turn_count == turns, "going down costs no turn")
	check(not game.dpad.is_descend_visible(), "the new floor starts with the button hidden")
	MessageBus.message_logged.disconnect(log_line)

func _count_in_bag(id: String) -> int:
	for e in GameState.inventory:
		if e.item_data.id == id:
			return e.quantity
	return 0

func _test_hunger() -> void:
	print("[hunger]")
	var lines: Array[String] = []
	var log_line := func(text): lines.append(text)
	MessageBus.message_logged.connect(log_line)
	await _new_game("mudang")
	_clear_monsters()
	var p: Player = game.player
	var rice: ItemData = ItemDatabase.get_item("jumeokbap")
	var packed: bool = _count_in_bag("jumeokbap") == 1
	check(GameState.hunger == 0 and packed, "a run starts full, with a rice ball")
	check(rice.get_display_name(false) == "주먹밥", "food needs no identifying")
	var refused: bool = not ItemEffects.use_item(rice, p)
	check(refused and _count_in_bag("jumeokbap") == 1, "nothing is eaten when full")
	check(game.hud.summary().contains("든든함 100%"), "a fresh run shows a full meter")
	var turns: int = GameState.turn_count
	p.wait_turn()
	check(GameState.hunger == 1 and GameState.turn_count == turns + 1, "hunger grows by one each turn")
	GameState.hunger = Player.HUNGRY - 1
	p.wait_turn()
	check(lines.any(func(l): return l.contains("배가 고프다")), "the player is warned when hungry")
	check(game.hud.summary().contains("배고픔"), "the HUD shows hunger")
	check(game.hud.summary().contains("배고픔 33%"), "the meter shows how full, as a percentage")
	check(Player.hunger_stage(0) == "든든함" and Player.hunger_stage(Player.WELL_FED) == "보통", "stages")
	GameState.hunger = Player.STARVING - 1
	p.current_hp = p.stats.max_hp - 20
	var hp: int = p.current_hp
	for i in range(10):
		p.wait_turn()
	check(GameState.hunger == Player.STARVING, "hunger stops rising once starving")
	check(game.hud.summary().contains("굶주림"), "the HUD shows starvation")
	check(p.current_hp == hp - 10 / Player.STARVE_INTERVAL, "starving drains HP and stops healing")
	turns = GameState.turn_count
	game._on_item_chosen(rice)
	var fed: int = Player.STARVING - rice.value_a + 1
	var took_turn: bool = GameState.turn_count == turns + 1
	check(took_turn and GameState.hunger == fed, "eating takes a turn and eases hunger")
	check(_count_in_bag("jumeokbap") == 0, "the food is used up")
	check(not game.hud.summary().contains("배고픔"), "a meal clears the hunger mark")
	var eaten: bool = lines.any(func(l): return l.contains("주먹밥을 먹었다"))
	check(eaten, "eating is logged")
	GameState.hunger = 123
	SaveManager.save_run(p)
	await _new_game("mudang", true)
	check(GameState.hunger == 123, "hunger survives save and continue")
	var one_each: bool = true
	for f in range(1, 6):
		game._load_floor(f)
		var meals: int = 0
		for item in DungeonState.items_at.values():
			if item.item_type == ItemData.ItemType.FOOD:
				meals += 1
		one_each = one_each and meals == 1
	check(one_each, "every floor lays out exactly one meal")
	IAPManager.reset_for_tests()
	IAPManager.purchase("revive_token")
	await _new_game("dosa")
	_clear_monsters()
	GameState.hunger = Player.STARVING
	game.player.current_hp = 1
	game.player.wait_turn()
	game.player.wait_turn()
	check(not game.player.is_alive and GameState.last_attacker == "굶주림", "starvation can kill")
	var said: String = game.game_over_screen._detail.text
	check(said.contains("굶주림에 쓰러졌다"), "the death screen says starvation (got %s)" % said)
	game._on_revive()
	check(game.player.is_alive and GameState.hunger == 0, "a revive also clears hunger")
	check(not game.hud.summary().contains("굶주림"), "the HUD drops the starving mark on revive")
	IAPManager.reset_for_tests()
	MessageBus.message_logged.disconnect(log_line)

func _test_graphics() -> void:
	print("[graphics]")
	var ids: Array = MonsterDatabase.monsters.keys() + ["mudang", "hwarang", "dosa"]
	var art_ok: bool = true
	for id in ids:
		var frames: Array[Texture2D] = SpriteLibrary.get_actor_frames(id)
		var sized: bool = frames.all(func(t): return t.get_size() == Vector2(24, 24))
		art_ok = art_ok and frames.size() == 2 and sized
	check(art_ok, "every character has two 24px idle frames")
	var gear_ok: bool = true
	for id in ItemDatabase.items.keys():
		var item: ItemData = ItemDatabase.get_item(id)
		if item.is_equipment():
			gear_ok = gear_ok and SpriteLibrary.get_gear_frames(id).size() == 2
	check(gear_ok, "every piece of equipment has a worn layer")
	var bare_ok: bool = ["mudang", "hwarang", "dosa"].all(
		func(c): return SpriteLibrary.get_actor_frames(c + "_bare").size() == 2)
	check(bare_ok, "every class has a bare body to dress")
	await _new_game("hwarang")
	_clear_monsters()
	var p: Player = game.player
	DungeonState.clear()
	for x in range(4):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(2, 0))
	game._on_direction_pressed(Vector2i(-1, 0))
	check(p.sprite.flip_h, "walking left turns the sprite left")
	game._on_direction_pressed(Vector2i(1, 0))
	check(not p.sprite.flip_h, "walking right turns it back")
	check(p.shadow.visible, "characters with art cast a ground shadow")
	game._load_floor(3)
	var looks: Array = []
	for pos in DungeonState.grid.keys():
		looks.append([DungeonRenderer.cell_hash(pos, 0), DungeonRenderer.decor_at(pos)])
	var again: Array = []
	for pos in DungeonState.grid.keys():
		again.append([DungeonRenderer.cell_hash(pos, 0), DungeonRenderer.decor_at(pos)])
	check(looks == again, "floor variants and decor are the same on every redraw")
	var light = game.floor_node.light
	light.refresh()
	var img: Image = light.light_map
	var here: Color = img.get_pixelv(p.grid_pos)
	var dark := Vector2i(-1, -1)
	for pos in DungeonState.grid.keys():
		if not DungeonState.explored.has(pos):
			dark = pos
			break
	check(dark.x >= 0 and img.get_pixelv(dark) == Color(0, 0, 0), "unexplored ground stays black")
	check(here.v > 0.8, "the player's own tile is brightly lit")

func _test_hit_feel() -> void:
	print("[hit feel]")
	await _new_game("hwarang")
	_clear_monsters()
	var p: Player = game.player
	DungeonState.clear()
	for x in range(5):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(1, 0))
	var goblin_data: MonsterData = MonsterDatabase.get_monster("dokkaebi")
	var goblin: Monster = game._spawn_monster_at(goblin_data, Vector2i(2, 0))
	goblin.stats.max_hp = 1000
	goblin.current_hp = 1000
	game._refresh_vision()
	goblin.set_hit_from(p.grid_pos)
	goblin.take_damage(1)
	var pushed: float = 0.0
	for i in range(20):
		await get_tree().create_timer(0.008).timeout
		pushed = maxf(pushed, goblin.body.position.x)
	check(pushed > 0.0, "a blow knocks the target back, away from the attacker")
	var labels: Array = game.world.get_children().filter(func(c): return c is Label)
	var small: Label = labels.back()
	goblin.take_damage(400)
	labels = game.world.get_children().filter(func(c): return c is Label)
	var big: Label = labels.back()
	var small_size: int = small.get_theme_font_size("font_size")
	var big_size: int = big.get_theme_font_size("font_size")
	check(big_size > small_size, "a heavy blow shows a bigger number")
	goblin.dodge(p.grid_pos)
	labels = game.world.get_children().filter(func(c): return c is Label)
	check((labels.back() as Label).text == "빗나감", "a miss says so over the one who dodged")
	var sparks: int = game.world.get_children().filter(func(c): return c is FxShape).size()
	goblin.set_hit_from(p.grid_pos)
	goblin.take_damage(1)
	var after: int = game.world.get_children().filter(func(c): return c is FxShape).size()
	check(after == sparks + 1, "a blow throws a spark where it lands")
	Fx.hit_stop_enabled = true
	goblin.set_hit_from(p.grid_pos)
	goblin.take_damage(1)
	check(Engine.time_scale < 1.0, "a blow freezes the picture for a moment")
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(Engine.time_scale == 1.0, "and the picture runs on again")
	Fx.hit_stop_enabled = false
	goblin.take_damage(1)
	check(Engine.time_scale == 1.0, "poison-like damage (no attacker) does not freeze")
	seed(99)
	var expected: int = randi()
	seed(99)
	Fx.shake(Fx.SHAKE_HEAVY)
	check(randi() == expected, "the camera shake does not use the game's dice")

## A 7x1 corridor with the player at x=1, for hazard and effect tests.
func _corridor(class_id: String) -> Player:
	await _new_game(class_id)
	_clear_monsters()
	DungeonState.clear()
	for x in range(7):
		DungeonState.grid[Vector2i(x, 0)] = DungeonState.Tile.FLOOR
	game._place_player(Vector2i(1, 0))
	game._refresh_vision()
	return game.player

func _test_hazards() -> void:
	print("[hazard zones]")
	await _new_game("mudang")
	var zoned: int = 0
	var clean: bool = true
	for f in range(2, 8):
		game._load_floor(f)
		if not DungeonState.hazards.is_empty():
			zoned += 1
		for pos in DungeonState.hazards.keys():
			if DungeonState.tile_at(pos) != DungeonState.Tile.FLOOR or pos == game.player.grid_pos:
				clean = false
	check(zoned >= 5, "floors from 2 on get hazard zones (%d of 6)" % zoned)
	check(clean, "zones lie only on plain floor, never under the player's start")
	var kinds: Dictionary = {}
	for pos in DungeonState.hazards.keys():
		kinds[DungeonState.hazards[pos]] = true
	var saved: Dictionary = DungeonState.hazards.duplicate()
	SaveManager.save_run(game.player)
	await _new_game("mudang", true)
	check(DungeonState.hazards == saved and not saved.is_empty(), "zones survive save and continue")

	var p: Player = await _corridor("hwarang")
	_god_mode()
	DungeonState.hazards[Vector2i(2, 0)] = HazardSystem.POISON
	var lines: Array[String] = []
	var log_line := func(text): lines.append(text)
	MessageBus.message_logged.connect(log_line)
	game._on_direction_pressed(Vector2i(1, 0))
	check(p.has_status("poison"), "a poison marsh poisons whoever stands in it")
	check(lines.any(func(l): return l.contains("늪")), "stepping in is announced")
	MessageBus.message_logged.disconnect(log_line)
	p.cure_status("poison")
	DungeonState.hazards.clear()
	DungeonState.hazards[Vector2i(3, 0)] = HazardSystem.ICE
	game._on_direction_pressed(Vector2i(1, 0))
	check(p.has_status("chill"), "ice chills")
	var dog_data: MonsterData = MonsterDatabase.get_monster("jeoseung_dog")
	var dog: Monster = game._spawn_monster_at(dog_data, Vector2i(6, 0))
	game._refresh_vision()
	var turns: int = GameState.turn_count
	game._on_wait_pressed()
	check(dog.grid_pos == Vector2i(4, 0), "while chilled the world moves twice (%s)" % dog.grid_pos)
	check(GameState.turn_count == turns + 1, "but only one turn of the player's passes")
	TurnManager.monsters.erase(dog)  # out of the way of the next checks
	DungeonState.clear_actor_at(dog.grid_pos)
	DungeonState.hazards.clear()
	p.statuses.clear()
	DungeonState.hazards[Vector2i(2, 0)] = HazardSystem.FIRE
	DungeonState.move_actor(p, p.grid_pos, Vector2i(2, 0))
	var hp: int = p.current_hp
	game._on_wait_pressed()
	check(p.current_hp < hp and GameState.last_attacker == "불길", "fire burns")
	p.apply_status("levitate", 5)
	hp = p.current_hp
	game._on_wait_pressed()
	check(p.current_hp >= hp, "a floating player is not burnt")
	DungeonState.hazards[dog.grid_pos] = HazardSystem.FIRE
	var dog_hp: int = dog.current_hp
	HazardSystem.affect(dog)
	check(dog.current_hp < dog_hp, "monsters burn too")
	DungeonState.hazards.clear()
	DungeonState.hazards[Vector2i(1, 0)] = HazardSystem.FIRE
	var route: Array[Vector2i] = Pathfinder.find_path(p.grid_pos, Vector2i(0, 0))
	check(route.size() == 3, "a hazard in a corridor with no way round is still walkable")

func _test_timed_effects() -> void:
	print("[timed effects]")
	var p: Player = await _corridor("mudang")
	var regen: ItemData = ItemDatabase.get_item("hoechuntang")
	GameState.add_item(regen)
	p.current_hp = 5
	game._on_item_chosen(regen)
	var lasting: bool = p.has_status("regen") and p.statuses["regen"] <= regen.value_a
	check(lasting, "the regen brew lasts its turns")
	var hp: int = p.current_hp
	game._on_wait_pressed()
	check(p.current_hp >= hp + 1, "and heals a point every turn")
	check(game.hud.summary().contains("회춘"), "the HUD lists the effect")
	var haste: ItemData = ItemDatabase.get_item("jilpungju")
	GameState.add_item(haste)
	game._on_item_chosen(haste)
	var dog_data: MonsterData = MonsterDatabase.get_monster("jeoseung_dog")
	var dog: Monster = game._spawn_monster_at(dog_data, Vector2i(6, 0))
	game._refresh_vision()
	var turns: int = GameState.turn_count
	game._on_wait_pressed()
	game._on_wait_pressed()
	check(GameState.turn_count == turns + 1, "haste: two actions take one turn")
	check(dog.grid_pos == Vector2i(5, 0), "and the monster moved only once (%s)" % dog.grid_pos)
	TurnManager.monsters.clear()
	DungeonState.clear_actor_at(dog.grid_pos)
	dog.queue_free()
	p.statuses.clear()
	var sight: ItemData = ItemDatabase.get_item("simantang")
	GameState.add_item(sight)
	game._load_floor(3)
	_clear_monsters()
	var before: int = DungeonState.visible_tiles.size()
	game._on_item_chosen(sight)
	check(DungeonState.visible_tiles.size() == DungeonState.grid.size(), "sight shows the whole floor")
	check(DungeonState.visible_tiles.size() > before, "far more than normal sight")
	p = await _corridor("mudang")
	var archer_data: MonsterData = MonsterDatabase.get_monster("mulgwisin")
	var archer: Monster = game._spawn_monster_at(archer_data, Vector2i(4, 0))
	archer.data = archer.data.duplicate()
	archer.data.ai_type = MonsterData.AIType.RANGED
	game._refresh_vision()
	var hide: ItemData = ItemDatabase.get_item("eunsin_talisman")
	GameState.add_item(hide)
	game._on_item_chosen(hide)
	archer.move_to_grid(Vector2i(4, 0))
	DungeonState.actors_at.erase(archer.grid_pos)
	DungeonState.clear_actor_at(Vector2i(3, 0))
	DungeonState.clear_actor_at(Vector2i(5, 0))
	DungeonState.set_actor_at(Vector2i(4, 0), archer)
	hp = p.current_hp
	archer.take_ai_turn()
	check(p.current_hp == hp, "an unseen player is not shot at from afar")
	check(p.body.modulate.a < 1.0, "the invisible player is drawn see-through")
	DungeonState.move_actor(archer, archer.grid_pos, p.grid_pos + Vector2i(1, 0))
	p.try_move(Vector2i(1, 0))
	check(not p.has_status("invisible"), "attacking gives the player away")
	var float_charm: ItemData = ItemDatabase.get_item("buyu_talisman")
	GameState.add_item(float_charm)
	game._on_item_chosen(float_charm)
	check(p.sprite.position.y < 0.0, "levitation lifts the character off the ground")
	DungeonState.grid[Vector2i(0, 0)] = DungeonState.Tile.TRAP
	DungeonState.move_actor(p, p.grid_pos, Vector2i(0, 0))
	check(not TrapSystem.trigger(p, Vector2i(0, 0)), "a floating player does not spring traps")
	check(DungeonState.tile_at(Vector2i(0, 0)) == DungeonState.Tile.TRAP, "and the trap stays armed")
	p.statuses["levitate"] = 1
	var ended: Array[String] = []
	var log_line := func(text): ended.append(text)
	MessageBus.message_logged.connect(log_line)
	game._on_wait_pressed()
	var landed: bool = not p.has_status("levitate") and p.sprite.position.y == 0.0
	check(landed, "it wears off and the player lands")
	check(ended.any(func(l): return l.contains("내려앉았다")), "wearing off is announced")
	MessageBus.message_logged.disconnect(log_line)

## A bare w x h room (walls all round) with the player at start and no monsters.
func _arena(class_id: String, w: int, h: int, start: Vector2i) -> Player:
	await _new_game(class_id)
	_clear_monsters()
	DungeonState.clear()
	for y in range(h):
		for x in range(w):
			DungeonState.grid[Vector2i(x, y)] = DungeonState.Tile.FLOOR
	game._place_player(start)
	game._refresh_vision()
	return game.player

func _test_boss_moves() -> void:
	print("[boss signature moves]")
	var p: Player = await _arena("hwarang", 7, 7, Vector2i(3, 2))
	_god_mode()
	var goo_data: MonsterData = MonsterDatabase.get_monster("eodukssini")
	var goo: Monster = game._spawn_monster_at(goo_data, Vector2i(3, 3))
	game._refresh_vision()
	var hp: int = p.current_hp
	goo.take_ai_turn()
	check(goo.is_winding_up() and p.current_hp == hp,
		"the floor-5 boss swells up instead of striking at once")
	var danger: Array[Vector2i] = goo.danger_tiles()
	check(danger.size() == 8 and danger.has(p.grid_pos), "a slam threatens all 8 tiles around it")
	check(goo._marks != null and goo._marks.tiles.size() == 8,
		"the threatened tiles are marked on the map")
	goo.take_ai_turn()
	check(p.current_hp < hp and not goo.is_winding_up(),
		"the slam lands on a player who stays beside it")
	check(goo._marks == null and goo.danger_tiles().is_empty(), "the marks go once the slam lands")
	check(goo._move_wait == goo.data.move_cooldown, "the slam then waits out its cooldown")
	goo.take_ai_turn()
	check(not goo.is_winding_up(), "between slams it fights normally")
	goo._move_wait = 0
	DungeonState.move_actor(p, p.grid_pos, Vector2i(4, 2))
	goo.take_ai_turn()
	hp = p.current_hp
	goo.take_ai_turn()
	check(p.current_hp < hp, "the slam reaches diagonals too")
	goo._move_wait = 0
	goo.take_ai_turn()
	DungeonState.move_actor(p, p.grid_pos, Vector2i(4, 1))
	hp = p.current_hp
	goo.take_ai_turn()
	check(p.current_hp == hp, "stepping off the marked tiles dodges the slam")
	goo._move_wait = 0
	DungeonState.move_actor(p, p.grid_pos, Vector2i(3, 2))
	p.apply_status("invisible", 5)
	goo.take_ai_turn()
	check(not goo.is_winding_up(), "it cannot aim at an invisible player")

	p = await _arena("hwarang", 7, 5, Vector2i(5, 2))
	_god_mode()
	var ox: Monster = game._spawn_monster_at(MonsterDatabase.get_monster("udu_nachal"), Vector2i(1, 2))
	game._refresh_vision()
	hp = p.current_hp
	ox.take_ai_turn()
	check(ox.is_winding_up() and ox.grid_pos == Vector2i(1, 2),
		"the floor-15 boss rears up when the player is in line")
	danger = ox.danger_tiles()
	check(danger.size() == 5 and danger.has(p.grid_pos), "the whole line up to the wall is marked")
	ox.take_ai_turn()
	check(ox.grid_pos == Vector2i(4, 2) and p.current_hp < hp,
		"the charge rushes up to the player and hits hard")
	ox._move_wait = 0
	DungeonState.move_actor(ox, ox.grid_pos, Vector2i(1, 2))
	ox.take_ai_turn()
	DungeonState.move_actor(p, p.grid_pos, Vector2i(5, 3))
	hp = p.current_hp
	ox.take_ai_turn()
	check(p.current_hp == hp and ox.grid_pos == Vector2i(6, 2),
		"a sidestep dodges; the charge runs on to the wall")
	check(ox.is_dazed(), "running into the wall leaves it dazed")
	ox.take_ai_turn()
	ox.take_ai_turn()
	check(ox.grid_pos == Vector2i(6, 2) and not ox.is_dazed(), "dazed for two turns, then it recovers")
	ox._move_wait = 0
	DungeonState.move_actor(ox, ox.grid_pos, Vector2i(1, 1))
	ox.take_ai_turn()
	check(not ox.is_winding_up(), "no charge when the player is not in a straight line")
	ox._move_wait = 0
	DungeonState.move_actor(ox, ox.grid_pos, Vector2i(1, 3))
	DungeonState.move_actor(p, p.grid_pos, Vector2i(2, 3))
	ox.take_ai_turn()
	check(not ox.is_winding_up(), "no charge from right beside the player")
