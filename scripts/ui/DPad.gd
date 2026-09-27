class_name DPad
extends Control
## On-screen directional pad and skill button for touch play. Emits intents;
## Game.gd decides what they mean.

signal direction_pressed(dir: Vector2i)
signal wait_pressed
signal skill_pressed
signal attack_pressed
signal descend_pressed

const BTN_SIZE: float = 90.0
## Gold like the stairs tile, so the button reads as "take these stairs".
const DESCEND_TINT := Color(1.0, 0.85, 0.4)

var _skill_button: Button
var _descend_button: Button

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, 1280)
	_add_button("", Vector2(140, 1000), func(): direction_pressed.emit(Vector2i(0, -1)), "up")
	_add_button("", Vector2(40, 1090), func(): direction_pressed.emit(Vector2i(-1, 0)), "left")
	_add_button("", Vector2(140, 1090), func(): wait_pressed.emit(), "wait")
	_add_button("", Vector2(240, 1090), func(): direction_pressed.emit(Vector2i(1, 0)), "right")
	_add_button("", Vector2(140, 1180), func(): direction_pressed.emit(Vector2i(0, 1)), "down")
	var attack := _add_button("공격", Vector2(440, 998), func(): attack_pressed.emit(), "attack")
	attack.size = Vector2(240, 84)
	attack.add_theme_font_size_override("font_size", 28)
	_skill_button = _add_button("기술", Vector2(440, 1090), func(): skill_pressed.emit())
	_skill_button.size = Vector2(240, 90)
	_skill_button.add_theme_font_size_override("font_size", 26)
	# Shown only while the player stands on the stairs: going down is a choice,
	# not something that happens on the way past.
	var descend := func(): descend_pressed.emit()
	_descend_button = _add_button("내려가기", Vector2(440, 1188), descend, "descend")
	_descend_button.size = Vector2(240, 84)
	_descend_button.add_theme_font_size_override("font_size", 28)
	_descend_button.modulate = DESCEND_TINT
	_descend_button.visible = false

func set_descend_visible(on: bool) -> void:
	_descend_button.visible = on

func is_descend_visible() -> bool:
	return _descend_button.visible

## skill_id picks the button's icon (icon_<skill_id> in the UI art).
func set_skill(skill_name: String, cooldown_left: int, skill_id: String = "") -> void:
	if skill_id != "":
		_skill_button.icon = UITheme.icon(skill_id)
	if cooldown_left > 0:
		_skill_button.text = "%s (%d)" % [skill_name, cooldown_left]
		_skill_button.modulate = Color(0.6, 0.6, 0.6)
	else:
		_skill_button.text = skill_name
		_skill_button.modulate = Color.WHITE

func _add_button(text: String, pos: Vector2, callback: Callable, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = UITheme.icon(icon_name)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	b.position = pos
	b.size = Vector2(BTN_SIZE, BTN_SIZE)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(callback)
	add_child(b)
	return b
