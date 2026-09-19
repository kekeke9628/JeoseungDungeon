extends Node
## Headless balance simulation: a thorough greedy bot (hunts every monster,
## collects loot, uses potions and class skills) plays full runs per class.
## Run: Godot --headless --path . res://tests/BalanceSim.tscn

const RUNS_PER_CLASS: int = 8
const MAX_STEPS: int = 3500
const CLASSES: Array[String] = ["mudang", "hwarang", "dosa"]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game: Node2D

func _ready() -> void:
	SettingsManager.settings_path = "user://test_settings.cfg"
	SettingsManager.tutorial_seen = true
	SaveManager.save_path = "user://sim_save.json"
	IAPManager.store_path = "user://sim_purchases.json"
	IAPManager.reset_for_tests()
	StatsManager.stats_path = "user://sim_stats.json"
	StatsManager.reset_for_tests()
	var total_wins: int = 0
	var total_runs: int = 0
	for cls in CLASSES:
		var wins: int = 0
		var floor_sum: int = 0
		for run in range(RUNS_PER_CLASS):
			seed(1000 + run)
			GameState.selected_class_id = cls
			GameState.pending_continue = false
			game = load("res://scenes/Game.tscn").instantiate()
			add_child(game)
			await get_tree().process_frame
			var steps: int = 0
			while not game._ended and steps < MAX_STEPS:
				_bot_step()
				steps += 1
			var victory: bool = game._ended and is_instance_valid(game.player) and game.player.is_alive
			if victory:
				wins += 1
			floor_sum += GameState.current_floor
			print("%-8s run %2d: %s floor=%2d lv=%2d turns=%4d" % [cls, run, "WIN " if victory else "LOSE", GameState.current_floor, GameState.player_level, GameState.turn_count])
			game.queue_free()
			await get_tree().process_frame
		print("== %s: wins %d/%d, avg floor %.1f" % [cls, wins, RUNS_PER_CLASS, float(floor_sum) / RUNS_PER_CLASS])
		total_wins += wins
		total_runs += RUNS_PER_CLASS
	print("== TOTAL wins %d/%d" % [total_wins, total_runs])
	SaveManager.delete_save()
	get_tree().quit(0)

func _bot_step() -> void:
	var p = game.player
	if not is_instance_valid(p) or not p.is_alive:
		return
	var turn_before: int = GameState.turn_count
	_use_consumables(p)
	if GameState.turn_count > turn_before or game._ended:
		return
	var goal: Vector2i = _pick_goal(p)
	var step: Vector2i = _first_step(p.grid_pos, goal)
	if step == Vector2i.ZERO:
		game._on_wait_pressed()
	else:
		game._on_direction_pressed(step)

func _nearest_monster_dist(p) -> int:
	var best: int = 9999
	for m in TurnManager.monsters:
		if is_instance_valid(m) and m.is_alive:
			best = mini(best, maxi(absi(m.grid_pos.x - p.grid_pos.x), absi(m.grid_pos.y - p.grid_pos.y)))
	return best

func _has(id: String) -> ItemData:
	for e in GameState.inventory:
		if e.item_data.id == id:
			return e.item_data
	return null

func _use_consumables(p) -> bool:
	var hp_ratio: float = float(p.current_hp) / float(p.stats.max_hp)
	var elixir: ItemData = _has("elixir")
	if elixir:
		game._on_item_chosen(elixir)
		return true
	if hp_ratio < 0.4:
		for id in ["immortal_wine", "flower_wine"]:
			var potion: ItemData = _has(id)
			if potion:
				game._on_item_chosen(potion)
				return true
		if GameState.player_class.skill_id == "salpuri" and GameState.skill_cooldown_left == 0:
			game._on_skill_pressed()
			return true
	for e in GameState.inventory.duplicate():
		var d: ItemData = e.item_data
		if d.item_type == ItemData.ItemType.WEAPON and (GameState.equipped_weapon == null or d.value_a > GameState.equipped_weapon.value_a):
			game._on_item_chosen(d)
			return true
		if d.item_type == ItemData.ItemType.ARMOR and (GameState.equipped_armor == null or d.value_b > GameState.equipped_armor.value_b):
			game._on_item_chosen(d)
			return true
	var near: int = _nearest_monster_dist(p)
	if near <= 4 and GameState.skill_cooldown_left == 0:
		var sid: String = GameState.player_class.skill_id
		if (sid == "ilseom" and near <= 1) or sid == "noejeon":
			game._on_skill_pressed()
			return true
	if near <= 2:
		var talisman: ItemData = _has("talisman")
		if talisman:
			game._on_item_chosen(talisman)
			return true
	return false

func _pick_goal(p) -> Vector2i:
	var best: Vector2i = DungeonState.stairs_pos
	var best_d: int = 9999
	for m in TurnManager.monsters:
		if is_instance_valid(m) and m.is_alive:
			var d: int = _bfs_dist(p.grid_pos, m.grid_pos)
			if d >= 0 and d < best_d:
				best = m.grid_pos
				best_d = d
	if best_d < 9999:
		return best
	for pos in DungeonState.items_at.keys() + DungeonState.gold_at.keys():
		var d2: int = _bfs_dist(p.grid_pos, pos)
		if d2 >= 0 and d2 < best_d:
			best = pos
			best_d = d2
	return best

func _bfs_dist(from: Vector2i, to: Vector2i) -> int:
	var path: Array[Vector2i] = _path(from, to)
	return path.size() - 1 if not path.is_empty() else -1

func _first_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var path: Array[Vector2i] = _path(from, to)
	if path.size() < 2:
		return Vector2i.ZERO
	return path[1] - from

func _path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var safe: Array[Vector2i] = _search(from, to, true)
	if not safe.is_empty():
		return safe
	return _search(from, to, false)

func _search(from: Vector2i, to: Vector2i, avoid_traps: bool) -> Array[Vector2i]:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			var out: Array[Vector2i] = [cur]
			while cur != from:
				cur = prev[cur]
				out.push_front(cur)
			return out
		for d in DIRS:
			var n: Vector2i = cur + d
			if prev.has(n) or not DungeonState.is_walkable(n):
				continue
			if n != to and (DungeonState.get_actor_at(n) != null or (avoid_traps and DungeonState.tile_at(n) == DungeonState.Tile.TRAP)):
				continue
			prev[n] = cur
			queue.append(n)
	var none: Array[Vector2i] = []
	return none
