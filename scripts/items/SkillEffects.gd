class_name SkillEffects
## Active class skills. use() returns true when the skill fired (and so
## should consume a turn and start its cooldown).

const HEAL_FRACTION: float = 0.4
const SLASH_MULTIPLIER: int = 3
const LIGHTNING_RANGE: int = 4
const LIGHTNING_BASE_DAMAGE: int = 8
const LIGHTNING_PER_LEVEL: int = 3

static func use(skill_id: String, player: Player) -> bool:
	match skill_id:
		"salpuri":
			return _salpuri(player)
		"ilseom":
			return _ilseom(player)
		"noejeon":
			return _noejeon(player)
	return false

static func _salpuri(player: Player) -> bool:
	var amount: int = int(player.stats.max_hp * HEAL_FRACTION)
	player.heal(amount)
	MessageBus.log_message("살풀이 한 판! 체력이 %d 회복됐다." % amount)
	return true

static func _ilseom(player: Player) -> bool:
	var target = null
	for m in TurnManager.monsters:
		if not is_instance_valid(m) or not m.is_alive:
			continue
		if maxi(absi(m.grid_pos.x - player.grid_pos.x), absi(m.grid_pos.y - player.grid_pos.y)) <= 1:
			if target == null or m.current_hp < target.current_hp:
				target = m
	if target == null:
		MessageBus.log_message("일섬을 날릴 적이 곁에 없다.")
		return false
	var dmg: int = randi_range(player.stats.attack_min, player.stats.attack_max) * SLASH_MULTIPLIER
	MessageBus.log_message("일섬! %s에게 %d의 피해를 입혔다." % [target.display_name, dmg])
	target.take_damage(dmg)
	return true

static func _noejeon(player: Player) -> bool:
	var dmg: int = LIGHTNING_BASE_DAMAGE + LIGHTNING_PER_LEVEL * GameState.player_level
	var hit: int = 0
	for m in TurnManager.monsters.duplicate():
		if not is_instance_valid(m) or not m.is_alive:
			continue
		var dist: int = maxi(absi(m.grid_pos.x - player.grid_pos.x), absi(m.grid_pos.y - player.grid_pos.y))
		if dist <= LIGHTNING_RANGE and DungeonState.has_line_of_sight(player.grid_pos, m.grid_pos):
			m.take_damage(dmg)
			hit += 1
	if hit == 0:
		MessageBus.log_message("뇌전을 내릴 적이 시야에 없다.")
		return false
	MessageBus.log_message("뇌전이 내리쳐 %d마리에게 %d의 피해를 입혔다!" % [hit, dmg])
	return true
