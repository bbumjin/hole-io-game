# hole.io 클론

Godot 4.7.1 로 만든 hole.io 클론. 지면 셰이더의 **월드좌표 SDF** 로 구멍 착시를 만들고,
그 위에 흡입 물리 · 면적 보존 성장 · 절차적 도시 · AI 경쟁 구멍 · 게임 루프를 쌓았다.

**플레이: https://hole-io-game-delta.vercel.app**

| 키 | 동작 |
|---|---|
| `WASD` / 방향키 | 구멍 이동 |
| `R` | 재시작 (게임 오버 상태에서) |

작은 것부터 삼키며 반경을 키운다. **무엇이 들어가는지는 물리가 정한다**(§23) — 구멍 둘레에
가운데가 뚫린 물리적 림이 있고, 감지 범위의 물체는 지면 대신 그 림을 딛는다. 크기 게이트는
없다. 폭이 구멍보다 넓으면 림에 걸쳐 얹히고, 나무는 밑동이 아니라 **가지가** 걸린다.
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
  screenshot.gd        기계 판정기 (--judge ~ --judge6)
assets/                Quaternius CC0 78모델 (OBJ + MTL 단색)
tools/
  web_judge.mjs        브라우저 판정 하네스 — build/ 서빙 + 판정 결과 수집(§24)
  sync_plan_blocks.ps1 PLAN.md 에 실린 소스 전문이 실제 파일과 같은지 대조(§24)
PLAN.md                설계 근거 · 실측 · 뒤집힌 결정 전부
```

## 검증

이 프로젝트는 **눈으로 확인하지 않는다.** 판정 14종을 창 모드 실행에서 돌려 픽셀과 상태를 잰다.

```powershell
$GODOT = "...\Godot_v4.7.1-stable_win64_console.exe"
& $GODOT --path . -- --judge      # 1a  정지 구멍 착시 (H1·H2·H7~H10 — H3·H6은 폐기, 진단용)
& $GODOT --path . -- --judge1b    # 1b  이동 + 흡입 물리 (B1~B4)
& $GODOT --path . -- --judge2     # 2   성장 · 거절 규격 · 스코어 (C1~C4)
& $GODOT --path . -- --judge3     # 3a  도로 셰이더 · 도시 격자 (D1~D6, 도로 위계 포함)
& $GODOT --path . -- --judge3b    # 3b  절차적 배치 (E1~E9, §36 가로수 포함)
& $GODOT --path . -- --judge3c    # 3c  성능 (F1~F2) — 단독으로 돌린다
& $GODOT --path . -- --judge4     # 4a  AI 경쟁 · 포식 (G1~G7)
& $GODOT --path . -- --judge5     # 4b  게임 루프 · 픽스처 격리 · 한글 HUD (T1~T8)
& $GODOT --path . -- --judge6     # §23 물리 통과 — 통과·거절·수관 걸림 (K1~K6)
& $GODOT --path . -- --judge7     # §27 교통 (Z1~Z8)
& $GODOT --path . -- --judge8     # §26 게임 UI (U1~U4)
& $GODOT --path . -- --judge9     # §28·§34 시민과 모델 (M1~M15)
& $GODOT --path . -- --judge10    # §29 카메라 — 회전 상수·성장 후퇴·스냅·계단 응답 (V1~V4)
& $GODOT --path . -- --judge11    # §37 가림 투명화 (O1~O6)
```

전부 `JUDGE RESULT -> PASS` / exit 0 이어야 한다.
배포본과 같은 렌더링 백엔드(WebGL2)로도 돌린다: `--rendering-driver opengl3` (§22).

**판정 기준은 만든 즉시 고장을 주입해 실제로 탈락하는지 확인한다.** 정상 빌드가 통과하는
것만 본 기준은 위약이다 — 이 프로젝트에서 그 함정을 여러 번 밟았고 전부 PLAN.md 에 남겼다.
누적 고장 주입 **85종**(PLAN.md 각 절의 합)을 전부 검출한다.

**판정기는 구현체를 믿지 않는다.** 성장 계수·격자 주기·포식 규칙 같은 규격 값을 `SPEC_*`
상수로 따로 들고 있다. 게임 값을 바꾸면 규격도 함께 고쳐야 하며, 그러지 않으면 판정이
오검출로 알려 준다(실제로 두 번 그랬다).

`PLAN.md` 는 주요 소스의 **전문**을 싣는다. 코드를 고쳤으면 문서의 사본도 맞춘다 —
손으로 지키다 열 블록 중 여덟이 어긋난 적이 있다(§24). 이제 기계가 대조한다.

```powershell
pwsh tools/sync_plan_blocks.ps1          # 대조 (어긋나면 exit 1)
pwsh tools/sync_plan_blocks.ps1 -Fix     # 문서를 파일에 맞춘다
```

## 웹 빌드

```powershell
& $GODOT --headless --path . --export-release "Web" build/index.html
```

스레드를 쓰지 않는 변형으로 내보내므로 `COOP`/`COEP` 헤더가 필요 없다 — 헤더 설정이
불가능한 정적 호스팅에서도 그대로 돈다.

### 브라우저에서 판정을 돌린다 (§24)

데스크톱 판정은 WASM·브라우저 합성을 재현하지 않는다. 익스포트본을 **실제 브라우저에서**
돌려 같은 판정을 받는다. 브라우저에는 명령줄이 없으므로 판정 이름은 쿼리로 준다
(`?judge=6` → `--judge6`).

```powershell
node tools/web_judge.mjs --expect --judge,--judge1b,--judge2,--judge3,--judge3b,--judge4,--judge5,--judge6
# 다른 터미널에서 (또는 브라우저를 직접) — 한 번만 띄우면 판정이 순서대로 이어진다
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --new-window http://127.0.0.1:8177/next
```

하네스는 판정 하나마다 시간 초과를 재고, **결과가 오지 않으면 `FAIL(무응답)`** 로 끝난다 —
페이지가 안 뜬 것을 "지적사항 없음" 으로 읽지 않는다. `--judge3c`(성능)는 브라우저가
`requestAnimationFrame` 으로 루프를 묶어 여유분을 잴 수 없으므로 **계측만** 하고 게이트로
쓰지 않는다(§24).

## 라이선스

코드는 이 저장소를 따른다. `assets/` 는 [Quaternius](https://quaternius.com) 의 CC0 에셋이며
각 팩의 `License.txt` 를 함께 두었다(`simplebuildings/`·`transport/` 두 팩은 원본 배포에
라이선스 파일이 없어 아직 비어 있다).
