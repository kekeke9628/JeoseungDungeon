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

var stats: ActorStats
var current_hp: int = 1
var grid_pos: Vector2i = Vector2i.ZERO
var is_alive: bool = true
var display_name: String = ""

var visual: ColorRect
var label: Label
var hp_bar: ColorRect
var sprite: TextureRect

func _init() -> void:
	var ts: int = Constants.TILE_SIZE
	visual = ColorRect.new()
	visual.position = Vector2(3, 3)
	visual.size = Vector2(ts - 6, ts - 6)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

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
	add_child(sprite)

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
	_update_hp_bar()

func move_to_grid(pos: Vector2i) -> void:
	grid_pos = pos
	position = Vector2(pos.x * Constants.TILE_SIZE, pos.y * Constants.TILE_SIZE)

func take_damage(amount: int) -> void:
	if not is_alive:
		return
	current_hp = max(0, current_hp - amount)
	_update_hp_bar()
	_show_popup(str(amount), COLOR_DAMAGE_PLAYER if self is Player else COLOR_DAMAGE_MONSTER)
	_flash()
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
	tw.tween_property(sprite, "modulate", Color.WHITE, FLASH_TIME)
