# hole.io 클론

Godot 4.7.1 로 만든 hole.io 클론. 지면 셰이더의 **월드좌표 SDF** 로 구멍 착시를 만들고,
그 위에 흡입 물리 · 면적 보존 성장 · 절차적 도시 · AI 경쟁 구멍 · 게임 루프를 쌓았다.

**플레이: https://bbumjin.github.io/hole-io-game/**

| 키 | 동작 |
|---|---|
| `WASD` / 방향키 | 구멍 이동 |
| `R` | 재시작 (게임 오버 상태에서) |

작은 것부터 삼키며 반경을 키운다. 크기 게이트(`반경 × 0.45`)를 넘는 것은 삼켜지지 않는다.
AI 구멍 5개가 같이 자라며, 상대가 8할쯤 내 원반 안으로 들어오면 삼킬 수 있다 — 반대도 마찬가지다.

## 구조

```
project.godot          Forward+ / Jolt / MSAA. 웹은 gl_compatibility 로 오버라이드
shaders/               지면 셰이더 — 구멍 SDF + 도로·보도·노면표시를 한 장에서 그린다
scripts/
  hole.gd              구멍(SSOT). 우물·감지범위·성장·포식이 전부 radius 에서 파생된다
  hole_registry.gd     autoload. 구멍 목록을 셰이더 uniform 으로 밀어 넣는다
  swallowable.gd       흡입 대상. 크기·낙하 상태만 안다
  city.gd              절차적 도시 배치(시드 고정). plan() 은 순수 함수라 판정이 두 번 돌린다
  hole_ai.gd           경쟁 구멍 조종 — 도망 / 추격 / 먹이 / 배회
  main.gd              아레나. 포식 해소·타이머·리더보드·승패·재시작
  camera_rig.gd        반경 비례 추적 + 최저 높이 clamp
  screenshot.gd        기계 판정기 (--judge ~ --judge5)
assets/                Quaternius CC0 76모델 (OBJ + MTL 단색)
PLAN.md                설계 근거 · 실측 · 뒤집힌 결정 전부
```

## 검증

이 프로젝트는 **눈으로 확인하지 않는다.** 판정 8종을 창 모드 실행에서 돌려 픽셀과 상태를 잰다.

```powershell
$GODOT = "...\Godot_v4.7.1-stable_win64_console.exe"
& $GODOT --path . -- --judge      # 1a  정지 구멍 착시 (H1~H10)
& $GODOT --path . -- --judge1b    # 1b  이동 + 흡입 물리 (B1~B4)
& $GODOT --path . -- --judge2     # 2   성장 · 크기 게이트 · 스코어 (C1~C4)
& $GODOT --path . -- --judge3     # 3a  도로 셰이더 · 도시 격자 (D1~D6, 도로 위계 포함)
& $GODOT --path . -- --judge3b    # 3b  절차적 배치 (E1~E7)
& $GODOT --path . -- --judge3c    # 3c  성능 (F1~F2) — 단독으로 돌린다
& $GODOT --path . -- --judge4     # 4a  AI 경쟁 · 포식 (G1~G7)
& $GODOT --path . -- --judge5     # 4b  게임 루프 (T1~T6)
```

전부 `JUDGE RESULT -> PASS` / exit 0 이어야 한다.

**판정 기준은 만든 즉시 고장을 주입해 실제로 탈락하는지 확인한다.** 정상 빌드가 통과하는
것만 본 기준은 위약이다 — 이 프로젝트에서 그 함정을 여러 번 밟았고 전부 PLAN.md 에 남겼다.
누적 고장 주입 54종을 전부 검출한다.

**판정기는 구현체를 믿지 않는다.** 성장 계수·격자 주기·포식 규칙 같은 규격 값을 `SPEC_*`
상수로 따로 들고 있다. 게임 값을 바꾸면 규격도 함께 고쳐야 하며, 그러지 않으면 판정이
오검출로 알려 준다(실제로 두 번 그랬다).

## 웹 빌드

```powershell
& $GODOT --headless --path . --export-release "Web" build/index.html
```

스레드를 쓰지 않는 변형으로 내보내므로 `COOP`/`COEP` 헤더가 필요 없다 — GitHub Pages
같은 헤더 설정이 불가능한 정적 호스팅에서도 그대로 돈다.

## 라이선스

코드는 이 저장소를 따른다. `assets/` 는 [Quaternius](https://quaternius.com) 의 CC0 에셋이며
각 팩의 `License.txt` 를 함께 두었다.
