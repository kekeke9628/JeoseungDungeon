class_name MessageLog
extends Control
## Scrolling event log showing the most recent lines. The newest line is
## brightest and older ones fade, so the latest event is easy to spot.

const MAX_LINES: int = 6
const NEWEST := Color(0.98, 0.96, 0.9)
const OLDEST := Color(0.55, 0.53, 0.6)

var _lines: Array[String] = []
var _label: RichTextLabel

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(0, 796)
	size = Vector2(720, 198)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UITheme.panel_box())
	bg.position = Vector2(-14, 0)  # sides tucked off screen
	bg.size = Vector2(748, size.y)
	bg.modulate = Color(1, 1, 1, 0.92)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.position = Vector2(16, 12)
	_label.size = Vector2(688, 176)
	_label.add_theme_font_size_override("normal_font_size", 19)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func add_message(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	var out: Array[String] = []
	for i in range(_lines.size()):
		var age: float = float(_lines.size() - 1 - i) / float(maxi(1, MAX_LINES - 1))
		var c: Color = NEWEST.lerp(OLDEST, age)
		out.append("[color=#%s]%s[/color]" % [c.to_html(false), _lines[i].replace("[", "[lb]")])
	_label.text = "\n".join(out)

## The visible lines as plain text.
func plain_text() -> String:
	return "\n".join(_lines)
