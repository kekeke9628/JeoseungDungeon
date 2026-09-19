import io
def patch(p, old, new):
    s = io.open(p, encoding="utf-8").read()
    assert old in s, (p, old)
    io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(old, new, 1))
patch("scripts/ui/HelpPanel.gd", "방향 버튼 / 방향키·WASD: 이동. 적에게 부딪히면 공격합니다.\n", "방향 버튼 / 방향키·WASD: 이동. 적에게 부딪히면 공격합니다.\n화면의 칸을 탭하면 그곳까지 걸어갑니다. (적이 보이면 한 칸씩)\n")
patch("README.md", "- 설정 화면, 첫 실행 도움말, 메인 메뉴 상점\n", "- 설정 화면, 첫 실행 도움말, 메인 메뉴 상점, 기록(통계) 화면\n- 전투 피드백(피해 숫자, 피격 번쩍임, 화면 흔들림), 탭 이동(자동 걷기, 적이 보이면 한 칸씩)\n")
