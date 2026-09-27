extends Node2D
## Slow motes drifting around the player, different in each depth band: pale
## dust on the road of the dead, rising bubbles by the river, embers at the
## hell gate, gold dust in the palace. Drawn under the light overlay, so they
## show only where there is light. Own RNG, like every effect.

## Under LightOverlay (5), over actors (0).
const Z: int = 4
const COUNT: int = 28
## Motes live within this many tiles of the player.
const REACH := Vector2(8, 11)
const PIXEL: float = 2.0
## Per band: colour, drift velocity (px/s), wobble strength, size in art pixels.
const STYLES: Array[Dictionary] = [
	{"color": Color(0.82, 0.8, 0.9, 0.55), "drift": Vector2(6, -4), "wobble": 10.0, "size": 1},
	{"color": Color(0.6, 0.85, 1.0, 0.6), "drift": Vector2(0, -16), "wobble": 6.0, "size": 1},
	{"color": Color(1.0, 0.55, 0.2, 0.85), "drift": Vector2(3, -22), "wobble": 14.0, "size": 1},
	{"color": Color(1.0, 0.85, 0.4, 0.6), "drift": Vector2(-5, -5), "wobble": 8.0, "size": 1},
]

var _motes: Array = []
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0

func _ready() -> void:
	z_index = Z
	_rng.seed = get_instance_id()

func _process(delta: float) -> void:
	_time += delta
	var ts: float = Constants.TILE_SIZE
	var center := (Vector2(DungeonState.fov_origin) + Vector2(0.5, 0.5)) * ts
	var reach := REACH * ts
	var style: Dictionary = STYLES[FloorTheme.band(GameState.current_floor)]
	while _motes.size() < COUNT:
		_motes.append(_new_mote(center, reach, true))
	for i in range(_motes.size()):
		var m: Dictionary = _motes[i]
		m.t += delta
		m.p += style.drift * m.speed * delta
		var off: Vector2 = m.p - center
		if m.t >= m.life or absf(off.x) > reach.x or absf(off.y) > reach.y:
			_motes[i] = _new_mote(center, reach, false)
	queue_redraw()

func _new_mote(center: Vector2, reach: Vector2, anywhere: bool) -> Dictionary:
	var p := center + Vector2(_rng.randf_range(-reach.x, reach.x), _rng.randf_range(-reach.y, reach.y))
	var life: float = _rng.randf_range(4.0, 9.0)
	# the first batch starts part-way through life, so they do not all fade in together
	var t: float = _rng.randf_range(0.0, life * 0.8) if anywhere else 0.0
	var speed: float = _rng.randf_range(0.5, 1.4)
	return {"p": p, "t": t, "life": life, "speed": speed, "phase": _rng.randf() * TAU}

func _draw() -> void:
	var style: Dictionary = STYLES[FloorTheme.band(GameState.current_floor)]
	var base: Color = style.color
	for m in _motes:
		# fade in and out over the mote's life, and twinkle a little
		var k: float = m.t / m.life
		var a: float = base.a * sin(k * PI) * (0.75 + 0.25 * sin(_time * 5.0 + m.phase))
		var wob := Vector2(sin(_time * 1.3 + m.phase) * style.wobble, 0)
		var at: Vector2 = ((m.p + wob) / PIXEL).floor() * PIXEL
		var side: float = PIXEL * style.size
		draw_rect(Rect2(at, Vector2(side, side)), Color(base.r, base.g, base.b, a))
