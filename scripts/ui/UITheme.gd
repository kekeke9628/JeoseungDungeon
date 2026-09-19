class_name UITheme
## Shared look for all UI: dark panels with a muted violet border, gold accents.

const BG := Color(0.08, 0.06, 0.13, 0.97)
const BUTTON_BG := Color(0.14, 0.11, 0.22)
const BUTTON_HOVER := Color(0.20, 0.16, 0.32)
const BUTTON_PRESSED := Color(0.10, 0.08, 0.16)
const BORDER := Color(0.42, 0.36, 0.62)
const GOLD := Color(0.95, 0.80, 0.40)
const TEXT := Color(0.93, 0.91, 0.86)
const TEXT_DISABLED := Color(0.5, 0.48, 0.55)

static var _theme: Theme = null

static func _box(bg: Color, border: Color, radius: int = 10, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _box(BUTTON_BG, BORDER))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER, GOLD))
	t.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, GOLD))
	t.set_stylebox("disabled", "Button", _box(BUTTON_BG.darkened(0.3), BORDER.darkened(0.5)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_color("font_color", "Label", TEXT)
	_theme = t
	return t

## A bordered background panel of the given size.
static func make_panel(panel_size: Vector2) -> Panel:
	var p := Panel.new()
	p.size = panel_size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", _box(BG, BORDER, 14, 3))
	return p
