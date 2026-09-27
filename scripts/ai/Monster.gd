class_name Monster
extends Actor
## Monster actor. Behavior per turn is driven by its MonsterData.ai_type:
## - AGGRESSIVE: always closes distance within detect_radius, attacks when adjacent.
## - WANDER: mostly moves randomly; only chases while player is close, with a
##   chance to ignore it.
## - RANGED: attacks from up to 3 tiles away without needing to close in.
## - AMBUSH: stays still until the player is within 2 tiles, then attacks like AGGRESSIVE.
##
## Like the player, monsters move and strike only up, down, left and right, so
## a monster standing diagonally must step beside the player before it can hit.
## RANGED attacks still reach any tile in range.
##
## Monsters do not see traps either, so any move can spring one (see TrapSystem).
##
## Some bosses have a signature move (MonsterData.boss_move), after Shattered
## Pixel Dungeon's bosses: they spend a turn winding up - the tiles it will
## strike glow red - and let it go on their next turn, so a player who reads
## the warning can step out of the way. "slam" hits every tile around the boss;
## "charge" rushes down a straight line and leaves the boss dazed if it ends
## in a wall. Below MonsterData.enrage_fraction of its HP a boss is enraged
## for the rest of the fight, like the bosses there at half health.

## Summoned minions come from a much shallower tier so they pressure, not overwhelm.
const SUMMON_TIER_DROP: int = 6
## Difficulty knob: every monster's attack is scaled by this when it spawns.
## Raised when monsters lost their diagonal strikes and the player gained four
## more equipment slots. With tests/BalanceSim.tscn the bot won 19 of 48 runs at
## 1.12 (1.0: 17/24, 1.10: 10/24, 1.15: 6/24, 1.25: 2/24).
const ATTACK_SCALE: float = 1.12
## Longest rush of a charge, in tiles; a charge starts from 2 tiles away or more.
const CHARGE_RANGE: int = 6
## Turns a charger stays dazed after running into a wall.
const CRASH_TURNS: int = 2
## How much a slammer swells while winding up.
const SWELL: float = 1.35
const CHARGE_STEP_TIME: float = 0.04
## Values above 1 brighten: a wound-up boss glows red even on a dark floor.
const WINDUP_TINT := Color(1.8, 0.85, 0.8)
const DAZED_TINT := Color(0.7, 0.7, 0.85)
## Enraged: blows land this much harder, and the boss stays tinted red.
const ENRAGE_ATTACK: float = 1.25
const ENRAGED_TINT := Color(1.3, 0.75, 0.75)

var data: MonsterData
var _summoned: bool = false
## Standing on ice: this monster loses its next turn.
var _chilled: bool = false
## Signature move: wound up and let go next turn; turns until it can be used
## again; the charge's direction; turns left dazed after a crash.
var _winding_up: bool = false
var _move_wait: int = 0
var _charge_dir := Vector2i.ZERO
var _dazed: int = 0
var _marks: DangerMarks
var _enraged: bool = false

func setup_from_data(p_data: MonsterData) -> void:
	data = p_data
	# A copy: the MonsterData stats resource is shared by every monster of the kind.
	var scaled: ActorStats = p_data.stats.duplicate()
	scaled.attack_min = roundi(scaled.attack_min * ATTACK_SCALE)
	scaled.attack_max = roundi(scaled.attack_max * ATTACK_SCALE)
	setup(scaled, p_data.color, p_data.glyph, p_data.display_name, p_data.id)
	TurnManager.register_monster(self)

func take_ai_turn() -> void:
	var player_actor = TurnManager.player
	if player_actor == null or not player_actor.is_alive:
		return
	if _chilled:
		_chilled = false
		return
	if _dazed > 0:
		_dazed -= 1
		if _dazed == 0:
			sprite.self_modulate = Color.WHITE
		return
	if _winding_up:
		_release_move(player_actor)
		return
	if _move_wait > 0:
		_move_wait -= 1
	elif _start_move(player_actor):
		return
	var dist: int = _chebyshev_distance(grid_pos, player_actor.grid_pos)
	var beside: bool = _is_beside(player_actor.grid_pos)
	# An invisible player is only noticed by what bumps right into them.
	if player_actor.has_status("invisible") and not beside:
		if data.ai_type != MonsterData.AIType.AMBUSH:
			_move_random()
		return
	match data.ai_type:
		MonsterData.AIType.WANDER:
			if beside:
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
			if beside:
				_attack(player_actor)
			elif dist <= 2:
				_move_toward(player_actor.grid_pos)
		_:  # AGGRESSIVE and default
			if beside:
				_attack(player_actor)
			elif dist <= data.detect_radius:
				_move_toward(player_actor.grid_pos)

## Ice under a monster costs it its next turn.
func chill() -> void:
	_chilled = true

## Tiles the move being wound up will strike (none when not winding up). A
## charge's line is drawn to where it would stop at a wall; anyone standing in
## it stops it sooner.
func danger_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _winding_up:
		return out
	match data.boss_move:
		"slam":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var pos := grid_pos + Vector2i(dx, dy)
					if pos != grid_pos and DungeonState.is_walkable(pos):
						out.append(pos)
		"charge":
			var pos := grid_pos
			for i in range(CHARGE_RANGE):
				pos += _charge_dir
				if not DungeonState.is_walkable(pos):
					break
				out.append(pos)
	return out

func is_winding_up() -> bool:
	return _winding_up

func is_dazed() -> bool:
	return _dazed > 0

## Winds up the signature move if the player is where it would land.
func _start_move(target) -> bool:
	if data.boss_move.is_empty() or target.has_status("invisible"):
		return false
	match data.boss_move:
		"slam":
			if _chebyshev_distance(grid_pos, target.grid_pos) > 1:
				return false
			MessageBus.log_message("%s 몸을 잔뜩 부풀린다! 곁에서 물러나라!" % Josa.i_ga(display_name))
		"charge":
			var dir: Vector2i = _clear_line_to(target.grid_pos)
			if dir == Vector2i.ZERO:
				return false
			_charge_dir = dir
			_face(dir.x)
			MessageBus.log_message("%s 뿔을 낮추고 콧김을 내뿜는다! 길목에서 비켜라!" % Josa.i_ga(display_name))
		_:
			return false
	_winding_up = true
	_show_windup()
	return true

## The direction of a charge at pos: straight up, down, left or right, 2 to
## CHARGE_RANGE tiles away, in sight and with nothing in between. ZERO if not.
func _clear_line_to(pos: Vector2i) -> Vector2i:
	var delta: Vector2i = pos - grid_pos
	if delta.x != 0 and delta.y != 0:
		return Vector2i.ZERO
	var dist: int = absi(delta.x) + absi(delta.y)
	if dist < 2 or dist > CHARGE_RANGE or not DungeonState.has_line_of_sight(grid_pos, pos):
		return Vector2i.ZERO
	var dir := Vector2i(signi(delta.x), signi(delta.y))
	for i in range(1, dist):
		var between: Vector2i = grid_pos + dir * i
		if not DungeonState.is_walkable(between) or DungeonState.get_actor_at(between) != null:
			return Vector2i.ZERO
	return dir

func _release_move(target) -> void:
	_winding_up = false
	_move_wait = maxi(1, data.move_cooldown - 1) if _enraged else data.move_cooldown
	_end_windup()
	match data.boss_move:
		"slam":
			_slam(target)
		"charge":
			_charge(target)

## Strikes every tile around: whoever is still beside it (diagonals too) is hit.
func _slam(target) -> void:
	MessageBus.log_message("%s 온몸으로 바닥을 내리찍는다!" % Josa.i_ga(display_name))
	AudioManager.play("hit_heavy")
	Fx.slam(self)
	if _chebyshev_distance(grid_pos, target.grid_pos) <= 1:
		_heavy_blow(target)
	else:
		MessageBus.log_message("간발의 차로 피했다!")

## Rushes down the line it wound up for until something stops it: the player
## (a heavy blow), another monster, a wall (dazed) or the end of its reach.
func _charge(target) -> void:
	MessageBus.log_message("%s 돌진한다!" % Josa.i_ga(display_name))
	AudioManager.play("hit_heavy")
	var steps: int = 0
	var crashed: bool = false
	var struck = null
	while steps < CHARGE_RANGE:
		var next: Vector2i = grid_pos + _charge_dir
		if not DungeonState.is_walkable(next):
			crashed = true
			break
		var in_way = DungeonState.get_actor_at(next)
		if in_way != null:
			if in_way == target:
				struck = target
			break
		if visible:
			Fx.dust(get_parent(), grid_pos)
		DungeonState.move_actor(self, grid_pos, next)
		TrapSystem.trigger(self, next)
		steps += 1
	if steps > 1 and _move_tween != null and _move_tween.is_valid():
		# one long slide rather than a hop per tile
		_move_tween.kill()
		_move_tween = create_tween()
		var end := Vector2(grid_pos * Constants.TILE_SIZE)
		_move_tween.tween_property(self, "position", end, CHARGE_STEP_TIME * steps)
	if struck != null:
		_heavy_blow(struck)
	elif crashed:
		_dazed = 1 if _enraged else CRASH_TURNS
		sprite.self_modulate = DAZED_TINT
		MessageBus.log_message("%s 벽에 머리를 들이받고 비틀거린다!" % Josa.i_ga(display_name))
		_show_popup("어질어질", COLOR_MISS)
		if visible:
			Fx.shake(Fx.SHAKE_HEAVY)
	else:
		MessageBus.log_message("간발의 차로 피했다!")

## The signature move landing: it never misses and hits move_power times as
## hard as an ordinary blow (armour still counts).
func _heavy_blow(target) -> void:
	var raw: int = roundi(randi_range(stats.attack_min, stats.attack_max) * data.move_power)
	var dmg: int = maxi(1, raw - target.stats.defense)
	if target is Player:
		GameState.last_attacker = display_name
	MessageBus.log_message("%s %d의 큰 피해를 입혔다!" % [Josa.i_ga(display_name), dmg])
	play_attack(target.grid_pos)
	target.set_hit_from(grid_pos)
	target.take_damage(dmg)

## Swells or rears up, tints red, and marks the tiles about to be struck.
func _show_windup() -> void:
	_marks = DangerMarks.new()
	for pos in danger_tiles():
		_marks.tiles.append(pos - grid_pos)
	_marks.z_index = Fx.Z
	add_child(_marks)
	AudioManager.play("windup")
	sprite.self_modulate = WINDUP_TINT
	var ts: float = Constants.TILE_SIZE
	sprite.pivot_offset = Vector2(ts * 0.5, ts * 0.95)
	var grow: float = SWELL if data.boss_move == "slam" else 1.1
	_tween_sprite_scale(Vector2(grow, grow), 0.25)

func _end_windup() -> void:
	if is_instance_valid(_marks):
		_marks.queue_free()
	_marks = null
	sprite.self_modulate = Color.WHITE
	_tween_sprite_scale(Vector2.ONE, 0.12)

func _tween_sprite_scale(to: Vector2, time: float) -> void:
	if not is_inside_tree():
		sprite.scale = to
		return
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", to, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Bosses smash floor traps instead of falling into them, so a boss fight is
## never cut short by a teleport trap.
func ignores_traps() -> bool:
	return data != null and data.is_boss

## Whether the one-time summon already happened (kept across saves so a
## reloaded boss does not call its escorts a second time).
func has_summoned() -> bool:
	return _summoned

## Puts a reloaded monster back the way it was saved (an enraged boss comes
## back enraged: that follows from its HP).
func restore_state(hp: int, summoned: bool) -> void:
	current_hp = clampi(hp, 1, stats.max_hp)
	_summoned = summoned
	_update_hp_bar()
	if _should_enrage():
		_enrage(false)

func is_enraged() -> bool:
	return _enraged

func _should_enrage() -> bool:
	return not _enraged and data.enrage_fraction > 0.0 \
		and float(current_hp) / float(stats.max_hp) <= data.enrage_fraction

func _enrage(announce: bool) -> void:
	_enraged = true
	stats.attack_min = roundi(stats.attack_min * ENRAGE_ATTACK)
	stats.attack_max = roundi(stats.attack_max * ENRAGE_ATTACK)
	sprite.modulate = ENRAGED_TINT
	if announce:
		MessageBus.log_message("%s 분노했다! 더욱 사나워진다!" % Josa.i_ga(display_name))
		AudioManager.play("windup")
		if visible:
			Fx.shake(Fx.SHAKE_LIGHT)

func die() -> void:
	TurnManager.unregister_monster(self)
	DungeonState.clear_actor_at(grid_pos)
	GameState.add_xp(data.xp_reward)
	StatsManager.record_kill()
	MessageBus.log_message("%s 물리쳤다! (경험치 +%d)" % [Josa.eul_reul(display_name), data.xp_reward])
	if data.loot_item_ids.size() > 0 and randf() < data.loot_chance:
		var item_id: String = data.loot_item_ids[randi() % data.loot_item_ids.size()]
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item and DungeonState.drop_item(grid_pos, item):
			MessageBus.log_message("%s 무언가를 떨어뜨렸다." % Josa.i_ga(display_name))
	if data.is_boss and data.max_floor >= Constants.MAX_FLOOR:
		MessageBus.log_message("%s 물리쳤다! 저승을 탈출했다!" % Josa.eul_reul(display_name))
		GameState.game_over.emit(true)
	elif data.is_boss:
		MessageBus.log_message("%s 쓰러뜨렸다. 저승 더 깊은 곳으로 길이 열렸다." % Josa.eul_reul(display_name))
	Fx.soul(self)
	_spawn_death_fx()
	super.die()

func hit_color() -> Color:
	return data.hit_color if data != null else super.hit_color()

func _attack(target) -> void:
	play_attack(target.grid_pos)
	target.set_hit_from(grid_pos)
	var result := CombatSystem.resolve_attack(self, target)
	AudioManager.play("hurt" if result.hit else "miss")
	if not result.hit:
		target.set_hit_from(Actor.NO_HIT)
		target.dodge(grid_pos)
	if result.hit:
		MessageBus.log_message("%s %d의 피해를 입혔다!" % [Josa.i_ga(display_name), result.damage])
		if target is Player:
			GameState.last_attacker = display_name
		_try_special(target)
	else:
		MessageBus.log_message("%s의 공격이 빗나갔다." % display_name)

## Steps one square toward target_pos along the longer axis first, falling
## back to the other axis when that square is blocked.
func _move_toward(target_pos: Vector2i) -> void:
	var delta: Vector2i = target_pos - grid_pos
	var candidates: Array[Vector2i] = [
		grid_pos + Vector2i(signi(delta.x), 0),
		grid_pos + Vector2i(0, signi(delta.y)),
	]
	if absi(delta.y) > absi(delta.x):
		candidates.reverse()
	for next_pos in candidates:
		if next_pos != grid_pos and DungeonState.is_walkable(next_pos) and DungeonState.get_actor_at(next_pos) == null:
			DungeonState.move_actor(self, grid_pos, next_pos)
			TrapSystem.trigger(self, next_pos)
			return

func _move_random() -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var np: Vector2i = grid_pos + d
		if DungeonState.is_walkable(np) and DungeonState.get_actor_at(np) == null:
			DungeonState.move_actor(self, grid_pos, np)
			TrapSystem.trigger(self, np)
			return

func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

## True when pos is directly up, down, left or right of this monster.
func _is_beside(pos: Vector2i) -> bool:
	return absi(pos.x - grid_pos.x) + absi(pos.y - grid_pos.y) == 1

func _try_special(target) -> void:
	if data.special.is_empty() or not (target is Player) or not target.is_alive:
		return
	if randf() >= data.special_chance:
		return
	match data.special:
		"poison":
			target.apply_status("poison", Player.POISON_TURNS)
			MessageBus.log_message("독에 중독됐다!")
		"stun":
			target.apply_status("stun", Player.STUN_TURNS)
			MessageBus.log_message("정신이 아찔하다! 잠시 움직일 수 없다.")

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if is_alive and _should_enrage():
		_enrage(true)
	if is_alive and not _summoned and data.summon_fraction > 0.0 			and float(current_hp) / float(stats.max_hp) <= data.summon_fraction:
		_summoned = true
		_summon_minions()

## Calls escorts onto free floor tiles around the boss (nearest rings first).
func _summon_minions() -> void:
	var pool: Array[MonsterData] = MonsterDatabase.get_monsters_for_floor(maxi(1, GameState.current_floor - SUMMON_TIER_DROP))
	if pool.is_empty() or get_parent() == null:
		return
	MessageBus.log_message("%s 수하를 불러냈다!" % Josa.i_ga(display_name))
	AudioManager.play("skill")
	var spawned: int = 0
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if spawned >= data.summon_count:
					return
				var pos := grid_pos + Vector2i(dx, dy)
				if DungeonState.tile_at(pos) != DungeonState.Tile.FLOOR or DungeonState.get_actor_at(pos) != null:
					continue
				var minion := Monster.new()
				get_parent().add_child(minion)
				minion.setup_from_data(pool[randi() % pool.size()])
				minion.move_to_grid(pos)
				minion.visible = DungeonState.visible_tiles.has(pos)
				DungeonState.set_actor_at(pos, minion)
				spawned += 1
