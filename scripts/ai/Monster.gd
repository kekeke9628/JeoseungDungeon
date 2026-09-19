class_name Monster
extends Actor
## Monster actor. Behavior per turn is driven by its MonsterData.ai_type:
## - AGGRESSIVE: always closes distance within detect_radius, attacks when adjacent.
## - WANDER: mostly moves randomly; only chases while player is close, with a
##   chance to ignore it.
## - RANGED: attacks from up to 3 tiles away without needing to close in.
## - AMBUSH: stays still until the player is within 2 tiles, then attacks like AGGRESSIVE.

var data: MonsterData

func setup_from_data(p_data: MonsterData) -> void:
	data = p_data
	setup(p_data.stats, p_data.color, p_data.glyph, p_data.display_name, p_data.id)
	TurnManager.register_monster(self)

func take_ai_turn() -> void:
	var player_actor = TurnManager.player
	if player_actor == null or not player_actor.is_alive:
		return
	var dist: int = _chebyshev_distance(grid_pos, player_actor.grid_pos)
	match data.ai_type:
		MonsterData.AIType.WANDER:
			if dist <= 1:
				_attack(player_actor)
			elif dist <= data.detect_radius and randf() < 0.5:
				_move_toward(player_actor.grid_pos)
			else:
				_move_random()
		MonsterData.AIType.RANGED:
			if dist <= 3 and DungeonState.has_line_of_sight(grid_pos, player_actor.grid_pos):
				_attack(player_actor)
			elif dist <= data.detect_radius:
				_move_toward(player_actor.grid_pos)
		MonsterData.AIType.AMBUSH:
			if dist <= 1:
				_attack(player_actor)
			elif dist <= 2:
				_move_toward(player_actor.grid_pos)
		_:  # AGGRESSIVE and default
			if dist <= 1:
				_attack(player_actor)
			elif dist <= data.detect_radius:
				_move_toward(player_actor.grid_pos)

func die() -> void:
	TurnManager.unregister_monster(self)
	DungeonState.clear_actor_at(grid_pos)
	GameState.add_xp(data.xp_reward)
	StatsManager.record_kill()
	MessageBus.log_message("%s 물리쳤다! (경험치 +%d)" % [Josa.eul_reul(display_name), data.xp_reward])
	if data.loot_item_ids.size() > 0 and randf() < data.loot_chance:
		var item_id: String = data.loot_item_ids[randi() % data.loot_item_ids.size()]
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item:
			DungeonState.place_item(grid_pos, item)
			MessageBus.log_message("%s 무언가를 떨어뜨렸다." % Josa.i_ga(display_name))
	if data.is_boss and data.max_floor >= Constants.MAX_FLOOR:
		MessageBus.log_message("%s 물리쳤다! 저승을 탈출했다!" % Josa.eul_reul(display_name))
		GameState.game_over.emit(true)
	elif data.is_boss:
		MessageBus.log_message("%s 쓰러뜨렸다. 저승 더 깊은 곳으로 길이 열렸다." % Josa.eul_reul(display_name))
	super.die()

func _attack(target) -> void:
	var result := CombatSystem.resolve_attack(self, target)
	AudioManager.play("hurt" if result.hit else "miss")
	if result.hit:
		MessageBus.log_message("%s %d의 피해를 입혔다!" % [Josa.i_ga(display_name), result.damage])
	else:
		MessageBus.log_message("%s의 공격이 빗나갔다." % display_name)

func _move_toward(target_pos: Vector2i) -> void:
	var dx: int = signi(target_pos.x - grid_pos.x)
	var dy: int = signi(target_pos.y - grid_pos.y)
	var candidates: Array[Vector2i] = [
		grid_pos + Vector2i(dx, dy),
		grid_pos + Vector2i(dx, 0),
		grid_pos + Vector2i(0, dy),
	]
	for next_pos in candidates:
		if next_pos != grid_pos and DungeonState.is_walkable(next_pos) and DungeonState.get_actor_at(next_pos) == null:
			DungeonState.move_actor(self, grid_pos, next_pos)
			return

func _move_random() -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var np: Vector2i = grid_pos + d
		if DungeonState.is_walkable(np) and DungeonState.get_actor_at(np) == null:
			DungeonState.move_actor(self, grid_pos, np)
			return

func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
