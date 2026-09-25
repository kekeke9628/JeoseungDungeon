# 구조 문서

## 한 턴의 흐름
1. 입력(`Game.gd`): 방향 버튼/키/탭 -> `_on_direction_pressed` 등. 기절이면 `_guard_stun()` 이 행동을 소모.
2. `Player.try_move` 가 이동/공격/줍기/함정(`TrapSystem.trigger`) 처리 후 `TurnManager.end_player_turn()`.
3. `TurnManager`: 턴 수 +1 -> 플레이어 상태이상 틱(독 피해) -> 기술 재사용 대기 -1 -> 자연 회복 -> 모든 몬스터가 `take_ai_turn()`. 몬스터가 이동한 칸에 함정이 있으면 같은 `TrapSystem.trigger` 를 탄다.
4. `Game._after_player_action()`: 계단이면 다음 층 로드, 아니면 시야(FOV) 갱신. 층 보스가 살아 있으면 계단이 막히고(`_floor_boss`), 한 번 막힌 뒤에는 계단에서 내려섰다가 다시 밟아야 내려간다(계단 위에서 보스를 잡아도 전리품을 주울 틈이 있게).

## 전역 상태(오토로드)
| 이름 | 역할 |
|---|---|
| GameState | 이번 판 진행(층, 골드, 레벨, 인벤토리, 장비, 감정 상태, 기술 대기) |
| DungeonState | 현재 층 타일/액터/바닥 아이템/시야(explored, visible_tiles)/알아챈 함정(spotted_traps) |
| TurnManager | 턴 진행, 몬스터 목록 |
| SaveManager | 현재 층까지 통째로 자동 저장(`encode_floor`/`decode_floor`), 판이 끝나면 삭제(영구 사망) |
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
- `tests/SmokeTest.tscn`: 헤드리스 로직 검증(콘텐츠 로딩, 클래스, 던전 연결성, 아이템/기술, 시야/문/함정, 20층 진행, 보스, 저장·층 복원·자동 저장, IAP/부활, 기록, 탭 이동, 상태이상)
- `tests/BalanceSim.tscn`: 봇이 클래스별로 자동 플레이(약 5분)
- 테스트는 저장/설정/구매/기록 경로를 `user://test_*` 로 바꿔 실제 데이터에 영향을 주지 않음
- 주의: `--script` 모드에서는 오토로드 전역 식별자를 컴파일 시점에 못 찾으므로 씬 방식으로 실행

## 알려진 설계 선택
- 플레이어 노드는 사망 시 해제하지 않음(부활 부적 지원). 몬스터는 사망 시 해제.
- 저장 시점: 층 진입, `Game.AUTOSAVE_TURNS`(10)턴마다, 앱이 백그라운드로 가거나 닫힐 때(`_notification`: APPLICATION_PAUSED / WM_CLOSE_REQUEST / WM_GO_BACK_REQUEST), 부활·부활 가능한 사망 직후. 저장에는 층 스냅샷(`floor_state`)이 들어가며, 타일과 탐험 여부는 칸당 숫자 한 글자인 행 문자열로 담는다. 이어하기는 이 스냅샷으로 층을 그대로 복원하므로 앱을 껐다 켜서 층을 다시 뽑을 수 없다.
- 스냅샷이 없거나 깨졌으면(`decode_floor` 가 `{}`) 새 층을 생성해 이어한다. 예전 버전 저장도 같은 경로를 타므로 `SAVE_VERSION` 은 그대로 1. 사라진 아이템·몬스터 id 는 건너뛴다.
- 부활 부적이 남은 사망은 `dead: true` 로 저장되고, 이어하면 같은 사망 화면이 다시 열린다(앱을 꺼서 죽음을 피하는 것 방지). 저장은 판이 확정적으로 끝날 때(클리어, 부활 없는 사망, 재도전)만 삭제된다.
- 크래시처럼 알림 없이 죽으면 마지막 자동 저장(최대 10턴 전)으로 돌아간다.
- 시야 밖 몬스터는 `visible=false` 로 숨김(피해 팝업도 생략).
- 함정은 `TrapSystem` 한 곳에서 처리하고 플레이어/몬스터가 공유한다. 보스만 예외로 함정을 부수고 지나간다(보스전 중 순간이동으로 싸움이 끊기지 않게).
- 함정 인지는 확률(`TrapSystem.SPOT_CHANCE`)이다. 인접하면 무조건 보이게 하면 플레이어는 함정을 절대 안 밟게 되어 위협이 사라진다. 알아챈 칸은 `DungeonState.spotted_traps` 에 쌓이고, 렌더러가 `trap_spotted` 타일로 그리며 `Pathfinder` 가 우회한다(우회로가 없으면 그대로 통과).
- 시야 밖에서 터진 함정은 소리/메시지를 내지 않는다(`DungeonState.visible_tiles` 기준).
