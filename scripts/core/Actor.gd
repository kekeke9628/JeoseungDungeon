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
const LUNGE_REACH: float = 0.35  # fraction of a tile
const LUNGE_TIME: float = 0.07
const SHAKE_PX: float = 4.0
const BOB_PX: float = 3.0
const DEATH_TIME: float = 0.4

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
var _move_tween: Tween
var _body_tween: Tween

func _init() -> void:
	var ts: int = Constants.TILE_SIZE
	body = Node2D.new()
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
	var tex: Texture2D = SpriteLibrary.get_actor(p_sprite_id)
	if tex != null:
		sprite.texture = tex
		sprite.visible = true
		visual.color = Color(0, 0, 0, 0)
		label.text = ""
		_start_idle_bob()
	_update_hp_bar()

## Places the actor on a tile. With animate, a one-tile step slides and hops
## there; anything else (spawning, a floor change, a teleport) snaps.
func move_to_grid(pos: Vector2i, animate: bool = false) -> void:
	var step: bool = absi(pos.x - grid_pos.x) + absi(pos.y - grid_pos.y) == 1
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
	var toward := Vector2(target_pos - grid_pos).normalized()
	var reach := toward * Constants.TILE_SIZE * LUNGE_REACH
	_restart_body_tween()
	_body_tween.tween_property(body, "position", reach, LUNGE_TIME).set_ease(Tween.EASE_OUT)
	var back_time: float = LUNGE_TIME * 1.6
	_body_tween.tween_property(body, "position", Vector2.ZERO, back_time).set_ease(Tween.EASE_IN)

## A quick side-to-side jolt when hit. Ends back at rest even if it cut a lunge short.
func _shake() -> void:
	if not is_inside_tree() or not visible:
		return
	_restart_body_tween()
	for x in [SHAKE_PX, -SHAKE_PX, SHAKE_PX * 0.5, 0.0]:
		_body_tween.tween_property(body, "position", Vector2(x, 0), 0.04)

func _restart_body_tween() -> void:
	if _body_tween != null and _body_tween.is_valid():
		_body_tween.kill()
	_body_tween = create_tween()

## Breathing: the sprite drifts up and down forever. The phase comes from the
## instance id rather than the RNG so animation never shifts the game's dice.
func _start_idle_bob() -> void:
	var half: float = 0.55 + float(get_instance_id() % 5) * 0.05
	var tw := sprite.create_tween().set_loops()
	tw.tween_property(sprite, "position:y", -BOB_PX, half).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position:y", 0.0, half).set_trans(Tween.TRANS_SINE)

## Leaves a fading, rising copy of the sprite behind, so a kill is seen even
## though the actor itself is freed straight away.
func _spawn_death_fx() -> void:
	if not is_inside_tree() or not visible or not sprite.visible or get_parent() == null:
		return
	var fx := TextureRect.new()
	fx.texture = sprite.texture
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
	_update_hp_bar()
	_show_popup(str(amount), COLOR_DAMAGE_PLAYER if self is Player else COLOR_DAMAGE_MONSTER)
	_flash()
	_shake()
	hp_changed.emit(current_hp, stats.max_hp)
	if current_hp <= 0:
		die()

func heal(amount: int) -> void:
	if not is_alive:
		return
	current_hp = min(stats.max_hp, current_hp + amount)
	_update_hp_bar()
	_show_popup("+%d" % amount, COLOR_HEAL)
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

## Floating combat number. Skipped for actors the player cannot see.
func _show_popup(text: String, color: Color) -> void:
	if not is_inside_tree() or not visible:
		return
	var parent := get_parent()
	if parent == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = position + Vector2(Constants.TILE_SIZE * 0.25, -4)
	l.z_index = 10
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - POPUP_RISE, POPUP_TIME)
	tw.tween_property(l, "modulate:a", 0.0, POPUP_TIME)
	tw.chain().tween_callback(l.queue_free)

func _flash() -> void:
	if not is_inside_tree() or not visible or not sprite.visible:
		return
	sprite.modulate = Color(1.0, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", _rest_tint(), FLASH_TIME)

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
