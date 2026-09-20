class_name TrapSystem
## Hidden floor traps, resolved the same way for whoever walks into one.
## A trap springs once and leaves a spent marker behind. Monsters set them off
## too, so a trap you have spotted is a weapon: back away and let a chaser walk
## over it. Bosses are too heavy to fall in - they smash the trap and keep
## coming.
## The player only ever notices an armed trap by chance while standing next to
## it (spot_near), so traps still bite - but a spotted one can be walked around
## or used as bait. Waiting next to one keeps re-rolling, which makes standing
## still a crude search action.

const BASE_DAMAGE: int = 4
const TELEPORT_CHANCE: float = 0.4
## Chebyshev distance at which the player can make out the seams of an armed trap.
const SPOT_RADIUS: int = 1
## Per-turn chance of noticing one armed trap within SPOT_RADIUS.
const SPOT_CHANCE: float = 0.35

## Springs the trap under actor at pos, if there is one.
## Returns true if a trap went off.
static func trigger(actor: Actor, pos: Vector2i) -> bool:
	if DungeonState.tile_at(pos) != DungeonState.Tile.TRAP:
		return false
	var is_player: bool = actor.is_player_actor()
	var seen: bool = is_player or DungeonState.visible_tiles.has(pos)
	DungeonState.set_tile(pos, DungeonState.Tile.TRAP_SPENT)
	DungeonState.spotted_traps.erase(pos)
	if seen:
		AudioManager.play("trap")
	if actor.ignores_traps():
		if seen:
			MessageBus.log_message("%s 함정을 밟아 부숴 버렸다." % Josa.i_ga(actor.display_name))
		return true
	if randf() < TELEPORT_CHANCE:
		var dest: Vector2i = DungeonState.random_free_floor_tile()
		if dest.x >= 0:
			if is_player:
				MessageBus.log_message("함정이다! 발밑이 꺼지며 다른 곳으로 끌려갔다.")
			elif seen:
				MessageBus.log_message("%s 함정에 빠져 어디론가 사라졌다." % Josa.i_ga(actor.display_name))
			DungeonState.move_actor(actor, actor.grid_pos, dest)
			if not is_player:
				actor.visible = DungeonState.visible_tiles.has(dest)
			return true
	var dmg: int = BASE_DAMAGE + GameState.current_floor
	if is_player:
		MessageBus.log_message("함정이다! 가시에 찔려 %d의 피해를 입었다." % dmg)
		GameState.last_attacker = "함정"
	elif seen:
		MessageBus.log_message("%s 함정에 찔려 %d의 피해를 입었다." % [Josa.i_ga(actor.display_name), dmg])
	actor.take_damage(dmg)
	return true

## Rolls to notice armed traps next to origin. Returns the ones spotted just
## now, so the caller can warn the player once per trap.
static func spot_near(origin: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for dx in range(-SPOT_RADIUS, SPOT_RADIUS + 1):
		for dy in range(-SPOT_RADIUS, SPOT_RADIUS + 1):
			var pos := origin + Vector2i(dx, dy)
			if DungeonState.tile_at(pos) != DungeonState.Tile.TRAP or DungeonState.spotted_traps.has(pos):
				continue
			if randf() < SPOT_CHANCE:
				DungeonState.spotted_traps[pos] = true
				found.append(pos)
	if not found.is_empty():
		DungeonState.changed.emit()
	return found

## Reveals every armed trap on the floor (clairvoyance).
static func spot_all() -> void:
	for pos in DungeonState.grid.keys():
		if DungeonState.tile_at(pos) == DungeonState.Tile.TRAP:
			DungeonState.spotted_traps[pos] = true
	DungeonState.changed.emit()
