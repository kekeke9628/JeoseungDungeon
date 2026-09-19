class_name RecordsPanel
extends Control
## Modal lifetime records screen.

var _body: Label

func _init() -> void:
	visible = false
	position = Vector2(30, 220)
	size = Vector2(660, 760)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.97)
	bg.size = size
	add_child(bg)
	var title := Label.new()
	title.text = "저승 기록"
	title.position = Vector2(0, 20)
	title.size = Vector2(660, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)
	_body = Label.new()
	_body.position = Vector2(50, 110)
	_body.size = Vector2(560, 520)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 28)
	add_child(_body)
	var close := Button.new()
	close.text = "닫기"
	close.position = Vector2(180, 650)
	close.size = Vector2(300, 80)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(hide_panel)
	add_child(close)

func show_panel() -> void:
	var s := StatsManager
	var lines: Array[String] = [
		"도전: %d회" % s.total_runs,
		"탈출(클리어): %d회 (%d%%)" % [s.wins, s.win_rate_percent()],
		"최고 도달: %d층" % s.best_floor,
		"최고 레벨: %d" % s.best_level,
		"처치한 적: %d마리" % s.kills,
	]
	if s.fastest_win_turns > 0:
		lines.append("최단 탈출: %d턴" % s.fastest_win_turns)
	for cls in s.class_wins.keys():
		lines.append("%s 탈출: %d회" % [cls, int(s.class_wins[cls])])
	_body.text = "\n".join(lines)
	visible = true

func hide_panel() -> void:
	visible = false
