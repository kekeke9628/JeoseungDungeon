# 저승던전 (Jeoseung Dungeon)

한국 설화 기반 턴제 로그라이크 던전 크롤러. Godot 4.7.1 / GDScript, 모바일(Android/iOS) 타겟.
Shattered Pixel Dungeon에서 장르 영감만 받았고, 코드/아트/이름은 전부 오리지널입니다
(SPD는 GPL-3.0이라 코드·에셋을 가져오면 안 됩니다).

## 실행
- 에디터: Godot 4.7.1로 `project.godot` 열기 -> F5
- 조작: 방향키/WASD 이동(적에게 부딪히면 공격), Space 대기, I 가방. 모바일은 화면 D-pad.
- 헤드리스 검증:
  - `Godot --headless --path . res://tests/SmokeTest.tscn` (로직 스모크 테스트, 실패 시 exit 1)
  - `Godot --headless --path . res://tests/BalanceSim.tscn` (봇 20판 밸런스 시뮬레이션)

## Phase 1 범위 (구현 완료)
- 클래스 1개(무당), 몬스터 7종 + 보스(염라대왕), 아이템 8종, 8층 던전
- 절차적 던전(방+복도), 턴제 전투, 아이템 감정(사용 시 정체 확인), 장비, 레벨업, 자연 회복
- 데이터 주도: 아이템/몬스터/클래스는 `resources/**/*.tres` (스크립트 수정 없이 추가 가능)
- 봇 시뮬레이션 기준 클리어율 약 55% (밸런스 출발점, 사람이 하면 더 쉬움)

## 구조
- `autoloads/` 전역 상태 (GameState, DungeonState, TurnManager, ItemDatabase, MonsterDatabase, MessageBus)
- `scripts/core` Actor/Player/Game/CombatSystem, `scripts/ai` Monster, `scripts/generation` 던전 생성/렌더
- `scripts/items` ItemData/ItemEffects, `scripts/ui` 코드로 만든 UI
- 아트는 색 사각형 + 글자 플레이스홀더. 실제 스프라이트는 `Actor.gd`/`DungeonRenderer.gd`만 교체

## 다음 단계
- Phase 2: 클래스 추가, 몬스터/아이템/스킬 확장, 20+층, 함정/문/시야(안개), 저장/불러오기
- Phase 3: 픽셀아트 에셋, 사운드, 한글 폰트 번들(Noto Sans KR 등, 현재는 시스템 폰트 fallback),
  IAP 연동, Android/iOS export 설정, 스토어 준비
- 알려진 한계: 시야/안개 없음, 원거리 몬스터는 벽 무시, 함정/문 미구현, 저장 없음
