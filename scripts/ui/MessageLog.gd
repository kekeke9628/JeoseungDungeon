class_name MessageLog
extends Control
## Scrolling event log showing the most recent lines.

const MAX_LINES: int = 6

var _lines: Array[String] = []
var _label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(0, 796)
	size = Vector2(720, 198)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_label = Label.new()
	_label.position = Vector2(14, 6)
	_label.size = Vector2(692, 186)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 19)
	add_child(_label)

func add_message(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_label.text = "\n".join(_lines)
