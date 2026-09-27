class_name HazardSystem
## Patches of bad ground laid over some rooms, after Shattered Pixel Dungeon's
## lingering gases, freezing and fire: a poison marsh poisons, ice chills
## (while chilled, the world gets two turns for each of the player's), fire
## burns. Unlike traps they are always in plain sight. Whoever stands in one at
## the end of a turn is affected - monsters too, so luring a chaser through a
## marsh works like baiting a trap. Bosses shrug them off, and a levitating
## player floats over them.

const POISON: String = "poison"
const ICE: String = "ice"
const FIRE: String = "fire"
const NAMES := {POISON: "독 늪", ICE: "얼음 바닥", FIRE: "불길"}
const POISON_TURNS: int = 3
const CHILL_TURNS: int = 2
const FIRE_BASE_DAMAGE: int = 2
## Monsters take this much a turn in a marsh.
const MONSTER_POISON_DAMAGE: int = 1
## Tiles in one zone.
const ZONE_MIN: int = 6
const ZONE_MAX: int = 13
## Which kinds each depth band gets, by weight.
const BAND_WEIGHTS: Array[Dictionary] = [
	{POISON: 7, ICE: 3},
	{ICE: 6, POISON: 4},
	{FIRE: 6, POISON: 4},
	{FIRE: 4, ICE: 3, POISON: 3},
]

## The kind the player was standing in last turn, to announce it once on entry.
static var _player_in: String = ""

## How many zones a floor gets: none on the first, then one, two from floor 10.
static func zones_for_floor(floor_num: int) -> int:
	if floor_num <= 1:
		return 0
	return 1 if floor_num < 10 else 2

## Lays this floor's zones on plain floor inside rooms that are neither the
## start room nor the stairs room. Part of level generation, so it uses the
## game's RNG like the rest of it.
static func generate(floor_num: int, rooms: Array[Rect2i], start_pos: Vector2i,
		stairs_pos: Vector2i) -> void:
	var candidates: Array[Rect2i] = []
	for room in rooms:
		if not room.has_point(start_pos) and not room.has_point(stairs_pos):
			candidates.append(room)
	for z in range(zones_for_floor(floor_num)):
		if candidates.is_empty():
			return
		var room: Rect2i = candidates.pop_at(randi() % candidates.size())
		var kind: String = _pick_kind(floor_num)
		var cx: int = randi_range(room.position.x, room.end.x - 1)
		var center := Vector2i(cx, randi_range(room.position.y, room.end.y - 1))
		_spread(center, room, kind, randi_range(ZONE_MIN, ZONE_MAX))

static func _pick_kind(floor_num: int) -> String:
	var weights: Dictionary = BAND_WEIGHTS[FloorTheme.band(floor_num)]
	var total: int = 0
	for k in weights:
		total += weights[k]
	var roll: int = randi() % total
	for k in weights:
		roll -= weights[k]
		if roll < 0:
			return k
	return POISON

## Grows a blob from center over plain floor inside room.
static func _spread(center: Vector2i, room: Rect2i, kind: String, size: int) -> void:
	var frontier: Array[Vector2i] = [center]
	var placed: int = 0
	while not frontier.is_empty() and placed < size:
		var pos: Vector2i = frontier.pop_at(randi() % frontier.size())
		if DungeonState.hazards.has(pos) or not room.has_point(pos):
			continue
		if DungeonState.tile_at(pos) != DungeonState.Tile.FLOOR:
			continue
		DungeonState.hazards[pos] = kind
		placed += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(pos + d)

static func at(pos: Vector2i) -> String:
	return DungeonState.hazards.get(pos, "")

## Forgets what the player stood in (a new floor, a reload).
static func reset() -> void:
	_player_in = ""

## The ground under actor does its work. Called for the player once per turn
## before the monsters move, and for each monster after it acts.
static func affect(actor) -> void:
	var kind: String = at(actor.grid_pos)
	var is_player: bool = actor.is_player_actor()
	if is_player:
		if kind != _player_in and kind != "":
			_announce(kind, actor)
		_player_in = kind
	if kind == "" or actor.ignores_traps():
		return
	if is_player and actor.has_status("levitate"):
		return
	match kind:
		POISON:
			if is_player:
				actor.apply_status("poison", POISON_TURNS)
			else:
				actor.take_damage(MONSTER_POISON_DAMAGE)
		ICE:
			if is_player:
				actor.apply_status("chill", CHILL_TURNS)
			else:
				actor.chill()
		FIRE:
			var dmg: int = FIRE_BASE_DAMAGE + GameState.current_floor / 6
			if is_player:
				GameState.last_attacker = "불길"
			actor.take_damage(dmg)

static func _announce(kind: String, player) -> void:
	if player.has_status("levitate"):
		MessageBus.log_message("%s 위를 둥실 떠서 지나간다." % NAMES[kind])
		return
	match kind:
		POISON:
			MessageBus.log_message("독기 서린 늪이다! 숨이 막히고 독이 오른다.")
		ICE:
			MessageBus.log_message("얼어붙은 바닥이다! 몸이 굳어 적이 두 번씩 움직인다.")
		FIRE:
			MessageBus.log_message("불길 속이다! 살갗이 탄다.")
