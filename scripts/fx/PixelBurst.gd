class_name PixelBurst
extends Node2D
## A one-shot spray of square pixels (blood, sparks, soul wisps, sparkles)
## that frees itself when the last one fades. It has its own random numbers,
## seeded from the instance id, so effects never touch the game's dice (the
## built-in particle nodes share the global RNG with randi()/randf()).

## One art pixel on the map is 2 screen pixels; particles snap to that grid.
const PIXEL: float = 2.0

var color: Color = Color.WHITE
## Colour particles fade toward over their life. Left at its negative-alpha
## default, it is color faded out.
var end_color: Color = Color(0, 0, 0, -1)
var count: int = 10
var speed: float = 120.0
## Positive pulls down (blood, sparks), negative floats up (wisps).
var gravity: float = 260.0
var life: float = 0.45
## Particle size in art pixels (1 or 2).
var size: int = 1
## Spread: full circle by default; narrower sprays point up.
var spread: float = TAU
var angle: float = -PI / 2.0
## Start positions are scattered this far (screen px) around the origin.
var scatter: float = 4.0

var _parts: Array = []
var _started: bool = false
var _rng := RandomNumberGenerator.new()

## Particles are made on the first frame rather than in _ready, so settings
## changed right after the burst is added still apply.
func _spawn() -> void:
	_started = true
	_rng.seed = get_instance_id()
	if end_color.a < 0.0:
		end_color = Color(color.r, color.g, color.b, 0.0)
	for i in range(count):
		var a: float = angle + _rng.randf_range(-spread / 2.0, spread / 2.0)
		var v: float = speed * _rng.randf_range(0.4, 1.0)
		var start := Vector2(_rng.randf_range(-scatter, scatter), _rng.randf_range(-scatter, scatter))
		_parts.append({"p": start, "v": Vector2(cos(a), sin(a)) * v, "t": 0.0,
			"life": life * _rng.randf_range(0.6, 1.0), "s": size + (_rng.randi() % 2 if size > 1 else 0)})

func _process(delta: float) -> void:
	if not _started:
		_spawn()
	var alive: int = 0
	for part in _parts:
		part.t += delta
		if part.t >= part.life:
			continue
		alive += 1
		part.v.y += gravity * delta
		part.v *= 1.0 - 1.5 * delta
		part.p += part.v * delta
	if alive == 0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for part in _parts:
		if part.t >= part.life:
			continue
		var k: float = part.t / part.life
		var c: Color = color.lerp(end_color, k)
		var side: float = PIXEL * part.s
		var at: Vector2 = (part.p / PIXEL).floor() * PIXEL
		draw_rect(Rect2(at, Vector2(side, side)), c)
