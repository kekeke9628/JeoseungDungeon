class_name DPad
extends Control
## On-screen directional pad for touch play. Emits direction/wait intents;
## Game.gd decides what they mean.

signal direction_pressed(dir: Vector2i)
signal wait_pressed

const BTN_SIZE: float = 90.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, 1280)
	_add_button("↑", Vector2(140, 1000), func(): direction_pressed.emit(Vector2i(0, -1)))
	_add_button("←", Vector2(40, 1090), func(): direction_pressed.emit(Vector2i(-1, 0)))
	_add_button("대기", Vector2(140, 1090), func(): wait_pressed.emit())
	_add_button("→", Vector2(240, 1090), func(): direction_pressed.emit(Vector2i(1, 0)))
	_add_button("↓", Vector2(140, 1180), func(): direction_pressed.emit(Vector2i(0, 1)))

func _add_button(text: String, pos: Vector2, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(BTN_SIZE, BTN_SIZE)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(callback)
	add_child(b)
