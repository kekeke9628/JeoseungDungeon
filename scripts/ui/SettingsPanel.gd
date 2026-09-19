class_name SettingsPanel
extends Control
## Modal settings: sound-effect and music volume.

signal closed

var _sfx_slider: HSlider
var _music_slider: HSlider

func _init() -> void:
	visible = false
	position = Vector2(40, 300)
	size = Vector2(640, 520)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.97)
	bg.size = size
	add_child(bg)

	_add_label("설정", Vector2(0, 20), Vector2(640, 60), 40)
	_add_label("효과음", Vector2(40, 130), Vector2(200, 50), 28)
	_sfx_slider = _add_slider(Vector2(240, 140))
	_add_label("음악", Vector2(40, 250), Vector2(200, 50), 28)
	_music_slider = _add_slider(Vector2(240, 260))

	var close := Button.new()
	close.text = "닫기"
	close.position = Vector2(170, 400)
	close.size = Vector2(300, 80)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(hide_panel)
	add_child(close)

func _ready() -> void:
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)

func _add_label(text: String, pos: Vector2, lbl_size: Vector2, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = lbl_size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)

func _add_slider(pos: Vector2) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.size = Vector2(360, 40)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	add_child(s)
	return s

func show_panel() -> void:
	_sfx_slider.set_value_no_signal(SettingsManager.sfx_volume)
	_music_slider.set_value_no_signal(SettingsManager.music_volume)
	visible = true

func hide_panel() -> void:
	visible = false
	closed.emit()

func _on_sfx_changed(v: float) -> void:
	SettingsManager.set_sfx_volume(v)
	AudioManager.play("click")

func _on_music_changed(v: float) -> void:
	SettingsManager.set_music_volume(v)
