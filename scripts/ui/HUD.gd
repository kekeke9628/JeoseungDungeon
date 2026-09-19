class_name HUD
extends Control
## Top status bar: floor, HP, level/xp, gold, and the inventory button.
## Built in code; fixed layout for the 720x1280 portrait viewport.

signal inventory_pressed
signal settings_pressed

var _label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, 70)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_label = Label.new()
	_label.position = Vector2(16, 8)
	_label.size = Vector2(440, 54)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	add_child(_label)

	var btn := Button.new()
	btn.text = "가방"
	btn.position = Vector2(590, 10)
	btn.size = Vector2(116, 50)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): inventory_pressed.emit())
	add_child(btn)

	var gear := Button.new()
	gear.text = "설정"
	gear.position = Vector2(462, 10)
	gear.size = Vector2(116, 50)
	gear.add_theme_font_size_override("font_size", 24)
	gear.pressed.connect(func(): settings_pressed.emit())
	add_child(gear)

var _floor: int = 1
var _hp: int = 0
var _max_hp: int = 0
var _level: int = 1
var _xp: int = 0
var _xp_next: int = 20
var _gold: int = 0

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

func _refresh() -> void:
	_label.text = "저승 %d층  HP %d/%d\nLv %d (%d/%d)  엽전 %d" % [_floor, _hp, _max_hp, _level, _xp, _xp_next, _gold]
