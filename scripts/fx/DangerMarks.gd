class_name DangerMarks
extends Node2D
## Pulsing red squares on the tiles a boss's wound-up move is about to strike,
## so the player can see where not to stand. The boss adds it as its own child
## (tiles are offsets from the boss's tile) and frees it when the move lands.
## Like the other effects it never touches the game's RNG.

const COLOR := Color(1.0, 0.16, 0.1)
const PULSE_SPEED: float = 7.0
const INSET: float = 3.0

## Offsets from the owner's tile.
var tiles: Array[Vector2i] = []
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var ts: float = Constants.TILE_SIZE
	var a: float = 0.36 + 0.14 * sin(_t * PULSE_SPEED)
	var fill := Color(COLOR.r, COLOR.g, COLOR.b, a)
	var edge := Color(1.0, 0.45, 0.35, minf(1.0, a + 0.5))
	var inset := Vector2(INSET, INSET)
	for off in tiles:
		var r := Rect2(Vector2(off) * ts + inset, Vector2(ts, ts) - inset * 2.0)
		draw_rect(r, fill)
		draw_rect(r, edge, false, 3.0)
