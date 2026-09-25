class_name HelpPanel
extends Control
## Modal how-to-play sheet. Shown automatically on the first run.

signal closed

const HELP_TEXT: String = "[ 조작 ]\n방향 버튼 / 방향키·WASD: 이동. 적에게 부딪히면 공격합니다.\n화면의 칸을 탭하면 그곳까지 걸어갑니다. (적이 보이면 한 칸씩)\n대기: 한 턴 쉬기 (Space)\n기술: 직업 고유 기술 (E). 재사용 대기가 있습니다.\n가방: 물건 사용·장착 (I)\n\n[ 알아두기 ]\n- 한 번 움직일 때마다 적도 한 번씩 움직입니다. 나도 적도 상하좌우로만 움직이고 공격합니다.\n- 감정되지 않은 물건은 쓰면 정체를 알게 됩니다.\n- 문은 시야를 막고, 밟으면 열립니다.\n- 바닥의 함정은 보이지 않지만, 바로 옆 칸에 서 있으면 가끔 이음새를 알아챕니다. (제자리에서 기다리면 더 잘 보입니다)\n- 적도 함정을 못 봅니다. 알아챈 함정 위로 적을 유인하면 대신 걸려듭니다. 단, 보스는 함정을 부수고 옵니다.\n- 파란 우물은 체력을 회복하고, 금빛 제단은 영구 강화를 줍니다. (한 번 쓰면 사라짐)\n- 계단을 밟으면 내려갑니다(보스 층은 보스를 쓰러뜨린 뒤에). 진행은 자동 저장되어, 앱을 꺼도 멈춘 자리에서 이어집니다.\n- 죽으면 처음부터 다시 시작합니다. 20층의 염라대왕을 쓰러뜨리면 탈출!"

func _init() -> void:
	visible = false
	position = Vector2(30, 110)
	size = Vector2(660, 1000)

	add_child(UITheme.make_panel(size))

	var title := Label.new()
	title.text = "도움말"
	title.position = Vector2(0, 20)
	title.size = Vector2(660, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	var body := Label.new()
	# Wrap before sizing: with wrapping off, the size is clamped to the longest line.
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = HELP_TEXT
	body.position = Vector2(30, 95)
	body.size = Vector2(600, 780)
	body.add_theme_font_size_override("font_size", 21)
	add_child(body)

	var close := Button.new()
	close.text = "확인"
	close.position = Vector2(180, 895)
	close.size = Vector2(300, 80)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(hide_panel)
	add_child(close)

func show_panel() -> void:
	visible = true

func hide_panel() -> void:
	visible = false
	closed.emit()
