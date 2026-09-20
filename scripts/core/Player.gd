class_name Player
extends Actor
## Player-controlled actor. Movement/attack/wait are invoked by Game.gd in
## response to input; this class only resolves the consequences of one action.

signal status_changed

const POISON_TURNS: int = 4
const STUN_TURNS: int = 1
const WELL_HEAL_FRACTION: float = 0.5

func _ready() -> void:
	TurnManager.register_player(self)

## Attempts to move one tile in dir; attacks if a monster occupies the target
## tile, moves if walkable and empty, otherwise does nothing.
## Returns true if a turn was actually consumed.
func try_move(dir: Vector2i) -> bool:
	var target := grid_pos + dir
	var blocking_actor = DungeonState.get_actor_at(target)
	if blocking_actor != null and blocking_actor != self:
		var result := CombatSystem.roll_attack(self, blocking_actor)
		_log_attack_result(result, blocking_actor)
		if result.hit:
			blocking_actor.take_damage(result.damage)
		TurnManager.end_player_turn()
		return true
	if DungeonState.is_walkable(target):
		DungeonState.move_actor(self, grid_pos, target)
		_check_pickup(target)
		TrapSystem.trigger(self, target)
		_check_feature(target)
		TurnManager.end_player_turn()
		return true
	return false

func wait_turn() -> void:
	TurnManager.end_player_turn()

func is_player_actor() -> bool:
	return true

## The player node is kept alive on death so a revive token can bring it back.
func die() -> void:
	is_alive = false
	modulate = Color(1, 1, 1, 0.45)
	died.emit(self)
	GameState.game_over.emit(false)

func revive(hp_fraction: float) -> void:
	is_alive = true
	modulate = Color.WHITE
	statuses.clear()
	sprite.modulate = Color.WHITE
	status_changed.emit()
	current_hp = maxi(1, int(stats.max_hp * hp_fraction))
	_update_hp_bar()
	hp_changed.emit(current_hp, stats.max_hp)

func _log_attack_result(result: Dictionary, target) -> void:
	AudioManager.play("hit" if result.hit else "miss")
	if result.hit:
		MessageBus.log_message("%s에게 %d의 피해를 입혔다!" % [target.display_name, result.damage])
	else:
		MessageBus.log_message("%s에 대한 공격이 빗나갔다." % target.display_name)

func _check_pickup(pos: Vector2i) -> void:
	var item: ItemData = DungeonState.take_item_at(pos)
	if item:
		GameState.add_item(item)
		AudioManager.play("pickup")
		MessageBus.log_message("%s 주웠다." % Josa.eul_reul(item.get_display_name(GameState.is_identified(item.id))))
	var gold: int = DungeonState.take_gold_at(pos)
	if gold > 0:
		GameState.add_gold(gold)
		AudioManager.play("gold")
		MessageBus.log_message("저승길 동전 %d개를 주웠다." % gold)

## Active status effects: name -> turns left ("poison", "stun").
var statuses: Dictionary = {}

func has_status(status_name: String) -> bool:
	return statuses.has(status_name)

func apply_status(status_name: String, turns: int) -> void:
	statuses[status_name] = maxi(int(statuses.get(status_name, 0)), turns)
	sprite.modulate = _rest_tint()
	status_changed.emit()

func cure_status(status_name: String) -> void:
	if statuses.erase(status_name):
		sprite.modulate = _rest_tint()
		status_changed.emit()

## Called once per player turn: poison hurts, then all timers count down.
func tick_statuses() -> void:
	if statuses.is_empty():
		return
	if statuses.has("poison"):
		var dmg: int = 1 + GameState.current_floor / 8
		MessageBus.log_message("독이 온몸에 퍼져 %d의 피해를 입었다." % dmg)
		GameState.last_attacker = "독"
		take_damage(dmg)
	for key in statuses.keys():
		statuses[key] -= 1
		if statuses[key] <= 0:
			statuses.erase(key)
	sprite.modulate = _rest_tint()
	status_changed.emit()

func status_text() -> String:
	var names := {"poison": "독", "stun": "기절"}
	var parts: Array[String] = []
	for key in statuses.keys():
		parts.append("%s %d" % [names.get(key, key), statuses[key]])
	return " ".join(parts)

func _rest_tint() -> Color:
	if statuses.has("poison"):
		return Color(0.6, 1.0, 0.6)
	if statuses.has("stun"):
		return Color(1.0, 1.0, 0.6)
	return Color.WHITE

## Wells and altars are used up when triggered. A well is left alone if it
## would be wasted (full HP, no poison).
func _check_feature(pos: Vector2i) -> void:
	match DungeonState.tile_at(pos):
		DungeonState.Tile.WELL:
			if current_hp >= stats.max_hp and not has_status("poison"):
				MessageBus.log_message("맑은 우물이 있다. 지금은 필요하지 않다.")
				return
			cure_status("poison")
			heal(int(stats.max_hp * WELL_HEAL_FRACTION))
			DungeonState.set_tile(pos, DungeonState.Tile.FLOOR)
			AudioManager.play("potion")
			MessageBus.log_message("우물물을 마시니 기운이 돌아온다.")
		DungeonState.Tile.ALTAR:
			DungeonState.set_tile(pos, DungeonState.Tile.FLOOR)
			AudioManager.play("levelup")
			match randi() % 3:
				0:
					stats.max_hp += 6
					heal(6)
					MessageBus.log_message("제단이 생명을 나누어 주었다. 최대 체력 +6")
				1:
					stats.attack_min += 1
					stats.attack_max += 1
					MessageBus.log_message("제단이 힘을 나누어 주었다. 공격력 +1")
				_:
					stats.defense += 1
					MessageBus.log_message("제단이 가호를 내렸다. 방어력 +1")
