class_name InventoryPanel
extends Control
## Modal inventory list. Tapping an entry emits item_chosen; Game.gd applies it.

signal item_chosen(item: ItemData)

var _list: VBoxContainer
var _title: Label

func _init() -> void:
	visible = false
	position = Vector2(40, 100)
	size = Vector2(640, 700)

	add_child(UITheme.make_panel(size))

	_title = Label.new()
	_title.position = Vector2(20, 12)
	_title.add_theme_font_size_override("font_size", 26)
	add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 60)
	scroll.size = Vector2(600, 570)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(600, 0)
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	var close := Button.new()
	close.text = "닫기"
	close.position = Vector2(20, 640)
	close.size = Vector2(600, 50)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(hide_panel)
	add_child(close)

func _ready() -> void:
	GameState.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if visible:
		refresh()

func show_panel() -> void:
	visible = true
	refresh()

func hide_panel() -> void:
	visible = false

func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var w: String = GameState.equipped_weapon.identified_name if GameState.equipped_weapon else "없음"
	var a: String = GameState.equipped_armor.identified_name if GameState.equipped_armor else "없음"
	_title.text = "가방  (무기: %s / 방어구: %s)" % [w, a]
	if GameState.inventory.is_empty():
		var empty := Label.new()
		empty.text = "비어 있다."
		empty.add_theme_font_size_override("font_size", 22)
		_list.add_child(empty)
		return
	for entry in GameState.inventory:
		var item: ItemData = entry.item_data
		var known: bool = GameState.is_identified(item.id)
		var b := Button.new()
		var qty: String = " x%d" % entry.quantity if entry.quantity > 1 else ""
		b.text = "%s%s\n%s" % [item.get_display_name(known), qty, item.get_display_description(known)]
		b.custom_minimum_size = Vector2(600, 84)
		var icon: Texture2D = SpriteLibrary.get_item(item.id)
		if icon != null:
			b.icon = icon
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 56)
			b.add_theme_constant_override("h_separation", 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): item_chosen.emit(item))
		_list.add_child(b)
