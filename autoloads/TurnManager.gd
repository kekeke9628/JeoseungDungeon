extends Node
## Coordinates the strict alternating turn loop: the player acts once, then
## every registered monster gets one action. Autoloaded as "TurnManager".
## Two conditions bend it, after Shattered Pixel Dungeon's haste and chill: a
## hasted player gets every other action for free (the world does not move),
## and a chilled one lets the world move twice.

signal turn_ended

## The player regains 1 HP every this many turns, unless starving.
const REGEN_INTERVAL: int = 5

var monsters: Array = []  # Array[Monster]
var player  # Player, set by Player._ready()
var is_processing: bool = false
## Haste: whether the free action of the current pair has been used.
var _haste_free_used: bool = false

func register_player(p) -> void:
	player = p

func register_monster(m) -> void:
	if not monsters.has(m):
		monsters.append(m)

func unregister_monster(m) -> void:
	monsters.erase(m)

## Every monster gets one action, then the ground it ends on does its work.
func _monsters_act() -> void:
	# Snapshot so a monster dying mid-loop (removed via unregister_monster)
	# doesn't shift indices out from under the iteration.
	var snapshot: Array = monsters.duplicate()
	for m in snapshot:
		if is_instance_valid(m) and m.is_alive and player != null and player.is_alive:
			m.take_ai_turn()
			if is_instance_valid(m) and m.is_alive:
				HazardSystem.affect(m)

func end_player_turn() -> void:
	if is_processing:
		return
	is_processing = true
	if player != null and player.is_alive and player.has_status("haste") and not _haste_free_used:
		_haste_free_used = true
		is_processing = false
		turn_ended.emit()
		return
	_haste_free_used = false
	GameState.turn_count += 1
	if player != null and player.is_alive:
		HazardSystem.affect(player)
	if player != null and player.is_alive:
		player.tick_statuses()
	if player != null and player.is_alive:
		player.tick_hunger()
	if GameState.skill_cooldown_left > 0:
		GameState.skill_cooldown_left -= 1
		GameState.skill_changed.emit()
	var can_regen: bool = player != null and player.is_alive and not player.is_starving()
	if can_regen and GameState.turn_count % REGEN_INTERVAL == 0:
		if player.current_hp < player.stats.max_hp:
			player.heal(1)
	var rounds: int = 2 if player != null and player.is_alive and player.has_status("chill") else 1
	for r in range(rounds):
		_monsters_act()
	is_processing = false
	turn_ended.emit()
