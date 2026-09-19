# 구조 문서

## 한 턴의 흐름
1. 입력(`Game.gd`): 방향 버튼/키/탭 -> `_on_direction_pressed` 등. 기절이면 `_guard_stun()` 이 행동을 소모.
2. `Player.try_move` 가 이동/공격/줍기/함정 처리 후 `TurnManager.end_player_turn()`.
3. `TurnManager`: 턴 수 +1 -> 플레이어 상태이상 틱(독 피해) -> 기술 재사용 대기 -1 -> 자연 회복 -> 모든 몬스터가 `take_ai_turn()`.
4. `Game._after_player_action()`: 계단이면 다음 층 로드, 아니면 시야(FOV) 갱신.

## 전역 상태(오토로드)
| 이름 | 역할 |
|---|---|
| GameState | 이번 판 진행(층, 골드, 레벨, 인벤토리, 장비, 감정 상태, 기술 대기) |
| DungeonState | 현재 층 타일/액터/바닥 아이템/시야(explored, visible_tiles) |
| TurnManager | 턴 진행, 몬스터 목록 |
| SaveManager | 층 진입 시 자동 저장, 판이 끝나면 삭제(영구 사망) |
| StatsManager | 누적 기록(도전/클리어/처치/최고 층) |
| IAPManager | 상품 목록·보유 상태. 실제 스토어 연결은 미구현(디버그 모의 결제만) |
| SettingsManager / AudioManager | 볼륨 설정 저장 / 효과음·음악 재생 |
| ItemDatabase / MonsterDatabase | `resources/**/*.tres` 로딩 |
| MessageBus | 메시지 로그 이벤트 |

## 데이터 주도 콘텐츠
- `resources/items|monsters|classes/*.tres` 가 원본. 현재는 스크립트로 생성했지만 에디터에서 직접 수정/추가해도 됨(자동 로딩).
- 몬스터 `special`("poison"/"stun")과 `special_chance`, 아이템 `min_floor`, 클래스 `skill_id` 로 동작이 결정됨.
- 새 기술은 `SkillEffects.use()` 의 `match` 에 `skill_id` 추가.
- 새 아이템 효과는 `ItemEffects` (`_drink`/`_read`/`_equip`)에 id 분기 추가.

## 아트/사운드 생성 도구 (`tools/`)
- `gen_sprites.py` + `sprite_templates.py`: 16x16 스프라이트/타일/아이콘
- `gen_audio.py`: 효과음·음악(numpy)
- `gen_icon.py`: 앱 아이콘 세트
- 모두 `assets/` 에 결과물을 쓰며, 같은 파일명의 PNG/WAV로 교체하면 게임이 그대로 사용

## 테스트
- `tests/SmokeTest.tscn`: 헤드리스 로직 검증(콘텐츠 로딩, 클래스, 던전 연결성, 아이템/기술, 시야/문/함정, 20층 진행, 보스, 저장, IAP/부활, 기록, 탭 이동, 상태이상)
- `tests/BalanceSim.tscn`: 봇이 클래스별로 자동 플레이(약 5분)
- 테스트는 저장/설정/구매/기록 경로를 `user://test_*` 로 바꿔 실제 데이터에 영향을 주지 않음
- 주의: `--script` 모드에서는 오토로드 전역 식별자를 컴파일 시점에 못 찾으므로 씬 방식으로 실행

## 알려진 설계 선택
- 플레이어 노드는 사망 시 해제하지 않음(부활 부적 지원). 몬스터는 사망 시 해제.
- 던전은 층 진입 시점에만 저장(층 중간 저장 없음). 저장은 판이 확정적으로 끝날 때(클리어, 부활 없는 사망, 재도전)만 삭제되므로, 부활 부적이 있는 사망 화면에서 앱을 끄면 층 시작 상태로 이어하기가 가능함.
- 시야 밖 몬스터는 `visible=false` 로 숨김(피해 팝업도 생략).
