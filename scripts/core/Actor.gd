class_name Actor
extends Node2D
## Base class for anything that occupies a dungeon tile and fights: Player and
## Monster both extend this. Holds runtime combat state; per-species data
## lives in the ActorStats/MonsterData resources instead.
## The visual (colored square + glyph + HP bar) is built in code so no scene
## file is required; replace with a Sprite2D once art exists.

signal died(actor)
signal hp_changed(current: int, max_hp: int)

const HP_BAR_HEIGHT: int = 5
const POPUP_RISE: float = 36.0
const POPUP_TIME: float = 0.7
const FLASH_TIME: float = 0.18
const COLOR_DAMAGE_PLAYER := Color(1.0, 0.35, 0.3)
const COLOR_DAMAGE_MONSTER := Color(1.0, 0.95, 0.6)
const COLOR_HEAL := Color(0.4, 1.0, 0.5)
## Motion. All of it is look only: the game state moves at once and these just
## catch the picture up, so a turn never waits for an animation.
const MOVE_TIME: float = 0.1
const HOP_HEIGHT: float = 5.0
const LUNGE_REACH: float = 0.45  # fraction of a tile
const LUNGE_TIME: float = 0.05
## The little pull back before a lunge, so the strike reads as wound up.
const WINDUP_PX: float = 4.0
const WINDUP_TIME: float = 0.04
const SHAKE_PX: float = 4.0
## How far a blow shoves the one it lands on, and how fast it slides back.
const KNOCKBACK_PX: float = 9.0
const KNOCKBACK_BACK_TIME: float = 0.14
## A side step on a miss.
const DODGE_PX: float = 8.0
const COLOR_MISS := Color(0.75, 0.75, 0.8)
const COLOR_HEAVY := Color(1.0, 0.7, 0.25)
## A blow of at least this share of max HP (or a kill) is heavy: bigger number,
## longer freeze, a camera shake and the heavy thud.
const HEAVY_SHARE: float = 0.3
const HIT_FLASH_SHADER: Shader = preload("res://assets/shaders/hit_flash.gdshader")
## Marks "no attacker": damage from poison, hunger or a trap is not a blow.
const NO_HIT := Vector2i(-9999, -9999)
const DEATH_TIME: float = 0.4
## Idle animation: seconds per frame (each actor a little different).
const IDLE_FRAME_TIME: float = 0.5
const SHADOW_COLOR := Color(0, 0, 0, 0.32)
## Heals smaller than this (natural regeneration) get no sparkle.
const HEAL_FX_MIN: int = 5
const BLOOD := Color(0.72, 0.1, 0.14)

## Alternates damage numbers left and right so quick hits do not stack.
static var _popup_side: int = 0

var stats: ActorStats
var current_hp: int = 1
var grid_pos: Vector2i = Vector2i.ZERO
var is_alive: bool = true
var display_name: String = ""

## Holds the drawn parts. Lunges and shakes offset this, never the actor's own
## position, which always sits on its tile.
var body: Node2D
var visual: ColorRect
var label: Label
var hp_bar: ColorRect
var sprite: TextureRect
var shadow: Node2D
## Where the blow about to land comes from (set_hit_from), or NO_HIT.
var _hit_from: Vector2i = NO_HIT
var _flash_tween: Tween
var _frames: Array[Texture2D] = []
var _frame_index: int = 0
## Worn-gear layers over the sprite: [{"rect": TextureRect, "frames": Array}].
var _layers: Array = []
var _move_tween: Tween
var _body_tween: Tween

## An oval on the floor under the actor. It stays put when the body hops or
## lunges, which is what makes those read as leaving the ground.
class GroundShadow:
	extends Node2D

	func _draw() -> void:
		var ts: float = Constants.TILE_SIZE
		draw_set_transform(Vector2(ts * 0.5, ts * 0.9), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, ts * 0.3, SHADOW_COLOR)

func _init() -> void:
	var ts: int = Constants.TILE_SIZE
	shadow = GroundShadow.new()
	shadow.visible = false
	add_child(shadow)
	body = Node2D.new()
	var flash_mat := ShaderMaterial.new()
	flash_mat.shader = HIT_FLASH_SHADER
	body.material = flash_mat
	add_child(body)
	visual = ColorRect.new()
	visual.position = Vector2(3, 3)
	visual.size = Vector2(ts - 6, ts - 6)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(visual)

	label = Label.new()
	label.size = visual.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(label)

	sprite = TextureRect.new()
	sprite.size = Vector2(ts, ts)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.visible = false
	sprite.use_parent_material = true  # flashes with the body's hit shader
	body.add_child(sprite)

	hp_bar = ColorRect.new()
	hp_bar.color = Color(0.2, 0.9, 0.3)
	hp_bar.position = Vector2(3, 0)
	hp_bar.size = Vector2(ts - 6, HP_BAR_HEIGHT)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar)

func setup(p_stats: ActorStats, p_color: Color, p_glyph: String, p_display_name: String, p_sprite_id: String = "") -> void:
	stats = p_stats
	current_hp = stats.max_hp
	display_name = p_display_name
	visual.color = p_color
	label.text = p_glyph
	_frames = SpriteLibrary.get_actor_frames(p_sprite_id)
	if not _frames.is_empty():
		sprite.texture = _frames[0]
		sprite.visible = true
		visual.color = Color(0, 0, 0, 0)
		label.text = ""
		shadow.visible = true
		_start_idle()
	_update_hp_bar()

## Places the actor on a tile. With animate, a one-tile step slides and hops
## there; anything else (spawning, a floor change, a teleport) snaps.
func move_to_grid(pos: Vector2i, animate: bool = false) -> void:
	var step: bool = absi(pos.x - grid_pos.x) + absi(pos.y - grid_pos.y) == 1
	if step:
		_face(pos.x - grid_pos.x)
	grid_pos = pos
	var target := Vector2(pos.x * Constants.TILE_SIZE, pos.y * Constants.TILE_SIZE)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if not (animate and step and is_inside_tree() and visible):
		position = target
		return
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, MOVE_TIME)
	var hop := create_tween()
	hop.tween_property(body, "position:y", -HOP_HEIGHT, MOVE_TIME * 0.5).set_ease(Tween.EASE_OUT)
	hop.tween_property(body, "position:y", 0.0, MOVE_TIME * 0.5).set_ease(Tween.EASE_IN)

## Leans toward target_pos and back, so an attack reads as a strike.
func play_attack(target_pos: Vector2i) -> void:
	if not is_inside_tree() or not visible:
		return
	_face(target_pos.x - grid_pos.x)
	var toward := Vector2(target_pos - grid_pos).normalized()
	var reach := toward * Constants.TILE_SIZE * LUNGE_REACH
	_restart_body_tween()
	_body_tween.tween_property(body, "position", -toward * WINDUP_PX, WINDUP_TIME)
	_body_tween.tween_property(body, "position", reach, LUNGE_TIME).set_ease(Tween.EASE_OUT)
	var back_time: float = LUNGE_TIME * 1.6
	_body_tween.tween_property(body, "position", Vector2.ZERO, back_time).set_ease(Tween.EASE_IN)

## Says where the next blow comes from, so it can knock this actor back and
## count as a real hit (freeze frame, spark). Call just before take_damage.
func set_hit_from(pos: Vector2i) -> void:
	_hit_from = pos

## A blow knocks the body back away from the attacker; anything else (poison,
## hunger) is a side-to-side jolt. Ends back at rest either way.
func _shake() -> void:
	if not is_inside_tree() or not visible:
		return
	_restart_body_tween()
	if _hit_from != NO_HIT and _hit_from != grid_pos:
		var away := Vector2(grid_pos - _hit_from).normalized() * KNOCKBACK_PX
		_body_tween.tween_property(body, "position", away, 0.03).set_ease(Tween.EASE_OUT)
		var back := _body_tween.tween_property(body, "position", Vector2.ZERO, KNOCKBACK_BACK_TIME)
		back.set_ease(Tween.EASE_IN)
		return
	for x in [SHAKE_PX, -SHAKE_PX, SHAKE_PX * 0.5, 0.0]:
		_body_tween.tween_property(body, "position", Vector2(x, 0), 0.04)

## A miss: side-step out of the way and float a grey "빗나감".
func dodge(from_pos: Vector2i) -> void:
	if not is_inside_tree() or not visible:
		return
	var toward := Vector2(grid_pos - from_pos).normalized()
	var side := Vector2(-toward.y, toward.x) * DODGE_PX
	_restart_body_tween()
	_body_tween.tween_property(body, "position", side, 0.05).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(body, "position", Vector2.ZERO, 0.12)
	_show_popup("빗나감", COLOR_MISS)

func _restart_body_tween() -> void:
	if _body_tween != null and _body_tween.is_valid():
		_body_tween.kill()
	_body_tween = create_tween()

## Characters are drawn facing right; one heading left is mirrored.
func _face(dx: int) -> void:
	if dx != 0:
		sprite.flip_h = dx < 0
		for layer in _layers:
			layer.rect.flip_h = sprite.flip_h

## Stacks layers (each an array of idle frames) over the sprite, bottom to top,
## replacing any there were. They animate, flip and flash with the body.
func set_layers(frame_sets: Array) -> void:
	for layer in _layers:
		layer.rect.queue_free()
	_layers.clear()
	for frames in frame_sets:
		if frames.is_empty():
			continue
		var rect := TextureRect.new()
		rect.size = sprite.size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.use_parent_material = true
		rect.flip_h = sprite.flip_h
		rect.texture = frames[_frame_index % frames.size()]
		body.add_child(rect)
		_layers.append({"rect": rect, "frames": frames})

func layer_count() -> int:
	return _layers.size()

func _show_frame(i: int) -> void:
	_frame_index = i
	sprite.texture = _frames[i]
	for layer in _layers:
		layer.rect.texture = layer.frames[i % layer.frames.size()]

## Idle animation: steps through the art's frames (breathing, or a ghost
## rising and sinking) forever. The pace comes from the instance id rather
## than the RNG so animation never shifts the game's dice.
func _start_idle() -> void:
	if _frames.size() < 2:
		return
	var step_time: float = IDLE_FRAME_TIME + float(get_instance_id() % 5) * 0.04
	var tw := sprite.create_tween().set_loops()
	for i in range(_frames.size()):
		tw.tween_callback(_show_frame.bind(i))
		tw.tween_interval(step_time)

## Leaves a fading, rising copy of the sprite behind, so a kill is seen even
## though the actor itself is freed straight away.
func _spawn_death_fx() -> void:
	if not is_inside_tree() or not visible or not sprite.visible or get_parent() == null:
		return
	var fx := TextureRect.new()
	fx.texture = sprite.texture
	fx.flip_h = sprite.flip_h
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_SCALE
	fx.size = sprite.size
	fx.pivot_offset = fx.size / 2.0
	fx.position = position + body.position + sprite.position
	fx.modulate = Color(1.0, 0.45, 0.45)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(fx)
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(fx, "position:y", fx.position.y - 18.0, DEATH_TIME)
	tw.tween_property(fx, "modulate:a", 0.0, DEATH_TIME)
	tw.tween_property(fx, "scale", Vector2(1.25, 0.6), DEATH_TIME)
	tw.chain().tween_callback(fx.queue_free)

func take_damage(amount: int) -> void:
	if not is_alive:
		return
	current_hp = max(0, current_hp - amount)
	var heavy: bool = current_hp <= 0 or float(amount) >= float(stats.max_hp) * HEAVY_SHARE
	var struck: bool = _hit_from != NO_HIT  # a blow, not poison, hunger or a trap
	_update_hp_bar()
	var number_color: Color = COLOR_DAMAGE_PLAYER if self is Player else COLOR_DAMAGE_MONSTER
	if heavy and not (self is Player):
		number_color = COLOR_HEAVY
	_show_popup(str(amount), number_color, heavy)
	_flash()
	_shake()
	Fx.hit(self, heavy)
	if struck:
		Fx.impact(self, _hit_from)
		Fx.hit_stop(self, Fx.HIT_STOP_HEAVY if heavy else Fx.HIT_STOP)
		if heavy and is_inside_tree() and visible:
			Fx.shake(Fx.SHAKE_HEAVY)
			AudioManager.play("hit_heavy")
	_hit_from = NO_HIT
	hp_changed.emit(current_hp, stats.max_hp)
	if current_hp <= 0:
		die()

func heal(amount: int) -> void:
	if not is_alive:
		return
	current_hp = min(stats.max_hp, current_hp + amount)
	_update_hp_bar()
	_show_popup("+%d" % amount, COLOR_HEAL)
	if amount >= HEAL_FX_MIN:
		Fx.heal(self)
	hp_changed.emit(current_hp, stats.max_hp)

## Raises or lowers max HP and moves current HP by the same amount (never below
## 1), so taking gear on and off can never be used to heal.
func change_max_hp(delta: int) -> void:
	stats.max_hp += delta
	current_hp = clampi(current_hp + delta, 1, stats.max_hp)
	_update_hp_bar()
	hp_changed.emit(current_hp, stats.max_hp)

func die() -> void:
	is_alive = false
	died.emit(self)
	queue_free()

func _update_hp_bar() -> void:
	var ratio: float = float(current_hp) / float(maxi(1, stats.max_hp))
	hp_bar.size.x = (Constants.TILE_SIZE - 6) * clampf(ratio, 0.0, 1.0)

## Floating combat number that pops in large and settles, then rises and
## fades. big: a heavy blow, drawn larger. Skipped for actors the player
## cannot see.
func _show_popup(text: String, color: Color, big: bool = false) -> void:
	if not is_inside_tree() or not visible:
		return
	var parent := get_parent()
	if parent == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34 if big else 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 8 if big else 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(Constants.TILE_SIZE * 2, 40)
	_popup_side = 1 - _popup_side
	var side: float = 8.0 if _popup_side == 0 else -8.0
	l.position = position + Vector2(-Constants.TILE_SIZE * 0.5 + side, -10)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(1.8, 1.8) if big else Vector2(1.4, 1.4)
	l.z_index = 10
	parent.add_child(l)
	var pop := l.create_tween()
	var settle := pop.tween_property(l, "scale", Vector2.ONE, 0.12)
	settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - POPUP_RISE, POPUP_TIME).set_delay(0.08)
	tw.tween_property(l, "modulate:a", 0.0, POPUP_TIME).set_delay(0.12)
	tw.chain().tween_callback(l.queue_free)

## White-out blink on the whole body (the player blinks red), through the
## body's hit shader, so status tints on the sprite are left alone.
func _flash() -> void:
	if not is_inside_tree() or not visible or not sprite.visible:
		return
	var mat := body.material as ShaderMaterial
	mat.set_shader_parameter("flash_color", Color(1.0, 0.35, 0.35) if self is Player else Color.WHITE)
	mat.set_shader_parameter("flash", 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v): mat.set_shader_parameter("flash", v), 1.0, 0.0, FLASH_TIME)

## What sprays out when this actor is hurt (Monster reads it from its data).
func hit_color() -> Color:
	return BLOOD

## Sprite color when not flashing; subclasses override (e.g. status tints).
func _rest_tint() -> Color:
	return Color.WHITE

## True only for the player-controlled actor (Player overrides), so shared
## systems can branch on it without depending on the Player class.
func is_player_actor() -> bool:
	return false

## Actors heavy enough to shrug off a floor trap (bosses; Monster overrides).
func ignores_traps() -> bool:
	return false
