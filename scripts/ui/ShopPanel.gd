class_name ShopPanel
extends Control
## Shop listing the IAP products with buy buttons and a result line.

var _status: Label
var _owned: Label
var _buttons: Dictionary = {}

func _init() -> void:
	visible = false
	position = Vector2(30, 200)
	size = Vector2(660, 800)
	add_child(UITheme.make_panel(size))
	_add_label("상점", Vector2(0, 20), Vector2(660, 60), 40)
	_owned = _add_label("", Vector2(20, 90), Vector2(620, 40), 22)
	var y: float = 150.0
	for pid in IAPManager.PRODUCTS.keys():
		var p: Dictionary = IAPManager.PRODUCTS[pid]
		var b := Button.new()
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # before size, or size clamps to the longest line
		b.text = "%s   %s\n%s" % [p.name, p.price, p.desc]
		b.position = Vector2(30, y)
		b.size = Vector2(600, 170)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_on_buy.bind(pid))
		add_child(b)
		_buttons[pid] = b
		y += 190.0
	_status = _add_label("", Vector2(20, 540), Vector2(620, 120), 22)
	var close := Button.new()
	close.text = "닫기"
	close.position = Vector2(180, 690)
	close.size = Vector2(300, 80)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(hide_panel)
	add_child(close)

func _ready() -> void:
	IAPManager.purchase_completed.connect(_on_done)
	IAPManager.purchase_failed.connect(_on_failed)
	IAPManager.state_changed.connect(_refresh)

func _add_label(text: String, pos: Vector2, lbl_size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # before size, or size clamps to the longest line
	l.text = text
	l.position = pos
	l.size = lbl_size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l

func show_panel() -> void:
	_status.text = "" if IAPManager.is_store_available() else "스토어 결제가 아직 연결되지 않았습니다."
	_refresh()
	visible = true

func hide_panel() -> void:
	visible = false

func _refresh() -> void:
	_owned.text = "후원자 팩: %s   부활 부적: %d개" % ["보유" if IAPManager.supporter else "미보유", IAPManager.revive_tokens]
	_buttons["supporter_pack"].disabled = IAPManager.supporter

func _on_buy(product_id: String) -> void:
	AudioManager.play("click")
	IAPManager.purchase(product_id)

func _on_done(product_id: String) -> void:
	_status.text = "%s 구매 완료! (테스트 결제)" % IAPManager.PRODUCTS[product_id].name

func _on_failed(_product_id: String, reason: String) -> void:
	_status.text = reason
