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

var stats: ActorStats
var current_hp: int = 1
var grid_pos: Vector2i = Vector2i.ZERO
var is_alive: bool = true
var display_name: String = ""

var visual: ColorRect
var label: Label
var hp_bar: ColorRect

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

	hp_bar = ColorRect.new()
	hp_bar.color = Color(0.2, 0.9, 0.3)
	hp_bar.position = Vector2(3, 0)
	hp_bar.size = Vector2(ts - 6, HP_BAR_HEIGHT)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar)

func setup(p_stats: ActorStats, p_color: Color, p_glyph: String, p_display_name: String) -> void:
	stats = p_stats
	current_hp = stats.max_hp
	display_name = p_display_name
	visual.color = p_color
	label.text = p_glyph
	_update_hp_bar()

func move_to_grid(pos: Vector2i) -> void:
	grid_pos = pos
	position = Vector2(pos.x * Constants.TILE_SIZE, pos.y * Constants.TILE_SIZE)

func take_damage(amount: int) -> void:
	if not is_alive:
		return
	current_hp = max(0, current_hp - amount)
	_update_hp_bar()
	hp_changed.emit(current_hp, stats.max_hp)
	if current_hp <= 0:
		die()

func heal(amount: int) -> void:
	if not is_alive:
		return
	current_hp = min(stats.max_hp, current_hp + amount)
	_update_hp_bar()
	hp_changed.emit(current_hp, stats.max_hp)

func die() -> void:
	is_alive = false
	died.emit(self)
	queue_free()

func _update_hp_bar() -> void:
	var ratio: float = float(current_hp) / float(maxi(1, stats.max_hp))
	hp_bar.size.x = (Constants.TILE_SIZE - 6) * clampf(ratio, 0.0, 1.0)
