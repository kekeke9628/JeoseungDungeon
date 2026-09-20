class_name Pathfinder
## Breadth-first pathfinding over the explored part of the current floor.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Returns the tile path from `from` to `to` inclusive, or [] if unreachable.
## Only explored, walkable tiles are used; tiles held by other actors block
## the route unless they are the destination (so tapping a monster walks up
## to it and attacks). Traps the player has spotted are routed around when
## there is any way around them.
static func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var safe: Array[Vector2i] = _search(from, to, true)
	if not safe.is_empty():
		return safe
	return _search(from, to, false)

static func _search(from: Vector2i, to: Vector2i, avoid_traps: bool) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if from == to or not DungeonState.is_walkable(to) or not DungeonState.explored.has(to):
		return none
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
			if prev.has(n) or not DungeonState.is_walkable(n) or not DungeonState.explored.has(n):
				continue
			if n != to and DungeonState.get_actor_at(n) != null:
				continue
			if avoid_traps and n != to and DungeonState.spotted_traps.has(n):
				continue
			prev[n] = cur
			queue.append(n)
	return none
