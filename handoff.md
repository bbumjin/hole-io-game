# 인계 — 성능 작업(§39, rev.40) 이후

작성 2026-10-08. 상세 근거·실측·감사 로그는 `PLAN.md` §39, 사용법은 `README.md`.

## 현재 상태

- **프로덕션 = main `1429548`** (https://hole-io-game-delta.vercel.app). 브랜치 `perf/p0` 는 main 에 fast-forward 병합됨.
- 판정 **Forward+ 14 · Compatibility 14 전부 PASS**. 구현 코드 감사 93(합격).
- 반영된 것: 게임 내 계측(`?perf=1`·`?perf=bench`) · AI 재선정 분산 + 격자 색인 · 다중 서피스 메시 굽기(드로우콜 −69%) ·
  델타 재시작(3.7s → 0.33s) · 유령(가림 투명화) 셰이더 재컴파일 제거 · 줌 비례 그림자 거리 · judge3c F3 드로우콜 게이트.
- 같이 고친 기존 결함: AMD 등 일부 GPU 에서 ±96·±192 대로가 일반 도로로 그려지던 셰이더 `mod` 정밀도 결함,
  R ≥ 15 에서 구멍 주변 그림자 소실.

## 처음 받았을 때 (필수)

구운 메시(`assets/baked/`)는 git 에 없다. 판정·실행 전에 한 번 굽는다 — 안 하면 원본 메시로 돌아 드로우콜이 세 배가 되고
judge3c F3 가 탈락한다(Vercel 빌드는 자동으로 굽고 개수를 하드 게이트로 본다).

```powershell
$GODOT = ".godot_engine\Godot_v4.7.1-stable_win64_console.exe"
& $GODOT --headless --path . --script res://tools/bake_meshes.gd        # BAKE RESULT made=35 single=15 bad=0
```

원본 OBJ/MTL 을 고치면 다시 굽는다(낡으면 실행 시 `§39: 구운 메시가 원본보다 낡았다` 경고).

## 추후 할 일 (우선순위 순)

### 1. 실기기(폰) 측정 — 유저 필요
- 모든 수치가 데스크톱이다. 목표는 웹·모바일이므로 실기기 기준선이 없다.
- 폰에서 `https://hole-io-game-delta.vercel.app/?perf=bench` 를 화면 켠 채 3회 → 결과표 스크린샷.
- 비교용 최적화 전 빌드가 필요하면 커밋 `9884937`(계측만 들어간 기준선)을 Vercel 프리뷰로 띄운다.

### 2. 같은 세션 A/B (최적화 전 대 후, Chrome)
- 이 기기는 세션 안에서도 처리량이 2~5배 흔들려(부팅 2s → 7s) **세션을 넘는 절대 수치 비교는 무효**다.
- 9884937 빌드와 현재 빌드를 번갈아(전→후→전→후) 같은 조건에서 돌린다. 지난 시도는 메모리 부족으로 강제 종료됐다
  — 기기가 한가할 때, 한 번에 프로세스 하나만.
- Chrome 은 창이 가려지면 rAF 를 멈춰 벤치가 서므로 `--disable-backgrounding-occluded-windows
  --disable-renderer-backgrounding --disable-background-timer-throttling` 로 띄운다. 끝나면 띄운 Chrome·node·Godot 를 정리한다.

### 3. 플레이 시작 직후 2~3초 멈춤 (웹)
- Chrome 벤치에서 첫 구간 시작 무렵 worst 2~3s 가 반복된다(최적화 전 빌드에도 있다 — 기존 문제).
- 가설: WebGL 셰이더·파이프라인의 지연 컴파일. 홈 화면 동안 주요 머티리얼 변형을 미리 그려 두는 예열을 검토.
- 먼저 프로파일로 원인을 확정할 것(가설만으로 고치지 않는다).

### 4. 다운로드 크기 (현재 약 15MB br, pck 는 구운 메시로 +2.6MB)
- `export_presets.cfg` 의 `export_filter="all_resources"` 가 안 쓰는 팩(streets 대부분·transport 일부·Grass)과 원본 OBJ 메시까지 싣는다.
  단, judge3b E1 이 원본 OBJ 를 읽으므로 원본 제외는 판정 쪽 조정과 함께 해야 한다.
- 미사용 모듈을 끈 커스텀 웹 템플릿(wasm 9.5MB br 절감 — 추정치, 미검증). CI 에서 템플릿 빌드·호스팅 방법까지 정해야 한다.

### 5. 남은 CPU 스파이크
- 삼킴 프레임 8~13ms: `hole.rebuild()`(림 `set_faces`·CylinderMesh 재생성·Area 리사이즈)와 동시 해동을 프로파일.
- 시민 재스폰은 `build_walks` 캐시로 일부 줄였다 — 남은 비용(GLB 인스턴스)은 모델 풀 재사용으로 더 줄일 수 있다.
- 저프레임 웹에서 물리 스텝이 한 프레임에 몰리는지(`max_physics_steps_per_frame`)를 실기기 수치로 판단.

### 6. 모바일 필레이트 — 실기기 수치가 나온 뒤
- 고 DPR 캔버스 해상도 상한, MSAA 2x 유지 여부, 그림자 아틀라스 크기(4096 → 2048). 데스크톱 iGPU 로는 판단 불가.

### 7. Forward+ 유령 전환 잔여 스파이크 (낮음)
- Compatibility(배포)는 25 → 1.5ms 로 해결. Forward+ 는 `set_surface_override_material` 한 줄이 14~17ms(엔진 파이프라인 컴파일).
  인스턴스 `transparency` 는 첫 프레임 700ms 라 대안 아님. 배포 렌더러가 아니라 기록만.

## 함정 (이번에 실제로 밟은 것)

- **Compatibility 는 `vertex_color_is_srgb` 를 안 탄다** — 색 관련 고장 주입은 Forward+ 에서 해야 잡힌다(`tools/probe_bake_diff.gd`).
- 셰이더에서 정수 경계 판정에 `mod(k, n)` 을 직접 쓰지 말 것 — `mod(k + 0.5, n) < 1` 처럼 구간 중앙에서 판정.
- 얼린 채 스크립트로 옮기는 차·시민은 정적 색인에 넣으면 안 된다(AI 는 `swallowable_dyn` 그룹으로 따로 훑는다).
- 판정 스위트(28회)·Chrome 벤치는 메모리를 많이 쓴다. Claude Code 의 메모리 회수가 두 번 강제 종료했다 — 남은 프로세스를 매번 정리.
- 이전 커밋(39a6d50 이전부터)은 judge3·judge7 이 이 기기에서 FAIL 이었다(위 `mod` 결함). "관련 판정만" 돌리면 이런 것을 놓친다 — 전체 스위트를 돌린다.

## 검증 명령

```powershell
# 판정 전체 (README 의 14종) — Forward+ 와 Compatibility 둘 다
& $GODOT --path . -- --judge3c                                   # 등등
& $GODOT --path . --rendering-driver opengl3 -- --judge3c        # F3 드로우콜 게이트는 여기서만
# 구운 메시 외형 대조 (두 드라이버)
& $GODOT --path . --rendering-driver opengl3 --script res://tools/probe_bake_diff.gd
# 데스크톱 벤치
& $GODOT --path . --rendering-driver opengl3 -- --perf-bench --perf-novsync --perf-quit
# PLAN.md 소스 전문 동기화
pwsh tools/sync_plan_blocks.ps1 -Fix
```
