# 출시 가이드 (Android 우선)

이 문서는 저승던전을 스토어에 내기까지 남은 작업을 순서대로 적은 것입니다.
디버그 APK는 2026-09-25에 Linux(클라우드 세션)에서 빌드·서명·검증까지 확인했습니다(3절). **릴리스 AAB(Gradle 빌드)와 실기기 실행은 아직 해보지 못했습니다.**

## 1. 빌드 환경 준비
1. Godot 4.7.1 에디터 -> `편집기 > 내보내기 템플릿 관리` 에서 4.7.1 템플릿 설치
2. JDK 17 설치 후 `편집기 설정 > 내보내기 > Android > Java SDK Path` 지정
3. Android Studio 또는 cmdline-tools로 Android SDK(플랫폼 35, 빌드 도구) 설치 후 SDK 경로 지정
4. `export/export_presets.template.cfg` 를 프로젝트 루트에 `export_presets.cfg` 로 복사
   (이 파일은 키스토어 정보가 들어갈 수 있어 `.gitignore` 처리되어 있음)
5. `Project > Install Android Build Template` 로 gradle 템플릿 설치 (gradle 빌드 사용)

## 2. 서명 키
- 릴리스 키스토어를 한 번만 만들고 **절대 저장소에 넣지 말 것**, 백업 필수 (분실하면 앱 업데이트 불가)
- `keytool -genkeypair -v -keystore jeoseung-release.keystore -alias jeoseung -keyalg RSA -keysize 2048 -validity 10000`
- Play App Signing 사용을 권장 (업로드 키만 로컬 보관)

## 3. 빌드
- 디버그 APK (Gradle 없이, 확인됨):
  1. 4.7.1 내보내기 템플릿 설치 (Android 파일 `android_debug.apk` 등만 있어도 됨)
  2. Android SDK 경로 지정. `dl.google.com` 에 접근할 수 없는 환경에서는 Ubuntu 패키지 `android-sdk-build-tools`, `adb` 로 대신할 수 있음(`/usr/lib/android-sdk`, apksigner 31). JDK 21로도 서명됨
  3. 디버그 키스토어: `keytool -genkeypair -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 10000 -dname "CN=Android Debug,O=Android,C=US"`
  4. `godot --headless --path . --export-debug "Android (APK debug)" build/JeoseungDungeon-debug.apk`
  5. 결과: 약 28MB, arm64-v8a, minSdk 24(Android 7.0), APK 서명 v2/v3. 32비트 기기에서 시험하려면 프리셋의 `architectures/armeabi-v7a` 를 켜면 됨(약 56MB)
  - Android 내보내기에는 `rendering/textures/vram_compression/import_etc2_astc=true` 가 필요함(`project.godot` 에 설정됨)
  - Gradle 없이 내보낼 때는 프리셋의 Min/Target SDK를 비워 둬야 함(템플릿의 디버그 프리셋은 비어 있음)
  - 디버그 빌드는 상점 결제가 모의 결제라 무료로 지급됨(4절). 테스트용으로만 배포
- 디버그: 기기 연결 후 에디터의 원격 디버그 버튼 (USB 디버깅 켜기)
- 릴리스: `프로젝트 > 내보내기 > Android (AAB release)` -> `build/JeoseungDungeon.aab`
- 웹 (아이폰·PC 브라우저, 확인됨): `godot --headless --path . --export-release "Web" build/web/index.html`
  - 단일 스레드 빌드(`variant/thread_support=false`)라 COOP/COEP 같은 특별한 서버 헤더 없이 아무 정적 호스팅에서나 돈다(itch.io, GitHub Pages 등)
  - 결과: `build/web/` 에 index.html·index.wasm(약 40MB)·index.pck. zip으로 묶으면 약 10MB
  - 모바일 크기(390x844) Chromium에서 새 게임 -> 도움말 -> 이동·줍기까지 확인. 실제 iPhone Safari는 아직 확인하지 못함
  - 브라우저 정책상 소리는 첫 탭 이후에 나오고, 저장은 그 브라우저 안에만 남는다
  - GitHub Pages 자동 게시: `.github/workflows/pages.yml` (저장소 공개 + Settings > Pages > Source를 GitHub Actions로 설정 필요)
- 빌드 전 `res://tests/SmokeTest.tscn` 헤드리스 테스트 통과 확인
- 내보낸 뒤 `tests/export_check.gd` 로 내보낸 빌드를 확인(README의 헤드리스 검증 참고). 편집기에서는 멀쩡해도 내보낸 빌드에서만 데이터가 비는 문제를 잡는다

## 4. 인앱결제 연결 (필수 — 지금은 미연결)
- 현재 `autoloads/IAPManager.gd` 는 디버그 빌드에서만 모의 결제로 동작하고, **릴리스에서는 구매가 막힙니다(안전장치).**
- 연결 순서:
  1. Play Console에 상품 등록: `supporter_pack`(비소모성), `revive_token`(소모성) — 상품 ID를 코드와 동일하게
  2. Godot Android 결제 플러그인(Google Play Billing 지원 플러그인) 설치 및 프리셋에서 활성화
  3. `IAPManager._request_store_purchase()` 에서 플러그인 구매 호출, 성공 콜백에서만 `_grant()` 호출
  4. 앱 시작 시 보유 구매 조회(복원)와 소모성 상품 consume/acknowledge 처리
  5. 출시 전 서버 측 영수증 검증 검토 (클라이언트 파일 저장은 조작 가능)
- 가격 문자열(`PRODUCTS.price`)은 자리표시자이므로 스토어에서 받아온 현지 가격으로 교체

## 5. 스토어 등록 체크리스트
- [ ] 개인정보처리방침 URL 공개 (`docs/PRIVACY_POLICY.md` 를 웹에 게시)
- [ ] 스토어 설명/스크린샷/기능 그래픽 (`docs/STORE_LISTING.md` 참고). 스크린샷은 실제 화면을 `--write-movie` 로 캡처 가능
- [ ] 콘텐츠 등급 설문 (판타지 폭력, 인앱결제 포함) — 한국은 게임물관리위원회 등급분류(또는 구글 IARC 자동 등급) 확인 필요
- [ ] 데이터 보안 양식: 수집 데이터 없음(모든 저장은 기기 내부)으로 기재 — 광고/분석 SDK를 붙이면 수정
- [ ] 대상 API 레벨, 64비트 지원(arm64-v8a 포함됨)
- [ ] 비공개 테스트 트랙으로 먼저 배포 후 실기기(저사양 포함) 확인

## 6. 출시 전 품질 체크 (권장)
- 실기기 터치 조작 감(버튼 크기, 세로 화면 안전 영역/노치)
- 배터리·발열(장시간 플레이), 백그라운드 전환 후 복귀 시 상태
- 저장 파일 손상 시 동작 (`SaveManager.load_data` 는 손상 시 빈 값 반환)
- 밸런스: 실제 플레이 데이터로 재조정 (`tests/BalanceSim.tscn` 는 봇 기준)

## 7. iOS
- macOS + Xcode + Apple 개발자 계정 필요. Godot iOS 내보내기 -> Xcode 프로젝트 -> StoreKit 결제 연동은 Android와 별도 작업입니다.
