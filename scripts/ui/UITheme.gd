class_name UITheme
## Shared look for all UI: black lacquer boxes with a gold inlay line (nine-
## slice art from tools/gen_ui.py), gold accents, warm white text. Falls back
## to flat boxes if the art is missing.

const UI_DIR: String = "res://assets/sprites/ui/"
const BG := Color(0.08, 0.06, 0.13, 0.97)
const BUTTON_BG := Color(0.14, 0.11, 0.22)
const BUTTON_HOVER := Color(0.20, 0.16, 0.32)
const BUTTON_PRESSED := Color(0.10, 0.08, 0.16)
const BORDER := Color(0.42, 0.36, 0.62)
const GOLD := Color(0.95, 0.80, 0.40)
const TEXT := Color(0.93, 0.91, 0.86)
const TEXT_DISABLED := Color(0.5, 0.48, 0.55)
## Nine-slice margins of the art, in screen px (art pixels are drawn at 2x).
const BUTTON_MARGIN: int = 10
const PANEL_MARGIN: int = 14
const BAR_MARGIN: int = 4

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

## A nine-slice box from ui art, or fallback when the art is missing.
## sink moves the content down (a pressed button).
static func skin(art: String, margin: int, fallback: StyleBox, sink: int = 0) -> StyleBox:
	var path: String = UI_DIR + art + ".png"
	if not ResourceLoader.exists(path):
		return fallback
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.set_texture_margin_all(margin)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8 + sink
	sb.content_margin_bottom = 8 - sink
	return sb

## A button icon from ui art (drawn at 3x already), or null.
static func icon(icon_name: String) -> Texture2D:
	var path: String = UI_DIR + "icon_" + icon_name + ".png"
	return load(path) if ResourceLoader.exists(path) else null

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var normal: StyleBox = skin("button_normal", BUTTON_MARGIN, _box(BUTTON_BG, BORDER))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	var pressed: StyleBox = skin("button_pressed", BUTTON_MARGIN, _box(BUTTON_PRESSED, GOLD), 2)
	t.set_stylebox("pressed", "Button", pressed)
	var off: StyleBox = _box(BUTTON_BG.darkened(0.3), BORDER.darkened(0.5))
	t.set_stylebox("disabled", "Button", skin("button_disabled", BUTTON_MARGIN, off))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0))
	t.set_constant("outline_size", "Button", 4)
	t.set_constant("h_separation", "Button", 10)
	t.set_color("font_color", "Label", TEXT)
	_theme = t
	return t

## A bordered background panel of the given size.
static func make_panel(panel_size: Vector2) -> Panel:
	var p := Panel.new()
	p.size = panel_size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", panel_box())
	return p

static func panel_box() -> StyleBox:
	return skin("panel", PANEL_MARGIN, _box(BG, BORDER, 14, 3))
