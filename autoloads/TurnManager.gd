extends Node
## Coordinates the strict alternating turn loop: the player acts once, then
## every registered monster gets one action. Autoloaded as "TurnManager".

signal turn_ended

## The player regains 1 HP every this many turns.
const REGEN_INTERVAL: int = 6

var monsters: Array = []  # Array[Monster]
var player  # Player, set by Player._ready()
var is_processing: bool = false

func register_player(p) -> void:
	player = p

func register_monster(m) -> void:
	if not monsters.has(m):
		monsters.append(m)

func unregister_monster(m) -> void:
	monsters.erase(m)

func end_player_turn() -> void:
	if is_processing:
		return
	is_processing = true
	GameState.turn_count += 1
	if player != null and player.is_alive and GameState.turn_count % REGEN_INTERVAL == 0:
		player.heal(1)
	# Snapshot so a monster dying mid-loop (removed via unregister_monster)
	# doesn't shift indices out from under the iteration.
	var snapshot: Array = monsters.duplicate()
	for m in snapshot:
		if is_instance_valid(m) and m.is_alive and player != null and player.is_alive:
			m.take_ai_turn()
	is_processing = false
	turn_ended.emit()
