class_name InventoryPanel
extends Control
## Paper-doll bag, after IsoDungeonRPG's inventory: the six worn slots sit on a
## body silhouette where the gear is worn, the bag is a fixed grid of icon cells
## below, and one detail line with a single action button explains the pick.
## Tapping a cell or slot selects it; the button then wears, drinks, reads or
## takes off. Game.gd applies the choice (item_chosen / unequip_chosen), so each
## one spends a turn like any other action.

signal item_chosen(item: ItemData)
signal unequip_chosen(slot: String)

const PANEL_SIZE := Vector2(680, 1112)
const SLOT_SIZE := Vector2(76, 76)
const CELL_SIZE := Vector2(92, 92)
const BAG_COLS := 6
## The bag always draws at least this many cells so it reads as a bag, not a list.
const BAG_MIN_CELLS := 24
## The silhouette's place in the panel (the texture is 260x460, drawn at 0.826).
const BODY_RECT := Rect2(233, 76, 215, 380)
## Slot positions (top-left, in panel coordinates) over the matching body part.
const SLOT_LAYOUT := {
	"head": Vector2(302, 79),
	"amulet": Vector2(414, 112),
	"armor": Vector2(302, 203),
	"weapon": Vector2(184, 262),
	"ring": Vector2(420, 262),
	"boots": Vector2(302, 380),
}
const SLOT_NAMES := {
	"head": "머리", "weapon": "무기", "armor": "옷",
	"amulet": "노리개", "ring": "가락지", "boots": "신발",
}
## Each slot's colour. The same colour marks bag cells that fit that slot, so
## where an item goes can be read without any text.
const SLOT_COLORS := {
	"head": Color(0.55, 0.75, 1.0),
	"weapon": Color(1.0, 0.45, 0.40),
	"armor": Color(0.45, 0.85, 0.60),
	"amulet": Color(0.95, 0.75, 0.35),
	"ring": Color(0.45, 0.90, 0.95),
	"boots": Color(0.70, 0.55, 0.40),
}
const EDGE := Color(0.36, 0.30, 0.50)
const EDGE_SELECT := Color(1.0, 0.86, 0.38)
const CELL_BG := Color(0.11, 0.09, 0.17)
const CELL_BG_HOVER := Color(0.17, 0.14, 0.26)
const BODY_TEXTURE := "res://assets/sprites/ui/paperdoll_body.png"

var _slot_buttons: Dictionary = {}  # slot -> Button
var _grid: GridContainer
var _stats: Label
var _detail: Label
var _action: Button
## What the detail line shows: a bag item, or (with _sel_slot set) a worn slot.
var _sel_item: ItemData = null
var _sel_slot: String = ""

func _init() -> void:
	visible = false
	position = Vector2(20, 84)
	size = PANEL_SIZE
	# Dim the whole screen behind the bag; the panel itself is fully opaque so
	# the message log underneath does not show through it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.position = -position
	dim.size = Vector2(720, 1280)
	add_child(dim)
	var bg := UITheme.make_panel(size)
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a = 1.0
	add_child(bg)

	var title := Label.new()
	title.text = "가방"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	add_child(title)

	var close := Button.new()
	close.text = "닫기"
	close.position = Vector2(548, 14)
	close.size = Vector2(116, 52)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(hide_panel)
	add_child(close)

	_stats = Label.new()
	_stats.position = Vector2(24, 84)
	_stats.size = Vector2(170, 170)
	_stats.add_theme_font_size_override("font_size", 21)
	add_child(_stats)

	var body := TextureRect.new()
	body.texture = load(BODY_TEXTURE)
	# Expand mode first: while it is KEEP_SIZE, a size smaller than the texture
	# is clamped up to the texture's own 260x460 and stays that way.
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.position = BODY_RECT.position
	body.size = BODY_RECT.size
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	body.modulate = Color(1, 1, 1, 0.85)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	_build_slots()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 476)
	scroll.size = Vector2(624, 410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = BAG_COLS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.position = Vector2(24, 900)
	_detail.size = Vector2(460, 196)
	_detail.add_theme_font_size_override("font_size", 21)
	add_child(_detail)

	_action = Button.new()
	_action.position = Vector2(500, 924)
	_action.size = Vector2(156, 84)
	_action.add_theme_font_size_override("font_size", 28)
	_action.pressed.connect(_on_action_pressed)
	add_child(_action)

func _ready() -> void:
	GameState.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if visible:
		refresh()

func show_panel() -> void:
	visible = true
	_clear_selection()
	refresh()

func hide_panel() -> void:
	visible = false

func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func refresh() -> void:
	# A selected bag item that is gone now (used up, or just worn) is deselected.
	if _sel_slot == "" and _sel_item != null and _bag_quantity(_sel_item) == 0:
		_sel_item = null
	_refresh_stats()
	_refresh_slots()
	_refresh_bag()
	_refresh_detail()

func _build_slots() -> void:
	for slot in GameState.EQUIP_SLOTS:
		var btn := Button.new()
		btn.position = SLOT_LAYOUT[slot]
		btn.size = SLOT_SIZE
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_slot_pressed.bind(slot), CONNECT_DEFERRED)
		btn.add_child(_color_bar(SLOT_COLORS[slot], SLOT_SIZE.x))
		var tag := Label.new()
		tag.name = "Tag"
		tag.text = SLOT_NAMES[slot]
		tag.add_theme_font_size_override("font_size", 17)
		tag.add_theme_color_override("font_color", Color(0.58, 0.53, 0.68))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(tag)
		add_child(btn)
		_slot_buttons[slot] = btn

func _refresh_stats() -> void:
	var p = TurnManager.player
	if p == null or not is_instance_valid(p):
		_stats.text = ""
		return
	_stats.text = "공격 %d-%d\n방어 %d\n체력 %d/%d" % [
		p.stats.attack_min, p.stats.attack_max, p.stats.defense, p.current_hp, p.stats.max_hp]

func _refresh_slots() -> void:
	for slot in _slot_buttons.keys():
		var btn: Button = _slot_buttons[slot]
		var worn: ItemData = GameState.equipped.get(slot)
		btn.icon = SpriteLibrary.get_item(worn.id) if worn != null else null
		btn.get_node("Tag").visible = worn == null
		_paint(btn, _sel_slot == slot)

func _refresh_bag() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var shown: int = 0
	for entry in GameState.inventory:
		_grid.add_child(_bag_cell(entry.item_data, entry.quantity))
		shown += 1
	for i in range(maxi(0, BAG_MIN_CELLS - shown)):
		var empty := Panel.new()
		empty.custom_minimum_size = CELL_SIZE
		var style := _cell_style(EDGE.darkened(0.3), 2, CELL_BG.darkened(0.25))
		empty.add_theme_stylebox_override("panel", style)
		_grid.add_child(empty)

func _bag_cell(item: ItemData, quantity: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CELL_SIZE
	btn.icon = SpriteLibrary.get_item(item.id)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.focus_mode = Control.FOCUS_NONE
	_paint(btn, _sel_slot == "" and _sel_item == item)
	if item.is_equipment():
		btn.add_child(_color_bar(SLOT_COLORS[item.equip_slot()], CELL_SIZE.x))
	if quantity > 1:
		var badge := Label.new()
		badge.text = "x%d" % quantity
		badge.add_theme_font_size_override("font_size", 18)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 5)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.position = Vector2(CELL_SIZE.x - 50, CELL_SIZE.y - 28)
		badge.size = Vector2(44, 24)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	# Deferred: the handler rebuilds the grid, which frees this very button.
	btn.pressed.connect(_on_bag_pressed.bind(item), CONNECT_DEFERRED)
	return btn

func _refresh_detail() -> void:
	_action.visible = false
	if _sel_slot != "":
		var worn: ItemData = GameState.equipped.get(_sel_slot)
		if worn == null:
			_detail.text = "%s 칸이 비어 있다. 가방의 장비를 눌러 입어 보자." % SLOT_NAMES[_sel_slot]
			return
		var slot_name: String = SLOT_NAMES[_sel_slot]
		_detail.text = "%s  [%s]\n%s" % [worn.identified_name, slot_name, worn.identified_description]
		_action.text = "벗기"
		_action.visible = true
		return
	if _sel_item == null:
		_detail.text = "칸을 누르면 물건을 살펴볼 수 있다.\n색 막대는 그 물건을 입는 자리다."
		return
	var known: bool = GameState.is_identified(_sel_item.id)
	var lines: Array[String] = [
		_sel_item.get_display_name(known), _sel_item.get_display_description(known)]
	if _sel_item.is_equipment():
		var slot: String = _sel_item.equip_slot()
		lines[0] += "  [%s]" % SLOT_NAMES[slot]
		var worn: ItemData = GameState.equipped.get(slot)
		if worn != null:
			lines.append("지금 착용: %s" % worn.identified_description)
		_action.text = "장착"
		_action.visible = true
	elif _sel_item.item_type == ItemData.ItemType.POTION:
		_action.text = "마시기"
		_action.visible = true
	elif _sel_item.item_type == ItemData.ItemType.SCROLL:
		_action.text = "읽기"
		_action.visible = true
	_detail.text = "\n".join(lines)

func _on_bag_pressed(item: ItemData) -> void:
	_sel_item = item
	_sel_slot = ""
	refresh()

func _on_slot_pressed(slot: String) -> void:
	_sel_slot = slot
	_sel_item = GameState.equipped.get(slot)
	refresh()

func _on_action_pressed() -> void:
	if _sel_slot != "":
		var worn: ItemData = GameState.equipped.get(_sel_slot)
		unequip_chosen.emit(_sel_slot)
		# Follow what was taken off into the bag, so it is easy to see where it went.
		if worn != null and not GameState.equipped.has(_sel_slot):
			_sel_slot = ""
			_sel_item = worn
	elif _sel_item != null:
		var item: ItemData = _sel_item
		item_chosen.emit(item)
		# Worn now: select its slot to show where it went.
		if item.is_equipment() and GameState.equipped.get(item.equip_slot()) == item:
			_sel_slot = item.equip_slot()
			_sel_item = item
	if visible:
		refresh()

func _clear_selection() -> void:
	_sel_item = null
	_sel_slot = ""

func _bag_quantity(item: ItemData) -> int:
	for entry in GameState.inventory:
		if entry.item_data == item:
			return entry.quantity
	return 0

func _color_bar(color: Color, width: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.position = Vector2(10, 5)
	bar.size = Vector2(width - 20, 5)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _paint(btn: Button, selected: bool) -> void:
	var width: int = 3 if selected else 2
	var edge: Color = EDGE_SELECT if selected else EDGE
	btn.add_theme_stylebox_override("normal", _cell_style(edge, width, CELL_BG))
	btn.add_theme_stylebox_override("hover", _cell_style(EDGE_SELECT, width, CELL_BG_HOVER))
	btn.add_theme_stylebox_override("pressed", _cell_style(EDGE_SELECT, width, CELL_BG_HOVER))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _cell_style(border: Color, width: int, bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	# expand_icon fits the icon inside the content margins.
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 14
	s.content_margin_bottom = 10
	return s
