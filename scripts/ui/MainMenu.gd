extends Control
## Title screen: new game (with class selection) or continue a saved run.

const GAME_SCENE: String = "res://scenes/Game.tscn"
const CLASS_DIR: String = "res://resources/classes"

var _main_box: Control
var _class_box: Control
var _settings_btn: Button
var _help_btn: Button
var _shop_btn: Button

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07)
	bg.size = size
	add_child(bg)
	AudioManager.play_music("ambient")
	_build_main_box()
	_build_class_box()
	var settings := SettingsPanel.new()
	var help := HelpPanel.new()
	add_child(settings)
	var shop := ShopPanel.new()
	add_child(help)
	add_child(shop)
	_shop_btn.pressed.connect(shop.show_panel)
	_settings_btn.pressed.connect(settings.show_panel)
	_help_btn.pressed.connect(help.show_panel)

func _make_button(text: String, pos: Vector2, btn_size: Vector2, font_size: int, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = btn_size
	b.add_theme_font_size_override("font_size", font_size)
	parent.add_child(b)
	return b

func _make_label(text: String, pos: Vector2, lbl_size: Vector2, font_size: int, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = lbl_size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

func _build_main_box() -> void:
	_main_box = Control.new()
	_main_box.size = size
	add_child(_main_box)
	_make_label("저승던전", Vector2(0, 260), Vector2(720, 100), 72, _main_box)
	_make_label("한국 설화 로그라이크", Vector2(0, 370), Vector2(720, 50), 28, _main_box)
	var new_btn := _make_button("새 게임", Vector2(210, 560), Vector2(300, 90), 32, _main_box)
	new_btn.pressed.connect(_show_classes)
	var cont_btn := _make_button("이어하기", Vector2(210, 680), Vector2(300, 90), 32, _main_box)
	_settings_btn = _make_button("설정", Vector2(210, 800), Vector2(300, 90), 32, _main_box)
	_help_btn = _make_button("도움말", Vector2(210, 920), Vector2(300, 90), 32, _main_box)
	_shop_btn = _make_button("상점", Vector2(210, 1040), Vector2(300, 90), 32, _main_box)
	var data: Dictionary = SaveManager.load_data()
	cont_btn.disabled = data.is_empty()
	if not data.is_empty():
		cont_btn.text = "이어하기 (%d층)" % int(data.floor)
		cont_btn.pressed.connect(_continue_run.bind(data))

func _build_class_box() -> void:
	_class_box = Control.new()
	_class_box.size = size
	_class_box.visible = false
	add_child(_class_box)
	_make_label("직업 선택", Vector2(0, 80), Vector2(720, 70), 48, _class_box)
	var classes: Array[CharacterClassData] = _load_classes()
	var y: float = 190.0
	for c in classes:
		var text: String = "%s   HP %d  공격 %d-%d  방어 %d\n%s\n기술 [%s] %s (재사용 %d턴)" % [
			c.display_name, c.stats.max_hp, c.stats.attack_min, c.stats.attack_max, c.stats.defense,
			c.description, c.skill_name, c.skill_description, c.skill_cooldown]
		var b := _make_button(text, Vector2(40, y), Vector2(640, 250), 22, _class_box)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_start_new_run.bind(c.id))
		y += 270.0
	var back := _make_button("뒤로", Vector2(210, 1180), Vector2(300, 70), 26, _class_box)
	back.pressed.connect(_show_main)

func _load_classes() -> Array[CharacterClassData]:
	var out: Array[CharacterClassData] = []
	var dir := DirAccess.open(CLASS_DIR)
	if dir == null:
		return out
	var names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			names.append(f)
	names.sort()
	for f in names:
		var c := load("%s/%s" % [CLASS_DIR, f]) as CharacterClassData
		if c:
			out.append(c)
	return out

func _show_classes() -> void:
	_main_box.visible = false
	_class_box.visible = true

func _show_main() -> void:
	_class_box.visible = false
	_main_box.visible = true

func _start_new_run(class_id: String) -> void:
	GameState.selected_class_id = class_id
	GameState.pending_continue = false
	SaveManager.delete_save()
	get_tree().change_scene_to_file(GAME_SCENE)

func _continue_run(data: Dictionary) -> void:
	GameState.selected_class_id = str(data.class_id)
	GameState.pending_continue = true
	get_tree().change_scene_to_file(GAME_SCENE)
