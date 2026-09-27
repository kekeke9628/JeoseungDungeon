class_name InventoryPanel
extends Control
## Paper-doll bag, after IsoDungeonRPG's inventory: the player's own character
## stands in the middle, drawn large and wearing everything that is worn (the
## same gear layers as on the map), with the six slots around it joined by a
## line to the body part they dress. The bag is a fixed grid of icon cells
## below, and one detail line with a single action button explains the pick.
## Putting something on flies its icon from the bag to its slot, and the
## figure bounces with a glint where it went.
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
## The figure: 24px character art at 9x, top-left in panel coordinates.
const FIGURE_POS := Vector2(232, 96)
const FIGURE_SCALE: int = 9
## Slots in two columns beside the figure (top-left, panel coordinates).
const SLOT_LAYOUT := {
	"head": Vector2(44, 90),
	"armor": Vector2(44, 190),
	"ring": Vector2(44, 290),
	"weapon": Vector2(560, 120),
	"amulet": Vector2(560, 220),
	"boots": Vector2(560, 320),
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
const LEADER := Color(0.85, 0.7, 0.35, 0.55)
const GAP := 12.0  # between bag cells

## The large character in the middle, wearing what is worn, with lines from
## each slot to the body part it dresses.
class Doll:
	extends Control

	var layers: Array = []  # [TextureRect, Array[Texture2D]] per layer, bottom first
	var lines: Array = []  # [from, to, color] in this control's coordinates
	## Holds the layers; scaled from the feet for the bounce when gear goes on.
	var figure: Control
	var _frame: int = 0

	func _init() -> void:
		figure = Control.new()
		figure.position = InventoryPanel.FIGURE_POS
		figure.size = Vector2(24, 24) * InventoryPanel.FIGURE_SCALE
		figure.pivot_offset = Vector2(figure.size.x * 0.5, figure.size.y * 0.92)
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(figure)

	func _draw() -> void:
		var s: float = InventoryPanel.FIGURE_SCALE
		var foot := InventoryPanel.FIGURE_POS + Vector2(12, 22) * s
		# a pool of light under the figure and a shadow at its feet
		draw_set_transform(foot + Vector2(0, -80), 0.0, Vector2(1.0, 1.25))
		draw_circle(Vector2.ZERO, 120.0, Color(0.95, 0.75, 0.35, 0.06))
		draw_circle(Vector2.ZERO, 80.0, Color(0.95, 0.75, 0.35, 0.06))
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, 70.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
		for l in lines:
			draw_line(l[0], l[1], l[2], 2.0)
			draw_circle(l[1], 4.0, l[2])

	func step() -> void:
		_frame += 1
		for l in layers:
			var frames: Array = l[1]
			if not frames.is_empty():
				l[0].texture = frames[_frame % frames.size()]

var _slot_buttons: Dictionary = {}  # slot -> Button
var _scroll: ScrollContainer
## The slot an icon is flying to; its pop waits for the landing.
var _flying_slot: String = ""
## While an icon is in the air, its slot and the figure keep showing what was
## worn before (slot -> ItemData or null), so the gear goes on as it lands.
var _held: Dictionary = {}
var _doll: Doll
var _doll_bounce: Tween
## What was worn at the last refresh, to tell what just changed.
var _worn_before: Dictionary = {}
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
	var flat := bg.get_theme_stylebox("panel") as StyleBoxFlat
	if flat != null:  # the flat fallback style is see-through; the art is not
		flat.bg_color.a = 1.0
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

	_doll = Doll.new()
	_doll.size = PANEL_SIZE
	_doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_doll)
	var breathe := _doll.create_tween().set_loops()
	breathe.tween_interval(0.5)
	breathe.tween_callback(_doll.step)

	_stats = Label.new()
	_stats.position = Vector2(0, 412)
	_stats.size = Vector2(PANEL_SIZE.x, 40)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_size_override("font_size", 22)
	add_child(_stats)
	_build_slots()

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(30, 476)
	_scroll.size = Vector2(624, 410)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = BAG_COLS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_scroll.add_child(_grid)

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
	GameState.equipment_changed.connect(_on_equipment_changed)

func _on_inventory_changed() -> void:
	if visible:
		refresh()

func show_panel() -> void:
	visible = true
	_clear_selection()
	_held.clear()
	_worn_before = GameState.equipped.duplicate()
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
	_refresh_doll()
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
	_stats.text = "공격 %d-%d    방어 %d    체력 %d/%d" % [
		p.stats.attack_min, p.stats.attack_max, p.stats.defense, p.current_hp, p.stats.max_hp]

## What a slot shows: what is worn, unless an icon is still flying to it.
func _shown(slot: String) -> ItemData:
	return _held[slot] if _held.has(slot) else GameState.equipped.get(slot)

func _refresh_slots() -> void:
	for slot in _slot_buttons.keys():
		var btn: Button = _slot_buttons[slot]
		var worn: ItemData = _shown(slot)
		btn.icon = SpriteLibrary.get_item(worn.id) if worn != null else null
		btn.get_node("Tag").visible = worn == null
		_paint(btn, _sel_slot == slot)

## Rebuilds the figure from the bare body and the worn gear, and the lines
## from each slot to its body part.
func _refresh_doll() -> void:
	for l in _doll.layers:
		l[0].queue_free()
	_doll.layers.clear()
	var sets: Array = []
	if GameState.player_class != null:
		var cid: String = GameState.player_class.id
		var base: Array[Texture2D] = SpriteLibrary.get_actor_frames(cid + "_bare")
		sets.append(base if not base.is_empty() else SpriteLibrary.get_actor_frames(cid))
	for slot in Player.GEAR_ORDER:
		var worn: ItemData = _shown(slot)
		if worn != null:
			sets.append(SpriteLibrary.get_gear_frames(worn.id))
	for frames in sets:
		if frames.is_empty():
			continue
		var r := TextureRect.new()
		r.texture = frames[0]
		r.size = _doll.figure.size
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_doll.figure.add_child(r)
		_doll.layers.append([r, frames])
	_doll.lines.clear()
	for slot in SLOT_LAYOUT:
		var at: Vector2 = SLOT_LAYOUT[slot]
		var left_column: bool = at.x < FIGURE_POS.x
		var from := at + Vector2(SLOT_SIZE.x if left_column else 0.0, SLOT_SIZE.y * 0.5)
		var color: Color = SLOT_COLORS[slot]
		color.a = 0.55 if _shown(slot) != null else 0.2
		_doll.lines.append([from, _anchor(slot), color])
	_doll.queue_redraw()

## Where slot's body part is on the figure, in panel coordinates.
func _anchor(slot: String) -> Vector2:
	return FIGURE_POS + Fx.GEAR_SPOTS[slot] * FIGURE_SCALE

## Gear went on or came off: pop the slot, glint on the body part, bounce the
## figure. An item flying in from the bag does this when it lands instead.
func _on_equipment_changed() -> void:
	if not visible:
		_worn_before = GameState.equipped.duplicate()
		return
	for slot in GameState.EQUIP_SLOTS:
		var now: ItemData = GameState.equipped.get(slot)
		if now == _worn_before.get(slot):
			continue
		if slot == _flying_slot:
			continue
		_celebrate(slot, now != null)
	_worn_before = GameState.equipped.duplicate()

func _celebrate(slot: String, put_on: bool) -> void:
	var btn: Button = _slot_buttons[slot]
	btn.pivot_offset = SLOT_SIZE * 0.5
	btn.scale = Vector2(1.3, 1.3) if put_on else Vector2(0.85, 0.85)
	var pop := btn.create_tween()
	var settle := pop.tween_property(btn, "scale", Vector2.ONE, 0.2)
	settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if put_on:
		var ring := FxShape.new()
		ring.kind = FxShape.Kind.RING
		ring.color = UITheme.GOLD
		ring.time = 0.45
		ring.radius = 46.0
		ring.width = 3.0
		ring.position = _anchor(slot)
		add_child(ring)
		var sparks := PixelBurst.new()
		sparks.color = UITheme.GOLD
		sparks.count = 16
		sparks.speed = 160.0
		sparks.gravity = 120.0
		sparks.size = 2
		sparks.position = _anchor(slot)
		add_child(sparks)
	if _doll_bounce != null and _doll_bounce.is_valid():
		_doll_bounce.kill()
	var fig: Control = _doll.figure
	fig.scale = Vector2(1.08, 0.9) if put_on else Vector2(0.96, 1.04)
	_doll_bounce = fig.create_tween()
	_doll_bounce.tween_property(fig, "scale", Vector2(0.97, 1.05), 0.09)
	_doll_bounce.tween_property(fig, "scale", Vector2.ONE, 0.14)

## The bag cell an item sits in, in panel coordinates (the grid lays cells out
## in inventory order).
func _cell_rect(item: ItemData) -> Rect2:
	for i in range(GameState.inventory.size()):
		if GameState.inventory[i].item_data == item:
			var cell := Vector2((i % BAG_COLS) * (CELL_SIZE.x + GAP), (i / BAG_COLS) * (CELL_SIZE.y + GAP))
			return Rect2(_scroll.position + cell - Vector2(0, _scroll.scroll_vertical), CELL_SIZE)
	return Rect2(_action.position, CELL_SIZE)

## Flies item's icon from start to its slot, then pops the slot.
func _fly_to_slot(item: ItemData, start: Rect2) -> void:
	var slot: String = item.equip_slot()
	var icon := TextureRect.new()
	icon.texture = SpriteLibrary.get_item(item.id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = start.position + Vector2(12, 12)
	icon.size = start.size - Vector2(24, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	var target: Vector2 = SLOT_LAYOUT[slot] + Vector2(10, 12)
	var fly := icon.create_tween().set_parallel(true)
	var arc := fly.tween_property(icon, "position", target, 0.24)
	arc.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(icon, "size", SLOT_SIZE - Vector2(20, 22), 0.24)
	fly.chain().tween_callback(func():
		icon.queue_free()
		if _flying_slot == slot:
			_flying_slot = ""
		_held.erase(slot)
		if visible:
			refresh()
		_celebrate(slot, true))

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
	elif _sel_item.item_type == ItemData.ItemType.FOOD:
		_action.text = "먹기"
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
		var start: Rect2 = _cell_rect(item)
		if item.is_equipment():
			_flying_slot = item.equip_slot()
			_held[_flying_slot] = GameState.equipped.get(_flying_slot)
		item_chosen.emit(item)
		# Worn now: fly it from the bag to its slot, and select the slot.
		if item.is_equipment() and GameState.equipped.get(item.equip_slot()) == item:
			_fly_to_slot(item, start)
			_sel_slot = item.equip_slot()
			_sel_item = item
		else:
			_held.erase(_flying_slot)
			_flying_slot = ""
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
