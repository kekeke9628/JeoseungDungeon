class_name Player
extends Actor
## Player-controlled actor. Movement/attack/wait are invoked by Game.gd in
## response to input; this class only resolves the consequences of one action.

const TRAP_BASE_DAMAGE: int = 4
const TELEPORT_TRAP_CHANCE: float = 0.4

func _ready() -> void:
	TurnManager.register_player(self)

## Attempts to move one tile in dir; attacks if a monster occupies the target
## tile, moves if walkable and empty, otherwise does nothing.
## Returns true if a turn was actually consumed.
func try_move(dir: Vector2i) -> bool:
	var target := grid_pos + dir
	var blocking_actor = DungeonState.get_actor_at(target)
	if blocking_actor != null and blocking_actor != self:
		var result := CombatSystem.resolve_attack(self, blocking_actor)
		_log_attack_result(result, blocking_actor)
		TurnManager.end_player_turn()
		return true
	if DungeonState.is_walkable(target):
		DungeonState.move_actor(self, grid_pos, target)
		_check_pickup(target)
		_check_trap(target)
		TurnManager.end_player_turn()
		return true
	return false

func wait_turn() -> void:
	TurnManager.end_player_turn()

func die() -> void:
	GameState.game_over.emit(false)
	super.die()

func _log_attack_result(result: Dictionary, target) -> void:
	if result.hit:
		var msg: String = "%s에게 %d의 피해를 입혔다!" % [target.display_name, result.damage]
		if result.defender_died:
			msg += " %s 물리쳤다!" % Josa.eul_reul(target.display_name)
		MessageBus.log_message(msg)
	else:
		MessageBus.log_message("%s에 대한 공격이 빗나갔다." % target.display_name)

func _check_pickup(pos: Vector2i) -> void:
	var item: ItemData = DungeonState.take_item_at(pos)
	if item:
		GameState.add_item(item)
		MessageBus.log_message("%s 주웠다." % Josa.eul_reul(item.get_display_name(GameState.is_identified(item.id))))
	var gold: int = DungeonState.take_gold_at(pos)
	if gold > 0:
		GameState.add_gold(gold)
		MessageBus.log_message("저승길 동전 %d개를 주웠다." % gold)

func _check_trap(pos: Vector2i) -> void:
	if DungeonState.tile_at(pos) != DungeonState.Tile.TRAP:
		return
	DungeonState.set_tile(pos, DungeonState.Tile.TRAP_SPENT)
	if randf() < TELEPORT_TRAP_CHANCE:
		var dest: Vector2i = DungeonState.random_free_floor_tile()
		if dest.x >= 0:
			MessageBus.log_message("함정이다! 발밑이 꺼지며 다른 곳으로 끌려갔다.")
			DungeonState.move_actor(self, grid_pos, dest)
			return
	var dmg: int = TRAP_BASE_DAMAGE + GameState.current_floor
	MessageBus.log_message("함정이다! 가시에 찔려 %d의 피해를 입었다." % dmg)
	take_damage(dmg)
