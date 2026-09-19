class_name HelpPanel
extends Control
## Modal how-to-play sheet. Shown automatically on the first run.

signal closed

const HELP_TEXT: String = "[ 조작 ]\n방향 버튼 / 방향키·WASD: 이동. 적에게 부딪히면 공격합니다.\n화면의 칸을 탭하면 그곳까지 걸어갑니다. (적이 보이면 한 칸씩)\n대기: 한 턴 쉬기 (Space)\n기술: 직업 고유 기술 (E). 재사용 대기가 있습니다.\n가방: 물건 사용·장착 (I)\n\n[ 알아두기 ]\n- 한 번 움직일 때마다 적도 한 번씩 움직입니다.\n- 감정되지 않은 물건은 쓰면 정체를 알게 됩니다.\n- 문은 시야를 막고, 밟으면 열립니다.\n- 바닥의 함정은 밟기 전까지 보이지 않습니다.\n- 계단은 자동으로 내려갑니다. 층에 들어갈 때 자동 저장됩니다.\n- 죽으면 처음부터 다시 시작합니다. 20층의 염라대왕을 쓰러뜨리면 탈출!"

func _init() -> void:
	visible = false
	position = Vector2(30, 160)
	size = Vector2(660, 900)

	add_child(UITheme.make_panel(size))

	var title := Label.new()
	title.text = "도움말"
	title.position = Vector2(0, 20)
	title.size = Vector2(660, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	var body := Label.new()
	body.text = HELP_TEXT
	body.position = Vector2(30, 100)
	body.size = Vector2(600, 660)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 21)
	add_child(body)

	var close := Button.new()
	close.text = "확인"
	close.position = Vector2(180, 790)
	close.size = Vector2(300, 80)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(hide_panel)
	add_child(close)

func show_panel() -> void:
	visible = true

func hide_panel() -> void:
	visible = false
	closed.emit()
