class_name GameOverScreen
extends Control
## Full-screen result overlay with a restart button.

signal restart_pressed

var _title: Label
var _detail: Label

func _init() -> void:
	visible = false
	position = Vector2.ZERO
	size = Vector2(720, 1280)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.size = size
	add_child(bg)

	_title = Label.new()
	_title.position = Vector2(0, 420)
	_title.size = Vector2(720, 80)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 48)
	add_child(_title)

	_detail = Label.new()
	_detail.position = Vector2(0, 520)
	_detail.size = Vector2(720, 120)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_font_size_override("font_size", 26)
	add_child(_detail)

	var btn := Button.new()
	btn.text = "다시 도전"
	btn.position = Vector2(210, 700)
	btn.size = Vector2(300, 80)
	btn.add_theme_font_size_override("font_size", 30)
	btn.pressed.connect(func(): restart_pressed.emit())
	add_child(btn)

func show_result(victory: bool, floor_reached: int, level: int, turns: int) -> void:
	_title.text = "저승을 탈출했다!" if victory else "영혼이 저승에 묶였다..."
	_detail.text = "도달: %d층  레벨: %d  턴: %d" % [floor_reached, level, turns]
	visible = true
