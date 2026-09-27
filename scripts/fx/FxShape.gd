class_name FxShape
extends Node2D
## A short drawn effect that plays once and frees itself: an expanding ring,
## a sword slash, a lightning bolt, or a column of light. Like PixelBurst it
## keeps its own random numbers away from the game's.

enum Kind { RING, SLASH, BOLT, PILLAR }

var kind: Kind = Kind.RING
var color: Color = Color.WHITE
var time: float = 0.35
## RING: final radius. SLASH: arc radius. PILLAR: half width.
var radius: float = 40.0
var width: float = 4.0
## BOLT: how far above the target the bolt starts.
var height: float = 420.0

var _t: float = 0.0
var _bolt: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	if kind == Kind.BOLT:
		var rng := RandomNumberGenerator.new()
		rng.seed = get_instance_id()
		var steps: int = 9
		for i in range(steps + 1):
			var k: float = float(i) / steps
			var jitter: float = 0.0 if i == 0 or i == steps else rng.randf_range(-14.0, 14.0)
			_bolt.append(Vector2(jitter, -height * (1.0 - k)))

func _process(delta: float) -> void:
	_t += delta
	if _t >= time:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k: float = clampf(_t / time, 0.0, 1.0)
	var c := Color(color.r, color.g, color.b, color.a * (1.0 - k))
	match kind:
		Kind.RING:
			var r: float = lerpf(radius * 0.2, radius, sqrt(k))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, width * (1.0 - k * 0.5))
		Kind.SLASH:
			# a bright crescent sweeping from upper left to lower right
			var sweep: float = lerpf(0.0, PI * 0.9, minf(1.0, k * 2.5))
			var start: float = -PI * 0.85
			draw_arc(Vector2.ZERO, radius, start, start + sweep, 16, c, width)
			var core := Color(1, 1, 1, c.a)
			draw_arc(Vector2.ZERO, radius - width, start + sweep * 0.3, start + sweep, 12, core, width * 0.5)
		Kind.BOLT:
			# flickers on and off while fading
			if int(_t * 30.0) % 3 != 2:
				draw_polyline(_bolt, Color(c.r, c.g, c.b, c.a * 0.5), width * 3.0)
				draw_polyline(_bolt, Color(1, 1, 1, c.a), width)
		Kind.PILLAR:
			var h: float = 180.0 * (0.4 + k)
			draw_rect(Rect2(-radius, -h, radius * 2.0, h), Color(c.r, c.g, c.b, c.a * 0.35))
			draw_rect(Rect2(-radius * 0.4, -h, radius * 0.8, h), Color(1, 1, 1, c.a * 0.3))
