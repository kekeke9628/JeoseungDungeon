class_name Fx
## Visual effects for things that happen in play: hits, deaths, healing,
## pickups, level-ups, skills and traps, plus the hit feel (freeze frames,
## camera shake). Every function only adds short-lived nodes or nudges the
## picture; none of them changes the game or uses its RNG. Effects for an
## actor the player cannot see are skipped.

## Above the light overlay (5), so effects glow in the dark; below damage numbers (10).
const Z: int = 8
const SOUL := Color(0.72, 0.86, 1.0)
const GOLD := Color(1.0, 0.86, 0.35)
const HEAL := Color(0.55, 1.0, 0.6)
const TELEPORT := Color(0.5, 0.7, 1.0)
const DUST := Color(0.75, 0.7, 0.65)
const FLAME := Color(1.0, 0.55, 0.2)
## The shaman's five colours, for salpuri.
const OBANG: Array[Color] = [Color(0.85, 0.2, 0.2), Color(0.95, 0.8, 0.25), Color(0.25, 0.45, 0.9)]
## Freeze frames: the picture slows almost to a stop for this long when a blow
## lands (longer for a heavy one), which is most of what makes a hit feel solid.
const HIT_STOP: float = 0.05
const HIT_STOP_HEAVY: float = 0.1
const HIT_STOP_SCALE: float = 0.05
## Camera shake strengths, in screen px.
const SHAKE_LIGHT: float = 5.0
const SHAKE_HEAVY: float = 11.0
const SHAKE_TIME: float = 0.22

## Where each worn slot sits on a hero's 24px body (tools/gear24.py), in art px.
const GEAR_SPOTS := {
	"head": Vector2(12, 3), "weapon": Vector2(20, 12), "armor": Vector2(12, 13),
	"amulet": Vector2(14.5, 17.5), "ring": Vector2(7, 18), "boots": Vector2(12, 21.5),
}

## Colour of each timed effect, for its burst when it starts.
const BUFF_COLORS := {
	"regen": Color(1.0, 0.45, 0.55), "haste": Color(0.5, 0.9, 1.0), "sight": Color(0.75, 0.5, 1.0),
	"invisible": Color(0.8, 0.8, 0.9), "levitate": Color(0.9, 0.95, 1.0),
}

## Off in headless test runs, where frames only pass when a test waits and a
## slowed clock would only slow the tests.
static var hit_stop_enabled: bool = true
## Set by Game: the camera to shake and its resting offset.
static var camera: Camera2D
static var camera_rest := Vector2.ZERO
static var _stop_until_ms: int = 0
static var _stop_token: int = 0
static var _shake_tween: Tween
static var _rng := RandomNumberGenerator.new()

static func _center(actor: Node2D) -> Vector2:
	var ts: float = Constants.TILE_SIZE
	return actor.position + Vector2(ts * 0.5, ts * 0.5)

static func _shown(actor) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return false
	return actor.visible and actor.get_parent() != null

static func _add(parent: Node, node: Node2D, at: Vector2) -> void:
	node.position = at
	node.z_index = Z
	parent.add_child(node)

static func burst(parent: Node, at: Vector2, color: Color, count: int, speed: float,
		gravity: float, life: float, size: int = 1) -> PixelBurst:
	var b := PixelBurst.new()
	b.color = color
	b.count = count
	b.speed = speed
	b.gravity = gravity
	b.life = life
	b.size = size
	_add(parent, b, at)
	return b

static func shape(parent: Node, at: Vector2, kind: FxShape.Kind, color: Color, time: float,
		radius: float = 40.0, width: float = 4.0) -> FxShape:
	var s := FxShape.new()
	s.kind = kind
	s.color = color
	s.time = time
	s.radius = radius
	s.width = width
	_add(parent, s, at)
	return s

## A spray in the actor's own colour (blood, soul-stuff, sparks) when it is hurt.
static func hit(actor, heavy: bool = false) -> void:
	if not _shown(actor):
		return
	var count: int = 18 if heavy else 10
	var speed: float = 190.0 if heavy else 150.0
	burst(actor.get_parent(), _center(actor), actor.hit_color(), count, speed, 320.0, 0.45, 1)

## A white star where a blow lands, on the side facing the attacker.
static func impact(target, from_tile: Vector2i) -> void:
	if not _shown(target):
		return
	var toward := Vector2(from_tile - target.grid_pos).normalized()
	var at: Vector2 = _center(target) + toward * Constants.TILE_SIZE * 0.3
	shape(target.get_parent(), at, FxShape.Kind.SPARK, Color(1.0, 0.98, 0.85), 0.12, 20.0, 3.0)

## Freezes the picture for a moment. Only the clock of animations slows; the
## game has already moved on, so nothing waits for this. Overlapping freezes
## merge: only the one that ends last turns the clock back on.
static func hit_stop(from: Node, seconds: float) -> void:
	if not hit_stop_enabled or from == null or not from.is_inside_tree():
		return
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _stop_until_ms:
		return  # a freeze that lasts longer is already on
	_stop_until_ms = until
	_stop_token += 1
	var token: int = _stop_token
	Engine.time_scale = HIT_STOP_SCALE
	var timer := from.get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(func(): _end_hit_stop(token))

static func _end_hit_stop(token: int) -> void:
	if token == _stop_token:
		Engine.time_scale = 1.0
		_stop_until_ms = 0

## Shakes the camera; a stronger shake replaces a weaker one in progress.
static func shake(strength: float) -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = camera.create_tween()
	var steps: int = 4
	for i in range(steps):
		var k: float = strength * (1.0 - float(i) / steps)
		var jolt := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * k
		_shake_tween.tween_property(camera, "offset", camera_rest + jolt, SHAKE_TIME / (steps + 1))
	_shake_tween.tween_property(camera, "offset", camera_rest, SHAKE_TIME / (steps + 1))

## Wisps rising from something that has just died.
static func soul(actor) -> void:
	if not _shown(actor):
		return
	var at: Vector2 = _center(actor)
	var b := burst(actor.get_parent(), at, SOUL, 14, 50.0, -90.0, 1.0, 2)
	b.spread = PI * 0.8
	b.scatter = 10.0
	burst(actor.get_parent(), at, actor.hit_color(), 12, 170.0, 300.0, 0.5, 1)

## Green-gold motes rising when an actor is healed by more than a trickle.
static func heal(actor) -> void:
	if not _shown(actor):
		return
	var b := burst(actor.get_parent(), _center(actor) + Vector2(0, 10), HEAL, 12, 40.0, -120.0, 0.8, 1)
	b.spread = PI * 0.5
	b.scatter = 14.0
	b.end_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.0)

## A glint on a tile where something was picked up.
static func sparkle(parent: Node, tile: Vector2i, color: Color = GOLD) -> void:
	var ts: float = Constants.TILE_SIZE
	var at := Vector2(tile.x * ts + ts * 0.5, tile.y * ts + ts * 0.5)
	var b := burst(parent, at, color, 8, 70.0, -60.0, 0.5, 1)
	b.scatter = 8.0

static func level_up(actor) -> void:
	if not _shown(actor):
		return
	var at: Vector2 = _center(actor)
	shape(actor.get_parent(), at + Vector2(0, 20), FxShape.Kind.PILLAR, GOLD, 0.8, 18.0)
	shape(actor.get_parent(), at, FxShape.Kind.RING, GOLD, 0.6, 56.0, 4.0)
	var b := burst(actor.get_parent(), at + Vector2(0, 14), GOLD, 20, 60.0, -160.0, 1.0, 1)
	b.spread = PI * 0.4
	b.scatter = 16.0

## A glint on the body part something was just put on.
static func equip(actor, slot: String) -> void:
	if not _shown(actor) or not GEAR_SPOTS.has(slot):
		return
	var spot: Vector2 = GEAR_SPOTS[slot]
	if actor.sprite.flip_h:
		spot.x = 24.0 - spot.x
	var at: Vector2 = actor.position + spot * (Constants.TILE_SIZE / 24.0)
	shape(actor.get_parent(), at, FxShape.Kind.RING, GOLD, 0.35, 18.0, 2.0)
	var b := burst(actor.get_parent(), at, GOLD, 10, 60.0, -40.0, 0.5, 1)
	b.scatter = 4.0

## A ring and rising motes in the effect's colour when a timed effect starts.
static func buff(actor, status: String) -> void:
	if not _shown(actor):
		return
	var c: Color = BUFF_COLORS.get(status, GOLD)
	var at: Vector2 = _center(actor)
	shape(actor.get_parent(), at, FxShape.Kind.RING, c, 0.5, 44.0, 3.0)
	var b := burst(actor.get_parent(), at + Vector2(0, 12), c, 16, 50.0, -130.0, 0.9, 1)
	b.spread = PI * 0.5
	b.scatter = 14.0

## Salpuri: rings in the shaman's colours and petals thrown up.
static func salpuri(actor) -> void:
	if not _shown(actor):
		return
	var at: Vector2 = _center(actor)
	for i in range(OBANG.size()):
		shape(actor.get_parent(), at, FxShape.Kind.RING, OBANG[i], 0.5 + i * 0.15, 40.0 + i * 16.0, 3.0)
	for c in OBANG:
		var b := burst(actor.get_parent(), at, c, 6, 110.0, 90.0, 0.9, 1)
		b.spread = PI

## Ilseom: a bright crescent across the target.
static func slash(target) -> void:
	if not _shown(target):
		return
	var steel := Color(0.85, 0.95, 1.0)
	shape(target.get_parent(), _center(target), FxShape.Kind.SLASH, steel, 0.28, 26.0, 5.0)

## Noejeon: a bolt from the sky onto the target.
static func lightning(target) -> void:
	if not _shown(target):
		return
	var at: Vector2 = _center(target)
	shape(target.get_parent(), at, FxShape.Kind.BOLT, Color(0.6, 0.8, 1.0), 0.3, 0.0, 3.0)
	burst(target.get_parent(), at, Color(0.8, 0.9, 1.0), 12, 200.0, 200.0, 0.35, 1)

## A burning talisman striking its target.
static func flame(target) -> void:
	if not _shown(target):
		return
	var b := burst(target.get_parent(), _center(target), FLAME, 16, 90.0, -140.0, 0.6, 2)
	b.end_color = Color(0.4, 0.1, 0.05, 0.0)

## Swirl of blue where someone vanishes or lands.
static func teleport(parent: Node, tile: Vector2i) -> void:
	var ts: float = Constants.TILE_SIZE
	var at := Vector2(tile.x * ts + ts * 0.5, tile.y * ts + ts * 0.5)
	shape(parent, at, FxShape.Kind.RING, TELEPORT, 0.45, 34.0, 3.0)
	var b := burst(parent, at, TELEPORT, 14, 60.0, -120.0, 0.7, 1)
	b.scatter = 12.0

## Dust kicked up by a spike trap.
static func dust(parent: Node, tile: Vector2i) -> void:
	var ts: float = Constants.TILE_SIZE
	var at := Vector2(tile.x * ts + ts * 0.5, tile.y * ts + ts * 0.8)
	var b := burst(parent, at, DUST, 10, 60.0, -30.0, 0.6, 2)
	b.spread = PI
	b.scatter = 12.0

## A full-screen flash under the HUD (lightning, a critical slash).
static func screen_flash(from: Node, color: Color, time: float = 0.25) -> void:
	if from == null or not from.is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.color = color
	rect.size = Vector2(720, 1280)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	from.get_tree().current_scene.add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, time)
	tw.tween_callback(layer.queue_free)
