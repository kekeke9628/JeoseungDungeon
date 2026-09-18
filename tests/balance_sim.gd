extends Node
## Headless balance simulation: a greedy bot plays N full runs and reports
## outcomes. Run: Godot --headless --path . res://tests/BalanceSim.tscn

const RUNS: int = 20
const MAX_STEPS: int = 4000
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game: Node2D

func _ready() -> void:
	var wins: int = 0
	var floors: Array[int] = []
	for run in range(RUNS):
		seed(1000 + run)
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
		floors.append(GameState.current_floor)
		print("run %2d: %s floor=%d lv=%d turns=%d steps=%d" % [run, "WIN " if victory else "LOSE", GameState.current_floor, GameState.player_level, GameState.turn_count, steps])
		game.queue_free()
		await get_tree().process_frame
	var avg: float = 0.0
	for f in floors:
		avg += f
	print("== wins %d/%d, avg floor %.1f" % [wins, RUNS, avg / RUNS])
	get_tree().quit(0)

func _bot_step() -> void:
	var p = game.player
	if not is_instance_valid(p) or not p.is_alive:
		return
	_manage_inventory(p)
	var goal: Vector2i = _pick_goal(p)
	var step: Vector2i = _first_step(p.grid_pos, goal)
	if step == Vector2i.ZERO:
		game._on_wait_pressed()
	else:
		game._on_direction_pressed(step)

func _manage_inventory(p) -> void:
	if p.current_hp < p.stats.max_hp * 0.45:
		for e in GameState.inventory:
			if e.item_data.id == "flower_wine":
				game._on_item_chosen(e.item_data)
				return
	for e in GameState.inventory.duplicate():
		var d: ItemData = e.item_data
		if d.item_type == ItemData.ItemType.WEAPON and (GameState.equipped_weapon == null or d.value_a > GameState.equipped_weapon.value_a):
			game._on_item_chosen(d)
			return
		if d.item_type == ItemData.ItemType.ARMOR and (GameState.equipped_armor == null or d.value_b > GameState.equipped_armor.value_b):
			game._on_item_chosen(d)
			return
	for m in TurnManager.monsters:
		if is_instance_valid(m) and m.is_alive and maxi(absi(m.grid_pos.x - p.grid_pos.x), absi(m.grid_pos.y - p.grid_pos.y)) <= 2:
			for e in GameState.inventory:
				if e.item_data.id == "talisman":
					game._on_item_chosen(e.item_data)
					return

func _pick_goal(p) -> Vector2i:
	var best: Vector2i = DungeonState.stairs_pos
	var best_d: int = 9999
	for m in TurnManager.monsters:
		if is_instance_valid(m) and m.is_alive:
			var d: int = _bfs_dist(p.grid_pos, m.grid_pos)
			if d >= 0 and d <= 7 and d < best_d:
				best = m.grid_pos
				best_d = d
	if best_d < 9999:
		return best
	for pos in DungeonState.items_at.keys() + DungeonState.gold_at.keys():
		var d2: int = _bfs_dist(p.grid_pos, pos)
		if d2 >= 0 and d2 <= 12 and d2 < best_d:
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
			if n != to and DungeonState.get_actor_at(n) != null:
				continue
			prev[n] = cur
			queue.append(n)
	var none: Array[Vector2i] = []
	return none
