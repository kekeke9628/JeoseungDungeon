class_name HUD
extends Control
## Top status bar: floor, a health bar, level and experience bar, coins, a
## hunger meter, timed conditions (poison, stun), and the settings and bag
## buttons.
## Built in code; fixed layout for the 720x1280 portrait viewport.

signal inventory_pressed
signal settings_pressed

const HEIGHT: float = 100.0
const HP_COLOR := Color(0.82, 0.2, 0.22)
const XP_COLOR := Color(0.92, 0.72, 0.28)
## Status marks, most urgent first: the label takes the colour of the worst.
const STATUS_COLORS: Array = [
	["독", Color(0.5, 0.95, 0.45)],
	["기절", Color(1.0, 0.9, 0.4)],
]
## Hunger meter colour per stage (Player.hunger_stage).
const HUNGER_COLORS := {
	"든든함": Color(0.45, 0.8, 0.35),
	"보통": Color(0.88, 0.72, 0.28),
	"배고픔": Color(1.0, 0.5, 0.18),
	"굶주림": Color(0.9, 0.18, 0.18),
}

## A framed bar filled from the left, shaded top to bottom in 2px rows so it
## matches the pixel art.
class Bar:
	extends Control

	var ratio: float = 1.0
	var color: Color = Color.RED
	var frame_box: StyleBox

	func _draw() -> void:
		if frame_box != null:
			draw_style_box(frame_box, Rect2(Vector2.ZERO, size))
		var inner := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var w: float = floorf(inner.size.x * clampf(ratio, 0.0, 1.0) / 2.0) * 2.0
		var y: float = 0.0
		while y < inner.size.y:
			var c: Color = color
			if y < 2.0:
				c = color.lightened(0.4)
			elif y >= inner.size.y - 4.0:
				c = color.darkened(0.35)
			draw_rect(Rect2(inner.position + Vector2(0, y), Vector2(w, 2)), c)
			y += 2.0

var _floor_label: Label
var _level_label: Label
var _gold_label: Label
var _status_label: Label
var _hp_text: Label
var _hp_bar: Bar
var _xp_bar: Bar
var _hunger_bar: Bar
var _hunger_text: Label

var _floor: int = 1
var _hp: int = 0
var _max_hp: int = 0
var _level: int = 1
var _xp: int = 0
var _xp_next: int = 20
var _gold: int = 0
var _status: String = ""
var _hunger: int = 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, HEIGHT)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UITheme.panel_box())
	bg.position = Vector2(-14, -14)  # top corners tucked off screen
	bg.size = Vector2(748, HEIGHT + 14)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_floor_label = _label(Vector2(18, 8), Vector2(220, 36), 24, UITheme.GOLD)
	_level_label = _label(Vector2(236, 8), Vector2(90, 36), 22, UITheme.TEXT)
	var coin := TextureRect.new()
	coin.texture = SpriteLibrary.get_item("gold")
	coin.position = Vector2(326, 12)
	coin.size = Vector2(28, 28)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin)
	_gold_label = _label(Vector2(358, 8), Vector2(110, 36), 22, UITheme.TEXT)

	var frame: StyleBox = UITheme.skin("bar_frame", UITheme.BAR_MARGIN, null)
	_hp_bar = _bar(Vector2(18, 50), Vector2(300, 30), HP_COLOR, frame)
	_hp_text = _label(Vector2(18, 50), Vector2(300, 30), 20, UITheme.TEXT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hp_text.add_theme_constant_override("outline_size", 5)
	_xp_bar = _bar(Vector2(18, 82), Vector2(300, 12), XP_COLOR, frame)
	var bowl := TextureRect.new()
	bowl.texture = SpriteLibrary.get_item("sajatbap")
	bowl.position = Vector2(330, 49)
	bowl.size = Vector2(32, 32)
	bowl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bowl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bowl)
	_hunger_bar = _bar(Vector2(366, 50), Vector2(180, 30), HUNGER_COLORS["든든함"], frame)
	_hunger_text = _label(Vector2(366, 50), Vector2(180, 30), 18, UITheme.TEXT)
	_hunger_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hunger_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hunger_text.add_theme_constant_override("outline_size", 5)
	_status_label = _label(Vector2(430, 8), Vector2(130, 36), 22, UITheme.TEXT)

	_icon_button("settings", Vector2(566, 12), func(): settings_pressed.emit())
	_icon_button("bag", Vector2(642, 12), func(): inventory_pressed.emit())

func _label(pos: Vector2, lbl_size: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = lbl_size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _bar(pos: Vector2, bar_size: Vector2, color: Color, frame: StyleBox) -> Bar:
	var b := Bar.new()
	b.position = pos
	b.size = bar_size
	b.color = color
	b.frame_box = frame
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	return b

func _icon_button(icon_name: String, pos: Vector2, callback: Callable) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(68, 68)
	btn.icon = UITheme.icon(icon_name)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.pressed.connect(callback)
	add_child(btn)
	return btn

func set_floor(v: int) -> void:
	_floor = v
	_refresh()

func set_hp(current: int, max_hp: int) -> void:
	_hp = current
	_max_hp = max_hp
	_refresh()

func set_level(level: int, xp: int, xp_next: int) -> void:
	_level = level
	_xp = xp
	_xp_next = xp_next
	_refresh()

func set_gold(v: int) -> void:
	_gold = v
	_refresh()

func set_status(text: String) -> void:
	_status = text
	_refresh()

## Hunger in turns (GameState.hunger): shown as fullness with its stage name.
func set_hunger(hunger: int) -> void:
	_hunger = hunger
	_refresh()

## Everything the bar says, as one string (for tests and debugging).
func summary() -> String:
	var parts: Array[String] = [_floor_label.text, _level_label.text, _gold_label.text]
	parts.append_array([_hp_text.text, _hunger_text.text, _status_label.text])
	return " ".join(parts)

func _refresh() -> void:
	_floor_label.text = "%s %d층" % [FloorTheme.band_name(_floor), _floor]
	_level_label.text = "Lv %d" % _level
	_gold_label.text = str(_gold)
	_hp_text.text = "%d / %d" % [_hp, _max_hp]
	_hp_bar.ratio = float(_hp) / float(maxi(1, _max_hp))
	_xp_bar.ratio = float(_xp) / float(maxi(1, _xp_next))
	var stage: String = Player.hunger_stage(_hunger)
	var full: float = Player.fullness(_hunger)
	_hunger_bar.ratio = full
	_hunger_bar.color = HUNGER_COLORS[stage]
	_hunger_text.text = "%s %d%%" % [stage, roundi(full * 100.0)]
	# starving empties the bar, so the words themselves turn red
	var text_color: Color = Color(1.0, 0.4, 0.35) if stage == "굶주림" else UITheme.TEXT
	_hunger_text.add_theme_color_override("font_color", text_color)
	_hp_bar.queue_redraw()
	_xp_bar.queue_redraw()
	_hunger_bar.queue_redraw()
	_status_label.text = _status
	var color: Color = UITheme.TEXT
	for entry in STATUS_COLORS:
		if _status.contains(entry[0]):
			color = entry[1]
			break
	_status_label.add_theme_color_override("font_color", color)
