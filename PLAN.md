# hole.io 클론 — 구현 계획 + 1a~4b 구현 · 플레이 재조정 · 도로 위계 · 물리적 림 · 한글 HUD · 브라우저 판정 · 지구제 도시 · 게임 UI · 교통 · 시민 · 카메라 멀미 · 흡입 게이트 (rev.29)

> **rev.23 = 브라우저에서 판정을 돌린다(§24).** 익스포트본을 **실제 Chrome 안에서** 돌려 판정 아홉 종을 전부 받았다(전부 PASS). 브라우저에는 명령줄이 없으므로 쿼리 문자열로 판정을 켜고, `console.log`를 감싸 결과를 하네스(`tools/web_judge.mjs`)로 되돌린다 — **결과가 오지 않으면 `FAIL(무응답)`이다.** 첫 실행이 판정기의 어긋남 둘을 드러냈다: H10의 기대값이 플랫폼의 함수가 아니었고, **C2는 §23이 걷어낸 크기 게이트 위에 서 있어 `main`이 이미 red였다.** 한글 HUD는 이제 육안이 아니라 WebGL2 프레임버퍼의 잉크 2515픽셀이 근거다.
>
> **rev.22 = 통과를 기하로 흉내내지 않는다(§23).** 구멍 둘레에 **물리적 바닥판(림)** 을 놓고 크기 게이트·통과 조건·§19 의 걸림 계수를 전부 지웠다. 무엇이 들어가고 무엇이 걸리는지는 물리가 정한다 — 차는 코부터 들어가고, 넓은 것은 림에 얹히며, 나무는 **수관 콜라이더**가 림에 걸린다. 플레이 피드백 셋(안 삼켜짐·걸림 부실·땅에서 녹음)이 한 뿌리였다.
>
> **rev.21 = 웹 렌더러 기계 판정 · 산포 반경 유도(§22).** `--rendering-driver opengl3` 로 판정 아홉 종을 **Compatibility 에서도 전부** 돌렸다(전부 PASS, 3c 는 2.7배 느리지만 예산의 32%). `plan_block` 의 산포 반경 8.5 를 사용 가능 구간에서 유도해 대로 인접 블록의 밀도 편향을 34% → 10% 로 줄였다(프롭 3804 → 3876).
>
> **rev.20 = 한글 HUD(§21).** 웹에는 시스템 폰트 폴백이 없어 rev.16 에서 영문으로 바꿔 두었던 HUD 를, Nanum Gothic 서브셋(70KB)을 번들해 되돌렸다. 4b 에 T8 신설 — 폰트 출처·글리프·한글 존재·잉크 넷을 함께 본다. **데스크톱은 시스템 폴백으로 그려 주므로 화면만 봐서는 이 결함을 못 잡는다.**
>
> **rev.19 = 판정 픽스처를 게임에서 걷어냈다(§20).** 노랑·파랑 큐브 8개가 시작 화면에 그대로 보였다. 지울 수는 없어(1b·2·3b·5의 시나리오가 그 위에 서 있다) **판정 모드에서만 스폰**하도록 옮겼다. 4b에 T7 신설 — 씬 파일과 게임 모드 재시작 양쪽을 본다.
>
> **rev.18 = 나무 흡입의 마찰감(§19).** §17이 나무 콜라이더를 밑동으로 바꾸면서 수관이 물리 모형에서 사라졌고, 유저 피드백은 정반대가 됐다(“너무 쉽게 삼켜진다”). 수관을 **데이터로** 되살려 통과 조건과 속력 상한에 건다. 판정 플래그가 **아홉 가지**가 됐다 — `--judge6` 신설(K1~K6), 3b에 E8 신설. 전부 PASS.
>
> **rev.16 = 플레이 재조정 2차(§17).** 1차에서 성장 속도·포식 판정·나무 콜라이더를, 2차에서 **시작 반경 5.0 → 1.5**·지면 448×448·카메라 최저 높이를 고쳤다. 판정 플래그는 여덟 가지이며 전부 PASS다: `--judge`(1a) / `--judge1b` / `--judge2` / `--judge3`(3a) / `--judge3b` / `--judge3c` / `--judge4` / `--judge5`.
>
> **rev.14에서 회귀가 잡은 것**: 4b의 `end_game()`이 모든 구멍의 물리를 멈추는데, 4a의 G4가 플레이어를 잃는 시나리오라 그 뒤 아레나가 얼어붙었다(`G7 path=15.1 dR=0.000`). 4b만 돌렸으면 못 봤을 결함이다 — 매번 판정 여덟 개를 전부 돌리는 이유다. `resume()`으로 해결(§16).
>
> rev.13에서 뒤집힌 것:
> 1. **§15 — 포식 규칙 교체.** "상대를 온전히 포함할 때 삼킨다"는 거의 성립하지 않아 자유 실행 900프레임에서 포식이 **0회**였다. hole.io 원작의 "중심 포함" 규칙으로 바꿨다.
> 2. **§15 — `growth_k` 함정을 2단계까지 소급해 고쳤다.** G2와 2단계 C1이 성장 계수를 구현체에서 읽고 있었다. 계수만 바꾼 빌드는 자기 값끼리 일치해 통과한다 — 판정기가 `SPEC_GROWTH_K`로 따로 들도록 고쳤고, 고장 주입으로 검출을 확인했다.
> 3. ~~§16 — 4b는 미착수다.~~ → rev.14에서 완료.
>
> rev.12에서 뒤집힌 것:
> 1. **§1-A — Downtown City MegaKit 폐기.** 실제로 내려받아 확인하니 rev.8이 적어 둔 "무텍스처 플랫 로우폴리"가 거짓이었다(4K PBR 텍스처 25장, 완성 건물 3동, 프롭 5종). Quaternius 클래식 팩 6종(OBJ, CC0, 76모델)으로 교체했다.
> 2. **§12 — H3 폐기.** rev.8이 "도로가 들어오면 정상 빌드가 탈락한다"고 예고한 그대로 12→12로 탈락했다. 대신 도시 지면 기준 D1~D5를 신설했다.
> 3. **§13 — `start_frozen` 의 근거 정정.** "고정하지 않으면 가늘고 높은 프롭이 넘어진다(실측)"고 적었으나 **거짓**이었다. 고장 주입으로 재 보니 180 물리 프레임 동안 최대 이동 0.9mm다. 최초 스크린샷의 원근 착시를 실측이라고 적은 것이다. 근거는 성능(§14의 6%)뿐이다.
> 4. **§14 — MultiMesh 최적화 폐기.** 로드맵에 있던 항목이지만 측정 결과 프레임 시간이 예산의 6%(0.99ms/16.67ms)여서 도입하지 않는다.
>
> **판정기가 두 번 위약이었다(§13).** 초안 E5는 콜라이더만 재서 "메시 피벗 보정 제거"를 통과시켰고, 물리를 한 프레임만 돌려 "정지 여부"를 시험조차 하지 않았다. 둘 다 고장 주입에서 드러났다.

> 계획 감사: rev.1 = 55 → rev.2 = 66 → rev.3 = 62/68 → rev.4 = 72/70 → rev.5 = 78 → rev.6 = **82/82 (합격)** → rev.7
> 코드 감사(1a 구현물): **90 (일치·품질 축, 합격) / 64 (고장 주입 축, 불합격)** → rev.8 = 본 문서
>
> **1a·1b·2·3a·3b·3c·4a·4b는 구현 완료 상태다 — 로드맵의 전 단계가 끝났다.** `project.godot` / `scenes` / `scripts` / `shaders` / `assets`가 이 문서와 함께 저장소에 있고, 이 문서의 모든 코드 블록은 그 파일들과 **바이트 단위로 동일**하다. 이 단언은 rev.16 이후 §17~§23에서 **열 블록 중 여덟이 어긋난 채로 방치돼 있었다**(§24에서 발견·복구). 이제 손이 아니라 `tools/sync_plan_blocks.ps1`이 대조한다.
>
> rev.7까지의 판정기는 고장 주입 감사에서 세 방향으로 무너졌다. rev.8은 그 결과다.
>
> | 감사가 찾은 결함 | rev.7 | rev.8 |
> |---|---|---|
> | **H8 무력화**: 하드 알파 + 접지 그림자 링을 함께 넣으면 통과(정상 3 vs 회귀 2로 구분 불가). §1이 계획한 도로 셰이더 경로에서 반드시 발생 | bbox 전체 / 한 스캔라인의 중간 톤 개수 | **32방향 × 국소 진폭 정규화.** 하드 알파는 어느 방향에서도 0 |
> | **두 번째 구멍을 아무도 안 본다**: 우물 없는 구멍을 옆에 뚫어도 통과 | `get_node("Hole")` 하나만 판정 | **레지스트리에 등록된 모든 구멍을 판정** |
> | **정상 빌드 탈락**: 구멍을 8만 옮겨도 H8 실패(0.0002 차), 800×600·`radius=12`도 실패 | 임계가 절대값 | **H7은 림 둘레 비례, H8은 방향 수 하한** |
> | **깊이 기준 부재**: 우물이 규정의 1/3 깊이여도 계측값이 정상과 4자리까지 동일 | 없음 | **H9**: `depth ≥ 2R·tan(앙각)` |
> | **작은 반경에서 진짜 이음새 누출**: `radius=1.0`에서 림 전체에 마젠타 프린지 | 배율만 사용 | **`wall_margin_min`**(절대 하한) 추가 |
> | 렌더러를 mobile 로 바꿔도 통과 / `flush()`에 해제 인스턴스 가드 없음 | — | **H10**(파이프라인 단언) / `is_instance_valid` 회수 + `_exit_tree` 해제 |
>
> **§0-E에 고장 주입 16종의 결과를 실었다.** 판정 기준을 만들 때마다 고장을 주입해 확인하는 것이 이 문서의 규칙이며, rev.5~rev.7에서 그 규칙을 세 번 어겨 매번 한 겹 안쪽에서 게이트가 뚫렸다.

- **엔진**: Godot 4.7.1 stable — 실행 파일:
  `C:\Users\bbum_ai\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`
  (winget alias는 비관리자 설치로 생성 실패 → 항상 전체 경로 사용)
- **렌더러**: Forward+ / Vulkan 1.4.325 / NVIDIA RTX 4060 Ti (실측)
- **물리**: Jolt — `project.godot`에 명시 필수
- **아트**: Quaternius (CC0), Downtown City MegaKit. 3단계 도입, 1단계는 프리미티브.

---

## §0. 실측 근거

### §0-A. 검증된 항목

| # | 항목 | 결과 |
|---|---|---|
| V1 | 손으로 쓴 `project.godot` + `[autoload]` | **동작** (`autoload_alive=true`) |
| V2 | `3d/physics_engine="Jolt Physics"` 키가 런타임에 **읽힌다** | **동작** |
| V3 | 손으로 쓴 `.tscn` (ext/sub_resource, Transform3D, Environment, `instance=ExtResource`) | **동작.** 에디터 불필요 |
| V3b | `.tscn`에 `rotation_degrees = Vector3(...)` 직접 기재 | **동작** (basis.x=(0.819,0,0.574)) |
| V4 | `uniform vec4 holes[16]`에 무타입 `Array`(Vector4 16개) 주입 | **동작** |
| V5 | 동일 uniform에 `PackedVector4Array` 주입 | **동작.** 위치·반경 변경이 화면에 반영(위양성 배제 — 구멍이 576px→725px 이동) |
| V5b | `shader.get_shader_uniform_list()`가 `holes`를 **`PackedVector4Array`(Variant type 38)** 로 선언 | **관측** |
| V6 | 월드 좌표 변환으로 구멍이 월드 공간에 매핑 | **동작.** 근거는 V5와 동일(구멍 이동)이며 독립 근거가 아니다 |
| V7 | `min(hole_count, 16)` 클램프 (`hole_count=20` 주입) | **동작.** 크래시·셰이더 에러 없음, 화면은 정상 프레임과 동일 |
| V11 | *(V21로 대체됨 — 육안 판단이던 "1.03이면 이음새가 없다"를 픽셀 카운트로 재측정했다)* |
| V12 | `CylinderMesh.cap_top=false`, `cull_mode=1` | 동작(§0-D 렌더 결과). **`cap_bottom`은 1a 카메라에서 렌더에 영향이 없다** — true/false의 출력 PNG가 SHA256까지 동일(§4-B) |
| V13 | `await RenderingServer.frame_post_draw` → `save_png` | err=0 |
| V14 | uniform 배열은 기본값을 가질 수 없다 | `SHADER ERROR: Setting default values to uniform arrays is not supported.` |
| V15 | `--check-only --script`: 정상 exit 0 / 파싱 오류 exit 1 | **종료 코드로 판정 가능** |
| V16 | `--check-only`는 **autoload 식별자를 해석하지 못한다** | `Compile Error: Identifier not found: HoleRegistry` → **위양성 exit 1** |
| V17 | `get_node("/root/HoleRegistry")` 접근은 `--check-only` 통과 (exit 0) | **동작** |
| V18 | `Shape3D.get_debug_mesh().get_aabb()` | 동작. `BoxShape3D(2,2,2)` → `P(-1,-1,-1) S(2,2,2)`, `xz_half_max=1.0000 / xz_diag_half=1.4142`. `CapsuleShape3D(r=0.7)` → `S(1.4,3.0,1.4)`, `xz_diag_half=0.9899` (**둥근 셰이프는 대각선 공식이 과대평가한다** — §4-D 참조) |
| V19 | `can_sleep = false` 설정만으로 잠든 RigidBody3D가 깨어난다 | **동작.** Jolt에서 31 physics frame 후 `sleeping=true` → `can_sleep=false` → 다음 프레임 `sleeping=false` |
| **V23** | **우물 벽 여유는 화면 공간 현상이다** | `radius=1.0` + 배율 1.03(월드 여유 0.03)에서 림 전체에 마젠타 프린지, `leak=9`. 절대 하한 0.15 를 두면 `leak=0`. R=5/12 에서도 0 |
| **V22** | **A2C + `depth_prepass_alpha` 머티리얼은 불투명 패스에 남는다 — 강한 간접 증거** | SSAO는 불투명 지오메트리에만 적용된다는 성질로 판별. SSAO ON/OFF 휘도차: 불투명 대조군 **0.1104**, 본 셰이더 **0.0791**, 확실한 알파 패스 대조군(`ALPHA=0.999`) **0.0039**. 알파 대조군의 20배지만 불투명 대조군의 72%이므로 **직접 관측이 아니라 추론**이다 |
| **V21** | **우물 반경 배율의 최소값** (배경을 마젠타로 두고 구멍 bbox 안의 배경 픽셀을 센 결과) | `1.000 → 97px`, `1.005 → 54`, `1.010 → 26`, **`1.020 → 0`**, `1.030 → 0`. 새는 것은 전부 AA 부분픽셀이며 통짜 틈(full leak)은 어느 배율에서도 0. **1.02가 최소, 1.03은 여유분** |
| **V20** | **자식 `_ready`의 `get_parent().set_process(false)`는 무효화된다** | `CHILD _ready parent.is_processing=false` → `PARENT _ready is_processing=true` → 1프레임 뒤에도 `true`. **엔진이 부모 `_ready` 직전에 되켠다** |

### §0-B. rev.3에서 강등·정정한 항목

| # | rev.3의 서술 | 정정 |
|---|---|---|
| V8 | "`discard`가 그림자 패스에 적용 — 태양광이 구멍을 통해 우물 벽을 비춘다" | **부분 사실, 크기 과장.** 지면 그림자가 우물 좌측 벽에 만드는 초승달은 프레임의 **0.14%(1046px)**, 최대 채널차 **0.09** |
| V9 | 지면 `cast_shadow = OFF` → "우물 내부 명암이 사라져 깊이감을 잃는다" | **거짓.** 우물의 N·L 그라디언트(중심행 dx −44에서 0.0627 → dx +37에서 0.1694)는 OFF에서도 거의 전부 보존된다. ON 유지는 옳지만 이유는 "공짜라서"이지 "깊이감 때문"이 아니다 |
| V10 | `alpha_to_coverage_and_one` → "우물 내부 명암이 죽는다" | **원인 오진.** 깊이 프리패스 미설정의 결과다. `depth_prepass_alpha`를 함께 켜면 내부 값이 `discard`와 소수점 4자리까지 동일하게 복원 → **A2C 채택으로 결론 전환(§2)** |

### §0-C. 셰이더 3종 비교 및 판정 기준 리허설

**(1) 지면 셰이더 3종, 동일 픽셀 측정** (`dx` = 구멍 중심 기준 픽셀 오프셋)

```
V d_discard   HOLE -44:0.0627 -37:0.0991 | RIM[508..519] 0.6393 0.6393 0.0627 ...   ← 중간 픽셀 없음(계단)
V a2c_plain   HOLE -44:0.0873 -37:0.1148 | RIM          0.6393 0.3418 0.0627 ...   ← 그림자 상실, 엣지 부드러움
V a2c_dpa     HOLE -44:0.0627 -37:0.0991 | RIM          0.6393 0.3418 0.0627 ...   ← 그림자 복원 + 엣지 부드러움
```

`a2c_dpa` = `render_mode cull_back, alpha_to_coverage_and_one, depth_prepass_alpha;` — §2의 결론 전환 근거.

**(2) 판정 기준 임계값 리허설** — 정상 1건, 붕괴 2건, 클램프 1건

| 케이스 | 구성 | H1 | H2 | H3 | H6 |
|---|---|---|---|---|---|
| A | 기준 프레임 (`hole_count=0`) | F | F | F | P |
| **B** | **정상** (구멍·우물 정렬) | **P** | **P** (Δ0.070) | **P** (4−2) | **P** (Δ0.064) |
| C | 구멍만 x=12로 이동, 우물은 원점 | P | **F** (Δ0.000) | P | **F** (Δ0.000) |
| D | 구멍 정상, 우물 노드 비표시 | P | **F** | P | **F** |
| E | `hole_count=20` (배열 16칸) | P | P | P | P (무크래시) |

rev.3의 기준으로는 C가 H1(0.142)·H3(+2)를 통과해 "성공"으로 판정되었다. C는 새까만 스티커 타원이 지면에 붙은, 1a의 목적과 정반대인 프레임이다. **붕괴를 실제로 탈락시키는 것은 H2와 H6뿐이다** — H1·H3는 C·D를 모두 통과시킨다. H1·H3는 필요조건으로만 쓴다.

**이 리허설이 검증한 범위는 임계값뿐이다.** 절차(기준 프레임 획득·게이팅·종료 코드)는 §0-D에서 별도로 검증했다. rev.4는 이 구분을 하지 않아 "전부 리허설 완료"라 적었고, 정확히 미검증 부분(절차)에서 실패했다.

**(3) H4 위약 확인**

```
J uniform_list = hole_count(type=2) holes(type=38) ground_color(type=20)
J typo_readback null=false size=16      ← 셰이더에 없는 이름 "holez" 를 주입했는데 되읽기 성공
```

`ShaderMaterial.get_shader_parameter()`는 **머티리얼 자신의 파라미터 캐시**를 되돌려줄 뿐 셰이더 uniform 목록을 조회하지 않는다. rev.3의 H4("non-null && size==16")는 이름 오타도 타입 불일치도 잡지 못하는 위약이었다.

### §0-D. 전(全) 파이프라인 실행 검증

**§3~§6의 명세대로 1a 프로젝트를 만들어 3단 검증을 끝까지 돌렸다.** 이 문서의 코드는 그 실행본이다.

```
=== 1단계: 파싱 (종료 코드) ===
  main EXIT=0   hole EXIT=0   hole_registry EXIT=0   screenshot EXIT=0
=== 2+3단계: 창 모드 실행 + 기계 판정 ===
  JUDGE EXIT=0            (SHADER ERROR / ERROR: 0건)
JUDGE saved res://shots/base.png err=0 hole_count=0
JUDGE saved res://shots/shot.png err=0 hole_count=1
JUDGE saved res://shots/probe.png err=0 hole_count=1
JUDGE hole0 px c=(576, 324) | lum c=0.1548 ring[0.0627..0.1694] g=0.6393 bg=0.0905 dRing=0.1067 dCB=0.0643 inside=true
JUDGE hole0 groups 2->4 | leak=0/3 rim_aa=18/32 depth=12.00/8.46
JUDGE hole0 H1=P H2=P H3=P H6=P H7=P H8=P H9=P -> PASS
JUDGE global H4=P H5=P H10=P clamped=false holes=1
JUDGE RESULT -> PASS
```

육안 확인도 통과: 원형 구멍, 우물 벽 좌우 명암, 매끄러운 엣지, 지면–우물 이음새 없음.

### §0-E. 고장 주입 검증 — 기준이 비정상을 실제로 탈락시키는가

정상 프레임을 통과시키는 것만으로는 게이트가 아니다. rev.5~rev.7이 매번 그것만 확인해 매번 뚫렸다. rev.8 기준으로 16종을 주입한 결과:

| 주입 | 결과 | 잡은 기준 | 계측 |
|---|---|---|---|
| *(정상 빌드)* | **PASS** | — | `leak=0/3 rim_aa=18/32 depth=12.00/8.46` |
| 하드 알파 (`ALPHA = d > 0.0 ? 1.0 : 0.0`) | FAIL | H8 | `rim_aa=0/32` |
| **하드 알파 + 접지 그림자 링** | **FAIL** | H8 | `rim_aa=0/32` — rev.7은 통과시켰다 |
| 접지 그림자 링만 (결함 없음) | **PASS** | — | `rim_aa=24/32` |
| `depth_ratio = 0.8` (바닥이 보임) | FAIL | H9 | `depth=4.00/8.46` |
| `wall_scale = 1.00` (이음새 누출) | FAIL | H7 | `leak=139/3` |
| 우물 `visible=false` | FAIL | H2·H6·H7 | `leak=8100/3` |
| **두 번째 구멍만 우물 없음** | **FAIL** | hole1의 H2·H6·H7 | `leak=3341/2` — rev.7은 보지도 않았다 |
| 두 구멍 모두 정상 (결함 없음) | **PASS** | — | hole0 `18/32`, hole1 `17/32` |
| `rendering_method = "mobile"` | FAIL | H10 | 구멍별 기준은 전부 P |
| `msaa_3d = 0` | FAIL | H8·H10 | `rim_aa=0/31` |
| `radius = 1.0` (결함 없음) | **PASS** | — | `leak=0/1` — rev.7은 실제 프린지로 탈락했다 |
| `radius = 12.0` (결함 없음) | **PASS** | — | `leak=0/8` — rev.7은 `leak=3`으로 오탈락 |
| 뷰포트 800×600 (결함 없음) | **PASS** | — | `rim_aa=16/32` — rev.7은 오탈락 |
| 구멍을 x=8로 이동 | FAIL | H2 | `RefBox(8,1,6)`가 구멍을 가린다(표본 0.4999 = 박스 휘도). 판정기 결함이 아니라 씬 배치 충돌 |
| 구멍을 x=20으로 이동 | FAIL | H2 | 링 진폭 0.0118 — 화면 가장자리에서 우물 명암 자체가 옅어진다. §6 "유효 전제"의 선언된 한계 |


---

## 전체 로드맵

| 단계 | 내용 | 상태 |
|---|---|---|
| 1a | 정지 구멍 착시 (구멍 + 우물 + 스케일 레퍼런스 박스) | **완료** — 3단 검증 PASS, 고장 주입 16종 검증(§0-E) |
| 1b | 구멍 이동 + 흡입 물리 + 카메라 추적 | **완료** — B1~B4 PASS, 고장 주입 4종 검증 |
| 2 | 성장 곡선, 크기별 흡입 판정, 스코어 | **완료** — C1~C4 PASS, 고장 주입 4종 검증 |
| 3a | 도로·보도·노면표시를 지면 셰이더에 통합 + 도시 격자 + 판정기 정비 | **완료** — D1~D6 PASS, 고장 주입 7종 검증(§12). 지면은 §17에서 448×448로 확대, 도로 위계는 §18 |
| 3b | Quaternius 에셋 임포트 + 절차적 도시 배치(건물·차량·가로시설물·녹지) | **완료** — E1~E8 PASS, 프롭 **3876개**(§22), 고장 주입 7종 검증(§13) |
| 3c | 성능 측정 → 필요하면 MultiMesh 인스턴싱 | **완료(측정 결과 최적화 불필요)** — 0.99ms/프레임, 예산의 6%(§14) |
| 4a | AI 경쟁 구멍 + 구멍끼리의 포식 | **완료** — G1~G7 PASS, 구멍 6개, 고장 주입 7종 검증(§15) |
| 4b | 타이머 · 순위 리더보드 · 승패 · 재시작 UI | **완료** — T1~T6 PASS, 고장 주입 8종 검증(§16) |

**1a/1b 분할 이유**: 착시(렌더링)와 이동·물리·카메라는 별개 작업이고, 착시가 성립하지 않으면 나머지가 무의미하다. **1a의 박스는 물리 없는 스케일 레퍼런스일 뿐이다** — 흡입은 1b에서 붙는다.

---

## §1. 아트 결정: Quaternius 단독 + 도로는 지면 셰이더에 통합

- **스타일**: 무텍스처 플랫 로우폴리 — hole.io 원작에 가깝다 (Kenney는 장난감 블록에 가깝다).
- **유료 팩(Synty 등) 미채택 이유**: 예산이 아니라 (a) 텍스처 아틀라스 기반 디테일 저폴리라 스타일 불일치, (b) 오브젝트 수백~수천 개 환경에서 정점·드로우콜 부담.
- **Kenney Roads 미채택 이유**: 도로가 별도 3D 메시로 지면 위에 얹히면 그 머티리얼에도 구멍 로직을 복제해야 하고, 두께가 있으면 구멍 가장자리에서 단면이 드러난다. **도로·인도·횡단보도는 지면 셰이더 안에서 그린다.**

### §1-A. rev.9에서 뒤집은 결정 — Downtown City MegaKit 폐기

rev.8까지 "Downtown City MegaKit(glTF) 단독"으로 적어 두었으나, **3단계 착수 시점에 실제로 내려받아 열어 보니 전제가 틀렸다.** Standard 판(223MB, itch.io, CC0)의 내용은 다음과 같다.

| rev.8의 전제 | 실측 |
|---|---|
| 무텍스처 플랫 로우폴리 | **거짓.** 4K PBR 텍스처 25장(BaseColor/Normal/ORM) — `T_RedBrick_Normal.png` 7.3MB, `T_Dirt_Normal.png` 9.7MB 등. 지면 셰이더가 그리는 평면 단색 위에 얹으면 톤이 정면충돌한다 |
| 도시 배치용 에셋 | **부분 사실.** 완성 건물은 3동(`Building_Small_1`/`Medium_2`/`Large_2`)뿐이고 나머지 ~150개는 벽·창·코니스 **모듈 조각**이라 조립 공정이 따로 필요하다 |
| 흡입 대상 확보 | **거짓.** 프롭은 `Prop_ACUnit`·`Bollard`·`Drain`·`ManholeCover`·`Planter_Single` 5종뿐. hole.io는 크기 사다리를 이루는 프롭 수백 개가 필요하다 |
| 도로 메시 필요 | **불필요.** `Street_*` 25종을 제공하지만 §1이 이미 도로를 지면 셰이더로 결정했으므로 전부 사장된다 |

**대체 결정: Quaternius 클래식 팩(OBJ + .mtl 단색 머티리얼).** 전부 CC0이고, `.mtl`이 텍스처 없이 `Kd` 단색만 담고 있어 원하던 플랫 로우폴리 그대로다(실측: `Taxi.mtl` = Black/Grey/Headlights/TailLights/… 6개 머티리얼, 텍스처 0장, `Taxi.obj` 146KB).

| 팩 | 모델 수 | 쓰임 |
|---|---|---|
| Cars | 7 | Taxi, SUV, Cop, SportsCar ×2, NormalCar ×2 — 중형 흡입 대상 |
| Buildings | 9 | Building1~4, House1~2 — 블록 채우기 |
| Simple Buildings | 10 | Bank, Flat, Hospital, Shop, House ×5 — 블록 채우기 |
| Modular Streets | 25 | Streetlight ×3, TrafficLight ×2, Sign ×3 — 소형~중형 가로 시설물 |
| Public Transport | 12 | TrafficCone, Bicycle, Bus, SchoolBus, Train, Ambulance — 크기 사다리의 양 끝 |
| Simple Nature | 13 | Tree ×4, Bush ×3, Rock ×3, Grass ×3 — 블록 녹지 |

**포맷 변경에 따른 재검토**: 이 팩들은 glTF를 제공하지 않고 OBJ/FBX/Blend만 있다. Godot 4는 `.obj`를 네이티브로 임포트하고 `.mtl`의 `Kd`를 읽으므로 **Blender는 여전히 불필요**하다. FBX는 `FBX2glTF` 외부 바이너리가 필요하므로 쓰지 않는다. → **3b 착수 시 OBJ 임포트가 실제로 머티리얼 색을 유지하는지가 첫 검증 항목이다.**

**입수 경로(검증됨)**: 클래식 팩은 itch.io가 아니라 Google Drive 공개 폴더에 있다. 폴더 열거는 `https://drive.google.com/embeddedfolderview?id=<folder>#list`(정적 HTML, 파일명+id 노출), 개별 파일은 `https://drive.usercontent.google.com/download?id=<id>&export=download`로 받는다. Drive API 키 불필요.

**지출 지점 철회**: Quaternius Patreon 후원(Downtown City MegaKit 전체 해금)은 더 이상 필요 없다 — 위 6개 팩은 전부 무료·CC0다.

---

## §2. 핵심 의사결정: 지면 셰이더 = 월드좌표 SDF + A2C + depth_prepass_alpha

### 2-1. 스텐실이 아니라 월드좌표 마스킹

| 항목 | 스텐실 (4.5+ `stencil_mode`) | 월드좌표 마스킹 |
|---|---|---|
| 구멍 모양 | 임의 | **원형만** |
| 구멍 개수 | 무제한 | uniform 배열 상한 (16) |
| 지면 셰이더가 구멍을 알아야 하나 | 아니오 | 예 (매 프레임 uniform 주입) |
| 구현 복잡도 | 중 (마스크 메시 + 렌더 순서) | **낮음** (지면 셰이더 단일) |

**채택 근거**: 이 게임의 구멍은 항상 정원이고 최대 8개(플레이어 1 + AI 7). 스텐실의 실익(임의 모양·무제한 개수)이 쓰이지 않는 반면, 지면 셰이더 하나로 도로까지 함께 처리하는 이점이 있다.

### 2-2. `discard`가 아니라 A2C + `depth_prepass_alpha` — rev.3에서 뒤집은 결정

| | `discard` | A2C + `depth_prepass_alpha` |
|---|---|---|
| 구멍 내부 명암 | 기준 | **동일** (0.0627 / 0.0991 — 소수점 4자리 일치) |
| 엣지 | 하드 전환, MSAA 무효 → 계단 | **중간 픽셀 존재**(0.3418), SDF 폭이 `fwidth`로 자동 조절 |
| depth prepass | **무효화** ([문서](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html): *"`discard` has a performance cost … prevent the depth prepass from being effective"*) | **유효** |
| 그림자 캐스팅 | 유지 | `depth_prepass_alpha` 없으면 상실 → 있으면 유지(실측) |

**감수하는 비용 — rev.4의 서술을 철회한다.** rev.4는 "알파 경로로 이동하므로 렌더 순서 이슈가 원리적으로 존재한다"고 적었으나 근거가 없었다. `depth_prepass_alpha`가 있으면 이 머티리얼은 깊이 프리패스와 그림자 캐스팅에 정상 참여하며(실측: 그림자 복원, 기준 프레임에서 지면이 그 아래 우물을 정상 차폐 → `base_groups=2`), **애초에 알파 렌더 리스트에 들어가지 않는다는 것이 V22로 확인됐다**(SSAO 응답이 알파 패스 대조군의 20배, 불투명 대조군과 같은 자릿수). **근거 없이 리스크를 적는 것은 근거 없이 안전을 적는 것과 같은 결함이므로 삭제한다.** 남는 위험은 3단계에서 진짜 반투명 오브젝트가 함께 놓일 때의 정렬뿐이며, 되돌리기 비용은 셰이더 1파일 교체다.

---

## §3. 1a 씬 명세

**구멍 반경 SSOT**: `hole.gd`의 `@export var radius := 5.0`이 유일한 정의다. 우물의 **반경**(`wall_scale`), **깊이**(`depth_ratio`), 1b의 Area3D 반경은 **모두 `_ready()`에서 이 값으로부터 계산해 대입**한다. `hole.tscn`의 `top_radius = 5.15`(=5.0×1.03)와 `height = 12.0`(=5.0×2.4)은 **에디터 표시용 초기값일 뿐** SSOT가 아니며, 런타임에 전부 덮어쓰인다.

| 노드 | 타입 | 비고 |
|---|---|---|
| `Main` | Node3D | `main.gd` |
| `WorldEnvironment` | WorldEnvironment | **`ambient_light_color`를 반드시 명시** — Godot 기본값은 검정이고, 누락하면 지면 휘도가 0.6393→0.5474로 떨어져 §6 임계값이 재현되지 않는다 |
| `Camera3D` | Camera3D | origin `(0, 22, 26)`. `look_at`은 `main.gd._ready()`에서. **`fov`/`near`/`far`를 기본값과 동일하게 명시**(75 / 0.05 / 4000) — §6 판정이 전부 `unproject_position` 의존이라 투영을 엔진 기본값에 암묵 의존하면 안 된다 |
| `Sun` | DirectionalLight3D | `rotation_degrees=(-55,-35,0)` — `.tscn` 직접 기재로 충분(V3b) |
| `Ground` | MeshInstance3D | **`surface_material_override/0`** 로 붙인다. `material_override`를 쓰면 `get_surface_override_material(0)`이 `null`을 반환해 `flush()`가 조용히 빠져나가고 **구멍이 아예 안 뚫린다** |
| `GroundBody` | StaticBody3D + CollisionShape3D | `BoxShape3D` 60×1×60, y=−0.5. **1a에서는 사용되지 않으며 1b 대비 선배치**. `WorldBoundaryShape3D`는 Jolt에서 유한 크기라 쓰지 않는다 |
| `Hole` | `hole.tscn` 인스턴스 | 원점 |
| `RefBox` | MeshInstance3D | `(8,1,6)`. **`StandardMaterial3D` sub_resource가 필요하다** — `albedo_color`는 MeshInstance3D의 프로퍼티가 아니다. 물리 없음 |
| `Judge` | Node | `screenshot.gd`. **루트가 아니라 자식이다** — 루트에는 `main.gd`가 있고 한 노드에 스크립트는 하나다 |

`RefBox` 위치 `(8,1,6)`은 지면 표본 `(-16,0,8)`의 반대편이라 표본이 박스나 그 그림자에 가리지 않는다. 배경색은 §6 H6이 "구멍 아래로 새는 배경"을 검출하는 기준이므로 어둡게 고정한다(배경 휘도 실측 0.0905).

### `scenes/main.tscn` (전문 — 실행 검증본)

```
[gd_scene load_steps=16 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]
[ext_resource type="Shader" path="res://shaders/ground_hole.gdshader" id="2"]
[ext_resource type="PackedScene" path="res://scenes/hole.tscn" id="3"]
[ext_resource type="Script" path="res://scripts/screenshot.gd" id="4"]
[ext_resource type="Script" path="res://scripts/camera_rig.gd" id="5"]
[ext_resource type="PackedScene" path="res://scenes/swallowable.tscn" id="6"]
[ext_resource type="PackedScene" path="res://scenes/swallowable_big.tscn" id="7"]
[ext_resource type="Script" path="res://scripts/city.gd" id="8"]
[ext_resource type="FontFile" uid="uid://b3x3lllwaes5u" path="res://assets/fonts/hud_kr.ttf" id="9"]
[ext_resource type="Script" path="res://scripts/ui.gd" id="10"]
[ext_resource type="Script" path="res://scripts/traffic.gd" id="11"]
[ext_resource type="Script" path="res://scripts/citizens.gd" id="12"]

[sub_resource type="Environment" id="Env_1"]
background_mode = 1
background_color = Color(0.08, 0.09, 0.13, 1)
ambient_light_source = 2
ambient_light_color = Color(1, 1, 1, 1)
ambient_light_energy = 0.35

[sub_resource type="PlaneMesh" id="Plane_1"]
size = Vector2(448, 448)

[sub_resource type="ShaderMaterial" id="MatG_1"]
shader = ExtResource("2")

[sub_resource type="BoxShape3D" id="Shape_1"]
size = Vector3(448, 1, 448)


[node name="Main" type="Node3D"]
script = ExtResource("1")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_1")

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 22, 26)
fov = 75.0
near = 0.05
far = 4000.0
script = ExtResource("5")

[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-55, -35, 0)
shadow_enabled = true

[node name="Ground" type="MeshInstance3D" parent="."]
mesh = SubResource("Plane_1")
surface_material_override/0 = SubResource("MatG_1")

[node name="GroundBody" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
collision_layer = 1
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="GroundBody"]
shape = SubResource("Shape_1")

[node name="Hole" parent="." instance=ExtResource("3")]

[node name="Swallowables" type="Node3D" parent="."]

[node name="City" type="Node3D" parent="."]
script = ExtResource("8")

[node name="Citizens" type="Node3D" parent="."]
script = ExtResource("12")

[node name="Traffic" type="Node3D" parent="."]
script = ExtResource("11")

[node name="Judge" type="Node" parent="."]
script = ExtResource("4")

[node name="UI" type="CanvasLayer" parent="."]
script = ExtResource("10")

[node name="HUD" type="CanvasLayer" parent="."]

[node name="Label" type="Label" parent="HUD"]
theme_override_fonts/font = ExtResource("9")
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 14.0
offset_top = -44.0
offset_right = 460.0
offset_bottom = -12.0

[node name="Timer" type="Label" parent="HUD"]
theme_override_fonts/font = ExtResource("9")
anchor_left = 0.5
anchor_right = 0.5
offset_left = -80.0
offset_top = 10.0
offset_right = 80.0
offset_bottom = 42.0
horizontal_alignment = 1

[node name="Board" type="Label" parent="HUD"]
theme_override_fonts/font = ExtResource("9")
anchor_left = 1.0
anchor_right = 1.0
offset_left = -230.0
offset_top = 10.0
offset_right = -12.0
offset_bottom = 210.0

[node name="Over" type="Label" parent="HUD"]
theme_override_fonts/font = ExtResource("9")
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -260.0
offset_top = -60.0
offset_right = 260.0
offset_bottom = 60.0
horizontal_alignment = 1
vertical_alignment = 1
visible = false
```

- `load_steps` = ext_resource 수 + sub_resource 수 + 1 (= 4 + 6 + 1).
- **다른 씬을 인스턴스로 붙이는 문법**: `[node name="Hole" parent="." instance=ExtResource("3")]` — `type=`을 쓰지 않는다.

### `scenes/hole.tscn` (전문 — 실행 검증본)

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/hole.gd" id="1"]

[sub_resource type="CylinderMesh" id="Cyl_1"]
resource_local_to_scene = true
top_radius = 5.15
bottom_radius = 5.15
height = 12.0
radial_segments = 48
cap_top = false
cap_bottom = true

[sub_resource type="StandardMaterial3D" id="MatW_1"]
cull_mode = 1
albedo_color = Color(0.16, 0.12, 0.1, 1)
roughness = 1.0

[sub_resource type="CylinderShape3D" id="Sh_1"]
resource_local_to_scene = true
radius = 5.0
height = 8.0

[sub_resource type="ConcavePolygonShape3D" id="Rim_1"]
resource_local_to_scene = true

[node name="Hole" type="Node3D"]
script = ExtResource("1")

[node name="Well" type="MeshInstance3D" parent="."]
mesh = SubResource("Cyl_1")
surface_material_override/0 = SubResource("MatW_1")

[node name="Area" type="Area3D" parent="."]
collision_layer = 0
collision_mask = 2
monitoring = true

[node name="Shape" type="CollisionShape3D" parent="Area"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, 0)
shape = SubResource("Sh_1")

[node name="Rim" type="StaticBody3D" parent="."]
collision_layer = 8
collision_mask = 0

[node name="Shape" type="CollisionShape3D" parent="Rim"]
shape = SubResource("Rim_1")
```

- **`resource_local_to_scene = true`는 이중 방어다** — 단독 필수 조건이 아니다. 4조합을 실측했다(반경 5.0/2.0 인스턴스 2개, `want 5.150`):

  | 구성 | 인스턴스1 | 인스턴스2 | 리소스 공유 |
  |---|---|---|---|
  | `local_to_scene` + `duplicate()` | 5.150 ✔ | 2.060 | false |
  | `local_to_scene` 만 | 5.150 ✔ | 2.060 | false |
  | **`duplicate()` 만** | **5.150 ✔** | 2.060 | false |
  | 둘 다 없음 | **2.060 ✘** | 2.060 | **true** |

  `hole.gd`가 `well.mesh.duplicate()`로 **새 메시를 대입**하므로 공유 리소스를 애초에 건드리지 않는다 — `duplicate()` 단독으로 완결이다. rev.5의 "없으면 덮어쓰인다"는 서술은 거짓이었다. 둘 다 거는 이유는 `hole.gd`의 `duplicate()`가 미래에 제거될 경우를 대비한 이중 방어이며, 비용은 홀 하나당 버려지는 `CylinderMesh` 사본 1개다.
- **`Area3D`/`CollisionShape3D`는 1a에 넣지 않는다** — 1a에는 물리가 없다. 1b에서 `Hole` 아래에 추가한다(§4-C).

---

## §4. 구성 요소

### A. 지면 셰이더 — `shaders/ground_hole.gdshader` (전문)

```glsl
shader_type spatial;
render_mode cull_back, alpha_to_coverage_and_one, depth_prepass_alpha;

uniform int hole_count = 0;
uniform vec4 holes[16];   // xyz = 월드 중심, w = 반지름

// --- 3단계 도시 격자 규격 -------------------------------------------------
// 도로·보도·노면표시는 별도 메시가 아니라 이 셰이더 안에서 그린다(§1).
// 별도 메시로 얹으면 그 머티리얼에도 구멍 SDF 를 복제해야 하고, 두께가 있으면
// 구멍 가장자리에서 단면이 드러난다. 여기서 그리면 ALPHA 하나가 전부를 뚫는다.
// screenshot.gd 는 이 uniform 을 읽지 않고 같은 수를 SPEC_* 로 따로 들고 있다.
uniform float block_pitch = 32.0;   // 도로 중심선 간격
uniform float road_half   = 4.0;    // 일반 도로 아스팔트 반폭
uniform float curb_half   = 6.0;    // 일반 도로 보도 바깥 경계 반폭
uniform float lane_half   = 0.30;   // 중앙선 반폭 (60cm — 실제 도로보다 굵다.
                                    // 게임 카메라 거리에서 판독되려면 이 정도가 필요하다:
                                    // 0.18 에서는 블록 하나 건너면 화면 2.3px 로 뭉갠다)
uniform float cross_w     = 1.6;    // 교차로 바깥 횡단보도 띠 폭
uniform float cross_pitch = 1.2;    // 횡단보도 줄무늬 주기

// --- 도로 위계 (§18) -------------------------------------------------------
// 균질한 격자는 "도로가 너무 격자" 로 읽힌다(플레이 피드백 4). boul_every 번째
// 중심선을 대로로 승격시켜 아스팔트 반폭을 **선 인덱스의 함수**로 만든다.
// 보도 폭(curb_half - road_half)은 위계와 무관하게 일정하다 — 대로만 넓어진다.
uniform float boul_every  = 3.0;    // 몇 번째 중심선마다 대로인가 (k mod 3 == 0)
uniform float boul_half   = 6.5;    // 대로 아스팔트 반폭
uniform float lane_gap    = 0.75;   // 대로 이중 중앙선의 중심 오프셋.
                                    // 선 반폭 0.30 이므로 두 줄 사이 빈 간격은 0.9 다

uniform vec3 road_color   : source_color = vec3(0.36, 0.37, 0.40);
uniform vec3 curb_color   : source_color = vec3(0.72, 0.72, 0.70);
uniform vec3 lane_color   : source_color = vec3(0.88, 0.80, 0.25);
uniform vec3 cross_color  : source_color = vec3(0.90, 0.90, 0.87);

// --- 지구제·수계 (§25) -----------------------------------------------------
// 존 지도는 city.gd 가 구운 14x14 R8 텍스처 하나가 원천이다. 셀당 zone_code*51 이
// 들어 있고 51/255 = 0.2 간격이라 복호가 8비트 양자화·필터 오차에 견고하다.
// **판정기는 이 텍스처를 읽지 않는다** — 자기 사본을 들고 같은 지도를 독립으로 계산한다.
uniform sampler2D zone_tex : filter_nearest, repeat_disable;
uniform float ground_half = 224.0;

// 존별 지면색. 휘도는 전부 [아스팔트 0.37 + 여유, 커브 0.72 - 여유] 안에 둔다 —
// 벗어나면 D1(인접 표면 휘도차)·D4(우물보다 밝다)가 무너진다. 아래 값은 렌더 후에도
// 어느 채널도 1.0 에 붙지 않도록 낮춰 잡았다(클리핑되면 채널 차가 뭉개져 Z1 이 흐려진다).
uniform vec3 zone_d_color : source_color = vec3(0.46, 0.44, 0.42);   // 도심: 무채색 콘크리트
uniform vec3 zone_c_color : source_color = vec3(0.47, 0.53, 0.38);   // 상업: 약한 녹조
uniform vec3 zone_r_color : source_color = vec3(0.39, 0.58, 0.31);   // 주거: 잔디
uniform vec3 zone_p_color : source_color = vec3(0.26, 0.55, 0.19);   // 공원: 짙은 녹지
uniform vec3 water_color  : source_color = vec3(0.13, 0.28, 0.47);   // 강
uniform vec3 ocean_color  : source_color = vec3(0.08, 0.19, 0.36);   // 지도 테두리 바다
uniform vec3 bank_color   : source_color = vec3(0.62, 0.58, 0.42);   // 기슭
uniform float bank_w = 2.4;

// 존 지도의 규격 상수. city.gd 의 CELL_MIN·CELL_COUNT·ZONE_TEX_STEP 과 같은 값이다.
const int ZMIN = -7;
const int ZN = 14;
const float ZSTEP = 51.0;
const int Z_D = 0;
const int Z_C = 1;
const int Z_R = 2;
const int Z_P = 3;
const int Z_W = 4;

int zone_at(int k, int j) {
	ivec2 t = ivec2(clamp(k - ZMIN, 0, ZN - 1), clamp(j - ZMIN, 0, ZN - 1));
	return int(texelFetch(zone_tex, t, 0).r * 255.0 / ZSTEP + 0.5);
}

// 교량. city.gd 의 BRIDGES 와 **같은 집합**이어야 한다 — 여기만 고치면 도로는 그려지는데
// 구멍이 못 지나가고, 저기만 고치면 그 반대가 된다. 강이 열 k=2 라 셀 인덱스는 2 다.
bool is_bridge_ew(int jl, int kc) {
	return kc == 2 && (jl == -3 || jl == 0 || jl == 3);
}

// 도로 세그먼트가 존재하는가. city.gd 의 seg_rule 과 같은 규칙이다.
float seg_rule(int a, int b, bool bridge) {
	if (a == Z_W || b == Z_W) { return bridge ? 1.0 : 0.0; }
	return (a == Z_P && b == Z_P) ? 0.0 : 1.0;
}
float seg_ew(int jl, int kc) {
	return seg_rule(zone_at(kc, jl - 1), zone_at(kc, jl), is_bridge_ew(jl, kc));
}
float seg_ns(int kl, int jc) {
	return seg_rule(zone_at(kl - 1, jc), zone_at(kl, jc), false);
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 경계를 화면 1픽셀 폭으로 부드럽게 만든다. MSAA 는 지오메트리 엣지만 덮으므로
// 절차적 색 경계는 여기서 직접 AA 하지 않으면 원거리에서 지글거린다.
// 폭을 fwidth(abs(u)) 가 아니라 fwidth(u) 로 재는 이유: abs 의 꺾임점(u=0)에서
// fwidth 가 튀어 중앙선 자리에 1픽셀 얼룩이 생긴다.
float aa_band(float u, float edge) {
	float w = max(fwidth(u), 1e-6);
	// 화면 미분이 특징 폭에 근접하면 그 특징은 서브픽셀이 되어 지글거린다.
	// aa_band 의 전이폭이 edge 를 넘어서면 띠가 화면 전체를 덮어 버리므로,
	// 그 전에 특징 자체를 걷어낸다(밉맵의 수동 구현에 해당).
	float fade = 1.0 - smoothstep(0.35 * edge, 1.0 * edge, w);
	return (1.0 - smoothstep(-w, w, abs(u) - edge)) * fade;
}

// 중심선 인덱스 k 가 대로인가 (1.0 = 대로). GLSL 의 mod 는 음수 인덱스에서도
// [0, n) 을 돌려주므로 k = -3, -6 도 0 이 되어 GDScript 의 posmod 와 **같은 집합**
// {…, -6, -3, 0, 3, 6, …} 을 만든다. 이 일치가 규격의 전제다.
float boulevard(float k) {
	return 1.0 - step(0.5, mod(k, boul_every));
}

void fragment() {
	vec2 p = world_pos.xz;
	float hp = block_pitch * 0.5;
	// 가장 가까운 도로 중심선의 **인덱스**와 그 선까지의 부호 있는 거리.
	// ux 는 남북 도로(x = kx*pitch), uz 는 동서 도로(z = kz*pitch) 기준이다.
	// ux = p.x - kx*pitch 는 옛 mod(p.x + hp, pitch) - hp 와 항등이다(음수 좌표 포함):
	//   mod(a, P) - hp = a - P*floor(a/P) - hp,  a = p.x + hp  →  p.x - P*floor((p.x+hp)/P)
	// 인덱스를 따로 꺼내는 이유는 반폭이 그 함수이기 때문이다.
	// kx 는 floor 라 블록 경계 쿼드에서 픽셀마다 달라지고 그때 fwidth(ux) 가 pitch 만큼
	// 튄다. 그 지점은 |ux| ≈ 16 이라 어떤 띠(최대 curb 8.5)에서도 멀어 무해하다 —
	// 옛 mod 식도 같은 성질이었다.
	float kx = floor((p.x + hp) / block_pitch);
	float kz = floor((p.y + hp) / block_pitch);
	float ux = p.x - kx * block_pitch;
	float uz = p.y - kz * block_pitch;

	// 위계. 보도 폭은 두 등급이 공유한다.
	float walk_w = curb_half - road_half;
	float bx = boulevard(kx);
	float bz = boulevard(kz);
	float rx = mix(road_half, boul_half, bx);
	float rz = mix(road_half, boul_half, bz);
	float cx = rx + walk_w;
	float cz = rz + walk_w;

	// --- 지구 지면색과 수계 (§25) -----------------------------------------
	// 프래그먼트를 **품는 셀**(중심선이 아니라 칸)의 존이 지면색을 정한다.
	int kc = int(floor(p.x / block_pitch));
	int jc = int(floor(p.y / block_pitch));
	int zc = zone_at(kc, jc);

	vec3 base;
	if (zc == Z_W) {
		// 기슭 띠는 **물 쪽에만** 그린다. 그러면 육지 픽셀(지도의 대부분)은
		// 이 네 번의 texelFetch 를 아예 건너뛴다.
		float ex = p.x - float(kc) * block_pitch;
		float ez = p.y - float(jc) * block_pitch;
		float bank = 0.0;
		if (zone_at(kc - 1, jc) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, ex)); }
		if (zone_at(kc + 1, jc) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, block_pitch - ex)); }
		if (zone_at(kc, jc - 1) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, ez)); }
		if (zone_at(kc, jc + 1) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, block_pitch - ez)); }
		// 지도 가장자리로 갈수록 깊어진다 — 강과 바다를 한 장의 지도로 잇는다.
		float deep = smoothstep(0.72, 1.0, max(abs(p.x), abs(p.y)) / ground_half);
		base = mix(mix(water_color, ocean_color, deep), bank_color, bank);
	} else if (zc == Z_D) {
		base = zone_d_color;
	} else if (zc == Z_C) {
		base = zone_c_color;
	} else if (zc == Z_R) {
		base = zone_r_color;
	} else {
		base = zone_p_color;
	}

	// 도로 마스크. 남북 도로는 자기가 걸친 z-셀로, 동서 도로는 x-셀로 존재를 묻는다.
	// 마스크가 0 인 자리에서는 아스팔트·보도·중앙선·횡단보도가 전부 사라지고
	// 그 자리의 존 지면색이 그대로 드러난다.
	float ens = seg_ns(int(kx), jc);
	float enw = seg_ew(int(kz), kc);

	vec3 col = base;
	col = mix(col, curb_color, max(aa_band(ux, cx) * ens, aa_band(uz, cz) * enw));
	col = mix(col, road_color, max(aa_band(ux, rx) * ens, aa_band(uz, rz) * enw));

	// 중앙선은 도로 중심선 위에 그리되 교차로에서는 끊는다.
	// 대로는 한 줄이 아니라 ±lane_gap 두 줄이다. abs(ux) 를 aa_band 에 넘기면 그
	// 꺾임점(= 대로 한가운데)에서 fwidth 가 튀어 1픽셀 얼룩이 생긴다 — 부호 있는
	// 인자 두 개의 max 로 푼다. aa_band 주석의 경고와 같은 이유다.
	// 한쪽 도로가 없으면 교차로도 없다(inter=0) — 남은 도로의 중앙선이 이어져야 한다.
	float inter = step(abs(ux), rx) * step(abs(uz), rz) * ens * enw;
	float lx = mix(aa_band(ux, lane_half),
		max(aa_band(ux - lane_gap, lane_half), aa_band(ux + lane_gap, lane_half)), bx) * ens;
	float lz = mix(aa_band(uz, lane_half),
		max(aa_band(uz - lane_gap, lane_half), aa_band(uz + lane_gap, lane_half)), bz) * enw;
	col = mix(col, lane_color, max(lx, lz) * (1.0 - inter));

	// 횡단보도: 교차로 바로 바깥의 도로 위 줄무늬. 중앙선 위에 덮인다.
	// 축이 섞인다 — "자기 도로 안(자기 축의 반폭)" × "교차로 밖~띠 안(교차 축의 반폭)".
	// 띠는 보도를 넘지 않는다: 대로 [6.5, 8.1] < 8.5, 일반 [4.0, 5.6] < 6.0.
	// 건널 상대가 없으면(교차 도로가 걷혔으면) 횡단보도도 그리지 않는다 — ens*enw.
	float cw_x = step(abs(ux), rx)
		* step(rz, abs(uz)) * step(abs(uz), rz + cross_w) * ens * enw;
	float cw_z = step(abs(uz), rz)
		* step(rx, abs(ux)) * step(abs(ux), rx + cross_w) * ens * enw;
	float cw_fade = 1.0 - smoothstep(0.15 * cross_pitch, 0.5 * cross_pitch,
		max(fwidth(p.x), fwidth(p.y)));
	float stripe = cw_x * step(fract(p.x / cross_pitch), 0.55)
		+ cw_z * step(fract(p.y / cross_pitch), 0.55);
	col = mix(col, cross_color, clamp(stripe, 0.0, 1.0) * cw_fade);

	int n = min(hole_count, 16);          // V7: 배열 범위 밖 인덱스 방지
	float d = 1e9;
	for (int i = 0; i < n; i++) {
		d = min(d, distance(p, holes[i].xz) - holes[i].w);
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	ALPHA = clamp(d / max(fwidth(d), 1e-6), 0.0, 1.0);   // 부호거리 → 1픽셀 폭 AA
}
```

- **월드 좌표는 `vertex()`에서 varying으로 넘긴다.** `fragment()`에서 `INV_VIEW_MATRIX * vec4(VERTEX,1.0)`도 정확하지만(fragment의 `VERTEX`는 뷰 공간) 픽셀마다 mat4 곱이 든다. 지면은 화면을 넓게 덮으므로 정점당 계산으로 옮긴다.
- **알파는 이진값이 아니라 부호거리를 화면 미분으로 나눈 값**이다. 이것이 A2C가 커버리지를 계산할 재료이며, 하드 `step()`을 쓰면 A2C의 이점이 사라진다.
- uniform 배열은 **기본값을 가질 수 없다**(V14). `hole_count`는 스칼라라 기본값 허용.
- **주입 타입**: 엔진이 `holes`를 `PackedVector4Array`로 선언하므로(V5b) 이를 1순위로 쓴다. 무타입 `Array`도 동작하지만(V4) 엔진 선언 타입과 어긋난다.
- **내용만 바꾸면 GPU에 반영되지 않는다 — 매번 `set_shader_parameter`를 다시 호출해야 한다.** (버퍼를 멤버로 두는 것은 `PackedVector4Array`가 값 타입이라 호출마다 어차피 복사되므로 할당 회피 효과가 크지 않다. 코드 단순성 때문에 유지한다.)

### B. 우물 — `scripts/hole.gd` (전문). 우물 메시는 `scenes/hole.tscn` 의 `Well` 노드다

```gdscript
extends Node3D

const CITY := preload("res://scripts/city.gd")

## 구멍 반경의 단일 진실 원천(SSOT). 우물의 반경과 깊이가 모두 여기서 파생된다.
## 시작값 1.5 — 크기 게이트(R × 0.45 = 0.675)가 트래픽콘·덤불·표지판만 열어 준다.
## 5.0 은 시작부터 나무가 걸림 없이 삼켜지고 90초에 지도를 비웠다(플레이 피드백).
@export var radius := 1.5
## 우물 벽 반경 배율. 1.02 가 이음새가 닫히는 최소값(V21), 1.03 은 여유분.
@export var wall_scale := 1.03
## 우물 벽 여유의 절대 하한(월드 단위). 배율만 쓰면 작은 반경에서 여유가
## 서브픽셀로 줄어 이음새가 샌다(V23: radius 1.0 에서 림 전체에 마젠타 프린지).
@export var wall_margin_min := 0.15
## 우물 깊이 = radius * depth_ratio. 5.0 * 2.4 = 12.0 (실측 구성과 동일).
## 근측 림 시선이 바닥에 닿지 않으려면 depth >= 2R*tan(카메라 앙각) 이어야 한다(H9).
@export var depth_ratio := 2.4
## 흡입력(중심 방향). 가장자리에서 덜덜 떨다 빨려드는 느낌을 만든다.
@export var suction := 26.0
## 낙하 오브젝트를 소멸시키는 깊이 = well_depth * kill_ratio.
@export var kill_ratio := 0.8
## AI 목표 선정용 상한(§23). 흡입을 막는 게이트가 **아니다** — 무엇이 들어가는지는
## 이제 물리가 정한다. AI 가 자기보다 큰 것을 쫓느라 굳지 않게 하는 조언일 뿐이다.
## 척도는 물체의 **좁은 쪽 반폭**(fit_radius)이다: 원형 구멍을 통과하는 데 필요한
## 것은 대각선이 아니라 좁은 쪽이다(실측: 택시는 외접반경 2.27 이지만 폭은 0.85).
@export var swallow_ratio := 0.9
## 림 바닥판의 바깥 반경 = radius + 이 값. 구멍 둘레에서 지면을 대신하는 판이므로,
## 감지 범위에 걸친 가장 큰 프롭(반extent 8.2)을 덮고도 남아야 한다.
@export var rim_outer := 30.0
## 림 바닥판의 분할 수. 48 은 우물 메시(radial_segments 48)와 같은 값이라
## 물리 경계와 그려지는 림이 어긋나 보이지 않는다.
@export var rim_segments := 48
## 이 깊이보다 내려가면 "구멍에 빠졌다" 로 본다. 지면 아래로 확실히 내려간 값이어야
## 한다 — 0 으로 두면 림 위에서 덜컹이는 것도 낙하로 오인한다.
@export var fall_depth := 0.6

## 성장: 면적 보존 법칙. R' = sqrt(R^2 + growth_k * r^2)
## 1.0 = 삼킨 단면적을 **그대로** 더한다(순수 면적 보존). 4.0 은 체감이 너무 빨랐다.
@export var growth_k := 1.0
## 지면 반폭. move_to() 가 구멍을 지면 안에 붙잡아 두는 데 쓴다.
## main.gd 가 스폰 시 GROUND_HALF 를 넣어 준다 — 값의 진실 원천은 거기 하나다.
@export var ground_half := 224.0
## 다른 구멍을 삼키려면 이 배수만큼 커야 한다. 동률에서 서로 삼키는 것을 막는다.
@export var hole_bite_ratio := 1.05
## 상대가 이 비율만큼 내 원반 안으로 들어와야 삼킨다(0 = 중심만, 1 = 온전히 포함).
## 중심 포함(0)은 서로 반쯤 걸친 상태에서 죽어 "접촉만 해도 사망" 으로 읽힌다.
@export var bite_depth := 0.8
## 리더보드 표시용 이름.
@export var label := "P"

## 이 구멍이 벌어들인 점수와 삼킨 개수. 4단계의 리더보드가 구멍별로 읽는다.
var score := 0
var swallowed_count := 0

signal swallowed(node: Node3D)
signal grew(from_radius: float, to_radius: float)

@onready var well: MeshInstance3D = $Well
@onready var area: Area3D = $Area
@onready var area_shape: CollisionShape3D = $Area/Shape
## §23. 구멍 둘레의 **물리적 바닥판**(가운데가 뚫린 원판). 감지 범위에 들어온
## 오브젝트는 지면 대신 이것을 딛는다 — 구멍 위에는 바닥이 없으므로 물체가
## 스스로 기울고 빠진다. 통과 조건을 기하로 흉내내지 않는 이유가 이것이다.
@onready var rim_shape: CollisionShape3D = $Rim/Shape

## Area3D 안에 있으나 아직 통과 조건을 만족하지 못한 후보.
var _candidates: Array[RigidBody3D] = []
## 통과 조건을 만족해 레이어를 전환한 낙하 중 오브젝트.
var _falling: Array[RigidBody3D] = []


func _ready() -> void:
	# 공유 sub_resource 를 건드리지 않도록 한 번만 복제해 두고 이후로는 값만 바꾼다.
	well.mesh = well.mesh.duplicate()
	area_shape.shape = area_shape.shape.duplicate()
	rebuild()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


## 반경이 바뀔 때마다 우물 메시·Area3D 셰이프를 SSOT 에서 다시 파생시킨다.
## 하나라도 빠뜨리면 착시가 깨지거나(H7) 감지 범위가 어긋난다.
func rebuild() -> void:
	var m: CylinderMesh = well.mesh
	m.top_radius = wall_radius()
	m.bottom_radius = wall_radius()
	m.height = well_depth()
	well.position.y = -m.height * 0.5     # 상단이 지면 y=0 에 일치

	# 반경 R 짜리 구를 지면 높이에 두면 지면 위에 얹힌 박스(중심 y>0)를 놓치므로
	# 세로로 긴 원기둥을 쓴다. 치수도 전부 SSOT 파생이다.
	var s: CylinderShape3D = area_shape.shape
	s.radius = radius
	s.height = radius * 1.6
	area_shape.position.y = radius * 0.4

	rim_shape.shape.set_faces(rim_faces())


## 림 바닥판의 삼각형들. 안쪽 반경 = 구멍 반경(그려지는 림과 같은 자리),
## 바깥 반경 = radius + rim_outer. 지면(y=0)과 같은 높이라 딛는 면이 이어진다.
##
## 안쪽을 구멍 반경보다 **넓게** 잡으면 물체가 림에 얹히기 전에 빠지고, **좁게**
## 잡으면 눈에 보이는 구멍 위에 투명한 바닥이 생긴다. 시각과 물리의 경계는 같아야 한다.
func rim_faces() -> PackedVector3Array:
	var f := PackedVector3Array()
	var ro: float = radius + rim_outer
	for i in rim_segments:
		var a0: float = TAU * float(i) / float(rim_segments)
		var a1: float = TAU * float(i + 1) / float(rim_segments)
		var i0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var i1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var o0 := Vector3(cos(a0) * ro, 0.0, sin(a0) * ro)
		var o1 := Vector3(cos(a1) * ro, 0.0, sin(a1) * ro)
		# 반시계 방향(위에서 볼 때)으로 감아 법선이 +Y 를 향하게 한다.
		f.append_array([i0, o0, o1])
		f.append_array([i0, o1, i1])
	return f


func set_radius(r: float) -> void:
	radius = r
	rebuild()
	# 자란 뒤에는 지면 여유가 줄어든다. 다시 붙잡아 두지 않으면 경계에 붙어 있던
	# 구멍이 삼킬 때마다 조금씩 지면 밖으로 밀려난다(실측: G5 위반 1회).
	if is_inside_tree():
		move_to(global_position)


## 면적 보존 성장. 삼킨 오브젝트의 단면적이 구멍 단면적에 더해진다.
func grow_by(obj_radius: float) -> void:
	var before := radius
	set_radius(sqrt(radius * radius + growth_k * obj_radius * obj_radius))
	grew.emit(before, radius)


## AI 조언용. 흡입을 막지 않는다(§23) — 무엇이 들어가는지는 물리가 정한다.
func can_swallow(obj_fit_radius: float) -> bool:
	return obj_fit_radius <= radius * swallow_ratio


## 구멍을 지면 안에 붙잡아 이동시킨다. 밖으로 나가면 우물이 허공에 뜨고
## 판정 전제도 깨진다. 플레이어와 AI 가 같은 함수를 쓴다.
##
## §25: 수역도 같은 방식으로 막는다. 막을 때는 **축별로 미끄러뜨린다** — 두 축을 함께
## 거절하면 강기슭에 대각으로 다가간 구멍이 그 자리에 못 박힌다. 한 축씩 시도하면
## 둑을 따라 흐르듯 움직여, 교량 진입로까지 자연스럽게 미끄러져 간다.
func move_to(p: Vector3) -> void:
	var lim: float = ground_half - radius * 1.15
	var t := Vector3(clampf(p.x, -lim, lim), 0.0, clampf(p.z, -lim, lim))
	if CITY.passable(t):
		global_position = t
		return
	var sx := Vector3(t.x, 0.0, global_position.z)
	if CITY.passable(sx):
		global_position = sx
		return
	var sz := Vector3(global_position.x, 0.0, t.z)
	if CITY.passable(sz):
		global_position = sz


## 다른 구멍을 삼킬 수 있는가 — 상대가 `bite_depth` 만큼 내 원반 안으로 들어와야 한다.
##
## 이 조건은 두 번 조정했다.
##   ① `d + Rb <= Ra` (온전히 포함): 거의 성립하지 않아 자유 실행 900프레임에서
##      포식이 0회였고, 비슷한 크기의 구멍들이 우물을 서로 파고든 채 공존했다.
##   ② `d <= Ra` (중심 포함): 성립은 하지만, 비슷한 크기끼리는 중심이 닿는 순간
##      상대의 절반이 아직 밖에 있어 **"접촉만 해도 죽었다"** 로 읽힌다(플레이 피드백).
## 지금은 그 사이다: `d + Rb*0.8 <= Ra` — 상대가 8할쯤 들어와야 삼킨다.
func can_bite(other: Node3D) -> bool:
	if other == self or not is_instance_valid(other):
		return false
	if radius < float(other.radius) * hole_bite_ratio:
		return false
	var d := Vector2(global_position.x - other.global_position.x,
		global_position.z - other.global_position.z).length()
	return d + float(other.radius) * bite_depth <= radius


## 다른 구멍을 흡수한다. 면적을 그대로 더한다 — 오브젝트 흡입의 growth_k 는
## 체감 조정 계수이지만, 구멍끼리는 실제 단면적이므로 보정 없이 R' = sqrt(Ra^2 + Rb^2) 다.
func bite(other: Node3D) -> void:
	var before := radius
	set_radius(sqrt(radius * radius + float(other.radius) * float(other.radius)))
	score += int(other.score)
	swallowed_count += int(other.swallowed_count)
	grew.emit(before, radius)


func _exit_tree() -> void:
	get_node("/root/HoleRegistry").unregister(self)
	# 이 구멍이 사라질 때 우물 안에서 떨어지던 것들을 함께 정리한다.
	# 그러지 않으면 레이어 4·마스크 0 인 채로 **아무와도 부딪히지 않고 영원히 낙하하는**
	# 개체가 남는다 — 아무도 인수하지 않으므로 해제되지도, 점수가 되지도 않는다.
	# (_candidates 쪽은 Area3D 가 사라질 때 body_exited 가 발화해 exit_rim 이 돌므로 안전하다.)
	for rb in _falling:
		if is_instance_valid(rb):
			rb.queue_free()


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func wall_radius() -> float:
	return radius + maxf(radius * (wall_scale - 1.0), wall_margin_min)


## 1b 의 kill_depth 등이 참조한다.
func well_depth() -> float:
	return radius * depth_ratio


func swallow_count() -> int:
	return _falling.size()


# --- 흡입 로직 -------------------------------------------------------------

## body_entered 는 등록만 한다. 여기서 곧바로 레이어를 전환하면,
## Area3D 반경 = 구멍 반경이라 중심이 구멍 밖인데 콜라이더만 걸친 오브젝트가
## 지면 충돌을 잃고 구멍 옆 단단한 지면 속으로 가라앉는다.
func _on_body_entered(body: Node3D) -> void:
	if not (body is RigidBody3D) or not body.has_method("begin_fall"):
		return
	var rb := body as RigidBody3D
	if rb.falling or _candidates.has(rb):
		return
	_candidates.append(rb)
	rb.hold_awake(true)      # 지면에 놓인 바디는 수 초 뒤 잠든다(V19)
	rb.enter_rim()           # 지면 대신 림 바닥판을 딛는다(§23)


## 레이어가 4 로 바뀌면 Area3D 가 더 이상 감지하지 않아 body_exited 가 반드시
## 발화한다. 낙하 중인 오브젝트의 이탈 신호는 무시해야 한다.
func _on_body_exited(body: Node3D) -> void:
	if not (body is RigidBody3D):
		return
	var rb := body as RigidBody3D
	if rb.falling:
		return
	_candidates.erase(rb)
	if is_instance_valid(rb) and rb.has_method("hold_awake"):
		rb.hold_awake(false)
		rb.exit_rim()        # 다시 지면을 딛는다


func _physics_process(_dt: float) -> void:
	var here := global_position

	# 후보: 림 바닥판을 딛고 있는 것들. 통과 여부를 기하로 판단하지 않는다 —
	# **지면 아래로 내려갔는가**만 본다. 기울어 빠지는 것도, 걸쳐서 안 빠지는 것도
	# 물리가 정한다(§23).
	for i in range(_candidates.size() - 1, -1, -1):
		var rb := _candidates[i]
		if not is_instance_valid(rb):
			_candidates.remove_at(i)
			continue
		# **꼭대기까지** 지면 아래로 내려갔을 때만 낙하로 본다. 원점만 보면 키 큰
		# 물체가 가지도 림에 닿기 전에 충돌을 잃고 그대로 빠진다(실측).
		if rb.global_position.y + float(rb.top_height) < -fall_depth:
			rb.begin_fall()          # 확실히 구멍 안 → 서로에 대한 충돌만 끊는다
			_candidates.remove_at(i)
			_falling.append(rb)
		else:
			pull(rb, here)

	var kill_y := -well_depth() * kill_ratio
	for i in range(_falling.size() - 1, -1, -1):
		var rb := _falling[i]
		if not is_instance_valid(rb):
			_falling.remove_at(i)
			continue
		# 소멸은 **우물 안에서만** 일어난다. 구멍이 떠나 버려 우물 밖에 있는 낙하물은
		# 흡입으로 다시 끌어온 뒤에 사라진다 — 지면 아래 아무 데서나 없어지면
		# "먹지도 않았는데 점수가 오른다" 가 된다.
		if rb.global_position.y < kill_y \
				and flat_dist(rb.global_position, here) < radius:
			_falling.remove_at(i)
			# 구멍 둘이 겹쳐 있으면 같은 개체가 양쪽의 _falling 에 들어 있다.
			# 먼저 삼킨 쪽만 세고, 늦은 쪽은 조용히 넘긴다 — 소멸을 기다리면
			# `queue_free` 가 프레임 끝에 도는 사이에 양쪽이 다 세어 버린다.
			if rb.consumed:
				continue
			rb.consumed = true
			grow_by(rb.radius)
			score += int(rb.score_value)
			swallowed_count += 1
			swallowed.emit(rb)
			rb.queue_free()
			kill_y = -well_depth() * kill_ratio      # 성장으로 우물이 깊어졌다
		else:
			pull(rb, here)


func pull(rb: RigidBody3D, here: Vector3, scale := 1.0) -> void:
	# §30: 구멍은 자기가 삼킬 수 없는 물체를 끌지 않는다. 통과 반경이 구멍보다 큰
	# 물체(fit_radius > radius)는 절대 안 삼켜지는 집합(§23)인데 흡입은 받고 있어서,
	# 시작 반경 1.5 구멍이 주차된 구급차·버스를 지도 위로 끌고 다녔다(플레이 피드백 —
	# 가속 26 이 질량 무관이라 22톤 급도 트래픽콘과 같이 끌려온다).
	# 반드시 삼켜지는 집합(외접 < R)은 외접 >= fit 이라 항상 fit < R 이므로 보장은
	# 그대로다. 회색 지대(fit < R < 외접)도 그대로 — 통과는 물리가 정한다.
	# 낙하물 회수도 안전하다: 낙하 시점에 fit < R 이었고 R 은 줄지 않는다.
	# 경사(램프)가 아니라 계단인 이유 — 원칙이 있는 문턱은 fit = R 하나뿐이다(§23 의
	# 집합 경계). 위로 올리면 통과 가능한 것이 흡입을 잃고, 아래로 내리면
	# 구급차(q=0.947)가 부분 흡입을 받아 문제가 남는다.
	if float(rb.fit_radius) > radius:
		return
	var to_center := Vector3(here.x - rb.global_position.x, 0.0, here.z - rb.global_position.z)
	if to_center.length_squared() < 1e-6:
		return
	rb.apply_central_force(to_center.normalized() * suction * scale * rb.mass)
```

**깊이도 SSOT에서 파생시킨다.** rev.5는 `height = 12.0`을 `.tscn` 리터럴로 두었는데, 2단계에서 반경이 자라면(R=20이면 폭 41에 깊이 12) 현재 카메라 앙각에서 `cap_bottom` 바닥면이 그대로 보여 §4-B가 막으려던 "바닥이 보이면 착시가 깨진다"가 그대로 발생한다. `kill_depth`(§4-D-7)도 함께 무의미해진다.

- `hole.gd`는 **자기 자신을 레지스트리에 등록하지 않는다.** 등록 주체는 `main.gd`다(§4-G).
- `cap_bottom = true`는 **1a 카메라에서는 효과가 없다 — 보험이다.** 앙각 40°·깊이 12·반경 5.15에서는 시선이 바닥에 닿지 않아, `cap_bottom = false`로 바꿔도 렌더 결과가 **바이트 단위로 동일**하다(SHA256 일치, 실측). rev.6까지 적혀 있던 "바닥이 열려 있으면 배경이 원반으로 보인다"는 이 구성에서 성립하지 않는다. 유지하는 이유는 **2단계에서 반경이 자라거나 카메라 앙각이 높아지면 실제로 바닥이 보이기 때문**이며(`depth_ratio`가 깊이를 반경에 비례시키지만 앙각 변화까지 막지는 못한다), 비용이 삼각형 몇 개다.
- **배율 1.03의 근거(V21)**: 배경을 마젠타로 바꿔 구멍 영역의 배경 픽셀을 세면 `1.00 → 97px`, `1.01 → 26px`, **`1.02 → 0`**, `1.03 → 0`이다. 새는 것은 전부 AA 부분픽셀이고 통짜 틈은 없다. **1.02가 최소이며 1.03은 여유분이다.**
- **배율만으로는 부족하다 — `wall_margin_min`이 필요한 이유(V23)**: 누출은 화면 공간의 AA 현상인데 `0.03R`은 월드 단위다. `radius = 1.0`에서 0.03 world는 서브픽셀이 되어 **림 전체에 마젠타 프린지가 생긴다**(실측 `leak=9`, 12배 확대 PNG에서 육안 확인). hole.io의 핵심 기제가 "작게 시작해 자란다"이므로 **작은 반경 쪽이 실전에서 더 중요하다.** `radius + max(radius·0.03, 0.15)`로 두면 R=5에서는 기존과 동일(5.15)하고 R=1에서 1.15가 되어 누출이 0으로 사라진다.
- 반대로 반경이 크게 자라면 `0.03R`의 절대 폭도 커져 우물 벽이 그만큼 두꺼워 보인다 — 2단계에서 상한도 함께 재평가한다.
- **y 오프셋을 주지 않는다.** 반경 확대와 y 상승을 함께 적용하면 R~1.03R 구간에서 지면 위로 벽 링이 돌출한다(마스킹 반경은 R이므로 그 구간 지면은 그려진다).
- 머티리얼의 **`shading_mode`는 기본값(PER_PIXEL) 유지** — UNSHADED로 두면 우물이 명암을 잃고 §6 H2가 무의미해진다.

### C. 레이어 설계 (1b) — Godot 충돌 판정은 OR

`(A.layer & B.mask) || (B.layer & A.mask)`. mask만 조작해서는 지면을 통과하지 못한다.

| 비트 | 레이어 | 용도 |
|---|---|---|
| 1 (값 1) | ground | 지면 |
| 2 (값 2) | swallowable | 흡입 가능 상태 |
| 3 (값 4) | falling | 낙하 중 |

| 노드 | collision_layer | collision_mask |
|---|---|---|
| `GroundBody` StaticBody3D | 1 | **0** |
| Swallowable RigidBody3D (정상) | 2 | 1 \| 2 |
| Swallowable (낙하 전환 후) | **4** | **0** |
| Hole `Area3D` (1b에서 추가) | 0 | 2 |

- 지면 mask=0 **그리고** 낙하 시 layer를 4로 이동. 검산: `1&0=0`, `4&0=0`.
- **rev.8까지의 서술 정정**: "mask만 조작해서는 지면을 통과하지 못한다"는 **이 구성에서는 틀렸다.** `GroundBody.mask = 0`이므로 낙하체의 mask만 0으로 해도 지면과의 OR 판정이 양쪽 다 0이 된다 — 실측으로 확인했다(레이어 전환을 빼고 mask만 0으로 한 빌드가 정상적으로 지면을 통과했다).
  **레이어 전환의 실제 기능은 낙하체와 다른 오브젝트의 분리다.** layer를 2로 남기면 다른 swallowable의 mask 3과 `2 & 3 = 2`로 겹쳐 낙하 중에 남은 오브젝트를 들이받는다. 1b의 성긴 배치에서는 드러나지 않지만 3단계 도시에서는 상시 발생한다 → 이것을 §6의 **B4**로 기계 판정한다.
- **Area3D 감지는 단방향이다**: [문서](https://docs.godotengine.org/en/stable/classes/class_area3d.html) — *"The overlapping body's `collision_layer` must be part of this area's `collision_mask` in order to be detected."*
- **Area3D 셰이프 (1b)**: 반경 R짜리 `SphereShape3D`를 지면 높이에 두면 지면 위에 얹힌 박스(중심 y>0)를 놓친다. **세로로 긴 `CylinderShape3D`**를 쓴다.
  **치수는 §4-B와 같이 SSOT에서 파생시킨다** — `radius = hole.radius`, `height = radius * 1.6`, 중심 `y = radius * 0.4`(R=5에서 height 8, y=+2로 현 값과 일치). 리터럴 8/2로 박으면 2단계에서 R=20일 때 반경 20 · 높이 8짜리 납작한 원판이 되어 "지면 위 오브젝트를 놓치지 않는다"는 목적 자체가 무너진다.

### D. 흡입 로직 (1b, `scripts/hole.gd` / `scripts/swallowable.gd`)

1. `body_entered` → 후보 목록에 **등록만** 한다. `if body is RigidBody3D`로 가드한 뒤 `body.can_sleep = false`(V19) — `can_sleep`은 `RigidBody3D` 전용 프로퍼티이므로 layer 2에 다른 타입이 섞이면 런타임 오류다.
2. `_physics_process`에서 후보마다 **매 프레임 조건 재평가**:
   ```
   통과 조건: distance(obj.global_position.xz, hole.xz) + obj_radius < hole_radius
   ```
   - 미충족: 구멍 중심 방향 **흡입력만** 가한다 → "가장자리에서 덜덜 떨다 빨려듦" 느낌.
     **한계**: 구멍보다 큰 오브젝트는 통과 조건을 영원히 만족하지 못한 채 림에서 계속 떤다. 크기 판정은 2단계 범위(§9)이며, 1b에서는 모든 오브젝트를 구멍보다 작게 배치해 회피한다.
   - 충족: 레이어 전환(layer 2→4, mask→0).
   - **즉시 전환하면 안 되는 이유**: Area3D 반경 = 구멍 반경이므로 중심이 구멍 밖이어도 콜라이더가 살짝 겹치면 `body_entered`가 뜬다. 그때 지면 충돌을 끄면 오브젝트가 **구멍 옆 단단한 지면 속으로 가라앉는다.**
3. **`obj_radius` 취득**: `@export var radius: float`. 미지정(≤0)이면 `_ready`에서 자동 산출:
   ```gdscript
   # 셰이프가 여럿이면 각각의 XZ 외접반경 중 최대값을 쓴다(보수적 = 안전한 방향).
   var cols := find_children("", "CollisionShape3D", false)
   assert(not cols.is_empty(), "swallowable 에 CollisionShape3D 가 없다")
   for col in cols:
       var s := col.shape.get_debug_mesh().get_aabb().size   # V18
       radius = maxf(radius, Vector2(s.x, s.z).length() * 0.5)   # XZ 외접반경
   ```
   **XZ 최대 절반값이 아니라 대각선의 절반이다.** 2×2×2 박스에서 전자는 1.0, 후자는 √2≈1.414(V18) — 전자를 쓰면 통과 조건이 최대 41% 일찍 참이 되어 2번이 막으려던 "지면 속으로 가라앉음"이 모서리 기준으로 그대로 발생한다.
   **한계 두 가지**:
   (a) AABB만 보므로 **둥근 셰이프에서는 과대평가**한다 — `CapsuleShape3D(r=0.7)`의 실제 XZ 외접반경은 0.7인데 이 식은 0.9899를 준다(V18). 과대평가는 흡입이 **늦어지는** 방향이라 안전하지만(가라앉지 않는다), 원통·구 위주 오브젝트가 많아지면 `@export radius`를 명시하는 편이 낫다.
   (b) `CollisionShape3D`의 로컬 스케일·회전을 반영하지 않는다. 회전·비균등 스케일된 콜라이더는 `@export radius`를 명시할 것.
4. **수면 처리**: 후보 등록 시 `can_sleep = false`, `body_exited`로 빠질 때 `can_sleep = true` 복구. **낙하 중인 물체는 복구하지 않는다** — 어차피 7번에서 해제되고, 낙하 도중 재수면하면 우물 안에서 멈춘다.
5. **복구 로직**: `body_exited` → **아직 낙하 상태가 아니면** 후보에서 제거하고 `can_sleep` 복구. 낙하 중이면 무시 — 레이어가 4로 바뀌면 Area3D가 감지하지 않아 `body_exited`가 **반드시** 발화하므로 이탈로 오해하면 안 된다.
6. 낙하 중 매 프레임 구멍 중심 방향 흡입력 + 중력.
7. `y < -kill_depth`(= `hole.well_depth() × 0.8`) → **후보 목록에서 먼저 제거한 뒤** `queue_free()` + 시그널 발신(2단계 스코어 연결점).
   - **제거를 빠뜨리면 안 된다**: 5번이 낙하 중의 `body_exited`를 무시하므로, 낙하 오브젝트를 목록에서 빼는 지점은 여기뿐이다. 빠뜨리면 다음 `_physics_process`에서 해제된 인스턴스에 힘을 가하려다 오류가 난다. 이중 방어로 순회 시작에 `if not is_instance_valid(b): 제거 후 continue`를 둔다.
8. **`continuous_cd`는 쓰지 않는다.** 우물에는 콜라이더가 없고 낙하 오브젝트는 mask=0이라 아무것과도 충돌하지 않는다.

### D-2. `scripts/swallowable.gd` (전문)

```gdscript
extends RigidBody3D

## 흡입 가능 오브젝트. 레이어 전환·수면 처리는 hole.gd 가 주도하고
## 이 스크립트는 자기 크기와 낙하 상태만 안다.

## XZ 외접반경. 0 이하이면 _ready 에서 콜라이더 AABB 로 산출한다.
## §17 이후 도시 프롭의 콜라이더는 **밑동**에서 따므로, 이 값은 곧 밑동 반경이다.
@export var radius := 0.0
## 원형 구멍을 통과하는 데 필요한 반경 — 콜라이더의 **좁은 쪽 반폭**이다(§23).
## `radius`(외접반경)로 이것을 대신하면 길쭉한 물체가 부당하게 거절된다:
## 택시는 외접반경 2.27 이지만 폭은 0.85 이고, 원 안에 들어와 보이는데도 안 먹혔다
## (플레이 피드백). AI 목표 선정이 이 값을 쓴다.
@export var fit_radius := 0.0
## 점수. 0 이하이면 단면적에 비례해 산출한다(큰 것을 삼킬수록 많이 받는다).
@export var score_value := 0
## 구멍이 다가올 때까지 정적으로 세워 둘 것인가.
## 이유는 **성능 하나**다 — 도시 프롭 수백 개를 매 프레임 시뮬레이션할 이유가 없다.
## (자세를 지키기 위한 것이 아니다. 고정을 해제해도 180 물리 프레임 동안 최대
##  이동 0.9mm·기울기 0.0001rad 로 멀쩡히 서 있다 — 실측. 초기 스크린샷에서
##  가로등이 넘어진 것처럼 보였던 것은 광각 원근의 착시였다.)
@export var start_frozen := false

var falling := false
## 이미 어떤 구멍이 삼켜서 점수·성장에 반영한 개체인가.
## `queue_free()` 는 프레임 끝에 실행되고 그때까지 `is_instance_valid` 가 참이라,
## 구멍 둘이 겹친 자리에서는 **같은 프레임에 두 구멍이 같은 개체를 각각 삼킨다** —
## 면적이 공짜로 두 배 늘어난다(실측: G2 가 성장 14.18 대 기대 7.37 로 잡았다).
## 소멸에 기대지 않고 여기서 한 번만 세도록 못을 박는다.
var consumed := false
## 콜라이더의 가장 높은 점(원점 기준). "구멍 안으로 들어갔다" 를 이 값으로 판단한다 —
## 원점만 보면 **키 큰 물체가 가지도 닿기 전에 낙하로 전환된다**(실측: 수관 픽스처가
## 밑동 0.6m 만 잠기고도 충돌을 잃어 그대로 통과했다).
var top_height := 0.0

var _can_sleep_default := true
## 이 물체를 감지 범위에 두고 있는 구멍의 수(§23).
var _rim_refs := 0


func _ready() -> void:
	_can_sleep_default = can_sleep
	if radius <= 0.0:
		radius = auto_radius()
	if fit_radius <= 0.0:
		fit_radius = auto_fit_radius()
	top_height = auto_top_height()
	if score_value <= 0:
		score_value = int(round(radius * radius * 100.0))
	if start_frozen:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true


## 셰이프가 여럿이면 각각의 XZ 외접반경 중 최대값을 쓴다(보수적 = 안전한 방향).
## XZ 최대 절반값이 아니라 대각선의 절반이다 — 2x2x2 박스에서 1.0 이 아니라 1.414.
## 전자를 쓰면 통과 조건이 최대 41% 일찍 참이 되어 구멍 옆 지면 속으로 가라앉는다.
func auto_radius() -> float:
	# owned=false 가 필수다. 기본값(true)은 owner 가 설정된 노드만 돌려주는데,
	# 코드로 만든 노드(3b 의 도시 프롭)는 owner 가 null 이라 전부 걸러진다
	# — 실측: 도시 프롭 541개가 전부 "CollisionShape3D 가 없다" 로 죽었다.
	var cols := find_children("", "CollisionShape3D", false, false)
	assert(not cols.is_empty(), "swallowable 에 CollisionShape3D 가 없다")
	var r := 0.0
	for c in cols:
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		r = maxf(r, Vector2(s.x, s.z).length() * 0.5)
	return r


## 통과 반경 = **가장 잘 눕혔을 때의 외접반경**.
##
## 좁은 쪽 반폭만 보면 안 된다 — 한 변 2.6 인 정육면체는 폭이 1.3 이지만 대각선이
## 3.68 이라 지름 3.4 인 구멍에 **모서리로 얹힌다**(실측: 그래서 한 개도 안 빠졌다).
## 반대로 외접반경만 보면 길쭉한 차가 부당하게 거절된다(택시 2.27, 실제 폭 0.85).
## 물체를 가장 유리하게 눕히면 통과 단면은 **가장 작은 두 반extent** 가 만드는
## 직사각형이므로, 그 외접반경이 규격이다: sqrt(h1^2 + h2^2), h1 <= h2 <= h3.
func auto_fit_radius() -> float:
	var r := INF
	for c in find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		var h := [s.x * 0.5, s.y * 0.5, s.z * 0.5]
		h.sort()
		r = minf(r, sqrt(h[0] * h[0] + h[1] * h[1]))
	return radius if is_inf(r) else r


## 콜라이더 전체의 꼭대기 높이(원점 기준).
func auto_top_height() -> float:
	var t := 0.0
	for c in find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		t = maxf(t, col.position.y + s.y * 0.5)
	return t


## 림 바닥판을 딛기 시작한다 — 지면(레이어 1) 대신 림(레이어 8)과 충돌한다(§23).
## 구멍 위에는 바닥이 없으므로, 여기서부터는 물체가 스스로 기울고 빠진다.
## 구멍 두 개의 감지 범위에 동시에 들어갈 수 있어 **횟수를 센다** — 하나가 떠났다고
## 지면을 되돌리면 나머지 구멍 위에서 지면을 딛고 서 있게 된다.
func enter_rim() -> void:
	_rim_refs += 1
	if not falling:
		collision_mask = (collision_mask & ~1) | 8


func exit_rim() -> void:
	_rim_refs = maxi(_rim_refs - 1, 0)
	if _rim_refs == 0 and not falling:
		collision_mask = (collision_mask & ~8) | 1


## 지면 아래로 확실히 내려갔을 때 hole.gd 가 호출한다(§23 이후로는 **물리가**
## 그 시점을 정한다 — 통과 조건을 기하로 흉내내지 않는다).
## 지면(layer 1)·림(layer 8)·다른 오브젝트(layer 2) 어느 쪽과도 더는 부딪히지 않는다.
## Godot 충돌 판정은 OR 이므로 mask 만 0 으로 해서는 지면을 통과하지 못한다.
func begin_fall() -> void:
	if falling:
		return
	falling = true
	collision_layer = 4
	collision_mask = 0
	sleeping = false


## hole.gd 가 Area3D 진입/이탈에서 호출한다. 정적으로 세워 둔 프롭은
## 구멍이 다가온 이 순간에 비로소 강체가 된다 — 한 번 풀리면 되돌리지 않는다
## (다시 얼리면 구멍 옆에서 반쯤 기울어진 채로 굳는다).
func hold_awake(on: bool) -> void:
	if on and freeze:
		freeze = false
	can_sleep = _can_sleep_default and not on
	if on:
		sleeping = false
```

### E. 입력 / 카메라 (1b)

- **InputMap을 쓰지 않는다.** `project.godot`에 InputEventKey를 손으로 직렬화하는 것은 오류가 잦다. `Input.is_key_pressed(KEY_W)` 등을 직접 사용(1단계 한정, 2단계에서 InputMap 정식화).
- 카메라: 고정 오프셋 추적 + 구멍 반지름 비례 거리 보간(2단계 성장 대비).

`scripts/camera_rig.gd` (전문)

```gdscript
extends Camera3D

## 구멍을 고정 오프셋으로 추적한다. 거리는 반경에 비례해 늘어난다(2단계 성장 대비).
## base_radius 에서 오프셋이 정확히 base_offset 이므로 1a 의 판정 수치가 보존된다.
##
## §29: **회전은 상수다.** 매 프레임 look_at(target) 을 하면 위치 lerp 의 지연과
## 결합해 방향 전환마다 시야 전체가 기울었다 돌아온다 — 실측 최대 86°/s 로,
## 휴대폰 멀미 피드백의 주 기제였다. 카메라가 목표 지점(want)에 정확히 있을 때의
## look_at 과 같은 회전이므로(want - target = base_offset·k, 방향은 k 와 무관)
## 판정 모드(snap)의 스크린샷 프레이밍은 변하지 않는다.

@export var base_offset := Vector3(0.0, 22.0, 26.0)
@export var base_radius := 5.0
@export var smooth := 6.0
## 카메라 최저 높이. 반경에 정비례만 시키면 시작 반경 1.5 에서 높이가 6.6m 로
## 내려가 12~14m 짜리 건물이 시야를 막는다. 배율을 통째로 clamp 하므로
## 앙각(40.2°)은 그대로 유지된다 — H9·판정 전제가 반경과 무관해진다.
@export var min_height := 14.0
## §29: 성장 후퇴 감속. 반경은 삼킬 때 계단으로 뛰므로 배율을 즉시 따라가면
## 카메라가 최대 83 m/s(주행 추적 14 m/s 의 6배)로 튀어 물러난다(실측).
## 배율 _k 를 이 시정수로 지수 평활하면 피크 후퇴 속도가 주행 추적 아래로 온다
## (해석: grow_by(5.0) 에서 13.1 m/s, 판정 V2 의 상한 16 m/s).
@export var grow_smooth := 1.5

## 현재 적용 중인 오프셋 배율. main 이 _ready/restart 에서 항상 snap 을 먼저
## 부르므로 0 인 채로 비스냅 경로에 들어가는 일은 없다.
var _k := 0.0


func follow(target: Node3D, radius: float, snap: bool, dt := 0.0) -> void:
	var k_target: float = maxf(radius / base_radius, min_height / base_offset.y)
	if snap:
		_k = k_target
		global_position = target.global_position + base_offset * _k
	else:
		# 평활 계수는 1-exp(-rate·dt) — clampf(rate·dt) 는 프레임률에 따라
		# 수렴 곡선 자체가 달라진다(§29 판정 V4 가 두 dt 로 단언한다).
		_k = k_target + (_k - k_target) * exp(-grow_smooth * dt)
		var want := target.global_position + base_offset * _k
		global_position = global_position.lerp(want, 1.0 - exp(-smooth * dt))
	global_basis = Basis.looking_at(-base_offset)
```

### F. 구멍 레지스트리 (`scripts/hole_registry.gd`, autoload — 전문)

```gdscript
extends Node

var _mat: ShaderMaterial = null
var _holes: Array[Node3D] = []
var _buf := PackedVector4Array()


func _ready() -> void:
	_buf.resize(16)


func set_target_material(m: ShaderMaterial) -> void:
	_mat = m


func register(h: Node3D) -> void:
	if not _holes.has(h):
		_holes.append(h)


func unregister(h: Node3D) -> void:
	_holes.erase(h)


func holes() -> Array[Node3D]:
	return _holes


func hole_count() -> int:
	return mini(_holes.size(), 16)


func flush() -> void:
	if _mat == null:
		return
	# 해제된 구멍이 남아 있으면 아래 global_position 접근이 매 프레임 터진다.
	# 4단계(AI 구멍 소멸)에서 unregister 를 빠뜨려도 여기서 회수된다.
	for i in range(_holes.size() - 1, -1, -1):
		if not is_instance_valid(_holes[i]):
			_holes.remove_at(i)
	var n := hole_count()
	for i in 16:
		if i < n:
			var p: Vector3 = _holes[i].global_position
			_buf[i] = Vector4(p.x, p.y, p.z, _holes[i].radius)
		else:
			_buf[i] = Vector4(0, 0, 0, 0)
	_mat.set_shader_parameter("holes", _buf)      # 내용만 바꾸면 반영 안 됨
	_mat.set_shader_parameter("hole_count", n)
```

- **16칸 패딩은 레지스트리 책임**이다(§6 H4가 size==16을 요구).
- **autoload는 씬 트리보다 먼저 생성되므로 지면 머티리얼을 스스로 찾을 수 없다** → `main.gd`가 `set_target_material()`로 주입한다.
- `_holes[i].radius`는 `Array[Node3D]`에 없는 프로퍼티라 `UNSAFE_PROPERTY_ACCESS` **경고**가 나지만 오류가 아니며 `--check-only` exit 0이다(실측). 대신 `radius` 오타는 §6-1 게이트를 통과해 런타임에서야 드러난다 — 트리아지에 항목을 두었다.

### G. `main.gd` — 1a의 실행 주체 (전문)

```gdscript
extends Node3D

const MOVE_SPEED := 14.0
const GROUND_HALF := 224.0           # PlaneMesh size 448 의 절반 (14x14 도시 블록)
const HOLE_SCENE := preload("res://scenes/hole.tscn")
const HOLE_AI := preload("res://scripts/hole_ai.gd")
const CITY := preload("res://scripts/city.gd")

## 4a: 경쟁 구멍 수. 0 이면 1단계~3단계와 같은 단독 구멍 씬이다.
@export var ai_count := 5
## AI 구멍이 등장하는 각도(원점 기준). 시드 대신 고정 배치로 두어 재현 가능하다.
@export var ai_spawn_radius := 128.0

@onready var registry := get_node("/root/HoleRegistry")
@onready var cam: Camera3D = $Camera3D
@onready var ground: MeshInstance3D = $Ground
@onready var hole: Node3D = $Hole

# screenshot.gd 가 판정하는 동안 uniform 갱신·입력·카메라 추적을 멈추기 위한 플래그.
# set_process(false) 를 쓰면 안 된다 — 엔진이 부모 _ready 직전에 다시 켠다(V20).
# @onready 로 선언해도 안 된다 — Main._ready 직전 대입이 Judge._ready 의 설정을 덮는다.
var judging := false

# 1a~3단계의 판정은 전부 "구멍 하나" 를 전제로 세워졌다. AI 구멍이 있으면
# judge_static 이 화면 밖 구멍까지 판정하고, AI 가 광장의 판정 대상을 먹어
# C1·C3 의 기대값이 깨진다. Judge._ready 가 Main._ready 보다 먼저 도는 것을 이용해
# 단독 구멍 판정에서는 이 플래그를 내린다(judging 과 같은 이유로 @onready 금지).
var arena := true

var ai_holes: Array[Node3D] = []

## 포인터 입력 상태(§26). 터치는 손가락 하나만 조종에 쓴다 — 둘째 손가락이
## 방향을 빼앗으면 조작이 튄다.
## 마우스 눌림은 **이벤트로 기억하지 않고 매번 물어본다.** 포커스를 잃으면
## (알트탭·탭 전환) Godot 은 눌림 상태를 비우면서 릴리즈 이벤트를 트리로 보내지
## 않는다 — 기억해 두면 참으로 남아 구멍이 마지막 커서 방향으로 계속 흘러간다.
const TOUCH_DEAD_PX := 18.0
var _touch_id := -1
var _touch_start := Vector2.ZERO
var _touch_cur := Vector2.ZERO

@onready var ui: CanvasLayer = get_node_or_null("UI")
@onready var hud_root: CanvasLayer = $HUD
@onready var hud: Label = $HUD/Label
@onready var hud_timer: Label = $HUD/Timer
@onready var hud_board: Label = $HUD/Board
@onready var hud_over: Label = $HUD/Over

# --- 4b: 게임 루프 ---------------------------------------------------------
## §26 에서 HOME 이 앞에 붙었다. **판정 모드는 이 상태로 들어가지 않는다** —
## 1a~4b 판정 스물아홉 종이 전부 "부팅 즉시 플레이 상태" 를 전제하므로,
## 그 앞에 화면 하나를 끼워 넣으면 통째로 깨진다.
enum State { HOME, PLAYING, OVER }
## 한 판의 길이(초). 판정기가 짧게 줄여 종료까지 돌린다.
@export var round_seconds := 120.0
var state := State.PLAYING
var time_left := 0.0
## 승자의 label 과 그때의 점수. 판정기가 독립 계산한 최댓값과 대조한다.
var winner := ""
var winner_score := 0
## 종료 사유 — "time"(시간 만료) 또는 "eaten"(플레이어가 먹힘).
var over_reason := ""

## §20. 판정 대상 8개(소형 6 + 대형 2). **판정 모드에서만** 스폰한다.
##
## 원래는 main.tscn 에 손으로 놓여 있었다. 그러나 이것들은 1a 의 스케일 기준용
## 픽스처이지 게임의 일부가 아니다 — 노랑·파랑 큐브가 광장에 서서 **시작 화면에
## 그대로 보였고**, 도시 에셋과 이질적이었다. §17 이 같은 이유로 `RefBox` 를 지운
## 것과 같은 판단이다. 다만 이쪽은 1b·2·3b·5 판정의 시나리오가 통째로 이 8개 위에
## 서 있으므로 지울 수는 없고, **판정에만 존재하도록** 옮겼다.
##
## 치수·자리를 바꾸면 안 된다. C2 는 "소형 6개를 다 먹어야 대형의 게이트가 열린다"
## 를 시험하고(R 5 → 6.73, 게이트 3.03 > 대형 r 2.83), B1 은 MOVED_TO 가 이것들에서
## 충분히 멀다는 전제 위에 있다(§17).
const JUDGE_SET := [
	["res://scenes/swallowable.tscn", "S0", Vector3(-6.0, 1.31, -8.0)],
	["res://scenes/swallowable.tscn", "S1", Vector3(0.0, 1.31, -9.0)],
	["res://scenes/swallowable.tscn", "S2", Vector3(6.0, 1.31, -9.0)],
	["res://scenes/swallowable.tscn", "S3", Vector3(11.0, 1.31, -4.0)],
	["res://scenes/swallowable.tscn", "S4", Vector3(-11.0, 1.31, -5.0)],
	["res://scenes/swallowable.tscn", "S5", Vector3(3.0, 1.31, -14.0)],
	["res://scenes/swallowable_big.tscn", "B0", Vector3(16.0, 2.0, -2.0)],
	["res://scenes/swallowable_big.tscn", "B1", Vector3(14.0, 2.0, -12.0)],
]

## 플레이어 점수. 구멍이 진실 원천이고 여기서는 되읽기만 한다
## (2단계 판정의 C3 가 이 이름으로 읽는다).
var score: int:
	get:
		return hole.score if is_instance_valid(hole) else 0

var swallowed_total: int:
	get:
		return hole.swallowed_count if is_instance_valid(hole) else 0


func _ready() -> void:
	var gmat: ShaderMaterial = ground.get_surface_override_material(0)
	registry.set_target_material(gmat)
	# 존 지도를 셰이더로 넘긴다(§25). City._ready 가 먼저 도는 것과 무관하게
	# 지도는 상수라 언제든 구울 수 있다. 판정 모드에서도 반드시 걸어야 한다 —
	# 안 걸면 미할당 sampler2D 의 기본값(흰색)이 읽혀 복호값이 존 코드 범위를 벗어나고,
	# 셰이더의 마지막 분기로 떨어져 **지도 전체가 공원색**이 된다.
	gmat.set_shader_parameter("zone_tex", CITY.zone_texture())
	gmat.set_shader_parameter("ground_half", GROUND_HALF)
	hole.ground_half = GROUND_HALF
	hole.label = "P"
	# 포식 해소는 그 프레임의 이동이 **끝난 뒤** 돌아야 한다. 기본 순서(부모 먼저)
	# 로는 AI 조종자가 Main 다음에 움직여, 이번 프레임에 겹친 쌍이 다음 프레임까지
	# 그대로 남는다 — 그 한 프레임 동안 우물이 서로 파고든 채 그려진다(실측 G6=1).
	process_physics_priority = 100
	registry.register(hole)        # 플레이어가 항상 0번이다(판정기가 [0] 을 쓴다)
	hole.swallowed.connect(_on_swallowed)
	if arena:
		spawn_ai()
	cam.follow(hole, hole.radius, true)
	spawn_judge_set()
	time_left = round_seconds
	# 교통은 여기서 켠다(§27). Traffic._ready 에서 켜면 형제 순서에 기대게 되고,
	# Judge 가 judging 을 세우기 전에 돌아 **판정 모드에서도 차가 난다**.
	# Main._ready 는 모든 자식보다 늦게 도는 것이 보장된다.
	var tr := get_node_or_null("Traffic")
	if tr != null and not judging:
		tr.boot()
	var cz := get_node_or_null("Citizens")
	if cz != null and not judging:
		cz.boot()
	# 게임은 시작 화면에서 열리고, 판정은 곧바로 플레이 상태에서 시작한다.
	# Judge._ready 가 Main._ready 보다 먼저 돌아 judging 을 세워 두므로 여기서 읽을 수 있다.
	state = State.HOME if not judging else State.PLAYING
	if state == State.HOME:
		set_ai(false)
		set_holes_physics(false)
	update_hud()


## 모든 구멍의 물리를 켜고 끈다. **AI 조종자만 멈추는 것으로는 부족하다** —
## 구멍 자신의 `_physics_process` 가 흡입·삼킴을 돌리므로, 시작 화면에 머무는 동안
## 스폰 지점에 걸친 프롭이 삼켜지고 점수·반경이 오른 채로 판이 시작한다.
func set_holes_physics(on: bool) -> void:
	for h in registry.holes():
		if is_instance_valid(h):
			h.set_physics_process(on)


## 시작 화면에서 한 판을 연다. UI 버튼이 부른다.
func begin_round() -> void:
	state = State.PLAYING
	time_left = round_seconds
	set_ai(true)
	set_holes_physics(true)


## 판정 대상 8개를 규격대로 세운다. **판정 모드가 아니면 아무것도 만들지 않는다** —
## 게임에는 이 픽스처가 존재하지 않는다.
##
## `judging` 은 Judge._ready 가 Main._ready 보다 먼저(자식 → 부모) 세워 두므로
## 여기서 읽을 수 있다. 판정 플래그 없이 실행하면 Judge 는 아무 일도 하지 않고
## 이 함수도 빈손으로 돌아간다.
##
## _ready 와 restart() 가 **같은 함수**를 부른다. 둘 중 하나만 조건을 걸면
## "게임에서는 없는데 재시작하면 나타난다" 가 된다.
func spawn_judge_set() -> void:
	var box := get_node_or_null("Swallowables")
	if box == null or not judging:
		return
	for spec in JUDGE_SET:
		var n: Node3D = load(spec[0]).instantiate()
		n.name = spec[1]
		box.add_child(n)
		n.position = spec[2]


## AI 구멍을 원점 둘레에 고르게 배치한다. 위치를 난수로 뽑지 않는 이유는
## 판정이 같은 시작 배치를 몇 번이든 다시 만들 수 있어야 하기 때문이다.
func spawn_ai() -> void:
	for i in ai_count:
		var h: Node3D = HOLE_SCENE.instantiate()
		var a := TAU * float(i) / float(ai_count)
		h.name = "AI%d" % i
		# 원둘레 위의 이상적 위치를 **격자 교차로로 스냅**한다. 그냥 원 위에 놓으면
		# 구멍이 건물 밑에서 시작해, 그 건물이 착시 판정의 표본을 가린다(실측:
		# 6개 중 3개가 H2 로 탈락). 교차로는 도시 배치가 비워 두는 자리다.
		h.position = snap_to_grid(Vector3(cos(a), 0.0, sin(a)) * ai_spawn_radius)
		add_child(h)
		h.ground_half = GROUND_HALF
		h.label = "AI%d" % (i + 1)
		var drv := Node.new()
		drv.set_script(HOLE_AI)
		drv.ai_seed = 1000 + i
		h.add_child(drv)
		registry.register(h)
		ai_holes.append(h)


## 플레이어 구멍이 아직 살아 있는가. 4단계에서는 플레이어도 먹힐 수 있으므로
## 구멍이 살아 있다는 전제를 두는 모든 곳이 이것을 먼저 물어야 한다
## (실측: 이 가드가 없으면 플레이어가 먹힌 프레임에 `previously freed` 로 죽는다).
func player_alive() -> bool:
	return is_instance_valid(hole)


## 가장 가까운 도로 교차로. 격자 주기는 city.gd 의 규격과 같은 값이다.
func snap_to_grid(p: Vector3) -> Vector3:
	var pitch := 32.0
	return Vector3(round(p.x / pitch) * pitch, 0.0, round(p.z / pitch) * pitch)


func _process(dt: float) -> void:
	if judging:
		return
	registry.flush()
	if state == State.PLAYING:
		time_left = maxf(time_left - dt, 0.0)
		if time_left <= 0.0:
			end_game("time")
	if Input.is_key_pressed(KEY_R) and state == State.OVER:
		restart()
		return
	if not player_alive():
		update_hud()
		return
	if state == State.PLAYING:
		move_hole(dt)
	cam.follow(hole, hole.radius, false, dt)
	update_hud()


## 판을 끝낸다. 승자는 점수 최댓값이며, 동점이면 반경으로 가른다.
## 끝난 뒤에는 모든 구멍의 물리 처리를 멈춘다 — AI 만 세우면 낙하 중이던
## 오브젝트가 계속 소멸하며 점수가 더 올라, "끝났다" 가 상태로 성립하지 않는다.
func end_game(reason: String) -> void:
	if state == State.OVER:
		return
	state = State.OVER
	over_reason = reason
	set_ai(false)
	var best: Node3D = null
	for h in registry.holes():
		if not is_instance_valid(h):
			continue
		h.set_physics_process(false)
		if best == null or int(h.score) > int(best.score) \
				or (int(h.score) == int(best.score) and float(h.radius) > float(best.radius)):
			best = h
	winner = str(best.label) if best != null else ""
	winner_score = int(best.score) if best != null else 0
	update_hud()


## 끝난 판을 **재시작 없이** 진행 상태로 되돌린다.
## 4a 판정이 포식 시나리오에서 플레이어를 잃은 뒤(= 판이 끝난 뒤) 아레나 자유
## 실행을 이어가야 해서 필요하다. end_game 이 멈춘 것을 정확히 되돌린다.
func resume() -> void:
	state = State.PLAYING
	over_reason = ""
	winner = ""
	winner_score = 0
	for h in registry.holes():
		if is_instance_valid(h):
			h.set_physics_process(true)
	set_ai(true)
	hud_over.visible = false


## 판을 처음 상태로 되돌린다. 씬 전체를 reload 하지 않는 이유는 Judge 노드가
## Main 의 자식이라 함께 사라져 재시작을 판정할 수 없기 때문이다.
## 도시는 시드 고정(E4)이고 AI 스폰도 고정 배치라, 되돌린 결과가 최초와 같아야 한다.
func restart() -> void:
	for h in registry.holes().duplicate():
		if is_instance_valid(h):
			registry.unregister(h)
			h.free()
	ai_holes.clear()

	hole = HOLE_SCENE.instantiate()
	hole.name = "Hole"
	add_child(hole)
	hole.ground_half = GROUND_HALF
	hole.label = "P"
	registry.register(hole)
	hole.swallowed.connect(_on_swallowed)
	if arena:
		spawn_ai()

	var city := get_node_or_null("City")
	if city != null:
		for c in city.get_children():
			c.free()
		city.build(city.plan(city.city_seed))

	var box := get_node_or_null("Swallowables")
	if box != null:
		for c in box.get_children():
			c.free()
	spawn_judge_set()

	# 교통도 되돌린다(§27). 안 그러면 이 함수가 단언하는 "되돌린 결과가 최초와 같다"
	# 가 거짓이 된다 — 차의 위치·속도·차선이 판을 넘겨 이어지고, 구멍이 스쳐 놓아둔
	# 자유 강체도 누적된다.
	var tr := get_node_or_null("Traffic")
	if tr != null and not judging:
		tr.reset()
	var cz := get_node_or_null("Citizens")
	if cz != null and not judging:
		cz.reset()

	state = State.PLAYING
	time_left = round_seconds
	winner = ""
	winner_score = 0
	over_reason = ""
	hud_over.visible = false
	cam.follow(hole, hole.radius, true)
	update_hud()


## AI 조종자를 일괄로 켜고 끈다. 판정이 특정 두 구멍만 두고 시나리오를 돌릴 때
## 나머지가 끼어들지 못하게 한다.
func set_ai(on: bool) -> void:
	for h in ai_holes:
		if not is_instance_valid(h):
			continue
		for c in h.get_children():
			if c is Node and c.get_script() == HOLE_AI:
				c.set_physics_process(on)


## 구멍끼리의 포식. 큰 구멍이 작은 구멍을 온전히 덮으면 흡수한다.
## 여기서 도는 이유: 레지스트리는 uniform 버퍼만 책임지고, 승패는 아레나의 일이다.
func _physics_process(_dt: float) -> void:
	if judging or state != State.PLAYING:
		return
	# 판이 끝난 뒤에도 돌면 구멍끼리 계속 잡아먹어 "끝났다" 가 상태로 성립하지 않는다
	# (실측: T3 가 종료 후 120프레임 동안 레지스트리 변동을 잡았다).
	resolve_bites()


## 성립하는 포식이 남지 않을 때까지 돈다. 한 프레임에 한 쌍만 처리하면 남은 쌍이
## 다음 프레임까지 겹친 채로 남아, 그 프레임의 착시가 깨진다.
## 한 번 삼킬 때마다 구멍이 하나 사라지므로 반드시 끝난다.
## 반환값은 이번에 삼켜진 구멍 수.
func resolve_bites() -> int:
	var n := 0
	# 구멍 수만큼만 돌면 충분하다 — 한 번 삼킬 때마다 하나가 사라진다.
	# (while true 는 GDScript 파서가 반환 경로를 증명하지 못해 거부한다)
	for _guard in registry.holes().size() + 1:
		var eaten: Node3D = null
		var eater: Node3D = null
		for a in registry.holes():
			if not is_instance_valid(a):
				continue
			for b in registry.holes():
				if not is_instance_valid(b) or a == b:
					continue
				if a.can_bite(b):
					eater = a
					eaten = b
					break
			if eaten != null:
				break
		if eaten == null:
			return n
		eater.bite(eaten)
		if ui != null:
			ui.kill_feed(str(eater.label), str(eaten.label))
		registry.unregister(eaten)
		ai_holes.erase(eaten)
		var was_player: bool = eaten == hole
		eaten.queue_free()
		n += 1
		if was_player:
			end_game("eaten")      # 플레이어가 먹히면 그 자리에서 판이 끝난다
			return n
	return n


## 입력을 해석하는 자리는 **여기 하나**다(§26). 키보드·마우스·터치 셋이 들어오지만
## 밖으로 나가는 것은 방향 벡터 하나이고, move_hole 은 그 벡터만 안다.
##
## InputMap 으로 정식화하지 않았다. §14 가 미룬 부채이지만, 그 값어치는 **키 재배치**인데
## 아직 아무도 그것을 필요로 하지 않고, project.godot 에 InputEventKey 를 손으로
## 직렬화하는 것은 이 프로젝트가 반복해서 밟은 함정이다(V1~V3b). 대신 "입력을 읽는
## 자리가 하나" 라는 실질을 여기서 얻는다 — 재배치가 필요해지면 이 함수만 바꾼다.
##
## 우선순위는 키보드 → 터치 → 마우스다. 셋이 동시에 들어오는 상황은 없지만,
## 순서를 고정해야 입력원이 바뀌는 순간에 방향이 튀지 않는다.
func input_dir() -> Vector3:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if v != Vector3.ZERO:
		return v.normalized()

	# 터치: 누른 자리를 원점으로 삼는 **플로팅 조이스틱**. 화면 어디를 눌러도 된다 —
	# 고정 조이스틱은 세로 화면에서 엄지가 닿지 않는 자리에 놓이기 쉽다.
	if _touch_id >= 0:
		var d := _touch_cur - _touch_start
		if d.length() >= TOUCH_DEAD_PX:
			return screen_to_world(d)

	# 마우스: 커서 쪽으로 간다. 데스크톱에서는 이쪽이 조이스틱보다 자연스럽다.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and is_instance_valid(hole) and not cam.is_position_behind(hole.global_position):
		var d2 := get_viewport().get_mouse_position() - cam.unproject_position(hole.global_position)
		if d2.length() >= TOUCH_DEAD_PX:
			return screen_to_world(d2)
	return Vector3.ZERO


## 화면 벡터 → 월드 XZ 방향. 카메라에 요(yaw)가 없고 구멍 바로 뒤 위에서 내려다보므로
## 화면 +x 가 월드 +x, 화면 +y(아래)가 월드 +z 다. 카메라 리그가 바뀌면 여기도 바뀐다.
func screen_to_world(d: Vector2) -> Vector3:
	return Vector3(d.x, 0.0, d.y).normalized()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _touch_id < 0:
			_touch_id = t.index
			_touch_start = t.position
			_touch_cur = t.position
		elif not t.pressed and t.index == _touch_id:
			_touch_id = -1
	elif e is InputEventScreenDrag:
		var g := e as InputEventScreenDrag
		if g.index == _touch_id:
			_touch_cur = g.position


func move_hole(dt: float) -> void:
	var v := input_dir()
	if v == Vector3.ZERO:
		return
	set_hole_position(hole.global_position + v * MOVE_SPEED * dt)


## 구멍이 지면 밖으로 나가면 우물이 허공에 뜨고 판정 전제도 깨진다.
func set_hole_position(p: Vector3) -> void:
	hole.move_to(p)


func _on_swallowed(_node: Node3D) -> void:
	update_hud()


## HUD 문구는 한글이다(§21). 쓰는 음절은 `assets/fonts/hud_kr.ttf` 에 서브셋으로
## 들어 있고, **여기에 새 음절을 쓰면 그 글자는 화면에서 사라진다** — 판정 T8 이
## 현재 HUD 가 그리는 모든 문자에 글리프가 있는지 본다. 문구를 바꾸면
## `assets/fonts/README.md` 의 재생성 절차로 폰트를 다시 만들어야 한다.
func update_hud() -> void:
	if player_alive():
		hud.text = "점수 %d    크기 %.2f    삼킴 %d" % [score, hole.radius, swallowed_total]
	else:
		hud.text = "점수 %d    (먹힘)" % score
	hud_timer.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	hud_board.text = leaderboard_text()
	hud_over.visible = state == State.OVER
	if state == State.OVER:
		var head := "시간 종료" if over_reason == "time" else "먹혔다"
		var mine := "승리" if winner == "P" else "패배"
		hud_over.text = "%s\n1위  %s   %d\n나: %s (%d)\nR 키로 다시 시작"\
			% [head, winner, winner_score, mine, score]


## 리더보드. 점수 내림차순, 동점이면 반경 순.
## 구멍이 진실 원천이므로 여기서는 정렬해 문자열로 만들기만 한다.
func leaderboard_text() -> String:
	var hs := []
	for h in registry.holes():
		if is_instance_valid(h):
			hs.append(h)
	hs.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return float(a.radius) > float(b.radius))
	# 상위 셋 + 나만 보인다. 여섯 줄을 다 세우면 화면 오른쪽이 표로 덮이고,
	# 정작 알고 싶은 것("내가 몇 등인가")은 그 안에 묻힌다.
	var lines := PackedStringArray([" 순위  이름    점수    크기"])
	var mine := -1
	for i in hs.size():
		if str(hs[i].label) == "P":
			mine = i
	for i in hs.size():
		if i >= 3 and i != mine:
			continue
		var h: Node3D = hs[i]
		lines.append("%2d.  %-4s %6d  %5.1f" % [i + 1, h.label, h.score, h.radius])
	return "\n".join(lines)
```

**`judging`은 반드시 일반 `var`여야 한다.** `@onready var judging := false`로 쓰면 `Main._ready` 직전에 대입이 일어나 `Judge._ready`가 세운 값을 덮어쓰고, rev.4의 실패(`base hole_count=1`, `delta 0`, H3=F)가 그대로 재현된다(실측 확인). 일반 `var`의 초기화자는 `PackedScene.instantiate()` 중 객체 생성 시점에 실행되므로 `Judge._ready`보다 확실히 먼저다 — 이는 우연이 아니라 엔진이 보장하는 순서다.

**autoload 접근은 반드시 `get_node("/root/HoleRegistry")`를 쓴다.** 직접 식별자 `HoleRegistry.foo()`는 런타임에서는 동작하지만 `--check-only`가 해석하지 못해 관련 파일이 전부 **위양성 파싱 실패**를 낸다(V16) → §6-1의 종료 코드 게이팅이 통째로 무력해진다. 타입 주석을 붙여도 정적 검사 이득이 없음을 확인했으므로 잃는 것이 없다.

**호출 순서 (V20에서 실측)**
```
Judge._ready  (자식이 먼저)  →  Main._ready  →  첫 _process  →  첫 프레임 렌더
                                  ↑ 이 직전에 엔진이 Main.set_process(true) 를 수행한다
```
따라서 `Judge._ready`에서 부모의 `_process`를 **플래그가 아닌 `set_process`로 끄면 무효화된다.** `judging` 플래그는 스크립트 인스턴스 생성 시점에 초기화되므로 `Judge._ready`에서 안전하게 세울 수 있다.

---

## §5. `project.godot` 전문

```ini
config_version=5

[application]

config/name="holeio"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")

[autoload]

HoleRegistry="*res://scripts/hole_registry.gd"

[display]

window/size/viewport_width=1152
window/size/viewport_height=648

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

renderer/rendering_method="forward_plus"
; 웹은 Forward+ 를 지원하지 않는다(WebGL2 = Compatibility 뿐).
; **이 줄은 엔진 기본값과 같다** — 지워도 웹은 gl_compatibility 로 뜬다(실측: 줄을
; 지우고 돌려도 ProjectSettings 가 gl_compatibility 를 돌려준다). 명시해 두는 것은
; 판정기(H10)가 이 값을 읽어 "웹이 Forward+ 로 바뀌지 않았는가" 를 지키기 위해서다.
; 실측: Compatibility 에서도 착시는 성립한다 — `--rendering-driver opengl3` 로
; 판정 아홉 종을 전부 돌려 전부 PASS 다(§22).
renderer/rendering_method.web="gl_compatibility"
anti_aliasing/quality/msaa_3d=2
```

- **`[display]` 필수**: §6 판정은 전부 픽셀 좌표 기반이고 `unproject_position` 결과가 뷰포트 크기에 의존한다. 1152×648로 고정(실측이 이 크기에서 이뤄졌다).
- **`[autoload]` 필수**: 누락하면 `/root`에 레지스트리가 없어 `main.gd._ready`의 `get_node`가 null을 반환한다.
- **`3d/physics_engine="Jolt Physics"` 필수**: 4.6+에서 바뀐 것은 "에디터가 신규 프로젝트에 이 키를 써 넣는다"일 뿐이다. 키가 없으면 `"DEFAULT"` → GodotPhysics3D로 조용히 떨어진다.
- `msaa_3d=2` = 4x. **A2C는 MSAA 샘플 수만큼의 커버리지 단계를 쓰므로 4x가 곧 엣지 품질이다.**
- `run/main_scene` 경로는 §7 파일 트리와 일치해야 한다.

---

## §6. 검증 절차

### 1단계 — GDScript 파싱 (종료 코드 판정, V15)

```powershell
$GODOT = "C:\Users\bbum_ai\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
$PROJ  = "C:\vibecoding\holeio"
foreach ($f in @("main","hole","hole_registry","screenshot")) {
    & $GODOT --headless --path $PROJ --check-only --script "res://scripts/$f.gd"
    if ($LASTEXITCODE -ne 0) { throw "parse fail: $f" }
}
```
- `--check-only`는 `--script`와 함께 써야 한다([문서](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html): *"Only parse for errors and quit (use with --script)"*). 일괄 처리는 문서화되어 있지 않으므로 파일당 1회 반복.
- **문자열 grep이 아니라 종료 코드로 판정한다.** 전제: §4-G의 `get_node("/root/...")` 규칙(V16).
- **이 게이트의 한계**: GDScript는 unsafe access를 경고로만 처리하므로 `_holes[i].radius`(`Array[Node3D]`에 없는 프로퍼티)나 `get_node(...).get_surface_override_material(0)`(`Node`에 없는 메서드)는 **exit 0으로 통과한다**(실측). 1단계는 구문 오류와 명백한 타입 오류만 잡는다 — 이름 오타류는 2·3단계에서 잡힌다.

### 2·3단계 — 창 모드 실행 + 셰이더 에러 검사 + 기계 판정

```powershell
$p = Start-Process -FilePath $GODOT -ArgumentList @("--path",$PROJ,"--","--judge") `
        -RedirectStandardOutput run.log -RedirectStandardError run.err -PassThru
if (-not $p.WaitForExit(120000)) { $p.Kill(); throw "judge hung (120s timeout)" }
if ($p.ExitCode -ne 0) { throw "judge FAIL (exit $($p.ExitCode))" }

foreach ($f in @("run.log","run.err")) { if (-not (Test-Path $f)) { throw "missing $f" } }
$pat  = "SHADER ERROR|SCRIPT ERROR|USER ERROR|^ERROR:"
$hits = @(Select-String -Path run.log,run.err -Pattern $pat)
if ($hits.Count -gt 0) { $hits; throw "runtime error ($($hits.Count) hits)" }
if (-not (Select-String -Path run.log -Pattern "JUDGE .* -> PASS" -Quiet)) { throw "no PASS line" }
```
- **정규식에 `SCRIPT ERROR`가 반드시 들어가야 한다.** rev.5는 `"SHADER ERROR|^ERROR:"`를 썼는데, `^` 앵커 때문에 GDScript 런타임 오류의 표준 접두사인 `SCRIPT ERROR:`가 통과했다. 실측: `main.gd`에 무해한 런타임 오류를 넣어도 `hits=0`, `EXIT=0`으로 DoD를 통과했다.
- **종료 코드만 믿지 않는다.** `JUDGE ... -> PASS` 문자열의 존재도 함께 확인해, 판정에 도달하지 못하고 우연히 0으로 끝나는 경우를 배제한다.
- `USER ERROR`는 이 프로젝트에서 실제로 관측된 적이 없다(`push_error()`의 실측 접두사는 `ERROR:`다). 방어적으로만 넣어 둔 항목이다.
- **`--headless`는 셰이더 검증에 쓸 수 없다** — dummy 렌더 드라이버라 스파셜 셰이더가 정상 컴파일 경로를 타지 않는다. 실제 GPU가 붙은 창 모드에서만 가능하다(§8).
- **타임아웃 필수**: `run_judge()`가 `quit()` 전에 죽으면 창이 뜬 채 무한 대기한다.
- `--` 뒤 인자는 `OS.get_cmdline_user_args()`로 읽힌다.
- 판정 플래그는 아홉 가지다: `--judge`(1a) / `--judge1b` / `--judge2` / `--judge3`(3a) / `--judge3b`(도시 배치) / `--judge3c`(성능) / `--judge4`(아레나) / `--judge5`(게임 루프) / `--judge6`(수관 걸림). 하나라도 실패하면 회귀다 — 3a의 도시 지면 기준(D1·D2·D4)은 정적 판정을 쓰는 네 가지 전부에 상시 포함된다.
- **`--judge3c` 는 다른 것과 같이 돌리지 않는다.** vsync 를 끄고 프레임 시간을 재므로, 판정 중 다른 창이 GPU 를 쓰면 수치가 흔들린다.

### `scripts/screenshot.gd` (전문 — 실행 검증본)

```gdscript
extends Node

## 1a 기계 판정. `-- --judge` 로 실행할 때만 동작하고, 그 외에는 아무것도 하지 않는다.

const SWALLOWABLE := preload("res://scripts/swallowable.gd")
const SHOT_DIR := "res://shots/"
const WARMUP := 30                                 # 셰이더 파이프라인 워밍업
const EDGE_THR := 0.08
const RING_K := 1.15                               # 누출 검사 영역 = 반경의 몇 배 원반인가
const MAGENTA_TH := 0.4                            # 배경이 지배적으로 섞인 픽셀만 센다
const LEAK_RATE := 0.01                            # 허용 누출 = 림 둘레 픽셀 × 이 비율
const RIM_DIRS := 32                               # 림 AA 를 몇 방향에서 표본하는가
const RIM_STEP_MAX := 0.7                          # 전이의 최대 단차 / 국소 진폭 상한
const RIM_AA_MIN := 4                              # 부드러운 전이가 관측돼야 할 최소 방향 수
const MOVED_TO := Vector3(-6.0, 0.0, 6.0)          # B1: 이동 후 재판정할 위치(오브젝트에서 먼 곳)
const SWALLOW_FRAMES := 2400                       # B2: 흡입에 허용하는 physics 프레임
const SINK_LIMIT := -0.05                          # B3: 낙하 전환 전 허용 최저 y
const HOVER_FRAMES := 150                          # C2: 큰 오브젝트 위에 머물며 게이트를 시험하는 프레임

# --- 3단계 도시 격자 규격 ---------------------------------------------------
# 판정기는 셰이더의 uniform 을 읽지 않는다. 같은 수를 여기에 따로 적어 두고
# 표본 좌표를 이 상수에서 직접 계산한다. uniform 을 읽으면 규격을 바꾼 빌드가
# 자기 값끼리 일치해 그대로 통과한다(1a~2단계에서 여섯 번 밟은 함정).
const SPEC_GROUND_HALF := 224.0                     # 지면 반폭 (표본이 지면 밖으로 나가지 않게)
const SPEC_PITCH := 32.0                           # 도로 중심선 간격
const SPEC_ROAD_HALF := 4.0                        # 일반 도로 아스팔트 반폭
const SPEC_CURB_HALF := 6.0                        # 일반 도로 보도 바깥 경계 반폭
const SPEC_LANE_HALF := 0.30                       # 중앙선 반폭 (가장 가는 특징)
const SPEC_CROSS_W := 1.6                          # 횡단보도 띠 폭
const SPEC_CROSS_PITCH := 1.2                      # 횡단보도 줄무늬 주기
# --- 도로 위계 규격 (§18) --------------------------------------------------
# 아스팔트 반폭이 선 인덱스의 함수가 됐다. 판정기는 그 **함수를** 따로 들고 있어야
# 한다 — 셰이더의 boul_* uniform 을 읽으면 위계를 지운 빌드가 자기 값끼리 일치해
# 그대로 통과한다. 표본 좌표가 전부 여기서 나온다.
const SPEC_BOUL_EVERY := 3                         # k mod 3 == 0 인 중심선이 대로
const SPEC_BOUL_HALF := 6.5                        # 대로 아스팔트 반폭
const SPEC_LANE_GAP := 0.75                        # 대로 이중 중앙선의 중심 오프셋
# --- 지구 지도 규격 (§25) --------------------------------------------------
# **city.gd 의 ZONE_ROWS 를 읽지 않는다.** 읽으면 지도를 바꾼 빌드가 자기 값끼리
# 일치해 그대로 통과한다 — 셰이더의 uniform 을 안 읽는 것과 정확히 같은 이유다.
# 여기가 판정기의 사본이고, 사본이 어긋나는 것 자체가 탈락 사유다.
#     행 r = j + 7,  열 c = k + 7,  spec_zone(k, j) = SPEC_ZONE_ROWS[j+7][k+7]
const SPEC_ZONE_ROWS := [
	"WWWWWWWWWWWWWW",   # j = -7
	"WRRRRRRRRWRRRW",   # j = -6
	"WRRRRRRRRWRRRW",   # j = -5
	"WRRCCCCCCWCRRW",   # j = -4
	"WRRCCCCCCWCRRW",   # j = -3
	"WRRCCDDDDWCRRW",   # j = -2
	"WRRCCDDDDWCRRW",   # j = -1
	"WPPCCDDDDWCRRW",   # j =  0
	"WPPCCDDDDWCRRW",   # j =  1
	"WRRCCCCCCWCRRW",   # j =  2
	"WRRCCCCCCWCPPW",   # j =  3
	"WRRPPRRRRWRPPW",   # j =  4
	"WRRRRRRRRWRRRW",   # j =  5
	"WWWWWWWWWWWWWW",   # j =  6
]
const SPEC_CELL_MIN := -7
const SPEC_CELL_MAX := 6
const SPEC_CELL_COUNT := 14
const SPEC_ZONE_CODE := { "D": 0, "C": 1, "R": 2, "P": 3, "W": 4 }
const SPEC_Z_DOWNTOWN := 0
const SPEC_Z_COMMERCIAL := 1
const SPEC_Z_RESIDENTIAL := 2
const SPEC_Z_PARK := 3
const SPEC_Z_WATER := 4
## 수역을 건너는 동서 도로 세그먼트 [중심선 인덱스, 셀 인덱스].
const SPEC_BRIDGES := [[-3, 2], [0, 2], [3, 2]]

## Z1: 존별 지면색을 **휘도**로 가르면 안 된다 — 네 지구가 전부 [아스팔트, 커브] 사이
## 좁은 띠 안에 있어야 D1·D4 가 성립하므로 휘도만으로는 서로 붙는다. 대신 조명 배율에
## 불변인 **채널 우세도**로 판정한다: 초록 우세 g = G - (R+B)/2, 파랑 우세 b = B - (R+G)/2.
## 규격은 순서다 — 공원이 가장 푸르고 도심이 가장 무채색이며 물만 파랗다.
const ZONE_G_MARGIN := 0.02                        # 이웃 지구 사이 초록 우세도 최소 차
const ZONE_W_MARGIN := 0.05                        # 물의 파랑 우세도 하한
const SURF_DIFF_MIN := 0.05                        # D1: 인접 표면 휘도차 하한
const PERIOD_TOL := 0.05                           # D3: 다른 블록에서 같은 표면의 휘도 허용 편차
const CROSS_GROUPS_MIN := 3                        # D2: 횡단보도 띠에서 세어야 할 엣지 그룹 수
const PROBE_MARGIN_PX := 12                        # 표본이 화면 가장자리에서 떨어져 있어야 할 여유
const PROBE_HOLE_K := 1.6                          # 표본이 구멍 중심에서 떨어져 있어야 할 반경 배수
# 규격 중앙선이 화면에서 이보다 가늘어진 블록은 표본에서 제외한다. 먼 지면에서
# 노면표시가 서브픽셀이 되어 사라지는 것은 결함이 아니라 셰이더의 정상적인 페이드다
# (실측: 64m 지점의 중앙선 휘도 = 아스팔트와 완전히 동일). 폭은 판정기의 SPEC 로
# 계산하므로 중앙선을 아예 안 그린 빌드도 이 필터를 그대로 통과해 D1 에서 걸린다.
## 3.0 은 **부풀려진 폭**을 기준으로 잡힌 값이었다(lane_width_px 참조). 직교 성분으로
## 바로잡자 같은 블록이 3.1 → 2.99 로 내려가 기존 지점의 후보가 전부 사라졌다 —
## 기준을 실측으로 재보정한다. 근거 두 점: §12 가 기록한 "뭉개져 판독 불가" 는 2.3px 이고,
## 2.8px 에서 셰이더 fade 는 0.41 이라 중앙선 휘도가 아스팔트보다 0.17 높다
## (SURF_DIFF_MIN 0.05 의 3.4배 여유). 그 사이에 둔다.
const LANE_MIN_PX := 2.8
# --- 3b 도시 배치 규격 ---------------------------------------------------
const SPEC_PLAZA_R := 26.0                         # E6: 판정 시나리오용 빈 광장 반경
## 게임의 시작 반경. T5(재시작 복원)와 4a 자유 실행의 기준점이다.
const SPEC_START_R := 1.5
## 흡입·성장 시나리오(1b·2단계)가 쓰는 **픽스처 반경**.
## 게임의 시작 반경과 분리한다 — 시작 반경을 5.0 → 1.5 로 줄이자 판정 대상 8개가
## 크기 게이트에 하나도 걸리지 않아 B2·C2 가 시험 자체를 못 하게 됐다(실측).
## 이 시나리오들이 묻는 것은 "흡입·성장 파이프라인이 규격대로 도는가" 이지
## "시작 반경이 얼마인가" 가 아니므로, 픽스처를 고정하는 편이 옳다.
const FIXTURE_R := 5.0
## 2단계의 "거절 → 성장 → 통과" 시나리오가 쓰는 반경(§23).
## 물리가 통과를 정하게 된 뒤로는 **구멍 지름과 물체 폭**의 관계가 곧 규격이다.
## 2.3 은 소형 픽스처는 눕히지 않고도 통과시키고(XZ 외접반경 1.838 < 2.3), 대형은
## 어떤 자세로도 막는다(통과 반경 2.828 > 2.3).
## 소형 6개를 삼키면 R = sqrt(2.3^2 + 6*1.838^2) = 5.06 으로 자라 대형도 열린다.
const GATE_R := 2.3
const MIN_PROPS := 300                             # E1: 도시가 실제로 생성됐는가
## E7a: 대로 규격에서만 가능한 자리에 선 프롭의 하한. 실측값의 절반이다.
## **이 하한이 잡는 것은 "위계가 통째로 사라졌는가"(그때 0 이 된다) 하나뿐이다.**
## 자리 하나를 지우는 정도의 부분 회귀는 비율로 안 걸린다 — 그것은 E7b(자리 구조)가
## 본다. 두 기준의 역할을 섞어서 읽지 마라.
## §25 재유도: 지구제·수계·수퍼블록이 들어오며 실측이 통째로 달라졌다.
## 대로 세그먼트 일부가 사라졌기 때문이다(강 횡단 중 교량 셋만 남고, 공원 내부가
## 걷히고, 바다 테두리에 도로가 없다). 실측 460/640 → 329/304, 하한은 그 절반이다.
const MIN_BOUL_ROAD := 88
const MIN_BOUL_WALK := 162
const MIN_ALBEDOS := 12                            # E1: 단색 팔레트가 실제로 다양한가
const GROUND_TOL := 0.05                           # E5: 접지 허용 오차(월드 단위)
const TILT_TOL := 0.02                             # E5: 직립 허용 기울기(라디안)
const MESH_BOX_TOL := 0.05                         # E5: 콜라이더와 메시의 XZ 허용 어긋남
const SETTLE_FRAMES := 180                         # E5: 정지 판정 전에 돌리는 물리 프레임
const SETTLE_MOVE_TOL := 0.01                      # E5: 그동안 허용되는 최대 이동(월드 단위)

# --- 4a 아레나 판정 -------------------------------------------------------
const ARENA_FRAMES := 900                          # G2·G5: 자유 실행 물리 프레임(15초)
const BITE_FRAMES := 20                            # G3·G4: 포식이 성사될 때까지 주는 프레임
                                                   # (첫 프레임에 성립한다. 길게 잡으면
                                                   #  그사이 오브젝트가 삼켜져 기대값이 흐려진다)
const BITE_R_BIG := 12.0                           # G3·G4 시나리오의 큰 구멍 반경
const BITE_R_SMALL := 4.0                          # G3·G4 시나리오의 작은 구멍 반경
const AREA_TOL := 0.02                             # G2: 면적 보존 허용 오차(R^2 단위)
const EDGE_SLACK := 0.05                           # G5: 지면 경계 허용 여유
## 판정이 유효한 최소 앙각(§8). 이보다 낮게 보이는 구멍은 판정 대상이 아니다.
const MIN_ELEV := deg_to_rad(30.0)
## §15 의 포식 규격. 구현체의 hole_bite_ratio·bite_depth 를 읽으면 규칙을 바꾼
## 빌드가 자기 값끼리 일치해 통과한다 — 판정기가 따로 들고 있어야 한다.
## (실제로 규칙을 0.0 → 0.8 로 바꿨을 때 여기를 안 고쳐 G6 가 16프레임 오검출했다.)
const SPEC_BITE_RATIO := 1.05
const SPEC_BITE_DEPTH := 0.8
## G7: AI 구멍이 자유 실행 동안 최소한 이만큼은 움직여야 한다(월드 단위).
## 속도 12 로 15초면 최대 180m 다 — "멈춰 있지 않다" 를 보는 낮은 문턱이다.
## 30 이었다가 §23 에서 11 로 내렸다. 통과를 물리가 정하게 되면서 AI 가 **자기 자리
## 근처의 것을 바로 먹을 수 있게 됐고**, 그만큼 덜 돌아다닌다(실측: 세 AI 의 이동이
## 44.7 / 37.2 / 21.9, 그동안 반경은 각각 +0.41 / +0.57 / +0.70 자랐다).
## 11 은 그 최솟값 21.9 의 절반이다. 굳은 AI 는 0 이 되므로 변별력은 그대로다.
const AI_MIN_PATH := 11.0
## G7: AI 전체가 자유 실행 동안 자라야 할 반경 합의 하한(§27). 실측 0.418 의 절반이다.
## 성장을 개체마다 묻지 않는 대신(배치의 운이 된다) 합에 하한을 둔다 — 하한이 없으면
## 다섯 중 넷이 죽어도 하나가 아주 조금 자라면 통과한다.
const AI_MIN_GROW := 0.2
const OVERLAP_FRAMES := 300                        # G6 시나리오: 사냥이 성사될 때까지

# --- 4b 게임 루프 판정 ----------------------------------------------------
const ROUND_TEST_SEC := 4.0                        # T1: 판정용 짧은 라운드
const ROUND_TEST_FRAMES := 600                     # T1: 그 라운드를 덮고도 남는 프레임 수
const TIMER_TOL := 0.25                            # T1: 판정기 시계와의 허용 오차(초)
const FREEZE_FRAMES := 120                         # T3: 종료 후 상태 고정을 확인하는 프레임
## 게임 상태의 규격 값(§26). **구현체의 enum 을 읽지 않는다** — 읽으면 상태를 재배치한
## 빌드가 자기 값끼리 일치해 통과한다. 판정기가 정수를 손으로 박아 두었던 자리를
## 이름으로 바꾼 것이기도 하다: HOME 이 앞에 붙으며 PLAYING·OVER 가 한 칸씩 밀렸고,
## 그 순간 T1·T5·T6 이 조용히 엉뚱한 상태를 보고 있었다(실측으로 셋 다 탈락했다).
## 리더보드에 싣는 상위 인원(§26). 그 아래로는 **나만** 더 싣는다.
const SPEC_BOARD_TOP := 3
const SPEC_STATE_HOME := 0
const SPEC_STATE_PLAYING := 1
const SPEC_STATE_OVER := 2
const RESTART_HOLES := 6                           # T5: 재시작 후 구멍 수 (플레이어 + AI 5)
## T5: 재시작 후 도시 프롭 수 (시드 고정). §22 에서 3804 → 3876 이었고,
## §25 에서 3876 → 2236 으로 줄었다. 줄어든 것이 규격이다 — 바다 테두리(52셀)와
## 강(14셀)에는 아무것도 놓지 않고, 공원 9셀은 수퍼블록 셋으로 합쳐 한 번만 채우며,
## 걷힌 도로 위의 보도·차도 프롭이 사라졌다.
const RESTART_PROPS := 2125
## §10 의 성장 계수. 구현체의 hole.growth_k 를 읽으면 계수만 바꾼 빌드가
## 자기 값끼리 일치해 그대로 통과한다 — 규격에서 판정기가 직접 들고 있어야 한다.
const SPEC_GROWTH_K := 1.0

# --- §23 물리 통과 판정 ----------------------------------------------------
## 통과 판정 시행의 기본 구멍 반경. 픽스처 치수가 이 값 둘레에서 정해진다:
##   flat 2x2x2  — XZ 외접반경 1.414 < 2.0  → 눕히지 않고도 통과(K1)
##   wide 6x2x6  — 통과 반경 3.162 > 2.0    → 어떤 자세로도 거절(K2)
##   pole 0.6x8  — 통과 반경 0.424 < 2.0    → 길어도 통과(K6)
const FALL_R := 2.0
## 수관보다 넓은 구멍. 나무 픽스처의 수관(6x6, 외접반경 4.243)보다 커야 한다.
const FALL_BIG_R := 5.0
## K7(§30): 견인 금지 픽스처(wide, fit 3.162 > FALL_R)를 세우는 자리. 콜라이더가
## x∈[1,7] 이라 감지 실린더(반경 2.0)에 확실히 걸치고, 림 바닥판(반경 R+30) 위에
## 온전히 얹혀 가장자리 기울어짐이 없다.
const K7_OFFSET := 4.0
## K7: 변위 허용(m). 흡입이 없으면 평지 정착 후 움직일 이유가 없다 — 예산은 정착
## 잔여 진동 몫이고, 게이트를 지운 주입은 240프레임에 미터 단위로 끌려온다.
const K7_MOVE_MAX := 0.10
## K8(§30): 보장 픽스처. 한 변 2.0 정육면체(fit = 외접 = 1.414, q=1.414)를 구멍
## **옆**에 세운다 — 흡입이 끌어와 삼키는가까지 묻는다(K1 은 정중앙 낙하만 본다).
## 경계에 더 붙이려던 시도는 실측이 기각했다: q=1.053(여유 5%)도 q=1.176(15%)도
## 옆에서 끌려오다 **기울면 투영 반경이 커져 쐐기가 됐다**(최저 y −0.3 에서 끼임).
## 옆-흡입 보장이 성립하는 조건은 외접이 아니라 **공간 대각 반경 < R** 이다 —
## 2×2×2 는 1.732 < 2.0 이라 어떤 자세로 굴러도 낄 수 없다. 게이트 판별 정밀도는
## 그래서 이 괄호까지다: [q=0.63(K7), q=1.41(K8)] 사이의 어긋난 문턱은 못 가른다.
const K8_SIDE := 2.0
const K8_OFFSET := 2.5
## 나무 픽스처: 밑동 0.8 각 3m + 수관 6x6 2m. 밑동만 보면 FALL_R 을 여유 있게
## 통과하지만(0.566 < 2.0) 수관이 걸린다(3.162 > 2.0).
const FALL_TREE := [Vector3(0.8, 3.0, 0.8), Vector3(6.0, 2.0, 6.0)]
## 한 시행에 허용하는 물리 프레임. 통과하는 것은 이보다 훨씬 빨리 빠지고(실측),
## 거절되는 것은 이 내내 남아야 한다.
const FALL_FRAMES := 240
## E8: 메시 반폭이 밑동 셰이프 반폭의 이 배 이상이면 "가지가 있는 프롭" 이다.
## city.gd 의 CANOPY_RATIO 와 같은 값을 판정기가 따로 든다.
const CANOPY_RATIO := 1.5
## E8: 그런 프롭의 하한. 이 하한이 잡는 것은 "밑동 셰이프가 다시 메시 전체가 되어
## 수관이 사라졌는가" 하나다 — 그때 0 이 된다.
## §25 재유도: 실측 955 → 687(도시 총량이 줄었다). 하한은 그 절반이다.
const MIN_CANOPY_PROPS := 354

# --- §21 한글 HUD 판정 -----------------------------------------------------
## 번들 폰트의 경로. 라벨이 이것을 쓰지 않으면 데스크톱에서는 시스템 폴백으로
## 멀쩡히 그려지고 **웹에서만** 글자가 사라진다 — 판정기가 도는 환경에서는 보이지
## 않는 결함이므로 출처를 직접 묻는다.
const HUD_FONT_PATH := "res://assets/fonts/hud_kr.ttf"
## HUD 문구 규격의 한글 음절 전부. 구현체의 문자열만 검사하면 문구를 통째로 영문으로
## 되돌린 빌드가 "쓰는 글자가 전부 있다" 로 통과한다 — 판정기가 따로 들어야 한다.
## 폰트 서브셋(assets/fonts/README.md)과 같은 집합이어야 한다.
## §26 에서 시작·결과 화면과 조작 안내가 붙어 16자가 늘었다(26 → 42).
## `tools/font_subset.mjs` 의 집합과 같아야 한다 — 판정기는 그 파일을 읽지 않고
## 사본을 든다. 어긋나면 T8 이 글리프 없음으로 잡는다.
const SPEC_HUD_CHARS := "점수크기삼킴먹힘순위이름시간종료혔다승리패배나키로작" \
	+ "도를켜라동화살표드래그레벨하홈으"
## T8③: SPEC_HUD_CHARS 를 그린 라벨이 남겨야 할 최소 잉크 픽셀.
## §21 실측 2568 의 1/4 로 잡았고, §26 에서 음절이 42자로 늘어 실측은 3434 다.
const HUD_INK_MIN := 640
## T8②-b: HUD 네 라벨이 그 순간 실제로 그리고 있어야 할 서로 다른 한글 음절 수.
## 실측 21 의 절반이다. 처음에 1/3(7)로 잡았더니 **네 문구 중 셋을 영문으로
## 되돌린 빌드가 정확히 7 로 통과했다** — 게임오버 문구 하나만 한글로 남아도
## 그만큼이 나온다. 절반으로 올리면 그 주입이 7 대 10 으로 갈린다.
const HUD_KR_MIN := 10

# --- 3c 성능 예산 ---------------------------------------------------------
## 성능을 재는 지점 **둘**. 하나로 갈아치우면 안 된다 — §17 이전의 계측과 비교할 수
## 없게 되고(측정 지점이 동시에 바뀌면 증감 주장이 성립하지 않는다), 그 함정을
## 실제로 밟았다(독립 감사가 실측으로 반증했다).
##   dense — §14 부터 써 온 지점. 실측상 드로우콜·프리미티브가 가장 많다(2535 / 2.70M).
##           역대 계측표와 like-for-like 비교를 위해 반드시 유지한다.
##   boul  — z = -96 대로에 접한 블록 중앙. 드로우콜은 더 적지만(2510 / 2.29M)
##           worst 프레임이 2배 나쁘다 — 대로 주변은 밀도가 아니라 **가려짐이 적어**
##           그리기 부담이 몰리는 지점이다. 둘 다 예산 안이어야 통과다.
const PERF_SPOTS := {
	"dense": Vector3(-48.0, 0.0, -48.0),
	"boul": Vector3(-48.0, 0.0, -80.0),
}
const PERF_FRAMES := 300
const FRAME_BUDGET_MS := 16.67                     # 60fps
const OVERLAP_EPS := 0.02                          # E3: SAT 수치 여유
# D5: 구멍을 옮겨 재판정할 규격 지점 (오브젝트가 없는 -x/+z 쪽)
# 앞의 셋에서 `road`·`block` 은 실측상 **인덱스 0 대로(z=0)** 를 표본한다(로그의 k·등급
# 참조). 대로 표본이 실제로 잡혔는가는 D6 가 단언하므로 우연에 기대지 않는다.
#
# 카메라가 구멍 +z 뒤 16.5m 에 있고 probe_blocks 가 sz = -1 을 먼저 시도하므로,
# 구멍을 대로의 +z 쪽 블록 안에 두면 최근접 블록의 sz = -1 도로가 곧 그 대로가 된다.
# 대로가 카메라에서 32.5m 여야 한다 — 16m 더 멀면 중앙선이 2.2px 로 뭉개져
# LANE_MIN_PX 에 걸리고, 구멍을 블록 **정중앙**에 두면 블록 표본이 구멍과 겹쳐
# "구멍근접" 으로 전부 탈락한다(둘 다 실측으로 밟았다).
const CITY_SPOTS := {
	"inter": Vector3(-32.0, 0.0, 32.0),            # 교차로 중심 (|ux|=0, |uz|=0)
	"road": Vector3(-32.0, 0.0, 16.0),             # 도로 위·교차로 밖 (|ux|=0, |uz|=16)
	"block": Vector3(-16.0, 0.0, 16.0),            # 블록 중앙 (|ux|=16, |uz|=16)
	# 인덱스 3 대로(z=96). 위상이 어긋난 빌드(boul_every 3 → 4)는 여기를 일반 도로로
	# 그려 D1 이 탈락한다 — 인덱스 0 은 3 으로도 4 로도 대로라 위상을 검출하지 못한다.
	# 덤으로 구멍이 x=0 대로 위에 있어 D5 가 "넓은 도로도 똑같이 뚫리는가" 를 본다.
	"boul_far": Vector3(0.0, 0.0, 112.0),
}

var _main: Node3D
var _cam: Camera3D
var _mat: ShaderMaterial
var _reg: Node
var _clamped := false                              # px() 가 화면 밖을 잘라냈는가
var _was_falling := {}                             # B3: 낙하 전환을 한 번만 채점한다
var _r_cache := {}                                 # true_radius 캐시(get_debug_mesh 는 비싸다)
var _blocks_ok := {}                               # D3: D1·D2 를 통과한 서로 다른 블록
var _boul_ok := false                              # D6: 대로를 표본해 D1·D2 를 통과했는가


# --- 도로 위계 규격 파생 (§18) ---------------------------------------------
# 셰이더·city.gd 와 같은 함수를 판정기가 **따로** 들고 있다.

## 좌표 → 가장 가까운 도로 중심선의 인덱스. 셰이더의 floor((p + hp)/pitch) 와
## 같은 식이어야 한다 — round() 는 0.5 를 0에서 멀어지게 반올림해 블록 정중앙의
## 음수 쪽(w = -16, -48 …)에서 한 칸 어긋나고, 그러면 판정기와 셰이더가 서로 다른
## 선을 대로로 본다.
func spec_line_index(w: float) -> int:
	return floori(w / SPEC_PITCH + 0.5)


func spec_is_boulevard(k: int) -> bool:
	return posmod(k, SPEC_BOUL_EVERY) == 0


func spec_road_half(k: int) -> float:
	return SPEC_BOUL_HALF if spec_is_boulevard(k) else SPEC_ROAD_HALF


## 보도 폭은 위계와 무관하게 일정하다.
func spec_curb_half(k: int) -> float:
	return spec_road_half(k) + (SPEC_CURB_HALF - SPEC_ROAD_HALF)


## 차량이 넘어설 수 없는 중앙 분리대의 안쪽 경계.
func spec_median(k: int) -> float:
	return (SPEC_LANE_GAP + SPEC_LANE_HALF) if spec_is_boulevard(k) else 0.0


## 중앙선 **도색**의 중심까지의 거리. 대로는 중앙선이 ±SPEC_LANE_GAP 두 줄로 갈라져
## |u| = 0 이 아스팔트다 — 여기를 안 옮기면 정상 빌드가 D1 에서 탈락한다.
## (city.gd 의 LANE 자리는 주행 차선 중심이라 완전히 다른 양이다. 이름을 구분한다.)
func spec_lane_mark_u(k: int) -> float:
	return SPEC_LANE_GAP if spec_is_boulevard(k) else 0.0


# --- 지구 지도 파생 (§25) — 전부 판정기의 사본에서만 계산한다 ------------------

func spec_cell_of(w: float) -> int:
	return clampi(floori(w / SPEC_PITCH), SPEC_CELL_MIN, SPEC_CELL_MAX)


func spec_zone(k: int, j: int) -> int:
	var c := clampi(k - SPEC_CELL_MIN, 0, SPEC_CELL_COUNT - 1)
	var r := clampi(j - SPEC_CELL_MIN, 0, SPEC_CELL_COUNT - 1)
	return int(SPEC_ZONE_CODE[(SPEC_ZONE_ROWS[r] as String)[c]])


func spec_zone_at(p: Vector3) -> int:
	return spec_zone(spec_cell_of(p.x), spec_cell_of(p.z))


func spec_is_bridge_ew(jl: int, kc: int) -> bool:
	for b in SPEC_BRIDGES:
		if int(b[0]) == jl and int(b[1]) == kc:
			return true
	return false


func spec_seg_rule(a: int, b: int, bridge: bool) -> bool:
	if a == SPEC_Z_WATER or b == SPEC_Z_WATER:
		return bridge
	return not (a == SPEC_Z_PARK and b == SPEC_Z_PARK)


func spec_seg_ew(jl: int, kc: int) -> bool:
	return spec_seg_rule(spec_zone(kc, jl - 1), spec_zone(kc, jl), spec_is_bridge_ew(jl, kc))


func spec_seg_ns(kl: int, jc: int) -> bool:
	return spec_seg_rule(spec_zone(kl - 1, jc), spec_zone(kl, jc), false)


## 구멍이 이 자리에 있을 수 있는가 — Z5 의 규격이다.
func spec_passable(p: Vector3) -> bool:
	var k := spec_cell_of(p.x)
	if spec_zone(k, spec_cell_of(p.z)) != SPEC_Z_WATER:
		return true
	var jl := spec_line_index(p.z)
	return spec_is_bridge_ew(jl, k) \
		and absf(p.z - float(jl) * SPEC_PITCH) <= spec_road_half(jl)


## 공원 수퍼블록의 축별 병합 범위. E2 가 "블록 구간 안인가" 를 물을 때 쓴다.
func spec_merge(k: int, j: int, along_k: bool) -> Vector2i:
	var v := k if along_k else j
	if spec_zone(k, j) != SPEC_Z_PARK:
		return Vector2i(v, v)
	var lo := v
	while lo > SPEC_CELL_MIN \
			and spec_zone(lo - 1 if along_k else k, j if along_k else lo - 1) == SPEC_Z_PARK:
		lo -= 1
	var hi := v
	while hi < SPEC_CELL_MAX \
			and spec_zone(hi + 1 if along_k else k, j if along_k else hi + 1) == SPEC_Z_PARK:
		hi += 1
	return Vector2i(lo, hi)


## 판정 인자의 전체 목록이자 **고르는 우선순위**다. 웹 쿼리는 외부 입력이라 이
## 화이트리스트를 거쳐야만 분기로 들어간다 — 임의의 문자열이 판정 이름 자리에
## 앉지 않게 한다(§24). 접두사가 겹치므로(`--judge` 가 `--judge3b` 의 앞부분)
## 긴 것부터 본다.
const JUDGE_ORDER := ["--judge10", "--judge9", "--judge8", "--judge7", "--judge6",
	"--judge5", "--judge4", "--judge3c", "--judge3b", "--judge3", "--judge2",
	"--judge1b", "--judge"]


## 이번 실행이 돌릴 판정 하나. 없으면 빈 문자열이다.
##
## 판정 인자는 데스크톱에서 명령줄로 온다. **브라우저에는 명령줄이 없다** —
## 그래서 §22 까지 브라우저에서 돈 기계 판정은 0회였다. 웹에서는 쿼리 문자열을
## 같은 인자로 옮긴다: `?judge=6` → `--judge6`, `?judge=` → `--judge`.
##
## **고르는 자리를 하나로 둔다.** 인자가 둘 이상 들어와도 도는 것은 하나인데,
## 분기와 하네스 보고가 각자 고르면 "판정 A 의 결과" 자리에 판정 B 의 결과가
## 기록된다.
func judge_flag() -> String:
	var args: Array = Array(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("window.location.search", true))
		for pair in q.trim_prefix("?").split("&", false):
			var kv := pair.split("=", true, 1)
			if kv.size() == 2 and kv[0] == "judge":
				args.append("--judge" + kv[1].uri_decode())
	for f in JUDGE_ORDER:
		if f in args:
			return f
	return ""


## 브라우저 안의 판정 결과를 하네스로 내보내는 통로(§24).
## Godot 의 `print` 는 `console.log` 로 나간다(엔진의 `onPrint` 가 호출 시점에
## `console.log` 를 찾으므로 나중에 감싸도 걸린다). 그 줄을 전부 모아 두고
## `JUDGE RESULT ->` 를 보는 순간 하네스에 되돌려 보낸다.
##
## **결과가 오지 않는 것을 통과로 읽으면 안 된다.** 하네스는 신호가 도착해야만
## 판정을 마치고, 도착하지 않으면 시간 초과로 FAIL 한다 — 페이지가 아예 안 뜨거나
## 판정이 중간에 죽은 경우가 "지적사항 없음" 으로 둔갑하는 것이 이 판정의 가장
## 큰 위험이다. 종료 직전에 보내지 않고 **결과 줄을 보는 즉시** 보내는 것도 같은
## 이유다(quit 뒤에는 프레임이 더 안 돌아 fetch 가 출발하지 못할 수 있다).
func web_beacon(flag: String) -> void:
	JavaScriptBridge.eval("""
window.__JUDGE = {flag: %s, ua: navigator.userAgent, lines: [], result: "", sent: false};
(function () {
	var orig = console.log;
	console.log = function () {
		var s = Array.prototype.map.call(arguments, String).join(" ");
		var j = window.__JUDGE;
		j.lines.push(s);
		if (!j.sent && s.indexOf("JUDGE RESULT ->") >= 0) {
			j.sent = true;
			j.result = s.indexOf("PASS") >= 0 ? "PASS" : "FAIL";
			document.title = "JUDGE " + j.flag + " " + j.result;
			var body = JSON.stringify(j);
			try {
				navigator.sendBeacon("/judge-result",
					new Blob([body], {type: "application/json"}));
			} catch (e) {
				fetch("/judge-result", {method: "POST", body: body, keepalive: true});
			}
			// 다음 판정으로 넘어가는 것은 하네스가 정한다. 여기서 하는 일은
			// "나는 끝났다" 를 들고 /next 를 두드리는 것뿐이다 — 브라우저를 판정마다
			// 손으로 다시 여는 것을 없애려는 것이고, 순서·목록은 서버가 쥔다.
			// 하네스가 서빙한 페이지에서만 넘어간다. 배포본에 `?judge=` 를 붙여 연
			// 사람을 있지도 않은 경로로 보내지 않는다.
			if (location.hostname === "127.0.0.1" || location.hostname === "localhost") {
				setTimeout(function () { window.location.replace("/next?after=" + j.flag); }, 500);
			}
		}
		orig.apply(console, arguments);
	};
})();
""" % JSON.stringify(flag), true)


func _ready() -> void:
	var flag := judge_flag()
	if flag.is_empty():
		return
	if OS.has_feature("web"):
		web_beacon(flag)
	_main = get_parent()
	_main.judging = true          # main.gd._ready 보다 먼저 실행된다 (자식 → 부모)
	# 1a~3단계 판정은 전부 "구멍 하나" 를 전제로 세워졌다. 4단계 판정에서만 아레나를 켠다.
	_main.arena = flag == "--judge4" or flag == "--judge5"
	process_mode = Node.PROCESS_MODE_ALWAYS    # 정적 판정 중 트리를 멈춰도 자신은 돈다
	match flag:
		"--judge10": await run_judge_10()
		"--judge9": await run_judge_9()
		"--judge8": await run_judge_8()
		"--judge7": await run_judge_7()
		"--judge6": await run_judge_6()
		"--judge5": await run_judge_5()
		"--judge4": await run_judge_4()
		"--judge3c": await run_judge_3c()
		"--judge3b": await run_judge_3b()
		"--judge3": await run_judge_3()
		"--judge2": await run_judge_2()
		"--judge1b": await run_judge_1b()
		_: await run_judge()
	# 판정이 결과 줄을 내지 못하고 끝나는 길이 있다(setup() 실패 등은 곧바로 quit 한다).
	# 웹에서는 그 침묵이 하네스의 시간 초과로만 드러나 원인이 "안 떴다" 와 구분되지
	# 않는다. quit 요청 뒤에도 이 프레임은 끝까지 도므로, 여기서 대신 FAIL 을 낸다.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
if (window.__JUDGE && !window.__JUDGE.sent) {
	console.log("JUDGE RESULT -> FAIL (판정이 결과를 내지 못하고 끝났다)");
}
""", true)


func setup() -> bool:
	_cam = _main.get_node("Camera3D")
	_mat = _main.get_node("Ground").get_surface_override_material(0)
	_reg = get_node("/root/HoleRegistry")
	# 없으면 여기서 즉시 죽는다. 이 검사가 없으면 아래 set_shader_parameter 가
	# null 접근으로 중단되어 quit() 에 도달하지 못하고 무한 대기가 된다(실측).
	if _mat == null:
		push_error("Ground.surface_material_override/0 is null (material_override 를 쓰지 않았는가?)")
		return false
	return true


func run_judge() -> void:
	if not setup():
		get_tree().quit(1)
		return
	var ok := await judge_static("")
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## 정적 판정 1회: 기준·판정·탐침 프레임을 찍고 H1~H10 을 평가한다.
## allow_no_block: 지면 표본 블록을 하나도 못 찾았을 때 D 기준을 "미적용" 으로
## 넘길지 여부. 기본값은 false — 표본을 못 찾는 것은 보통 판정 전제가 깨진 것이다.
## 4단계에서만 true 를 쓴다: 구멍이 크게 자라면 카메라가 그만큼 물러나 규격
## 노면표시가 화면에서 서브픽셀이 되고, 그때 D 는 물을 수 없는 질문이 된다.
## 이 완화가 셰이더 결함의 도피처가 되지는 않는다 — 블록 유효성 판정은 전부
## 판정기의 SPEC 상수와 투영 기하로만 계산하므로, 도로를 안 그린 빌드에서도
## 블록은 그대로 유효하고 D1 이 잡는다.
## props_hidden: 이 판정 내내 씬 오브젝트를 숨긴다. 4단계의 G1 에서 쓴다 —
## G1 이 묻는 것은 "여러 구멍이 한 셰이더로 동시에 제대로 그려지는가" 이고,
## 도시가 구멍을 가리는 것은 그 질문과 무관한 배치 문제다(§6 의 선언된 전제).
## 실측: 교차로에 스폰한 구멍도 6m 앞의 차량·가로시설물이 림 스캔에 섞여
## H2·H8 이 무너졌다.
func judge_static(prefix: String, allow_no_block := false, props_hidden := false) -> bool:
	_main.judging = true
	# 물리를 멈춘다. 멈추지 않으면 캡처 90프레임 동안 흡입이 진행되어
	# 기준 프레임과 판정 프레임의 씬이 달라진다(실측: 그 사이 2개가 삼켜졌다).
	get_tree().paused = true

	# --- 패스 0: 지면 전용 프레임 (씬 오브젝트를 전부 숨긴다) ---
	# 3b 에서 도시가 들어서면 어떤 지면 표본도 건물·나무의 가림과 그림자에서 자유롭지
	# 않다. 근접 휴리스틱으로는 못 막는다 — 15m 건물의 가림 범위는 앙각 40°에서
	# 18m 에 달한다. D1·D2·D4 는 "지면 셰이더가 무엇을 칠했는가" 를 재는 기준이므로
	# 오브젝트를 숨긴 프레임에서 재는 것이 기준의 정의에 맞다.
	var hidden := hide_props()
	var ground := await capture(prefix + "ground")
	if not props_hidden:
		restore_props(hidden)

	# --- 패스 1: 기준 프레임 (구멍 없음) ---
	_mat.set_shader_parameter("hole_count", 0)
	var base := await capture(prefix + "base")

	# --- 패스 2: 판정 프레임 ---
	_reg.flush()
	var shot := await capture(prefix + "shot")

	# --- 패스 3: 누출 탐침 프레임 (배경만 마젠타로 강제) ---
	# 배경색을 씬 팔레트와 무관한 색으로 바꿔 찍으면, 구멍 안에 배경이 새는지를
	# 지면·우물 색과 상관없이 판정할 수 있다. V21 이 실제로 쓴 방법이다.
	# 전제: ambient_light_source 가 Color(=2) 이므로 배경색이 조명에 영향을 주지 않는다.
	var env: Environment = _main.get_node("WorldEnvironment").environment
	var saved_bg := env.background_color
	env.background_color = Color(1, 0, 1)
	var probe := await capture(prefix + "probe")
	env.background_color = saved_bg
	if props_hidden:
		restore_props(hidden)
	get_tree().paused = false
	_main.judging = false

	# 지면 기준 휘도는 "블록 중앙"에서 잰다. 3단계에서 지면은 더 이상 균질하지
	# 않으므로 절대 좌표 상수를 쓰면 도로 위에 떨어져 H1·H2 임계가 무너진다.
	var holes: Array = _reg.holes()
	var blocks := probe_blocks(holes, shot)
	if blocks.is_empty():
		if not allow_no_block:
			print("JUDGE %scity FAIL: 화면 안인 블록 중앙을 찾지 못했다" % prefix)
			return false
		print("JUDGE %scity D 미적용: 이 카메라 거리에서는 규격 노면표시가 서브픽셀이다"
			% prefix)
	# 표본 블록이 없으면 지면 기준 휘도는 카메라 정면의 지면에서 잰다.
	var lum_g := lum_at(ground,
		blocks[0][0] if not blocks.is_empty() else camera_focus())

	# 배경 휘도는 탐침 프레임에서 실제로 마젠타인 모서리를 찾아 그 좌표로 잰다.
	# 고정 좌표 (4,4) 는 지면이 넓어지면 배경이 아니게 되어 H6 가 무의미해진다.
	var bg_px := background_pixel(probe)
	if bg_px.x < 0:
		print("JUDGE %sbg FAIL: 탐침 프레임 위쪽 절반에 배경(마젠타)이 없다" % prefix)
		return false
	var lum_bg := shot.get_pixel(bg_px.x, bg_px.y).get_luminance()

	# --- 전역 기준 ---
	var h4 := check_uniforms()
	var h5: bool = ProjectSettings.get_setting("physics/3d/physics_engine", "") == "Jolt Physics"
	var h10 := check_pipeline()
	var dcity := judge_city(prefix, ground, blocks)

	# --- 구멍별 기준: 화면 안에 있는 구멍을 전부 판정한다 ---
	# 화면 밖 구멍까지 판정하면 표본이 클램프되어 판정 자체가 무효가 된다(4단계).
	# 화면 밖 구멍은 이 프레임에서 "제대로 그려졌는가" 를 물을 대상이 아니다 —
	# 4단계의 G1 이 카메라를 구멍마다 옮겨 가며 따로 판정한다.
	var seen := onscreen_holes(holes, shot)
	var per_hole := seen.size() > 0
	for i in seen.size():
		per_hole = judge_hole(seen[i], i, base, shot, probe, lum_g, lum_bg) and per_hole

	var all_pass := per_hole and h4 and h5 and h10 and dcity and not _clamped
	print("JUDGE %sglobal H4=%s H5=%s H10=%s D=%s bg=%s clamped=%s holes=%d/%d -> %s"
		% [prefix, pf(h4), pf(h5), pf(h10), pf(dcity), str(bg_px), _clamped,
		   seen.size(), holes.size(), ("PASS" if all_pass else "FAIL")])
	return all_pass


## 림까지 화면 안에 들어오고, **앙각이 충분한** 구멍만 남긴다.
## 앙각 조건이 필요한 이유: 지평선 근처의 구멍은 근측 림이 우물 안쪽을 가려
## "구멍 안" 표본이 지면을 읽는다(실측: R=31 구멍이 화면 상단에서 H2 ring 상한
## 0.6314 = 지면 휘도, inside=false). §8 이 "커버리지 AA 는 앙각 30° 아래에서
## 무너진다" 고 선언한 그 범위 밖이며, 판정의 유효 전제이지 결함이 아니다.
func onscreen_holes(holes: Array, img: Image) -> Array:
	var out := []
	for h in holes:
		if not is_instance_valid(h):
			continue
		if elevation(h.global_position) < MIN_ELEV:
			continue
		# 다른 구멍과 원반이 겹친 구멍은 판정 대상이 아니다. 다중 구멍 SDF 는
		# 합집합 하나로 그려지므로 "구멍 하나 = 원반 하나" 라는 H1·H2 의 전제가
		# 그 상태에서는 성립하지 않는다. 겹침이 **해소되는가** 는 G6 가 따로 본다.
		var overlapped := false
		for g in holes:
			if g == h or not is_instance_valid(g):
				continue
			if flat_dist(g.global_position, h.global_position) \
					< float(g.radius) + float(h.radius):
				overlapped = true
				break
		if overlapped:
			continue
		var ok := true
		for k in RIM_DIRS:
			var a := TAU * float(k) / float(RIM_DIRS)
			var p: Vector3 = h.global_position \
				+ Vector3(cos(a), 0.0, sin(a)) * float(h.radius) * RING_K
			if _cam.is_position_behind(p):
				ok = false
				break
			var v := _cam.unproject_position(p)
			if v.x < 0.0 or v.y < 0.0 or v.x > float(img.get_width() - 1) \
					or v.y > float(img.get_height() - 1):
				ok = false
				break
		if ok:
			out.append(h)
	return out


# --- 1b 판정 --------------------------------------------------------------

## B1: 구멍을 옮긴 뒤에도 착시가 유지되는가 (카메라를 정면으로 스냅하고 H1~H10 재판정)
## B2: 모든 흡입 대상이 제한 시간 안에 소멸하는가
## B3: 낙하 전환 전 오브젝트가 지면 아래로 가라앉지 않는가 (§4-D-2 가 막으려던 것)
func run_judge_1b() -> void:
	if not setup():
		get_tree().quit(1)
		return

	# Judge._ready 는 Main._ready 보다 먼저 돈다(자식 → 부모). 등록을 기다린다.
	await get_tree().process_frame
	var hole: Node3D = _reg.holes()[0]
	hole.set_radius(FIXTURE_R)          # 흡입 시나리오는 픽스처 반경에서 돈다

	# --- B1: 이동 후 착시 유지 ---
	_main.set_hole_position(Vector3(MOVED_TO.x, 0.0, MOVED_TO.z))
	_reg.flush()
	_cam.follow(hole, hole.radius, true)
	var b1 := await judge_static("moved_")

	# --- B2·B3: 흡입 ---
	_main.judging = false
	var objs: Array = get_tree().get_nodes_in_group("judge_set")
	var n0 := objs.size()
	var sink := 0
	var collide := 0
	var worst := 0.0
	var frames := 0
	while frames < SWALLOW_FRAMES and alive_count(objs) > 0:
		# 아직 낙하 전환되지 않은 가장 가까운 대상 위로 구멍을 몬다.
		# 전부 낙하 중이면 제자리에서 소멸을 기다린다(여기서 루프를 끊으면 안 된다).
		var target := nearest_alive(objs, hole.global_position)
		if target != null:
			var to := target.global_position - hole.global_position
			to.y = 0.0
			var step: float = minf(to.length(), _main.MOVE_SPEED / 60.0)
			if step > 0.0001:
				_main.set_hole_position(hole.global_position + to.normalized() * step)
		# B3 은 연속 상태가 아니라 **전환 순간**을 본다.
		# 낙하 중인 오브젝트는 구멍이 다음 대상으로 옮겨가면 자연히 "구멍 밖"이 되므로,
		# 상태로 판정하면 정상 빌드도 위반으로 센다(실측 142건).
		# §4-D-2 가 경고한 실패는 "통과 조건을 만족하지 않았는데 낙하로 전환되어
		# 구멍 옆 단단한 지면 속으로 가라앉는" 것이다.
		for o in objs:
			if not is_instance_valid(o):
				continue
			var id: int = o.get_instance_id()
			if o.falling and not _was_falling.has(id):
				_was_falling[id] = true
				var dxz: float = Vector2(o.global_position.x - hole.global_position.x,
					o.global_position.z - hole.global_position.z).length()
				# §23 이후 전환 시점은 **물리**가 정한다("지면 아래로 내려갔다").
				# 그러니 물을 것은 "기하 조건을 만족했는가" 가 아니라
				# **"그때 물체가 구멍 위에 있었는가"** 다 — 구멍 밖 지면 아래로
				# 내려간 채 전환됐다면 그것이 곧 "땅에서 녹아 사라진" 것이다.
				# 반경은 구현체를 믿지 않고 콜라이더에서 직접 잰다.
				var margin: float = hole.radius - (dxz - true_fit(o))
				worst = minf(worst, margin)
				if margin < 0.0:
					sink += 1
					print("JUDGE 1b  구멍 밖에서 낙하 전환: dist=%.3f - fit=%.3f > R=%.3f (margin %.3f)"
						% [dxz, true_fit(o), hole.radius, margin])
				# B4: 낙하 전환 후에는 지면·다른 오브젝트 어느 쪽과도 충돌하면 안 된다.
				# Godot 판정은 OR 이므로 양방향을 모두 본다.
				for other in objs:
					if other == o or not is_instance_valid(other) or other.falling:
						continue
					if (o.collision_layer & other.collision_mask) != 0 \
							or (other.collision_layer & o.collision_mask) != 0:
						collide += 1
						print("JUDGE 1b  falling body still collides: layer=%d mask=%d vs layer=%d mask=%d"
							% [o.collision_layer, o.collision_mask,
							   other.collision_layer, other.collision_mask])
						break
			elif not o.falling and o.global_position.y < SINK_LIMIT \
					and not over_hole(o, hole):
				# 구멍 위가 아닌데 지면 아래로 내려갔다 = 단단한 지면을 뚫었다.
				# 구멍 위에서 기울며 잠기는 것은 §23 이 노린 정상 거동이다.
				sink += 1
				print("JUDGE 1b  지면 관통: %s y=%.3f dist=%.3f fit=%.3f R=%.3f"
					% [o.name, o.global_position.y,
					   flat_dist(o.global_position, hole.global_position),
					   true_fit(o), hole.radius])
		await get_tree().physics_frame
		frames += 1

	var left := 0
	for o in objs:
		if is_instance_valid(o):
			left += 1
	var b2 := left == 0
	var b3 := sink == 0
	var b4 := collide == 0
	var ok := b1 and b2 and b3 and b4

	print("JUDGE 1b swallowed=%d/%d left=%d frames=%d sink_violations=%d collide_violations=%d worst_margin=%.3f"
		% [_main.swallowed_total, n0, left, frames, sink, collide, worst])
	print("JUDGE 1b B1=%s B2=%s B3=%s B4=%s -> %s"
		% [pf(b1), pf(b2), pf(b3), pf(b4), ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func nearest_alive(objs: Array, from: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for o in objs:
		if not is_instance_valid(o) or o.falling:
			continue
		var d: float = Vector2(o.global_position.x - from.x, o.global_position.z - from.z).length()
		if d < bd:
			bd = d
			best = o
	return best


func judge_hole(h: Node3D, idx: int, base: Image, shot: Image, probe: Image,
		lum_g: float, lum_bg: float) -> bool:
	var C: Vector3 = h.global_position
	var R: float = h.radius
	var p_c := px(C, shot)
	var lum_c := shot.get_pixelv(p_c).get_luminance()

	# 우물 내부를 반경 0.6R 링 위 RIM_DIRS 방향에서 표본한다.
	# 특정 월드 축(±x)에 고정하면 구멍이 움직이거나 태양 방위가 바뀔 때 무의미해진다.
	var lum_lo := 1.0
	var lum_hi := 0.0
	var inside := true
	for k in RIM_DIRS:
		var a := TAU * float(k) / float(RIM_DIRS)
		var l := shot.get_pixelv(px(C + Vector3(cos(a), 0.0, sin(a)) * R * 0.6, shot)).get_luminance()
		lum_lo = minf(lum_lo, l)
		lum_hi = maxf(lum_hi, l)
		inside = inside and l <= lum_g * 0.5      # H2 전제: 표본이 전부 구멍 안

	var poly := ring_poly(C, R * RING_K)
	var leak := magenta_pixels(probe, poly)
	var tol := int(round(rim_perimeter_px(C, R) * LEAK_RATE))
	var aa := rim_aa(shot, C, R)                         # x=통과 방향 수, y=유효 방향 수
	var g_base := edge_groups(base, p_c.y)
	var g_shot := edge_groups(shot, p_c.y)

	var h1 := lum_c <= lum_g * 0.5
	var h2 := inside and (lum_hi - lum_lo) >= 0.02
	# H6(중심 휘도가 배경과 구별되는가)은 §24 에서 게이트에서 내렸다 — H3 와 같은 이유다.
	# 묻는 것은 "구멍 안이 배경이 비쳐 보이는 구멍(월드를 뚫은 구멍)이 아닌가" 인데,
	# 이 씬에서는 우물 안도 하늘도 둘 다 어두워 판별 폭이 팔레트와 백엔드에 달려 있다.
	# 실측(정상 빌드, 같은 커밋):
	#   Forward+          중심 0.1548 배경 0.2115 → 0.0567  통과
	#   브라우저 WebGL2    중심 0.1817 배경 0.0905 → 0.0912  통과
	#   데스크톱 opengl3   중심 0.1817 배경 0.1849 → **0.0032  탈락**
	# 세 값 중 다른 것은 **배경 휘도뿐**이다. 같은 빌드·같은 렌더링 백엔드인데
	# 클리어 색이 데스크톱과 브라우저에서 다르게 읽힌다. 정상 빌드가 재는 사람의
	# 백엔드에 따라 탈락하는 수는 게이트가 될 수 없다.
	#
	# 표본 좌표는 정상이다. bg=(50,2) 은 화면 꼭대기의 하늘이고, 저장된 프레임에서
	# 직접 읽어도 같은 값이다(shot.png (50,2) = RGB 46,47,52 → 0.1846). 즉 **재는
	# 자리가 틀린 것이 아니라, 렌더된 하늘과 우물 안의 휘도가 실제로 붙어 있다.**
	#
	# 그리고 **H6 은 자기가 이름 붙인 결함을 잡지도 못했다.** 우물 메시를 숨겨
	# 배경이 원반 안으로 그대로 비치게 한 주입에서 H6 은 두 백엔드 모두 통과했다
	# (dCB = 0.1210 / 0.0944). 그 프레임에서 중심은 0.0905 로 읽히는데 꼭대기 하늘은
	# 0.2115 다 — 같은 배경인데 두 자리의 값이 다르다. **왜 다른지는 규명하지 않았다.**
	# 다만 그 차이가 있는 한 "중심 == 배경" 은 성립하지 않고, H6 은 배경이 그대로
	# 비치는 프레임을 통과시킨다. 잡은 것은 H7(leak 1862/2, 1856/2)과 H2(dRing 0.0000)다.
	#
	# **같은 질문의 강한 판본이 이미 있다.** H7 은 배경을 **마젠타로 바꿔** 놓고
	# 원반 안의 마젠타 픽셀을 센다(정상 빌드 실측 leak=0/2) — 마젠타는 어떤 씬
	# 팔레트와도 겹치지 않으므로 지면·우물 색을 바꿔도, 백엔드를 바꿔도 흔들리지 않는다.
	# 진단용으로 계속 찍는다.
	var h6 := absf(lum_c - lum_bg) >= 0.03
	var h7 := leak <= tol                                # 이음새·정렬: 배경이 새지 않는다
	# 하드 알파는 어느 방향에서도 부드러운 전이가 없다(실측 0/32).
	# A2C 는 서브픽셀 정렬에 따라 방향별 편차가 크므로(11~24/32) 하한만 요구한다.
	var h8 := aa.y >= RIM_DIRS / 2 and aa.x >= RIM_AA_MIN
	var need_depth := 2.0 * R * tan(elevation(C))
	var depth: float = h.well_depth()
	var h9 := depth >= need_depth                        # 우물 바닥이 보이지 않는다
	# H3(엣지 그룹 증분)은 3단계에서 폐기했다. 지면에 도로 스트라이프가 생기면
	# 기준·판정 프레임이 같은 엣지를 세어 정상 빌드가 탈락한다(실측 base=9 shot=10).
	# 윤곽의 존재는 H7(이음새)·H8(림 AA)이 더 강하게 판정한다. 진단용으로만 남긴다.
	var ok: bool = h1 and h2 and h7 and h8 and h9

	print("JUDGE hole%d px c=%s | lum c=%.4f ring[%.4f..%.4f] g=%.4f bg=%.4f dRing=%.4f dCB=%.4f inside=%s"
		% [idx, str(p_c), lum_c, lum_lo, lum_hi, lum_g, lum_bg,
		   lum_hi - lum_lo, absf(lum_c - lum_bg), inside])
	print("JUDGE hole%d groups %d->%d (H3 폐기, 진단용) | leak=%d/%d rim_aa=%d/%d depth=%.2f/%.2f"
		% [idx, g_base, g_shot, leak, tol, aa.x, aa.y, depth, need_depth])
	print("JUDGE hole%d H1=%s H2=%s H6=%s(폐기, 진단용) H7=%s H8=%s H9=%s -> %s"
		% [idx, pf(h1), pf(h2), pf(h6), pf(h7), pf(h8), pf(h9),
		   ("PASS" if ok else "FAIL")])
	return ok


## H4: uniform 이름·타입·크기·내용. 등록된 모든 슬롯의 반경이 유효해야 한다.
func check_uniforms() -> bool:
	var names := {}
	for u in _mat.shader.get_shader_uniform_list():
		names[u["name"]] = int(u["type"])
	if not (names.has("holes") and names.has("hole_count")):
		return false
	if names["holes"] != TYPE_PACKED_VECTOR4_ARRAY:
		return false
	var rb: Variant = _mat.get_shader_parameter("holes")     # 리터럴 이름 고정
	var n: int = _reg.hole_count()
	if typeof(rb) != TYPE_PACKED_VECTOR4_ARRAY or rb.size() != 16:
		return false
	if int(_mat.get_shader_parameter("hole_count")) != n:
		return false
	for i in n:
		if rb[i].w <= 0.0:
			return false
	return true


## H10: §2·§5 의 결정이 유지되는가 — 렌더러와 셰이더 render_mode 를 직접 단언한다.
## 픽셀 휴리스틱(H8)만으로는 아트 변경에 가려질 수 있으므로 구조적으로도 막는다.
## 착시가 서 있는 파이프라인 전제를 **설정과 런타임 양쪽에서** 확인한다.
##
## 웹 렌더링 방식을 함께 단언한다(§22). 웹은 Forward+ 를 지원하지 않으므로 이 값이
## 어긋나면 브라우저에서 렌더러 초기화가 실패한다 — 데스크톱 실행에는 아무 영향이
## 없어서 판정 아홉 종이 전부 통과한 채 배포본만 죽는다.
##
## **다만 이 검사가 무는 범위는 좁다.** `rendering_method.web` 은 project.godot 에
## 없어도 엔진 기본값이 이미 `gl_compatibility` 다(실측: 그 줄을 지우고 돌려도
## 판정기가 gl_compatibility 를 읽는다). 그러니 이 검사가 잡는 것은 **누가 그 값을
## 다른 것으로 바꿔 놓는 경우** 하나이고, 줄을 지우는 것은 잡지 못한다 — 잡을 것이
## 없기 때문이다. project.godot 의 그 줄은 설정이라기보다 문서에 가깝다.
##
## 실행 렌더러는 **런타임에서** 읽어 로그에 남긴다. 프로젝트 설정만 보면
## `--rendering-driver opengl3` 로 돌린 판정도 "forward_plus" 라고 보고한다.
##
## **기대값은 실행 플랫폼의 함수다(§24).** `rendering_method` 를 무조건
## `forward_plus` 로 단언하면 브라우저 판정이 **정상 빌드에서** 탈락한다 —
## 웹 익스포트본에서 그 키는 언제나 `gl_compatibility` 로 읽히기 때문이다.
## 데스크톱에서는 관측할 수 없는 사실이었다.
##
## 처음에 그 이유를 "익스포트가 `.web` 오버라이드를 기본 키에 적용한다" 고 적었다가
## **고장 주입에 반증당했다**: `.web` 을 `forward_plus` 로 바꾼 빌드에서도 기본 키는
## 그대로 `gl_compatibility` 였다(설정=gl_compatibility, 웹=forward_plus). 오버라이드가
## 적용된 것이 아니라 **익스포터가 웹 기본값을 그 키에 써 넣는다.** 두 키는 독립이다.
##
## 웹에서는 **런타임 렌더러까지** 단언한다. 설정만 보는 것보다 강하다 — 같은 주입에서
## 실행 렌더러가 실제로 `forward_plus` 로 떴고(실측), 그것은 설정 검사가 아니라
## 이 검사가 무는 자리다. 데스크톱에서는 런타임을 단언하지 않는다: §22 의
## `--rendering-driver opengl3` 회귀가 같은 코드로 돌아야 한다.
func check_pipeline() -> bool:
	var web := OS.has_feature("web")
	var code: String = _mat.shader.code
	var ok := code.contains("alpha_to_coverage") and code.contains("depth_prepass_alpha")
	ok = ok and int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)) > 0
	ok = ok and str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) \
		== ("gl_compatibility" if web else "forward_plus")
	ok = ok and str(ProjectSettings.get_setting("rendering/renderer/rendering_method.web", "")) \
		== "gl_compatibility"
	ok = ok and (not web or RenderingServer.get_current_rendering_method() == "gl_compatibility")
	print("JUDGE pipeline: 실행 렌더러=%s 설정=%s 웹=%s msaa=%d 플랫폼=%s"
		% [RenderingServer.get_current_rendering_method(),
		   str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		   str(ProjectSettings.get_setting("rendering/renderer/rendering_method.web", "")),
		   int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)),
		   "web" if web else "desktop"])
	return ok


# --- 3단계: 도시 지면 판정 --------------------------------------------------

## 블록 중앙 b 에서 파생되는 규격 표면 4종의 대표점.
## sz(±1)는 네 변 중 어느 쪽 도로를 보는가다. 한쪽으로 고정하면 구멍의 위치에 따라
## 표본이 카메라에서 16m 더 멀어져 중앙선이 서브픽셀이 된다(실측: judge3 의
## road·block 지점에서 유효 블록 0개). 규격은 네 변이 대칭이므로 양쪽을 다 시도한다.
## 좌표를 전부 SPEC_* 에서 계산하므로, 셰이더가 다른 주기·폭을 쓰면 표본이
## 엉뚱한 표면에 떨어져 D1 이 무너진다 — 그것이 이 기준의 검출력이다.
## 표본 대상은 z = b.z + sz*half 의 도로다. **sz 의 부호가 곧 그 도로의 인덱스를
## 결정하므로 한쪽으로 고정하지 않는다** — 고정하면 대로 옆 블록에서 규격 좌표가
## 엉뚱한 등급으로 계산되어 정상 빌드가 탈락한다.
func surf_points(b: Vector3, sz: float) -> Array:
	var half := SPEC_PITCH * 0.5
	var z := b.z + sz * half
	var k := spec_line_index(z)
	var rh := spec_road_half(k)
	var ch := spec_curb_half(k)
	return [
		b,                                                       # 블록   |uz| = 16
		Vector3(b.x, 0.0, z - sz * (rh + ch) * 0.5),             # 보도   일반 5   / 대로 7.5
		Vector3(b.x, 0.0, z - sz * rh * 0.5),                    # 아스팔트 일반 2   / 대로 3.25
		Vector3(b.x, 0.0, z - sz * spec_lane_mark_u(k)),         # 중앙선 일반 0   / 대로 0.75
	]


## 횡단보도 띠를 가로지르는 선분의 두 끝점.
## (sx, sz) 가 가리키는 교차로의 바깥쪽 — |ux| = road_half + cross_w/2 (띠 안),
## |uz| <= 3 (도로 위). 점 하나로는 줄무늬의 틈에 떨어질 수 있으므로 선분으로 본다.
## 띠의 위치는 **가로지르는 x 선의 등급**에서 나온다(sx 부호가 그 인덱스를 정한다).
func cross_segment(b: Vector3, sx: float, sz: float) -> Array:
	var half := SPEC_PITCH * 0.5
	var rx := spec_road_half(spec_line_index(b.x + sx * half))
	var x := b.x + sx * (half - (rx + SPEC_CROSS_W * 0.5))
	var z := b.z + sz * half
	return [Vector3(x, 0.0, z - 3.0), Vector3(x, 0.0, z + 3.0)]


## 지면 전용 프레임을 찍기 위해 지면·조명·환경만 남기고 전부 숨긴다.
## 되돌릴 수 있도록 원래 visible 값을 함께 돌려준다.
func hide_props() -> Array:
	var saved := []
	for n in ["City", "Swallowables", "RefBox", "HUD"]:
		var node := _main.get_node_or_null(n)
		if node != null:
			saved.append([node, node.visible])
			node.visible = false
	return saved


func restore_props(saved: Array) -> void:
	for pair in saved:
		pair[0].visible = pair[1]


## 카메라 정면 광선이 지면(y=0)과 만나는 점 = 화면 한가운데의 지면.
func camera_focus() -> Vector3:
	var o := _cam.global_position
	var d := -_cam.global_basis.z
	if d.y > -1e-4:
		return Vector3(o.x, 0.0, o.z)
	return o + d * (-o.y / d.y)


## 규격 중앙선의 화면 폭(픽셀). 구현체가 아니라 SPEC_LANE_HALF 로 계산한다.
##
## **선을 가로지르는 두 점의 화면 거리를 그대로 쓰면 안 된다.** 표본 블록이 카메라의
## x 에서 벗어나면 그 화면 변위에 소실점 방향 성분 — 즉 **선을 따라가는 성분** — 이
## 섞여 폭이 부풀려진다. 실측: 축상 블록은 3.1px(기하 계산과 일치)인데 32m 벗어난
## 블록은 6.2px 로 찍혔고 실제 직교 폭은 3.9px 였다(1.6배). 그 상태의 LANE_MIN_PX 는
## 가드로 작동하지 않는다 — 뭉개진 중앙선을 가진 블록을 그대로 통과시킨다.
## 선 방향을 화면에서 직접 구해 그 **직교 성분만** 폭으로 센다.
func lane_width_px(b: Vector3, sz: float) -> float:
	var z := b.z + sz * SPEC_PITCH * 0.5
	var c := z - sz * spec_lane_mark_u(spec_line_index(z))     # 실제 도색 위치
	var a := Vector3(b.x, 0.0, c - SPEC_LANE_HALF)
	var d := Vector3(b.x, 0.0, c + SPEC_LANE_HALF)
	# 선 방향(도로는 x 축을 달린다). 짧으면 투영 오차에 묻히므로 넉넉히 잡는다.
	var e := Vector3(b.x - 4.0, 0.0, c)
	var f := Vector3(b.x + 4.0, 0.0, c)
	for p in [a, d, e, f]:
		if _cam.is_position_behind(p):
			return 0.0
	var dir := _cam.unproject_position(f) - _cam.unproject_position(e)
	if dir.length() < 1e-6:
		return _cam.unproject_position(a).distance_to(_cam.unproject_position(d))
	var n := Vector2(-dir.y, dir.x).normalized()               # 화면에서 선에 직교
	return absf((_cam.unproject_position(d) - _cam.unproject_position(a)).dot(n))


## 중앙선의 휘도. 점 하나가 아니라 **줄 안을 훑는 짧은 선분의 최대값**으로 잰다.
## px() 의 반올림(±0.5px)만 흡수하면 되므로 선분은 줄 반폭의 절반(±0.15m)이다.
##
## **선분을 넓히면 안 된다.** ±0.6m 로 잡았더니, 대로 표본(|u| = 0.75)의 선분이
## |u| ∈ [0.15, 1.35] 까지 뻗어 **일반 중앙선 한 줄([-0.3, 0.3])의 가장자리를 주웠고**,
## 대로에 한 줄만 그린 고장 빌드가 그대로 통과했다(실측: 주입 #2 가 PASS). 좁히자
## 선분은 [0.60, 0.90] 이 되어 그 줄에서 1.6px 떨어진다 — 규격대로 아스팔트를 읽는다.
func lane_lum(img: Image, b: Vector3, sz: float) -> float:
	var z := b.z + sz * SPEC_PITCH * 0.5
	var c := z - sz * spec_lane_mark_u(spec_line_index(z))
	var a := Vector3(b.x, 0.0, c - SPEC_LANE_HALF * 0.5)
	var d := Vector3(b.x, 0.0, c + SPEC_LANE_HALF * 0.5)
	var mid := Vector3(b.x, 0.0, c)
	if _cam.is_position_behind(a) or _cam.is_position_behind(d):
		return lum_at(img, mid)
	var line := sample_line(img, _cam.unproject_position(a), _cam.unproject_position(d))
	if line.is_empty():
		return lum_at(img, mid)          # 선분이 1픽셀 미만이면 점으로 되돌린다
	var best := 0.0
	for v in line:
		best = maxf(best, float(v))
	return best


## 대로 중앙 분리대의 휘도 — 두 줄 **사이**(|u| = 0)를 읽는다.
##
## 이것이 없으면 "이중 중앙선" 이라는 규격의 정의가 검증되지 않는다. D1 은 |u| = 0.75 에
## 도색이 있는지만 보므로, 대로 중앙을 **폭 2.1m 통짜 노란 띠**로 칠한 빌드
## (`aa_band(ux, lane_gap + lane_half)`)가 판정 8종을 전부 통과했다 — 실측으로 확인했다.
## 오히려 중앙선 휘도가 0.7203 → 0.8434 로 **올라가** D1 을 더 여유 있게 넘긴다.
## 두 줄 사이가 아스팔트라는 것이 `median_at = 1.05`(차량이 넘지 못하는 경계)의
## 렌더 근거이므로, 규격이 주장하는 것을 판정기가 직접 읽어야 한다.
## |ux| = 16(블록 중앙)에서 재므로 중앙선이 끊기는 교차로에 걸리지 않는다.
func median_gap_lum(img: Image, b: Vector3, sz: float) -> float:
	return lum_at(img, Vector3(b.x, 0.0, b.z + sz * SPEC_PITCH * 0.5))


## 표본 지점이 쓸 수 있는지. 못 쓰면 이유 문자열, 쓸 수 있으면 "" 를 돌려준다.
## 이유를 남기지 않으면 "유효 블록 0개" 로 실패했을 때 원인을 짚을 단서가 없다.
func probe_why(p: Vector3, holes: Array, img: Image) -> String:
	if absf(p.x) > SPEC_GROUND_HALF or absf(p.z) > SPEC_GROUND_HALF:
		return "지면밖"
	if _cam.is_position_behind(p):
		return "카메라뒤"
	var v := _cam.unproject_position(p)
	if v.x < PROBE_MARGIN_PX or v.y < PROBE_MARGIN_PX \
			or v.x > float(img.get_width() - PROBE_MARGIN_PX) \
			or v.y > float(img.get_height() - PROBE_MARGIN_PX):
		return "화면밖%s" % str(v.round())
	for h in holes:
		if not is_instance_valid(h):
			continue
		var hp: Vector3 = h.global_position
		if Vector2(p.x - hp.x, p.z - hp.z).length() < float(h.radius) * PROBE_HOLE_K:
			return "구멍근접"
	return ""


func probe_ok(p: Vector3, holes: Array, img: Image) -> bool:
	return probe_why(p, holes, img).is_empty()


## 판정 표본에 쓸 후보 목록 [블록 중앙, sx, sz] — 파생 표본이 전부 화면 안이고
## 구멍·오브젝트에서 떨어졌으며 규격 중앙선이 화면에서 충분히 굵은 것만 남기고,
## 구멍에 가까운 순으로 돌려준다. 블록당 (sx, sz) 조합은 최초로 유효한 하나만 쓴다.
## 절대 좌표 상수(rev.8 의 GROUND_SAMPLE)를 쓰면 도시 격자에서 도로 위에 떨어진다.
func probe_blocks(holes: Array, img: Image) -> Array:
	# 표본 탐색의 기준점은 "화면 한가운데의 지면" 이다. holes[0] 을 쓰면 4단계에서
	# 카메라를 AI 구멍으로 옮겼을 때 기준점이 화면 밖(플레이어 구멍)에 머문다.
	var c := camera_focus()
	var half := SPEC_PITCH * 0.5
	var k0 := int(floor((c.x - half) / SPEC_PITCH))
	var j0 := int(floor((c.z - half) / SPEC_PITCH))
	var found := []
	var why := []
	for dk in range(-2, 3):
		for dj in range(-2, 3):
			var kc := k0 + dk
			var jc := j0 + dj
			var b := Vector3(float(kc) * SPEC_PITCH + half, 0.0,
				float(jc) * SPEC_PITCH + half)
			# §25: D 계열 표본은 "블록 지면 + 보도 + 아스팔트 + 중앙선" 넷을 전제한다.
			# 공원·수역 셀에는 그 넷이 없다 — 표본을 옮긴다(건너뛴다).
			# 존을 안 거르면 정상 빌드가 공원 잔디를 아스팔트로 알고 D1 에서 탈락한다.
			var dz := spec_zone(kc, jc)
			if dz == SPEC_Z_PARK or dz == SPEC_Z_WATER:
				why.append("(%.0f,%.0f):존%d" % [b.x, b.z, dz])
				continue
			for sz in [-1.0, 1.0]:
				# 그 변의 동서 도로가 실제로 존재해야 표본이 의미를 갖는다.
				if not spec_seg_ew(spec_line_index(b.z + sz * half), kc):
					why.append("(%.0f,%.0f)sz%.0f:동서도로없음" % [b.x, b.z, sz])
					continue
				if lane_width_px(b, sz) < LANE_MIN_PX:
					why.append("(%.0f,%.0f)sz%.0f:중앙선%.1fpx" % [b.x, b.z, sz, lane_width_px(b, sz)])
					continue
				var bad := ""
				for p in surf_points(b, sz):
					if bad.is_empty():
						bad = probe_why(p, holes, img)
				if not bad.is_empty():
					why.append("(%.0f,%.0f)sz%.0f:%s" % [b.x, b.z, sz, bad])
					continue
				var picked := false
				for sx in [-1.0, 1.0]:
					# 횡단보도는 **가로지르는 남북 도로**가 있어야 존재한다.
					# 사유를 남긴다 — 후보가 전부 이 이유로 죽으면 "후보 전부 탈락: "
					# 뒤가 비어 원인을 못 읽는다.
					if not spec_seg_ns(spec_line_index(b.x + sx * half), jc):
						why.append("(%.0f,%.0f)s(%.0f,%.0f):남북도로없음" % [b.x, b.z, sx, sz])
						continue
					var seg_bad := ""
					for p in cross_segment(b, sx, sz):
						if seg_bad.is_empty():
							seg_bad = probe_why(p, holes, img)
					if seg_bad.is_empty():
						found.append([b, sx, sz])
						picked = true
						break
					why.append("(%.0f,%.0f)s(%.0f,%.0f):횡단보도 %s" % [b.x, b.z, sx, sz, seg_bad])
				if picked:
					break
	if found.is_empty():
		print("JUDGE probe_blocks 후보 전부 탈락: %s" % ", ".join(why))
	found.sort_custom(func(x: Array, y: Array) -> bool:
		return (x[0] as Vector3).distance_to(c) < (y[0] as Vector3).distance_to(c))
	return found


## D1: 규격이 지정한 4종 지면(블록·보도·아스팔트·중앙선)이 서로 구별되는가.
## D2: 횡단보도 줄무늬가 그려졌는가.
## D4: 어떤 지면도 우물만큼 어둡지 않은가 — 아트가 H1 임계를 무력화하지 못하게 한다.
## D3(주기성)은 여기서 판정하지 않는다. 게임 카메라의 화각(구멍 기준 약 55m)이
## 격자 주기(32m)의 1.7배뿐이라 한 프레임에 규격 조건을 만족하는 블록이 보통
## 하나뿐이다(실측). 통과한 블록을 _blocks_ok 에 모아 두고, 구멍을 격자의 다른
## 칸으로 옮겨 가며 도는 run_judge_3 에서 "서로 다른 블록 2개 이상"으로 판정한다.
func judge_city(prefix: String, shot: Image, blocks: Array) -> bool:
	var use: Array = blocks.slice(0, 2)          # 구멍에 가장 가까운 두 후보
	var d1 := true
	var d2 := true
	var d4 := true
	for cand in use:
		var b: Vector3 = cand[0]
		var sx: float = cand[1]
		var sz: float = cand[2]
		var k := spec_line_index(b.z + sz * SPEC_PITCH * 0.5)   # 표본한 도로의 인덱스
		var l := []
		for p in surf_points(b, sz):
			l.append(lum_at(shot, p))
		l[3] = lane_lum(shot, b, sz)                            # 중앙선만 선분 최대값으로
		var seg: Array = cross_segment(b, sx, sz)
		var groups := edge_groups_line(sample_line(shot,
			_cam.unproject_position(seg[0]), _cam.unproject_position(seg[1])))
		var b1: bool = absf(l[0] - l[1]) >= SURF_DIFF_MIN \
			and absf(l[1] - l[2]) >= SURF_DIFF_MIN \
			and absf(l[2] - l[3]) >= SURF_DIFF_MIN
		# 대로만: 두 줄 사이가 아스팔트여야 한다 — 그것이 "이중" 의 정의다.
		# 아스팔트와 같고(<) 중앙선과 달라야(>=) 한다. 통짜 띠는 둘 다 어긴다.
		var lm := -1.0
		if spec_is_boulevard(k):
			lm = median_gap_lum(shot, b, sz)
			b1 = b1 and absf(lm - l[2]) < SURF_DIFF_MIN \
				and absf(lm - l[3]) >= SURF_DIFF_MIN
		var b2 := groups >= CROSS_GROUPS_MIN
		var b4: bool = l[1] > l[0] * 0.5 and l[2] > l[0] * 0.5 and l[3] > l[0] * 0.5
		d1 = d1 and b1
		d2 = d2 and b2
		d4 = d4 and b4
		if b1 and b2:
			_blocks_ok[Vector2i(roundi(b.x), roundi(b.z))] = true
			if spec_is_boulevard(k):
				_boul_ok = true                                 # D6
		print("JUDGE %scity b(%.0f,%.0f)s(%.0f,%.0f) k=%d %s block=%.4f curb=%.4f road=%.4f lane=%.4f 분리대=%.4f cross=%d lanepx=%.1f D1=%s D2=%s D4=%s"
			% [prefix, b.x, b.z, sx, sz, k,
			   ("대로" if spec_is_boulevard(k) else "일반"),
			   l[0], l[1], l[2], l[3], lm, groups,
			   lane_width_px(b, sz), pf(b1), pf(b2), pf(b4)])
	if use.is_empty():
		return true                       # 미적용 — 호출자가 allow_no_block 으로 허용했다
	var ok := d1 and d2 and d4
	print("JUDGE %scity blocks=%d/%d D1=%s D2=%s D4=%s -> %s"
		% [prefix, use.size(), blocks.size(), pf(d1), pf(d2), pf(d4),
		   ("PASS" if ok else "FAIL")])
	return ok


func lum_at(img: Image, p: Vector3) -> float:
	return img.get_pixelv(px(p, img)).get_luminance()


## 탐침 프레임에서 실제로 배경(마젠타)인 픽셀을 찾는다.
## 고정 좌표 (4,4) 는 지면이 넓어지면 배경이 아니게 되어 H6 가 의미를 잃는다.
## 네 모서리만 보는 것도 부족하다 — 카메라를 당기고 도시를 채우자 모서리마다
## 원경의 건물이 걸려 "네 모서리가 모두 배경이 아니다" 로 판정이 무효화됐다(실측).
## 배경은 화면 위쪽에만 남으므로, 위에서부터 아래로 훑으며 처음 만나는 것을 쓴다.
##
## **성기게 훑으면 안 된다.** 옛 격자(y 4칸·x 16칸)는 화면의 1/64 만 봤는데, 이 배경
## 띠는 원경에서 **최상단 몇 픽셀**로 눌린 활 모양이라(shots/boul_far_probe.png) 캔버스
## 크기가 조금만 달라져도 격자가 통째로 비켜간다 — 데스크톱 1152x648 은 통과하고
## 브라우저는 창 크기 셋(1568x779·1160x760·900x900)에서 전부 "배경이 없다" 로 떨어졌다.
## 그것은 렌더 결함이 아니라 **판정이 증거를 못 찾은 것**이고, 그대로 두면 브라우저
## 게이트가 창 크기에 따라 뒤집히는 위약이 된다.
## 요구하는 증거는 그대로다(마젠타 우세 픽셀이 실제로 있어야 한다) — 탐색만 촘촘히 한다.
## 보통 첫 몇 행에서 찾고 곧장 빠져나오므로 비용도 거의 없다.
func background_pixel(probe: Image) -> Vector2i:
	var w := probe.get_width()
	var h := probe.get_height()
	for y in range(0, h / 2):
		for x in range(0, w, 2):
			var c := probe.get_pixel(x, y)
			if minf(c.r, c.b) - c.g > MAGENTA_TH:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## 휘도열에서 급변 구간을 그룹으로 병합해 센다 (edge_groups 의 임의 선분 버전).
func edge_groups_line(vals: PackedFloat32Array) -> int:
	var groups := 0
	var run := false
	for i in range(1, vals.size()):
		if absf(vals[i] - vals[i - 1]) > EDGE_THR:
			if not run:
				groups += 1
				run = true
		else:
			run = false
	return groups


## D5: 구멍을 규격 지점(교차로·도로 위·블록 중앙)마다 옮겨 재판정한다.
## 도로도 같은 지면 셰이더가 그리므로, 구멍은 도로 위에서도 똑같이 뚫려야 한다.
func run_judge_3() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var hole: Node3D = _reg.holes()[0]
	_main.hud_root.visible = false
	var ok := true
	for key in CITY_SPOTS:
		_main.set_hole_position(CITY_SPOTS[key])
		_reg.flush()
		_cam.follow(hole, hole.radius, true)
		var r := await judge_static(str(key) + "_", false, true)
		print("JUDGE 3 spot=%s at %s -> %s" % [key, str(hole.global_position), pf(r)])
		ok = ok and r
	_main.hud_root.visible = true
	# D3: 격자가 실제로 주기적인가 — 서로 다른 격자 칸 2개 이상에서 D1·D2 가 성립했는가.
	# 휘도의 상등이 아니라 "분류가 재현되는가"로 본다. 먼 블록은 서브픽셀 페이드로
	# 노면표시가 정당하게 흐려지므로 휘도 상등을 요구하면 정상 빌드가 탈락한다.
	var d3 := _blocks_ok.size() >= 2
	# D6: 도로 위계가 **판정에 실제로 걸렸는가**. probe_blocks 는 sz 를 [-1, +1] 순으로
	# 시도해 처음 유효한 하나에서 멈추고 judge_city 는 거리순 상위 2개만 보므로,
	# 대로를 한 번도 표본하지 않은 채 D1 이 PASS 할 수 있다. 그러면 위계에 관한 모든
	# 고장 주입이 조건부가 된다. 이 기준은 오늘의 고장을 잡는 것이 아니라 **내일의
	# 커버리지 소실을 막는 가드**다 — 카메라·아트·지점이 바뀌어 대로가 표본에서
	# 빠지면 여기서 즉시 드러난다.
	var d6 := _boul_ok
	var all_ok := ok and d3 and d6
	print("JUDGE 3 D5=%s D3=%s D6=%s blocks_ok=%s -> %s"
		% [pf(ok), pf(d3), pf(d6), str(_blocks_ok.keys()),
		   ("PASS" if all_ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if all_ok else "FAIL"))
	get_tree().quit(0 if all_ok else 1)


# --- 3b: 도시 배치 판정 ----------------------------------------------------

## 지역 AABB 를 월드로 옮겨 XZ 바닥 다각형·최저 y·XZ 크기를 낸다.
## 8꼭짓점을 실제로 변환하므로 회전이 90° 배수가 아니어도 정확하다
## (생성기는 90° 단위만 쓰지만 판정기가 그 전제를 믿을 이유는 없다).
func world_box(xf: Transform3D, ab: AABB, into: PackedVector2Array) -> float:
	var min_y := INF
	for i in 8:
		var p: Vector3 = xf * (ab.position + Vector3(
			ab.size.x * float(i & 1), ab.size.y * float((i >> 1) & 1),
			ab.size.z * float((i >> 2) & 1)))
		min_y = minf(min_y, p.y)
		into.append(Vector2(p.x, p.z))
	return min_y


## 프롭의 콜라이더 상자와 **보이는 메시**를 둘 다 잰다.
## 콜라이더만 재면 안 된다 — 메시 피벗 보정을 통째로 지운 빌드가 그대로 통과했다
## (실측). 콜라이더는 제자리인데 모델만 공중에 뜨거나 지면에 박힌 상태다.
func prop_box(o: Node3D) -> Dictionary:
	var quad := PackedVector2Array()
	var min_y := INF
	for c in o.find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		min_y = minf(min_y, world_box(o.global_transform * col.transform,
			col.shape.get_debug_mesh().get_aabb(), quad))
	var mesh_pts := PackedVector2Array()
	var mesh_y := INF
	for c in o.find_children("", "MeshInstance3D", false, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		mesh_y = minf(mesh_y, world_box(mi.global_transform, mi.mesh.get_aabb(), mesh_pts))
	# 분리축은 다각형의 **변**에서 나온다. 변환한 꼭짓점을 담긴 순서대로 이으면
	# 대각선이 변으로 잡혀 엉뚱한 축을 시험하게 되고, 실제로는 떨어져 있는 상자가
	# 겹쳤다고 나온다(실측: 차선 반대편 차량 7쌍이 위양성). 볼록껍질로 순서를 잡는다.
	var hull := Geometry2D.convex_hull(quad)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	return { "pts": hull, "min_y": min_y, "mesh_y": mesh_y,
		"xz_gap": xz_mismatch(quad, mesh_pts) }


## 콜라이더 XZ 상자가 **메시 밖으로 얼마나 삐져나왔는가**(월드 단위, 안쪽이면 0).
##
## 처음에는 두 상자의 크기가 같은지를 봤는데, 3b 재조정에서 콜라이더 XZ 를
## 메시 전체가 아니라 **밑동**에서 따게 바뀌었다(나무의 가지를 물리에서 놓아주기
## 위해서다 — 그러지 않으면 구멍이 몸통보다 훨씬 커도 크기 게이트에 걸린다).
## 그래서 콜라이더가 메시보다 작은 것은 이제 설계다. 남은 불변식은
## "물리가 그림보다 크지는 않다" 이고, 그것을 잰다.
func xz_mismatch(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.is_empty() or b.is_empty():
		return INF
	var alo := a[0]
	var ahi := a[0]
	for p in a:
		alo = alo.min(p)
		ahi = ahi.max(p)
	var blo := b[0]
	var bhi := b[0]
	for p in b:
		blo = blo.min(p)
		bhi = bhi.max(p)
	# a = 콜라이더, b = 메시. 콜라이더가 메시 경계를 넘어선 양만 센다.
	return maxf(maxf(blo.x - alo.x, blo.y - alo.y),
		maxf(maxf(ahi.x - bhi.x, ahi.y - bhi.y), 0.0))


## 볼록 다각형 두 개가 겹치는가 (분리축 정리, XZ 평면).
func convex_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for q in [a, b]:
		for i in q.size():
			var e: Vector2 = q[(i + 1) % q.size()] - q[i]
			if e.length_squared() < 1e-9:
				continue
			var ax := Vector2(-e.y, e.x).normalized()
			var a0 := INF
			var a1 := -INF
			var b0 := INF
			var b1 := -INF
			for p in a:
				var d := ax.dot(p)
				a0 = minf(a0, d)
				a1 = maxf(a1, d)
			for p in b:
				var d2 := ax.dot(p)
				b0 = minf(b0, d2)
				b1 = maxf(b1, d2)
			if a1 < b0 + OVERLAP_EPS or b1 < a0 + OVERLAP_EPS:
				return false
	return true


## |u| 가 [lo, hi] 구간을 훑을 때의 최소·최대 절대값.
func abs_range(lo: float, hi: float) -> Vector2:
	var mn := 0.0 if (lo <= 0.0 and hi >= 0.0) else minf(absf(lo), absf(hi))
	return Vector2(mn, maxf(absf(lo), absf(hi)))


## E2: 프롭이 도로·보도·블록 중 **한 구역 안에 온전히** 들어가는가.
## 구역 경계는 판정기의 SPEC_* 로만 계산한다 — 카탈로그를 읽지 않으므로
## 배치 규격을 바꾼 빌드가 자기 값끼리 일치해 통과하는 일이 없다.
## 프롭 발자국을 가장 가까운 도로 중심선 기준으로 정리한다. zone_of 와 E7 이 함께 쓴다.
## 오브젝트가 한 주기보다 작으므로 이 기준에서는 mod 의 접힘을 걱정할 필요가 없다.
## 인덱스는 셰이더와 같은 식(floor(w/P + 0.5))으로 뽑는다 — round() 는 블록 정중앙의
## 음수 쪽에서 한 칸 어긋나 등급 판정이 갈린다.
func footprint(pts: PackedVector2Array) -> Dictionary:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var kx := spec_line_index(c.x)
	var kz := spec_line_index(c.y)
	var cx := float(kx) * SPEC_PITCH
	var cz := float(kz) * SPEC_PITCH
	var xlo := INF
	var xhi := -INF
	var zlo := INF
	var zhi := -INF
	for p in pts:
		xlo = minf(xlo, p.x - cx)
		xhi = maxf(xhi, p.x - cx)
		zlo = minf(zlo, p.y - cz)
		zhi = maxf(zhi, p.y - cz)
	return { "kx": kx, "kz": kz, "xlo": xlo, "xhi": xhi, "zlo": zlo, "zhi": zhi,
		"ax": abs_range(xlo, xhi), "az": abs_range(zlo, zhi) }


## 셀 (k, j) 의 블록 구간(월드 절대 좌표). 공원이면 **병합 구간**이다.
## 대로가 한쪽에만 붙은 블록은 좌우 여백이 다르므로(8.5 대 6.0) 두 경계선을 각각 본다.
func spec_block_span(k: int, j: int, along_k: bool) -> Vector2:
	var m := spec_merge(k, j, along_k)
	return Vector2(float(m.x) * SPEC_PITCH + spec_curb_half(m.x),
		float(m.y + 1) * SPEC_PITCH - spec_curb_half(m.y + 1))


func zone_of(pts: PackedVector2Array) -> String:
	var fp := footprint(pts)
	var kx: int = fp["kx"]
	var kz: int = fp["kz"]
	var ax: Vector2 = fp["ax"]
	var az: Vector2 = fp["az"]
	var rx := spec_road_half(kx)
	var rz := spec_road_half(kz)
	# 발자국 중심이 속한 셀. 존 판정과 도로 존재 판정이 둘 다 이것을 쓴다.
	var cc := Vector2.ZERO
	for p in pts:
		cc += p
	cc /= float(pts.size())
	var kc := spec_cell_of(cc.x)
	var jc := spec_cell_of(cc.y)
	# §25: 수역 셀 안에는 아무것도 없어야 한다 — 교량 위도 예외가 아니다.
	if spec_zone(kc, jc) == SPEC_Z_WATER:
		return ""
	# 차도는 세 조건을 전부 만족해야 한다: 아스팔트 안 · 중앙 분리대 밖 ·
	# 교차로와 그 바깥 횡단보도 밖. 뒤의 둘은 §18 에서 추가한 배치 규칙이고,
	# 판정기가 이것을 안 들면 그 규칙을 지운 빌드를 아무도 안 잡는다.
	# §25 는 넷째를 더한다: **그 도로가 실제로 존재하는가**. 없으면 그 위의 프롭은
	# 맨땅에 선 것이고, 기하 띠만 재는 옛 판정은 그것을 정상으로 통과시킨다.
	if (az.y <= rz and az.x >= spec_median(kz) and ax.x >= rx + SPEC_CROSS_W \
				and spec_seg_ew(kz, kc)) \
			or (ax.y <= rx and ax.x >= spec_median(kx) and az.x >= rz + SPEC_CROSS_W \
				and spec_seg_ns(kx, jc)):
		return "road"
	if (az.x >= rz and az.y <= spec_curb_half(kz) and ax.x >= rx and spec_seg_ew(kz, kc)) \
			or (ax.x >= rx and ax.y <= spec_curb_half(kx) and az.x >= rz \
				and spec_seg_ns(kx, jc)):
		return "walk"
	# 블록 구간은 **셀 좌표**로 묻는다. 공원 수퍼블록은 여러 셀이 한 구간으로 병합되고
	# 걷힌 내부 도로 자리까지 프롭이 들어가는 것이 규격이라, 중심선 기준 편차만 보던
	# 옛 판정은 그 배치를 전부 "구역 이탈" 로 잡는다.
	var sx := spec_block_span(kc, jc, true)
	var sz := spec_block_span(kc, jc, false)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	if lo.x >= sx.x and hi.x <= sx.y and lo.y >= sz.x and hi.y <= sz.y:
		return "block"
	return ""                                  # 어느 구역에도 온전히 안 들어간다


## §18 의 대로 차선 자리 — 중앙선에서의 거리. 편도 주행 띠 [median, road_half] 를
## 4등분한 1/4·2/4·3/4 지점이다. **구현체의 lane_slots 를 읽지 않는다** — 읽으면
## 자리를 바꾼 빌드가 자기 값끼리 일치해 통과한다.
## §27: 대로의 **정차 자리는 하나**다(바깥 0.75 지점). 안쪽·가운데는 주행 차선과
## 겹쳐서 걷어냈다. 이 사본이 옛 세 자리로 남아 있으면 판정기의 규격이 구현체와
## 어긋난 채 방치된다 — 이 프로젝트가 가장 경계하는 상태다.
func spec_lane_slots(k: int) -> Array:
	var m := spec_median(k)
	return [m + (spec_road_half(k) - m) * 0.75]


## |u| 가 어느 규격 자리에 가장 가까운가.
func nearest_lane_slot(k: int, u: float) -> int:
	var best := 0
	var bd := INF
	var slots := spec_lane_slots(k)
	for i in slots.size():
		var d: float = absf(u - float(slots[i]))
		if d < bd:
			bd = d
			best = i
	return best


## E7: 이 프롭이 **대로 규격에서만 가능한 자리**에 있는가.
## 돌려주는 것은 ["road"|"walk"|"", 자리 번호] — 자리는 차량 중심의 |u| 가 규격 자리
## 셋 중 어느 것에 가장 가까운가이고(안쪽 0 / 가운데 1 / 바깥 2), E7b 가 그 다양성을 본다.
##
## 차도 조건에 `|u| > SPEC_ROAD_HALF` 를 걸면 안 된다. 안쪽 자리(2.4125)의 차량은
## median 1.05 제약 때문에 반폭이 1.3625 를 못 넘어 최대 |u| 가 3.775 < 4.0 이다 —
## 그 게이트를 두면 **안쪽 자리가 E7 에 아예 보이지 않아, 그 자리 두 줄을 통째로
## 지워도 아무 기준이 안 걸린다**(독립 감사가 지적했고 산술로 확인했다).
## "대로 위에 온전히 들어갔는가"(spec_is_boulevard + zone_of 와 같은 기하)면 충분하다.
## 보도는 `az.x >= rz`(대로 6.5)가 이미 |u| > 6.0 을 함의하므로 별도 조건이 필요 없다.
## 카탈로그는 읽지 않는다.
func boulevard_slot(pts: PackedVector2Array) -> Array:
	var fp := footprint(pts)
	var kx: int = fp["kx"]
	var kz: int = fp["kz"]
	var ax: Vector2 = fp["ax"]
	var az: Vector2 = fp["az"]
	var rx := spec_road_half(kx)
	var rz := spec_road_half(kz)
	if spec_is_boulevard(kz) and az.y <= rz and az.x >= spec_median(kz) \
			and ax.x >= rx + SPEC_CROSS_W:
		return ["road", nearest_lane_slot(kz, (az.x + az.y) * 0.5), az.x, kz]
	if spec_is_boulevard(kx) and ax.y <= rx and ax.x >= spec_median(kx) \
			and az.x >= rz + SPEC_CROSS_W:
		return ["road", nearest_lane_slot(kx, (ax.x + ax.y) * 0.5), ax.x, kx]
	if spec_is_boulevard(kz) and az.x >= rz and az.y <= spec_curb_half(kz) \
			and ax.x >= rx:
		return ["walk", -1, 0.0, 0]
	if spec_is_boulevard(kx) and ax.x >= rx and ax.y <= spec_curb_half(kx) \
			and az.x >= rz:
		return ["walk", -1, 0.0, 0]
	return ["", -1, 0.0, 0]


## E1~E6. 도시 배치 자체를 판정한다.
func run_judge_3b() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var city: Node3D = _main.get_node_or_null("City")
	if city == null:
		print("JUDGE 3b FAIL: City 노드가 없다")
		get_tree().quit(1)
		return

	# 물리를 SETTLE_FRAMES 만큼 돌린 뒤에 잰다. 한 프레임만 돌리고 멈추면
	# "도시가 제자리에 서 있는가" 를 시험할 기회가 없다 — 프롭 고정을 통째로
	# 해제한 빌드가 그대로 통과했다(실측).
	var before := {}
	for o in city.get_children():
		var n0 := o as Node3D
		if n0 != null:
			before[n0.get_instance_id()] = n0.global_transform
	for _i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var moved := 0.0
	var tilted := 0.0
	for o in city.get_children():
		var n1 := o as Node3D
		if n1 == null or not before.has(n1.get_instance_id()):
			continue
		var t0: Transform3D = before[n1.get_instance_id()]
		moved = maxf(moved, t0.origin.distance_to(n1.global_position))
		tilted = maxf(tilted, t0.basis.y.angle_to(n1.global_basis.y))
	get_tree().paused = true

	# --- E1: 카탈로그·임포트 무결성 ---
	var cat: Array = city.CATALOG
	var albedos := {}
	var e1_bad := 0
	for e in cat:
		var m := load(e["path"]) as Mesh
		if m == null or m.get_surface_count() == 0:
			e1_bad += 1
			print("JUDGE 3b E1 로드 실패: %s" % e["path"])
			continue
		for i in m.get_surface_count():
			var sm := m.surface_get_material(i) as StandardMaterial3D
			if sm == null or sm.albedo_texture != null:
				e1_bad += 1
				print("JUDGE 3b E1 머티리얼 결함: %s surf%d" % [e["path"], i])
				continue
			albedos[sm.albedo_color.to_html(false)] = true
	var props: Array = city.get_children()
	var e1: bool = e1_bad == 0 and cat.size() >= 30 and props.size() >= MIN_PROPS \
		and albedos.size() >= MIN_ALBEDOS

	# --- E2·E3·E5·E6 ---
	var boxes := []
	var e2_bad := 0
	var e5_bad := 0
	var e6_bad := 0
	var zone_n := {"road": 0, "walk": 0, "block": 0}
	var boul_n := {"road": 0, "walk": 0}
	var boul_bands := {}
	var boul_lane_bad := 0
	var e8_bad := 0
	var canopy_n := 0
	for o in props:
		var n3 := o as Node3D
		if n3 == null:
			continue
		var bx := prop_box(n3)
		if bx["pts"].is_empty():
			e5_bad += 1
			continue
		boxes.append(bx["pts"])
		var z := zone_of(bx["pts"])
		if z.is_empty():
			e2_bad += 1
			if e2_bad <= 5:
				print("JUDGE 3b E2 구역 이탈: %s at %s" % [n3.name, str(n3.position)])
		else:
			zone_n[z] += 1
		# E7: 일반 도로 규격에서는 불가능한 자리에 선 프롭을 따로 센다.
		var bs := boulevard_slot(bx["pts"])
		if not str(bs[0]).is_empty():
			boul_n[str(bs[0])] += 1
			if str(bs[0]) == "road":
				boul_bands[int(bs[1])] = true
				# 실제로 **차도에 놓인 것**만 본다. boulevard_slot 은 기하만 보므로
				# 보도 프롭이 교차 도로 쪽 띠에서 이 분기에 걸릴 수 있다 — 그것은
				# 다른 띠를 기준으로 재야 하는 다른 질문이다(실측: 덤불·바위가 걸렸다).
				# E7b(§27): 정차 차량이 **주행 차선을 침범하지 않는가.**
				# 대로의 주행 차선은 중앙선에서 0.25 지점이고 주차는 0.75 지점이다.
				# 둘이 겹치면 frozen 강체인 주차차를 주행차가 그대로 뚫고 지나간다 —
				# 계획이 경고했고 실제로 옛 자리 셋 중 둘이 그 상태였다.
				# 규격: 프롭의 |u| 하한이 중앙선~아스팔트 폭의 절반보다 바깥이어야 한다.
				var kb: int = int(bs[3])
				var mb := spec_median(kb)
				if z == "road" and float(bs[2]) < mb + (spec_road_half(kb) - mb) * 0.5 - 1e-4:
					if boul_lane_bad < 5:
						print("JUDGE 3b E7b 정차차가 주행 차선을 침범: %s |u|하한=%.3f (>= %.3f)"
							% [n3.name, float(bs[2]), mb + (spec_road_half(kb) - mb) * 0.5])
					boul_lane_bad += 1
		# 접지는 **보이는 메시**로도 재야 한다. 콜라이더만 재면 피벗 보정을 지운
		# 빌드가 통과한다 — 콜라이더는 제자리이고 모델만 뜨거나 박히기 때문이다.
		var why5 := ""
		if absf(float(bx["min_y"])) > GROUND_TOL:
			why5 = "콜라이더 min_y=%.3f" % bx["min_y"]
		elif absf(float(bx["mesh_y"])) > GROUND_TOL:
			why5 = "메시 min_y=%.3f" % bx["mesh_y"]
		elif float(bx["xz_gap"]) > MESH_BOX_TOL:
			why5 = "콜라이더-메시 XZ 어긋남=%.3f" % bx["xz_gap"]
		elif n3.global_basis.y.angle_to(Vector3.UP) > TILT_TOL:
			why5 = "기울기=%.4f rad" % n3.global_basis.y.angle_to(Vector3.UP)
		if not why5.is_empty():
			e5_bad += 1
			if e5_bad <= 5:
				print("JUDGE 3b E5 %s: %s" % [n3.name, why5])
		if Vector2(n3.global_position.x, n3.global_position.z).length() < SPEC_PLAZA_R:
			e6_bad += 1
		# --- E8: 수관 셰이프(§23) ---
		# 가지가 림에 걸리려면 **가지에 콜라이더가 있어야 한다.** 보이는 메시가
		# 밑동 셰이프보다 확연히 넓은 프롭은 셰이프가 둘이어야 한다(밑동 + 수관).
		# 메시와 셰이프를 판정기가 직접 재고 개수를 센다 — 구현체의 필드를 안 믿는다.
		var shapes: Array = n3.find_children("", "CollisionShape3D", false, false)
		var base_half: float = 0.0
		if not shapes.is_empty() and (shapes[0] as CollisionShape3D).shape != null:
			var bsz := (shapes[0] as CollisionShape3D).shape.get_debug_mesh().get_aabb().size
			base_half = maxf(bsz.x, bsz.z) * 0.5
		var mesh_half: float = 0.0
		for c in n3.find_children("", "MeshInstance3D", false, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			var ms: Vector3 = mi.mesh.get_aabb().size * mi.scale.abs()
			mesh_half = maxf(mesh_half, maxf(ms.x, ms.z) * 0.5)
		if base_half > 0.0 and mesh_half >= base_half * CANOPY_RATIO:
			canopy_n += 1
			if shapes.size() < 2:
				e8_bad += 1
				if e8_bad <= 5:
					print("JUDGE 3b E8 %s: 메시 반폭 %.2f 가 밑동 %.2f 의 %.1f배인데 셰이프가 %d개다"
						% [n3.name, mesh_half, base_half, mesh_half / base_half,
						   shapes.size()])

	# --- E3: 겹침 (SAT). 반경으로 1차 걸러 쌍 수를 줄인다 ---
	var e3_bad := 0
	var cent := []
	var rad := []
	for q in boxes:
		var c := Vector2.ZERO
		for p in q:
			c += p
		c /= float(q.size())
		var r := 0.0
		for p in q:
			r = maxf(r, c.distance_to(p))
		cent.append(c)
		rad.append(r)
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if cent[i].distance_to(cent[j]) > rad[i] + rad[j]:
				continue
			if convex_overlap(boxes[i], boxes[j]):
				e3_bad += 1
				if e3_bad <= 8:
					print("JUDGE 3b E3 겹침: %s@%s r=%.2f <-> %s@%s r=%.2f d=%.2f"
						% [props[i].name, str(cent[i].round()), rad[i],
						   props[j].name, str(cent[j].round()), rad[j],
						   cent[i].distance_to(cent[j])])

	# --- E4: 재현성 ---
	var f1: String = city.fingerprint(city.plan(city.city_seed))
	var f2: String = city.fingerprint(city.plan(city.city_seed))
	var f3: String = city.fingerprint(city.plan(city.city_seed + 1))
	var e4: bool = f1 == f2 and f1 != f3 and not f1.is_empty()

	# --- 판정 대상 8개가 광장에 그대로 있는가 (E6 의 나머지 절반) ---
	var jset: int = get_tree().get_nodes_in_group("judge_set").size()
	var e6: bool = e6_bad == 0 and jset == 8

	get_tree().paused = false
	var e2: bool = e2_bad == 0
	var e3: bool = e3_bad == 0
	# E5 는 정지 판정도 포함한다: 도시는 구멍이 닿기 전까지 스스로 움직이지 않는다.
	var e5: bool = e5_bad == 0 and moved <= SETTLE_MOVE_TOL and tilted <= TILT_TOL
	# E7: 도로 위계가 **배치에도** 반영됐는가. zone_of 는 카탈로그 zone 을 안 읽으므로,
	# walk_center_at·lane_slots 를 상수로 되돌린 빌드는 프롭이 규격 밖이 되어 add_slot 이
	# 조용히 거절할 뿐 어떤 기준도 안 걸린다(총 프롭 수만 줄고 그건 RESTART_PROPS 갱신에
	# 묻힌다). 개수 하한만으로도 부족하다 — 자리 하나를 빼는 정도의 회귀는 비율로 안 걸린다.
	#   E7a: 일반 도로 규격에서 기하적으로 불가능한 자리(차도 |u|>4.0, 보도 |u|>6.0)에
	#        프롭이 하한 이상 있는가. 위계를 지우면 0 이 된다.
	#   E7b: 대로 차도의 **규격 자리 셋(안쪽·가운데·바깥)이 전부 쓰였는가.**
	#        자리 하나를 지우는 회귀는 개수 비율로는 안 걸린다(실측: 3자리 → 1자리
	#        주입이 하한 230 대 223 으로 간신히 걸렸다) — 구조로 물어야 한다.
	# E7b 는 §27 에서 **"자리 셋이 전부 쓰였는가" → "정차차가 주행 차선을 침범하지
	# 않는가"** 로 바뀌었다. 대로 정차 자리가 하나로 줄어 앞의 질문이 의미를 잃었다.
	# 옛 조건(`boul_bands.size() >= 3`)을 지우지 않고 새 카운터만 세다가, 주입 실행에서
	# **옛 조건이 우연히 걸린 것을 새 기준이 잡은 것으로 오독했다** — 독립 감사가 잡았다.
	# 통과식에 실제로 들어가지 않는 카운터는 판정력이 0 이다.
	var e7: bool = boul_n["road"] >= MIN_BOUL_ROAD and boul_n["walk"] >= MIN_BOUL_WALK \
		and boul_lane_bad == 0
	# E8: §19 의 걸림 모형이 실제로 입력을 갖는가. 두 질문을 함께 묻는다.
	#   ① 수관이 넓은 프롭에 수관 셰이프가 달려 있는가 (셰이프 개수)
	#   ② 그런 프롭이 하한 이상 있는가 — 밑동 셰이프를 다시
	#      메시 전체로 되돌리면 둘이 같아져 걸림이 조용히 사라진다.
	var e8: bool = e8_bad == 0 and canopy_n >= MIN_CANOPY_PROPS
	var ok: bool = e1 and e2 and e3 and e4 and e5 and e6 and e7 and e8
	print("JUDGE 3b props=%d catalog=%d albedos=%d zones road=%d walk=%d block=%d"
		% [props.size(), cat.size(), albedos.size(),
		   zone_n["road"], zone_n["walk"], zone_n["block"]])
	print("JUDGE 3b E7 대로전용자리: road=%d(>=%d) walk=%d(>=%d) 주행차선침범=%d"
		% [boul_n["road"], MIN_BOUL_ROAD, boul_n["walk"], MIN_BOUL_WALK, boul_lane_bad])
	print("JUDGE 3b bad: E1=%d E2=%d E3=%d E5=%d E6=%d E8=%d judge_set=%d fp=%d/%d settle_move=%.4f settle_tilt=%.4f"
		% [e1_bad, e2_bad, e3_bad, e5_bad, e6_bad, e8_bad, jset, f1.length(), f3.length(),
		   moved, tilted])
	print("JUDGE 3b E8 수관프롭=%d(>=%d, 수관/밑동 >= %.1f)" % [canopy_n, MIN_CANOPY_PROPS, CANOPY_RATIO])
	print("JUDGE 3b E1=%s E2=%s E3=%s E4=%s E5=%s E6=%s E7=%s E8=%s -> %s"
		% [pf(e1), pf(e2), pf(e3), pf(e4), pf(e5), pf(e6), pf(e7), pf(e8),
		   ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


# --- 4b: 게임 루프 판정 ----------------------------------------------------

## T1: 타이머가 실제 경과만큼 줄고 0 에서 판이 끝나는가
## T2: 리더보드가 점수 내림차순이고 등록된 구멍과 일치하는가
## T3: 끝난 뒤 상태가 고정되는가 (점수·반경·위치가 더 변하지 않는다)
## T4: 승자가 최고 점수 구멍인가
## T5: 재시작이 초기 상태를 복원하는가
## T6: 플레이어가 먹히면 그 자리에서 판이 끝나는가
## T7: 판정 픽스처 8개가 게임에는 존재하지 않는가 (§20)
func run_judge_5() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	_main.round_seconds = ROUND_TEST_SEC
	_main.restart()                       # 짧은 라운드로 처음부터 다시 시작
	_main.judging = false

	# --- T1: 타이머 ---
	# 남은 시간을 판정기의 독립 시계와 대조한다. _main.time_left 를 그대로 믿으면
	# 타이머를 아예 멈춘 빌드도 "0 이 아니다" 로 통과한다.
	#
	# 절대 시각이 아니라 **기울기**로 잰다. 재시작 직후의 첫 프레임은 도시 프롭
	# 588개를 다시 세우느라 dt 가 커서, 그 한 프레임이 절대 비교에 0.25초짜리
	# 오차로 남는다(실측). 워밍업 뒤 기준점을 다시 잡으면 사라진다.
	for _i in WARMUP:
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var base: float = float(_main.time_left)
	var t1_drift := 0.0
	var over_at := -1.0
	for _i in ROUND_TEST_FRAMES:
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
		var spent: float = base - float(_main.time_left)
		if int(_main.state) == SPEC_STATE_PLAYING:
			t1_drift = maxf(t1_drift, absf(spent - elapsed))
		elif over_at < 0.0:
			over_at = elapsed
	var t1: bool = t1_drift <= TIMER_TOL and over_at >= 0.0 \
		and absf(over_at - base) <= TIMER_TOL * 2.0
	print("JUDGE 5 T1: 기준=%.2fs drift=%.3fs 종료시각=%.2fs state=%d"
		% [base, t1_drift, over_at, _main.state])

	# --- T2·T4: 리더보드와 승자 ---
	var scored := []
	for h in _reg.holes():
		if is_instance_valid(h):
			scored.append([str(h.label), int(h.score), float(h.radius)])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[2] > b[2])
	# §26: 보드는 **상위 셋 + 나**만 싣는다. 여섯 줄을 다 세우면 화면 오른쪽이 표로
	# 덮이고 정작 알고 싶은 것("내가 몇 등인가")이 그 안에 묻힌다.
	# 판정기가 기대 목록을 **따로 계산한다** — 구현체의 출력을 파싱해 자기 자신과
	# 비교하면 무엇을 싣든 통과한다.
	var want_rows := []
	var mine := -1
	for i in scored.size():
		if str(scored[i][0]) == "P":
			mine = i
	for i in scored.size():
		if i < SPEC_BOARD_TOP or i == mine:
			want_rows.append(i)
	var board: String = _main.hud_board.text
	var rows := board.split("\n", false)
	var t2: bool = rows.size() == want_rows.size() + 1
	for n in want_rows.size():
		if not t2:
			break
		# 판정기가 정렬한 순서대로 이름·점수·**등수**가 그 줄에 있어야 한다.
		# 등수를 함께 보지 않으면 나를 4위가 아니라 4번째 줄이라고만 적어도 통과한다.
		var i: int = want_rows[n]
		t2 = t2 and rows[n + 1].contains(str(scored[i][0])) \
			and rows[n + 1].contains(str(scored[i][1])) \
			and rows[n + 1].strip_edges().begins_with("%d." % (i + 1))
	var t4: bool = not scored.is_empty() and str(_main.winner) == str(scored[0][0]) \
		and int(_main.winner_score) == int(scored[0][1])
	print("JUDGE 5 T2/T4: 구멍=%d 보드행=%d 승자=%s(%d) 기대=%s(%d)"
		% [scored.size(), rows.size() - 1, _main.winner, _main.winner_score,
		   scored[0][0] if not scored.is_empty() else "-",
		   scored[0][1] if not scored.is_empty() else -1])

	# --- T3: 종료 후 상태 고정 ---
	var snap := {}
	for h in _reg.holes():
		if is_instance_valid(h):
			snap[h.get_instance_id()] = [int(h.score), float(h.radius), h.global_position]
	for _i in FREEZE_FRAMES:
		await get_tree().physics_frame
	var t3 := true
	for h in _reg.holes():
		if not is_instance_valid(h) or not snap.has(h.get_instance_id()):
			t3 = false
			continue
		var s: Array = snap[h.get_instance_id()]
		if int(h.score) != int(s[0]) or absf(float(h.radius) - float(s[1])) > 1e-4 \
				or h.global_position.distance_to(s[2]) > 1e-3:
			t3 = false
			print("JUDGE 5 T3 변동: %s score %d->%d R %.4f->%.4f"
				% [h.label, s[0], h.score, s[1], h.radius])
	print("JUDGE 5 T3: %d 구멍 %d 프레임 동안 고정=%s" % [snap.size(), FREEZE_FRAMES, pf(t3)])

	# --- T5: 재시작 복원 ---
	var city: Node3D = _main.get_node("City")
	var fp0: String = city.fingerprint(city.plan(city.city_seed))
	# T5 는 **판정 모드의** 재시작을 본다. §20 이후 픽스처 8개는 판정 모드에서만
	# 스폰되므로, 앞의 시나리오가 내려 둔 플래그를 여기서 다시 올려야 한다.
	_main.judging = true
	_main.restart()
	await get_tree().process_frame
	var hs: Array = _reg.holes()
	var radii_ok := true
	var score_ok := true
	for h in hs:
		radii_ok = radii_ok and absf(float(h.radius) - SPEC_START_R) < 1e-4
		score_ok = score_ok and int(h.score) == 0
	var props: int = city.get_child_count()
	var jset: int = get_tree().get_nodes_in_group("judge_set").size()
	var t5: bool = hs.size() == RESTART_HOLES and radii_ok and score_ok \
		and props == RESTART_PROPS and jset == 8 \
		and int(_main.state) == SPEC_STATE_PLAYING \
		and absf(float(_main.time_left) - ROUND_TEST_SEC) < 0.2 \
		and fp0 == city.fingerprint(city.plan(city.city_seed))
	print("JUDGE 5 T5: 구멍=%d(기대 %d) R=5 %s 점수0 %s 프롭=%d(기대 %d) 판정대상=%d state=%d 남은시간=%.2f"
		% [hs.size(), RESTART_HOLES, pf(radii_ok), pf(score_ok), props, RESTART_PROPS,
		   jset, _main.state, _main.time_left])

	# --- T7: 판정 픽스처는 게임에 존재하지 않는다 (§20) ---
	# 두 갈래로 회귀할 수 있어 둘 다 막는다.
	#   ① 씬에 손으로 다시 놓는다 → main.tscn 을 **파일로 열어** Swallowables 아래
	#      노드 수를 센다. 실행 중의 노드를 세면 판정 모드에서 스폰된 8개와 구별할
	#      수 없어 이 회귀를 영원히 못 잡는다.
	#   ② 스폰 조건을 없앤다 → 게임 모드로 재시작해 픽스처가 0 인지 본다.
	#      도시는 그대로여야 한다 — 제거가 픽스처에만 닿았는지 함께 묻는다.
	var authored := 0
	var st: SceneState = (load("res://scenes/main.tscn") as PackedScene).get_state()
	for i in st.get_node_count():
		# SceneState 의 경로는 루트 상대라 앞에 "./" 가 붙는다("./Swallowables/S0").
		# 이 접두사를 빼먹은 첫 판은 **주입한 픽스처를 못 잡는 위약**이었다 — 고장
		# 주입이 아니었으면 "0 개" 라는 통과 로그를 그대로 믿었을 것이다.
		var p := str(st.get_node_path(i)).trim_prefix("./")
		if p.begins_with("Swallowables/"):
			authored += 1
			print("JUDGE 5 T7 씬에 픽스처가 남아 있다: %s" % p)
	_main.judging = false
	_main.restart()
	await get_tree().process_frame
	var jset_play: int = get_tree().get_nodes_in_group("judge_set").size()
	var props_play: int = city.get_child_count()
	var t7: bool = authored == 0 and jset_play == 0 and props_play == RESTART_PROPS
	print("JUDGE 5 T7: 씬에 놓인 픽스처=%d 게임 재시작 후 픽스처=%d 도시프롭=%d(기대 %d)"
		% [authored, jset_play, props_play, RESTART_PROPS])

	# --- T8: 한글 HUD 가 실제로 그려지는가 (§21) ---
	var t8 := await judge_hud_font()

	# --- T6: 플레이어가 먹히면 그 자리에서 끝난다 ---
	var t6r := await judge_player_eaten()
	var t6: bool = bool(t6r["over"]) and str(t6r["reason"]) == "eaten"
	print("JUDGE 5 T6: state=%d reason=%s" % [t6r["state"], t6r["reason"]])

	_main.judging = true
	var ok: bool = t1 and t2 and t3 and t4 and t5 and t6 and t7 and t8
	print("JUDGE 5 T1=%s T2=%s T3=%s T4=%s T5=%s T6=%s T7=%s T8=%s -> %s"
		% [pf(t1), pf(t2), pf(t3), pf(t4), pf(t5), pf(t6), pf(t7), pf(t8),
		   ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## T6 시나리오: 플레이어를 작게, AI 를 크게 겹쳐 놓고 먹히게 한다.
func judge_player_eaten() -> Dictionary:
	var hs: Array = _reg.holes()
	var player: Node3D = null
	var big: Node3D = null
	for h in hs:
		if str(h.label) == "P":
			player = h
		elif big == null:
			big = h
	if player == null or big == null:
		return { "over": false, "reason": "구멍 부족", "state": -1 }
	isolate([player, big])
	big.set_radius(BITE_R_BIG)
	player.set_radius(BITE_R_SMALL)
	big.move_to(Vector3.ZERO)
	player.move_to(big.global_position)
	_main.judging = false
	for _i in BITE_FRAMES:
		await get_tree().physics_frame
		if int(_main.state) == SPEC_STATE_OVER:
			break
	return { "over": int(_main.state) == SPEC_STATE_OVER, "reason": str(_main.over_reason),
		"state": int(_main.state) }


# --- 4a: 아레나 판정 -------------------------------------------------------

## G1: 남은 모든 구멍이 자기 위치에서 착시를 유지하는가 (카메라를 옮겨 가며 재판정)
## G2: 총 면적이 보존되는가 — 성장의 출처가 실제로 사라진 것들인가
## G3: 큰 구멍이 작은 구멍을 삼키고, 면적이 그대로 더해지는가
## G4: 작은 구멍은 큰 구멍을 삼키지 못한다 (방향이 뒤집히지 않는가)
## G5: 어떤 구멍도 지면 밖으로 나가지 않는가
func run_judge_4() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var holes: Array = _reg.holes()
	if holes.size() < 2:
		print("JUDGE 4 FAIL: 아레나에 구멍이 %d 개뿐이다" % holes.size())
		get_tree().quit(1)
		return
	_main.hud_root.visible = false

	# --- G1: 시작 배치에서 구멍마다 카메라를 옮겨 착시 판정 ---
	# 자유 실행 **전에** 한다. 실행 후에는 구멍들이 자라 서로 겹치는데, 다중 구멍
	# SDF 는 합집합 하나로 그려지므로 "구멍 하나 = 원반 하나" 를 전제하는 H1·H2 가
	# 그 상태에서 성립하지 않는다(겹침의 해소 여부는 G6 가 따로 본다).
	var g1 := true
	for i in holes.size():
		var h0: Node3D = holes[i]
		_cam.follow(h0, float(h0.radius), true)
		g1 = await judge_static("arena%d_" % i, false, true) and g1

	# --- G6: 겹침이 같은 프레임에 해소되는가 ---
	# 자유 실행에 맡기면 이 기준이 자극되지 않는다(실측: 우선순위 결함을 심어도
	# unresolved=0 으로 통과). 겹침은 "AI 가 Main 보다 늦게 움직여 만든 겹침" 일
	# 때만 한 프레임 남으므로, **AI 가 사냥해 들어가는** 상황을 따로 만들어야 한다.
	var g6r := await judge_overlap()
	var g6_scenario: bool = g6r["bad"] == 0 and bool(g6r["ate"])

	# --- G3·G4: 포식 시나리오 ---
	# 자유 실행 **전에** 한다. 자유 실행 뒤에는 구멍이 커지고 우물 안에 낙하 중인
	# 오브젝트가 잔뜩 남는데, 그 상태에서 시나리오가 반경을 강제로 줄이면
	# kill 깊이가 얕아져 멀리서 낙하 중이던 것들이 한꺼번에 소멸 처리된다
	# (실측: R=2 로 줄인 구멍이 60프레임 만에 R=24.35 로 폭주). 게임에서는
	# 일어나지 않는 일이지만, 판정 시나리오가 만들어 낸 상태였다.
	var g3 := await judge_bite("G3", 0, 1)
	var g4 := await judge_bite("G4", 1, 0)

	# 자유 실행을 위해 판을 진행 상태로 되돌리고 남은 구멍을 시작 반경으로 되돌린다.
	# G4 는 플레이어가 먹히는 시나리오라 4b 의 end_game 이 발동해 모든 구멍의
	# 물리가 멈춘 상태다 — resume() 없이 이어가면 AI 가 얼어붙어 G7 이 무너진다.
	_main.resume()
	for h in _reg.holes():
		if is_instance_valid(h):
			h.set_radius(SPEC_START_R)

	# 시작 상태를 판정기가 따로 기록한다.
	var r0_sum := 0.0
	for h in _reg.holes():
		r0_sum += float(h.radius) * float(h.radius)
	var obj_r := {}
	for o in get_tree().get_nodes_in_group("swallowable"):
		obj_r[o.get_instance_id()] = true_radius(o)

	# --- 자유 실행: AI 가 스스로 움직이고 먹는다 ---
	_main.judging = false
	var g5_bad := 0
	var g6_bad := 0
	var bites := 0
	var n_before: int = _reg.holes().size()
	# G7: AI 구멍별 이동 거리. "AI 구멍이 있다" 가 아니라 "AI 가 실제로 경쟁한다" 를
	# 봐야 한다 — 조종자를 통째로 죽여도 G1~G6 은 전부 통과한다(실측).
	var path := {}
	var last := {}
	var r_start := {}
	for h in _reg.holes():
		path[h.get_instance_id()] = 0.0
		last[h.get_instance_id()] = h.global_position
		r_start[h.get_instance_id()] = float(h.radius)
	for _i in ARENA_FRAMES:
		await get_tree().physics_frame
		g5_bad += offground_holes()
		g6_bad += unresolved_bites()
		for h in _reg.holes():
			var id: int = h.get_instance_id()
			if not path.has(id):
				continue
			path[id] += flat_dist(h.global_position, last[id])
			last[id] = h.global_position
	_main.judging = true
	var alive: Array = _reg.holes().duplicate()
	bites = n_before - alive.size()

	# --- G2: 총 면적 보존 ---
	# 좌변(현재 반경)만 구현체에서 읽는다. 우변은 판정기가 콜라이더에서 잰 반경과
	# "인스턴스가 실제로 사라졌는가" 로 독립 계산한다. AI 가 공짜로 자라면 어긋난다.
	var r1_sum := 0.0
	for h in alive:
		r1_sum += float(h.radius) * float(h.radius)
	var eaten_sq := 0.0
	var eaten_n := 0
	for id in obj_r:
		if not instance_from_id(id):
			eaten_sq += float(obj_r[id]) * float(obj_r[id])
			eaten_n += 1
	var expect_sum: float = r0_sum + SPEC_GROWTH_K * eaten_sq
	var g2: bool = absf(r1_sum - expect_sum) <= AREA_TOL * maxf(expect_sum, 1.0)
	print("JUDGE 4 arena: holes %d->%d bites=%d objects_eaten=%d SumR2 %.4f -> %.4f (expect %.4f)"
		% [n_before, alive.size(), bites, eaten_n, r0_sum, r1_sum, expect_sum])

	# --- G7: AI 가 실제로 움직이고 자랐는가 ---
	var g7 := true
	var g7_n := 0
	var g7_grew := 0.0
	for h in alive:
		if not is_instance_valid(h) or str(h.label) == "P":
			continue
		g7_n += 1
		var id: int = h.get_instance_id()
		var moved: float = float(path.get(id, 0.0))
		var grew: float = float(h.radius) - float(r_start.get(id, 0.0))
		g7_grew += grew
		# **이동은 AI 마다, 성장은 합으로 본다**(§27 에서 고쳤다).
		# 이동은 그 AI 의 조종자가 살아 있는가를 묻는 것이라 개체마다 물어야 한다.
		# 성장은 다르다 — 흡입은 모든 구멍이 **공유하는** 기계이므로, 그것이 망가지면
		# 아무도 자라지 못한다. 개체마다 요구하면 "그 AI 근처에 먹이가 있었는가" 라는
		# 배치의 운을 묻게 되고, 실제로 대로 주차를 주행 차선 밖으로 옮기자
		# 대로 위에 난 AI 가 15초 동안 굶어 정상 빌드가 탈락했다(실측 dR=+0.000).
		# 게임에서는 그 자리에 교통이 흐르지만 판정은 정적 도시를 쓴다.
		var okh: bool = moved >= AI_MIN_PATH
		g7 = g7 and okh
		print("JUDGE 4 G7 %s: path=%.1f (>= %.0f) dR=%+.3f -> %s"
			% [h.label, moved, AI_MIN_PATH, grew, pf(okh)])
	# 하한이 없으면 다섯 중 넷의 성장이 죽어도 하나가 +0.001 만 자라면 통과한다.
	# 실측 총합 0.418 의 절반을 문턱으로 둔다(다른 계측 파생 상수와 같은 방식).
	g7 = g7 and g7_n > 0 and g7_grew >= AI_MIN_GROW
	print("JUDGE 4 G7 AI 총 성장=%+.3f (>= %.2f)" % [g7_grew, AI_MIN_GROW])

	var g5: bool = g5_bad == 0
	var g6: bool = g6_bad == 0 and g6_scenario
	var ok: bool = g1 and g2 and g3 and g4 and g5 and g6 and g7
	print("JUDGE 4 G1=%s G2=%s G3=%s G4=%s G5=%s G6=%s G7=%s (offground=%d unresolved=%d ai=%d) -> %s"
		% [pf(g1), pf(g2), pf(g3), pf(g4), pf(g5), pf(g6), pf(g7),
		   g5_bad, g6_bad, g7_n, ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## G6 전용 시나리오. AI 가 조종하는 큰 구멍 앞에 작은 구멍을 놓고, AI 가 스스로
## 사냥해 들어가게 한다. 겹침이 그 프레임 안에 해소되지 않으면 카운트된다.
## 반환: { bad: 해소되지 않은 프레임 수, ate: 실제로 잡아먹혔는가 }
func judge_overlap() -> Dictionary:
	var hs: Array = _reg.holes()
	var hunter: Node3D = null
	var prey: Node3D = null
	for h in hs:
		if str(h.label) == "P":
			prey = h
		elif hunter == null:
			hunter = h
	if hunter == null or prey == null:
		return { "bad": 0, "ate": false }
	_main.resume()
	isolate([hunter, prey])
	hunter.set_radius(BITE_R_BIG)
	prey.set_radius(BITE_R_SMALL)
	hunter.move_to(Vector3.ZERO)
	prey.move_to(Vector3(0.0, 0.0, 20.0))     # 사정권(sight) 안, 원반 밖
	var prey_id := prey.get_instance_id()
	_main.set_ai(true)                        # 사냥꾼만 스스로 움직인다
	_main.judging = false
	var bad := 0
	var ate := false
	for _i in OVERLAP_FRAMES:
		await get_tree().physics_frame
		bad += unresolved_bites()
		if not instance_from_id(prey_id):
			ate = true
			break
	_main.judging = true
	print("JUDGE 4 G6 시나리오: 미해소 프레임=%d 포식성사=%s | %s"
		% [bad, ate, holes_dump()])
	return { "bad": bad, "ate": ate }


## 포식 한 판. eater_i / prey_i 는 레지스트리 인덱스다.
## 큰 쪽이 작은 쪽을 삼키고, 반경이 정확히 sqrt(Ra^2 + Rb^2) 가 되어야 한다.
## G3 와 G4 는 두 구멍의 역할만 맞바꾼 같은 시나리오다 — 포식이 크기로 정해지고
## 등록 순서나 플레이어 여부로 정해지지 않는다는 것을 그렇게 확인한다.
func judge_bite(tag: String, eater_i: int, prey_i: int) -> bool:
	var hs: Array = _reg.holes()
	if hs.size() < 2:
		print("JUDGE 4 %s FAIL: 남은 구멍이 %d 개" % [tag, hs.size()])
		return false
	var eater: Node3D = hs[eater_i]
	var prey: Node3D = hs[prey_i]
	# 앞선 시나리오에서 플레이어가 먹혀 판이 끝나 있으면 포식 처리가 멈춰 있다.
	_main.resume()
	isolate([eater, prey])
	eater.set_radius(BITE_R_BIG)
	prey.set_radius(BITE_R_SMALL)
	eater.move_to(Vector3.ZERO)           # 격리한 구멍(네 귀퉁이)에서 가장 먼 곳
	prey.move_to(eater.global_position)
	var eater_id := eater.get_instance_id()
	var prey_id := prey.get_instance_id()
	var expect := sqrt(BITE_R_BIG * BITE_R_BIG + BITE_R_SMALL * BITE_R_SMALL)
	print("JUDGE 4 %s setup: %s" % [tag, holes_dump()])
	_main.judging = false
	for _i in BITE_FRAMES:
		await get_tree().physics_frame
		if not instance_from_id(prey_id):
			break
	_main.judging = true
	var e: Node3D = instance_from_id(eater_id)
	var ok: bool = instance_from_id(prey_id) == null and e != null \
		and absf(float(e.radius) - expect) < 0.005
	print("JUDGE 4 %s: prey_gone=%s eater_alive=%s R=%.4f expect=%.4f | %s"
		% [tag, instance_from_id(prey_id) == null, e != null,
		   (e.radius if e != null else -1.0), expect, holes_dump()])
	return ok


## 포식 시나리오를 두 구멍만 두고 돌리기 위해, AI 조종을 끄고 나머지 구멍을
## 지면 네 귀퉁이로 치운 뒤 작게 만든다.
func isolate(keep: Array) -> void:
	_main.set_ai(false)
	var spots := [Vector3(-80, 0, -80), Vector3(80, 0, -80),
		Vector3(-80, 0, 80), Vector3(80, 0, 80)]
	var k := 0
	for h in _reg.holes():
		if not is_instance_valid(h) or keep.has(h):
			continue
		h.set_radius(2.0)
		h.move_to(spots[k % spots.size()])
		k += 1


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 등록된 구멍의 상태를 한 줄로. 포식 시나리오가 어긋날 때 원인을 짚는 유일한 단서다.
func holes_dump() -> String:
	var parts := PackedStringArray()
	for h in _reg.holes():
		if is_instance_valid(h):
			parts.append("%s R=%.2f @(%.0f,%.0f)"
				% [h.label, h.radius, h.global_position.x, h.global_position.z])
		else:
			parts.append("<freed>")
	return " | ".join(parts)


## G6: 포식이 성립하는데 아직 남아 있는 쌍의 수.
## 규칙(중심 포함 + 크기비)을 판정기가 직접 계산한다 — can_bite() 에 묻지 않는다.
## 물리 프레임이 끝난 시점에 이 수가 0 이 아니면 겹친 우물이 한 프레임 이상 남는다.
func unresolved_bites() -> int:
	var hs: Array = _reg.holes()
	var n := 0
	for a in hs:
		if not is_instance_valid(a):
			continue
		for b in hs:
			if a == b or not is_instance_valid(b):
				continue
			if float(a.radius) < float(b.radius) * SPEC_BITE_RATIO:
				continue
			var reach: float = flat_dist(a.global_position, b.global_position) \
				+ float(b.radius) * SPEC_BITE_DEPTH
			if reach <= float(a.radius):
				n += 1
	return n


## G5: 서 있으면 안 되는 자리에 있는 구멍 수. 한계는 판정기의 SPEC 로만 계산한다.
##
## §25 부터 "지면 밖" 에 **물 위**가 더해졌다. 이 자리에서 묻는 이유가 있다 —
## judge7 의 Z5 는 `move_to` 로 옮겨 본 자리만 시험하는데, **AI 스폰은 move_to 를
## 거치지 않고 좌표를 직접 받는다**(main.gd 의 격자 스냅). 물 위에서 태어난 구멍은
## 축별 슬라이드가 둘 다 막혀 영원히 그 자리에 굳는다. 아레나 자유 실행은 매 프레임
## 이것을 부르므로 스폰 순간부터 덮인다 — 지도를 고칠 때 스폰 링이 강·바다에 닿는
## 것이 이 프로젝트에서 가장 놓치기 쉬운 회귀다.
func offground_holes() -> int:
	var n := 0
	for h in _reg.holes():
		if not is_instance_valid(h):
			continue
		var lim: float = SPEC_GROUND_HALF - float(h.radius) * RING_K + EDGE_SLACK
		var p: Vector3 = h.global_position
		if absf(p.x) > lim or absf(p.z) > lim or absf(p.y) > EDGE_SLACK \
				or not spec_passable(p):
			n += 1
	return n


# --- 3c: 성능 측정 ---------------------------------------------------------

## F1·F2. 도시가 빽빽한 지점에서 프레임 시간을 잰다.
## MultiMesh 같은 최적화는 **측정 뒤에** 판단한다 — 근거 없는 최적화는 하지 않는다.
func run_judge_3c() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	# vsync 를 끄지 않으면 어떤 씬이든 16.7ms 로 측정되어 판정이 무의미해진다.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var hole: Node3D = _reg.holes()[0]
	var props: int = _main.get_node("City").get_child_count()
	var f1 := true
	var f2 := true
	for key in PERF_SPOTS:
		_main.set_hole_position(PERF_SPOTS[key])
		_reg.flush()
		_cam.follow(hole, hole.radius, true)
		for _i in WARMUP * 2:
			await get_tree().process_frame

		var t0 := Time.get_ticks_usec()
		var prev := t0
		var worst := 0.0
		for _i in PERF_FRAMES:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, float(now - prev) / 1000.0)
			prev = now
		var avg := float(Time.get_ticks_usec() - t0) / 1000.0 / float(PERF_FRAMES)

		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var phys := Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		var s1 := avg <= FRAME_BUDGET_MS
		var s2 := worst <= FRAME_BUDGET_MS * 2.0
		f1 = f1 and s1
		f2 = f2 and s2
		print("JUDGE 3c [%s] props=%d draws=%d prims=%d active_bodies=%d"
			% [key, props, int(draws), int(prims), int(phys)])
		print("JUDGE 3c [%s] avg=%.2fms (%.0f fps) worst=%.2fms budget=%.2fms F1=%s F2=%s"
			% [key, avg, 1000.0 / maxf(avg, 0.001), worst, FRAME_BUDGET_MS, pf(s1), pf(s2)])

	# --- 교통 on (§27) -------------------------------------------------------
	# 게임 기본값만큼 차를 띄우고 같은 지점을 다시 잰다. 동적 개체는 그리기뿐 아니라
	# **매 물리 프레임 위치를 다시 쓰는 비용**이 있어서, 정적 도시의 계측만으로는
	# 예산을 말할 수 없다. 이것이 car_count 를 조정할 근거다.
	var tr: Node = _main.get_node_or_null("Traffic")
	if tr != null:
		tr.spawn_for_judge(int(tr.car_count))
		var czp: Node = _main.get_node_or_null("Citizens")
		if czp != null:
			czp.spawn_for_judge(int(czp.citizen_count))
		_main.set_hole_position(PERF_SPOTS["dense"])
		_reg.flush()
		_cam.follow(hole, hole.radius, true)
		for _i in WARMUP * 2:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		var prev := t0
		var worst := 0.0
		for _i in PERF_FRAMES:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, float(now - prev) / 1000.0)
			prev = now
		var avg := float(Time.get_ticks_usec() - t0) / 1000.0 / float(PERF_FRAMES)
		var s1 := avg <= FRAME_BUDGET_MS
		var s2 := worst <= FRAME_BUDGET_MS * 2.0
		f1 = f1 and s1
		f2 = f2 and s2
		var czn: Node = _main.get_node_or_null("Citizens")
		print("JUDGE 3c [dynamic] 차=%d 시민=%d avg=%.2fms (%.0f fps) worst=%.2fms F1=%s F2=%s"
			% [tr.car_total(), 0 if czn == null else czn.citizen_total(),
			   avg, 1000.0 / maxf(avg, 0.001), worst, pf(s1), pf(s2)])

	var ok := f1 and f2
	print("JUDGE 3c F1=%s F2=%s -> %s" % [pf(f1), pf(f2), ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func capture(tag: String) -> Image:
	for i in WARMUP:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw       # 필수 (V13)
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var err := img.save_png(SHOT_DIR + tag + ".png")
	print("JUDGE saved %s%s.png err=%d hole_count=%s"
		% [SHOT_DIR, tag, err, str(_mat.get_shader_parameter("hole_count"))])
	return img


## 카메라가 구멍을 내려다보는 앙각(라디안).
func elevation(c: Vector3) -> float:
	var d := _cam.global_position - c
	return atan2(maxf(d.y, 0.0), maxf(Vector2(d.x, d.z).length(), 1e-6))


## 반경 r 원을 RIM_DIRS 방향으로 투영한 볼록 다각형.
## 월드 정사각형의 두 모서리만 투영하면 원근에서 영역이 어긋나고,
## 구멍이 지면 가장자리에 가까울 때 지면 밖 배경까지 먹는다.
func ring_poly(c: Vector3, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in RIM_DIRS:
		var a := TAU * float(k) / float(RIM_DIRS)
		pts.append(_cam.unproject_position(c + Vector3(cos(a), 0.0, sin(a)) * r))
	return pts


## 림 둘레의 화면 길이(픽셀). H7 허용치를 해상도·반경에 비례시키는 데 쓴다.
func rim_perimeter_px(c: Vector3, r: float) -> float:
	var pts := ring_poly(c, r)
	var s := 0.0
	for k in pts.size():
		s += pts[k].distance_to(pts[(k + 1) % pts.size()])
	return s


## H7: 탐침 프레임(배경=마젠타)에서 구멍 원반 안의 마젠타 우세 픽셀 수.
## 마젠타는 어떤 씬 팔레트와도 겹치지 않으므로 지면·우물 색을 바꿔도 흔들리지 않는다.
func magenta_pixels(img: Image, poly: PackedVector2Array) -> int:
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var x0 := clampi(int(floor(lo.x)), 0, img.get_width() - 1)
	var x1 := clampi(int(ceil(hi.x)), 0, img.get_width() - 1)
	var y0 := clampi(int(floor(lo.y)), 0, img.get_height() - 1)
	var y1 := clampi(int(ceil(hi.y)), 0, img.get_height() - 1)
	var n := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not in_poly(Vector2(x, y), poly):
				continue
			var q := img.get_pixel(x, y)
			if minf(q.r, q.b) - q.g > MAGENTA_TH:
				n += 1
	return n


func in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var sign_seen := 0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var cr := (b - a).cross(p - a)
		if absf(cr) < 1e-6:
			continue
		var s := 1 if cr > 0.0 else -1
		if sign_seen == 0:
			sign_seen = s
		elif s != sign_seen:
			return false
	return true


## H8: 림을 여러 방향에서 가로지르며 "전이가 한 픽셀에 몰려 있지 않은가"를 본다.
## 한 스캔라인만 보면 서브픽셀 정렬에 따라 정상 빌드도 중간 픽셀이 없을 수 있고,
## bbox 전체의 중간 톤을 세면 부드러운 아트 그라디언트에 오염된다(실측).
## 국소 진폭으로 정규화하므로 접지 그림자·도로 같은 그라디언트에 영향받지 않는다.
func rim_aa(img: Image, c: Vector3, r: float) -> Vector2i:
	var pass_n := 0
	var valid_n := 0
	for k in RIM_DIRS:
		var a := TAU * float(k) / float(RIM_DIRS)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var p_in := _cam.unproject_position(c + dir * r * 0.85)
		var p_out := _cam.unproject_position(c + dir * r * 1.15)
		var vals := sample_line(img, p_in, p_out)
		if vals.size() < 4:
			continue
		var m := 0
		var step := 0.0
		for i in range(1, vals.size()):
			var d := absf(vals[i] - vals[i - 1])
			if d > step:
				step = d
				m = i
		# 전이 양쪽의 국소 평탄값으로 진폭을 잰다 (창 전체의 min/max 가 아니다)
		var before := vals[maxi(m - 2, 0)]
		var after := vals[mini(m + 1, vals.size() - 1)]
		var span := absf(after - before)
		if span < EDGE_THR:
			continue
		valid_n += 1
		if step < span * RIM_STEP_MAX:
			pass_n += 1
	return Vector2i(pass_n, valid_n)


## 두 화면 좌표를 잇는 선분 위의 픽셀 휘도열(같은 픽셀은 한 번만).
func sample_line(img: Image, a: Vector2, b: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var steps := int(ceil(a.distance_to(b)))
	if steps < 1:
		return out
	var last := Vector2i(-1, -1)
	for s in steps + 1:
		var p := a.lerp(b, float(s) / float(steps))
		var pi := Vector2i(int(round(p.x)), int(round(p.y)))
		if pi == last:
			continue
		last = pi
		if pi.x < 0 or pi.y < 0 or pi.x >= img.get_width() or pi.y >= img.get_height():
			continue
		out.append(img.get_pixel(pi.x, pi.y).get_luminance())
	return out


func px(world: Vector3, img: Image) -> Vector2i:
	var v := _cam.unproject_position(world)
	var cx := clampi(int(round(v.x)), 0, img.get_width() - 1)
	var cy := clampi(int(round(v.y)), 0, img.get_height() - 1)
	if cx != int(round(v.x)) or cy != int(round(v.y)):
		_clamped = true          # 표본이 화면 밖 → 판정 무효
	return Vector2i(cx, cy)


## 연속된 급변 픽셀을 한 그룹으로 병합해 센다 (AA 로 인한 이중 카운트 방지)
func edge_groups(img: Image, y: int) -> int:
	var groups := 0
	var run := false
	var prev := img.get_pixel(0, y).get_luminance()
	for x in range(1, img.get_width()):
		var cur := img.get_pixel(x, y).get_luminance()
		if absf(cur - prev) > EDGE_THR:
			if not run:
				groups += 1
				run = true
		else:
			run = false
		prev = cur
	return groups


func pf(b: bool) -> String:
	return "P" if b else "F"


func alive_count(objs: Array) -> int:
	var n := 0
	for o in objs:
		if is_instance_valid(o):
			n += 1
	return n


## 물체가 **어떤 자세로든** 통과하려면 구멍 반경이 이보다 커야 한다(§23).
## 가장 작은 두 반extent 가 만드는 단면의 외접반경 — 판정기가 콜라이더에서 직접 잰다.
## 이 값보다 구멍이 작으면 그 물체는 **어떻게 해도 못 들어간다**(거절 규격).
## 반대로 XZ 외접반경(true_radius)보다 구멍이 크면 눕히지 않고도 들어간다(통과 규격).
## 그 사이는 물리가 정하는 회색 지대이고, 판정기는 그 구간을 단언하지 않는다.
func true_fit(o: Node3D) -> float:
	var key: int = -o.get_instance_id()
	if _r_cache.has(key):
		return _r_cache[key]
	var r := INF
	for c in o.find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		var h := [s.x * 0.5, s.y * 0.5, s.z * 0.5]
		h.sort()
		r = minf(r, sqrt(h[0] * h[0] + h[1] * h[1]))
	if is_inf(r):
		r = true_radius(o)
	_r_cache[key] = r
	return r


## 물체의 XZ 원반이 구멍 원반과 겹치는가. 지면 아래로 내려가도 되는 자리인지를 가른다.
func over_hole(o: Node3D, hole: Node3D) -> bool:
	return flat_dist(o.global_position, hole.global_position) \
		< float(hole.radius) + true_radius(o)


## 오브젝트의 XZ 외접반경을 콜라이더에서 직접 잰다(구현체의 radius 필드와 독립).
## get_debug_mesh() 는 비싸므로 인스턴스별로 한 번만 계산한다.
func true_radius(o: Node3D) -> float:
	var key: int = o.get_instance_id()
	if _r_cache.has(key):
		return _r_cache[key]
	var r := 0.0
	# owned=false — 코드로 만든 도시 프롭은 owner 가 null 이라 기본값에서는 안 잡힌다.
	for c in o.find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		r = maxf(r, Vector2(s.x, s.z).length() * 0.5)
	_r_cache[key] = r
	return r


# --- 2단계 판정 ------------------------------------------------------------

## C1: 성장이 면적 보존 법칙을 따르는가  R' = sqrt(R^2 + k*r^2)
## C2: 거절 규격 — 통과반경이 구멍 반경보다 큰 물체는 삼켜지지도, 가라앉지도 않는다.
##     그리고 구멍이 자라 그 반경을 넘기면 그때는 삼켜진다(R 2.3 → 5.06).
##     구간마다 묻는 것이 다르다: 0차는 **반경이 고정된 채** 거절이 성립하는가,
##     1차는 자라는 내내 매 프레임 규격이 지켜지는가(gate_breaches), 2차는 열리는가.
## C3: 스코어가 삼킨 오브젝트의 기여 합과 일치하는가
## C4: 성장한 반경에서도 착시가 유지되는가 (우물·Area3D 가 SSOT 를 따라갔는가)
func run_judge_2() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var hole: Node3D = _reg.holes()[0]
	hole.set_radius(GATE_R)             # 거절 → 성장 → 통과 시나리오의 시작 반경
	var r0: float = hole.radius
	var objs: Array = get_tree().get_nodes_in_group("judge_set")

	# 시작 시점의 참반경·점수를 판정기가 독립적으로 기록해 둔다
	var r_of := {}
	var score_of := {}
	var big: Array = []
	var small: Array = []
	var grey: Array = []
	for o in objs:
		var id: int = o.get_instance_id()
		r_of[id] = true_radius(o)
		# 점수도 판정기가 규격대로 직접 계산한다 — 구현체의 score_value 를 믿으면
		# 산출식을 통째로 바꾼 빌드가 자기 값끼리 일치해 그대로 통과한다(실측).
		score_of[id] = int(round(float(r_of[id]) * float(r_of[id]) * 100.0))
		# 분류는 구현체에 묻지 않고 **물리 규격**으로 한다(§23). 두 규격은 서로 다른
		# 양이고, 셋으로 갈린다.
		#   통과 규격 — XZ 외접반경 < R : 눕히지 않고도 들어간다. 반드시 삼켜진다.
		#   거절 규격 — 통과반경(true_fit) > R : 어떤 자세로도 못 들어간다.
		#   그 사이 — 회색 지대. **판정기는 단언하지 않는다.**
		# can_swallow() 에 물으면 안 된다 — 이제 그 함수는 AI 조언일 뿐이라
		# 흡입을 막지 않는다.
		if true_radius(o) < r0:
			small.append(o)
		elif true_fit(o) > r0:
			big.append(o)
		else:
			grey.append(o)
	# 픽스처를 손대다 어느 한쪽이 비면 시나리오가 조용히 아무것도 시험하지 않게 된다.
	# 그 상태를 통과로 읽지 않는다.
	var c2set: bool = small.size() > 0 and big.size() > 0
	print("JUDGE 2 start R=%.4f objects=%d 통과=%d 거절=%d 회색=%d (거절 = 통과반경 > %.4f)"
		% [r0, objs.size(), small.size(), big.size(), grey.size(), r0])

	# --- 0차: 반경이 작은 상태로 거절 규격 물체 위에 머문다 ---
	# 이 단계가 없으면 시나리오가 "거절"을 한 번도 건드리지 않아,
	# 물체를 무조건 삼키는 빌드도 그대로 통과한다(실측).
	var gate_violation := 0
	for b in big:
		gate_violation += await hover(hole, objs, b, HOVER_FRAMES)
	# **거절 생존은 여기서 묻는다 — 1차가 끝난 뒤가 아니다.**
	# 0차 내내 반경은 r0 그대로라 "거절 규격이면 안 들어간다" 가 그대로 성립한다.
	# 1차에서는 구멍이 소형을 먹으며 2.3 → 5.79 로 자라고, 그 경로가 대형 픽스처
	# (16,-2)에서 5.4m 까지 접근한다 — 그때 대형이 빠지는 것은 **규격대로다**
	# (거절 반경 2.83 < 5.79). 옛 기준은 그 소멸을 위반으로 셌고, 그래서 §23 이
	# 크기 게이트를 걷어낸 뒤로는 픽스처 배치라는 우연에 기대고 있었다.
	# 1차 구간의 규격 준수는 gate_breaches 가 **매 물리 프레임** 본다 — 그쪽이
	# 반경과 물체를 그때그때 비교하므로 자라는 도중에도 정확하다.
	var c2a: bool = alive_count(big) == big.size()
	print("JUDGE 2 hover 후 거절 생존=%d/%d gate_violations=%d"
		% [alive_count(big), big.size(), gate_violation])

	# --- 1차: 통과 규격의 소형만 삼킨다 ---
	gate_violation += await suck(hole, objs, small)

	var r1: float = hole.radius
	var sum_sq := 0.0
	var expect_score := 0
	for id in r_of:
		if not instance_from_id(id):
			sum_sq += float(r_of[id]) * float(r_of[id])
			expect_score += int(score_of[id])
	var expect_r1: float = sqrt(r0 * r0 + SPEC_GROWTH_K * sum_sq)
	var c1 := absf(r1 - expect_r1) < 0.005
	var c3: bool = _main.score == expect_score

	print("JUDGE 2 after small: R=%.4f expect=%.4f (dR=%.4f) score=%d expect=%d big_alive=%d/%d"
		% [r1, expect_r1, r1 - expect_r1, _main.score, expect_score,
		   alive_count(big), big.size()])

	# --- 2차: 이제 큰 것도 게이트를 통과하는가 ---
	# 이미 삼켜진 것은 건너뛴다 — 해제된 인스턴스에 접근하면 코루틴이 죽어
	# quit() 에 도달하지 못하고 무한 대기가 된다(실측: 게이트 제거 빌드에서 300초 초과).
	var c2b := true
	for o in big:
		if not is_instance_valid(o):
			continue
		if true_radius(o) >= hole.radius:
			c2b = false
	gate_violation += await suck(hole, objs, big)
	var left := alive_count(objs)

	# --- C4: 성장한 반경에서 착시 재판정 ---
	_main.set_hole_position(Vector3.ZERO)
	_reg.flush()
	_cam.follow(hole, hole.radius, true)
	_main.hud_root.visible = false
	var c4 := await judge_static("grown_")
	_main.hud_root.visible = true

	var c2 := c2set and c2a and c2b and gate_violation == 0 and left == 0
	var ok := c1 and c2 and c3 and c4
	print("JUDGE 2 final R=%.4f score=%d left=%d gate_violations=%d set=%s 거절생존=%s 개방=%s"
		% [hole.radius, _main.score, left, gate_violation, pf(c2set), pf(c2a), pf(c2b)])
	print("JUDGE 2 C1=%s C2=%s C3=%s C4=%s -> %s"
		% [pf(c1), pf(c2), pf(c3), pf(c4), ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## 구멍을 몰아 `only` 안의 대상을 전부 삼킬 때까지 돈다.
## 낙하 중인 것이 아직 남아 있는데 끊으면 성장이 덜 반영된 상태로 판정하게 된다(실측).
## 반환값 = 게이트 위반 수(상한을 넘는 오브젝트가 낙하하거나 지면 아래로 내려간 횟수).
func suck(hole: Node3D, objs: Array, only: Array) -> int:
	var violations := 0
	var frames := 0
	while frames < SWALLOW_FRAMES and alive_count(only) > 0:
		var target: Node3D = null
		var bd := INF
		for o in only:
			if not is_instance_valid(o) or o.falling:
				continue
			var d: float = Vector2(o.global_position.x - hole.global_position.x,
				o.global_position.z - hole.global_position.z).length()
			if d < bd:
				bd = d
				target = o
		if target != null:
			var to := target.global_position - hole.global_position
			to.y = 0.0
			var step: float = minf(to.length(), _main.MOVE_SPEED / 60.0)
			if step > 0.0001:
				_main.set_hole_position(hole.global_position + to.normalized() * step)
		# 거절 감시: 통과할 수 없는 물체는 빠지지도, 지면을 뚫지도 않아야 한다
		violations += gate_breaches(hole, objs)
		await get_tree().physics_frame
		frames += 1
	return violations


## 구멍을 target 위로 몰고 frames 동안 머문다. 게이트 위반 수를 반환한다.
func hover(hole: Node3D, objs: Array, target: Node3D, frames: int) -> int:
	var violations := 0
	for i in frames:
		if not is_instance_valid(target):
			break
		var to := target.global_position - hole.global_position
		to.y = 0.0
		var step: float = minf(to.length(), _main.MOVE_SPEED / 60.0)
		if step > 0.0001:
			_main.set_hole_position(hole.global_position + to.normalized() * step)
		violations += gate_breaches(hole, objs)
		await get_tree().physics_frame
	return violations


## **통과할 수 없는** 물체(좁은 쪽 반폭 >= 구멍 반경)가 빠졌거나 지면을 뚫었는가.
## 규격을 구현체에 묻지 않는다 — §23 이후 `can_swallow()` 는 AI 조언일 뿐이고
## 흡입을 막지 않으므로, 그 함수로 판정하면 검사 대상이 통째로 사라진다.
func gate_breaches(hole: Node3D, objs: Array) -> int:
	var n := 0
	for o in objs:
		if not is_instance_valid(o):
			continue
		if true_fit(o) < float(hole.radius):
			continue                              # 통과 가능 — 검사 대상이 아니다
		if o.falling or (o.global_position.y < SINK_LIMIT and not over_hole(o, hole)):
			n += 1
			print("JUDGE 2  거절 위반: fit=%.3f >= R=%.3f falling=%s y=%.3f dist=%.3f"
				% [true_fit(o), hole.radius, o.falling, o.global_position.y,
				   flat_dist(o.global_position, hole.global_position)])
	return n


# --- §23: 물리 통과 판정 ---------------------------------------------------

## K1 통과 규격 — XZ 외접반경이 구멍 반경보다 작은 물체는 **눕히지 않고도** 들어간다.
##    반드시 예산 안에 삼켜져야 한다.
## K2 거절 규격 — 통과 반경(가장 작은 두 반extent 의 외접반경)이 구멍 반경보다 큰
##    물체는 **어떤 자세로도** 못 들어간다. 예산 내내 림 위에 남아야 한다.
## K3 수관 걸림 — 밑동은 들어가고도 남지만 가지가 구멍보다 넓은 물체는 걸려서 남는다.
##    §19 는 이것을 통과 조건에 계수를 곱해 흉내냈다. 지금은 **가지에 콜라이더가
##    있고 구멍 둘레에 물리적 림이 있어서** 그냥 걸린다.
## K4 해소 — 구멍이 수관보다 커지면 그 물체도 들어간다.
## K5 지면 관통 없음 — 어느 시행에서도, 지면 아래로 내려간 물체는 **구멍 위**에 있다.
##    플레이 피드백의 "땅 위에서 녹아 사라진다" 가 이 기준이다.
## K6 긴 물체 — 폭이 구멍보다 좁으면 길이가 아무리 길어도 결국 들어간다(전봇대).
## K7 견인 금지(§30) — 통과 반경이 구멍보다 큰 물체는 감지 범위에 걸쳐도 **끌려가지
##    않는다.** 시작 반경 1.5 구멍이 주차된 구급차·버스를 끌고 다닌 플레이 피드백이
##    이 기준이다. 픽스처는 구멍 **옆**에 세운다 — K1~K6 은 정중앙 배치라 흡입이
##    사실상 개입하지 않고(중심 대칭이라 순변위를 만들지 못한다), 견인과 옆-흡입은
##    K7·K8 이 처음 묻는 질문이다.
## K8 옆-흡입 보장(§30) — 2×2×2 정육면체(fit = 외접 = 1.414, q=1.414)는 구멍
##    옆에서도 끌려와 삼켜진다. K7 의 게이트를 과욕으로 잡으면(예: q >= 1.5 부터
##    흡입) 여기서 걸린다 — 금지와 보장의 양방향 단언.
##    경계 판별 정밀도는 이 괄호까지다: [q=0.63(K7), q=1.41(K8)] 사이의 어긋난
##    문턱(예: q >= 1.2)은 두 기준이 못 가른다 — 더 붙인 픽스처(q=1.05·1.18)는
##    옆-흡입 중 기울며 쐐기가 되어 실측이 기각했다(K8_SIDE 주석).
func run_judge_6() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var hole: Node3D = _reg.holes()[0]
	# 광장의 판정 대상 8개를 치운다 — 시행 도중 함께 삼켜져 구멍이 자라면
	# 시나리오의 전제(반경 고정)가 깨진다(§19 에서 밟은 함정).
	for o in get_tree().get_nodes_in_group("judge_set"):
		o.queue_free()
	await get_tree().physics_frame

	var flat := await fall_run(hole, "flat", FALL_R, [Vector3(2.0, 2.0, 2.0)])
	var wide := await fall_run(hole, "wide", FALL_R, [Vector3(6.0, 2.0, 6.0)])
	var pole := await fall_run(hole, "pole", FALL_R, [Vector3(0.6, 8.0, 0.6)])
	var tree := await fall_run(hole, "tree", FALL_R, FALL_TREE)
	var tree_big := await fall_run(hole, "tree_big", FALL_BIG_R, FALL_TREE)

	var k1: bool = bool(flat["gone"])
	var k2: bool = not bool(wide["gone"])
	var k3: bool = not bool(tree["gone"])
	var k4: bool = bool(tree_big["gone"])
	var k6: bool = bool(pole["gone"])

	# --- K7: 견인 금지 ---------------------------------------------------------
	hole.set_radius(FALL_R)
	hole.move_to(Vector3.ZERO)
	var wide7 := fall_fixture("Fall_wide7", [Vector3(6.0, 2.0, 6.0)])
	_main.add_child(wide7)
	wide7.position = Vector3(K7_OFFSET, 0.0, 0.0)
	# 한 물리 프레임 정착 → 감지 진입 전제를 단언 → **그 프레임의 위치를 기준선**으로
	# 변위를 잰다. 기준선을 스폰 시점에 찍으면 접촉 해소의 정착 튐이 예산을 갉아먹고,
	# 전제를 안 물으면 픽스처를 너무 멀리 세운 대본이 공허하게 통과한다(계획 감사).
	await get_tree().physics_frame
	var k7_pre: bool = (int(wide7.collision_mask) & 8) != 0
	var base7: Vector3 = wide7.global_position
	for _i in FALL_FRAMES:
		await get_tree().physics_frame
	var moved7 := Vector2(wide7.global_position.x - base7.x,
		wide7.global_position.z - base7.z).length()
	var k7: bool = k7_pre and moved7 < K7_MOVE_MAX
	print("JUDGE 6 K7 견인 금지: 감지=%s XZ변위=%.4f m (< %.2f) %s"
		% [pf(k7_pre), moved7, K7_MOVE_MAX, pf(k7)])
	wide7.queue_free()
	await get_tree().physics_frame

	# --- K8: 옆-흡입 보장 -------------------------------------------------------
	var edge := await fall_run(hole, "edge", FALL_R,
		[Vector3(K8_SIDE, K8_SIDE, K8_SIDE)], Vector3(K8_OFFSET, 0.0, 0.0))
	var k8: bool = bool(edge["gone"])

	# K5 는 옆-흡입 시행(edge)의 관통도 함께 본다 — 옆에서 끌려오는 경로에서
	# 구멍 밖 지면 관통이 생겨도 중앙 5시행만 보면 침묵한다(코드 감사).
	var k5 := true
	for r in [flat, wide, pole, tree, tree_big, edge]:
		k5 = k5 and int(r["sink_bad"]) == 0

	var ok: bool = k1 and k2 and k3 and k4 and k5 and k6 and k7 and k8
	print("JUDGE 6 K1=%s K2=%s K3=%s K4=%s K5=%s K6=%s K7=%s K8=%s -> %s"
		% [pf(k1), pf(k2), pf(k3), pf(k4), pf(k5), pf(k6), pf(k7), pf(k8),
		   ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## 시행 하나. 구멍을 r 로 되돌려 원점에 세우고, 픽스처를 **구멍 한가운데**에 놓은 뒤
## 구멍을 움직이지 않고 예산만큼 돌린다. 가운데에 놓는 것이 가장 강한 시험이다 —
## "가운데 놓아도 안 빠진다" 와 "가운데 놓으면 빠진다" 를 각각 단언할 수 있다.
## §30: `at` 으로 옆에 세울 수도 있다(K8 — 흡입이 끌어오는가까지 묻는다).
## 기본값은 중심이라 기존 다섯 시행은 무변경이다.
##
## 반환: gone(삼켜졌는가) / frames(삼켜진 프레임) / sink_bad(구멍 밖 지면 관통 횟수)
func fall_run(hole: Node3D, tag: String, r: float, boxes: Array,
		at := Vector3.ZERO) -> Dictionary:
	hole.set_radius(r)
	hole.move_to(Vector3.ZERO)
	var body := fall_fixture("Fall_" + tag, boxes)
	_main.add_child(body)
	body.position = at
	await get_tree().physics_frame
	var rr: float = true_radius(body)
	var rf: float = true_fit(body)
	var gone := -1
	var sink_bad := 0
	var min_y := 0.0
	var f := 0
	while f < FALL_FRAMES and gone < 0:
		if not is_instance_valid(body):
			gone = f
			break
		min_y = minf(min_y, body.global_position.y)
		if body.global_position.y < SINK_LIMIT and not over_hole(body, hole):
			sink_bad += 1
			if sink_bad == 1:
				print("JUDGE 6 %s 구멍 밖 지면 관통: y=%.3f dist=%.3f R=%.3f"
					% [tag, body.global_position.y,
					   flat_dist(body.global_position, hole.global_position), r])
		await get_tree().physics_frame
		f += 1
	print("JUDGE 6 %-9s R=%5.2f 외접=%.3f 통과반경=%.3f 삼킴=%s(%d프레임) 최저y=%.2f 관통=%d"
		% [tag, r, rr, rf, "예" if gone >= 0 else "아니오", gone, min_y, sink_bad])
	if is_instance_valid(body):
		body.queue_free()
	await get_tree().physics_frame
	return { "gone": gone >= 0, "frames": gone, "sink_bad": sink_bad }


## 판정용 픽스처. 상자 셰이프를 아래에서부터 쌓는다(밑동 + 수관).
## 도시 프롭과 같은 규약(레이어 2, swallowable.gd)을 따르되 치수는 판정기가 정한다.
func fall_fixture(name: String, boxes: Array) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(SWALLOWABLE)
	body.collision_layer = 2
	body.collision_mask = 1 | 2
	body.name = name
	body.mass = 10.0
	body.add_to_group("swallowable")
	var y := 0.0
	for b in boxes:
		var size: Vector3 = b
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.position.y = y + size.y * 0.5
		body.add_child(cs)
		y += size.y
	return body

# --- §27: 교통 판정 ---------------------------------------------------------

## M 시나리오가 띄우는 차의 수. 게임 기본값과 달라도 된다 — 묻는 것은 "규격대로
## 도는가" 이지 "몇 대인가" 가 아니다.
const TRAFFIC_N := 24
## M8·M9 시나리오의 시민 수.
const CITIZEN_N := 120
## M8: 300프레임(5초) 동안 걸어야 할 **경로장**의 중앙값(m).
## 처음 근거를 틀리게 적었다 — "왕복이 섞여 짧아진다" 고 4.0 을 정당화했는데,
## 상쇄되는 것은 변위이고 **경로장은 왕복에 영향받지 않는다**(감사가 잡았다).
## 실제 하한은 walk_speed 1.8 x 0.8 = 1.44 m/s x 5s = 7.2m 이고 실측은 9.8m 다.
## 6.0 이면 속도가 절반이 된 고장이 걸린다.
const CITIZEN_MIN_PATH := 6.0
## M10: 겁먹은 시민이 90프레임(1.5초) 동안 구멍에서 이만큼은 멀어져야 "도망쳤다" 로 본다.
## 도망 속도 1.8 x 2.6 = 4.68 m/s 이므로 1.5 는 낮은 문턱이다(구간 끝에 몰린 사람이 섞인다).
const FLEE_MIN_GAIN := 1.5
## M1: 이 프레임 동안 돌리고 평균 변위를 잰다.
const TRAFFIC_FRAMES := 300
## M1: 그동안 차가 최소한 이만큼은 움직여야 한다(m). 속도 하한 6.0 × 5초 = 30m 이므로
## 20 은 "굳지 않았다" 를 보는 낮은 문턱이다. 앞차에 막혀 선 차가 섞이므로 평균으로 본다.
const TRAFFIC_MIN_PATH := 20.0
## M3: 주행 차선 오프셋의 허용 오차(m). 규격은 한 점이므로 좁게 잡는다.
const LANE_U_TOL := 0.05
## M7: 한 물리 프레임에 이보다 크게 움직이면 순간이동이다. 최고 속도 12 m/s 에서
## 한 프레임은 0.2m 이므로 5.0 은 압도적인 여유다 — 차선을 잘못 옮겨 앉는 것만 잡는다.
const JUMP_MAX := 5.0
## 정상적인 순간이동은 **재스폰**뿐이다(차선 끝에 닿아 반대편에서 다시 난다).
## 900프레임 · 24대에서 몇 번인지는 계측으로 정한다.
const JUMP_MAX_N := 40


## 주행 차선의 중앙선 기준 오프셋. **구현체의 driving_lanes 를 읽지 않는다** —
## 읽으면 차선을 옮긴 빌드가 자기 값끼리 일치해 통과한다.
func spec_driving_u(k: int) -> float:
	var m := spec_median(k)
	return m + (spec_road_half(k) - m) * 0.25


## 시민이 걷는 보도 안의 오프셋. **보도 중심선이 아니다** — 거기에는 가로등·표지판이
## 서 있어서, 시민이 그 자리를 걸으면 프롭을 통과한다(§28). 차도 쪽에 붙여 걷는다.
func spec_walk_u(k: int) -> float:
	return spec_road_half(k) + 0.5


## 이 사람이 규격 보도 위에 있는가. 도로가 **존재하는** 세그먼트여야 한다 —
## 걷힌 도로의 보도는 맨땅이고, 거기를 걸으면 허공을 걷는 것으로 보인다.
func on_spec_walk(p: Vector3) -> bool:
	var kx := spec_line_index(p.x)
	var kz := spec_line_index(p.z)
	var on_ew: bool = absf(absf(p.z - float(kz) * SPEC_PITCH) - spec_walk_u(kz)) < LANE_U_TOL \
		and spec_seg_ew(kz, spec_cell_of(p.x))
	var on_ns: bool = absf(absf(p.x - float(kx) * SPEC_PITCH) - spec_walk_u(kx)) < LANE_U_TOL \
		and spec_seg_ns(kx, spec_cell_of(p.z))
	return on_ew or on_ns


## 이 차가 규격 차선 위에 있는가. 대로여야 하고, 오프셋이 규격 한 점이어야 하며,
## 그 자리의 도로 세그먼트가 **실제로 존재**해야 한다(공원 안·다리 없는 강 위 금지).
func on_spec_lane(p: Vector3) -> bool:
	var kx := spec_line_index(p.x)
	var kz := spec_line_index(p.z)
	var on_ew: bool = spec_is_boulevard(kz) \
		and absf(absf(p.z - float(kz) * SPEC_PITCH) - spec_driving_u(kz)) < LANE_U_TOL \
		and spec_seg_ew(kz, spec_cell_of(p.x))
	var on_ns: bool = spec_is_boulevard(kx) \
		and absf(absf(p.x - float(kx) * SPEC_PITCH) - spec_driving_u(kx)) < LANE_U_TOL \
		and spec_seg_ns(kx, spec_cell_of(p.z))
	return on_ew or on_ns


## 교통을 처음부터 다시 내고 정해진 프레임만큼 돌린 뒤 지문을 낸다.
## M2 는 이것을 두 번 불러 견준다 — **두 실행이 같은 코드 경로를 타야** 대기 구조의
## 비대칭이 결과에 섞이지 않는다.
func traffic_take(tr: Node, frames: int) -> String:
	for c in tr.get_children():
		c.free()
	tr._cars.clear()
	tr.spawn_for_judge(TRAFFIC_N)
	for _f in frames + 1:
		await get_tree().physics_frame
	return traffic_fingerprint(tr)


func traffic_fingerprint(tr: Node) -> String:
	var parts := PackedStringArray()
	for i in int(tr.car_total()):
		var p: Vector3 = tr.car_pos(i)
		parts.append("%.3f,%.3f" % [p.x, p.z])
	return "|".join(parts)


## M1~M5. 교통이 규격대로 흐르는가.
func run_judge_9() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var tr: Node = _main.get_node_or_null("Traffic")
	if tr == null:
		print("JUDGE 9 FAIL: Traffic 노드가 없다")
		print("JUDGE RESULT -> FAIL")
		get_tree().quit(1)
		return

	# --- M4: 판정 격리 -------------------------------------------------------
	# **전용 요청이 없으면 판정 모드에는 동적 개체가 하나도 없다.** 이것을 먼저 묻는다 —
	# 아래에서 직접 띄우고 나면 다시 물을 수 없다.
	var cz: Node = _main.get_node_or_null("Citizens")
	var m4: bool = int(tr.car_total()) == 0 and tr.get_child_count() == 0
	# **노드가 없으면 탈락이다.** `cz == null` 을 통과로 두면 Citizens 를 통째로 지운
	# 빌드에서 M4확장·M8·M9 셋이 조용히 P 로 인쇄되고 판정이 PASS 한다 —
	# "기능이 아예 없다" 가 가장 센 고장인데 그것을 못 잡는다(감사가 잡았다).
	var cz_pre: bool = cz != null \
		and int(cz.citizen_total()) == 0 and cz.get_child_count() == 0
	print("JUDGE 9 M4 판정 격리: 요청 전 차=%d/%d 시민=%d/%d %s"
		% [tr.car_total(), tr.get_child_count(),
		   0 if cz == null else cz.citizen_total(),
		   0 if cz == null else cz.get_child_count(), pf(m4 and cz_pre)])

	# 구멍을 지도 구석으로 치운다. 대로에서 멀어야 차를 먹지 않는다.
	var hole: Node3D = _reg.holes()[0]
	hole.move_to(Vector3(-176.0, 0.0, -176.0))
	_reg.flush()

	# --- M1: 실제로 움직이는가 -----------------------------------------------
	tr.spawn_for_judge(TRAFFIC_N)
	await get_tree().physics_frame
	var n0: int = int(tr.car_total())
	# **직선 변위를 재면 안 된다.** 300프레임(5초)에 물리적 상한은 12 m/s × 5s = 60m 인데
	# 옛 M1 은 평균 137m 를 보고했다 — 절반 이상이 재스폰 **순간이동**이었다.
	# 그러면 속도를 0.01 로 낮춘 빌드도 통과한다(독립 감사가 산술로 증명했다).
	# 프레임마다 이동을 누적하되 도약은 버리는 **경로장**으로 잰다.
	# 평균이 아니라 **중앙값**을 본다 — 24대 중 스물이 굳어도 평균은 넘어간다.
	var path := {}
	var last := {}
	for i in n0:
		last[int(tr.car_id(i))] = tr.car_pos(i)
	var m3 := true
	var m3_bad := 0
	for f in TRAFFIC_FRAMES:
		await get_tree().physics_frame
		for i in int(tr.car_total()):
			var p: Vector3 = tr.car_pos(i)
			var id: int = int(tr.car_id(i))
			if last.has(id):
				var step: float = (p - (last[id] as Vector3)).length()
				if step <= JUMP_MAX:                     # 재스폰 도약은 주행이 아니다
					path[id] = float(path.get(id, 0.0)) + step
			last[id] = p
			# --- M3: 매 프레임 규격 위에 있는가 ---
			# 표본 시점 하나만 보면 "가끔 차선을 벗어난다" 를 놓친다.
			if not on_spec_lane(p):
				if m3_bad < 5:
					print("JUDGE 9 M3 규격 밖: %s (프레임 %d)" % [str(p), f])
				m3_bad += 1
				m3 = false
	var paths := []
	for id in path:
		paths.append(float(path[id]))
	paths.sort()
	var med: float = 0.0 if paths.is_empty() else float(paths[paths.size() / 2])
	var m1: bool = med >= TRAFFIC_MIN_PATH
	print("JUDGE 9 M1 경로장 중앙값=%.1fm (>= %.0f) 차=%d %s"
		% [med, TRAFFIC_MIN_PATH, n0, pf(m1)])
	print("JUDGE 9 M3 규격 이탈 표본=%d %s" % [m3_bad, pf(m3)])
	var fp1 := traffic_fingerprint(tr)

	# --- M6: 우측통행 --------------------------------------------------------
	# M3 는 오프셋의 **크기**만 본다. 방향과 좌우가 짝지어졌는지는 묻지 않으므로,
	# 두 차선을 통째로 맞바꾼 빌드(= 마주 오는 차끼리 같은 차선을 쓰는 도시)가
	# 그대로 통과한다. 진행 방향 d 의 오른쪽은 (-d.z, d.x) 다 — 그 부호를 단언한다.
	var before := []
	for i in int(tr.car_total()):
		before.append(tr.car_pos(i))
	await get_tree().physics_frame
	var m6 := true
	var m6_bad := 0
	for i in mini(before.size(), int(tr.car_total())):
		var p: Vector3 = tr.car_pos(i)
		var d: Vector3 = p - (before[i] as Vector3)
		if d.length() < 1e-4:
			continue                                   # 앞차에 막혀 선 차는 건너뛴다
		if d.length() > JUMP_MAX:
			continue                                   # 재스폰 도약은 진행 방향이 아니다
		var kx := spec_line_index(p.x)
		var kz := spec_line_index(p.z)
		var ok := false
		if absf(d.x) > absf(d.z):                      # 동서 주행 → 오프셋은 z
			var uz := p.z - float(kz) * SPEC_PITCH
			ok = signf(uz) == signf(d.x)               # 오른쪽 = (+z when d.x>0)
		else:                                          # 남북 주행 → 오프셋은 x
			var ux := p.x - float(kx) * SPEC_PITCH
			ok = signf(ux) == signf(-d.z)              # 오른쪽 = (-x when d.z>0)
		if not ok:
			if m6_bad < 5:
				print("JUDGE 9 M6 역주행: 위치(%.2f,%.2f) 변위(%.3f,%.3f)"
					% [p.x, p.z, d.x, d.z])
			m6_bad += 1
			m6 = false
	print("JUDGE 9 M6 우측통행 위반=%d %s" % [m6_bad, pf(m6)])

	# --- M2: 같은 시드면 같은 흐름 -------------------------------------------
	# **두 실행을 같은 코드 경로에 태운다.** 위의 M1 실행과 견주면 안 된다 —
	# 그쪽은 M3 표본을 끼고 돌아 물리 프레임 정렬이 한 칸 어긋나고, 그러면 차마다
	# 속도에 비례해 0.1~0.2m 씩 벌어져 **정상 빌드가 탈락한다**(실측으로 밟았다).
	# 재현성의 질문은 "같은 시드가 같은 흐름을 내는가" 이지 "판정의 대기 구조가
	# 같은가" 가 아니므로, 대칭인 헬퍼를 두 번 부른다.
	var fpa := await traffic_take(tr, TRAFFIC_FRAMES)
	var fpb := await traffic_take(tr, TRAFFIC_FRAMES)
	var m2: bool = not fpa.is_empty() and fpa == fpb
	print("JUDGE 9 M2 결정성 지문 %d자 일치=%s" % [fpa.length(), pf(m2)])

	# --- M5: 구멍이 달리는 차를 삼킨다 ---------------------------------------
	# 대로 위에 큰 구멍을 놓고 차가 지나가기를 기다린다. 흡입 파이프라인(§23)과
	# 교통의 인계가 이어져 있는가를 본다 — 점수가 오르면 끝까지 이어진 것이다.
	hole.set_radius(9.0)
	hole.move_to(Vector3(0.0, 0.0, spec_driving_u(0)))     # 인덱스 0 대로 위
	_reg.flush()
	var score0: int = int(hole.score)
	# M7 도 여기서 함께 잰다 — **차가 먹히는 동안**의 상태다.
	# M1·M3 는 구멍이 멀리 있는 조용한 실행이라 이 경로를 아예 지나지 않는다.
	# 인계는 교통의 내부 배열을 건드리는 유일한 자리이고, 그 자리가 어긋나면
	# 남은 차가 엉뚱한 원소를 움직인다(실측: 루프 도중 제거로 인덱스가 밀렸다).
	var m7 := true
	var m7_bad := 0
	var m7_min := 9999
	# 순간이동 세기. **인덱스가 아니라 개체 식별자로 따라간다** — 먹힌 차가 빠지고
	# 새 차가 뒤에 붙으므로 인덱스는 프레임마다 다른 차를 가리킨다.
	# 인계가 내부 배열을 어긋내면 남은 차가 **다른 차선의 좌표로 옮겨 앉는데**,
	# 그 자리도 유효한 차선이라 규격 검사로는 보이지 않는다. 보이는 것은 그 도약이다.
	var last_pos := {}
	var jumps := 0
	for _f in 900:
		await get_tree().physics_frame
		var n: int = int(tr.car_total())
		m7_min = mini(m7_min, n)
		var seen := {}
		for i in n:
			var p: Vector3 = tr.car_pos(i)
			var id: int = int(tr.car_id(i))
			seen[id] = true
			if last_pos.has(id) and (p - (last_pos[id] as Vector3)).length() > JUMP_MAX:
				jumps += 1
			last_pos[id] = p
			if not on_spec_lane(p):
				if m7_bad < 5:
					print("JUDGE 9 M7 인계 중 규격 밖: %s" % str(p))
				m7_bad += 1
				m7 = false
		for id in last_pos.keys():
			if not seen.has(id):
				last_pos.erase(id)
	m7 = m7 and jumps <= JUMP_MAX_N
	print("JUDGE 9 M7 순간이동=%d (<= %d)" % [jumps, JUMP_MAX_N])
	var m5: bool = int(hole.score) > score0
	# 총량이 유지되는가. 하나가 빠질 때마다 하나가 나야 한다 — 안 그러면 도로가
	# 시간이 갈수록 비고, 그것은 판이 길어질수록 심해진다.
	m7 = m7 and m7_min >= TRAFFIC_N
	print("JUDGE 9 M5 주행차 흡입: 점수 %d -> %d %s" % [score0, hole.score, pf(m5)])
	print("JUDGE 9 M7 인계 중 규격이탈=%d 최소 대수=%d(>= %d) %s"
		% [m7_bad, m7_min, TRAFFIC_N, pf(m7)])

	# --- M8·M9: 시민 (§28) ---------------------------------------------------
	# 판정 격리는 위의 M4 와 같은 자리에서 이미 쟀다(cz_pre).
	# M8: 실제로 걷는가 — 도약을 버린 경로장의 중앙값으로 본다(M1 과 같은 이유).
	# M9: 보도 규격 위인가 — 걷힌 도로의 보도(맨땅)를 걷지 않는가.
	var m8 := cz != null
	var m9 := cz != null
	if cz != null:
		hole.set_radius(SPEC_START_R)
		hole.move_to(Vector3(-176.0, 0.0, -176.0))
		_reg.flush()
		cz.spawn_for_judge(CITIZEN_N)
		await get_tree().physics_frame
		var cpath := {}
		var clast := {}
		var m9_bad := 0
		for i in int(cz.citizen_total()):
			clast[int(cz.citizen_id(i))] = cz.citizen_pos(i)
		for _f in TRAFFIC_FRAMES:
			await get_tree().physics_frame
			for i in int(cz.citizen_total()):
				var p: Vector3 = cz.citizen_pos(i)
				var id: int = int(cz.citizen_id(i))
				if clast.has(id):
					var st: float = (p - (clast[id] as Vector3)).length()
					if st <= JUMP_MAX:
						cpath[id] = float(cpath.get(id, 0.0)) + st
				clast[id] = p
				if not on_spec_walk(p):
					if m9_bad < 5:
						print("JUDGE 9 M9 보도 규격 밖: %s" % str(p))
					m9_bad += 1
					m9 = false
		var cp := []
		for id in cpath:
			cp.append(float(cpath[id]))
		cp.sort()
		var cmed: float = 0.0 if cp.is_empty() else float(cp[cp.size() / 2])
		m8 = cmed >= CITIZEN_MIN_PATH
		print("JUDGE 9 M8 시민 경로장 중앙값=%.1fm (>= %.0f) 인원=%d %s"
			% [cmed, CITIZEN_MIN_PATH, cz.citizen_total(), pf(m8)])
		print("JUDGE 9 M9 보도 규격이탈=%d %s" % [m9_bad, pf(m9)])

		# --- M10: 도망 -------------------------------------------------------
		# **이것이 §28 의 간판 기능인데 위의 셋 중 어느 것도 건드리지 않는다.**
		# M8·M9 는 구멍을 지도 구석(-176,-176)에 두고 도는데, 그 자리에서 가장 가까운
		# 보도까지 8.5m 이고 겁먹는 반경은 1.5 × 3.5 = 5.25m 다 — **도망 분기가 한 번도
		# 실행되지 않는다.** 실제로 "구멍 쪽으로 달려들게" + "보도를 벗어나게" 를 동시에
		# 주입해도 M8·M9 가 통과했다(감사가 실증했다).
		# 구멍을 보도 옆에 크게 놓아 fear 를 확보하고, 겁먹은 사람이 **실제로 멀어지는가**를
		# 묻는다. 도망 중에도 보도 규격 위여야 한다.
		# 구멍을 크게 키워 겁먹는 반경을 넓힌다 — 표본이 서넛뿐이면 "과반" 이 우연에 흔들린다.
		# 16 × 3.5 = 56m 반경이면 시민 120명 중 열 명 안팎이 든다.
		hole.set_radius(16.0)
		hole.move_to(Vector3(0.0, 0.0, -64.0))
		_reg.flush()
		await get_tree().physics_frame
		var d0 := {}
		for i in int(cz.citizen_total()):
			var p: Vector3 = cz.citizen_pos(i)
			if flat_dist(p, hole.global_position) < 16.0 * 3.5:
				d0[int(cz.citizen_id(i))] = flat_dist(p, hole.global_position)
		for _f in 90:
			await get_tree().physics_frame
		var fled := 0
		var stayed := 0
		var m10_walk := true
		for i in int(cz.citizen_total()):
			var id: int = int(cz.citizen_id(i))
			if not d0.has(id):
				continue
			var p: Vector3 = cz.citizen_pos(i)
			if not on_spec_walk(p):
				m10_walk = false
			if flat_dist(p, hole.global_position) > float(d0[id]) + FLEE_MIN_GAIN:
				fled += 1
			else:
				stayed += 1
		# 구석에 몰린 사람은 더 못 간다 — 전부를 요구하지 않고 **과반**을 요구한다.
		var m10: bool = d0.size() >= 3 and fled > stayed and m10_walk
		print("JUDGE 9 M10 겁먹은 %d명 중 멀어짐=%d 제자리=%d 보도유지=%s %s"
			% [d0.size(), fled, stayed, pf(m10_walk), pf(m10)])
		m9 = m9 and m10
	m4 = m4 and cz_pre

	print("JUDGE 9 M1=%s M2=%s M3=%s M4=%s M5=%s M6=%s M7=%s M8=%s M9=%s"
		% [pf(m1), pf(m2), pf(m3), pf(m4), pf(m5), pf(m6), pf(m7), pf(m8), pf(m9)])
	var ok := m1 and m2 and m3 and m4 and m5 and m6 and m7 and m8 and m9
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


# --- §26: 게임 UI 판정 ------------------------------------------------------

## U1 이 각 상태에서 보여야 한다고 단언하는 것. 노드 이름이 아니라 **역할**로 적는다 —
## 판정기가 ui.gd 의 변수 이름을 읽으면 이름만 바꾼 빌드가 통과한다.
## 값은 [시작화면, 결과버튼, 인게임요소] 의 기대 가시성이다.
const SPEC_UI_VIS := {
	SPEC_STATE_HOME: [true, false, false],
	SPEC_STATE_PLAYING: [false, false, true],
	SPEC_STATE_OVER: [false, true, false],
}
## U2: 화면 벡터 → 월드 방향 규격. 카메라에 요(yaw)가 없고 구멍 바로 뒤 위에서
## 내려다보므로 화면 +x 가 월드 +x, 화면 아래(+y)가 월드 +z 다.
## **구현체의 screen_to_world 를 부르지 않는다** — 부르면 축을 뒤집은 빌드가
## 자기 값끼리 일치해 통과한다. 여기가 판정기의 사본이다.
const SPEC_DRAG := [
	["위로", Vector2(0.0, -120.0), Vector3(0.0, 0.0, -1.0)],
	["아래로", Vector2(0.0, 120.0), Vector3(0.0, 0.0, 1.0)],
	["왼쪽", Vector2(-120.0, 0.0), Vector3(-1.0, 0.0, 0.0)],
	["오른쪽", Vector2(120.0, 0.0), Vector3(1.0, 0.0, 0.0)],
	["대각", Vector2(90.0, 90.0), Vector3(0.7071, 0.0, 0.7071)],
]
## U2 의 허용 각오차(라디안). 정규화한 방향끼리 비교하므로 넉넉할 이유가 없다.
const DRAG_TOL := 0.02


## 그 역할의 노드들이 보이는가. `want` 가 참이면 **전부** 보여야 하고, 거짓이면
## **하나도** 보이면 안 된다.
##
## "하나라도 보이면 참" 으로 두면 안 된다 — 제목만 남기고 부제·안내를 꺼도, 레벨만
## 남기고 진행 바를 꺼도 통과한다. 규격은 "그 화면이 성립한다" 이지
## "그 화면의 무언가가 있다" 가 아니다.
##
## 라벨·버튼은 **문구가 비어 있지 않은지도** 함께 본다. `visible` 만 보면 이름만
## 맞춰 두고 아무것도 안 그리는 구현이 그대로 통과한다(빈 문자열 노드는 T8 의
## 글리프 검사에서도 제외되므로 어디에서도 안 걸린다).
func role_ok(node: Node, names: Array, want: bool) -> bool:
	var seen := 0
	for c in node.get_children():
		if not (c is CanvasItem) or not names.has(str(c.name)):
			continue
		seen += 1
		var vis: bool = (c as CanvasItem).visible
		if want:
			if not vis:
				return false
			if (c is Label or c is Button) and str(c.text).strip_edges().is_empty():
				print("JUDGE 8 U1 %s 가 보이지만 문구가 비어 있다" % str(c.name))
				return false
		elif vis:
			return false
	return seen == names.size()


## U1·U2. 게임 UI 가 규격대로 도는가.
##
## 판정 모드는 UI 를 통째로 끄고 곧장 플레이 상태로 들어간다(그래야 스물아홉 종이
## 성립한다). 그래서 이 판정만 **`judging` 을 스스로 내리고** UI 를 켠 뒤 상태를
## 손으로 몰아 본다 — 4a 의 자유 실행이 같은 일을 하는 것과 같은 방식이다.
func run_judge_8() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var ui: CanvasLayer = _main.get_node_or_null("UI")
	if ui == null:
		print("JUDGE 8 FAIL: UI 노드가 없다")
		print("JUDGE RESULT -> FAIL")
		get_tree().quit(1)
		return

	# --- U2: 입력 해석 --------------------------------------------------------
	# 먼저 한다. 렌더가 필요 없고, 상태를 흔들기 전에 물어야 깨끗하다.
	# **구멍을 실제로 움직여 본다** — input_dir 만 부르면 move_hole 이 그 벡터를
	# 엉뚱하게 쓰는 회귀를 놓친다.
	var hole: Node3D = _reg.holes()[0]
	var u2 := true
	for d in SPEC_DRAG:
		var scr: Vector2 = d[1]
		var want: Vector3 = (d[2] as Vector3).normalized()
		hole.move_to(Vector3(-16.0, 0.0, -16.0))       # 도심 한복판, 물·경계에서 멀다
		var from := hole.global_position
		# 터치 한 번을 손으로 만들어 넣는다. 눌린 자리를 원점으로 삼는 규격이므로
		# 시작점과 끝점 둘 다 필요하다.
		var t0 := InputEventScreenTouch.new()
		t0.index = 0
		t0.pressed = true
		t0.position = Vector2(400.0, 400.0)
		_main._unhandled_input(t0)
		var dg := InputEventScreenDrag.new()
		dg.index = 0
		dg.position = Vector2(400.0, 400.0) + scr
		_main._unhandled_input(dg)
		_main.move_hole(0.1)
		var moved := hole.global_position - from
		var t1 := InputEventScreenTouch.new()
		t1.index = 0
		t1.pressed = false
		t1.position = dg.position
		_main._unhandled_input(t1)
		var ang := INF
		if moved.length() > 1e-4:
			ang = moved.normalized().angle_to(want)
		var ok: bool = ang <= DRAG_TOL
		u2 = u2 and ok
		print("JUDGE 8 U2 %s 화면(%.0f,%.0f) 이동(%.3f,%.3f) 기대(%.3f,%.3f) 각오차=%.4f %s"
			% [d[0], scr.x, scr.y, moved.x, moved.z, want.x, want.z, ang, pf(ok)])
	# 손을 뗀 뒤에는 움직이지 않아야 한다 — 안 그러면 구멍이 혼자 흘러간다.
	hole.move_to(Vector3(-16.0, 0.0, -16.0))
	var idle_from := hole.global_position
	_main.move_hole(0.1)
	var idle_ok: bool = hole.global_position.distance_to(idle_from) < 1e-4
	u2 = u2 and idle_ok
	print("JUDGE 8 U2 손뗌 후 정지 %s" % pf(idle_ok))

	# --- U1: 상태 전이와 가시성 ----------------------------------------------
	# UI 를 켜고 상태를 손으로 몬다. 각 상태에서 보여야 할 것과 보이면 안 되는 것을
	# **역할별로** 단언한다.
	_main.judging = false
	ui.set_process(true)
	var start_names := ["_title", "_sub", "_hint", "_start_btn"]
	var over_names := ["_again_btn", "_home_btn"]
	var play_names := ["_level", "_bar"]
	_main.state = SPEC_STATE_HOME
	var u1 := true
	for st in [SPEC_STATE_HOME, SPEC_STATE_PLAYING, SPEC_STATE_OVER]:
		_main.state = st
		if st == SPEC_STATE_PLAYING:
			_main.begin_round()
		for _i in 3:
			await get_tree().process_frame
		var want: Array = SPEC_UI_VIS[st]
		var got := [role_ok(ui, start_names, want[0]), role_ok(ui, over_names, want[1]),
			role_ok(ui, play_names, want[2])]
		var ok: bool = got[0] and got[1] and got[2]
		u1 = u1 and ok
		print("JUDGE 8 U1 상태=%d 시작화면(%s)=%s 결과버튼(%s)=%s 인게임(%s)=%s %s"
			% [st, pf(want[0]), pf(got[0]), pf(want[1]), pf(got[1]),
			   pf(want[2]), pf(got[2]), pf(ok)])

	# 재시작이 플레이 상태로 되돌리는가(결과 화면의 "다시 하기" 가 하는 일).
	_main.restart()
	for _i in 3:
		await get_tree().process_frame
	var back_ok: bool = int(_main.state) == SPEC_STATE_PLAYING \
		and role_ok(ui, over_names, false) and role_ok(ui, play_names, true)
	u1 = u1 and back_ok
	print("JUDGE 8 U1 재시작 후 state=%d 인게임복귀 %s" % [_main.state, pf(back_ok)])

	# --- U4: **동적 문구**의 글리프 ------------------------------------------
	# T8 은 정적 상수(TXT_*)만 덮는다. 레벨·킬 피드·점수 팝업은 `_process` 가 채우므로
	# 판정 모드에서는 빈 문자열이고, T8 이 빈 노드를 제외해 **어디에서도 안 걸린다** —
	# `"레벨 %d"` 를 `"단계 %d"` 로 바꾸면 웹에서 두 글자가 조용히 사라지는데 열한 종이
	# 전부 통과한다. 이 프로젝트가 가장 무서워하는 실패 모드가 정확히 이 자리에 있었다.
	# 그래서 **문구가 실제로 채워진 상태에서** 글리프를 묻는다.
	_main.state = SPEC_STATE_PLAYING
	ui.kill_feed("P", "AI1")
	if is_instance_valid(hole):
		hole.score += 1234                     # 점수 팝업을 띄운다
	for _i in 3:
		await get_tree().process_frame
	var font: Font = (_main.hud as Control).get_theme_font("font")
	var dyn := ""
	for c in ui.get_children():
		if c is Label or c is Button:
			dyn += str(c.text)
	var miss := ""
	if font != null:
		for i in dyn.length():
			var ch := dyn.unicode_at(i)
			if ch > 32 and not font.has_char(ch) and not miss.contains(dyn[i]):
				miss += dyn[i]
	var u4: bool = font != null and miss.is_empty() and not dyn.strip_edges().is_empty()
	print("JUDGE 8 U4 동적 문구 %d자 글리프없음='%s' %s" % [dyn.length(), miss, pf(u4)])

	# --- U3: 버튼이 실제로 눌리는가 -----------------------------------------
	# U1 은 `begin_round()` 를 직접 부르므로 **버튼이 클릭을 받는지**는 아무도 안 본다.
	# 전체 화면 딤이나 라벨이 mouse_filter 를 STOP 으로 두면 화면은 멀쩡한데
	# 아무 버튼도 안 눌린다 — 배포하고 나서야 알게 되는 종류의 결함이다.
	# 그래서 **뷰포트에 진짜 마우스 이벤트를 밀어 넣어** 히트 테스트까지 통과시킨다.
	_main.state = SPEC_STATE_HOME
	for _i in 3:
		await get_tree().process_frame
	var btn: Button = ui.get_node_or_null("_start_btn")
	var u3 := btn != null
	if u3:
		var at := btn.get_global_rect().get_center()
		for pressed in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = pressed
			mb.position = at
			mb.global_position = at
			get_viewport().push_input(mb)
			await get_tree().process_frame
		for _i in 3:
			await get_tree().process_frame
		u3 = int(_main.state) == SPEC_STATE_PLAYING
	print("JUDGE 8 U3 시작 버튼 클릭 -> state=%d (기대 %d) %s"
		% [_main.state, SPEC_STATE_PLAYING, pf(u3)])

	# 판정을 끝내기 전에 되돌린다. 지금은 곧바로 quit 하지만, 뒤에 기준을 하나만 더
	# 붙여도 게임 루프가 밑에서 돌기 시작한다 — 타이머가 줄고, 포식이 해소되고,
	# **move_hole 이 판정 실행자의 실제 키보드·마우스를 읽는다.**
	_main.judging = true
	ui.set_process(false)

	print("JUDGE 8 U1=%s U2=%s U3=%s U4=%s" % [pf(u1), pf(u2), pf(u3), pf(u4)])
	var ok2 := u1 and u2 and u3 and u4
	print("JUDGE RESULT -> %s" % ("PASS" if ok2 else "FAIL"))
	get_tree().quit(0 if ok2 else 1)


# --- §25: 지구제·수계 판정 --------------------------------------------------

## 존 대표 셀. 좌표는 판정기의 사본에서 고른 것이고 구현체를 읽지 않는다.
const ZONE_SPOTS := [
	["도심", SPEC_Z_DOWNTOWN, Vector3(-16.0, 0.0, -16.0)],      # 셀 (-1,-1)
	["상업", SPEC_Z_COMMERCIAL, Vector3(-80.0, 0.0, -80.0)],    # 셀 (-3,-3)
	["주거", SPEC_Z_RESIDENTIAL, Vector3(-144.0, 0.0, -144.0)], # 셀 (-5,-5)
	["공원", SPEC_Z_PARK, Vector3(-176.0, 0.0, 16.0)],          # 셀 (-6, 0) 서쪽 공원
	["수역", SPEC_Z_WATER, Vector3(80.0, 0.0, 16.0)],           # 셀 ( 2, 0) 강
]
## 톱다운 표본 카메라의 높이. FOV 75 에서 세로 약 92m — 셀 세 칸이 들어온다.
## 톱다운으로 보는 이유: 표본이 화면 한가운데로 떨어져 투영·가림·거리 페이드를
## 걱정할 필요가 없다. D 계열이 게임 카메라에서 겪은 문제(서브픽셀 중앙선 등)를
## 여기서는 처음부터 피한다.
const ZONE_CAM_Y := 60.0
## Z2: 서쪽 공원(k=-6..-5, j=0..1)의 **걷힌 내부 중심선** 위 표본.
## 여기에 아스팔트가 보이면 수퍼블록이 성립하지 않은 것이다.
const PARK_INNER := [Vector3(-160.0, 0.0, 32.0), Vector3(-160.0, 0.0, 20.0),
	Vector3(-160.0, 0.0, 44.0), Vector3(-172.0, 0.0, 32.0), Vector3(-148.0, 0.0, 32.0)]
## Z4: 교량 위 표본. **손으로 적지 않고 SPEC_BRIDGES 를 순회해 만든다.**
## 처음에는 z = 0·96 두 곳만 적었는데, 그 상태에서 셋째 교량(z = -96)을 city.gd 와
## 셰이더에서 동시에 지워도 judge7·3b·5 가 전부 통과했다(주입으로 실증) — 수역 셀에는
## 원래 프롭이 없어 T5 의 개수 트립와이어에도 안 걸린다. 규격이 "BRIDGES 전부" 라면
## 표본도 전부여야 한다. 목록에서 유도하면 교량을 더해도 판정이 저절로 따라온다.
func bridge_on_points() -> Array:
	var out := []
	for b in SPEC_BRIDGES:
		var z := float(int(b[0])) * SPEC_PITCH
		var cx := float(int(b[1])) * SPEC_PITCH
		out.append(Vector3(cx + 8.0, 0.0, z))                  # 셀 서쪽 1/4
		out.append(Vector3(cx + SPEC_PITCH - 8.0, 0.0, z))     # 셀 동쪽 1/4
	return out


## Z4: 교량이 아닌 강 위. 여기에도 도로가 있으면 강을 통째로 덮은 것이다.
const BRIDGE_OFF := [Vector3(72.0, 0.0, 32.0), Vector3(88.0, 0.0, 64.0),
	Vector3(72.0, 0.0, -64.0)]
## 아스팔트로 인정할 상한 둘. 물과 아스팔트를 가르는 것은 휘도가 아니라 색이다 —
## 둘 다 어둡지만 물만 파랗다(실측: 물 0.255 / 아스팔트 0.035). 임계는 그 중간이다.
## 초록 쪽도 함께 막는다: 파랑만 보면 **교량 자리가 잔디로 바뀐 빌드**가 통과한다
## (잔디는 파랗지 않다). 아스팔트는 무채색이라 두 우세도가 모두 0 근처여야 한다.
const ROAD_B_MAX := 0.14
const ROAD_G_MAX := 0.06
## 무채색 조건만으로는 부족하다 — **커브(0.72,0.72,0.70)와 도심 지면도 무채색이라
## 그대로 통과한다.** 교량 자리를 보도로만 칠하거나 도심 지면색으로 칠한 빌드가
## Z4 를 빠져나간다. 휘도 조건을 AND 로 더해 막는다.
##
## 절대 휘도 대신 **관계**로 적는다: 아스팔트는 어느 지구 지면보다 어둡고 물보다 밝다.
## Z1 이 같은 실행에서 다섯 지면을 이미 재므로 기준점이 공짜로 있고, 팔레트를 다시
## 잡거나 조명을 바꿔도 규격이 그대로 성립한다(실측 톱다운: 물 0.315 < 아스팔트 0.416
## < 도심 0.493 < 공원 0.515 < 상업 0.556 < 주거 0.574).
const ROAD_LUM_MARGIN := 0.02
## Z2 의 잔디 기준점이 실제로 잔디인지 묻는 하한.
## **기준점 자체를 단언하지 않으면 단방향 비교는 위약이다** — 존 텍스처를 한 칸 민
## 주입에서 기준점이 -0.0294(무채색)로 떨어졌는데도 "그보다 낮지 않다" 는 조건은
## 그대로 참이라 Z2 가 통과했다(주입으로 실증). 공원을 통째로 아스팔트로 칠해도 같다.
const PARK_G_MIN := 0.25


## 카메라를 지정 지점 바로 위에서 수직으로 내려다보게 세운다.
func top_down(at: Vector3) -> void:
	_cam.global_position = Vector3(at.x, ZONE_CAM_Y, at.z)
	_cam.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)


## 그 픽셀의 초록 우세도와 파랑 우세도. **조명 배율에 불변인 양**이다
## (모든 채널이 같은 배율로 곱해지면 차도 같은 배율로 곱해진다).
## 휘도를 쓰지 않는 이유: 네 지구의 지면은 D1·D4 때문에 [아스팔트, 커브] 사이 좁은
## 휘도 띠 안에 들어가야 해서, 휘도만으로는 서로 갈리지 않는다.
func chroma(img: Image, p: Vector3) -> Vector2:
	var c := img.get_pixelv(px(p, img))
	return Vector2(c.g - (c.r + c.b) * 0.5, c.b - (c.r + c.g) * 0.5)


## Z1~Z5. 지구제·수계·수퍼블록이 규격대로 그려지고 막히는가.
func run_judge_7() -> void:
	if not setup():
		get_tree().quit(1)
		return
	# Judge._ready 는 Main._ready 보다 먼저 돈다 — _main.hole 은 아직 Nil 이다.
	# 한 프레임 뒤 레지스트리에서 받는다(다른 판정과 같은 방식).
	await get_tree().process_frame
	var hole: Node3D = _reg.holes()[0]
	_main.hud_root.visible = false
	# 구멍을 표본에서 먼 구석으로 치운다. 톱다운이라 구멍이 표본 셀 위에 있으면
	# 우물이 그대로 표본 픽셀에 찍힌다.
	hole.move_to(Vector3(-176.0, 0.0, -176.0))
	_reg.flush()
	var saved := hide_props()
	await get_tree().process_frame

	# --- Z1: 존별 지면색 -----------------------------------------------------
	# 규격은 **순서**다: 공원이 가장 푸르고 도심이 가장 무채색이며 물만 파랗다.
	# 존 텍스처를 한 칸 밀면 대표 셀이 이웃 지구를 읽어 순서가 깨진다.
	var gd := {}
	var bd := {}
	var ld := {}
	for spot in ZONE_SPOTS:
		top_down(spot[2])
		for _i in 3:
			await get_tree().process_frame
		var shot := await capture("zone_%s" % spot[0])
		var ch := chroma(shot, spot[2])
		gd[int(spot[1])] = ch.x
		bd[int(spot[1])] = ch.y
		ld[int(spot[1])] = lum_at(shot, spot[2])       # Z4 의 아스팔트 기준점
		print("JUDGE 7 존 %s at (%.0f,%.0f) 초록우세=%.4f 파랑우세=%.4f 휘도=%.4f"
			% [spot[0], float((spot[2] as Vector3).x), float((spot[2] as Vector3).z),
			   ch.x, ch.y, ld[int(spot[1])]])
	var z1: bool = float(gd[SPEC_Z_PARK]) - float(gd[SPEC_Z_RESIDENTIAL]) >= ZONE_G_MARGIN \
		and float(gd[SPEC_Z_RESIDENTIAL]) - float(gd[SPEC_Z_COMMERCIAL]) >= ZONE_G_MARGIN \
		and float(gd[SPEC_Z_COMMERCIAL]) - float(gd[SPEC_Z_DOWNTOWN]) >= ZONE_G_MARGIN \
		and float(bd[SPEC_Z_WATER]) >= ZONE_W_MARGIN
	for z in [SPEC_Z_DOWNTOWN, SPEC_Z_COMMERCIAL, SPEC_Z_RESIDENTIAL, SPEC_Z_PARK]:
		z1 = z1 and float(bd[z]) < ZONE_W_MARGIN          # 물만 파랗다

	# --- Z2: 공원 수퍼블록 안에 도로가 없다 ----------------------------------
	top_down(Vector3(-160.0, 0.0, 32.0))
	for _i in 3:
		await get_tree().process_frame
	var park := await capture("zone_park_inner")
	# 기준점부터 단언한다 — 이것이 잔디가 아니면 아래의 단방향 비교는 아무것도 안 묻는다.
	var park_ref: float = float(gd[SPEC_Z_PARK])
	var z2: bool = park_ref >= PARK_G_MIN
	if not z2:
		print("JUDGE 7 Z2 기준점이 잔디가 아니다: 공원 초록우세=%.4f (>= %.2f 이어야 한다)"
			% [park_ref, PARK_G_MIN])
	for p in PARK_INNER:
		# 아스팔트·보도는 무채색이라 초록 우세도가 잔디보다 확 낮다.
		var gg := chroma(park, p).x
		var ok := gg >= park_ref - ZONE_G_MARGIN * 2.0
		z2 = z2 and ok
		print("JUDGE 7 공원내부 (%.0f,%.0f) 초록우세=%.4f (잔디 %.4f) %s"
			% [(p as Vector3).x, (p as Vector3).z, gg, park_ref, pf(ok)])

	# --- Z4: 교량은 있고, 교량이 아닌 강 위에는 도로가 없다 -------------------
	var z4 := true
	# 아스팔트의 휘도 기준점: 어느 지구 지면보다 어둡고 물보다 밝아야 한다.
	var land_min := INF
	for z in [SPEC_Z_DOWNTOWN, SPEC_Z_COMMERCIAL, SPEC_Z_RESIDENTIAL, SPEC_Z_PARK]:
		land_min = minf(land_min, float(ld[z]))
	var water_lum: float = float(ld[SPEC_Z_WATER])
	for p in bridge_on_points():
		top_down(p)
		for _i in 3:
			await get_tree().process_frame
		var img := await capture("zone_bridge_%d_%d" % [int((p as Vector3).x), int((p as Vector3).z)])
		var ch := chroma(img, p)
		var lm := lum_at(img, p)
		# 무채색이고(커브·잔디·물이 아니다) 어느 지면보다 어둡다(도심 지면·보도가 아니다).
		var ok: bool = ch.y < ROAD_B_MAX and absf(ch.x) < ROAD_G_MAX \
			and lm + ROAD_LUM_MARGIN <= land_min and lm >= water_lum + ROAD_LUM_MARGIN
		z4 = z4 and ok
		print("JUDGE 7 교량위 (%.0f,%.0f) 파랑우세=%.4f 초록우세=%.4f 휘도=%.4f (물 %.4f < ? < 지면 %.4f) %s"
			% [(p as Vector3).x, (p as Vector3).z, ch.y, ch.x, lm, water_lum, land_min, pf(ok)])
	for p in BRIDGE_OFF:
		top_down(p)
		for _i in 3:
			await get_tree().process_frame
		var img := await capture("zone_river_%d_%d" % [int((p as Vector3).x), int((p as Vector3).z)])
		var ch := chroma(img, p)
		var ok := ch.y >= ZONE_W_MARGIN                   # 물이다
		z4 = z4 and ok
		print("JUDGE 7 교량아님 (%.0f,%.0f) 파랑우세=%.4f %s"
			% [(p as Vector3).x, (p as Vector3).z, ch.y, pf(ok)])
	restore_props(saved)

	# 항공 뷰 두 장. **판정이 아니라 휴먼 검수용**이다 — 지구·강·공원·바다가 사람 눈에
	# 도시로 읽히는가는 기계가 답할 질문이 아니다(전역 원칙 §1).
	top_down(Vector3.ZERO)
	_cam.global_position = Vector3(0.0, 430.0, 0.0)
	for _i in 3:
		await get_tree().process_frame
	await capture("aerial_zones")
	await get_tree().process_frame
	await capture("aerial_city")

	# --- Z3: 수역 셀 안에 프롭이 하나도 없다 ---------------------------------
	var city: Node3D = _main.get_node("City")
	var items: Array = city.plan(city.city_seed)
	var in_water := 0
	for it in items:
		var p: Vector3 = it["pos"]
		if spec_zone(spec_cell_of(p.x), spec_cell_of(p.z)) == SPEC_Z_WATER:
			if in_water < 5:
				print("JUDGE 7 Z3 수역 위 프롭: %s at (%.1f, %.1f)" % [it["path"], p.x, p.z])
			in_water += 1
	var z3 := in_water == 0

	# --- Z5: 수역은 못 지나가고 교량은 지나간다 -------------------------------
	# 구현체의 passable 을 부르지 않는다. **구멍을 실제로 그리로 보내고** 어디에
	# 도착했는지 판정기의 사본으로 본다 — move_to 의 가드를 지우면 그대로 걸린다.
	var z5 := true
	var probes := [
		["강 한가운데", Vector3(80.0, 0.0, 32.0), false],
		["강 상류", Vector3(80.0, 0.0, -64.0), false],
		["바다 테두리", Vector3(-208.0, 0.0, 0.0), false],
	]
	# 교량은 **전부** 시험한다(Z4 와 같은 이유 — 손으로 둘만 적었더니 셋째를 지운
	# 주입이 모든 판정을 통과했다). 목록에서 유도하면 교량을 더해도 따라온다.
	for b in SPEC_BRIDGES:
		var z := float(int(b[0])) * SPEC_PITCH
		var cx := float(int(b[1])) * SPEC_PITCH + SPEC_PITCH * 0.5
		probes.append(["교량 z=%.0f" % z, Vector3(cx, 0.0, z), true])
	for pr in probes:
		var goal: Vector3 = pr[1]
		hole.move_to(Vector3(48.0, 0.0, goal.z))          # 목표 옆 육지에서 출발
		hole.move_to(goal)
		var landed := hole.global_position
		var dry := spec_passable(landed)
		var reached := landed.distance_to(goal) < 0.5
		var ok: bool = dry and reached == bool(pr[2])
		z5 = z5 and ok
		print("JUDGE 7 Z5 %s 목표(%.0f,%.0f) 도착(%.1f,%.1f) 육지=%s 도달=%s 기대=%s %s"
			% [pr[0], goal.x, goal.z, landed.x, landed.z,
			   pf(dry), pf(reached), pf(bool(pr[2])), pf(ok)])

	# --- Z6: 공원 영역은 직사각형이어야 한다 --------------------------------
	# 병합(merge_k·merge_j)이 축별 확장이라 L자·계단형 공원에서는 대표 셀이 여럿 나오거나
	# 구간이 실제 영역을 넘어선다 — 같은 자리에 밀도가 겹치고 프롭이 비-공원 셀을 침범한다.
	# 지도는 "사람이 읽고 고치라" 고 만든 표이므로 이 회귀는 언젠가 반드시 일어난다.
	# 주석으로만 적어 둔 전제를 기계가 지키게 한다.
	var z6 := true
	var seen := {}
	for j0 in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
		for k0 in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
			if spec_zone(k0, j0) != SPEC_Z_PARK or seen.has(Vector2i(k0, j0)):
				continue
			# 4방 연결성분을 훑는다.
			var comp := []
			var stack := [Vector2i(k0, j0)]
			seen[Vector2i(k0, j0)] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				comp.append(c)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x < SPEC_CELL_MIN or n.x > SPEC_CELL_MAX \
							or n.y < SPEC_CELL_MIN or n.y > SPEC_CELL_MAX:
						continue
					if seen.has(n) or spec_zone(n.x, n.y) != SPEC_Z_PARK:
						continue
					seen[n] = true
					stack.append(n)
			var lo := Vector2i(comp[0])
			var hi := Vector2i(comp[0])
			for c in comp:
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
			var area := (hi.x - lo.x + 1) * (hi.y - lo.y + 1)
			var rect := comp.size() == area
			z6 = z6 and rect
			print("JUDGE 7 Z6 공원 연결성분 k[%d..%d] j[%d..%d] 셀=%d 외접=%d %s"
				% [lo.x, hi.x, lo.y, hi.y, comp.size(), area, pf(rect)])

	print("JUDGE 7 Z1=%s Z2=%s Z3=%s Z4=%s Z5=%s Z6=%s (수역프롭=%d)"
		% [pf(z1), pf(z2), pf(z3), pf(z4), pf(z5), pf(z6), in_water])
	var ok := z1 and z2 and z3 and z4 and z5 and z6
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


# --- §21: 한글 HUD 판정 ----------------------------------------------------

## T8. 세 가지를 함께 묻는다.
##   ① 네 라벨이 **번들 폰트**를 쓰는가. 시스템 폴백에 기대면 데스크톱에서는
##      멀쩡하고 웹에서만 글자가 사라진다 — 판정기가 도는 데스크톱에서는
##      그 결함이 보이지 않으므로, **폰트의 출처**를 직접 물어야 한다.
##   ② 서브셋에 글리프가 다 있는가. 문구에 새 음절을 쓰면 그 글자만 조용히
##      사라진다. 지금 그려지는 문자열과, 판정기가 **따로 든** 문구 규격
##      양쪽으로 본다 — 구현체의 문자열만 보면 문구를 통째로 영문으로 되돌린
##      빌드가 자기 값끼리 일치해 그대로 통과한다.
##   ③ 한글이 실제로 화면에 잉크를 남기는가. 라벨을 비운 프레임과 채운 프레임을
##      찍어 라벨 영역의 **다른 픽셀 수**를 센다. 밝기 문턱으로 세면 3D 장면의
##      밝은 부분이 섞인다.
func judge_hud_font() -> bool:
	# update_hud() 가 매 프레임 `hud_over.visible = (state == OVER)` 를 다시 쓴다.
	# 판정 중에는 그것을 멈춰야 한다 — 안 그러면 라벨을 켜 두어도 다음 프레임에
	# 꺼져 잉크가 0 이 된다(실측: 첫 판이 그래서 떨어졌다).
	_main.judging = true
	var labels := {
		"Label": _main.hud, "Timer": _main.hud_timer,
		"Board": _main.hud_board, "Over": _main.hud_over,
	}
	# §26: 시작·결과 화면의 라벨·버튼도 같은 검사를 받는다. 이것들은 판정 모드에서
	# 보이지 않지만 **문자열은 이미 들어 있으므로** 글리프 검사에는 아무 지장이 없다 —
	# 오히려 이쪽이 중요하다. 화면에 잠깐만 뜨는 문구는 육안으로 놓치기 쉽다.
	var uin := _main.get_node_or_null("UI")
	if uin != null:
		for c in uin.get_children():
			if (c is Label or c is Button) and not str(c.text).is_empty():
				labels["UI/" + str(c.name)] = c
	# ① 폰트 출처
	var src_ok := true
	for k in labels:
		var f: Font = (labels[k] as Control).get_theme_font("font")
		var p := "" if f == null else f.resource_path
		if p != HUD_FONT_PATH:
			src_ok = false
			print("JUDGE 5 T8 %s 의 폰트가 번들본이 아니다: '%s'" % [k, p])
	# ② 글리프 커버리지
	var font: Font = (labels["Label"] as Control).get_theme_font("font")
	var shown := ""
	for k in labels:
		shown += str((labels[k] as Control).text)
	var need := SPEC_HUD_CHARS + shown
	# ②-b HUD 가 실제로 한글을 그리고 있는가. ①~③ 은 폰트만 보므로, 문구를 통째로
	# 영문으로 되돌린 빌드(= §21 이전 상태)가 전부 통과한다 — 그것도 회귀다.
	var kr := {}
	for i in shown.length():
		if SPEC_HUD_CHARS.contains(shown[i]):
			kr[shown[i]] = true
	var kr_ok: bool = kr.size() >= HUD_KR_MIN
	if not kr_ok:
		print("JUDGE 5 T8 HUD 에 한글이 %d 자뿐이다(>= %d 이어야 한다)" % [kr.size(), HUD_KR_MIN])
	var missing := ""
	if font != null:
		for i in need.length():
			var c := need.unicode_at(i)
			if c > 32 and not font.has_char(c) and not missing.contains(need[i]):
				missing += need[i]
	var glyph_ok: bool = font != null and missing.is_empty()
	if not glyph_ok:
		print("JUDGE 5 T8 글리프 없음: '%s'" % missing)
	# ③ 잉크
	var over: Label = labels["Over"]
	var kept := str(over.text)
	over.visible = true
	over.text = SPEC_HUD_CHARS
	var with_ink := await capture("hud_kr")
	over.text = ""
	var blank := await capture("hud_blank")
	over.text = kept
	var rect := over.get_global_rect()
	var ink := 0
	var x0 := maxi(int(rect.position.x), 0)
	var y0 := maxi(int(rect.position.y), 0)
	var x1 := mini(int(rect.end.x), with_ink.get_width())
	var y1 := mini(int(rect.end.y), with_ink.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			if with_ink.get_pixel(x, y).is_equal_approx(blank.get_pixel(x, y)):
				continue
			ink += 1
	var ink_ok: bool = ink >= HUD_INK_MIN
	print("JUDGE 5 T8: 폰트출처=%s 글리프=%s 한글=%d(>=%d) 잉크=%d(>=%d) 영역=%dx%d"
		% [pf(src_ok), pf(glyph_ok), kr.size(), HUD_KR_MIN, ink, HUD_INK_MIN,
		   x1 - x0, y1 - y0])
	return src_ok and glyph_ok and kr_ok and ink_ok


# --- §29: 카메라 멀미 판정 ---------------------------------------------------
## 카메라 리그 규격의 **판정기 사본**. 구현체(camera_rig.gd)에서 읽으면 오프셋이나
## 시정수를 바꾼 빌드가 자기 값끼리 일치해 통과한다 — 판정기가 따로 든다.
const SPEC_CAM_OFFSET := Vector3(0.0, 22.0, 26.0)
const SPEC_CAM_BASE_R := 5.0
const SPEC_CAM_MIN_H := 14.0
const SPEC_CAM_SMOOTH := 6.0
## 합성 dt. 판정은 프레임을 실제로 넘기되 **시간은 이 값으로 센다.** 브라우저 rAF 의
## 실측 dt 를 쓰면 저프레임 기기에서 목표점의 계단(ZOH) 간격이 커져 정상 빌드가
## 속도 상한을 넘는다(해석 상계: 20fps 에서 16.7 m/s > 16). 합성 dt 로는 세 플랫폼에서
## 궤적이 허용오차 안에서 결정적이고, 브라우저 게이트는 wasm 코드패스 검증만 진다.
const CAM_DT := 1.0 / 60.0
const CAM_MOVE_SPEED := 14.0     # 대본 주행 속도 (main.gd MOVE_SPEED 의 사본)
## V1: 각속도 상한(도/초). 회전이 상수이므로 기대값은 0 — 부동소수 여유만 준다.
## look_at 추적이던 §28 이전 리그는 방향 반전에서 86 °/s 를 냈다(실측, 멀미 기제).
const CAM_ROT_MAX_DPS := 0.1
## V1: 대본 전체의 누적 회전 편차 상한(도). 율 상한만으로는 문턱 밑의 일정한
## 회전이 누적되는 것을 못 잡는다 — 시작 basis 대비 총 편차 각을 함께 본다.
const CAM_ROT_TOTAL_DEG := 0.01
## V2: 성장 후퇴 속도 상한. 구현의 grow_smooth 에서 파생하지 않는 **규격 선언**이다 —
## "카메라는 주행 추적(14 m/s)보다 눈에 띄게 빨리 물러나지 않는다". 평활 없던 §28
## 이전 리그는 83 m/s 를 냈다(실측).
const CAM_RECEDE_MAX := 16.0
const CAM_SETTLE_SEC := 2.5      # V2: 성장 후 수렴을 묻는 시점(초)
const CAM_SETTLE_TOL := 1.0      # V2: 그때 목표점과의 허용 거리(m) — 수렴 하한
const CAM_GROW_OBJ_R := 5.0      # V2: 성장 이벤트로 삼키는 물체 반경
const CAM_STEP_D := 10.0         # V4: 계단 크기(m)
const CAM_STEP_SEC := 0.5        # V4: 계단 후 관찰 시간(초)
const CAM_STEP_TOL := 0.05       # V4: 잔차 허용 오차(m)
const CAM_STEP_DTS := [1.0 / 30.0, 1.0 / 120.0]   # V4: 두 합성 dt
const CAM_ELEV_DEG := 40.236     # V3: 앙각 atan2(22, 26) — H9 프레이밍 전제
const CAM_ELEV_TOL := 0.01
const CAM_POS_TOL := 1e-4        # V3·대본 전제: 위치 오차 허용
## V1 대본: [이름, 프레임 수, 방향]. 실측 도구(cam_diag)의 대본을 판정이 흡수했다.
## 반전 쌍을 두 축 모두 넣는다 — look_at 회귀의 각속도가 반전에서 최대였다.
const CAM_SCRIPT := [
	["주행+x", 90, Vector3(1, 0, 0)],
	["반전-x", 90, Vector3(-1, 0, 0)],
	["주행+z", 90, Vector3(0, 0, 1)],
	["반전-z", 90, Vector3(0, 0, -1)],
	["정지", 60, Vector3.ZERO],
]


## 규격 오프셋 배율. camera_rig.follow 의 k 와 같은 식이지만 **규격 상수로만** 계산한다.
func cam_spec_k(r: float) -> float:
	return maxf(r / SPEC_CAM_BASE_R, SPEC_CAM_MIN_H / SPEC_CAM_OFFSET.y)


## §29 V1~V4. 판정기가 게임 루프의 카메라 호출을 재현한다 — 판정 모드에서는
## main._process 가 일찍 반환해 follow 를 부르지 않으므로, 여기서 직접 부른다.
## 스크린샷은 찍지 않는다. 묻는 것은 넷:
##   V1 회전 안정 — 대본(주행·반전·정지·성장) 전 구간에서 카메라 회전이 상수인가.
##   V2 성장 후퇴 — 반경이 계단으로 뛸 때 후퇴 속도가 상한 아래이고, 그러면서도
##      제 시간 안에 목표점에 **수렴하는가** (상한만 물으면 안 움직이는 카메라가 통과한다).
##   V3 스냅 프레이밍 — snap 경로가 규격 위치·앙각을 정확히 재현하는가 (H 계열 전제).
##   V4 계단 응답 — 평활이 프레임률과 무관한가. 목표가 정지한 계단 응답은 ZOH 오차가
##      없어 잔차가 정확히 D·e^(-smooth·T) 다. 두 합성 dt 에서 같은 값이 나와야 한다 —
##      clampf(rate·dt) 식은 1/30 에서 0.352 를 내 확실히 걸린다(감사가 산술로 확인).
func run_judge_10() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var hole: Node3D = _reg.holes()[0]
	# 카메라만 계측한다. 물리를 끄지 않으면 대본 경로의 프롭·픽스처가 흡입돼 반경이
	# 규격에서 어긋나고 V2 의 기대 종점이 오염된다(계획 감사가 잡았다).
	hole.set_physics_process(false)

	# --- 대본 전제: 시작 반경이 규격이고, 원점(광장, 통행 가능)에 안착한다 -----
	hole.move_to(Vector3.ZERO)
	var pre_r: bool = absf(float(hole.radius) - SPEC_START_R) < 1e-6
	var pre_p: bool = hole.global_position.distance_to(Vector3.ZERO) < CAM_POS_TOL
	print("JUDGE 10 전제: 반경=%.4f(규격 %.1f) %s 원점 안착 %s"
		% [float(hole.radius), SPEC_START_R, pf(pre_r), pf(pre_p)])
	if not (pre_r and pre_p):
		print("JUDGE RESULT -> FAIL")
		get_tree().quit(1)
		return

	# --- V3: 스냅 프레이밍 (성장 전, r = SPEC_START_R) -------------------------
	_cam.follow(hole, hole.radius, true)
	var want0: Vector3 = hole.global_position + SPEC_CAM_OFFSET * cam_spec_k(SPEC_START_R)
	var v3_pos: bool = _cam.global_position.distance_to(want0) <= CAM_POS_TOL
	var fwd: Vector3 = -_cam.global_basis.z
	var elev := rad_to_deg(atan2(-fwd.y, Vector2(fwd.x, fwd.z).length()))
	var v3_elev: bool = absf(elev - CAM_ELEV_DEG) <= CAM_ELEV_TOL
	var aim: Vector3 = (hole.global_position - _cam.global_position).normalized()
	var v3_aim: bool = rad_to_deg(fwd.angle_to(aim)) <= CAM_ELEV_TOL
	var v3: bool = v3_pos and v3_elev and v3_aim
	print("JUDGE 10 V3 스냅 오차=%.6f 앙각=%.4f(규격 %.3f±%.2f) 조준오차=%.4f° %s"
		% [_cam.global_position.distance_to(want0), elev, CAM_ELEV_DEG, CAM_ELEV_TOL,
		   rad_to_deg(fwd.angle_to(aim)), pf(v3)])

	# --- V4: 계단 응답 — 평활의 프레임률 독립 ----------------------------------
	var v4 := true
	for sdt_v in CAM_STEP_DTS:
		var sdt := float(sdt_v)
		hole.move_to(Vector3.ZERO)
		_cam.follow(hole, hole.radius, true)
		var stepped := Vector3(CAM_STEP_D, 0.0, 0.0)
		hole.move_to(stepped)
		# 전제: 순간이동이 미끄러지지 않았다. move_to 는 통행 불가 지점에서 축별로
		# 미끄러지므로(§25), 착지점이 명령점과 다르면 판정이 아니라 대본이 틀린 것이다.
		var landed: bool = hole.global_position.distance_to(stepped) < CAM_POS_TOL
		var n := int(round(CAM_STEP_SEC / sdt))
		for _i in n:
			await get_tree().process_frame
			_cam.follow(hole, hole.radius, false, sdt)
		var want_s: Vector3 = stepped + SPEC_CAM_OFFSET * cam_spec_k(SPEC_START_R)
		var rem := _cam.global_position.distance_to(want_s)
		var expect := CAM_STEP_D * exp(-SPEC_CAM_SMOOTH * CAM_STEP_SEC)
		var ok: bool = landed and absf(rem - expect) <= CAM_STEP_TOL
		v4 = v4 and ok
		print("JUDGE 10 V4 dt=1/%d 프레임=%d 잔차=%.4f 기대=%.4f±%.2f 안착=%s %s"
			% [int(round(1.0 / sdt)), n, rem, expect, CAM_STEP_TOL, pf(landed), pf(ok)])

	# --- V1: 대본 주행 — 회전이 상수인가 (성장 구간까지 계속 계측) --------------
	hole.move_to(Vector3.ZERO)
	_cam.follow(hole, hole.radius, true)
	var basis0: Basis = _cam.global_basis
	var max_dps := 0.0
	var prev_basis: Basis = _cam.global_basis
	# 대본 전제: 구멍이 규격 경로를 **실제로 달렸는가.** move_to 는 통행 불가 지점에서
	# 미끄러지므로(§25), 배치가 바뀌어 경로가 막히면 구멍이 서고 V1 은 정지 카메라를
	# 상수 회전으로 오판해 공허하게 통과한다(코드 감사가 잡았다). 세그먼트 끝마다
	# 규격 누적 위치와 대조한다 — 대본이 원점 복귀 대칭이라 끝점만 보면 못 잡는다.
	var drove := true
	var expect_pos := Vector3.ZERO
	for seg in CAM_SCRIPT:
		var dir: Vector3 = seg[2]
		for _i in int(seg[1]):
			await get_tree().process_frame
			if dir != Vector3.ZERO:
				hole.move_to(hole.global_position + dir * CAM_MOVE_SPEED * CAM_DT)
			_cam.follow(hole, hole.radius, false, CAM_DT)
			var dps := rad_to_deg((prev_basis.inverse() * _cam.global_basis)
				.get_rotation_quaternion().get_angle()) / CAM_DT
			max_dps = maxf(max_dps, dps)
			prev_basis = _cam.global_basis
		expect_pos += dir * CAM_MOVE_SPEED * CAM_DT * int(seg[1])
		if hole.global_position.distance_to(expect_pos) >= CAM_POS_TOL:
			drove = false
			print("JUDGE 10 V1 대본 전제 위반: %s 끝 위치 %s (기대 %s)"
				% [seg[0], str(hole.global_position), str(expect_pos)])

	# --- V2: 성장 후퇴 — 상한과 수렴 -------------------------------------------
	hole.grow_by(CAM_GROW_OBJ_R)
	var spec_r1 := sqrt(SPEC_START_R * SPEC_START_R
		+ SPEC_GROWTH_K * CAM_GROW_OBJ_R * CAM_GROW_OBJ_R)
	# 전제: 성장식이 규격과 일치. 성장식 자체는 C 계열의 몫이지만, 어긋나면
	# V2 의 기대 종점이 무의미해지므로 전제로 못 박는다.
	var pre_g: bool = absf(float(hole.radius) - spec_r1) < 1e-4
	var max_recede := 0.0
	var prev_pos: Vector3 = _cam.global_position
	for _i in int(round(CAM_SETTLE_SEC / CAM_DT)):
		await get_tree().process_frame
		_cam.follow(hole, hole.radius, false, CAM_DT)
		max_recede = maxf(max_recede, _cam.global_position.distance_to(prev_pos) / CAM_DT)
		prev_pos = _cam.global_position
		var dps := rad_to_deg((prev_basis.inverse() * _cam.global_basis)
			.get_rotation_quaternion().get_angle()) / CAM_DT
		max_dps = maxf(max_dps, dps)
		prev_basis = _cam.global_basis
	var want1: Vector3 = hole.global_position + SPEC_CAM_OFFSET * cam_spec_k(spec_r1)
	var settle := _cam.global_position.distance_to(want1)
	# 누적 편차: 율(도/초)만 물으면 문턱 밑에서 일정하게 도는 카메라가 대본 내내
	# 0.66° 를 누적해도 통과한다. 스냅 직후 basis 대비 총 편차 각을 함께 단언한다.
	var drift := rad_to_deg((basis0.inverse() * _cam.global_basis)
		.get_rotation_quaternion().get_angle())
	var v1: bool = drove and max_dps <= CAM_ROT_MAX_DPS and drift <= CAM_ROT_TOTAL_DEG
	var v2: bool = pre_g and max_recede <= CAM_RECEDE_MAX and settle <= CAM_SETTLE_TOL
	print("JUDGE 10 V1 주행=%s 최대 각속도=%.4f 도/초 (<= %.1f) 누적 편차=%.4f° (<= %.2f) %s"
		% [pf(drove), max_dps, CAM_ROT_MAX_DPS, drift, CAM_ROT_TOTAL_DEG, pf(v1)])
	print("JUDGE 10 V2 성장식=%s 후퇴 최대=%.2f m/s (<= %.0f) %.1f초 후 잔차=%.3f m (<= %.1f) %s"
		% [pf(pre_g), max_recede, CAM_RECEDE_MAX, CAM_SETTLE_SEC, settle,
		   CAM_SETTLE_TOL, pf(v2)])

	var ok_all: bool = v1 and v2 and v3 and v4
	print("JUDGE 10 V1=%s V2=%s V3=%s V4=%s -> %s"
		% [pf(v1), pf(v2), pf(v3), pf(v4), "PASS" if ok_all else "FAIL"])
	print("JUDGE RESULT -> %s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)
```

### 이 판정기의 유효 전제 (1b 확장 시 반드시 손봐야 할 곳)

`screenshot.gd`는 1a 구성에 결합돼 있다. 아래 전제가 깨지면 **정상 구현이 탈락한다** — 실측: `Hole`만 x=20으로 옮기면(여전히 지면 위, 렌더는 정상) `H2=F`로 실패한다.

| 전제 | 깨지면 | 1b에서의 대응 |
|---|---|---|
| 구멍이 화면 중앙부에 있다 | 화면 가장자리에서는 우물 명암 자체가 옅어져 H2 링 진폭이 임계 아래로 떨어진다(실측 x=20에서 0.0118) | 판정 직전 카메라를 구멍 정면으로 스냅 |
| 구멍이 지면 경계에서 1.15R 이상 안쪽 | H7 다각형이 지면 밖 배경을 먹는다 | 다각형을 지면 실루엣과 교집합(가장 견고한 방법은 지면만 렌더한 마스크 프레임을 한 장 더 찍는 것) |
| **다른 오브젝트가 구멍을 가리지 않는다** | H2 링 표본이 그 오브젝트를 읽어 `inside=false`가 된다. 실측: 구멍을 x=8로 옮기면 `RefBox(8,1,6)`에 가려 표본이 0.4999(박스 휘도)를 읽는다 | 링 표본에 깊이 검사를 붙이거나 판정용 배치를 따로 둔다 |
| 카메라 고정 | 표본 좌표·스캔라인이 어긋난다 | 판정 직전 카메라를 고정 위치로 스냅 |
| ~~`GROUND_SAMPLE` 상수 `(-16,0,8)`가 지면 위~~ | ~~`lum_g`가 배경이 되어 H1·H2 붕괴~~ | **3a에서 해소.** 도시 격자에서는 절대 좌표가 도로 위에 떨어진다 → `probe_blocks()`가 규격 격자로 **블록 중앙**을 계산해 고른다 |
| ~~화면 모서리 `(4,4)`가 배경~~ | ~~지면이 넓어지면 배경이 아니게 되어 H6가 무의미해진다~~ | **3a에서 해소.** `background_pixel()`이 **탐침 프레임에서 실제로 마젠타인 모서리**를 찾아 그 좌표로 `lum_bg`를 잰다. 네 모서리가 전부 배경이 아니면 판정을 무효로 하고 실패시킨다 |
| **`ambient_light_source`가 Color(=2)** | H7 탐침 프레임의 마젠타 배경이 조명까지 바꿔 다른 기준도 흔들린다 | Sky 앰비언트로 바꾸면 탐침 시 앰비언트를 함께 고정 |
| ~~**지면이 균질하고 배경 대비가 `EDGE_THR`보다 큼**~~ | ~~H3가 무너진다~~ | **3a에서 해소 — H3 폐기.** 예고대로 정상 빌드가 탈락했다(12→12) |

**기준 프레임 획득이 2패스인 이유**: H3는 "기준 프레임 대비 증분"으로 판정한다. 기준값을 상수로 박으면 카메라·해상도가 바뀌는 순간 무너진다. `hole_count=0`으로 한 번, 복원 후 한 번 찍는다. 이 사이 `main.gd._process`의 `flush()`가 `hole_count`를 즉시 되돌리므로 **`judging` 플래그로 막는다** — `set_process(false)`는 V20 때문에 통하지 않는다.

**로그는 실패 진단의 유일한 단서다.** 표본 픽셀 좌표, 6개 휘도, 두 프레임의 엣지 그룹 수, 각 기준의 P/F를 전부 남긴다. `base.png`/`shot.png`가 저장되므로 **기준 프레임이 실제로 구멍 없이 찍혔는지 눈으로 확인할 수 있다.**

### 기계 판정 기준

**표본은 전부 월드 좌표를 `Camera3D.unproject_position()`으로 투영해 얻는다.** 원근에서 구멍은 타원이므로 "반경을 픽셀로 환산"하지 않는다. rev.3의 H2는 이 원칙을 선언한 직후 스스로 위반해 실패했다.

| ID | 기준 | 검출 대상 | 실측 (정상 / 붕괴) |
|---|---|---|---|
| **H1** | `lum(p_c) ≤ lum(p_g) × 0.5` | 지면이 실제로 뚫렸는가 | 0.155 ≤ 0.320 ✔ (붕괴도 통과 — 필요조건) |
| **H2** | 반경 0.6R **링 위 32방향** 표본이 전부 구멍 안(`≤ lum(p_g) × 0.5`)이고 **최대−최소 ≥ 0.02** | 우물 내부에 **명암**이 있는가 = 원통이 실제로 보이는가 | **0.1067 ✔ / 0.0000 ✘** |
| ~~**H3**~~ | ~~엣지 **그룹** 수가 기준 프레임 대비 **+2 이상**~~ | **3a에서 폐기.** 지면에 도로가 들어오자 기준·판정 프레임이 같은 도로 엣지를 세어 **정상 빌드가 12→12로 탈락**했다(rev.8이 예고한 그대로). 윤곽의 존재는 H7·H8이 더 강하게 판정한다. 로그에는 진단용으로만 남긴다 | — |
| **H4** | uniform 목록에 `holes`(타입 `PackedVector4Array`)·`hole_count` 존재 **AND** 리터럴 이름으로 되읽은 배열이 size 16 **AND** `hole_count == registry.hole_count()` **AND** 등록된 **모든** 슬롯의 `w > 0` | uniform 이름 오타·타입·개수·빈 슬롯 | ✔ |
| **H5** | `ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"` | 키 누락·오타 | ✔ |
| **H6** | `abs(lum(p_c) − lum_bg) ≥ 0.03` | 중심 픽셀이 배경인가 (값싼 1차 필터) | 0.0643 ✔ (**여유가 얇다 — 아래 참조**) |
| **H7** | **배경을 마젠타로 바꿔 찍은 탐침 프레임**에서, 반경 1.15R 원을 32방향 투영한 **다각형 안**의 `min(r,b) − g > 0.4` 픽셀 수 **≤ 림 둘레 픽셀 × 1%** | **지면–우물 이음새와 정렬** | **0/3 ✔ / 139·3341·8100 ✘** |
| **H8** | 림을 **32방향**으로 가로지르며 전이의 **최대 단차 / 국소 진폭 < 0.7**인 방향이 **4개 이상**(유효 방향 16개 이상) | **커버리지 AA가 살아 있는가** = §2의 결정이 유지되는가 | **18/32 ✔ / 0/32 ✘** |
| **H9** | `well_depth() ≥ 2R · tan(카메라 앙각)` | **우물 바닥이 보이지 않는가** — 얕은 우물은 "대야"로 보인다 | 12.00 ≥ 8.46 ✔ / 4.00 ✘ |
| **H10** | 셰이더 `render_mode`에 `alpha_to_coverage`·`depth_prepass_alpha`가 있고, `msaa_3d > 0`, `rendering_method == "forward_plus"` | §2·§5의 결정이 구조적으로 유지되는가 | ✔ |
| **—** | `px()`가 화면 밖을 클램프하지 않았을 것 | 표본이 화면을 벗어나면 모서리 배경을 재게 되어 원인 불명의 오판정이 난다 | `clamped=false` |

**축을 세로가 아니라 가로로 잡은 이유**: 태양 방위각이 −35°이므로 우물 내부 명암은 **좌우 방향**으로 생긴다. 중심 세로열은 y 288~368 전 구간에서 0.1537~0.1576으로 사실상 평탄하다 — rev.3의 H2는 명암이 존재하지 않는 축을 표본해 정상 프레임에서도 Δ=0.0008로 탈락했다.

**H4가 세 조건을 모두 요구하는 이유**
- `get_shader_uniform_list()` 대조만으로는 **레지스트리가 무엇을 주입했는지 알 수 없다** — 셰이더는 어차피 uniform을 선언하고 있으므로 이 검사는 셰이더 파일만 본다.
- `get_shader_parameter`는 머티리얼 캐시를 반환하므로, 레지스트리와 같은 변수로 되읽으면 오타가 있어도 통과한다(§0-C(3)). **셰이더가 선언한 리터럴 이름 `"holes"`로 되읽어야** 오타가 드러난다.
- `hole_count == registry.hole_count()` 비교가 **`set_target_material()` 미호출을 잡는다**: 주입이 안 되면 `flush()`가 초입에서 반환해 판정 프레임의 `hole_count`가 기준 프레임 값(0)에 머무는 반면 레지스트리는 1을 보고한다.

**H6은 단독으로 정렬을 증명하지 못한다 — H7이 그 역할이다.** H6은 중심 **한 픽셀**만 보므로 중심만 우물에 덮여 있으면 통과한다(rev.5가 우물 0.8R과 구멍 0.4R 오정렬을 놓친 이유). 게다가 여유도 얇다: 구멍을 크게 옮겨 완전히 붕괴시켜도 중심 픽셀이 배경이 아니라 **그림자 진 우물 벽(0.0627)** 에 떨어져 `dCB = 0.0278`이 나오는데, 이는 임계값 0.03 바로 아래다(여유 7%). rev.5 표의 "붕괴 0.0000"은 §0-C(2)의 특정 구성에서만 성립한 값이었다. **H6은 값싼 1차 필터로 남기고, 정렬의 실질 판정은 H7이 한다.**

**H2가 전제조건을 요구하는 이유**: `|lum_l − lum_r|`는 "좌우 픽셀이 다른가"만 잰다. 구멍이 크게 어긋나 좌측 표본이 **일반 지면**(0.6393)에 떨어지면 차이가 0.47로 커져 오히려 통과한다(실측). 두 표본이 실제로 구멍 안이라는 보장이 없으면 H2는 우물 명암을 재는 기준이 아니다.

**H5의 한계**: `PhysicsServer3D.get_class()`는 Jolt/GodotPhysics 모두 `"PhysicsServer3D"`만 반환하므로 **활성 서버를 런타임에서 확인할 수단이 없다.** H5는 "ini 키가 정확히 적혔는가"만 증명한다(오타 시 엔진은 경고조차 내지 않는다).

**임계값 근거**

| 값 | 근거 |
|---|---|
| H1 `0.5` | 실측 ratio 0.242 — 2배 여유 |
| H2 `0.02` | 정상 링 진폭 0.1067(5배 여유). 우물이 없으면 링이 전부 배경색이라 0.0000 |
| H3 `+2` | 그룹 병합 후 좌우 2개. 이론 최소치와 같으므로 **그룹 병합이 전제다** |
| H6 `0.03` | 정상 0.0643, 완전 붕괴 0.0278 — **여유 7%로 얇다.** H7이 실질 판정이므로 값싼 필터로만 유지 |
| H7 `≤ 둘레×1%` | **절대 개수로 두면 안 된다** — 림 둘레가 길어질수록 AA 부분픽셀이 늘어 정상 빌드가 탈락한다(실측: `radius=12`에서 `leak=3`). 둘레 비례로 바꾸면 R=1/5/12에서 모두 `leak=0`이고, 진짜 결함은 `wall_scale=1.00 → 139/3`, 우물 없는 두 번째 구멍 → `3341/2`로 두 자릿수 이상 초과한다 |
| `MAGENTA_TH` `0.4` | 문턱별 실측(`1.03 / 1.02 / 1.01 / 1.00 / 0.8R`): `0.0 → 6/93/196/277/2109`, `0.1 → 0/18/123/217/2033`, **`0.4 → 0/0/31/139/1951`**. 0.4에서만 "1.02 이상 통과, 1.01 이하 탈락"이 성립한다 |
| H8 `≥ 4` 방향 | **한 스캔라인으로는 안 된다** — 서브픽셀 정렬에 따라 정상 빌드도 그 줄에 중간 픽셀이 없을 수 있다(실측). 32방향에서 A2C는 11~24, 하드 알파·MSAA 끔은 **0**. 0과 11 사이라 4는 양쪽에 2배 이상 여유 |
| `RIM_STEP_MAX` `0.7` | 전이 단차를 **국소** 진폭으로 나눈다. A2C ≈ 0.5, 하드 알파 = 1.0. 창 전체의 min/max로 정규화하면 접지 그림자·도로 그라디언트가 진폭을 부풀려 하드 알파가 통과한다(실측: 정상 8309 vs 회귀 8412로 구분 불가였다) |
| H9 `2R·tan(앙각)` | 근측 림을 지나는 시선이 바닥에 닿지 않을 기하 조건. 현 카메라(40.2°)에서 `depth_ratio ≥ 1.69`. 앙각이 바뀌면 자동으로 따라간다 |
| edge `0.08` | 지면(0.639) ↔ 우물(0.155) 대비의 1/6 |

**H7이 "탐침 프레임"을 따로 찍는 이유** — 두 번의 실패에서 배웠다.
1. **정확일치 판정**(초안)은 V21이 측정한 AA 부분픽셀 누출을 전부 0으로 세어 `wall_scale=1.00`을 통과시켰다.
2. **프레임에서 표본한 색으로 삼각형을 만들어 거리 비교**하는 방식은 팔레트에 의존했다 — 우물 albedo만 `Color(0.13,0.14,0.18)`(콘크리트 수직갱)로 바꾸면 **결함 없는 프레임이 `leak=1574`로 탈락**하고, 같은 팔레트의 진짜 고장(0.8R)은 1758이라 **정상과 고장을 구분하지 못했다**.

배경을 마젠타로 강제해 한 프레임 더 찍으면 두 문제가 동시에 사라진다. 마젠타는 어떤 씬 팔레트와도 겹치지 않으므로 지면·우물 색을 바꿔도 판정이 흔들리지 않는다(실측: 우물색 변경 시 정상 `leak=0`, 같은 팔레트 0.8R `leak=1950`).

**H8이 bbox 전체가 아니라 림만 보는 이유** — bbox 전체의 중간 톤을 세면 **지면에 부드러운 그라디언트가 하나만 있어도 무력화된다.** 실측: 구멍 주변 AO 링을 넣으면 A2C 정상 `mids=8309` vs `discard` 회귀 `mids=8412`로 **구분 불가**였다. 이것은 가정이 아니라 §1이 계획한 경로다(도로·인도를 지면 셰이더에서 그린다). 림 전이 폭만 재면 같은 조건에서 정상 2 / 회귀 0으로 갈린다.

**육안 확인** (기계 판정 통과 후 `shot.png`를 직접 확인): (a) 원형 구멍, (b) 우물 벽 명암, (c) 엣지 매끄러움, (d) 지면–우물 이음새. **착시가 "그럴듯한가"는 기계 판정 불가이며 이 단계가 최종 관문이다.**

### 1a 완료 정의 (DoD)

**1단계 4파일 전부 exit 0** AND **2단계 오류 패턴 0건**(`SHADER ERROR|SCRIPT ERROR|USER ERROR|^ERROR:`) AND **3단계 `JUDGE ... -> PASS` (exit 0)** AND **육안 (a)~(d) 이상 없음.**

**육안 항목의 판정 기준** — 주관을 줄이기 위해 각각 대응하는 계측값을 함께 본다. 기계 판정이 이미 이들을 커버하므로 육안은 **기계가 못 보는 전체 인상**을 확인하는 단계다.

| 육안 항목 | 대응 계측 | 육안으로만 판단하는 것 |
|---|---|---|
| (a) 원형 구멍 | H3 `delta=2`, H1 | 타원이 찌그러지거나 잘리지 않았는가 |
| (b) 우물 벽 명암 | H2 `dRing`(링 진폭) | 명암 방향이 태양과 맞는가(좌측이 어두운가) |
| (c) 엣지 매끄러움 | H8 `rim_aa`(부드러운 전이 방향 수) | 계단이 눈에 띄는가 |
| (d) 이음새·깊이 | H7 `leak ≤ tol`, H9 `depth` | 벽 링이 지면 위로 돌출하지 않았는가, 바닥이 보이지 않는가 |

`probe.png`(마젠타 배경)도 함께 저장되므로 **누출이 있다면 어디서 새는지 눈으로 바로 확인할 수 있다** — 테두리 전체면 반경 문제, 한쪽 초승달이면 정렬 문제다.

### 1b DoD — 구현·검증 완료

`-- --judge1b` 로 실행한다. 1a 판정(H1~H10)을 **이동한 위치에서 다시 돌리고**, 흡입 물리를 기계 판정한다.

| ID | 기준 | 검출 대상 | 실측 (정상 / 고장) |
|---|---|---|---|
| **B1** | 구멍을 `(-6,0,6)`으로 옮기고 카메라를 스냅한 뒤 **H1~H10 전부 통과** | 이동해도 착시가 유지되는가 | 원점과 동일한 `ring[0.0627..0.1694] leak=0/3 rim_aa=18/32` |
| **B2** | 제한 프레임 안에 흡입 대상이 **전부 소멸** | 흡입이 끝까지 도달하는가 | `6/6, 221 프레임` |
| **B3** | **낙하 전환 순간**에 `dist + obj_radius ≤ hole_radius` | §4-D-2의 "구멍 옆 지면 속으로 가라앉음" | `margin 0.000` / 즉시 전환 `−1.578`, 반경 과소평가 `−0.057` |
| **B4** | 낙하 전환 후 `layer & other.mask == 0` **이고** `other.layer & mask == 0` | 낙하체가 남은 오브젝트를 들이받는가 | `0` / 레이어 미전환 `5건` |

**B3은 상태가 아니라 전환 순간을 본다.** 처음에는 "구멍 밖에 있는데 지면 아래로 내려간 오브젝트"를 세었는데, 구멍이 다음 대상으로 이동하면 **우물 안에서 정상 낙하 중인 오브젝트도 "구멍 밖"이 되어** 정상 빌드가 142건 위반으로 나왔다.

**B3은 오브젝트 반경을 구현체에서 읽지 않고 콜라이더에서 직접 잰다.** 처음에는 `swallowable.radius`를 그대로 썼는데, 산출식을 XZ 최대 절반값(계획이 41% 과소평가라 지적한 그것)으로 바꾼 고장본이 **판정도 같은 값으로 오염되어 그대로 통과**했다.

**고장 주입 결과**

| 주입 | 결과 | 잡은 기준 |
|---|---|---|
| *(정상 빌드)* | **PASS** | — |
| `body_entered`에서 즉시 레이어 전환 (§4-D-2가 금지한 것) | FAIL | B3 `dist=5.381 + r=0.849 > R=5.000` |
| `obj_radius`를 XZ 대각선이 아니라 최대 절반값으로 | FAIL | B3 `구현이 쓴 r=0.600` vs 실제 `0.849` |
| 낙하 시 mask만 0으로 하고 layer는 유지 | FAIL | B4 `5건` (지면 통과는 정상 — §4-C 정정 참조) |

**아직 기계 판정이 없는 것**: 카메라 추적의 부드러움, 흡입의 손맛("가장자리에서 덜덜 떨다 빨려듦"), 입력 반응성 — 전부 육안·수동 조작으로 확인한다.

### 실패 트리아지

| 증상 | 1차 의심 | 확인 |
|---|---|---|
| 1단계 exit 1 | autoload 직접 식별자 사용(V16) | 로그에 `Identifier not found: HoleRegistry` → `get_node("/root/...")`로 교체 |
| H4 실패 | uniform 이름 오타 / `set_target_material` 미호출 | `get_shader_uniform_list()` 출력, `hole_count` 되읽기 값과 `registry.hole_count()` 비교 |
| H1 실패 (구멍이 안 뚫림) | uniform이 GPU에 도달 안 함 | H4 먼저 확인 → 셰이더 `ALPHA` 식 |
| **H7 실패 (`leak > tol`)** | 우물 반경이 구멍보다 작다 / 구멍과 우물이 어긋났다 / `wall_scale·wall_margin_min` 부족 | `probe.png`에서 새는 위치를 본다 — 테두리 전체면 반경, 한쪽 초승달이면 정렬. 로그의 `hole<N>` 번호로 어느 구멍인지 특정된다 |
| **H8 실패 (`rim_aa` 통과 방향 < 4)** | 셰이더 `ALPHA`가 이진값이 됐다 / `render_mode` 누락 / `msaa_3d` 꺼짐 | H10 동반 실패면 `render_mode`·`msaa_3d`, H10이 P인데 H8만 F면 `ALPHA` 식이 하드해졌는지 |
| **H9 실패** | 우물이 얕아 바닥이 보인다 / 카메라 앙각이 높아졌다 | 로그의 `depth=현재/필요`. `depth_ratio`를 올리거나 앙각을 낮춘다 |
| **H10 실패** | `render_mode`에서 `alpha_to_coverage`·`depth_prepass_alpha` 누락 / `msaa_3d=0` / 렌더러가 `forward_plus`가 아님 | `ground_hole.gdshader` 1행, `project.godot`의 `[rendering]` |
| H6 실패 (구멍 아래로 배경) | 우물 미배치·비표시·반경 불일치 | `Well.visible`, `mesh.top_radius` vs `radius × wall_scale`. H7 동반 실패 여부 |
| H2 실패 (내부 평탄) | 우물 머티리얼 UNSHADED / 조명 없음 / 우물 미배치 | `shading_mode`, `Sun.shadow_enabled`, H6 동반 실패 여부 |
| **H3 실패이고 `base == shot`** | **기준 프레임 획득 실패** — `judging` 플래그 미적용 또는 `set_process` 방식 사용(V20) | 로그의 `saved base.png ... hole_count=` 가 0인지, `base.png`에 구멍이 있는지 육안 |
| H3 실패이고 `base == 2`, `shot < 4` | 스캔라인이 구멍을 빗나감 | 로그의 `px c=` 좌표, `[display]` 해상도 |
| 화면은 정상인데 구멍이 안 움직임/반경 이상 | `radius` 오타 (경고만 나고 파싱은 통과) | `flush()`에서 `_buf[0]` 값을 print |
| 2단계 SHADER ERROR | 셰이더 문법 / uniform 배열 기본값(V14) | `run.log` |
| **exit 1인데 `JUDGE` 로그가 없음** | `Ground`에 `material_override`를 썼다 → `get_surface_override_material(0)`이 null | `run.err`의 `Ground.surface_material_override/0 is null`. **rev.5는 이 경우 무한 대기했다** — 판정 스크립트의 null 검사가 hang을 exit 1로 바꾼다 |
| 2단계 무한 대기 | `run_judge()`가 `quit()` 전에 예외로 중단 | 타임아웃 후 `run.err` 확인. 오류 패턴에 `SCRIPT ERROR`가 포함돼 있어야 잡힌다 |
| `clamped=true` | 카메라·해상도 변경으로 표본이 화면 밖 | `[display]` 해상도, 카메라 transform. **판정은 자동 무효화된다** |

---

## §7. 파일 구조

```
C:\vibecoding\holeio\
  project.godot
  PLAN.md
  scenes/
    main.tscn           (§3 전문)
    hole.tscn           (§3 전문)
    swallowable.tscn    (1b, 흡입 대상)
    swallowable_big.tscn (2단계, 크기 게이트 시험용)
  scripts/
    main.gd             (§4-G 전문)
    hole.gd             (§4-B 전문)
    hole_registry.gd    (§4-F 전문, autoload)
    screenshot.gd       (§6 전문, Judge 노드, --judge* 게이팅)
    swallowable.gd      (§4-D 전문, 1b)
    camera_rig.gd       (§4-E 전문, 1b)
    hole_ai.gd          (§15 전문, 4a — 경쟁 구멍 조종)
    city.gd             (§13 전문, 3b — 절차적 도시 배치)
    ui.gd               (§26 전문, 게임 UI — 시작·결과 화면, 코드 생성)
    traffic.gd          (§27 전문, 대로를 달리는 차)
    citizens.gd         (§28 전문, 보도를 걷는 시민)
  shaders/
    ground_hole.gdshader (§4-A 전문)
  tools/
    web_judge.mjs       (§24 — 브라우저 판정 하네스. build/ 정적 서빙 + 판정 결과 수집)
  assets/                (Quaternius 클래식 팩, CC0 — §1-A. OBJ+MTL 76모델, 9.4MB)
    cars/ buildings/ simplebuildings/ streets/ transport/ nature/
  shots/                 (판정 산출물, screenshot.gd 가 자동 생성)
    <prefix>ground.png                       (지면 전용 프레임 — D1·D2·D4 측정용)
    base.png  shot.png  probe.png            (1a)
    moved_*.png                              (1b B1)
    grown_*.png                              (2단계 C4)
    inter_*.png  road_*.png  block_*.png     (3a D5 — 교차로·도로·블록 위 구멍)
    arena0_*.png ~ arena5_*.png              (4a G1 — 구멍 6개를 하나씩)
                                             (4b 는 화면 캡처 없이 상태로만 판정한다)
```

**`assets/` 는 저장소에 포함한다.** CC0이고 9.4MB이며, 입수 경로(Google Drive 공개 폴더)가 언제까지 유효할지 보장할 수 없다. 각 팩의 `License.txt` 도 함께 둔다.

- `run.log` / `run.err`는 §6-2를 실행한 셸의 CWD에 생긴다. **프로젝트 루트에서 실행하면 루트가 오염되므로** 별도 작업 폴더에서 돌리거나 절대 경로로 리다이렉트한다.
- `.godot/`(임포트 캐시)는 엔진이 자동 생성한다.

`.tscn`은 **손으로 작성한다** — V3/V3b에서 ext/sub_resource, Transform3D, Environment, `instance=ExtResource`, `rotation_degrees` 직접 기재가 모두 정상 동작함을 확인했다. 에디터 GUI를 거치지 않는다.

---

## §8. 리스크

| 리스크 | 상태 / 대응 |
|---|---|
| project.godot / .tscn 손작성 오류 | **해소** — V1~V3b + §0-D 전문 수록 |
| uniform 배열 주입 실패 | **해소** — V4/V5/V5b, H4로 검출 |
| 엣지 계단현상 | **해소** — A2C + `depth_prepass_alpha`(§2-2) |
| depth prepass 무효화 성능 | **해소** — `depth_prepass_alpha`로 프리패스 복원 |
| 판정 절차 자체의 결함 | **해소** — §0-D에서 3단 검증을 끝까지 실행. V20을 트리아지에 반영 |
| **모든 검증이 실제 GPU에 의존** | `--headless`는 스파셜 셰이더 검증 불가. CI·원격 자동화 불가하며 이 PC의 창 모드 실행이 유일한 경로다. **완화 없음 — 제약으로 수용** |
| 검증 프로세스 hang | §6-2에 120초 타임아웃 + `Kill()` |
| ~~알파 경로 렌더 순서~~ | **철회.** V22로 이 머티리얼이 불투명 패스에 남는 것이 확인됐다(§2-2) |
| 다중 구멍에서 `fwidth(min(...))` 불연속 | 두 구멍의 영향 경계에서 부호거리가 꺾여 1px 아티팩트가 가능하다. 1a(구멍 1개)에는 무관하며 4단계에서 관측 시 평가 |
| 판정이 정상만 확인하고 비정상을 놓침 | **해소** — §0-E 고장 주입 13종. 새 기준(H7·H8)은 도입 즉시 주입 검증했다 |
| **착시 "품질"은 기계 판정 불가** | H1~H10은 필요조건일 뿐. 최종 관문은 `shot.png` 육안 확인(§6의 육안↔계측 대응표) |
| **판정기가 1a 구성에 결합돼 있다** | 구멍 원점·카메라 고정 전제. 1b에서 구멍이 움직이면 정상 구현도 탈락한다 — §6 "유효 전제" 표에 수정 지점을 명시했다 |
| **얕은 카메라 앙각에서 SDF 엣지가 뭉갠다** | 실측: 앙각 ≈40°(현 카메라)에서는 구멍이 15px로 작아져도 중간 톤 띠가 1~2px로 일정하다. 그러나 카메라를 거의 수평(y=3)으로 낮추면 완전 불투명 픽셀이 사라지고 띠가 39~61px로 번져 구멍이 회색 얼룩이 된다. 커버리지 AA의 정상적 열화이며 1a/1b 고정 카메라에서는 무해하나, **2단계의 "반지름 비례 거리 보간"에서 앙각 하한(≥30°)을 지켜야 한다** |
| 해상도 의존 판정 | `[display]`로 1152×648 고정. 변경 시 §6 임계값 재측정 필요 |
| 리소스 공유로 인한 SSOT 붕괴 (4단계) | `resource_local_to_scene = true` + `hole.gd`의 `duplicate()` 이중 방어 |
| 1b 물리(레이어 전환·수면·걸침) | `can_sleep`(V19)·AABB(V18)는 검증. 전체 흐름은 1b에서 실측 필요 |

## §10. 2단계 — 성장 · 크기 게이트 · 스코어 (구현·검증 완료)

### 규칙

| 항목 | 규칙 | 근거 |
|---|---|---|
| **성장** | `R' = sqrt(R² + growth_k · r²)`, **`growth_k = 1.0`** (§17에서 4.0 → 1.0) | **면적 보존.** 삼킨 오브젝트의 단면적이 구멍 단면적에 **그대로** 더해진다. 선형 성장(`R += k·r`)은 반경이 커질수록 체감 성장이 과도해진다. 4.0은 플레이에서 "너무 빨리 자란다"로 판정됐다 |
| **크기 게이트** | `obj_radius ≤ R · swallow_ratio`, `swallow_ratio = 0.45` | 게이트가 없으면 구멍보다 큰 오브젝트가 통과 조건(`dist + r < R`)을 영원히 만족하지 못한 채 림에서 계속 떤다(§4-D-2의 한계). **막힌 오브젝트에는 흡입력도 주지 않는다** |
| 게이트 재평가 | 매 `_physics_process`에서 다시 판단 | 구멍이 자라면 전에 막혔던 것이 열려야 한다. `body_entered`는 다시 발화하지 않으므로 진입 시점에 확정하면 안 된다 |
| **스코어** | `round(r² · 100)` | 단면적 비례 = 성장 기여도와 같은 척도 |
| 반경 전파 | `set_radius()` → `rebuild()`가 우물 메시·깊이·Area3D 셰이프를 **전부 다시 파생** | 하나라도 빠뜨리면 착시가 깨지거나(H7) 감지 범위가 어긋난다 → **C4가 이것을 잡는다** |

### 2단계 DoD

`-- --judge2` 로 실행한다.

| ID | 기준 | 실측 (정상 / 고장) |
|---|---|---|
| **C1** | 성장이 면적 보존 법칙을 따른다 | `R 5.0000 → 6.5023`, 기대값과 **오차 0.0000** / 선형 성장 `+0.5342` |
| **C2** | 상한을 넘는 오브젝트 위에 머물러도 삼켜지지 않고, 구멍이 자라 상한을 넘기면 그때 삼켜진다 | 위반 0 / 게이트 제거 시 `r=2.828 > R*0.45=2.250 falling=true` |
| **C3** | 스코어가 규격 산출식의 합과 일치 | `432 → 2032` 일치 / 고정 점수 `600 vs 432` |
| **C4** | **성장한 반경에서도 H1~H10 통과** | `R=10.3092`에서 `leak=0/3 rim_aa=20/32 depth=24.74/17.45` / `rebuild()` 누락 시 실패 |

**고장 주입 결과**

| 주입 | 결과 | 잡은 기준 |
|---|---|---|
| *(정상 빌드)* | **PASS** | — |
| 크기 게이트 제거 (`can_swallow`가 항상 true) | FAIL | C2 |
| 성장을 선형으로 (`R += k·r·0.1`) | FAIL | C1 |
| `set_radius`에서 `rebuild()` 생략 | FAIL | C4 |
| 점수를 크기와 무관하게 고정 | FAIL | C3 |

### 판정기가 구현체를 믿으면 안 된다 — 이번 단계에서 세 번 더

1a·1b에서 반복된 그 실패가 2단계에서도 세 번 나왔다. **판정 기준의 진실 원천이 구현체이면 검출력은 0이다.**

| 초안 | 왜 위약이었나 | 수정 |
|---|---|---|
| 게이트 분류를 `hole.can_swallow()`에 물음 | 게이트를 제거한 빌드에서 그 함수가 **항상 true** → 검사 대상이 사라져 통과 | 판정기가 `true_radius > R · swallow_ratio`로 직접 비교 |
| 기대 스코어를 `o.score_value` 합으로 계산 | 산출식을 고정값으로 바꾼 빌드가 **자기 값끼리 일치**해 통과 | 판정기가 규격(`r²·100`)으로 직접 계산 |
| 시나리오가 게이트를 건드리지 않음 | 큰 오브젝트에 접근할 때는 이미 구멍이 자라 있어 게이트가 **한 번도 시험되지 않음** | **0차 단계 신설** — 반경이 작은 상태로 큰 오브젝트 위에 150프레임 머문다 |

부수로 판정기 자체의 버그도 둘 잡았다: 삼킨 뒤 **해제된 인스턴스에 접근**해 코루틴이 죽으면 `quit()`에 도달하지 못해 300초 무한 대기가 됐고(`is_instance_valid` 가드로 해결), `true_radius()`가 매 프레임 `get_debug_mesh()`를 호출해 판정이 20배 느렸다(인스턴스별 캐시로 해결).

### 아직 기계 판정이 없는 것

성장의 **체감 곡선**(너무 빠른가/느린가), 카메라 거리 보간의 부드러움, 흡입의 손맛, HUD 가독성 — 전부 육안·수동 조작으로 확인한다.

## §11. 비범위 (3단계까지 하지 않음)

AI 경쟁 구멍, 사운드, 게임 루프·타이머·승패, 메뉴/UI, 도시 밖 지형.

---

## §12. 3a단계 — 도로 셰이더 · 도시 격자 · 판정기 정비 (구현·검증 완료)

### 왜 3단계를 3a/3b/3c로 나눴나

1a/1b를 나눈 것과 같은 이유다. **도로를 지면 셰이더에 통합하는 일과 에셋을 배치하는 일은 별개 작업이고, 지면이 성립하지 않으면 그 위에 무엇을 놓든 무의미하다.** 게다가 §1-A에서 에셋 결정 자체가 뒤집혔으므로, 에셋에 의존하지 않는 부분을 먼저 끝내 두는 편이 위험이 낮다. 3a의 산출물은 에셋과 무관하게 완결된다.

### 규격 — 도시 격자

| 항목 | 값 | 근거 |
|---|---|---|
| 지면 | **448×448** (`GROUND_HALF = 224`, §17에서 두 번 확대) | 주기 32 × 10칸. 60×60에서는 격자가 한 칸도 안 나오고, 192×192는 구멍 6개가 돌기에 좁았다 |
| `block_pitch` | 32.0 | 도로 중심선 간격 = 블록 20 + 보도 4 + 도로 8 |
| `road_half` | 4.0 | **일반 도로**의 아스팔트 폭 8 (2차선). §18에서 반폭이 선 인덱스의 함수가 됐다 |
| `curb_half` | 6.0 | **일반 도로**의 보도 폭 2 (도로 양옆). 보도 폭은 등급과 무관하게 일정하다 |
| `boul_every` / `boul_half` / `lane_gap` | 3 / 6.5 / 0.75 | **§18 도로 위계.** `k mod 3 == 0`인 중심선은 대로 — 아스팔트 반폭 6.5, 보도 바깥 8.5, 중앙선이 `±0.75` 두 줄 |
| `lane_half` | **0.30** | 중앙선 폭 60cm. 실제 도로(10~15cm)보다 굵다 — **0.18에서는 블록 하나 건너면 화면 2.3px로 뭉개져 판정 표본이 잡히지 않았다**(실측). 게임 카메라 거리에서 판독되는 것이 우선이다 |
| `cross_w` / `cross_pitch` | 1.6 / 1.2 | 교차로 바깥 횡단보도 띠 폭 / 줄무늬 주기 |
| 색 | 블록 `(0.45,0.65,0.35)` / 아스팔트 `(0.36,0.37,0.40)` / 보도 `(0.72,0.72,0.70)` / 중앙선 `(0.88,0.80,0.25)` / 횡단보도 `(0.90,0.90,0.87)` | 화면 휘도 0.6393 / 0.4163 / 0.7790 / 0.8328 / — (실측). **아스팔트가 어두우면 H1 임계(`lum_g × 0.5 = 0.32`)를 밑돌아 착시 판정이 무력화된다** → D4가 이것을 잡는다 |

**지면 색 경계는 직접 AA한다.** MSAA는 지오메트리 엣지만 덮으므로, 절차적 색 경계는 `fwidth` 기반 `smoothstep`이 없으면 원거리에서 지글거린다. 나아가 **전이폭이 특징 폭을 넘어서기 전에 특징 자체를 걷어낸다**(`aa_band`의 `fade`, 밉맵의 수동 구현). 이것이 없으면 먼 지면에서 띠가 화면을 통째로 덮는다.

`fwidth(abs(u))`가 아니라 `fwidth(u)`로 폭을 재는 이유: `abs`의 꺾임점(u=0)에서 `fwidth`가 튀는데, 그 지점이 정확히 중앙선 자리라 1픽셀 얼룩이 생긴다.

### 3a DoD — `-- --judge3`

`--judge`/`--judge1b`/`--judge2`는 그대로 두고, 도시 기준(D1·D2·D4)은 **모든 정적 판정에 상시 포함**된다. D3·D5는 `--judge3` 전용이다.

| ID | 기준 | 검출 대상 | 실측 (정상 / 고장) |
|---|---|---|---|
| **D1** | 규격 좌표에서 잰 지면 4종(블록·보도·아스팔트·중앙선)의 **인접 쌍 휘도차 ≥ 0.05** | 도로·보도·노면표시가 실제로 그려졌는가, 그리고 **격자 주기가 규격과 같은가** | `0.6393/0.7790/0.4163/0.8328` ✔ / 도로 미출력 시 `road=curb=0.7790` ✘ |
| **D2** | 규격 횡단보도 띠를 가로지르는 선분의 **엣지 그룹 ≥ 3** | 줄무늬가 그려졌는가. 점 하나로는 줄무늬의 틈에 떨어진다 | `10~12` ✔ / 미출력 `2` ✘ |
| **D3** | **서로 다른 격자 칸 2개 이상**에서 D1·D2가 성립 | 격자가 진짜 주기적인가 (한 칸에만 도로를 그린 빌드) | `4칸` ✔ |
| **D4** | 모든 지면 표면이 `lum > lum_block × 0.5` | **아트가 H1 임계를 무력화하지 못하게** 한다 | 최저 `0.4163 > 0.3197` ✔ / 어두운 아스팔트 `0.1653` ✘ |
| **D5** | 구멍을 **교차로 중심·도로 위·블록 중앙**으로 옮겨 H1·H2·H6~H9 전부 통과 | 도로도 같은 셰이더가 그리므로 구멍은 도로 위에서도 똑같이 뚫려야 한다 | 3지점 전부 P ✔ |

**D 기준의 진실 원천은 셰이더가 아니라 판정기다.** `screenshot.gd`는 `SPEC_PITCH`·`SPEC_ROAD_HALF`·`SPEC_CURB_HALF`·`SPEC_LANE_HALF`·`SPEC_CROSS_*`를 **따로** 들고 표본 좌표를 직접 계산한다. uniform을 읽으면 규격을 바꾼 빌드가 자기 값끼리 일치해 그대로 통과한다 — 1a~2단계에서 여섯 번 밟은 함정이다. 실제로 주기를 32→48로 바꾼 빌드는 표본이 엉뚱한 표면에 떨어져 D1·D2가 함께 무너진다.

**표본 블록은 탐색으로 고른다.** `probe_blocks()`가 구멍 주변 5×5 격자 칸에 대해 (a) 파생 표본 6점이 전부 화면 안(여유 12px)이고, (b) 구멍 중심에서 1.6R 밖이고, (c) 씬 오브젝트에서 XZ 4m 밖이고, (d) **규격 중앙선의 화면 폭이 3px 이상**인 칸만 남긴다. (d)가 없으면 먼 블록에서 노면표시가 정당하게 페이드아웃한 것을 결함으로 오판한다(실측: 64m 지점의 중앙선 휘도가 아스팔트와 **완전히 동일**). 폭을 판정기의 SPEC로 계산하므로 **중앙선을 아예 안 그린 빌드도 이 필터는 그대로 통과해 D1에서 걸린다.**

네 변 대칭도 이용한다 — 블록의 어느 쪽 도로를 볼지(`sz`)와 어느 쪽 교차로를 볼지(`sx`)를 둘 다 시도한다. 한쪽으로 고정하면 구멍 위치에 따라 표본이 16m 더 멀어져 유효 블록이 0개가 된다(실측: judge3의 road·block 지점).

**D3를 정적 판정 안에서 하지 않는 이유**: 게임 카메라의 화각(구멍 기준 약 55m)이 격자 주기(32m)의 1.7배뿐이라 한 프레임에 규격 조건을 만족하는 칸이 보통 하나뿐이다. 구멍을 격자의 다른 칸으로 옮겨 가며 도는 `--judge3`에서 누적 판정한다.

### 고장 주입 결과 (7종)

| 주입 | 결과 | 잡은 기준 | 계측 |
|---|---|---|---|
| *(정상 빌드)* | **PASS** | — | `D1=P D2=P D3=P D4=P D5=P`, `blocks_ok = 4칸` |
| 도로 미출력 | FAIL | D1 | `road=0.7790 = curb` |
| 보도 미출력 | FAIL | D1 | `curb=0.6393 = block` |
| 중앙선 미출력 | FAIL | D1 | `lane=0.4163 = road` |
| 횡단보도 미출력 | FAIL | D2 | `cross 10 → 2` |
| 격자 주기 32 → 48 | FAIL | D1·D2 | `block=0.7648 curb=0.8188 road=0.8294` (표본이 전부 엉뚱한 표면) |
| 아스팔트를 우물만큼 어둡게 | FAIL | D4 | `road=0.1653 < lum_block × 0.5 = 0.3197` |
| 도로 위에서는 구멍이 안 뚫림 | FAIL | **H1·H2** | 구멍 자리가 도로색으로 채워져 중심 휘도가 임계를 넘는다 |

마지막 주입에서 **H7(마젠타 누출)은 통과했다** — 구멍이 도로색으로 메워지면 배경이 샐 자리가 없기 때문이다. H7은 "이음새로 배경이 새는가"를 재는 기준이지 "구멍이 뚫렸는가"를 재는 기준이 아니며, 그 역할은 H1·H2가 맡는다. 두 기준이 서로를 대체하지 못한다는 뜻이다.

### 회귀

3a 변경 후 기존 판정 4종 전부 재실행: `--judge` / `--judge1b` / `--judge2` / `--judge3` 모두 **PASS**(exit 0, 오류 패턴 0건). `rim_aa`는 도로 엣지가 림 근처 스캔에 섞이며 18/32 → 13/32로 줄었으나 임계(4)의 3배 이상 여유가 남는다.

### 육안 확인

`shots/shot.png`(교차로 위 구멍)·`shots/road_shot.png`(도로 위 구멍) — 아스팔트·보도·중앙선·횡단보도가 지평선까지 계단 없이 그려지고, 구멍이 도로와 횡단보도를 함께 깨끗이 잘라낸다. **남은 문제**: 지면 끝이 배경과 만나는 경계가 그대로 드러난다 — 3b에서 블록에 건물이 서면 가려진다.

### 아직 기계 판정이 없는 것

도로 격자의 스케일이 게임플레이에 적절한가(블록이 너무 크지 않은가), 색 팔레트의 인상 — 전부 육안·수동 조작으로 확인한다.

### 3b 착수 시 첫 검증 항목 — 통과

**Godot 4.7의 `.obj` 임포터가 `.mtl`의 `Kd` 단색 머티리얼을 유지하는가 → 유지한다.** `Taxi.obj` 실측: `importer="wavefront_obj"`, `type="Mesh"` → `ArrayMesh` 12서피스, 각 서피스에 `.mtl` 이름 그대로의 `StandardMaterial3D`(`Yellow`/`Windows`/`Black`/`Grey`/`Headlights`/`TailLights`), `albedo_texture = null`. **Blender 불필요 확정** — §1-A의 에셋 결정이 그대로 선다.

---

## §13. 3b단계 — 에셋 임포트 · 절차적 도시 배치 (구현·검증 완료)

### 실측: 팩마다 스케일도 피벗도 다르다

76개를 전부 로드해 AABB를 찍은 결과(텍스처 0장, 머티리얼 누락 0개), **공통 스케일이 없다.**

| 팩 | 대표 치수 | 스케일 보정 |
|---|---|---|
| cars | Taxi `1.81 × 1.31 × 4.22` — 실제 크기 | ×1.0 |
| buildings | Building1_Large `7.99 × 4.67 × 2.74` — 건물이 4.7m | ×2.0 |
| simplebuildings | Bank `4.01 × 2.92 × 4.24` | ×3.0 |
| streets | Streetlight_Single **높이 1.09m** — 약 1/8 축척 | ×7.3 |
| transport | Bus `4.09 × 1.68 × 1.74` — 긴 축이 **X** | ×1.96 |
| nature | Tree1 `2.07 × 4.10 × 2.99` | ×1.5 |

피벗도 제각각이다(모델 최저점 `y0`가 −1.12 ~ +0.01). **두 보정 모두 카탈로그에 손으로 적지 않고 AABB에서 유도한다** — 메시를 `-y0·s`만큼 올리고 XZ 중심을 원점으로 옮기면 어떤 팩이 들어와도 지면에 정확히 선다(E5가 이것을 잡는다).

차량 방향도 카탈로그에 적지 않는다. **모델 AABB의 긴 축**에서 유도해 도로 축에 맞춘다 — `Bus`처럼 X로 누운 모델과 승용차처럼 Z로 누운 모델이 섞여 있어서, 방향을 상수로 박으면 버스가 도로를 가로질러 눕는다.

### 규격 — 배치

경계값은 전부 **그 축의 도로 중심선 인덱스 `k`의 함수**다(§18). 아래는 `r = road_half_at(k)`,
`c = curb_half_at(k) = r + 2.0` 로 쓴 것이고, 일반 도로는 `(r, c) = (4.0, 6.0)`,
대로는 `(6.5, 8.5)` 다.

| 구역 | 조건 | 내용 |
|---|---|---|
| 차도 | `median(k) ≤ |u| - ex` 이고 `|u| + ex ≤ r` 이고 **교차 축으로 `r_cross + 1.6` 밖** | 승용차 7종, Bus·SchoolBus·Ambulance, TrafficCone. 차선 자리 위, 도로 축 방향. `median`은 일반 0 / 대로 1.05(이중 중앙선 사이는 분리대다) |
| 보도 | `r ≤ |u| - ex`, `|u| + ex ≤ c` | 가로등, 신호등, 표지판, 덤불 |
| 블록 | `[k·32 + c(k) + 0.8, (k+1)·32 - c(k+1) - 0.8]` 구간 안 | 건물 19종, 나무·바위. **감싸는 두 경계선을 각각 본다** — 대로가 한쪽에만 붙은 블록은 좌우 여백이 8.5 대 6.0으로 다르다 |
| **판정 광장** | 원점 반경 26m | **아무것도 생성하지 않는다.** 1b·2단계의 흡입·성장 시나리오가 여기서 돈다 — 도시 오브젝트가 섞여 들면 C1·C3의 기대값이 깨진다 |

**구역 적합성을 외접원으로 판단하면 안 된다.** 길쭉한 것은 대각선이 폭보다 훨씬 커서, 폭 8m 도로에 넉넉히 들어가는 차량이 전부 탈락한다 — 실측: 승용차 7종 중 1종만 남고 버스·구급차는 전멸(도로 프롭 191개가 전부 `NormalCar2`와 콘). 회전이 90° 단위이므로 **축방향 반extent**로 정확히 재면 전 차종이 배치된다.

**겹침은 생성 시점에 배제한다.** `fits()`가 이미 놓인 것과 상자가 닿으면 그 자리를 포기한다(여유 0.4m). 판정기의 E3는 이것을 믿지 않고 콜라이더에서 다시 잰다.

**난수 소비량은 배치 성공 여부와 무관해야 한다.** 자리가 없어 중도 반환하더라도 회전값은 먼저 뽑아 둔다 — 그러지 않으면 한 자리의 성패가 이후 모든 배치를 흔들어 시드 재현성이 깨진다.

### 3b DoD — `-- --judge3b`

| ID | 기준 | 검출 대상 | 실측 (정상 / 고장) |
|---|---|---|---|
| **E1** | 카탈로그 전 항목이 로드되고, 서피스마다 텍스처 없는 `StandardMaterial3D`가 있으며, 서로 다른 albedo ≥ 12종, 카탈로그 ≥ 30개, 생성 프롭 ≥ 300개 | 임포트 파이프라인·에셋 무결성 | `props=588 catalog=48 albedos=49` ✔ / 생성 비활성 시 ✘ |
| **E2** | 모든 프롭이 도로·보도·블록 **한 구역 안에 온전히** 들어간다 | 구역 침범(도로를 막는 건물, 보도로 튀어나온 버스) | 위반 `0` ✔ / 구역 검사 제거 시 `46` ✘ |
| **E3** | 어떤 두 프롭도 XZ에서 겹치지 않는다 (콜라이더 상자 → 볼록껍질 → 분리축) | 파고든 배치 | `0` ✔ / 겹침 검사 제거 시 `215` ✘ |
| **E4** | 같은 시드는 같은 배치, 다른 시드는 다른 배치 | 재현성(판정 자체의 전제) | 지문 일치 ✔ / `randomize()` ✘ |
| **E5** | 콜라이더·**메시** 모두 최저점 y ≈ 0, 둘의 XZ 상자가 일치, 기울기 ≤ 0.02rad, 그리고 **180 물리 프레임 동안 정지** | 뜨거나 박힌 배치, 물리와 그림의 분리 | `0`, `settle_move=0.0000` ✔ / 피벗 보정 제거 시 `113` ✘ |
| **E6** | 광장 반경 안에 도시 프롭 0개, 판정 대상 8개 온존 | 1b·2 시나리오 오염 | `0 / 8` ✔ / 광장 무시 시 `33` ✘ |

**구역 판정은 카탈로그를 읽지 않는다.** 판정기가 SPEC 격자로 프롭의 상자를 u좌표로 옮겨 "세 구역 중 하나에 온전히 들어가는가"만 본다. 카탈로그의 `zone`과 대조하면 배치 규격을 통째로 바꾼 빌드가 자기 값끼리 일치해 통과한다.

### 고장 주입 결과 (7종) — 그리고 판정기가 두 번 위약이었다

| 주입 | 결과 | 잡은 기준 |
|---|---|---|
| *(정상 빌드)* | **PASS** | — |
| 메시 피벗 y 보정 제거 | FAIL | E5 (`113`) |
| 겹침 검사 제거 | FAIL | E3 (`215`) |
| 구역 검사 제거 | FAIL | E2 (`46`) |
| 시드 무시(`randomize()`) | FAIL | E4 |
| 판정 광장 무시 | FAIL | E6 (`33`) |
| 도시 생성 비활성 | FAIL | E1 |

**초안의 E5는 위약이었다 — 두 방향으로.**

1. **콜라이더만 쟀다.** 메시 피벗 보정을 통째로 지운 빌드가 그대로 통과했다. 콜라이더는 제자리에 있고 **모델만** 공중에 뜨거나 지면에 박히기 때문이다. 보이는 것을 재지 않는 기준은 보이는 결함을 못 잡는다 → 메시 AABB와 콜라이더-메시 정합까지 함께 재도록 고쳤다.
2. **시나리오가 기준을 건드리지 않았다.** 판정 전에 물리를 한 프레임만 돌리고 멈춰서, "도시가 제자리에 서 있는가"를 시험할 기회가 없었다 → 180 물리 프레임을 돌린 뒤 이동·기울기를 재도록 고쳤다.

**그리고 이 주입이 내 사실 주장 하나를 뒤집었다.** `start_frozen`을 도입하며 "없으면 가늘고 높은 프롭이 제 무게로 넘어진다(실측)"고 적었는데, 고정을 해제한 빌드의 실측은 **180 프레임 동안 최대 이동 0.9mm·기울기 0.0001rad**였다. 넘어지지 않는다. 최초 스크린샷에서 가로등이 누운 것처럼 보인 것은 fov 75°의 원근 착시였고, 나는 그것을 실측이라고 적었다. `start_frozen`은 자세가 아니라 **성능만을 위한 것**이며, 그 근거도 §14에서 6%로 측정됐다.

### 아직 기계 판정이 없는 것

도시의 밀도·색 팔레트가 hole.io답게 읽히는가, 블록 안 녹지 비율, 건물 스케일의 인상 — 육안 확인 사항이다. `shots/block_shot.png`(블록 위 구멍)·`shots/road_shot.png`(도로 위 구멍)으로 본다.

### `scripts/city.gd` (전문 — 실행 검증본)

```gdscript
extends Node3D

## 3b: Quaternius 에셋을 §12 의 도시 격자 규격에 맞춰 절차적으로 배치한다.
##
## 배치는 두 단계로 나뉜다.
##   plan(seed) -> 배치 계획(순수 함수, 씬을 건드리지 않는다)
##   build(plan) -> 계획대로 노드를 만든다
## 판정기가 plan() 을 두 번 돌려 대조하면 재현성(E4)을 씬 변형 없이 검증할 수 있다.

const SWALLOWABLE := preload("res://scripts/swallowable.gd")

# --- 도시 격자 규격 (셰이더 uniform 과 같은 값. 여기가 배치의 진실 원천이다) ---
const PITCH := 32.0
const ROAD_HALF := 4.0
const CURB_HALF := 6.0
## 중앙선 반폭. 셰이더의 lane_half 와 같은 값 — 대로의 중앙 분리대 경계를 여기서 낸다.
const LANE_HALF := 0.30
## 횡단보도 띠 폭. 셰이더의 cross_w 와 같은 값 — 그 위에 차를 세우지 않으려고 쓴다.
const CROSS_W := 1.6
## 건물·녹지는 커브에서 이만큼 물러난다. 판정기가 |u| = CURB_HALF + 1 에서
## 블록 지면을 표본하므로, 이 여백이 없으면 표본이 건물 위에 떨어진다.
const BLOCK_SETBACK := 0.8
const GROUND_HALF := 224.0

# --- 도로 위계 (§18) -------------------------------------------------------
## BOULEVARD_EVERY 번째 중심선(k mod 3 == 0)은 대로다. 지면 ±224(인덱스 -7..7)에서
## x·z = 0, ±96, ±192 각 다섯 줄이다. 게임 시야가 구멍 기준 약 55m 이므로 96m 주기면
## 이동 중에 대로가 규칙적으로 걸린다 — 128m(4번째)는 지도 절반에서 한 번도 안 보인다.
const BOULEVARD_EVERY := 3
const BOUL_HALF := 6.5
## 보도 폭. 위계와 무관하게 일정하다 — 대로는 아스팔트만 넓어진다.
const SIDEWALK_W := CURB_HALF - ROAD_HALF
## 대로 이중 중앙선의 중심 오프셋. 두 줄 바깥 가장자리(LANE_GAP + LANE_HALF)가
## 중앙 분리대의 경계이고 차량은 그 안으로 들어오지 못한다.
const LANE_GAP := 0.75
## 판정 시나리오(1b·2단계의 흡입·성장)가 도는 영역. 여기에는 아무것도 생성하지 않는다.
## 이 광장이 없으면 도시 오브젝트가 시나리오에 섞여 들어 C1·C3 의 기대값이 깨진다.
const PLAZA_R := 26.0
## 오브젝트 사이에 두는 최소 여유(월드 단위).
const GAP := 0.3
## 블록 내부 산포 반경의 상한. 실제 반경은 블록의 사용 가능 구간에서 유도하고
## 이 값으로 자른다(§22 — plan_block 참조).
const SPREAD_MAX := 8.5

# --- 지구 지도 (§25) -------------------------------------------------------
## 셀은 블록과 1:1 이다. 셀 (k, j) 는 x ∈ [32k, 32k+32], z ∈ [32j, 32j+32] 를 덮고
## 그 중앙이 블록 중앙이다. k·j 는 둘 다 [-7, 6] 이다 (14x14 = 196 셀).
##
## **행·열 ↔ 월드 대응식** — 셰이더·판정기가 같은 식을 각자 들고 있어야 한다:
##     행 r = j + 7   (r=0 이 최소 z, r=13 이 최대 z)
##     열 c = k + 7   (c=0 이 최소 x, c=13 이 최대 x)
##     zone_at(k, j) = ZONE_ROWS[j + 7][k + 7]
##
## 지도는 **시드 난수가 아니라 손으로 저작한 고정 상수**다. 이유 셋:
##   ① 판정기가 독립 구현으로 같은 표를 들 수 있다
##   ② 강·공원·도심을 의도적으로 디자인할 수 있다
##   ③ E4 재현성이 시드와 무관하게 자동으로 성립한다
##
## 글자: D 도심 · C 상업 · R 주거 · P 공원 · W 수역
##
## **바다는 지면 메시를 키워서 만들지 않는다.** 테두리 한 줄을 W 로 둔다.
## 지면을 448 → 4000 으로 키우면 화면에서 하늘이 사라져 H 계열 판정이 배경 기준점을
## 잃고 통째로 무너진다(주입으로 실증). 지도 밖은 지금처럼 배경으로 남긴다.
##
## 설계 제약 — 어기면 판정이 깨진다:
##   · 중앙 2x2(k,j ∈ {-1,0})는 D 고정. 판정 광장(반경 26)이 그 안에 있다.
##   · 판정 지점(CITY_SPOTS·PERF_SPOTS)이 떨어지는 셀은 P·W 가 아니다.
##   · AI 스폰 링(반경 128 격자 스냅)이 닿는 네 셀도 P·W 가 아니다 —
##     스폰은 move_to 를 거치지 않으므로 W 위에서 태어나면 Z5 가 스폰 순간 깨진다.
##   · P 영역은 **직사각형**이어야 한다. 병합 구간을 축별 확장으로 구하기 때문이다.
const ZONE_ROWS := [
	"WWWWWWWWWWWWWW",   # j = -7   바다 테두리
	"WRRRRRRRRWRRRW",   # j = -6
	"WRRRRRRRRWRRRW",   # j = -5
	"WRRCCCCCCWCRRW",   # j = -4
	"WRRCCCCCCWCRRW",   # j = -3
	"WRRCCDDDDWCRRW",   # j = -2
	"WRRCCDDDDWCRRW",   # j = -1
	"WPPCCDDDDWCRRW",   # j =  0   서쪽 공원(2x2, k=-6..-5)
	"WPPCCDDDDWCRRW",   # j =  1
	"WRRCCCCCCWCRRW",   # j =  2
	"WRRCCCCCCWCPPW",   # j =  3   동쪽 공원(2x2, k=4..5)
	"WRRPPRRRRWRPPW",   # j =  4   북서 공원(1x2, k=-4..-3)
	"WRRRRRRRRWRRRW",   # j =  5
	"WWWWWWWWWWWWWW",   # j =  6   바다 테두리
]
const CELL_MIN := -7
const CELL_MAX := 6
const CELL_COUNT := 14

const Z_DOWNTOWN := 0
const Z_COMMERCIAL := 1
const Z_RESIDENTIAL := 2
const Z_PARK := 3
const Z_WATER := 4
const ZONE_CODE := { "D": 0, "C": 1, "R": 2, "P": 3, "W": 4 }

## 교량 = 수역을 건너는 **동서 도로 세그먼트** [중심선 인덱스 jl, 셀 인덱스 kc].
## 강이 남북(열 k=2)으로 흐르므로 이를 건너는 것은 동서 도로다.
## **세그먼트 단위로 적는다.** 선 전체를 여는 방식은 같은 z 의 바다 테두리(k=-7·6)까지
## 뚫어 구멍이 지도 밖 물 위로 나간다.
## 셋 다 대로(인덱스 mod 3 == 0)라 아스팔트 폭이 13m 다.
const BRIDGES := [[-3, 2], [0, 2], [3, 2]]

## 존별 배치 규격. kinds 는 **블록 내부**에 놓을 수 있는 카탈로그 종류다
## (보도·차도 프롭은 존과 무관하게 같은 목록을 쓰고 밀도만 달라진다).
## scale_mul 은 블록 내부 프롭에만 곱한다 — 가로등·차는 실제 치수가 규격이다.
## 배열 순서가 곧 존 코드다.
const ZONE_PROFILE := [
	# D 도심 — 고층이 빽빽하고 녹지가 없다
	{ "kinds": ["tower"], "scale_mul": 1.35, "center": 0.85, "center_ext": 4.0,
		"tries": 12, "spread": 8.5, "walk_skip": 0.35, "road_skip": 0.40 },
	# C 상업 — 중저층 상가, 가로 시설물이 많다
	{ "kinds": ["shop", "tower"], "scale_mul": 1.0, "center": 0.55, "center_ext": 3.5,
		"tries": 16, "spread": 8.5, "walk_skip": 0.40, "road_skip": 0.45 },
	# R 주거 — 주택과 마당 녹지, 밀도가 낮다
	{ "kinds": ["house", "tree", "rock"], "scale_mul": 0.95, "center": 0.25,
		"center_ext": 3.0, "tries": 14, "spread": 8.5, "walk_skip": 0.60, "road_skip": 0.60 },
	# P 공원 — 수퍼블록 하나를 통째로 쓴다. 시행 수·산포가 병합 구간에 맞춰 크다
	{ "kinds": ["tree", "rock", "bush"], "scale_mul": 1.0, "center": 0.0, "center_ext": 0.0,
		"tries": 64, "spread": 40.0, "walk_skip": 0.70, "road_skip": 0.75 },
	# W 수역 — 아무것도 놓지 않는다(add_slot 이 셀 존으로 먼저 거절한다)
	{ "kinds": [], "scale_mul": 1.0, "center": 0.0, "center_ext": 0.0,
		"tries": 0, "spread": 0.0, "walk_skip": 1.0, "road_skip": 1.0 },
]

## 셰이더로 넘길 존 지도의 채널 간격. zone_code * 51 을 R8 한 채널에 담는다.
## 51/255 = 0.2 는 8비트 양자화·필터 오차보다 압도적으로 커서 복호가 견고하다.
const ZONE_TEX_STEP := 51

@export var city_seed := 20260728
@export var enabled := true

## 카탈로그. scale 은 팩마다 제각각인 모델 치수를 실측(§13)에서 실제 크기로 맞춘 값이다.
## zone: "block"(블록 내부) / "walk"(보도) / "road"(차도) — **자리의 종류**다.
## kind: 지구제(§25)가 쓰는 **에셋의 종류**다. 블록 내부 자리에서만 걸러진다
##       (tower 고층 · shop 상가 · house 주택 · tree · rock · bush).
const CATALOG := [
	# --- 건물: 블록 내부 ---
	{ "path": "res://assets/buildings/Building1_Large.obj", "scale": 2.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/buildings/Building1_Small.obj", "scale": 2.0, "zone": "block", "kind": "shop" },
	{ "path": "res://assets/buildings/Building2_Large.obj", "scale": 2.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/buildings/Building2_Small.obj", "scale": 2.0, "zone": "block", "kind": "shop" },
	{ "path": "res://assets/buildings/Building3_Big.obj", "scale": 2.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/buildings/Building3_Small.obj", "scale": 2.0, "zone": "block", "kind": "shop" },
	{ "path": "res://assets/buildings/Building4.obj", "scale": 2.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/buildings/House1.obj", "scale": 2.0, "zone": "block", "kind": "house" },
	{ "path": "res://assets/buildings/House2.obj", "scale": 2.0, "zone": "block", "kind": "house" },
	{ "path": "res://assets/simplebuildings/Bank.obj", "scale": 3.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/simplebuildings/Flat.obj", "scale": 3.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/simplebuildings/Flat2.obj", "scale": 3.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/simplebuildings/Hospital.obj", "scale": 3.0, "zone": "block", "kind": "tower" },
	{ "path": "res://assets/simplebuildings/House.obj", "scale": 3.0, "zone": "block", "kind": "house" },
	{ "path": "res://assets/simplebuildings/House2.obj", "scale": 3.0, "zone": "block", "kind": "house" },
	{ "path": "res://assets/simplebuildings/House3.obj", "scale": 3.0, "zone": "block", "kind": "house" },
	{ "path": "res://assets/simplebuildings/House4.obj", "scale": 3.0, "zone": "block", "kind": "house" },
	{ "path": "res://assets/simplebuildings/House5.obj", "scale": 3.0, "zone": "block", "kind": "house" },
	{ "path": "res://assets/simplebuildings/Shop.obj", "scale": 3.0, "zone": "block", "kind": "shop" },
	# --- 녹지: 블록 내부 ---
	{ "path": "res://assets/nature/Tree1.obj", "scale": 1.5, "zone": "block", "kind": "tree" },
	{ "path": "res://assets/nature/Tree2.obj", "scale": 1.2, "zone": "block", "kind": "tree" },
	{ "path": "res://assets/nature/Tree3.obj", "scale": 1.5, "zone": "block", "kind": "tree" },
	{ "path": "res://assets/nature/Tree4.obj", "scale": 1.0, "zone": "block", "kind": "tree" },
	{ "path": "res://assets/nature/Rock1.obj", "scale": 1.0, "zone": "block", "kind": "rock" },
	{ "path": "res://assets/nature/Rock2.obj", "scale": 1.0, "zone": "block", "kind": "rock" },
	{ "path": "res://assets/nature/Rock3.obj", "scale": 1.0, "zone": "block", "kind": "rock" },
	# 공원 전용 덤불. 같은 에셋이 보도에도 있지만 자리의 종류가 다르다 —
	# "bush" 는 P 의 kinds 에만 있으므로 D·C·R 블록에는 나타나지 않는다.
	{ "path": "res://assets/nature/Bush1.obj", "scale": 1.0, "zone": "block", "kind": "bush" },
	{ "path": "res://assets/nature/Bush2.obj", "scale": 1.0, "zone": "block", "kind": "bush" },
	{ "path": "res://assets/nature/Bush3.obj", "scale": 1.0, "zone": "block", "kind": "bush" },
	# --- 가로 시설물: 보도 ---
	{ "path": "res://assets/streets/Streetlight_Single.obj", "scale": 7.3, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Streetlight_Double.obj", "scale": 7.3, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/TrafficLight.obj", "scale": 5.2, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Sign_Stop.obj", "scale": 4.4, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Sign_NoParking.obj", "scale": 4.4, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Sign_Triangle.obj", "scale": 4.4, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/transport/TrafficSign1.obj", "scale": 1.6, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/transport/TrafficSign2.obj", "scale": 1.6, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/nature/Bush1.obj", "scale": 1.0, "zone": "walk", "kind": "bush" },
	{ "path": "res://assets/nature/Bush2.obj", "scale": 1.0, "zone": "walk", "kind": "bush" },
	{ "path": "res://assets/nature/Bush3.obj", "scale": 1.0, "zone": "walk", "kind": "bush" },
	# --- 차량: 차도 ---
	{ "path": "res://assets/cars/Taxi.obj", "scale": 1.0, "zone": "road", "kind": "car" },
	{ "path": "res://assets/cars/Cop.obj", "scale": 1.0, "zone": "road", "kind": "car" },
	{ "path": "res://assets/cars/NormalCar1.obj", "scale": 1.0, "zone": "road", "kind": "car" },
	{ "path": "res://assets/cars/NormalCar2.obj", "scale": 1.0, "zone": "road", "kind": "car" },
	{ "path": "res://assets/cars/SUV.obj", "scale": 1.0, "zone": "road", "kind": "car" },
	{ "path": "res://assets/cars/SportsCar.obj", "scale": 1.0, "zone": "road", "kind": "car" },
	{ "path": "res://assets/cars/SportsCar2.obj", "scale": 1.0, "zone": "road", "kind": "car" },
	{ "path": "res://assets/transport/Ambulance.obj", "scale": 1.05, "zone": "road", "kind": "car" },
	{ "path": "res://assets/transport/Bus.obj", "scale": 1.96, "zone": "road", "kind": "car" },
	{ "path": "res://assets/transport/SchoolBus.obj", "scale": 1.84, "zone": "road", "kind": "car" },
	{ "path": "res://assets/transport/TrafficCone.obj", "scale": 0.6, "zone": "road", "kind": "car" },
]

## 콜라이더 XZ 를 딸 밑동의 높이 비율. 아래 35% 는 밑동 셰이프, 나머지는 수관 셰이프다.
const BASE_FRAC := 0.35
## 수관 셰이프를 다는 기준. 전체 반폭이 밑동 반폭의 이 배 이상이면 "가지가 있다".
const CANOPY_RATIO := 1.5

var _mesh_cache := {}
var _r_cache := {}
var _base_cache := {}


func _ready() -> void:
	if enabled:
		build(plan(city_seed))


## 배치 계획. 같은 시드면 항상 같은 배열을 돌려준다(E4).
## 씬을 건드리지 않으므로 판정기가 몇 번이든 다시 부를 수 있다.
func plan(s: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var out := []
	for k in range(CELL_MIN, CELL_MAX + 1):
		for j in range(CELL_MIN, CELL_MAX + 1):
			plan_block(rng, k, j, out)
			plan_walk(rng, k, j, out)
			plan_road(rng, k, j, out)
	return out


# --- 도로 위계 파생 (§18) ---------------------------------------------------
# 반폭이 선 인덱스의 함수가 됐다. 셰이더·판정기가 같은 함수를 각자 들고 있다.

## 좌표 → 가장 가까운 도로 중심선의 인덱스.
## `roundi(w / PITCH)` 를 쓰면 안 된다 — 셰이더는 `floor((p + hp) / pitch)` 로 뽑는데
## round 는 0.5 를 0에서 멀어지게 반올림해 블록 정중앙의 음수 쪽(w = -16, -48 …)에서
## 한 칸 어긋난다. 그러면 두 규격이 **서로 다른 선을 대로로 그린다.**
static func line_index(w: float) -> int:
	return floori(w / PITCH + 0.5)


static func is_boulevard(k: int) -> bool:
	return posmod(k, BOULEVARD_EVERY) == 0


static func road_half_at(k: int) -> float:
	return BOUL_HALF if is_boulevard(k) else ROAD_HALF


static func curb_half_at(k: int) -> float:
	return road_half_at(k) + SIDEWALK_W


## 보도 프롭의 중심선. 도로와 커브의 한가운데다.
static func walk_center_at(k: int) -> float:
	return (road_half_at(k) + curb_half_at(k)) * 0.5


## 차량이 넘어설 수 없는 안쪽 경계. 일반 도로의 한 줄은 노면 위 표시일 뿐이라 0 이고,
## 대로의 두 줄 사이는 중앙 분리대라 차량이 들어가면 안 된다.
static func median_at(k: int) -> float:
	return (LANE_GAP + LANE_HALF) if is_boulevard(k) else 0.0


## 차선 자리 [오프셋, 최소 반extent]. **순서가 곧 우선순위다** — fits() 가 뒤에 오는
## 자리를 막는다(이웃 간격 1.3625 는 승용차 두 대의 폭합보다 좁다).
## 일반 도로는 편도 주행 띠 [0, 4.0] 을 2등분 → ±2.0 (옛 LANE_U 와 같은 값, 회귀 없음).
## 대로는 띠 [1.05, 6.5](폭 5.45)를 4등분한 세 지점이다. 2차선으로 등분하면 차선 반폭이
## 1.3625 로 **일반 도로의 유효 반폭 2.0 보다 좁아져** 버스(폭반값 1.71)·스쿨버스(1.73)·
## 구급차(1.49)가 대로에서 전멸한다 — 가장 넓은 도로가 가장 큰 차를 거절하는 규격 오류다.
## 가운데 자리는 띠의 한가운데라 반extent 2.725 까지 받는다. 그 자리를 **먼저** 시도하고
## min_ext 를 걸어 큰 차 전용으로 둔다(plan_block 의 min_ext 3.5 와 같은 근거·같은 도구).
## min_ext 는 긴 축과 비교되므로 2.5 는 Ambulance(3.00)·Bus(4.00)·SchoolBus(4.24)만 연다.
## 가운데가 비면 안쪽 2.4125 와 바깥 5.1375 가 둘 다 들어간다(간격 2.725).
## §27 에서 **주차와 주행을 갈랐다.** 대로에서 옛 자리 셋 중 안쪽(±2.4125)과
## 가운데(±3.775)는 주행 차선과 겹친다 — 정차 차량은 frozen 강체라 충돌 해소가 없고,
## 주행차가 그것을 그대로 뚫고 지나간다. 바깥 자리 하나만 남긴다(|u| ∈ [3.775, 6.5]).
##
## 일반 도로는 그대로 둔다. 폭 8m 에 주행과 노상 주차는 공존할 수 없고
## (주차차가 |u| ∈ [0, 4] 를 다 쓴다), 그렇다고 주차를 걷어내면 도시의 차가
## 대부분 사라진다 — **교통은 대로에만 흐른다**(driving_lanes 참조).
static func lane_slots(k: int) -> Array:
	var m := median_at(k)
	var w := road_half_at(k) - m
	if not is_boulevard(k):
		return [[-(m + w * 0.5), 0.0], [m + w * 0.5, 0.0]]
	return [[-(m + w * 0.75), 0.0], [m + w * 0.75, 0.0]]


## 주행 차선 [중앙선에서의 오프셋, 진행 방향]. 대로에만 있다.
##
## 우측통행이다. 진행 방향 d 의 **오른쪽**은 (-d.z, d.x) 이므로
##   동서 도로(x 축 주행): +x 로 가면 오른쪽이 +z → u = +안쪽
##   남북 도로(z 축 주행): +z 로 가면 오른쪽이 -x → u = -안쪽
## 축마다 부호가 뒤집히는 것이 이 함수가 축을 인자로 받는 이유다.
static func driving_lanes(k: int, axis: String) -> Array:
	if not is_boulevard(k):
		return []
	var m := median_at(k)
	var inner := m + (road_half_at(k) - m) * 0.25
	if axis == "x":
		return [[inner, 1.0], [-inner, -1.0]]
	return [[-inner, 1.0], [inner, -1.0]]


## 도로 축 방향의 정차 자리. 교차 도로가 넓어지면 교차로·횡단보도도 넓어지므로
## 자리를 안쪽으로 당긴다. 실제 침범 여부는 in_zone 이 프롭의 extent 로 정확히 재고,
## 이 목록은 "대부분의 차가 들어갈 수 있는 자리" 를 고르는 역할만 한다.
##   일반 교차: 교차로+횡단보도 5.6 → t=±8 이면 여유 8.0 (승용차 반길이 2.11 통과)
##   대로 교차: 8.1 → t=±5 이면 여유 11.0 (승용차·구급차 통과)
## 옛 t=±10 은 여유가 6.0 뿐이라 버스(반길이 4.24)가 **일반 교차로 안에 서 있었다** —
## 선재 결함이었고 어떤 기준도 잡지 않았다.
static func road_slots(k_cross: int) -> Array:
	if is_boulevard(k_cross) or is_boulevard(k_cross + 1):
		return [-5.0, -2.5, 2.5, 5.0]
	return [-8.0, -3.5, 3.5, 8.0]


# --- 지구 지도 파생 (§25) ---------------------------------------------------

## 좌표 → 그 좌표를 품는 셀 인덱스. 지도 밖은 테두리 셀로 자른다(테두리는 W 다).
static func cell_of(w: float) -> int:
	return clampi(floori(w / PITCH), CELL_MIN, CELL_MAX)


static func zone_at(k: int, j: int) -> int:
	var c := clampi(k - CELL_MIN, 0, CELL_COUNT - 1)
	var r := clampi(j - CELL_MIN, 0, CELL_COUNT - 1)
	return int(ZONE_CODE[(ZONE_ROWS[r] as String)[c]])


static func zone_at_pos(p: Vector3) -> int:
	return zone_at(cell_of(p.x), cell_of(p.z))


static func is_bridge_ew(jl: int, kc: int) -> bool:
	for b in BRIDGES:
		if int(b[0]) == jl and int(b[1]) == kc:
			return true
	return false


## 도로 세그먼트가 존재하는가. **존 지도에서 파생되는 순수 함수**이고 별도 데이터가 없다.
##   · 어느 한쪽이 수역이면 → 교량 목록에 있을 때만 존재한다.
##   · 양쪽이 모두 공원이면 → 없다(수퍼블록 내부 관통 도로를 걷어낸다).
##     한쪽만 공원이면 남는다 — 공원은 도로로 둘러싸인 것이 자연스럽다.
static func seg_rule(a: int, b: int, bridge: bool) -> bool:
	if a == Z_WATER or b == Z_WATER:
		return bridge
	return not (a == Z_PARK and b == Z_PARK)


## 동서 도로(중심선 z = PITCH*jl)의, x 가 셀 kc 에 걸친 구간.
static func seg_ew(jl: int, kc: int) -> bool:
	return seg_rule(zone_at(kc, jl - 1), zone_at(kc, jl), is_bridge_ew(jl, kc))


## 남북 도로(중심선 x = PITCH*kl)의, z 가 셀 jc 에 걸친 구간.
## 강이 남북이라 이를 건너는 교량은 없다 — 남북 도로는 수역을 만나면 항상 끊긴다.
static func seg_ns(kl: int, jc: int) -> bool:
	return seg_rule(zone_at(kl - 1, jc), zone_at(kl, jc), false)


## 구멍이 이 자리에 있을 수 있는가(§25). 수역은 막고, 교량 아스팔트 위는 연다.
## 판정하는 것은 **구멍 중심** 하나다 — 원반 절반이 물 위에 걸치는 것은 허용이다
## ("강기슭이 파인" 연출이고, 반경 마진으로 막으면 교량 진입로까지 막힌다).
static func passable(p: Vector3) -> bool:
	var k := cell_of(p.x)
	if zone_at(k, cell_of(p.z)) != Z_WATER:
		return true
	var jl := line_index(p.z)
	return is_bridge_ew(jl, k) and absf(p.z - float(jl) * PITCH) <= road_half_at(jl)


## P 수퍼블록의 축별 병합 범위 [최소 셀, 최대 셀]. 공원이 아니면 자기 셀 하나다.
## 경계에서 멈추지 않으면 zone_at 이 테두리를 잘라 같은 값을 돌려주어 무한 루프가 된다.
static func merge_k(k: int, j: int) -> Vector2i:
	if zone_at(k, j) != Z_PARK:
		return Vector2i(k, k)
	var k0 := k
	while k0 > CELL_MIN and zone_at(k0 - 1, j) == Z_PARK:
		k0 -= 1
	var k1 := k
	while k1 < CELL_MAX and zone_at(k1 + 1, j) == Z_PARK:
		k1 += 1
	return Vector2i(k0, k1)


static func merge_j(k: int, j: int) -> Vector2i:
	if zone_at(k, j) != Z_PARK:
		return Vector2i(j, j)
	var j0 := j
	while j0 > CELL_MIN and zone_at(k, j0 - 1) == Z_PARK:
		j0 -= 1
	var j1 := j
	while j1 < CELL_MAX and zone_at(k, j1 + 1) == Z_PARK:
		j1 += 1
	return Vector2i(j0, j1)


## 수퍼블록의 대표 셀인가 — (k, j) 사전순 최소. 배치는 여기서 **한 번만** 돈다.
## 셀마다 돌리면 같은 병합 구간에 밀도가 셀 수 배로 겹친다.
static func is_super_root(k: int, j: int) -> bool:
	return merge_k(k, j).x == k and merge_j(k, j).x == j


## 셀 (k, j) 의 배치 가능 구간. 공원이면 **병합 구간**이다 — 셰이더에서 내부 도로를
## 지우기만 하고 이 구간을 셀 단위로 두면, 프롭이 옛 도로 띠를 계속 피해
## "도로만 지워진 블록 넷" 이 되지 "수퍼블록" 이 되지 않는다.
## 병합 구간은 첫 비-공원 인접 중심선의 커브에서 멈추므로, 지워진 내부 도로 자리는
## 구간에 포함되어 그 위에도 나무가 선다.
static func span_x(k: int, j: int) -> Vector2:
	var m := merge_k(k, j)
	return Vector2(float(m.x) * PITCH + curb_half_at(m.x) + BLOCK_SETBACK,
		float(m.y + 1) * PITCH - curb_half_at(m.y + 1) - BLOCK_SETBACK)


static func span_z(k: int, j: int) -> Vector2:
	var m := merge_j(k, j)
	return Vector2(float(m.x) * PITCH + curb_half_at(m.x) + BLOCK_SETBACK,
		float(m.y + 1) * PITCH - curb_half_at(m.y + 1) - BLOCK_SETBACK)


## 셰이더로 넘길 존 지도 텍스처. 여기가 지도의 단일 원천이고 셰이더는 이것을 읽는다
## (판정기는 읽지 않는다 — 자기 사본을 든다).
static func zone_texture() -> ImageTexture:
	var img := Image.create(CELL_COUNT, CELL_COUNT, false, Image.FORMAT_R8)
	for j in range(CELL_MIN, CELL_MAX + 1):
		for k in range(CELL_MIN, CELL_MAX + 1):
			var v := float(zone_at(k, j) * ZONE_TEX_STEP) / 255.0
			img.set_pixel(k - CELL_MIN, j - CELL_MIN, Color(v, v, v))
	return ImageTexture.create_from_image(img)


static func block_center(k: int, j: int) -> Vector3:
	return Vector3(float(k) * PITCH + PITCH * 0.5, 0.0, float(j) * PITCH + PITCH * 0.5)


## 블록 내부. 큰 건물 한 채를 먼저 시도하고 남는 자리를 작은 것으로 채운다.
## 자리가 되는지는 add_slot 이 판단한다 — 레이아웃마다 기하를 손으로 맞추지 않는다.
## §25: 무엇이·얼마나 들어가는지는 그 셀의 **지구(zone)** 가 정한다.
func plan_block(rng: RandomNumberGenerator, k: int, j: int, out: Array) -> void:
	var dz := zone_at(k, j)
	if dz == Z_WATER:
		return
	# 공원은 수퍼블록 하나를 통째로 쓴다 — 대표 셀에서 한 번만 돈다.
	if dz == Z_PARK and not is_super_root(k, j):
		return
	var prof: Dictionary = ZONE_PROFILE[dz]
	# 블록 중앙 자리는 큰 것 전용이다. min_ext 를 안 걸면 이 한 번뿐인 기회를
	# 덤불이 차지해 대형 건물이 도시 전체에서 한두 채로 줄어든다(실측).
	# 대로가 한쪽에 붙은 블록은 격자 중앙과 사용 가능 구간의 중앙이 1.25m 어긋난다.
	# 중앙 슬롯뿐 아니라 산포의 기준점도 함께 옮겨야 한다 — 중앙만 옮기면 나머지가
	# 대로 보도 쪽으로 편향된 채 전부 거절된다.
	var sx := span_x(k, j)
	var sz := span_z(k, j)
	var c := Vector3((sx.x + sx.y) * 0.5, 0.0, (sz.x + sz.y) * 0.5)
	if rng.randf() < float(prof["center"]):
		add_slot(rng, c, "block", out, "", float(prof["center_ext"]), dz)
	# 산포 반경을 **사용 가능 구간에서 유도한다**(§22). 상수를 그대로 쓰면 대로가
	# 붙은 블록(반폭 7.95)에서 축당 6.5% 의 시도가 구간 밖으로 나가 add_slot 이 조용히
	# 거절한다. 구간 반폭을 그대로 쓰지 않고 상한을 씌우는 이유: 이 값은 **중심**의
	# 범위이고 에셋에는 폭이 있어서, 구간 끝까지 벌리면 가장자리 시도가 폭만큼 거절된다.
	# 공원은 병합 구간이 넓으므로 상한도 넓다(ZONE_PROFILE).
	var lim: float = float(prof["spread"])
	var spread := Vector2(minf(lim, (sx.y - sx.x) * 0.5), minf(lim, (sz.y - sz.x) * 0.5))
	for _i in int(prof["tries"]):
		add_slot(rng, c + Vector3(rng.randf_range(-spread.x, spread.x), 0.0,
			rng.randf_range(-spread.y, spread.y)), "block", out, "", 0.0, dz)


## 보도: 블록 네 변의 중앙선 위에 일정 간격으로 놓는다.
## 변마다 인접 도로의 등급이 다를 수 있으므로 중심선을 변마다 계산한다.
## 밀도는 그 셀의 지구가 정한다. 도로가 걷힌 자리의 보도는 in_zone 이 거절한다.
func plan_walk(rng: RandomNumberGenerator, k: int, j: int, out: Array) -> void:
	var b := block_center(k, j)
	var dz := zone_at(k, j)
	var skip: float = float(ZONE_PROFILE[dz]["walk_skip"])
	var half: float = PITCH * 0.5
	for side in [-1.0, 1.0]:
		var wz: float = b.z + side * (half - walk_center_at(line_index(b.z + side * half)))
		for t in [-8.0, -3.0, 3.0, 8.0]:
			if rng.randf() < skip:
				continue
			add_slot(rng, Vector3(b.x + t, 0.0, wz), "walk", out, "", 0.0, dz)
		var wx: float = b.x + side * (half - walk_center_at(line_index(b.x + side * half)))
		for t in [-8.0, -3.0, 3.0, 8.0]:
			if rng.randf() < skip:
				continue
			add_slot(rng, Vector3(wx, 0.0, b.z + t), "walk", out, "", 0.0, dz)


## 차도: 블록의 -x·-z 쪽 도로만 담당한다. 그래야 인접 블록과 중복 생성되지 않는다.
## 차량은 도로 축 방향으로 세운다 — 방향은 카탈로그에 적지 않고 모델 AABB 의
## 긴 축에서 유도한다(팩마다 모델이 X 로 눕기도, Z 로 눕기도 한다).
## 차선 수와 정차 자리는 둘 다 도로 등급의 함수다 — 대로에는 차가 더 많이, 더 넓게 선다.
func plan_road(rng: RandomNumberGenerator, k: int, j: int, out: Array) -> void:
	var b := block_center(k, j)
	var dz := zone_at(k, j)
	var skip: float = float(ZONE_PROFILE[dz]["road_skip"])
	var half: float = PITCH * 0.5
	var kz := j                               # 블록 -z 쪽 동서 도로의 중심선 인덱스
	var kx := k                               # 블록 -x 쪽 남북 도로의 중심선 인덱스
	var tz := road_slots(kx)                  # 동서 도로를 가로지르는 것은 남북 도로다
	var tx := road_slots(kz)
	for i in 4:
		for slot in lane_slots(kz):
			if rng.randf() < skip:
				continue
			add_slot(rng, Vector3(b.x + float(tz[i]), 0.0, b.z - half + float(slot[0])),
				"road", out, "x", float(slot[1]), dz)
		for slot in lane_slots(kx):
			if rng.randf() < skip:
				continue
			add_slot(rng, Vector3(b.x - half + float(slot[0]), 0.0, b.z + float(tx[i])),
				"road", out, "z", float(slot[1]), dz)


## 한 자리에 들어갈 에셋을 고른다.
##  (1) 판정 광장·지면 밖이면 아무것도 놓지 않는다.
##  (2) 그 자리·그 방향에서 **구역 밖으로 한 뼘도 나가지 않는** 에셋만 후보다.
##  (3) 이미 놓인 것과 상자가 겹치면 놓지 않는다 — 겹침을 생성 시점에 배제한다.
##
## (2)를 외접원으로 판단하면 안 된다. 길쭉한 것은 대각선이 폭보다 훨씬 커서
## 차선(폭 4m)에 들어가는 차가 전부 탈락한다 — 실측: 승용차 7종 중 1종만 남고
## 버스·구급차는 전멸했다. 회전이 90° 단위이므로 축방향 반extent 로 정확히 잰다.
func add_slot(rng: RandomNumberGenerator, pos: Vector3, zone: String, out: Array,
		road_axis := "", min_ext := 0.0, dz := Z_RESIDENTIAL) -> void:
	if Vector2(pos.x, pos.z).length() < PLAZA_R:
		return                                                      # 판정 광장
	if absf(pos.x) > GROUND_HALF - 2.0 or absf(pos.z) > GROUND_HALF - 2.0:
		return
	# 수역 셀 안에는 **자리의 종류를 가리지 않고** 아무것도 놓지 않는다(§25).
	# 교량 위도 비운다 — 그래야 Z3 가 "수역 셀 안에 프롭 0개" 라는 예외 없는 단언이 된다.
	if zone_at(cell_of(pos.x), cell_of(pos.z)) == Z_WATER:
		return
	var prof: Dictionary = ZONE_PROFILE[dz]
	var kinds: Array = prof["kinds"]
	var mul: float = float(prof["scale_mul"]) if zone == "block" else 1.0
	# 회전 후보를 먼저 정한다. 차량은 도로 축에 맞춰 두 방향, 나머지는 90° 네 방향.
	var spin := rng.randi_range(0, 3)
	var cands := []
	for e in CATALOG:
		if e["zone"] != zone:
			continue
		# 블록 내부만 지구제로 거른다 — 보도·차도 프롭은 어느 지구에서나 같다.
		if zone == "block" and not kinds.has(e["kind"]):
			continue
		var s: float = float(e["scale"]) * mul
		var h := half_extent(e["path"], s)
		if maxf(h.x, h.y) < min_ext:
			continue
		var yaw: float
		if road_axis.is_empty():
			yaw = float(spin) * PI * 0.5
		else:
			# 긴 축이 도로 축과 나란해지는 회전
			var long_is_z: bool = h.y >= h.x
			var want_z: bool = road_axis == "z"
			yaw = (0.0 if long_is_z == want_z else PI * 0.5) + float(spin % 2) * PI
		var ex := axis_extent(h, yaw)
		if in_zone(pos, ex, zone):
			cands.append({ "e": e, "yaw": yaw, "ex": ex, "s": s })
	if cands.is_empty():
		return
	var pick: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
	if not fits(pos, pick["ex"], out):
		return
	var e: Dictionary = pick["e"]
	# scale 은 **지구 배수를 곱한 실효값**을 싣는다. make_prop·지문·판정이 전부
	# 이 값을 쓰므로, 여기서 확정하지 않으면 도심 고층이 배치만 크고 렌더는 원래 크기가 된다.
	out.append({ "path": e["path"], "scale": pick["s"], "zone": zone,
		"pos": pos, "ex": pick["ex"], "yaw": pick["yaw"] })


## 회전(90° 단위)을 반영한 월드 축방향 반extent.
func axis_extent(h: Vector2, yaw: float) -> Vector2:
	var swapped := absf(sin(yaw)) > 0.5
	return Vector2(h.y, h.x) if swapped else h


## pos 에 반extent ex 로 놓았을 때 구역 안에 온전히 들어가는가.
## u = 가장 가까운 도로 중심선까지의 거리. 반폭은 그 선의 **등급**에 따라 다르다(§18).
func in_zone(pos: Vector3, ex: Vector2, zone: String) -> bool:
	var kx := line_index(pos.x)
	var kz := line_index(pos.z)
	var ux: float = absf(pos.x - float(kx) * PITCH)
	var uz: float = absf(pos.z - float(kz) * PITCH)
	var rx := road_half_at(kx)
	var rz := road_half_at(kz)
	# §25: 그려지지 않는 도로 위에는 프롭도 서지 않는다. 기하 조건만 보면 공원 내부의
	# 걷힌 도로 자리에 가로등이 서고 강기슭의 걷힌 차선에 차가 맨땅 위에 선다 —
	# in_zone 의 띠 검사는 도로가 **있는지**를 묻지 않기 때문이다.
	var kc := cell_of(pos.x)
	var jc := cell_of(pos.z)
	match zone:
		"road":
			# 동서 도로 또는 남북 도로 중 한쪽에 온전히 들어가면 된다. 세 조건이다:
			#  ① 아스팔트 안   ② 중앙 분리대 밖   ③ 교차로·횡단보도 밖.
			# ②가 없으면 대로 안쪽 자리의 차가 반extent 4.09 까지 허용되어 이중 중앙선을
			#   넘어 반대 차선까지 뻗는다. 일반 도로는 median 이 0 이라 기존과 동일하다.
			# ③은 자리 중심이 아니라 **프롭의 실제 길이**로 잰다. 중심만 빼는 방식은
			#   버스(반길이 4.24)의 차체가 교차로 안에 남는 것을 못 막는다.
			var on_z: bool = uz + ex.y <= rz and uz - ex.y >= median_at(kz) \
				and ux - ex.x >= rx + CROSS_W and seg_ew(kz, kc)
			var on_x: bool = ux + ex.x <= rx and ux - ex.x >= median_at(kx) \
				and uz - ex.y >= rz + CROSS_W and seg_ns(kx, jc)
			return on_z or on_x
		"walk":
			# 한 축은 보도 띠 안, 다른 축은 교차 도로를 침범하지 않아야 한다.
			var on_z: bool = uz - ex.y >= rz and uz + ex.y <= curb_half_at(kz) \
				and ux - ex.x >= rx and seg_ew(kz, kc)
			var on_x: bool = ux - ex.x >= rx and ux + ex.x <= curb_half_at(kx) \
				and uz - ex.y >= rz and seg_ns(kx, jc)
			return on_z or on_x
		_:
			# 대로가 한쪽에만 붙은 블록은 좌우 여백이 다르다 — 구간으로 본다.
			# 공원이면 span_* 이 **병합 구간**을 돌려주므로 걷힌 내부 도로 자리까지 찬다.
			if zone_at(kc, jc) == Z_WATER:
				return false
			var sx := span_x(kc, jc)
			var sz := span_z(kc, jc)
			return pos.x - ex.x >= sx.x and pos.x + ex.x <= sx.y \
				and pos.z - ex.y >= sz.x and pos.z + ex.y <= sz.y
	return false


## 이미 계획된 것들과 축정렬 상자가 겹치지 않는가. 회전이 90° 단위라 상자는
## 전부 월드 축에 정렬돼 있다(판정기의 E3 는 그 전제를 믿지 않고 OBB 로 다시 잰다).
func fits(pos: Vector3, ex: Vector2, out: Array) -> bool:
	for it in out:
		var p: Vector3 = it["pos"]
		var o: Vector2 = it["ex"]
		if absf(pos.x - p.x) < ex.x + o.x + GAP and absf(pos.z - p.z) < ex.y + o.y + GAP:
			return false
	return true


## 에셋의 XZ 반extent(스케일 반영). 메시 AABB 에서 직접 잰다.
## 스케일을 인자로 받는다 — 지구 배수(§25)가 붙으면 카탈로그의 값과 다르기 때문이다.
func half_extent(path: String, scale: float) -> Vector2:
	if not _r_cache.has(path):
		var s: Vector3 = mesh_of(path).get_aabb().size
		_r_cache[path] = Vector2(s.x, s.z) * 0.5
	return (_r_cache[path] as Vector2) * scale


## 모델 밑동(아래 BASE_FRAC 높이)의 XZ 반extent와, 메시 XZ 중심 대비 그 중심의
## 오프셋. 반환은 (반extent.x, 반extent.z, 중심오프셋.x, 중심오프셋.z) 로 담는다.
## 정점을 직접 훑으므로 에셋당 한 번만 계산해 캐시한다.
## 밑동에 정점이 거의 없으면(가는 기둥 등) 전체 AABB 로 되돌린다 — 콜라이더가
## 0 이 되어 물리가 사라지는 것보다 낫다.
func base_extent(path: String, ab: AABB) -> Vector4:
	if _base_cache.has(path):
		return _base_cache[path]
	var mesh := mesh_of(path)
	var cut: float = ab.position.y + ab.size.y * BASE_FRAC
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(i)
		for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.y <= cut:
				lo = lo.min(Vector2(v.x, v.z))
				hi = hi.max(Vector2(v.x, v.z))
	var full_half := Vector2(ab.size.x, ab.size.z) * 0.5
	var mesh_c := Vector2(ab.position.x + full_half.x, ab.position.z + full_half.y)
	var out: Vector4
	if lo.x > hi.x or (hi - lo).x < 0.02 or (hi - lo).y < 0.02:
		out = Vector4(full_half.x, full_half.y, 0.0, 0.0)
	else:
		var half := (hi - lo) * 0.5
		var c := lo + half
		out = Vector4(half.x, half.y, c.x - mesh_c.x, c.y - mesh_c.y)
	_base_cache[path] = out
	return out


func mesh_of(path: String) -> Mesh:
	if not _mesh_cache.has(path):
		_mesh_cache[path] = load(path)
	return _mesh_cache[path]


## 계획대로 노드를 만든다. 각 오브젝트는 1b/2단계의 흡입 대상과 완전히 같은 규약
## (레이어 2, "swallowable" 그룹, swallowable.gd)을 따른다 — 도시가 곧 먹이다.
func build(items: Array) -> void:
	for i in items.size():
		add_child(make_prop(items[i], i))


func make_prop(it: Dictionary, idx: int) -> RigidBody3D:
	var mesh := mesh_of(it["path"])
	var ab := mesh.get_aabb()
	var s: float = it["scale"]

	var body := RigidBody3D.new()
	body.set_script(SWALLOWABLE)
	body.collision_layer = 2
	body.collision_mask = 1 | 2
	# 이름에 번호를 붙여 형제 사이에서 유일하게 만든다. 중복이면 add_child 가
	# "@RigidBody3D@425" 같은 기계 이름으로 갈아치워 실패 로그를 못 읽게 된다
	# (읽기 좋은 이름을 얻는 add_child(node, true) 는 노드 588개에서 느리다).
	body.name = "%s_%d" % [String(it["path"]).get_file().get_basename(), idx]
	body.position = it["pos"]
	body.rotation.y = it["yaw"]
	body.add_to_group("swallowable")
	body.start_frozen = true      # 구멍이 다가올 때까지 정적. 넘어짐 방지 + 성능

	# 피벗 정규화: 모델의 XZ 중심을 원점으로, 최저점을 y=0 으로 옮긴다.
	# 팩마다 피벗이 제각각이라(y0 가 -1.12 ~ +0.01) 이 보정이 없으면
	# 오브젝트가 공중에 뜨거나 지면에 박힌 채 생성된다(E5).
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * s
	mi.position = Vector3(-(ab.position.x + ab.size.x * 0.5) * s, -ab.position.y * s,
		-(ab.position.z + ab.size.z * 0.5) * s)
	body.add_child(mi)

	# 콜라이더의 XZ 는 메시 전체가 아니라 **밑동**에서 딴다.
	# 전체 AABB 를 쓰면 나무가 "가지 폭 8.8m 짜리 통짜 덩어리" 가 되어,
	# 구멍이 몸통보다 훨씬 커도 크기 게이트에 걸려 영원히 안 먹힌다(플레이 피드백).
	# 지면에 닿아 있는 부분이 곧 지지면이므로, 물리적으로도 이쪽이 맞다.
	# 배치(placement)는 여전히 메시 전체 AABB 를 쓴다 — 가지가 이웃을 파고들면 안 된다.
	var base := base_extent(it["path"], ab)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(base.x * 2.0 * s, ab.size.y * s * BASE_FRAC, base.y * 2.0 * s)
	cs.shape = box
	cs.position = Vector3(base.z * s, ab.size.y * s * BASE_FRAC * 0.5, base.w * s)
	body.add_child(cs)

	# 수관: 밑동보다 확연히 넓은 모델(나무 등)은 **위쪽에 셰이프를 하나 더** 단다(§23).
	# §17 은 이것을 달 수 없었다 — 그때는 크기 게이트가 콜라이더의 외접반경을 보고
	# 있어서, 수관을 달면 나무가 통째로 거절됐다. 이제 구멍 둘레에 물리적 림이 있고
	# 통과 여부를 물리가 정하므로, 수관은 **가지가 림에 걸리는** 진짜 이유가 된다.
	var top_half := Vector2(ab.size.x, ab.size.z) * 0.5 * s
	if maxf(top_half.x, top_half.y) >= maxf(base.x, base.y) * s * CANOPY_RATIO:
		var cc := CollisionShape3D.new()
		var cbox := BoxShape3D.new()
		cbox.size = Vector3(top_half.x * 2.0, ab.size.y * s * (1.0 - BASE_FRAC),
			top_half.y * 2.0)
		cc.shape = cbox
		cc.position = Vector3(0.0, ab.size.y * s * (1.0 + BASE_FRAC) * 0.5, 0.0)
		body.add_child(cc)

	# 질량은 부피 비례. pull() 이 mass 를 곱하므로 가속도가 크기와 무관해진다.
	var vol: float = ab.size.x * ab.size.y * ab.size.z * s * s * s
	body.mass = clampf(vol * 0.25, 0.5, 400.0)
	return body


## 판정용: 계획을 문자열 지문으로 만든다. 시드가 같으면 지문이 같아야 한다(E4).
static func fingerprint(items: Array) -> String:
	var parts := PackedStringArray()
	for it in items:
		var p: Vector3 = it["pos"]
		parts.append("%s|%.3f|%.3f|%.4f|%.2f"
			% [it["path"], p.x, p.z, fposmod(float(it["yaw"]), TAU), it["scale"]])
	return "\n".join(parts)
```

---

## §14. 3c단계 — 성능 측정 (측정 결과: 최적화 불필요)

로드맵의 "MultiMesh 최적화"는 **측정 뒤에 판단할 항목**으로 두었다. 근거 없는 최적화는 하지 않는다.

### 3c DoD — `-- --judge3c`

도시가 빽빽한 지점 `(-48, 0, -48)`으로 구멍을 옮기고 워밍업 60프레임 뒤 300프레임을 잰다. **vsync를 끄지 않으면 어떤 씬이든 16.7ms로 측정되어 판정이 무의미해진다.**

| ID | 기준 | 실측 |
|---|---|---|
| **F1** | 평균 프레임 시간 ≤ 16.67ms (60fps) | **0.99ms (1007fps)** — 예산의 6% |
| **F2** | 최악 프레임 ≤ 33.3ms | **2.66ms** |

`props=588 draws=1562 prims=786730 active_bodies=0`

### 결론

**MultiMesh 인스턴싱은 도입하지 않는다.** 드로우콜 1562개에 프레임 시간이 예산의 6%다 — 이 규모에서 인스턴싱은 측정 가능한 이득 없이 구조만 복잡하게 만든다(흡입 대상은 개별 강체여야 하므로 MultiMesh는 "그리기 따로, 물리 따로"의 이중 표현을 요구한다). F1·F2를 판정에 남겨 두었으므로, 4단계에서 오브젝트·AI 구멍이 늘어 예산을 넘기면 **그때 측정이 알려 준다.**

`start_frozen`(프롭을 정적으로 시작)의 이득도 측정했다: 고정 0.99ms vs 해제 1.05ms — **6%**. 양쪽 모두 `active_bodies=0`으로, Jolt는 어차피 곧 재운다. 유지하되 근거는 "넘어짐 방지"가 아니라 이 6%와 초기 정착 지터 제거다.

### 측정의 한계

RTX 4060 Ti / Forward+ / 1152×648 한 대의 수치다. 저사양 GPU나 고해상도에서는 다르게 나온다. **판정이 이 PC의 창 모드 실행에 묶여 있다는 §8의 제약이 그대로 적용된다.**

---

## §15. 4a단계 — AI 경쟁 구멍 · 구멍끼리의 포식 (구현·검증 완료)

### 규칙

| 항목 | 규칙 | 근거 |
|---|---|---|
| 구멍 수 | 플레이어 1 + AI 5 = **6** | 셰이더는 16개까지 받는다(V7 클램프). 6개는 판정 시나리오가 세 번 소비해도 자유 실행에 3개가 남는 최소값이다 |
| 스폰 | 원점 둘레 반경 64의 원 위 이상점을 **격자 교차로로 스냅** | 원 위에 그냥 놓으면 구멍이 건물 밑에서 시작한다 — 실측: 6개 중 3개가 그 건물에 가려 H2로 탈락 |
| **포식** | **`d + Rb × 0.8 ≤ Ra`** (§17에서 재조정). 단 `Ra ≥ Rb × 1.05` | 조건을 두 번 바꿨다. "온전히 포함"(`d + Rb ≤ Ra`)은 자유 실행 900프레임에서 포식 **0회**였고, "중심 포함"(`d ≤ Ra`)은 플레이에서 **"접촉만 해도 죽는다"**로 읽혔다 |
| 포식 성장 | `Ra' = sqrt(Ra² + Rb²)` — **보정 없는 면적 합** | 오브젝트 흡입의 `growth_k = 4`는 체감 조정 계수지만, 구멍끼리는 실제 단면적이므로 보정하지 않는다 |
| 포식 해소 시점 | Main의 `process_physics_priority = 100` — **그 프레임의 이동이 끝난 뒤** | 기본 순서(부모 먼저)로는 AI가 Main 다음에 움직여, 이번 프레임에 생긴 겹침이 다음 프레임까지 남는다. 그 한 프레임 동안 우물이 서로 파고든 채 그려진다 |
| 성장 시 재클램프 | `set_radius()`가 `move_to(global_position)`를 다시 부른다 | 자란 만큼 지면 여유가 줄어든다. 없으면 경계에 붙은 구멍이 삼킬 때마다 조금씩 밖으로 밀려난다(실측 G5 위반 1회) |
| AI 행동 | ① 나를 먹을 수 있는 구멍이 `3.5R` 안에 있으면 도망 ② 내가 먹을 수 있는 구멍을 쫓음 ③ 없으면 삼킬 수 있는 가장 가까운 오브젝트 ④ 없으면 시드에서 뽑은 배회 지점 | 세 줄이면 충분하다. 난수는 시드 고정 — 판정이 같은 시나리오를 다시 돌릴 수 있어야 한다 |
| 플레이어 사망 | 플레이어 구멍도 먹힌다. `player_alive()`가 모든 전제를 먼저 검사 | 없으면 먹힌 프레임에 `previously freed`로 죽는다(실측) |

**1a~3단계 판정은 구멍 하나를 전제로 세워졌다.** AI를 씬에 넣으면 `judge_static`이 화면 밖 구멍까지 판정하고, AI가 광장의 판정 대상을 먹어 C1·C3의 기대값이 깨진다. `Judge._ready`가 `Main._ready`보다 먼저 도는 것을 이용해 **`--judge4`에서만 아레나를 켠다**(`_main.arena`).

### 4a DoD — `-- --judge4`

| ID | 기준 | 검출 대상 | 실측 (정상 / 고장) |
|---|---|---|---|
| **G1** | 시작 배치에서 **구멍 6개 각각** 카메라를 옮겨 H1~H10 통과 | 다중 구멍이 한 셰이더로 동시에 제대로 그려지는가 | 6/6 PASS |
| **G2** | **총 면적 보존**: `Σ_생존 R² == Σ_시작 R² + 4·Σ_사라진 r²` | 성장의 출처가 실제로 사라진 것들인가 (AI가 공짜로 자라지 않는가) | `1793.6565 == 1793.6565` ✔ / 계수 6.0 ✘ |
| **G3** | 큰 구멍이 작은 구멍을 삼키고 `R' = sqrt(12²+4²)` | 포식과 면적 합 | `12.6491 == 12.6491` ✔ / 선형 성장 ✘ |
| **G4** | **역할을 맞바꾼 같은 시나리오** — AI가 플레이어를 삼킨다 | 포식이 크기로 정해지고 등록 순서·플레이어 여부로 정해지지 않는가 | `12.6491` ✔ / 크기 조건 제거 ✘ |
| **G5** | 모든 구멍이 항상 지면 안 (`|p| ≤ 96 − 1.15R`) | 우물이 허공에 뜨는 것 | 위반 `0` ✔ / 클램프 제거 시 `688` ✘ |
| **G6** | 겹침이 **같은 프레임에** 해소된다 | 포식 판정이 이동보다 먼저 돌아 한 프레임 늦는 것 | 미해소 `0` ✔ / 우선순위 제거 시 `1` ✘ |
| **G7** | AI가 실제로 움직이고(경로 ≥ 30m) 자란다(ΔR > 0) | "AI 구멍이 있다"가 아니라 "AI가 경쟁한다" | `path=178.2 dR=+23.8` ✔ / 조종 무력화 ✘ |

**G2의 좌변만 구현체에서 읽는다.** 우변은 판정기가 콜라이더에서 직접 잰 오브젝트 반경과 "인스턴스가 실제로 사라졌는가"로 계산하고, **성장 계수도 판정기가 `SPEC_GROWTH_K = 4.0`으로 따로 들고 있다.** 처음에는 `alive[0].growth_k`를 읽었는데, 그러면 계수만 바꾼 빌드가 자기 값끼리 일치해 그대로 통과한다 — **2단계 C1도 같은 함정에 빠져 있어 함께 고쳤다.**

**판정의 유효 전제 두 가지를 판정기에 명시했다.**
- **앙각 ≥ 30°**: 지평선 근처의 구멍은 근측 림이 우물 안쪽을 가려 "구멍 안" 표본이 지면을 읽는다(실측: R=31 구멍이 화면 상단에서 H2 ring 상한 0.6314 = 지면 휘도). §8이 선언한 범위 밖이며 결함이 아니다.
- **다른 구멍과 겹치지 않을 것**: 다중 구멍 SDF는 합집합 하나로 그려지므로 "구멍 하나 = 원반 하나"라는 H1·H2의 전제가 겹친 상태에서는 성립하지 않는다. 겹침이 **해소되는가**는 G6가 따로 본다.
- **G1은 씬 오브젝트를 숨기고 판정한다**: G1이 묻는 것은 "여러 구멍이 한 셰이더로 동시에 제대로 그려지는가"이고, 도시가 구멍을 가리는 것은 그 질문과 무관한 배치 문제다(§6의 선언된 전제). 실측: 교차로에 스폰해도 6m 앞의 차량·가로시설물이 림 스캔에 섞여 H2·H8이 무너졌다.

**구멍이 크게 자라면 D(도시 지면) 기준은 물을 수 없는 질문이 된다** — 카메라가 반경에 비례해 물러나 규격 노면표시가 화면에서 서브픽셀이 되기 때문이다. `judge_static(allow_no_block)`으로 이 완화를 **호출자가 명시적으로 켜는 경우에만** 허용한다. 셰이더 결함의 도피처는 되지 않는다: 블록 유효성 판정은 전부 판정기의 SPEC 상수와 투영 기하로만 계산하므로, 도로를 안 그린 빌드에서도 블록은 그대로 유효하고 D1이 잡는다.

### 고장 주입 결과 (7종)

| 주입 | 결과 | 잡은 기준 |
|---|---|---|
| *(정상 빌드)* | **PASS** | — |
| 포식 크기 조건 제거 | FAIL | G4 |
| 포식 성장을 선형으로 | FAIL | G2·G3·G4 |
| 성장 계수 4.0 → 6.0 | FAIL | G2 |
| 지면 클램프 제거 | FAIL | G5 (`offground=688`) |
| 포식 해소 우선순위 제거 | FAIL | G6 (`unresolved=1`) |
| AI 조종 무력화 | FAIL | G6·G7 |

### 판정 시나리오가 스스로 만들어 낸 함정 셋

1. **자유 실행 뒤에 포식 시나리오를 돌렸다.** 커진 구멍의 반경을 강제로 줄이면 kill 깊이가 얕아져, 멀리서 낙하 중이던 오브젝트가 한꺼번에 소멸 처리된다 — R=2로 줄인 구멍이 60프레임 만에 **R=24.35로 폭주**했다. 게임에서는 일어나지 않는 상태였다. → 포식 시나리오를 자유 실행 **앞으로** 옮겼다.
2. **격리한 구멍이 시나리오에 끼어들었다.** 네 귀퉁이로 치운 구멍 옆에 시나리오 참가자가 서 있어 기대값이 `R=16.82`(vs 12.65)로 어긋났다. → 참가자를 원점으로 옮겨 격리 지점에서 가장 멀리 뒀다.
3. **G6를 자유 실행에 맡겼더니 자극되지 않았다.** 우선순위 결함을 심어도 `unresolved=0`으로 통과했다 — 겹침은 "AI가 Main보다 늦게 움직여 만든 겹침"일 때만 한 프레임 남는데, 자유 실행에서는 AI가 위협을 피해 다니느라 그 상황이 오지 않았다. → **AI가 사냥해 들어가는 전용 시나리오**를 만들고, 포식이 실제로 성사됐는지(`ate`)까지 함께 확인한다.

### 아직 기계 판정이 없는 것

AI의 난이도 균형(너무 강한가/약한가), 쫓기는 긴장감, 카메라가 큰 반경에서 물러나는 정도의 체감 — 육안·수동 조작 확인 사항이다.

### `scripts/hole_ai.gd` (전문 — 실행 검증본)

```gdscript
extends Node

const CITY := preload("res://scripts/city.gd")

## 4a: 경쟁 구멍의 조종자. 부모 Hole 을 매 물리 프레임 움직인다.
##
## 규칙은 세 줄이다.
##   1. 나보다 큰 구멍이 사정권에 있으면 도망친다 (먹히면 끝이다).
##   2. 내가 삼킬 수 있는 구멍이 가까이 있으면 쫓는다 (가장 큰 이득).
##   3. 아니면 삼킬 수 있는 오브젝트 중 가장 가까운 것으로 간다.
## 목표가 없으면 시드에서 뽑은 배회 지점으로 간다 — 제자리에 굳지 않게.
##
## 난수는 시드로 고정한다. 판정이 같은 시나리오를 두 번 돌릴 수 있어야 한다.

@export var speed := 12.0
@export var ai_seed := 0
## 이 반경 안에서만 목표를 찾는다. 맵 전체를 매 프레임 훑으면 오브젝트 500개에
## 구멍 수를 곱한 만큼 비용이 든다.
@export var sight := 70.0
## 나보다 큰 구멍에서 이만큼(내 반경 배수) 떨어져 있으면 위협으로 본다.
@export var fear_k := 3.5
## 목표를 다시 고르는 주기(물리 프레임). 매 프레임 고르면 동률에서 덜덜 떤다.
@export var retarget_frames := 20
## 무진전 감지(§25). 강이 생기면서 "목표가 강 건너" 가 일상이 됐다 — 축별 슬라이드는
## 둑을 따라 미끄러지게 해 주지만, 목표가 계속 강 건너면 둑을 영원히 밀며 정지한다.
## **배회 지점만 다시 뽑는 것으로는 부족하다**: choose_target 이 sight(70) 안의 최근접
## 먹이를 다시 고르는데 강폭이 32 뿐이라 강 건너 먹이가 최근접인 상황이 흔하다.
## 그래서 목표도 함께 일정 시간 제외한다. 경로 탐색은 도입하지 않는다 —
## 이 게임의 AI 는 조언 수준이면 충분하다.
@export var stuck_frames := 120
@export var stuck_dist := 0.5
@export var ban_frames := 600

var _rng := RandomNumberGenerator.new()
var _hole: Node3D
var _reg: Node
var _target: Node3D = null
var _wander := Vector3.ZERO
var _tick := 0
var _stuck_ref := Vector3.ZERO
## 인스턴스 ID -> 이 틱까지 목표에서 제외
var _banned := {}


func _ready() -> void:
	_hole = get_parent()
	_reg = get_node("/root/HoleRegistry")
	_rng.seed = ai_seed
	_wander = pick_wander()


func _physics_process(_dt: float) -> void:
	if _hole == null or not is_instance_valid(_hole):
		return
	_tick += 1
	# 무진전이면 배회 지점을 다시 뽑고 지금 목표를 한동안 제외한다(§25).
	if _tick % stuck_frames == 0:
		if _hole.global_position.distance_to(_stuck_ref) < stuck_dist:
			_wander = pick_wander()
			if is_instance_valid(_target):
				_banned[_target.get_instance_id()] = _tick + ban_frames
			_target = null
		_stuck_ref = _hole.global_position
	if _tick % retarget_frames == 0 or not is_instance_valid(_target):
		_target = choose_target()
	var goal := _wander
	if is_instance_valid(_target):
		goal = _target.global_position
	var threat := nearest_threat()
	if threat != null:
		# 위협의 반대 방향으로. 목표보다 우선한다.
		var away := _hole.global_position - threat.global_position
		away.y = 0.0
		if away.length_squared() < 1e-6:
			away = Vector3(1, 0, 0)
		goal = _hole.global_position + away.normalized() * sight
	var to := goal - _hole.global_position
	to.y = 0.0
	if to.length() < 0.05:
		_wander = pick_wander()
		return
	var step: float = minf(to.length(), speed / 60.0)
	_hole.move_to(_hole.global_position + to.normalized() * step)


## 나를 삼킬 수 있는 구멍 중 가장 가까운 것.
func nearest_threat() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for h in _reg.holes():
		if h == _hole or not is_instance_valid(h):
			continue
		if float(h.radius) < float(_hole.radius) * float(_hole.hole_bite_ratio):
			continue
		var d: float = flat_dist(h.global_position, _hole.global_position)
		if d < float(_hole.radius) * fear_k and d < bd:
			bd = d
			best = h
	return best


## 쫓을 대상. 먹을 수 있는 구멍이 우선, 없으면 먹을 수 있는 오브젝트.
func choose_target() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for h in _reg.holes():
		if h == _hole or not is_instance_valid(h) or is_banned(h):
			continue
		if float(_hole.radius) < float(h.radius) * float(_hole.hole_bite_ratio):
			continue
		var d: float = flat_dist(h.global_position, _hole.global_position)
		if d < sight and d < bd:
			bd = d
			best = h
	if best != null:
		return best
	for o in get_tree().get_nodes_in_group("swallowable"):
		if not is_instance_valid(o) or o.falling or is_banned(o):
			continue
		# 척도는 좁은 쪽 반폭이다(§23) — 외접반경으로 고르면 원 안에 들어가는
		# 길쭉한 물체를 AI 가 통째로 무시한다.
		if not _hole.can_swallow(float(o.fit_radius)):
			continue
		var d2: float = flat_dist(o.global_position, _hole.global_position)
		if d2 < sight and d2 < bd:
			bd = d2
			best = o
	return best


## 무진전 때 제외한 목표인가. 지난 것은 그 자리에서 정리한다.
func is_banned(n: Node) -> bool:
	var id := n.get_instance_id()
	if not _banned.has(id):
		return false
	if _tick >= int(_banned[id]):
		_banned.erase(id)
		return false
	return true


## 지면 안의 임의 지점. 반경에 여유를 두어 가장자리에 붙지 않게 한다.
## §25: 수역은 배회 지점이 될 수 없다 — 도달할 수 없는 곳을 향해 둑을 밀게 된다.
## 시행 횟수를 고정해야 재현성이 유지된다(난수 소비량이 결과에 따라 달라지면 안 된다).
func pick_wander() -> Vector3:
	var lim: float = float(_hole.ground_half) * 0.8
	var out := Vector3.ZERO
	var got := false
	for _i in 8:
		var p := Vector3(_rng.randf_range(-lim, lim), 0.0, _rng.randf_range(-lim, lim))
		if not got and CITY.passable(p):
			out = p
			got = true
	return out


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
```

---

## §16. 4b단계 — 게임 루프 · UI (구현·검증 완료)

### 규칙

| 항목 | 규칙 | 근거 |
|---|---|---|
| 라운드 | `round_seconds = 120`. `PLAYING → OVER` 두 상태 | 판정기는 `round_seconds`를 4초로 줄여 종료까지 돌린다 |
| 승자 | 점수 최댓값, 동점이면 반경 | 리더보드의 정렬 기준과 같아야 한다 |
| 종료 사유 | `"time"`(시간 만료) / `"eaten"`(플레이어가 먹힘) | 플레이어가 먹히면 `resolve_bites`가 그 자리에서 판을 끝낸다 |
| **종료 시 정지** | 모든 구멍의 `set_physics_process(false)` + `set_ai(false)` | **AI만 세우면 안 된다** — 낙하 중이던 오브젝트가 계속 소멸하며 점수가 더 올라, "끝났다"가 상태로 성립하지 않는다(T3가 이것을 잡는다) |
| 재시작 | `R` 키 → `restart()`. 구멍·도시·판정 대상을 전부 다시 만든다 | `reload_current_scene()`을 쓰지 않는 이유는 **Judge 노드가 Main의 자식이라 함께 사라져 재시작을 판정할 수 없기 때문**이다 |
| UI | 하단 좌측 = 내 상태, 상단 중앙 = 타이머, 우측 = 리더보드, 중앙 = 게임 오버 | 판정 중에는 `hud_root`(CanvasLayer) 전체를 숨긴다 — 라벨 하나만 숨기면 리더보드가 지면 표본을 가린다 |

**재시작이 초기 상태를 복원한다는 것은 이미 갖춘 재현성 덕분에 값싸게 검증된다.** 도시 배치가 시드 고정(E4)이고 AI 스폰이 고정 배치이므로, 재시작 후의 프롭 수·배치 지문·구멍 수·반경·점수가 최초와 같아야 한다.

### 4b DoD — `-- --judge5`

| ID | 기준 | 검출 대상 | 실측 (정상 / 고장) |
|---|---|---|---|
| **T1** | 남은 시간이 **판정기의 독립 시계**와 같은 속도로 줄고, 0에서 `OVER`가 된다 | 멈춘 타이머·잘못된 속도 | `drift=0.009s` ✔ / 정지·2배속 ✘ |
| **T2** | 리더보드 행 수가 구멍 수와 같고, **판정기가 정렬한 순서대로** 이름·점수가 그 줄에 있다 | 정렬 누락, 표시와 실제의 불일치 | 6행/6구멍 ✔ / 정렬 제거 ✘ |
| **T3** | 종료 후 120 물리 프레임 동안 모든 구멍의 점수·반경·위치가 불변 | "끝났다"가 상태로 성립하는가 | 변동 `0` ✔ / 물리 계속 시 ✘ |
| **T4** | 승자가 **판정기가 독립 계산한** 최고 점수 구멍과 일치 | 승자 산출 오류 | `AI4(1103)` 일치 ✔ / 항상 플레이어 ✘ |
| **T5** | 재시작 후 구멍 6개·전부 R=5·점수 0·프롭 1965개·배치 지문 동일·판정 대상 8개·`PLAYING`·시간 복원 | 부분 복원 | 전부 일치 ✔ / 도시·시간 미복원 ✘ |
| **T6** | 플레이어가 먹히면 그 자리에서 `OVER`, 사유 `"eaten"` | 패배가 판정되지 않는 것 | ✔ / 종료 안 함 ✘ |

**T1은 절대 시각이 아니라 기울기로 잰다.** 재시작 직후 첫 프레임은 도시 프롭 588개를 다시 세우느라 `dt`가 커서, 그 한 프레임이 절대 비교에 0.25초짜리 오차로 남는다(실측 `drift=0.255s`로 정상 빌드가 탈락). 워밍업 뒤 기준점을 다시 잡으면 `0.009s`가 된다. **`_main.time_left`를 그대로 믿지 않는다** — 그러면 타이머를 아예 멈춘 빌드도 "0이 아니다"로 통과한다.

### 고장 주입 결과 (8종)

| 주입 | 결과 | 잡은 기준 |
|---|---|---|
| *(정상 빌드)* | **PASS** | — |
| 타이머 정지 | FAIL | T1(·T2·T3·T4 연쇄) |
| 타이머 2배속 | FAIL | T1 |
| 리더보드 정렬 제거 | FAIL | T2 |
| 승자를 항상 플레이어로 | FAIL | T4 |
| 종료 후에도 물리 계속 | FAIL | T3·T4 |
| 재시작에서 도시 미복원 | FAIL | T5 |
| 재시작에서 시간 미복원 | FAIL | T1·T3·T4·T5 |
| 플레이어 사망 시 종료 안 함 | FAIL | T6 |

### 4b가 4a를 깼고, 그것을 회귀가 잡았다

4b의 `end_game()`이 모든 구멍의 물리를 멈추는데, **4a의 G4는 플레이어가 먹히는 시나리오**라 그 순간 판이 끝난다. 이후 아레나 자유 실행에서 AI가 얼어붙어 `G7: path=15.1 dR=+0.000`으로 무너졌다. 전 판정 회귀를 돌리지 않았으면 4b만 보고 넘어갔을 결함이다.

해결은 `resume()` — 재시작 없이 끝난 판을 진행 상태로 되돌리는 경로다. `end_game`이 멈춘 것을 정확히 되돌린다. 4a 판정이 이것을 호출해 자유 실행을 이어간다.

### 아직 기계 판정이 없는 것

라운드 길이(120초)가 적당한가, 리더보드 가독성, 게임 오버 화면의 인상, `R` 키 재시작의 손맛 — 육안·수동 조작 확인 사항이다. **입력 자체도 기계 판정 밖이다** — 판정기는 `restart()`를 직접 호출하지 키 입력을 흉내 내지 않는다.

---

## §17. 플레이 피드백 재조정 (rev.15 · rev.16)

4b까지 판정 8종이 전부 통과한 상태에서 **사람이 직접 플레이했다.** 기계 판정이 "아직 판정 없음"으로 남겨 둔 항목들이 바로 문제로 돌아왔다 — 그 목록이 정확했다는 뜻이기도 하다.

| # | 피드백 | 조치 |
|---|---|---|
| 1 | 착시 그럴듯함, 계단현상 없음 | — |
| 2 | **모두 너무 빨리 자람** | `growth_k` 4.0 → **1.0** |
| 3 | **AI가 너무 강함 / 지도가 좁음 / 포식 판정이 관대함** | 지면 192² → **320²**, 포식 규칙에 `bite_depth = 0.8` 도입 |
| 4 | 도로가 너무 격자, 건물 밀도 낮음 | 밀도만 상향(**미완**: 도로 위계는 남음) |
| 5 | 카메라 괜찮음 | — |
| 6 | 라운드 길이 괜찮음 | — |
| 7 | **나무가 안 먹힘 / 빨간 박스가 아무 구멍에도 안 먹힘** | 콜라이더를 밑동 기준으로 / `RefBox` 제거 |

### 7번은 진짜 결함이었다 — 콜라이더가 잘못된 물리 모형이었다

도시 프롭의 콜라이더를 **메시 전체 AABB**로 만들고 있었다. 나무는 그래서 "가지 폭 8.8m짜리 통짜 덩어리"가 되고, 크기 게이트(`r ≤ R × 0.45`)가 몸통이 아니라 수관을 기준으로 걸린다. 구멍이 몸통보다 훨씬 커도 안 먹히는 이유가 이것이다.

콜라이더의 XZ를 **아래 35% 높이의 정점에서** 딴다(`BASE_FRAC`). 지면에 닿아 있는 부분이 곧 지지면이므로 물리적으로도 이쪽이 옳다. **배치는 여전히 메시 전체 AABB로 한다** — 가지가 이웃을 파고들면 안 된다.

| 에셋 | 먹는 데 필요한 구멍 반경 (전 → 후) |
|---|---|
| Tree3 | 7.4 → **1.8** |
| Tree1 | 6.1 → **2.0** |
| Tree4 | 9.8 → **3.7** |
| 덤불·표지판 | 1.4~0.8 → **0.4~0.2** |
| 건물 (Bank, Hospital…) | 19.5 → 19.2 / 17.9 → 17.6 (거의 불변) |
| 차량 | 5.1 → 5.1 (불변) |

건물과 차량이 거의 안 변하는 것이 이 방법이 옳다는 증거다 — 벽이 수직이면 밑동이 곧 전체다.

**`RefBox`는 1a의 스케일 기준용 장식이었다.** 콜라이더도 물리도 없으니 어떤 구멍에도 안 먹히는 것이 맞았고, 완성된 게임에 남아 있을 이유가 없어 제거했다.

### 재조정이 판정기를 두 곳에서 깼다

**① 포식 규칙을 바꾸고 판정기의 독립 사본을 안 고쳤다.** `unresolved_bites()`가 옛 규칙(`d ≤ Ra`)으로 계산해 G6가 16프레임을 오검출했다. 판정기가 규격을 따로 드는 설계 덕에 드러났지만, 동시에 **게임 규칙을 바꾸면 규격도 의식적으로 고쳐야 한다**는 뜻이다. `SPEC_BITE_RATIO`·`SPEC_BITE_DEPTH`로 명시했다.

**② 성장을 늦추니 판정 시나리오가 성립하지 않게 됐다.** 판정 대상 8개(소형 6 + 대형 2)에서, 소형을 다 먹어도 대형의 크기 게이트에 닿지 못한다 — B2가 `swallowed=6/8`, C2가 "구멍이 자라면 열린다"를 시험할 기회를 잃었다. 소형 박스를 `1.2` → `2.6`으로 키워 해결했다(`R 5 → 6.73`, 게이트 `3.03 > 대형 r 2.83`).

### D5·G1의 판정 전제를 맞췄다

도시 밀도를 올리자 3a의 D5 지점(교차로·도로 위)에도 프롭이 3m 안에 들어와 H2·H8이 무너졌다. **D5는 지면 셰이더가 구멍에 뚫리는가를 묻는 기준**이므로, G1과 같은 근거로 프롭을 숨기고 판정한다(§15의 "G1은 씬 오브젝트를 숨기고 판정한다"와 동일).

### 재조정 후 계측

| 항목 | 전 | 후 |
|---|---|---|
| 프롭 수 | 588 | **1965** |
| 프레임 시간 | 0.99ms | **1.69ms** (591fps, 예산의 10%) |
| 드로우콜 | 1562 | 2251 |
| 15초 자유 실행에서 AI 반경 증가 | +23~26 | **+4~9** |
| 2단계 최종 반경 (판정 대상 8개 흡입) | 10.31 | **7.83** |

**판정 8종 전부 PASS**로 회귀 확인.

### 2차 재조정 — 시작 반경 (rev.16)

1차 재조정 뒤 다시 플레이한 결과: 성장 속도는 맞으나 **30초를 남기고 지도의 건물을 다 먹어 치웠고 AI도 할 일이 없어졌다.** 원인은 성장률이 아니라 **시작 크기**였다. 원작은 소화전·사람 같은 작은 것부터 먹으며 커지는데, `R = 5.0`은 처음부터 나무가 걸림 없이 삼켜지는 크기다.

| 항목 | 전 | 후 | 근거 |
|---|---|---|---|
| 시작 반경 | 5.0 | **1.5** | 게이트 `R × 0.45 = 0.675` → 트래픽콘(0.43)·덤불(0.16~0.34)·표지판(0.07~0.19)만 열린다. 나무는 1.8~3.7, 차량은 4.0~5.2, 건물은 8.7~19.2에서 열린다 |
| 지면 | 320×320 | **448×448** | 면적 1.96배 |
| AI 스폰 반경 | 96 | 128 | 지면 확대에 비례 |
| 카메라 | 반경 정비례 | **최저 높이 14m 로 clamp** | 정비례만 시키면 `R=1.5`에서 높이 6.6m 로 내려가 12~14m 건물이 시야를 막는다. 배율을 통째로 clamp 하므로 앙각 40.2°는 유지된다 |
| 프롭 수 | 1965 | **3832** | |
| 프레임 시간 | 1.69ms | **2.04ms** (489fps) | 예산의 12% |

**판정 픽스처를 게임 값에서 떼어냈다.** 시작 반경을 1.5로 줄이자 판정 대상 8개(소형 r=1.84, 대형 r=2.83)가 게이트(0.675)에 하나도 걸리지 않아 **B2·C2가 시험 자체를 못 하게 됐다.** 1b·2단계가 묻는 것은 "흡입·성장 파이프라인이 규격대로 도는가"이지 "시작 반경이 얼마인가"가 아니므로, 두 시나리오는 시작 시 `FIXTURE_R = 5.0`으로 반경을 고정하고 돈다. 시작 반경 자체는 `SPEC_START_R`로 따로 두어 T5(재시작 복원)와 4a 자유 실행이 검사한다.

**이번에도 재조정이 판정기와 게임을 각각 하나씩 깼다.**

| 깨진 것 | 원인 | 조치 |
|---|---|---|
| `--judge` H6 무효 | 카메라를 당기고 도시를 채우자 **네 모서리마다 원경의 건물이 걸려** 탐침 프레임에서 배경(마젠타)을 못 찾았다 | `background_pixel()`이 화면 위쪽부터 훑어 처음 만나는 배경 픽셀을 쓴다 |
| `--judge2` C3 (`score 2029 vs 2028`) | 광장을 26 → 18로 줄였더니, R=7.8로 자란 구멍이 x=16까지 이동해 **Area 도달 반경 23.9m**가 광장을 넘어 도시 프롭을 삼켰다 | 광장을 26으로 되돌렸다. 대가로 플레이어는 반경 26m의 빈 광장에서 시작한다(약 2초 이동) |
| **게임: 판이 끝난 뒤에도 구멍끼리 잡아먹음** | `resolve_bites()`가 `state`를 보지 않았다 | `state == OVER`면 돌지 않는다. **T3가 잡았다** — 종료 후 120프레임 동안 레지스트리가 변했다 |
| `--judge4` G3·G4 | 위 수정의 부작용 — G6 시나리오에서 플레이어가 먹혀 판이 끝나면 이후 포식 시나리오가 아예 성립하지 않는다 | 각 포식 시나리오가 시작 시 `resume()`을 부른다 |

### 배포 (rev.16)

- **저장소**: https://github.com/bbumjin/hole-io-game
- **플레이**: https://hole-io-game-delta.vercel.app (Vercel 프로덕션)
- GitHub Pages 는 **폐기했다**(2026-07-29). `gh-pages` 브랜치가 stale 한 옛 빌드를 계속
  서빙하고 있었다 — 브랜치를 지웠고 `bbumjin.github.io/hole-io-game` 은 404 다.
  배포 경로는 Vercel 하나뿐이다.

**웹은 Forward+ 를 지원하지 않는다**(WebGL2 = Compatibility 뿐). `project.godot` 에 `rendering_method.web="gl_compatibility"` 오버라이드를 두었다. 그 렌더러에서도 착시가 성립하는 것을 **실측으로 확인했다** — `--rendering-driver opengl3` 로 1a 판정을 돌려 H1·H2·H7·H8(`rim_aa=16/32`)·H9 가 전부 통과했다. 데스크톱 Forward+ 의 `rim_aa` 는 13~18 이므로 엣지 품질도 같은 수준이다.

**스레드를 쓰지 않는 변형으로 내보낸다**(`variant/thread_support=false`). `SharedArrayBuffer` 를 안 쓰므로 `COOP`/`COEP` 헤더가 필요 없고, 헤더를 설정할 수 없는 정적 호스팅에서도 그대로 돈다.

**브라우저에서 확인한 결함 하나**: 웹 빌드에는 시스템 폰트 폴백이 없어 **HUD 의 한글이 전부 두부(□)로 깨졌다.** 데스크톱에서는 시스템 폰트가 받쳐 줘서 안 보이던 문제다. UI 문자열을 ASCII 로 바꿔 해결했다(`SCORE / SIZE / EATEN / # NAME SCORE SIZE / TIME UP / PRESS R TO RESTART`). 한글 UI 를 유지하려면 폰트를 번들해야 한다.

빌드 크기: `index.wasm` 39.5MB + `index.pck` 11.9MB (2026-07-30 CI 실측; rev.16 당시 37.7/11.2 에서 커졌다).

#### 자동배포 (2026-07-30)

**`main` 에 push 하면 Vercel 이 직접 export 해서 프로덕션을 갱신한다.** 그전까지는 로컬 export 후
`vercel --prod` 수동 실행이었고(직전 프로덕션 3건 전부 `source=cli`), 그래서 "빌드했지만 배포를
잊은 커밋"이 생길 수 있었다 — 실제로 카메라 수정 `c9a6c7a` 가 미배포 상태였다.

- 배선: Vercel 프로젝트 `hole-io-game` ↔ 이 저장소 연결, production branch = `main`.
- `vercel.json` → `buildCommand: bash scripts/vercel-build.sh`, `outputDirectory: build`.
- `scripts/vercel-build.sh` 가 빌드마다 Godot 을 내려받는다(Vercel 이미지에 Godot 이 없다).
  에디터 76MB + Web export template 88MB. 템플릿 번들 `.tpz` 전체는 1.22GB 인데 필요한 멤버만
  HTTP Range 로 뽑는다. 빌드 시간 약 24초.
- **엔진 핀**: `GODOT_VERSION=4.7.1-stable`. 스크립트가 `project.godot` 의 `config/features` 와
  같은 계열인지 검사하고 어긋나면 배포를 깬다. 로컬에서 상위 버전으로 열어 저장했다면
  `GODOT_VERSION`/`GODOT_TEMPLATE_DIR` 를 함께 올려야 한다.
- `build/` 는 계속 `.gitignore` 다. 산출물을 커밋하지 않는다.

**롤백** — 자동배포는 사람이 안 보고 있을 때 깨질 수 있으니 경로를 먼저 적어 둔다.

1. **즉시 복구**: Vercel 대시보드 → 프로젝트 → Deployments → 직전의 정상 프로덕션 배포 →
   *Promote to Production* (CLI 로는 `vercel promote <deployment-url>`). 과거 프로덕션 배포가
   `READY` 로 남아 있어 재빌드 없이 alias 만 옮긴다.
2. **원인 제거**: `git revert <sha> && git push` — push 가 곧 배포이므로 revert 가 곧 롤백이다.
3. **브랜치 선검증**: 위험한 변경은 브랜치로 push 하면 preview 배포가 생긴다. 단 preview URL 은
   팀 SSO 로 막혀 있어(`ssoProtection: all_except_custom_domains`) 브라우저 로그인 없이 확인하려면
   Protection Bypass 시크릿이 필요하다. 302 를 파이프라인 고장으로 오독하지 말 것.
   프로덕션 도메인 `hole-io-game-delta.vercel.app` 은 프로젝트 도메인이라 공개 상태다.


---

## §18. 도로 위계 — 대로 (구현·검증 완료, rev.17)

§17의 플레이 피드백 4번 "도로가 너무 격자"의 미해결분이다. 격자는 주기 32m로 **완전히 균질**했다 — 모든 도로가 같은 폭, 같은 중앙선, 같은 차선 수였다.

### 규격

**`k mod 3 == 0`인 중심선을 대로로 승격시킨다.** 아스팔트 반폭이 **선 인덱스의 함수**가 된다.

| 항목 | 일반 도로 | 대로 |
|---|---|---|
| 아스팔트 반폭 | 4.0 | **6.5** |
| 보도 폭 | 2.0 | 2.0 (등급과 무관하게 일정) |
| 보도 바깥 반폭 | 6.0 | **8.5** |
| 중앙선 | 중심선 위 한 줄 | **±0.75 두 줄** (사이 빈 간격 0.9) |
| 차선 자리 | 편도 1 (±2.0) | **편도 3** (±2.4125 / ±3.775 / ±5.1375) |

지면 ±224(인덱스 k = -7..7)에서 대로는 k = -6, -3, 0, 3, 6 → **x·z = 0, ±96, ±192 각 다섯 줄**. 대로끼리 인접하지 않으므로 소멸하는 블록은 없다.

### 뒤집은 결정 — "4번째"에서 3번째로

rev.16이 기록한 계획은 **4번째** 중심선마다였다. 게임 시야는 구멍 기준 약 55m인데 4번째는 주기 128m라 **지도의 절반 이상에서 대로가 화면에 한 번도 안 들어온다** — 균질한 격자를 깨는 것이 목적인데 절반만 달성한다. 3번째(96m)면 도로의 1/3이 대로가 된다. `BOULEVARD_EVERY` 상수 하나이므로 플레이 후 재조정 가능하다 — **단 판정 지점 `boul_far`가 인덱스 3을 보므로 값을 바꾸면 그 지점도 함께 옮겨야 한다.**

### 인덱스 정의를 세 파일에서 하나로

셰이더가 `k = floor((p + hp) / pitch)`로 뽑으므로 GDScript도 **같은 식**(`floori(w / PITCH + 0.5)`)을 쓴다. `roundi(w / PITCH)`는 안 된다 — round는 0.5를 0에서 멀어지게 반올림해 **블록 정중앙의 음수 쪽**(w = -16, -48 …)에서 한 칸 어긋나고, 그러면 두 규격이 **서로 다른 선을 대로로 그린다**. `zone_of`의 기존 `round(c.x / SPEC_PITCH)`도 함께 교체했다.

GLSL `mod`는 음수 인덱스에서도 `[0, n)`을 돌려주므로 `posmod`와 같은 집합 `{…, -6, -3, 0, 3, 6, …}`을 만든다. 이 일치가 규격의 전제다.

### 셰이더 — `abs()`를 aa_band에 넘기지 않는다

대로의 두 줄은 `max(aa_band(u - gap, ·), aa_band(u + gap, ·))`로 그린다. `aa_band(abs(u) - gap, ·)`로 쓰면 **`abs`의 꺾임점(= 대로 한가운데)에서 `fwidth`가 튀어 1픽셀 얼룩**이 생긴다 — §4-A가 이미 같은 이유로 경고하던 것이다.

`ux = p.x - kx·pitch`는 옛 `mod(p.x + hp, pitch) - hp`와 **항등**이다(음수 좌표 포함): `mod(a,P) - hp = a - P·floor(a/P) - hp`에 `a = p.x + hp`를 넣으면 `p.x - P·floor((p.x+hp)/P)`. 인덱스를 따로 꺼내는 이유는 반폭이 그 함수이기 때문이다.

### 차량 실측 — 대로 2차선에는 버스가 안 들어간다

OBJ 정점에서 직접 잰 값(스케일 반영):

| 에셋 | 폭반값 | 길이반값 |
|---|---|---|
| SchoolBus | **1.73** | 4.24 |
| Bus | **1.71** | 4.00 |
| Ambulance | 1.49 | 3.00 |
| SUV | 1.06 | 2.10 |
| 승용차 6종 | 0.82~0.94 | 1.65~2.11 |

대로 편도 주행 띠는 `[median, 6.5]` = [1.05, 6.5], 폭 5.45다. 이것을 **2차선으로 등분하면 차선 반폭이 1.3625**로 일반 도로의 유효 반폭 2.0보다 **좁아진다** — 가장 넓은 도로가 가장 큰 차를 거절하는 규격 오류다.

대신 띠를 4등분한 **세 지점**을 둔다. 허용 반extent = `min(u - median, r - u)`:

| 자리 | 오프셋 | 허용 반extent | 들어가는 것 |
|---|---|---|---|
| **가운데** | 3.775 | **2.725** | 버스·스쿨버스·구급차 |
| 안쪽 | 2.4125 | 1.3625 | 승용차·SUV |
| 바깥 | 5.1375 | 1.3625 | 승용차·SUV |

**순서와 `min_ext`가 핵심이다.** `fits()`는 이웃 자리(간격 1.3625)를 항상 배제하므로, 가운데를 나중에 시도하면 45% 확률로 소형차가 먼저 차지하고 버스는 24.75%로 떨어진다 — 일반 도로(45%)보다 드물어져 이 설계의 논거가 뒤집힌다. **가운데를 먼저 시도하고 `min_ext = 2.5`를 걸어 큰 차 전용으로 둔다**(`plan_block`의 `min_ext 3.5`와 같은 근거·같은 도구). 가운데가 비면 안쪽과 바깥이 둘 다 들어간다(간격 2.725).

일반 도로는 `[0, 4.0]`을 2등분 → **±2.0 = 옛 `LANE_U`와 같은 값. 회귀 없음.**

### 새 배치 규칙 둘 — 그리고 그 각각에 붙인 판정

**① 중앙 분리대 하한.** 기존 `in_zone("road")`은 상한만 봤다. 대로에서 그것만 두면 안쪽 자리의 차가 반extent 4.09까지 허용되어 **이중 중앙선을 넘어 반대 차선까지 뻗는다.** `|u| - ex ≥ median(k)`를 추가했다. 일반 도로는 median = 0이라 기존과 완전히 동일하다.

**② 교차로·횡단보도 클리어런스.** 자리 **중심**만 교차로 밖으로 빼는 방식은 차체 길이를 무시한다 — t=7.5에 스쿨버스(반길이 4.24)를 세우면 교차 중심선까지 4.26m로 **차체가 대로 교차로 위에 남는다.** 그래서 프롭의 **실제 extent**로 잰다: `u_cross - ex_cross ≥ r_cross + 1.6`.

이 규칙은 **일반 도로에도 소급 적용된다.** 옛 자리 `t = ±10`은 교차선까지 6.0뿐이라 버스가 **이미 일반 교차로 안에 서 있었다** — 선재 결함이었고 어떤 기준도 잡지 않았다. 자리를 `{±8, ±3.5}`(일반) / `{±5, ±2.5}`(대로 교차)로 당겼다.

**두 규칙 모두 판정기의 `zone_of`에 독립 사본을 넣었다.** 넣지 않으면 그 규칙을 지운 빌드를 아무도 안 잡는다 — 이 프로젝트가 여섯 번 밟은 함정과 같은 형태다. 고장 주입 #9·#10이 각각 E2에서 248개·149개의 구역 이탈로 걸린다.

### 판정기가 부풀린 값을 재고 있었다 — `lane_width_px`

`LANE_MIN_PX` 필터는 중앙선을 가로지르는 두 점의 **화면 2D 거리**를 폭으로 썼다. 표본 블록이 카메라 x에서 벗어나면 그 변위에 **소실점 방향 성분(= 선을 따라가는 성분)**이 섞여 폭이 부풀려진다.

| 블록 | 카메라 x에서 | 옛 `lanepx` | 직교 성분 |
|---|---|---|---|
| b(-16,-16) | 0m (축상) | 3.1 | 3.0 |
| b(-48,-16) | 32m | **6.2** | **3.0** |

즉 **필터가 가드로 작동하지 않았다** — 뭉개진 중앙선을 가진 블록을 그대로 통과시킨다. 선 방향을 화면에서 직접 구해 **직교 성분만** 재도록 고쳤다.

고치자 기존 지점의 후보가 전부 2.99px로 탈락했다(정상 빌드가 FAIL). **`LANE_MIN_PX`가 부풀려진 값 기준으로 잡힌 상수였기 때문이다.** 실측 두 점으로 재보정했다: §12가 기록한 "뭉개져 판독 불가"는 2.3px이고, 2.8px에서 셰이더 `fade`는 0.41이라 중앙선 휘도가 아스팔트보다 0.17 높다(`SURF_DIFF_MIN` 0.05의 3.4배). → **3.0 → 2.8.**

### 중앙선 휘도는 선분의 최대값 — 단 선분을 넓히면 안 된다

점 표본은 `px()`의 반올림(±0.5px)에 흔들린다. 줄 안을 훑는 짧은 선분의 최대값으로 바꿨다.

**처음에 ±0.6m로 잡았다가 고장을 통과시켰다.** 대로 표본(`|u| = 0.75`)의 선분이 `|u| ∈ [0.15, 1.35]`까지 뻗어 **일반 중앙선 한 줄(`[-0.3, 0.3]`)의 가장자리를 주웠고**, 대로에 한 줄만 그린 빌드가 D1을 그대로 통과했다(실측: 주입 #2가 PASS). ±0.15m로 좁히자 선분이 `[0.60, 0.90]`이 되어 그 줄에서 1.6px 떨어진다 — 규격대로 아스팔트를 읽고 주입 #2가 `lane = 0.4191 = road`로 탈락한다.

### 신규 기준 D6 · E7

**D6 — 대로가 실제로 표본됐는가(커버리지 가드).** `probe_blocks`는 `sz`를 `[-1, +1]` 순으로 시도해 처음 유효한 하나에서 멈추고 `judge_city`는 거리순 상위 2개만 본다. **대로를 한 번도 표본하지 않은 채 D1이 PASS할 수 있고**, 그러면 위계에 관한 모든 고장 주입이 조건부가 된다. 오늘의 고장이 아니라 **내일의 커버리지 소실**을 막는 기준이다.

**E7 — 위계가 배치에도 반영됐는가.** `zone_of`는 카탈로그 zone을 안 읽으므로, `walk_center_at`·`lane_slots`를 상수로 되돌린 빌드는 프롭이 규격 밖이 되어 `add_slot`이 조용히 거절할 뿐 **어떤 기준도 안 걸린다**(총 프롭 수만 줄고 그건 `RESTART_PROPS` 갱신에 묻힌다). 개수 하한만으로도 부족하다 — 자리 하나를 빼는 회귀는 비율로 안 걸린다.

- **E7a**: 대로 위에 온전히 들어간 프롭이 하한 이상 있는가. 위계를 배치에서 지우면 0이 된다. 실측 road 764 / walk 645 → 하한 230 / 320. **차도에 `|u| > 4.0` 게이트를 걸면 안 된다** — 안쪽 자리 차량은 median 1.05 제약 때문에 최대 `|u|`가 3.775라 그 게이트에 걸려 사라지고, 그러면 안쪽 자리를 통째로 지워도 아무 기준이 안 걸린다(코드 감사가 잡았다).
- **E7b**: 대로 차도의 **규격 자리 셋(안쪽 2.4125 · 가운데 3.775 · 바깥 5.1375)이 전부 쓰였는가.** 프롭 중심의 `|u|`가 어느 규격 자리에 가장 가까운가로 매긴다. 자리를 지우는 회귀는 개수 비율로는 안 걸린다 — 구조로 물어야 한다. 판정기는 구현체의 `lane_slots`를 읽지 않고 `[median, road_half]`를 4등분해 자리를 직접 낸다.

### 판정 지점 — 실측으로 확정했다

이 작업의 계획은 두 번 감사에서 불합격했고(70점·63점), **실패의 원인은 매번 같았다: 지점이 무엇을 표본하는지 모른 채 좌표를 적었다.** 그래서 좌표를 계산으로 정하지 않고 로그에 등급·인덱스·직교 lanepx를 찍어 **읽어서** 확정했다.

| 지점 | 좌표 | 표본한 블록 | 도로 | lanepx |
|---|---|---|---|---|
| `inter` | (-32, 0, 32) | (-48,16) (-16,16) | k=1 일반 | 7.6 |
| `road` | (-32, 0, 16) | (-48,16) (-16,16) | **k=0 대로** | 3.2 |
| `block` | (-16, 0, 16) | (-16,-16) (-48,-16) | **k=0 대로** | 3.0 |
| `boul_far` | (0, 0, 112) | (-16,112) (16,112) | **k=3 대로** | 3.2 |

- `boul_far`는 **인덱스 3**을 본다. 인덱스 0은 `every=3`으로도 `every=4`로도 대로라 **위상 어긋남을 검출하지 못한다** — 주입 #3이 걸리는 것은 오직 이 지점 덕이다. 구멍이 x=0 대로 위에 있어 D5도 겸한다.
- 시도했다 버린 지점: **(-48, 0, 24)** — 대로가 40.5m로 멀어 축상 블록이 2.2px로 탈락. **(-48, 0, 16)** — 구멍이 블록 **정중앙**이라 블록 표본이 구멍과 겹쳐 "구멍근접"으로 전부 탈락. **(0, 0, 120)** — 인덱스 3 대로 대신 z=128 일반 도로를 표본.

### 고장 주입 11종 — 전부 검출

| # | 주입 | 잡은 기준 |
|---|---|---|
| 1 | 셰이더 `boul_half` 6.5 → 4.0 (위계 소거) | D1(보도 표본이 잔디) + D6 |
| 2 | 셰이더가 대로에도 중앙선 한 줄만 | D1(`lane = road = 0.4191`) + D6 |
| 3 | 셰이더 `boul_every` 3 → 4 (위상 어긋남) | D1 @ `boul_far` |
| 4 | 판정기의 `spec_road_half`만 상수로 | D1 + D6 — **판정기가 구현체를 안 믿는 증거** |
| 5 | `city.gd` `curb_half_at` 상수 | E2 (구역 이탈 262) + E7 |
| 6 | `walk_center_at` 상수 | **E7a만** (walk 645 → 153). E2는 통과한다 |
| 7 | `lane_slots` 위계 소거 | **E7b만** (차선자리 [0] 하나) |
| 8 | 대로 차선이 가운데 자리 하나뿐 | **E7b** (차선자리 [1]) |
| 9 | 중앙 분리대 하한 제거 | E2 (248) |
| 10 | 교차로 클리어런스 제거 | E2 (149) |
| 11 | 판정기가 대로를 모름(`spec_is_boulevard = false`) | D1 + D6 |
| 12 | 대로 중앙을 **폭 2.1m 통짜 노란 띠**로 (감사자가 만든 주입) | D1(`분리대 = lane`) + D6 |
| 13 | 대로 차선에서 **안쪽 자리 두 줄만** 제거 | **E7b** (차선자리 [1, 2]) |

**6·7·8·13은 E2가 통과하고 E7만 잡는다** — E7을 만든 이유가 정확히 그 사각이었다. **12·13은 코드 감사가 드러낸 위약을 메운 뒤에야 탈락한다** — 그전에는 둘 다 8종 전부를 통과했다.

누적 고장 주입 **56종**.

### 계측

| 항목 | 전(rev.16) | 후 |
|---|---|---|
| 프롭 수 | 3832 | **3804** |
| 구역 분포 (차도/보도/블록) | 1265 / 1372 / 1195 | **1454 / 1393 / 957** |
| 대로 전용 자리 (차도/보도) | — | **764 / 645** |
| 프레임 시간 (dense 지점) | 2.04ms (489fps) | **2.04ms (491fps)**, 예산의 12% |
| 드로우콜 (dense 지점) | 2251 | **2535** |
| 프레임 시간 (boul 지점) | — | 1.78ms (561fps) |
| 드로우콜 (boul 지점) | — | 2510 |

차도가 는 것은 대로에 자리가 세 배로 늘었기 때문이고, 블록이 준 것은 대로 인접 블록이 편당 2.5m 좁아졌기 때문이다.

**성능 지점을 갈아치우지 않고 둘로 늘렸다.** 처음에는 `PERF_SPOT`을 (-48,-48) → (-48,-80)으로 **옮기고** "구 지점은 대로에 안 접해 늘어난 밀도를 못 본다"고 적었다. 독립 감사가 실측으로 반증했다 — **구 지점이 드로우콜·프리미티브 모두 더 많다**(2535 / 2.70M 대 2510 / 2.29M). 대로 주변은 밀도가 아니라 **가려짐이 적어** 그리기 부담이 몰리는 지점이다.

더 나쁜 것은, 지점을 옮기면서 계측표를 옛 지점 값과 나란히 놓아 **"드로우콜 2251 → 2510"이라는 성립하지 않는 증감**을 적었다는 것이다. 같은 지점 기준이면 2251 → **2535**(+12.6%)다. 지금은 `PERF_SPOTS` 둘을 다 재고 **둘 다 예산 안이어야 통과**한다 — 역대 계측과의 like-for-like 비교(`dense`)와 대로 커버리지(`boul`)를 동시에 얻는다.

### 남긴 한계

- **대형 건물**: 대로 인접 블록의 사용 가능 반폭은 7.95다(일반-일반은 9.2). `Building1_Large`(긴 축 반extent 7.99)만 0.04 초과하나 90° 회전 후보가 있어 배치된다. 소실 없음.
- **부동소수 경계**: 바깥 차선 `5.1375 + 1.3625 == 6.5` 같은 정확 등호가 `<=`에서 뒤집힐 수 있다. 기존 코드도 같은 성질이었고(`2.0 + 2.0 <= 4.0`) 결과는 안정적이다.
- **광장 통과**: x=0, z=0 대로가 판정 광장(r=26)을 통과한다. 광장에는 프롭이 없어 배치에는 영향이 없고, 플레이어는 대로 교차점에서 시작한다.
- **E7a의 개수 하한은 부분 회귀를 못 잡는다.** 주입 #8은 개수로는 road 223 대 하한 230으로 3% 차이였다 — 결정적인 것은 E7b(차선 자리 구조)다. 개수 하한은 "위계가 통째로 사라졌는가"(그때 0이 된다)용으로만 믿는다.
- **`plan_block`의 산포 반경 8.5는 `block_span`에서 유도하지 않는다.** 대로 인접 블록의 사용 가능 반폭은 7.95이므로 축당 약 6.5%의 시도가 확정 거절된다. `add_slot`이 거르므로 결함은 아니지만, `min(8.5, span/2)`로 유도하는 편이 근본적이다. 배치를 다시 흔들고 전 수치를 재측정할 값어치가 지금은 없다고 판단해 남긴다.
- **웹(gl_compatibility)에서 새 셰이더는 재익스포트로만 확인했다.** `check_pipeline()`이 `forward_plus`를 단언하므로 판정기는 Compatibility 경로를 보지 않는다. 새로 쓴 GLSL은 `mod`/`floor`/`mix`/`step`뿐이고 `ux = p.x − kx·pitch`의 수치 범위도 옛 `mod` 식과 같아 위험은 낮지만, **기계 판정은 0회**다.

### 이번에도 코드 감사가 위약을 하나 잡았다

**"이중 중앙선"이라는 규격의 정의가 검증되지 않고 있었다.** D1은 `|u| = 0.75`에 도색이 있는지만 봤으므로, 대로 중앙을 **폭 2.1m 통짜 노란 띠**(`aa_band(ux, lane_gap + lane_half)`)로 칠한 빌드가 판정 8종을 전부 통과했다 — 감사자가 실제로 주입해 보였다. 중앙선 휘도가 0.7203 → 0.8434로 **올라가** D1을 더 여유 있게 넘긴다.

두 줄 **사이**가 아스팔트라는 것이 `median_at = 1.05`(차량이 넘지 못하는 경계)의 렌더 근거다. 규격이 주장하는 것을 판정기가 안 읽고 있었던 것이다. D1에 대로 전용 조건을 넣었다: `|u| = 0`의 휘도가 아스팔트와 같고(`< SURF_DIFF_MIN`) 중앙선과 달라야(`≥ SURF_DIFF_MIN`) 한다. 주입은 이제 `분리대 = 0.8434 = lane`으로 탈락한다.

**같은 감사에서 E7의 대역 판정도 반쪽이었다.** 게이트 `az.y > SPEC_ROAD_HALF`가 안쪽 자리(2.4125) 차량을 통째로 배제하고 있었다 — median 1.05 제약 때문에 그 자리 차량의 최대 `|u|`는 3.775 < 4.0이다. 그래서 **안쪽 자리 두 줄을 지워도 아무 기준이 안 걸렸다.** 게이트를 없애고(대로 위에 온전히 들어갔는가로 충분하다) 대역을 **규격 자리 셋 중 최근접**으로 매기도록 바꿨다. 대로 차도 프롭이 472 → 764로 늘어난 것이 안쪽 자리가 비로소 보인다는 뜻이다.

---

## §19. 나무 흡입의 마찰감 — 수관 걸림 (구현·검증 완료, rev.18)

§17의 7번(“나무가 안 먹힘”)을 콜라이더를 **밑동** 기준으로 바꿔 고쳤는데, 유저의 다음 피드백은 정반대였다: **“가지가 걸려 좌우로 움직이면 먹히는 원작 느낌이 없다. 너무 쉽게 삼켜진다.”** §17은 나무를 “가지 폭 8.8m짜리 통짜 덩어리”에서 “밑동 폭짜리 기둥”으로 바꿨고, 그 과정에서 수관이 물리 모형에서 **완전히 사라졌다**.

### 규격

수관은 콜라이더가 아니라 **데이터**로 되살린다. 콜라이더를 둘로 나누는 안(밑동=게이트용 + 수관=물리용)은 채택하지 않았다 — **지면에는 물리적 구멍이 없다.** 지면은 평평한 StaticBody이고 구멍은 셰이더의 착시 + 기하 조건이므로, 수관 셰이프를 붙여도 걸릴 림 자체가 없다. 걸림은 통과 조건에서 모형화해야 한다.

- `swallowable.radius` = **밑동** XZ 외접반경(콜라이더에서). 크기 게이트·성장·점수는 전부 그대로 이것을 쓴다.
- `swallowable.snag_radius` = **수관** XZ 외접반경(**보이는 메시**에서). 밑동보다 작을 수 없다.
- 걸림 상태 `is_snagged` = `수관 > 구멍 반경` **그리고** `d + 밑동 < R`. 즉 **밑동은 이미 들어왔는데 가지가 구멍보다 넓어 림에 얹힌** 상태다.
- 통과 조건이 `d + radius < R`에서 `d + pass_radius(rb) < R`로 바뀐다.
- 걸린 동안 흡입력에 `snag_drag`(0.6)를 곱하고, **수평 속력을 `snag_speed`(1.0 m/s)로 깎는다.**

```gdscript
## 오브젝트의 수관 반경(밑동보다 작을 수 없다).
func snag_of(rb: RigidBody3D) -> float:
	return maxf(float(rb.snag_radius), float(rb.radius))


## 걸림 상태인가 — **수관이 구멍보다 넓고**(가지가 림에 얹힐 수 있고),
## **밑동은 이미 구멍 안에 들어와 있다**(옛 규격이라면 벌써 삼켜졌을 자리다).
## 수관 = 밑동인 오브젝트에서는 두 조건이 서로 모순이라 절대 참이 되지 않는다 —
## 상자·건물·차량의 거동이 §17 과 완전히 같다는 것이 이 정의에서 바로 나온다.
func is_snagged(rb: RigidBody3D, d: float) -> bool:
	return snag_of(rb) > radius and d + float(rb.radius) < radius


## 통과 조건에 쓰는 유효 반경. 밑동과 수관 사이 어딘가다.
##
## 걸림의 세기는 **수관이 림 밖으로 얼마나 나가 있는가**에 비례해야 한다. 절대량으로
## 두면(= grip 만 곱하면) 구멍이 아무리 커져도 같은 거리만큼 갈리고, 원작에서 큰
## 구멍이 나무를 즉시 삼키는 것과 어긋난다. 구멍이 수관보다 넓어지면 ov = 0 이 되어
## 걸림이 스스로 사라진다.
func pass_radius(rb: RigidBody3D) -> float:
	var s := snag_of(rb)
	if s <= radius:
		return float(rb.radius)               # 구멍이 수관보다 넓다 — 걸릴 것이 없다
	var ov: float = (s - radius) / s          # 수관의 림 밖 초과분 (0..1)
	var eff: float = float(rb.radius) + (s - float(rb.radius)) * snag_grip * ov
	return maxf(float(rb.radius), minf(eff, radius * snag_cap))
```

### 이 모형이 가진 세 가지 성질

1. **무캐노피 오브젝트에는 아무 일도 일어나지 않는다.** `수관 = 밑동`이면 `is_snagged`의 두 조건이 서로 모순이고(`d + r < R`이면서 `r > R`일 수 없다), `pass_radius`도 `s ≤ radius` 분기에서 밑동을 그대로 돌려준다. 상자·건물·차량의 거동이 §17과 **바이트 단위로 같다**는 것이 회귀 위험을 없앤다 — 실제로 1b·2·4·5 판정이 값 하나 안 바뀌고 통과했다.
2. **구멍이 자라면 걸림이 스스로 사라진다.** `ov = (수관 − R) / 수관`이므로 구멍이 수관보다 넓어지는 순간 0이다. grip만 곱하는(절대량) 모형은 구멍이 아무리 커져도 같은 거리를 갈아, 원작과 어긋난다.
3. **중심에 오면 반드시 삼켜진다.** `snag_cap = 0.85`가 유효반경을 `0.85R`로 자른다. 이 상한이 없으면 “게이트는 열렸는데 영원히 안 먹히는 오브젝트”가 생긴다 — §4-D-2가 경고한 그 실패다.

### 왜 힘을 줄이는 것만으로는 부족했나

처음에는 걸린 동안 흡입력만 0.6배로 줄이고 선형 감쇠(5.0)를 걸었다. 정지 상태에서 시작한 나무는 86프레임을 갈렸지만, **흡입으로 가속돼 들어온 나무는 7프레임 만에 통과했다.** 오브젝트는 구멍에 닿기 전에 이미 9~13 m/s까지 가속돼 있어서, 감속으로는 관성을 못 이긴다.

가지가 림에 걸린다는 것은 **힘의 문제가 아니라 “얼마나 빨리 들어갈 수 있는가”의 상한**이다. 수평 속력을 직접 깎자 두 경우가 90 / 38프레임으로 나란해졌다. 수직 성분은 건드리지 않는다 — 가지가 막는 것은 미끄러져 들어가는 것이지 떨어지는 것이 아니다.

### 에셋 실측 — 걸리는 것은 나무 넷뿐이다

밑동 반경(콜라이더)과 수관 반경(메시)을 카탈로그 48종에서 직접 쟀다(일회용 계측 스크립트, 비율 내림차순 상위):

| 에셋 | 밑동 r | 수관 s | s/r | 게이트가 열리는 R (= r/0.45) |
|---|---|---|---|---|
| TrafficSign1 / 2 | 0.072 | 0.382 | 5.31 | 0.16 |
| **Tree3** | **0.821** | **3.340** | **4.07** | **1.83** |
| Bush3 / Bush2 | 0.164 | 0.641 | 3.92 | 0.36 |
| **Tree2** | 1.258 | 4.231 | 3.36 | 2.80 |
| **Tree1** | 0.891 | 2.725 | 3.06 | 1.98 |
| **Tree4** | 1.672 | 4.405 | 2.64 | 3.72 |
| Bush1 | 0.341 | 0.760 | 2.23 | 0.76 |
| Streetlight_Double | 0.687 | 1.249 | 1.82 | 1.53 |
| Shop | 3.919 | 4.593 | 1.17 | 8.71 |
| 건물 일반 | — | — | 1.03~1.12 | 6~18 |

걸림이 성립하려면 **수관 > 현재 구멍 반경**이어야 한다. 시작 반경이 1.5이므로 표지판·덤불(수관 0.38~0.76)은 처음부터 걸릴 일이 없고, **실제로 걸리는 것은 수관 2.7~4.4인 나무 넷**이다 — 유저가 지적한 바로 그 대상이다. 건물은 비율 1.1 안팎이라 애초에 대상이 아니다.

### 판정 — `--judge6` (신설, 기준 K1~K6)

시행 일곱 번. 구멍은 **가만히 두고** 픽스처 하나만 놓아, 밑동이 구멍 안에 들어온 프레임(`fit`)부터 낙하 전환(`conv`)까지 몇 프레임 갈리는지(`delay`)를 잰다.

- **K1 마찰 존재** — 정지 시작한 수관 프롭이 `SNAG_MIN_STILL`(45) 이상 갈린다.
- **K2 관성에도 걸린다** — 감지 범위 가장자리에서 흡입 가속을 받고 들어온 수관 프롭이 `SNAG_MIN_RUSH`(19) 이상 갈린다.
- **K3 무캐노피 불변** — 수관 = 밑동인 프롭은 지연 ≤ 3프레임이고 전환 마진이 유도 상한 안이다.
- **K4 규격 일치** — 전환 순간이 판정기가 **따로 든** `SPEC_SNAG_GRIP`·`SPEC_SNAG_CAP`으로 계산한 유효반경과 맞는다.
- **K5 마찰 소멸** — 구멍이 수관보다 넓으면 수관 프롭도 무캐노피처럼 즉시 전환된다.
- **K6 해소 보장** — 걸린 것은 예산(600프레임) 안에 반드시 전환된다.

| 시행 | R | 밑동 | 수관 | 규격 유효반경 | delay | spec_margin (상한) |
|---|---|---|---|---|---|---|
| still_plain | 1.90 | 0.821 | 0.821 | 0.821 | 1 | 0.100 (0.127) |
| **still_canopy** | 1.90 | 0.821 | 3.340 | 1.310 | **90** | 0.006 (0.144) |
| rush_plain | 1.90 | 0.821 | 0.821 | 0.821 | 1 | 0.142 (0.309) |
| **rush_canopy** | 1.90 | 0.821 | 3.340 | 1.310 | **38** | 0.002 (0.144) |
| big_plain | 6.00 | 0.821 | 0.821 | 0.821 | 1 | 0.100 (0.127) |
| **big_canopy** | 6.00 | 0.821 | 3.340 | 0.821 | **1** | 0.100 (0.127) |
| extreme | 1.90 | 0.821 | 11.000 | 1.615 (상한) | 115 | 0.004 (0.144) |

정지한 나무는 **1.5초**, 흡입으로 밀려 들어온 나무는 **0.63초** 갈린다. 플레이어가 구멍을 움직이면 `d`가 초속 14로 줄어드니 그만큼 빨리 삼켜진다 — 이것이 “좌우로 움직이면 먹힌다”의 실체다.

### 3b 판정에 E8 신설 — 걸림 모형에 입력이 실제로 있는가

판정기가 도시 프롭 3804개를 훑으며 두 가지를 묻는다.
- `snag_radius`가 **보이는 메시**에서 나왔는가 (판정기가 `mi.mesh.get_aabb()`로 직접 재서 대조, 허용 오차 0.01)
- 수관/밑동 ≥ 1.5인 프롭이 `MIN_CANOPY_PROPS`(475 = 실측 951의 절반) 이상인가

두 번째가 **§17 이전으로 되돌아가는 회귀를 잡는 유일한 기준**이다. 콜라이더를 다시 메시 전체 AABB로 만들면 밑동 = 수관이 되어 걸림이 **조용히** 사라진다 — 개수가 0이 된다.

### 판정기가 스스로 만든 함정 둘

**① 시나리오가 구멍을 자라게 하고 있었다.** R=12 시행에서 광장의 판정 대상 8개가 함께 삼켜졌고, **그 낙하가 다음 시행 도중에 소멸에 도달해** 구멍이 4.00 → 4.77로 자랐다. 판정기의 규격 계산은 4.00 기준이라 정상 빌드가 K4에서 떨어졌다. 시행 전에 `judge_set`을 치우고, 전환 순간의 반경이 설정값과 같은지도 K4가 함께 단언한다.

**② 픽스처 치수가 오브젝트 반경이 아니었다.** 처음에는 §17 표의 “1.8 / 7.4”를 픽스처의 밑동·수관으로 썼는데, 그 둘은 **먹는 데 필요한 구멍 반경**(= r / 0.45)이다. 비율(4.07)은 우연히 같았지만 절대 치수가 2.22배였고, **절대 속력 상한이 걸린 시간을 정하는 이 모형에서는 실제보다 2.2배 긴 마찰을 재고 있었다.** 판정은 출시되는 치수(Tree3의 0.821 / 3.340)로 해야 한다.

**③ 고정 허용치가 우연에 기대고 있었다.** 전환 마진의 상한을 고정 0.30으로 두었더니 grip을 2배로 주입한 빌드가 0.309로 **간신히** 걸렸다. 판정이 아니라 우연이다. 상한을 시행에서 유도하도록 바꿨다 — `시작 여유(0.1) + 한 프레임 이동(v/60) + 0.02`. 같은 주입이 이제 0.144 대 0.309로 갈린다.

### 고장 주입 7종 — 전부 검출

| # | 주입 | 걸린 기준 |
|---|---|---|
| 1 | `pass_radius`가 밑동을 그대로 반환 (걸림 모형 제거) | K1·K2·K4 |
| 2 | 속력 상한 제거 (힘만 0.6배) | K1(34<45)·K2(4<19) |
| 3 | `snag_cap` 0.85 → 10.0 (상한 제거) | K6 (extreme이 600프레임 내내 안 먹힘) |
| 4 | `snag_grip` 0.45 → 0.90 | K4 (마진 0.309 대 상한 0.144) |
| 5 | 모든 오브젝트에 가짜 수관(`radius × 1.5`) | 3b E8 (불일치 2853) |
| 6 | `snag_radius = radius` (수관 폐기) | K1·K2·K4 + 3b E8 (불일치 2792, 수관프롭 0) |
| 7 | 콜라이더를 메시 전체 AABB로 (§17 이전으로 회귀) | 3b E8 (수관프롭 0, 불일치는 0) |

주입 5가 `--judge6`을 통과하는 것은 설계대로다: 가짜 수관 1.5배는 구멍(1.9)보다 작아 `ov = 0`이라 모형이 정상적으로 아무 일도 하지 않는다. **“수관 값이 어디서 왔는가”는 도시 전체를 보는 E8이 묻고, “그 값으로 무엇을 하는가”는 K1~K6이 묻는다.**

### 회귀

판정 **아홉 종 전부 PASS**(`--judge` / `1b` / `2` / `3` / `3b` / `3c` / `4` / `5` / `6`). 3c 성능은 dense 1.95ms(512fps) · boul 1.80ms(554fps)로 예산의 12% — 걸림 계산은 후보 오브젝트당 곱셈 몇 번이라 계측에 나타나지 않는다.

### 남긴 한계

- **걸린 나무는 기울지 않는다.** 밑동이 구멍 안에 들어온 채 y=0에 서 있으므로, 수관이 림에 얹혀 버틴다는 설정이 **시각적으로는** 나무가 우물 위에 떠 있는 것으로 보인다. 수관이 구멍보다 훨씬 넓어(3.34 대 1.9) 실제로 걸쳐 있는 모습이라 읽히지만, 원작의 기울어짐(tilt)은 없다. 토크를 주는 안이 있으나 §13이 지킨 “도시는 스스로 움직이지 않는다”(E5)와 충돌하므로 손대지 않았다.
- **`snag_speed`는 절대 속력이라 스케일에 따라 체감이 달라진다.** 큰 나무는 갈리는 거리가 길어 더 오래 걸린다(Tree4는 걸림 구간 자체가 좁아 거의 안 걸린다). 오브젝트 크기에 비례하는 상한이 더 근본적이나, 실제로 걸리는 것이 나무 넷뿐이고 그 치수 폭이 좁아 값어치가 없다고 판단했다.
- **`snag_grip` 0.45 / `snag_speed` 1.0은 플레이로 검증한 값이 아니다.** 기계 판정은 “걸림이 존재하고, 해소되고, 무캐노피에 영향이 없다”만 보증한다. 체감이 과하거나 모자라면 이 둘만 조정하면 된다 — 판정 기준은 실측에서 유도하므로 값을 바꾸면 `SPEC_SNAG_GRIP`과 `SNAG_MIN_*`도 함께 옮겨야 한다.
- **독립 감사(Agent)는 이번에 돌리지 않았다.** 유저가 감사 라운드보다 진행을 우선한다고 밝혔고, 대신 기준 6종 신설 + 고장 주입 7종으로 자체 검증했다.

---

## §20. 판정 픽스처를 게임에서 걷어냈다 (구현·검증 완료, rev.19)

노랑·파랑 큐브 8개(`S0`~`S5`, `B0`·`B1`)가 광장에 서서 **시작 화면에 그대로 보였다.** 도시 에셋과 이질적이고, 게임의 일부가 아니라 **1a의 스케일 기준용 픽스처**다. §17이 같은 이유로 `RefBox`를 지웠는데, 그때 이 8개는 남겨 뒀다 — 1b·2·3b·5 판정의 시나리오가 통째로 이것들 위에 서 있기 때문이다.

### 지우는 대신 판정 모드에만 존재하게 했다

- `main.tscn`에서 8개를 들어내고, 자리·씬 경로를 `main.gd`의 `JUDGE_SET` 상수로 옮겼다.
- `spawn_judge_set()`은 **`judging`이 아니면 빈손으로 돌아간다.** `Judge._ready`가 `Main._ready`보다 먼저(자식 → 부모) 플래그를 세우므로 `_ready`에서 읽을 수 있고, 판정 플래그 없이 실행하면 픽스처가 아예 생기지 않는다.
- `_ready`와 `restart()`가 **같은 함수**를 부른다. 둘 중 하나만 조건을 걸면 "게임에는 없는데 재시작하면 나타난다"가 된다.
- 치수와 자리는 한 톨도 안 바꿨다. C2가 "소형 6개를 다 먹어야 대형의 게이트가 열린다"(R 5 → 6.73, 게이트 3.03 > 대형 r 2.83)를 시험하고, B1의 `MOVED_TO`가 이것들에서 멀다는 전제 위에 서 있다.

**메시만 도시 에셋으로 갈아 끼우는 안은 버렸다.** 픽스처는 2.6·4.0 정육면체인데 그 치수에 맞는 도시 모델이 없어 스케일이 일그러지고, 더 나쁜 것은 **§19의 수관이 생긴다**는 점이다 — 메시가 콜라이더보다 넓어지는 순간 그 픽스처에 걸림이 붙어 1b·2의 흡입 시간이 달라진다. 보이지 않게 하는 편이 시나리오를 건드리지 않는다.

### T7 — 두 갈래 회귀를 각각 막는다

| 회귀 경로 | 판정 |
|---|---|
| 편집기에서 씬에 다시 놓는다 | `main.tscn`을 **파일로 열어**(`PackedScene.get_state()`) `Swallowables` 아래 노드 수를 센다 |
| 스폰 조건을 없앤다 | `judging = false`로 재시작해 픽스처가 0인지 본다. **도시 프롭은 3804 그대로**여야 한다 |

실행 중의 노드를 세는 것으로는 첫 번째를 영원히 못 잡는다 — 판정 모드에서는 스폰된 8개와 구별할 수 없고, `restart()`가 `Swallowables`의 자식을 전부 비우고 다시 세우므로 **씬에 놓인 것은 재시작 한 번에 사라진다.** 파일을 읽어야 한다.

T5의 전제도 함께 옮겼다: T5는 **판정 모드의** 재시작을 보므로, 앞 시나리오가 내려 둔 `judging`을 다시 올리고 재시작한다.

### 판정기가 또 위약이었다 — `./` 접두사

첫 판 T7은 `get_node_path(i).begins_with("Swallowables/")`로 셌다. **`SceneState`의 경로는 루트 상대라 앞에 `./`가 붙는다**(`./Swallowables/S0`). 그래서 씬에 픽스처를 주입해도 `authored = 0`, 즉 **항상 통과하는 기준**이었다. 고장 주입이 아니었으면 "씬에 놓인 픽스처=0"이라는 통과 로그를 그대로 믿었을 것이다. 판정기의 위약은 이것으로 네 번째다(E5 둘, D1, T7).

### `.tscn`에 `#` 주석을 넣으면 안 된다

들어낸 자리에 "여기 픽스처가 있었다"는 주석을 `#`로 세 줄 적었더니, **그 뒤의 `City` 노드가 통째로 사라졌다**(`Node not found: "City"`). 씬 파서는 그 주석을 노드 헤더 사이의 유효한 토큰으로 보지 않는다. 씬 파일에는 주석을 쓰지 않고, 설명은 코드(`main.gd`의 `JUDGE_SET`)에 둔다.

### 고장 주입 2종 — 전부 검출

| # | 주입 | 걸린 기준 |
|---|---|---|
| 1 | `spawn_judge_set()`의 `judging` 조건 제거 | T7 (게임 재시작 후 픽스처 8) |
| 2 | `main.tscn`에 `S0`를 다시 놓기 | T7 (씬에 놓인 픽스처 1) |

### 회귀·계측

판정 **아홉 종 전부 PASS**. 3c 성능 dense 2.10ms(476fps) · boul 1.82ms(550fps). 판정 모드의 씬은 이전과 완전히 같으므로(같은 8개가 같은 자리에) 1a~4b의 어떤 수치도 바뀌지 않았다.

### 남긴 한계

- **`_ready` 분기는 직접 판정하지 못한다.** 씬을 다시 로드하면 `Judge` 노드도 함께 되살아나 판정이 재귀한다. `_ready`와 `restart()`가 **같은 함수**를 부른다는 구조로만 보증된다 — 그래서 스폰 지점을 하나로 유지하는 것이 규격이다.
- **광장(r=26)이 완전히 비었다.** 플레이 영향은 없다: 시작 반경 1.5의 게이트는 0.675이고 픽스처의 반경은 1.838·2.828이라 **원래도 처음에는 못 먹는 것들**이었다. 첫 끼니는 예나 지금이나 광장 밖의 트래픽콘·덤불·표지판이다.
- **시작 화면을 눈으로 확인하지는 않았다.** T7이 "게임 모드에 픽스처가 0개"를 기계로 단언할 뿐, 렌더 결과를 본 판정은 없다. 판정 모드에서만 스크린샷을 찍는 구조라 그렇다.

---

## §21. 한글 HUD — 폰트 번들 (구현·검증 완료, rev.20)

rev.16의 웹 배포에서 HUD를 영문으로 바꿨다. **웹 빌드에는 시스템 폰트 폴백이 없어서** 한글이 통째로 사라졌기 때문이다. 폰트를 번들해 되돌렸다.

### 폰트 — 2.05MB를 70KB로

- **Nanum Gothic Regular** (NHN, SIL OFL 1.1). `assets/fonts/OFL.txt`에 라이선스 전문을 함께 둔다.
- HUD가 쓰는 문자만 남긴 **서브셋**: ASCII `0x20`~`0x7E` + 한글 26음절 → `2,054,744 → 70,420` 바이트(3.4%).
- 서브셋 도구는 `subset-font`(npm, harfbuzz/wasm)다. `pyftsubset`을 쓰지 않은 이유는 이 환경에 파이썬이 없기 때문이다(`python3` 호출이 실패한다).
- 재생성 절차는 `assets/fonts/README.md`에 있다.

번들 폰트는 네 라벨에 `theme_override_fonts/font`로 직접 건다. `CanvasLayer`는 `Control`이 아니라 테마를 얹을 수 없어서, 라벨마다 거는 편이 확실하다.

| 자리 | 문구 |
|---|---|
| 좌하단 | `점수 %d    크기 %.2f    삼킴 %d` / `점수 %d    (먹힘)` |
| 우상단 | ` 순위  이름    점수    크기` + 구멍별 행 |
| 중앙 | `시간 종료` / `먹혔다`, `1위 …`, `나: 승리/패배 (점수)`, `R 키로 다시 시작` |

### T8 — 데스크톱에서 보이지 않는 결함을 판정한다

**이 결함은 판정기가 도는 환경에서는 재현되지 않는다.** 데스크톱 Godot은 시스템 폰트로 폴백하므로 폰트를 안 붙여도 한글이 멀쩡히 그려진다. 실제로 고장 주입 #1(폰트 오버라이드 제거)에서 **잉크 픽셀이 오히려 늘었다**(2568 → 3278). 화면만 봐서는 절대 못 잡는다는 뜻이다.

그래서 T8은 넷을 함께 묻는다.

1. **폰트 출처** — 네 라벨의 `get_theme_font("font")`가 `res://assets/fonts/hud_kr.ttf`인가. 웹에서만 나는 결함을 데스크톱에서 잡는 유일한 통로다.
2. **글리프 커버리지** — 지금 그리는 문자열 + **판정기가 따로 든 문구 규격**(`SPEC_HUD_CHARS`)의 모든 문자에 `font.has_char()`가 참인가.
3. **한글 존재** — 네 라벨이 그 순간 실제로 그리는 서로 다른 한글 음절이 `HUD_KR_MIN` 이상인가. 1·2·4는 폰트만 보므로, 문구를 영문으로 되돌린 빌드(= §21 이전)가 전부 통과한다.
4. **잉크** — 라벨을 채운 프레임과 비운 프레임을 찍어 **다른 픽셀 수**를 센다. 밝기 문턱으로 세면 3D 장면의 밝은 부분이 섞인다.

### 고장 주입 3종 — 전부 검출(둘은 재보정·재임포트 뒤에)

| # | 주입 | 결과 |
|---|---|---|
| 1 | `theme_override_fonts/font` 제거 | 출처=F, 글리프=F. **잉크는 2568 → 3278로 늘어 통과** — 시스템 폴백이 대신 그린다 |
| 2 | 서브셋에서 `킴` 제거 | 글리프=F (`글리프 없음: '킴'`) — 단, `--import` 를 다시 돌린 뒤에야 |
| 3 | 네 문구 중 셋을 영문으로 | 한글=9 < 10 |

### 판정기가 두 번 헛돌았다

**① 라벨이 다음 프레임에 꺼졌다.** 잉크를 재려고 `hud_over.visible = true`로 켰는데 `update_hud()`가 매 프레임 `visible = (state == OVER)`로 되돌려 잉크가 0이었다. 정적 판정 동안에는 `judging`을 올려 `_process`를 멈춰야 한다.

**② 폰트를 갈아 끼워도 게임은 옛 글리프를 본다.** 주입 #2를 처음 돌렸을 때 `킴`이 없는 폰트인데 글리프 검사가 통과했다. 게임 실행(`--path . -- --judge5`)은 **임포트를 다시 하지 않고** `.godot/imported/*.fontdata`를 그대로 읽는다. `--headless --import`를 먼저 돌려야 새 폰트가 반영된다 — 폰트를 바꾸고 임포트를 안 하면 **웹 빌드에도 옛 글리프가 실린다.**

**③ 임계값이 우연에 기대고 있었다.** `HUD_KR_MIN`을 실측(21)의 1/3인 7로 잡았더니, 네 문구 중 셋을 영문으로 되돌린 빌드가 **정확히 7**로 통과했다(게임오버 문구 하나만 한글로 남아도 그만큼 나온다). 절반(10)으로 올려 9 대 10으로 갈렸다. §19에서 밟은 것과 같은 함정이다 — 하한은 실측의 절반, 그리고 **주입해서 실제로 갈리는지 확인**한다.

### 회귀·계측

판정 **아홉 종 전부 PASS**. 3c 성능 dense 1.95ms(514fps) · boul 1.80ms(555fps). pck는 폰트 70KB만큼 커진다.

### 남긴 한계

- **웹에서 실제로 렌더되는지는 기계로 판정하지 않았다.** T8은 "번들 폰트를 쓰고, 글리프가 있고, 데스크톱에서 잉크가 남는다"까지다. 웹(gl_compatibility)에서의 확인은 여전히 육안이다 — §18이 남긴 한계 그대로다. **2026-07-29 배포본에서 유저가 육안으로 확인했다**(한글 HUD가 브라우저에 정상 표시).
- **문구를 바꾸면 폰트를 다시 만들어야 한다.** 새 음절은 서브셋에 없어 화면에서 사라진다. T8②가 잡지만, 잡히는 시점은 판정을 돌릴 때다.
- **비례 폰트라 리더보드 열이 정렬되지 않는다.** `%-4s`·`%6d` 서식이 고정폭을 전제하는데 Nanum Gothic은 비례폭이다. Godot 기본 폰트도 비례폭이라 이전과 같은 상태이며, 고정폭 한글 폰트를 쓰면 용량이 커진다.

---

## §22. 웹 렌더러 기계 판정 · 산포 반경 유도 (구현·검증 완료, rev.21)

§18이 남긴 한계 둘을 정리했다.

### ① Compatibility에서 판정 아홉 종을 전부 돌렸다

배포본은 `gl_compatibility`(WebGL2)로 도는데 판정기는 Forward+에서만 돌아, §18까지 **웹 렌더 경로의 기계 판정은 0회**였다. 데스크톱에서도 `--rendering-driver opengl3`로 같은 백엔드를 쓸 수 있다.

```
godot --rendering-driver opengl3 --path . -- --judge…
```

**아홉 종 전부 PASS.** 착시(H1·H2·H7·H8), 도시 지면(D1~D6), 흡입·성장·아레나·게임루프·수관 걸림이 전부 성립한다.

> **이 초록은 §23 뒤로 재현되지 않았다.** §23이 우물·림을 갈아엎고 이 Compatibility 회귀를 다시 돌리지 않아, 1a가 H6에서 탈락한 채로 남아 있었다(§24에서 발견·처분). 백엔드를 하나 더 돌리기로 한 규율은 **바꿀 때마다** 지켜야 의미가 있다.

| | Forward+ | Compatibility |
|---|---|---|
| 판정 아홉 종 | 전부 PASS | **전부 PASS** |
| 3c dense | 1.99ms (502fps) | **5.31ms (188fps)** |
| 3c boul | 1.86ms (537fps) | **4.53ms (221fps)** |

Compatibility는 2.7배 느리지만 예산(16.67ms)의 32%다. **브라우저는 이보다 더 느릴 수 있다** — WASM·브라우저 합성이 더 얹히기 때문이다. 그 몫은 여전히 판정 밖이다.

`check_pipeline()`은 이제 실행 렌더러를 **런타임에서** 읽어 로그에 남긴다. 프로젝트 설정만 읽으면 `opengl3`로 돌린 판정도 자기가 "forward_plus"라고 보고한다.

### 판정기가 다섯 번째로 위약이었다 — 엔진 기본값

H10에 "웹 렌더링 방식이 `gl_compatibility`인가"를 넣고 `project.godot`에서 그 줄을 지워 봤다. **통과했다.** `rendering_method.web`은 project.godot에 없어도 **엔진 기본값이 이미 `gl_compatibility`**이기 때문이다(실측: 줄을 지우고 돌려도 `ProjectSettings`가 그 값을 돌려준다).

그래서 §11 이후 project.godot에 적혀 있던 주석 — "이 오버라이드가 없으면 브라우저에서 렌더러 초기화가 실패한다" — 은 **검증되지 않은 주장**이었다. 지워도 웹은 Compatibility로 뜬다. 지금 H10이 무는 것은 **누가 그 값을 다른 것으로 바꾸는 경우** 하나이고(`forward_plus`로 바꾼 주입은 FAIL), 줄을 지우는 것은 잡지 못한다 — 잡을 것이 없기 때문이다. 주석도 그렇게 고쳤다.

### ② `plan_block`의 산포 반경을 구간에서 유도한다

`rng.randf_range(-8.5, 8.5)`는 상수였다. 대로가 붙은 블록의 사용 가능 반폭은 **7.95**라 축당 6.5%의 시도가 구간 밖으로 나가 `add_slot`이 조용히 거절한다. 그리고 **지도의 92%(196블록 중 180)가 그런 블록이다.**

```gdscript
	var spread := Vector2(minf(SPREAD_MAX, (sx.y - sx.x) * 0.5),
		minf(SPREAD_MAX, (sz.y - sz.x) * 0.5))
```

구간 반폭을 그대로 쓰지 않고 상한(8.5)을 씌운다 — 이 값은 **중심**의 범위이고 에셋에는 폭이 있어서, 구간 끝까지 벌리면 가장자리 시도가 폭만큼 거절된다.

| | 전 | 후 |
|---|---|---|
| 총 프롭 | 3804 | **3876** (+1.9%) |
| 블록 구역 프롭 | 957 | **1018** |
| 대로 인접 블록(180개) 블록당 | 4.75 | **5.15** (+8.4%) |
| 대로 없는 블록(16개) 블록당 | 6.38 | 5.69 |
| 두 종류의 밀도 차 | **+34%** | **+10%** |

노린 것은 마지막 줄이다 — 대로 인접 블록만 덜 차던 편향이 줄었다. 남은 10%는 구간 자체가 좁은 데서 오는 것이라 정상이다(반폭 7.95 대 9.2).

### 주석이 계측에 반증당했다

처음에 "일반 블록에서는 배치가 한 톨도 안 바뀐다. `randf_range`는 범위와 무관하게 난수를 하나씩 뽑으므로 시드 정렬도 유지된다"고 적었다. **둘 다 틀렸다.** 산포 반경이 달라진 블록에서 `add_slot`이 고르는 후보 집합이 달라지고, 후보 수에 따라 난수 소비량이 달라져 **그 뒤의 시드 흐름이 통째로 어긋난다.** 산포 반경이 8.5 그대로인 블록의 밀도가 6.38 → 5.69로 바뀐 것이 그 증거다.

§13의 `start_frozen`, §18의 성능 지점에 이어 **세 번째로, 그럴듯한 근거를 적었다가 실측에 뒤집혔다.** 이번에는 커밋 전에 계측했다.

### 회귀

Forward+ 아홉 종 · Compatibility 아홉 종 전부 PASS. `RESTART_PROPS`를 3804 → 3876으로 갱신했다(T5가 이 수를 단언하므로, 산포를 되돌리면 T5가 잡는다).

### 남긴 한계

- **브라우저에서 실제로 도는 것은 여전히 판정하지 않는다.** `--rendering-driver opengl3`는 같은 렌더링 백엔드를 쓸 뿐, WASM·emscripten·브라우저 합성은 재현하지 않는다. 웹 전용 결함(§21의 폰트 폴백 같은 것)은 설정·자원을 직접 읽어 잡는 수밖에 없다.
- ~~한글 HUD가 브라우저에서 그려지는지 눈으로도 확인하지 못했다.~~ → **2026-07-29 유저가 배포본에서 육안 확인했다("한글 HUD도 잘 보임").** 기계 판정은 여전히 데스크톱까지다(T8) — 브라우저에서 그려진다는 것은 이 육안 확인 하나가 근거다.
> → **둘 다 §24에서 해소됐다.** 판정 아홉 종이 실제 Chrome 안에서 돌고, T8은 WebGL2 프레임버퍼에서 잉크 2515픽셀을 센다.

---

## §23. 통과를 기하로 흉내내지 않는다 — 물리적 림 (구현·검증 완료, rev.22)

플레이 피드백 셋이 들어왔고, **셋이 한 뿌리**였다.

| # | 피드백 | 원인 |
|---|---|---|
| 1 | 검은 돌·자동차가 원 안에 들어왔는데 안 삼켜진다 | 크기 게이트가 **외접반경**(대각선/2)에 `0.45`를 곱해 요구했다 |
| 2 | 걸린 물체의 물리가 원작 대비 부실하다 | 물체는 애초에 **아무것에도 걸릴 수 없었다** — 림이 물리적으로 존재하지 않았다 |
| 3 | 어지간하면 땅 위에서 녹듯 사라진다 | 통과를 **기하 조건**으로 판정해, 조건이 참이 되는 순간 충돌을 끊고 지워 버렸다 |

지면은 평평한 `StaticBody3D` 하나였고 구멍은 셰이더의 착시였다. 그래서 §4부터 통과를 `d + r < R`이라는 기하 조건으로 흉내냈고, §19는 그 위에 걸림까지 계수로 얹었다. **모형이 잘못된 자리에 있었다.**

### 계측 — 게이트가 요구하던 구멍

| 물체 | 밑동 반폭 | 옛 게이트가 요구한 R | 실제로 필요한 R |
|---|---|---|---|
| Taxi (1.7×4.2m) | 0.85 × 2.11 | **5.05** | 2.27(눕히지 않고) |
| Rock2 (검은 돌) | 0.59 × 0.92 | **2.42** | 1.09 |
| Building1_Large | 7.77 × 2.55 | **18.17** | 8.18 |

4.2m 차를 삼키는 데 **지름 10m** 구멍이 필요했다. 원 안에 들어와 보이는데 거부되는 것이 맞았다.

### 구멍 둘레에 물리적 바닥판을 놓는다

감지 범위(Area3D)에 들어온 물체는 **지면(레이어 1) 대신 림(레이어 8)** 을 딛는다. 림은 구멍 둘레의 가운데가 뚫린 원판이고, 안쪽 반경이 곧 그려지는 구멍 반경이다.

```gdscript
func rim_faces() -> PackedVector3Array:
	var f := PackedVector3Array()
	var ro: float = radius + rim_outer
	for i in rim_segments:
```

이제 **구멍 위에는 바닥이 없다.** 통과 조건도, 크기 게이트도, §19의 걸림 계수도 전부 지웠다. 무엇이 들어가고 무엇이 걸리는지는 물리가 정한다.

- 들어갈 수 있으면 기울며 빠진다 — 차는 코부터 들어간다.
- 구멍보다 넓으면 **림 위에 그대로 남는다** — 우물에 걸친 채 얹혀 있다.
- 삼킴 판정은 "지면 아래로 **꼭대기까지** 내려갔다" 하나다. 원점만 보면 키 큰 물체가 **가지가 림에 닿기도 전에** 충돌을 잃고 통과한다(실측: 수관 픽스처가 밑동 0.6m만 잠기고 그대로 빠졌다).
- 소멸은 **우물 안에서만** 일어난다. 구멍이 떠나 버린 낙하물은 다시 끌어온 뒤에 사라진다.

### 나무는 이제 가지로 걸린다 — §17·§19를 물리로 대체

§17은 나무 콜라이더를 밑동으로 바꿔 "안 먹힘"을 고쳤고, §19는 사라진 수관을 계수로 되살렸다. 둘 다 게이트가 외접반경을 보던 시절의 우회책이다. 지금은 **수관에 콜라이더를 단다** — 밑동 셰이프 + 수관 셰이프. 게이트가 없으니 수관을 달아도 나무가 통째로 거절되지 않고, 대신 가지가 림에 **실제로** 얹힌다.

판정 6의 나무 픽스처(밑동 0.8각, 수관 6×6)는 지름 4m 구멍에서 밑동이 3.00m 잠긴 채 멈춘다 — 계수가 아니라 접촉이다.

### 통과 규격 — 판정기가 단언할 수 있는 두 경계

물리가 정하게 두면 판정기는 무엇을 단언하는가. 두 경계는 자세와 무관하게 참이다.

- **통과 규격**: XZ 외접반경 < R 이면 눕히지 않고도 들어간다 → **반드시 삼켜진다**.
- **거절 규격**: 가장 작은 두 반extent가 만드는 단면의 외접반경 `sqrt(h1²+h2²)` > R 이면 **어떤 자세로도** 못 들어간다 → 삼켜지면 안 된다.
- 그 사이는 회색 지대다. 판정기는 단언하지 않는다.
- (§30 이 좁혔다) 통과 규격의 "반드시" 는 **정중앙 낙하**에서 성립한다. 옆에서 흡입으로
  끌려오는 경로는 기울며 투영 반경이 커져 경계 근처(외접 1.9 < R 2.0)에서 쐐기가 될 수
  있다 — 옆-흡입 보장은 **공간 대각 반경 < R** 에서 단언한다(실측, §30).

한 변 2.6인 정육면체는 폭이 1.3이지만 대각선이 3.68이라 지름 3.4 구멍에 **모서리로 얹힌다.** 처음에 좁은 쪽 반폭만 규격으로 삼았다가 소형 픽스처가 한 개도 안 빠져 잡았다 — 폭만 보면 안 된다.

### 판정 개편

| 기준 | 전 | 후 |
|---|---|---|
| 1b B3 | 전환 순간 `d + r <= R` 인가 | **지면 아래로 내려간 물체는 구멍 위에 있는가** (피드백 3) |
| 2 C2 | 크기 게이트가 상한을 지키는가 | 거절 규격 물체는 안 빠지고, 자라면 빠지는가 (R 2.3 → 5.06) |
| 3b E8 | `snag_radius`가 메시에서 나왔는가 | **수관이 넓은 프롭에 수관 셰이프가 있는가**(955개) |
| 6 K1~K6 | 걸림 계수 모형 | 통과·거절·수관 걸림·해소·지면 관통·긴 물체 |
| 4 G7 | AI 이동 ≥ 30 | ≥ 11 — 근처 것을 바로 먹게 되어 덜 돌아다닌다(실측 21.9~44.7) |

`--judge6` 실측:

| 픽스처 | R | 결과 |
|---|---|---|
| flat 2×2×2 | 2.0 | 삼킴(55프레임) |
| wide 6×2×6 | 2.0 | **안 빠짐** (최저 y = 0.00 — 얹힌 채 꿈쩍 않는다) |
| pole 0.6×8×0.6 | 2.0 | 삼킴(82프레임) — 전봇대는 폭이 맞으면 들어간다 |
| tree(밑동+수관) | 2.0 | **안 빠짐** (최저 y = −3.00 — 가지가 림에 걸렸다) |
| tree | 5.0 | 삼킴(87프레임) |

### 고장 주입 4종 — 전부 검출

| # | 주입 | 걸린 기준 |
|---|---|---|
| 1 | 림 바닥판을 비운다 | K2·K3 (모든 것이 빠진다) |
| 2 | 림 전환을 안 한다(지면을 계속 딛는다) | K1·K4·K6 (아무것도 안 빠진다) |
| 3 | 낙하 전환을 원점 기준으로(키 무시) | K3 (나무가 가지 닿기 전에 빠진다) |
| 4 | 수관 셰이프를 안 단다 | 3b E8 (955건) |

주입 4가 `--judge6`을 통과하는 것은 설계대로다 — 판정 6의 픽스처는 판정기가 직접 만든다. "도시 프롭에 수관이 달렸는가"는 도시 전체를 보는 E8이 묻는다.

### 회귀·계측

판정 **아홉 종 전부 PASS**. 3c 성능 dense 2.03ms(494fps) · boul 1.88ms(532fps) — 림 트라이메시(구멍당 96삼각형)는 계측에 나타나지 않는다.

> **이 초록에 구멍이 둘 있었다(§24에서 드러남).** ① Forward+ 판정 2가 실제로는 FAIL이다 — C2가 크기 게이트 시절의 전제 위에 서 있었는데 §23이 그 게이트를 걷어냈다. ② Compatibility 회귀를 돌리지 않아 1a의 H6 탈락을 놓쳤다. 둘 다 §24에서 고쳤다. **"전부 PASS"는 그것을 적은 시점에 실제로 아홉 종을 다 돌렸을 때만 참이다.**

**게임에 미치는 영향**: 같은 물체를 훨씬 작은 구멍으로 먹는다. 차량 5.05 → 2.27, 검은 돌 2.42 → 1.09, 대형 건물 18.17 → 8.18. 나무는 반대로 수관이 걸려 늦어진다(밑동 1.83 → 수관 2.7~4.4).

### 남긴 한계

- **회색 지대는 판정하지 않는다.** 외접반경과 통과 반경 사이의 물체가 실제로 들어가는지는 물리·자세·운에 달렸다. 그 구간을 단언하려면 자세까지 규격으로 잡아야 하는데, 그러면 판정기가 물리 엔진을 다시 구현하는 셈이 된다.
- **림은 평평한 판이라 우물 벽이 없다.** 빠진 물체는 벽을 긁지 않고 자유낙하한다. 벽을 세우면 구멍이 자랄 때 벽에 낀 물체를 밀어내야 해서, 지금은 두지 않았다.
- **구멍이 떠난 자리의 낙하물은 지면 아래에서 끌려온다.** 보이지 않는 자리라 눈에 띄지 않지만, 물리적으로는 지면을 통과해 이동한다.
- **`snag_*`·`swallow_ratio` 계열이 규격에서 사라졌다.** `swallow_ratio`는 AI 목표 선정용 조언으로만 남았다.

---

## §24. 브라우저에서 판정을 돌린다 (구현·검증 완료, rev.23)

§22가 남긴 한계가 그대로 남아 있었다 — **"브라우저에서 실제로 도는 것은 여전히 판정하지 않는다."** `--rendering-driver opengl3`는 같은 렌더링 백엔드를 쓸 뿐 WASM·emscripten·브라우저 합성을 재현하지 않는다. 그래서 한글 HUD가 브라우저에서 그려진다는 근거는 **유저 육안 확인 하나**였고, 그것이 이 프로젝트에 남은 마지막 "눈으로 본 것" 이었다.

이제 **판정 아홉 종이 전부 실제 Chrome 안에서 돈다.** 그중 여덟이 게이트이고, 3c(성능)는 브라우저에서 게이트가 될 수 없어 계측만 한다(아래 따로).

### 브라우저에는 명령줄이 없다

판정은 `OS.get_cmdline_user_args()`에서 이름을 받는다. 브라우저에는 그것이 없다 — 그래서 웹 판정 횟수가 0이었다. 쿼리 문자열을 같은 자리로 옮긴다.

```gdscript
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("window.location.search", true))
```

`?judge=6` → `--judge6`, `?judge=` → `--judge`. 쿼리는 **외부 입력**이므로 `JUDGE_ORDER` 화이트리스트를 거친 것만 분기로 들어간다. 그 상수는 화이트리스트이자 **고르는 우선순위**다 — 인자가 둘 이상 들어와도 도는 판정은 하나인데, 분기와 하네스 보고가 각자 고르면 "판정 A의 결과" 자리에 판정 B의 결과가 기록된다. 고르는 자리를 `judge_flag()` 하나로 뒀다.

### 결과가 오지 않는 것을 통과로 읽지 않는다

데스크톱 판정은 종료 코드로 결과를 낸다. 브라우저에는 종료 코드가 없다. Godot의 `print`는 `console.log`로 나가므로(엔진의 `onPrint`가 **호출 시점에** `console.log`를 찾는다 — 나중에 감싸도 걸린다) 그것을 감싸 판정 줄을 전부 모으고, `JUDGE RESULT ->`를 보는 순간 하네스(`tools/web_judge.mjs`)로 되돌려 보낸다.

**이 판정의 가장 큰 위험은 페이지가 안 뜬 것이 "지적사항 없음"으로 둔갑하는 것이다.** 하네스는 신호가 도착해야만 판정을 마치고, 오지 않으면 `FAIL(무응답)`으로 끝난다. 판정이 결과 줄을 내지 못하고 죽는 길(`setup()` 실패 등)도 침묵으로 남지 않게, `quit` 요청 뒤에도 끝까지 도는 그 프레임에서 판정기가 대신 FAIL을 낸다.

하네스는 정적 서버를 겸한다. `Cache-Control: no-store` — 다시 익스포트한 빌드를 브라우저가 옛 wasm/pck로 대신하면 **고장 주입이 통과해 버린다.** 시간 초과는 전체가 아니라 **판정 하나마다** 잰다(전체에 한 번 걸면 앞 판정이 길어질수록 뒤 판정의 예산이 줄어 같은 빌드가 실행마다 다른 결과를 낸다). 판정이 끝난 페이지는 `/next`로 돌아오고 서버가 다음 판정으로 302한다 — 브라우저는 처음 한 번만 띄우면 아홉 종이 이어서 돈다.

### 판정기가 세 곳에서 어긋나 있었다 — 둘은 이미 red였다

**§23·§22가 "전부 PASS"로 적어 둔 것이 지금 재현되지 않는다.** 브라우저 판정이 그 둘을 끌어냈다. 아래 ②·③은 `main`을 그대로 받아 돌려도 탈락한다(pristine HEAD 실측). 새 환경에서 판정을 돌린다는 것은 **기존 판정이 무엇을 근거로 초록이었는지** 다시 묻는 일이기도 했다.

**① H10 — 기대값이 실행 플랫폼의 함수다.** `rendering_method`를 무조건 `forward_plus`로 단언하고 있었다. 웹 익스포트본에서 그 키는 `gl_compatibility`로 읽히므로 **정상 빌드가 탈락했다.** 데스크톱에서는 관측할 수 없는 사실이다. 웹에서는 기대값을 `gl_compatibility`로 바꾸고, 대신 **런타임 렌더러까지** 단언한다 — 설정만 보는 것보다 강하다.

**② C2 — 없어진 게이트 위에 서 있던 기준.** (③ H6은 아래 따로) `main`이 이미 red였다(실측: 데스크톱 단독 2회, 브라우저 1회 모두 같은 값으로 FAIL). §23이 크기 게이트를 걷어내기 전, C2는 "1차(소형 흡입)가 끝날 때까지 대형이 하나도 안 사라진다"를 단언했다. 게이트가 있던 시절에는 대형이 **반경과 무관하게** 거절되었으므로 그것이 참이었다. 게이트가 사라진 뒤로는 1차에서 구멍이 2.3 → 5.79로 자라고, 소형 (11,−4)로 가는 경로가 대형 (16,−2)에서 5.4m까지 접근한다 — 거절 반경 2.83을 한참 넘긴 구멍이 그것을 삼키는 것은 **규격대로다.** 기준이 물리가 아니라 **픽스처 배치라는 우연**에 기대고 있었다.

고친 자리는 "언제 묻는가"다.

| 구간 | 묻는 것 |
|---|---|
| 0차 (반경 고정 2.3) | 거절 규격 물체가 전부 살아 있는가 — **여기서 묻는다** |
| 1차 (2.3 → 5.79로 성장) | `gate_breaches`가 **매 물리 프레임** 반경과 물체를 그때그때 비교한다 |
| 2차 (성장 후) | 이제 열리는가 (`left == 0`) |

분류도 셋으로 갈랐다. 통과 규격(XZ 외접반경 < R) 6개 · 거절 규격(통과반경 > R) 2개 · **회색 지대 0개** — §23이 "단언하지 않는다"고 못 박은 구간에 픽스처가 하나도 없다는 것을 판정기가 매번 보고한다. 어느 한쪽이 비면(`c2set`) 시나리오가 조용히 아무것도 시험하지 않는 것이므로 그 상태를 통과로 읽지 않는다.

### ③ H6 — 자기가 이름 붙인 결함을 잡지 못하고 있었다

브라우저 아홉 종이 전부 통과한 뒤, §22가 세운 규율("배포본과 같은 백엔드로도 돌려라")대로 데스크톱 `--rendering-driver opengl3`를 다시 돌렸다. **1a가 탈락했다 — H6.** `main`도 똑같이 탈락한다(pristine HEAD 실측). §23이 우물·림을 갈아엎고 §22의 Compatibility 회귀를 다시 돌리지 않은 것이다. **두 번째 stale green이다.**

H6은 `|중심 휘도 − 배경 휘도| ≥ 0.03` — "구멍 안이 배경이 비쳐 보이는 구멍이 아닌가"를 묻는다. 정상 빌드의 실측은 이렇다.

| 백엔드 | 중심 | 배경 | 차 | H6 |
|---|---|---|---|---|
| Forward+ | 0.1548 | 0.2115 | 0.0567 | 통과 |
| 브라우저 WebGL2 | 0.1817 | 0.0905 | 0.0912 | 통과 |
| 데스크톱 opengl3 | 0.1817 | 0.1849 | **0.0032** | **탈락** |

세 값에서 움직인 것은 **배경 휘도뿐**이다. 같은 빌드·같은 렌더링 백엔드인데 클리어 색이 데스크톱과 브라우저에서 다르게 읽힌다.

**표본 좌표가 틀린 것은 아니다.** `bg=(50,2)`는 화면 꼭대기의 하늘이고, 저장된 프레임을 판정기 밖에서 직접 읽어도 같은 값이 나온다(`shot.png (50,2) = RGB 46,47,52` → 0.1846). 재는 자리가 아니라 **렌더된 하늘과 우물 안의 휘도가 실제로 붙어 있다.**

여기서 임계를 낮추고 싶어지는데, **먼저 물어야 할 것은 "이 기준이 무엇을 잡는가"** 였다. 우물 메시를 숨겨 배경이 원반 안으로 그대로 비치게 하는 주입 — H6이 이름 붙인 바로 그 결함 — 을 넣었다.

```
JUDGE hole0 lum c=0.0905 g=0.6396 bg=0.2115 dRing=0.0000 dCB=0.1210
JUDGE hole0 H1=P H2=F H6=P H7=F H8=P H9=P -> FAIL      (leak=1862/2)
```

**H6은 통과했다.** 두 백엔드 모두에서. 그 프레임에서 중심은 0.0905로 읽히는데 꼭대기 하늘은 0.2115다 — 같은 배경인데 두 자리의 값이 다르다. **왜 다른지는 규명하지 않았다**(여기서 더 파는 것은 이 절의 목적이 아니다). 다만 그 차이가 있는 한 "중심 == 배경"은 성립하지 않고, H6은 배경이 그대로 비치는 프레임을 통과시킨다. 잡은 것은 **H7**(마젠타 누출 1862/2)과 **H2**(내부 그라디언트 0.0000)다.

그래서 H6은 **완화가 아니라 폐기**다(H3와 같은 처분, 같은 이유). 같은 질문의 강한 판본이 이미 있다 — H7은 배경을 마젠타로 바꿔 놓고 원반 안의 마젠타를 센다. 마젠타는 어떤 씬 팔레트와도 겹치지 않으므로 우물 색을 바꿔도, 백엔드를 바꿔도 흔들리지 않는다. 값은 진단용으로 계속 찍는다.

### 주석이 또 고장 주입에 반증당했다

H10을 고치며 "익스포트가 `.web` 오버라이드를 기본 키에 적용해서 웹에서는 그 키가 `gl_compatibility`로 읽힌다"고 근거를 적었다. **주입 4가 그것을 반증했다**: `.web`을 `forward_plus`로 바꾼 빌드에서도 기본 키는 그대로 `gl_compatibility`였다(설정=gl_compatibility, 웹=forward_plus). 오버라이드가 적용된 것이 아니라 **익스포터가 웹 기본값을 그 키에 써 넣는다 — 두 키는 독립이다.**

§13의 `start_frozen`, §18의 성능 지점, §22의 산포 반경에 이어 **네 번째로 그럴듯한 근거가 실측에 뒤집혔다.** 이번에도 커밋 전에 잡혔고, 잡은 것은 고장 주입이다.

### 고장 주입 5종 — 전부 검출

| # | 주입 | 결과 |
|---|---|---|
| 1 | 브라우저를 아예 안 띄운다 | 하네스 `FAIL(무응답)` · exit 1 — **무응답이 통과로 새지 않는다** |
| 2 | HUD를 시스템 폰트(Malgun Gothic)로 바꾸고 T8①(폰트 출처)을 무력화 | **데스크톱 PASS(잉크 2590) / 브라우저 FAIL** — 글리프=F, 규격 26자 전부 없음 |
| 3 | 림 바닥판을 비운다 | 판정 2 C2 FAIL — 거절생존=F(0/2) · `gate_violations=11` |
| 4 | `rendering_method.web`을 `forward_plus`로 | 브라우저 H10 FAIL — 실행 렌더러가 실제로 `forward_plus`로 떴다 |
| 5 | 우물 메시를 숨긴다(배경이 원반 안으로 비친다) | H7 FAIL(leak 1862/2 · 1856/2) · H2 FAIL — **두 백엔드 모두. H6은 통과했다** |

**주입 2가 이 절의 존재 이유다.** 데스크톱은 Windows에 Malgun Gothic이 있어 한글을 멀쩡히 그린다 — 화면을 봐도, T8③(잉크)을 재도 결함이 안 보인다. 브라우저에는 시스템 폰트 폴백이 없다.

그리고 그 브라우저 실행에서 **잉크는 2312로 통과했다.** 폴백이 두부(tofu) 상자를 그려 픽셀을 남기기 때문이다. 잡은 것은 T8②(글리프 커버리지)다 — **"글자가 보이는가"를 잉크로만 물으면 두부를 통과시킨다.**

주입 3은 §23의 주입 1과 같은 고장이지만 기준이 바뀌었으므로 다시 주입했다. 옛 c2a가 잡던 "무조건 삼키는 빌드"를 새 기준도 **두 갈래로** 잡는다(0차 생존 + 매 프레임 감시).

### 계측 — 브라우저 대 데스크톱

| | 데스크톱 Forward+ | 데스크톱 Compatibility | **브라우저(Chrome 150 / WebGL2)** |
|---|---|---|---|
| 판정 | 아홉 종 전부 PASS | 아홉 종 전부 PASS(§24에서 재실측 — §22의 초록은 §23 뒤로 깨져 있었다) | **게이트 여덟 종 전부 PASS** (3c는 계측) |
| T8 잉크 | 2568 | — | **2515** (규격 하한 640) |
| T8 한글 음절 | 21 | — | **21** (하한 10) |
| 판정 6 tree 최저 y | −3.00 | — | **−3.00** (프레임 수까지 동일: 55/82/87) |
| 3c dense draws | 2527 | — | **10102** |
| 3c dense avg | 1.99ms | 5.31ms | **16.67ms (60fps — rAF 상한)** |

물리는 WASM에서 **프레임 단위로 같은 값**을 낸다(판정 6의 삼킴 프레임 55·82·87이 §23의 데스크톱 표와 일치). 한글 HUD는 이제 육안이 아니라 **WebGL2 프레임버퍼에서 센 잉크 2515픽셀**이 근거다.

### 3c는 브라우저에서 게이트가 아니다

브라우저는 `requestAnimationFrame`으로 루프를 묶는다. `window_set_vsync_mode(VSYNC_DISABLED)`도 `Engine.max_fps = 0`도 그 위에서는 효력이 없다. 그래서 avg가 정확히 **16.67ms = 60fps**로 나온다 — 이것은 여유분이 아니라 **모니터 주사율**이다. 예산 16.67ms와 그 값이 우연히 같아서, F1은 사실상 동전 던지기가 된다.

**같은 빌드를 두 번 돌려 그것을 실제로 봤다.**

| 실행 | dense avg | F1 | 결과 |
|---|---|---|---|
| 1회차 | 16.67ms | P | PASS |
| 2회차 (같은 커밋·같은 익스포트본) | **16.72ms** | **F** | **FAIL** |

0.05ms 차이로 판정이 뒤집힌다. 144Hz 화면에서는 6.9ms로 거저 통과하고, 50Hz 화면에서는 20ms로 결함 없이 탈락한다. **재는 사람의 모니터가 결과를 정하는 수는 게이트가 될 수 없다.**

그래서 브라우저의 3c는 **계측만 한다** — `--expect` 목록에 넣지 않는다. 데스크톱 3c는 그대로 게이트로 남는다(vsync를 실제로 끌 수 있다). 여기서 읽을 것은 avg가 아니라 **worst**다: dense 20.10~30.70ms · boul 17.10~19.40ms — 60fps 주기의 2배(F2 예산) 안이므로 프레임을 흘리고 있지는 않다. 드로우콜이 데스크톱의 4배(10102 대 2527)인 것도 이 표의 소득이다.

### 이 문서의 코드 블록도 어긋나 있었다 — 열 중 여덟

세 번째 stale green은 문서 자신이었다. 이 문서는 서두에서 **"이 문서의 모든 코드 블록은 그 파일들과 바이트 단위로 동일하다(기계 대조 — rev.16에서 12개 파일 전부 재확인)"** 고 단언한다. §24에서 대조해 보니 **열 블록 중 여덟이 어긋나 있었다.**

| 블록 | 문서 | 파일 |
|---|---|---|
| `scripts/screenshot.gd` | 2110줄 | **2612줄** |
| `scripts/main.gd` | 344줄 | 372줄 |
| `scripts/city.gd` | 479줄 | 510줄 |
| `scripts/swallowable.gd` | 72줄 | **136줄** |
| `scenes/main.tscn` | 130줄 | 111줄 |
| `scenes/hole.tscn` | 38줄 | 48줄 |
| `scripts/hole_ai.gd` · `project.godot` | 114 · 30줄 | 116 · 32줄 |

rev.16 이후의 §17~§23이 파일만 고치고 문서의 사본을 두고 갔다. **손으로 지키는 규율은 이렇게 조용히 깨진다** — 이 절이 판정기에 대해 말한 것과 같은 이야기다. 그래서 사람이 아니라 기계가 확인하게 했다.

```powershell
pwsh tools/sync_plan_blocks.ps1          # 대조 (어긋나면 exit 1)
pwsh tools/sync_plan_blocks.ps1 -Fix     # 문서를 파일에 맞춘다
```

열 블록을 전부 맞췄고, 대조가 `어긋난 블록 0개 / 전체 10개`로 끝난다. **코드를 고친 커밋에서는 이것을 돌린다.**

### 회귀

**데스크톱 Forward+ 아홉 종 · 데스크톱 Compatibility 아홉 종 · 브라우저 게이트 여덟 종 — 스물여섯 번 전부 PASS.** 배포본에는 판정 코드가 이미 실려 있었고(§20 이후 픽스처만 판정 모드에 갇혀 있다), §24가 더한 것은 **트리거**뿐이다 — 쿼리가 없으면 `_ready`가 즉시 돌아가 아무 일도 하지 않는다. 자동 이동(`/next`)은 `127.0.0.1`/`localhost`에서만 도므로, 배포본에 `?judge=`를 붙여 연 사람을 있지도 않은 경로로 보내지 않는다.

### 남긴 한계

- **브라우저 하나·기계 하나에서만 돌렸다.** Chrome 150 / Windows / RTX 4060 Ti다. Firefox·Safari·모바일 GPU는 여전히 판정 밖이고, 특히 Safari의 WebGL2와 모바일의 정밀도 차이는 이 판정이 아무것도 말해 주지 않는다.
- **브라우저를 띄우는 것은 자동화되지 않았다.** 하네스는 URL을 열어 주지 않는다 — 사람이든 스크립트든 한 번은 띄워야 한다. 대신 그 한 번 뒤로는 아홉 종이 스스로 이어진다.
- **3c는 게이트가 아니다**(위 참조). 브라우저에서 성능 여유분을 재려면 rAF 밖의 계측 수단이 필요하다.
- **판정 스크린샷이 남지 않는다.** `save_png`는 브라우저에서도 `err=0`을 돌려주지만(실측 — "익스포트본의 `res://`는 읽기 전용이라 실패할 것"이라는 예상은 틀렸다) 그 파일은 브라우저의 메모리 파일시스템에 있고 새로고침과 함께 사라진다. 판정은 이미지를 메모리에서 재므로 결과에는 영향이 없지만, **데스크톱과 달리 나중에 열어 볼 그림이 없다.** 어긋난 자리를 눈으로 대조하려면 그 판정을 데스크톱에서 다시 돌려야 한다.

---

## §25. 격자 위에 도시를 얹는다 — 지구제·수계·수퍼블록 (구현·검증 완료, rev.24)

유저의 지적은 넷이었고 그 첫째가 이것이다: **"실제 도시의 도로는 100% 바둑판이 아니다."** §18이 3배수 중심선을 대로로 승격시켰지만 그것으로는 부족했다 — 32m 격자가 지도 끝까지 완벽하게 균질했고, 병원·은행·주택이 위치와 무관하게 섞였으며, 지도는 보이지 않는 clamp에서 뚝 끊겼다. 여기서 격자 **위에** 지구제·수계·수퍼블록을 얹는다. 인프라(셰이더 도로·32m 주기)는 그대로 두고, **무엇이 어디에 서는가**와 **도로가 존재하는가**를 지도의 함수로 만든다.

### 지도는 난수가 아니라 손으로 저작한 상수다

`city.gd`의 `ZONE_ROWS` 열네 줄이 14×14 셀 전체를 정한다. 시드 난수로 뽑지 않은 이유가 셋이다. ① 판정기가 **독립 사본**으로 같은 지도를 들 수 있다(셰이더 uniform을 안 읽는 것과 같은 이유다). ② 강·공원·도심을 의도적으로 디자인할 수 있다. ③ E4 재현성이 시드와 무관하게 자동으로 성립한다.

행·열 ↔ 월드 대응식은 **세 곳이 같은 식을 들어야 한다**(city.gd · 셰이더 · 판정기):

```
행 r = j + 7,  열 c = k + 7,  zone_at(k, j) = ZONE_ROWS[j + 7][k + 7]
셀 (k, j) 는 x ∈ [32k, 32k+32], z ∈ [32j, 32j+32]
```

셰이더에는 14×14 R8 텍스처로 굽는다. 셀당 `zone_code * 51`이 들어가고, 51/255 = 0.2 간격은 8비트 양자화·필터 오차보다 압도적으로 커서 복호가 견고하다. **판정기는 이 텍스처를 읽지 않는다.**

### 바다는 지면을 키워서 만들지 않는다 — 주입이 그것을 증명했다

지도 밖을 바다로 칠하려면 `PlaneMesh`를 키우는 것이 자연스러워 보인다. **그렇게 하면 H 계열 판정이 통째로 무너진다.** 착시 판정은 탐침 프레임에서 배경(마젠타)을 찾아 그것을 기준 휘도로 쓰는데, 지면이 넓어지면 화면에서 하늘이 사라져 기준점 자체가 없어진다. 448 → 4000 주입을 실제로 넣어 보니 `inter`·`road` 지점이 즉시 `배경(마젠타)이 없다`로 탈락했다.

그래서 바다는 **지도 안쪽 테두리 한 줄**(k 또는 j 가 ±끝인 52셀)이다. 지면 메시는 448 그대로고, 놀이 영역이 384×384로 줄어드는 대신 세계가 물로 둘러싸여 끝난다.

### 도로의 존재는 지도에서 파생되는 순수 함수다

세그먼트 데이터를 따로 두지 않는다. 어떤 도로 세그먼트든 양쪽 셀만 보면 정해진다.

```gdscript
static func seg_rule(a: int, b: int, bridge: bool) -> bool:
	if a == Z_WATER or b == Z_WATER:
		return bridge
	return not (a == Z_PARK and b == Z_PARK)
```

양쪽이 공원이면 없다(수퍼블록 내부 관통 도로가 걷힌다). 한쪽만 공원이면 남는다 — 공원은 도로로 둘러싸인 것이 자연스럽다. 수역은 **교량 목록에 있을 때만** 뚫린다.

교량은 **선이 아니라 세그먼트 단위**로 적는다(`BRIDGES = [[-3, 2], [0, 2], [3, 2]]`). 선 전체를 열면 같은 z의 바다 테두리까지 뚫려 구멍이 지도 밖 물 위로 나간다.

### 공원은 도로만 지워서는 생기지 않는다

셰이더에서 내부 도로를 지워도 `block_span`이 셀 단위로 커브를 물고 있으면 프롭이 옛 도로 띠를 계속 피한다 — 결과는 수퍼블록이 아니라 **"도로만 지워진 블록 넷"**이고, 빈 십자 띠가 그대로 남는다. 그래서 span을 존 인지로 병합하고, 배치는 **대표 셀(사전순 최소)에서 한 번만** 돈다. 셀마다 돌리면 같은 병합 구간에 밀도가 셀 수 배로 겹친다.

### 존별 지면색은 휘도로 가를 수 없다

네 지구의 지면은 D1(인접 표면 휘도차 ≥ 0.05)과 D4(어떤 지면도 우물만큼 어둡지 않다)를 지키려면 **[아스팔트 0.37, 커브 0.72] 사이 좁은 띠 안**에 전부 들어가야 한다. 그 안에서 넷을 휘도로 벌리면 서로 붙거나 D1을 깬다.

그래서 Z1은 조명 배율에 불변인 **채널 우세도**로 판정한다 — 초록 우세도 `g = G - (R+B)/2`, 파랑 우세도 `b = B - (R+G)/2`. 규격은 값이 아니라 **순서**다.

```
g(공원 0.328) > g(주거 0.237) > g(상업 0.108) > g(도심 0.002)     그리고    물만 파랗다(b = 0.255)
```

모든 채널이 같은 배율로 곱해지면 차도 같은 배율로 곱해지므로 이 순서는 조명·톤매핑을 타지 않는다. 팔레트는 렌더 후에도 어느 채널도 1.0에 붙지 않도록 낮춰 잡았다 — 클리핑되면 채널 차가 뭉개진다(옛 커브색은 실제로 1.0000으로 포화해 있다).

### AI는 목표가 아니라 경로에서 막힌다

강이 생기자 "목표가 강 건너"가 일상이 됐다. `move_to`의 축별 슬라이드가 둑을 따라 미끄러지게 해 주지만, `choose_target`이 sight 70 안의 최근접 먹이를 계속 고르는데 **강폭이 32뿐**이라 강 건너 먹이가 최근접인 상황이 흔하다. 배회 지점만 다시 뽑는 완화로는 부족하다 — 목표도 함께 일정 시간 제외해야 풀린다(120프레임 실이동 < 0.5m → 재추첨 + 600프레임 블랙리스트). 경로 탐색은 도입하지 않았다.

### 판정기의 계측 파생 상수는 전부 다시 유도했다

`plan()`이 바뀌면 판정기에 박힌 **실측 유래 상수**가 통째로 깨진다. 그대로 두고 "기존 판정 전부 PASS"를 목표로 삼으면 정상 구현이 red가 된다. 재유도하고, 갱신한 상수마다 고장 주입을 다시 걸었다.

| 상수 | 옛값 | 새값 | 근거 |
|---|---|---|---|
| `RESTART_PROPS` | 3876 | **2236** | 수역 64셀(테두리 52 + 강 12 — 테두리 행과 강 열이 두 칸 겹친다)은 비고, 공원 10셀은 수퍼블록 셋으로 합치고, 걷힌 도로의 보도·차도 프롭이 사라졌다 |
| `MIN_BOUL_ROAD` | 230 | **164** | 실측 329의 절반 |
| `MIN_BOUL_WALK` | 320 | **152** | 실측 304의 절반 |
| `MIN_CANOPY_PROPS` | 475 | **343** | 실측 687의 절반 |

`PERIOD_TOL`은 선언만 있고 쓰이지 않는 상수였다(D3는 "D1·D2를 통과한 서로 다른 블록 2개 이상"으로 판정한다). 존별 지면색이 D3와 충돌할까 걱정할 필요가 없었던 이유다.

### 판정이 증거를 못 찾던 자리 — 브라우저 게이트의 위약

작업 전 baseline에서 브라우저 판정 둘(`--judge3`·`--judge4`)이 **창 크기 셋에서 전부** `탐침 프레임에 배경이 없다`로 떨어졌다(1568×779 · 1160×760 · 900×900). 데스크톱 1152×648은 통과했다. 렌더 결함이 아니라 **판정이 증거를 못 찾은 것**이었다.

배경 띠는 원경에서 **최상단 몇 픽셀로 눌린 활 모양**인데(`shots/boul_far_probe.png`), `background_pixel`이 y 4칸·x 16칸 격자로 화면의 1/64만 훑고 있었다. 캔버스 크기가 조금만 달라지면 격자가 통째로 비켜간다. 그대로 두면 브라우저 게이트가 **창 크기에 따라 뒤집히는 위약**이다.

요구하는 증거는 그대로 두고(마젠타 우세 픽셀이 실제로 있어야 한다) 탐색만 촘촘히 했다. 보통 첫 몇 행에서 찾고 곧장 빠져나오므로 비용도 거의 없다. 주입(지면 448 → 4000)이 여전히 탈락시키는 것을 확인했다.

### 겹친 구멍 둘이 같은 개체를 각각 삼키고 있었다

G2(총 면적 보존)가 성장 14.18 대 기대 7.37로 잡았다. `queue_free()`는 프레임 끝에 실행되고 그때까지 `is_instance_valid`가 참이라, 구멍 둘이 겹친 자리에서는 **같은 프레임에 두 구멍이 같은 개체를 각각 삼킨다.** 면적이 공짜로 두 배 늘어난다.

선재 결함이고, AI 궤적이 바뀌면서 드러났다(`pick_wander`의 난수 소비량이 달라졌다). 소멸에 기대지 않고 `swallowable.consumed`로 한 번만 세도록 못을 박았다. 고친 뒤 G2는 45.5473 대 45.5473으로 정확히 일치한다.

### 새 기준 — 전부 고장 주입으로 검증했다

`--judge7` 하나에 모았다. 존 표본은 **톱다운 카메라**로 찍는다 — 표본이 화면 한가운데로 떨어져 투영·가림·거리 페이드를 걱정할 필요가 없다.

| 기준 | 묻는 것 | 주입 | 결과 |
|---|---|---|---|
| Z1 | 존별 지면색의 순서 | 존 텍스처를 한 칸 민다 | F ✓ |
| Z2 | 공원 수퍼블록 안에 도로가 없다 | 셰이더 도로 마스크를 끈다 | F ✓ |
| Z3 | 수역 셀 안에 프롭이 0개 | 수역 검사·프로파일 잠금을 풀어 실제로 놓이게 한다 | F ✓ |
| Z4 | 교량은 아스팔트, 나머지 강은 물 | 교량 목록을 비운다 | F ✓ |
| Z5 | 수역은 못 지나가고 교량은 지나간다 | `move_to`의 수역 가드를 없앤다 | F ✓ |
| Z6 | 공원 연결성분이 전부 직사각형이다 | 공원 한 셀을 지워 L자로 만든다 | F ✓ |

### 독립 감사가 뚫은 구멍 넷 — 판정을 다시 조였다

코드 감사 둘(각 84/100)이 **주입으로 실증한** 커버리지 구멍이 넷 있었다. 전부 "지금 깨진다"가 아니라 **"틀린 구현을 통과시킨다"**였고, 이 프로젝트에서는 그것이 곧 결함이다.

**① 셋째 교량은 아무 기준도 지키지 않았다.** `BRIDGE_ON`과 Z5 probe를 손으로 z = 0·96 둘만 적어 두었다. z = -96 교량을 `city.gd`와 셰이더에서 **동시에** 지우면 judge7·3b·5가 전부 통과한다 — 수역 셀에는 원래 프롭이 없어 T5의 개수 트립와이어에도 안 걸린다. 이제 표본을 **`SPEC_BRIDGES`에서 유도**한다. 교량을 더하면 판정이 저절로 따라온다.

**② Z2의 기준점 자체가 미검증이었다.** 잔디 기준점을 표본에서 뽑아 놓고 그 값이 잔디인지는 아무도 묻지 않았다. 존 텍스처를 한 칸 민 주입에서 기준점이 −0.0294(무채색)로 떨어졌는데 "그보다 낮지 않다"는 조건은 그대로 참이라 **Z2가 통과했다.** 공원을 통째로 아스팔트로 칠해도 같다. 기준점에 절대 하한을 걸고, Z1이 이미 측정한 값을 쓰게 했다. **단방향 비교는 기준점을 단언하지 않으면 위약이다.**

**③ Z4는 "아스팔트"가 아니라 "무채색"만 단언했다.** 커브(0.72,0.72,0.70)와 도심 지면도 무채색이라 그대로 통과한다 — 교량을 보도로만 칠한 빌드가 빠져나간다. 휘도 조건을 AND로 더했는데, **절대값이 아니라 관계로 적었다**: 아스팔트는 어느 지구 지면보다 어둡고 물보다 밝다. Z1이 같은 실행에서 다섯 지면을 이미 재므로 기준점이 공짜로 있고, 팔레트나 조명을 바꿔도 규격이 그대로 성립한다.

**④ 수퍼블록의 직사각형 전제를 기계가 안 지켰다.** 병합이 축별 확장이라 L자 공원에서는 대표 셀이 여럿 나오거나 구간이 실제 영역을 넘어선다. 지도는 "사람이 읽고 고치라"고 만든 표이므로 이 회귀는 언젠가 반드시 일어난다. 주석으로만 적어 둔 전제를 Z6가 지키게 했다.

덤으로 선재 결함 하나를 더 고쳤다: **먹힌 구멍의 우물 안에서 떨어지던 개체가 고아가 됐다.** 레이어 4·마스크 0이라 아무와도 부딪히지 않고 영원히 낙하하며, 아무도 인수하지 않으므로 해제되지도 점수가 되지도 않는다. `_exit_tree`에서 함께 정리한다.

Z3의 첫 주입은 **잡히지 않았다**. `add_slot`의 수역 가드를 지워도 수역 존 프로파일의 skip 1.0이 따로 막고 있어 위반 자체가 발생하지 않았기 때문이다. 방어가 겹쳐 있으면 하나를 지우는 것으로는 주입이 성립하지 않는다 — 실제로 프롭이 물 위에 놓이는 데까지 밀어야 기준을 시험한 것이다.

Z5는 구현체의 `passable`을 부르지 않는다. **구멍을 실제로 그리로 보내고** 도착 지점을 판정기의 사본으로 본다.

G5(4a의 "지면 밖으로 나간 구멍")도 함께 넓혔다 — 이제 **물 위**도 규격 밖이다. 자유 실행 900프레임을 매 프레임 재므로 Z5가 못 보는 경로(AI가 스스로 걸어 들어가는 경우)를 덮는다. 주입(`move_to`의 수역 가드 제거)에서 `offground=90`으로 탈락한다.

**세우려다 만 기준 하나를 적어 둔다.** AI 스폰은 `move_to`를 거치지 않고 좌표를 직접 받으므로(격자 스냅) "태어난 자리가 물 위인가"를 따로 묻고 싶었다. 그런데 판정이 그 자리를 잴 수 있는 시점이 없다 — 첫 프레임이 돌면 AI가 이미 움직여 있고, G3·G4·G6 시나리오는 구멍을 전부 옮긴다. 실제로 스폰 링을 강 위로 옮기는 주입을 세 번 시도했지만 모두 "물 위에 태어났으나 첫 프레임에 육지로 빠져나온" 상태라 위반이 성립하지 않았다. **주입으로 탈락시키지 못하는 기준은 세우지 않는다** — 대신 **해로운 결과는 G7이 이미 잡는다**(물 위에서 굳은 AI는 이동 0이고 G7의 하한은 11m다). 지도를 고칠 때 스폰 링이 강·바다에 닿지 않게 하는 것은 `city.gd`의 설계 제약 주석에 남겼다.

### 문서 동기화의 사각지대 둘

§24가 만든 `sync_plan_blocks.ps1`은 열 블록을 지키고 있었다. 그런데 이 절에서 고친 **`ground_hole.gdshader`와 `hole.gd`가 그 열에 없었다.** 파일 지도(§8)는 둘 다 "전문"이라고 적어 두었지만, 실제 절 제목에 그 표기가 없어 도구가 건너뛰고 있었다. `hole.gd` 쪽은 제목에 백틱 경로가 둘(`scenes/hole.tscn`이 먼저)이라 정규식이 엉뚱한 파일을 집기도 했다.

제목을 고쳐 둘을 검사 범위로 끌어들였다. **열 블록에서 열두 블록이 됐다.** 기계가 지키지 않는 규율은 조용히 깨진다는 §24의 이야기가, 그 도구 자신의 사각지대에서 한 번 더 반복된 셈이다.

### 회귀

**데스크톱 Forward+ 열 종 · 데스크톱 Compatibility 열 종 · 브라우저 게이트 아홉 종 — 스물아홉 번 전부 PASS.** 신규 주입 6종(Z1~Z5 + 배경 탐색)을 더해 누적 91종이다.
문서 대조는 `어긋난 블록 0개 / 전체 12개`로 끝난다.

### 남긴 한계

- **§24의 한계는 그대로다** — Chrome 하나·기계 하나. 이번에도 넓히지 않았다.
- **놀이 영역이 384×384로 줄었다.** 바다 테두리 한 줄만큼이다. 지면 메시를 키우는 길은 위에서 막혔으므로, 더 넓히려면 격자 자체를 키워야 한다.
- **기슭에 걸친 구멍은 허용이다.** Z5는 구멍 **중심**만 본다 — 원반 절반이 물 위에 걸치는 것은 "강기슭이 파인" 연출이고, 반경 마진으로 막으면 교량 진입로 접근까지 막힌다. 구현자가 이를 버그로 오인해 고치지 말 것.
- **교량에는 프롭이 없다.** Z3를 "수역 셀 안에 프롭 0개"라는 예외 없는 단언으로 두기 위한 선택이다. Phase B의 주행 차량은 교량을 건너므로, 그때 M3에 교량 예외를 명시해야 한다(PLAN2 §4에 적어 두었다).
- **교량의 시각 경계와 통과 경계가 1.6m 어긋난다.** 셰이더는 교량 자리에 보도(반폭 8.5)까지 그리는데 `passable`은 아스팔트(6.5)까지만 연다. 보도처럼 보이는 띠에 구멍 중심이 못 올라간다. 보수적인 쪽이라 두었지만 두 사본의 경계가 다르다는 것은 기록해 둔다.
- **강 양안의 걷힌 도로 자리는 빈 띠로 남는다.** 공원은 병합으로 옛 도로 자리까지 채웠지만(A4), 강기슭은 `span_x`가 여전히 없어진 도로의 커브에서 멈춰 폭 ~6.8m의 프롭 없는 띠가 두 줄 생긴다. 강변 완충지로 읽히므로 그대로 두었다 — **의도한 것이지 누락이 아니다.**
- **judge7은 존 지도의 어긋남을 표본 다섯 점 밖에서 스스로 잡지 못한다.** 지도를 한쪽만 고치면 3b의 E2(구역 이탈)와 5의 T5(프롭 수 정확 일치)가 잡는다 — 게이트 전체로는 막히지만 judge7 단독으로는 아니다.
- **`zone_of`가 셀을 실측 발자국 중심에서 뽑는다.** 구현체는 슬롯 중심 `pos`로 뽑는데 콜라이더에는 XZ 오프셋이 있어, 셀 경계 근처에서 둘이 갈릴 수 있다(지금은 안 갈린다 — E2 bad=0). §25가 존 파생을 셀 인덱스에 얹으면서 새로 생긴 민감도다.
- **존별 밀도·스케일 배수는 체감으로 조정할 값이다.** 유저가 아직 길게 플레이하지 않았다.

---

## §26. 게임 UI와 손가락 — 시작·결과 화면, 포인터 조작 (구현·검증 완료, rev.25)

유저 지적의 셋째는 "게임 UI 필요" 였다. 그런데 실제로 더 급한 결함이 그 안에 있었다: **입력이 키보드뿐인데 배포처가 웹이다.** 휴대폰으로 열면 구멍이 한 칸도 움직이지 않는다. 배포된 게임의 절반이 죽어 있었던 셈이고, 그래서 PLAN2는 UI(C)를 교통(B)보다 앞에 두었다.

### 손가락과 커서를 하나의 방향 벡터로

입력을 해석하는 자리를 `input_dir()` 하나로 모았다. 키보드·터치·마우스 셋이 들어오고 나가는 것은 방향 벡터 하나다 — `move_hole`은 그 벡터만 안다.

- **터치**: 누른 자리를 원점으로 삼는 **플로팅 조이스틱**. 화면 어디를 눌러도 된다. 고정 조이스틱은 세로 화면에서 엄지가 닿지 않는 자리에 놓이기 쉽다.
- **마우스**: 커서 쪽으로 간다. 데스크톱에서는 이쪽이 조이스틱보다 자연스럽다.
- 손가락은 **하나만** 조종에 쓴다. 둘째 손가락이 방향을 빼앗으면 조작이 튄다.

화면 벡터를 월드로 옮기는 식은 카메라 리그의 함수다. 카메라에 요(yaw)가 없고 구멍 바로 뒤 위에서 내려다보므로 화면 +x가 월드 +x, 화면 아래가 월드 +z다. **판정기는 이 함수를 부르지 않고 사본을 든다** — 부르면 축을 뒤집은 빌드가 자기 값끼리 일치해 통과한다.

InputMap으로 정식화하지는 않았다. §14가 미룬 부채이지만 그 값어치는 **키 재배치**인데 아직 아무도 그것을 필요로 하지 않고, `project.godot`에 `InputEventKey`를 손으로 직렬화하는 것은 이 프로젝트가 반복해서 밟은 함정이다(V1~V3b). 대신 "입력을 읽는 자리가 하나"라는 실질을 얻었다 — 재배치가 필요해지면 그 함수만 바꾼다.

### 화면 셋과 HOME 상태

`enum State`에 `HOME`이 앞에 붙었다. 게임은 시작 화면에서 열리고, **판정 모드는 이 상태로 들어가지 않는다** — 스물아홉 종이 전부 "부팅 즉시 플레이 상태"를 전제하므로 그 앞에 화면 하나를 끼워 넣으면 통째로 깨진다. `Judge._ready`가 `Main._ready`보다 먼저 도는 것을 그대로 이용했다(§20의 판정 픽스처와 같은 장치다).

**그 한 줄이 판정 셋을 조용히 무너뜨렸다.** 판정기가 상태를 `int(_main.state) == 0` 처럼 **정수로 박아** 두고 있어서, `HOME`이 앞에 붙는 순간 T1·T5·T6이 엉뚱한 상태를 보며 전부 탈락했다. 규격을 이름으로 세웠다(`SPEC_STATE_HOME/PLAYING/OVER`). 판정기가 구현체의 enum을 읽으면 안 된다는 규율은 지키고 있었지만, **사본을 이름 없는 리터럴로 두면 규격이 바뀐 것을 사람이 알아차릴 수 없다.**

UI 노드는 코드로 만든다. `.tscn` 손작성은 이 프로젝트가 반복해서 밟은 함정이고, 화면 셋의 레이아웃을 손으로 직렬화할 이유가 없다. 다만 **노드 이름은 판정과의 계약**이다 — 이름을 안 주면 `@Label@7` 같은 기계 이름을 받고, 그러면 판정기가 자식 순서에 기대게 된다. 순서는 레이아웃을 손볼 때마다 바뀐다.

### 인게임 보강

- **크기 레벨 진행 바**. hole.io의 핵심 피드백 장치는 점수가 아니라 "내가 커지고 있다"이고, 반경 숫자(1.50)만으로는 그것이 읽히지 않는다. 반경 문턱 열 개로 1~10레벨을 나눴다.
- **킬 피드**와 **점수 팝업**. 팝업은 신호를 따로 만들지 않고 점수 차를 읽는다 — 삼킴은 한 프레임에 여럿 일어날 수 있고, 그때는 합쳐 보이는 편이 낫다.
- 킬 피드의 화살표는 **ASCII `->`** 다. `→`(U+2192)는 서브셋 밖인데다 **동적 문구에만 나타나 정적 검사를 빠져나간다** — 3초 뜨는 동안만 글자가 비는 결함은 육안으로도 놓치기 쉽다.

### 폰트 집합의 원천을 파일로 옮겼다

음절이 26 → **42자**로 늘었다(시작·결과 화면, 조작 안내, 레벨 표시). §21은 서브셋 스크립트를 "열 줄짜리"라고만 적고 저장소에 넣지 않았다. 그러면 재생성이 사람의 기억에 의존하고, 다음 사람이 같은 집합으로 굽는다는 보장이 없다. 이제 `tools/font_subset.mjs`가 집합을 들고 있고 README는 그것을 가리킨다.

**폰트만 다시 구우면 새 글자가 여전히 없다.** Godot이 `.godot/imported/`의 옛 서브셋을 계속 쓴다 — 실측으로 T8이 새 음절 16자를 전부 "글리프 없음"으로 잡았다. 캐시를 지우고 재임포트하는 절차를 README에 적었다.

T8은 이제 시작·결과 화면의 라벨·버튼까지 본다. 그것들은 판정 모드에서 **보이지 않지만 문자열은 이미 들어 있으므로** 검사에 지장이 없다 — 오히려 이쪽이 중요하다. 화면에 잠깐만 뜨는 문구가 육안으로 가장 놓치기 쉽다.

### 새 기준 — 전부 고장 주입으로 검증했다

`--judge8`은 UI만 본다. 판정 모드가 UI를 끄고 곧장 플레이로 들어가므로, **이 판정만 `judging`을 스스로 내리고** UI를 켠 뒤 상태를 손으로 몬다(4a의 자유 실행이 같은 일을 한다).

| 기준 | 묻는 것 | 주입 | 결과 |
|---|---|---|---|
| U1 | 상태마다 **역할의 노드가 전부** 보이고 문구가 비어 있지 않다 | 시작 화면을 늘 켜 둔다 / 부제만 끈다 / 부제 문구를 비운다 | F ✓ (셋 다) |
| U1 | 재시작이 플레이로 되돌린다 | (같은 경로) | — |
| U2 | 화면 드래그 → 월드 방향 (5방향) | 화면→월드 축을 뒤집는다 | F ✓ |
| U2 | 손을 뗀 뒤에는 멈춘다 | 손뗌 처리를 없앤다 | F ✓ |
| U3 | 시작 버튼이 **실제로 눌린다** | 버튼이 클릭을 무시하게 한다 | F ✓ |
| U4 | **동적** 문구의 글리프가 전부 있다 | `"레벨 %d"` → `"단계 %d"` | F ✓ |
| T8확장 | 정적 UI 문구의 글리프가 전부 있다 | 서브셋 밖 음절을 문구에 넣는다 | F ✓ |
| T2개정 | 보드가 상위 셋 + 나이고 **등수**가 맞다 | 나를 뺀다 / 등수를 한 칸 민다 | F ✓ (둘 다) |

U2는 `input_dir()`만 부르지 않는다. **구멍을 실제로 움직여 본다** — 방향 벡터만 확인하면 `move_hole`이 그것을 엉뚱하게 쓰는 회귀를 놓친다. U3도 같은 이유로 `pressed` 신호를 쏘지 않고 **뷰포트에 진짜 마우스 이벤트를 밀어 넣어** 히트 테스트까지 통과시킨다.

### 독립 감사가 찾은 것 — 판정 셋과 실물 하나

감사(81/100)가 지적한 자리 중 셋은 **판정이 통과시키면 안 되는 것을 통과시키는** 종류였다.

**① 동적 문구는 어떤 판정에도 안 걸렸다.** `_level`·`_feed`·`_pop`은 `text=""`로 만들어지고 `_process`가 채우는데, 판정 모드에서는 `set_process(false)`라 T8 시점에 전부 빈 문자열이고 T8은 빈 노드를 제외한다. `"레벨 %d"`를 `"단계 %d"`로 바꾸면 웹에서 두 글자가 조용히 사라지는데 **열한 종이 전부 통과한다.** 이 프로젝트가 가장 무서워하는 실패 모드가 정확히 그 자리에 있었고, 위 표가 이미 막았다고 적고 있어 더 위험했다. U4가 문구를 실제로 채운 뒤 묻는다.

**② U1이 `visible`만 봤다.** 이름만 맞춰 두고 아무것도 안 그리는 구현이 통과한다. 문구가 비어 있지 않은지도 함께 본다.

**③ `any_visible`이 "하나라도 보이면 참"이었다.** 제목만 남기고 부제·안내를 꺼도 통과한다. "보여야 한다" 쪽은 **전부**, "보이면 안 된다" 쪽은 **하나도**로 갈랐다.

실물 결함 하나: **`ProgressBar`의 `mouse_filter`가 기본값(STOP)이었다.** 딤과 라벨은 IGNORE로 두었는데 이것만 빠져서, 플레이 중 좌하단 246×12px — 휴대폰 엄지가 놓이기 쉬운 자리 — 에서 시작한 터치가 `_unhandled_input`에 닿지 못했다. 모바일 입력이 Phase C를 앞당긴 이유였으므로 가벼운 누락이 아니다.

그 밖에 함께 고친 것: 마우스 눌림을 이벤트로 기억하지 않고 매번 묻는다(포커스를 잃으면 릴리즈가 안 와서 구멍이 흘러간다) · 시작 화면에서 구멍의 물리를 멈춘다(스폰 지점에 걸친 프롭이 판이 시작하기 전에 삼켜졌다) · `judge8`이 끝나며 `judging`을 되돌린다 · 계획에 있었으나 빠졌던 **조이스틱 시각 피드백**과 **보드 압축(상위 3 + 나)**.

### 회귀

**데스크톱 Forward+ 열한 종 · 데스크톱 Compatibility 열한 종 · 브라우저 게이트 열 종 — 서른두 번 전부 PASS.** 신규 주입 10종(U1 셋 · U2 둘 · U3 · U4 · T8확장 · T2 둘)을 더해 누적 107종이다.

### 남긴 한계

- **실기 검증은 사람 몫이다.** 터치 경로는 판정이 합성 이벤트로 시험하지만, 실제 휴대폰의 화면 크기·DPI·주소창 높이에서 버튼이 눌리는지는 기계가 답하지 않는다.
- **UI 레이아웃은 앵커 기반이라 극단적 종횡비에서 겹칠 수 있다.** 세로로 아주 긴 화면에서 시작 버튼과 조작 안내가 가까워진다. 감사가 기본 해상도에서 제목·부제 상자가 약 24px 겹친다고 지적해 부제를 아래로 내렸지만, **상자 겹침 자체를 기계가 보지는 않는다.**
- **결과 화면에 통계가 없다.** 파괴율·최다 포식 카테고리·신기록은 Phase D(리텐션)의 몫이고, 그 앞에 저장이 있어야 한다.
- **InputMap 정식화는 여전히 미이행이다**(위 근거 참조).

### `scripts/ui.gd` (전문)

```gdscript
extends CanvasLayer

## §26: 게임 UI — 시작 화면 · 인게임 보강 · 결과 화면.
##
## 노드를 **코드로 만든다.** `.tscn` 손작성은 이 프로젝트가 반복해서 밟은 함정이고
## (§0-D 의 V1~V3b), 화면 셋의 레이아웃을 손으로 직렬화할 이유가 없다. 도시 프롭이
## 코드 생성인 것과 같은 판단이다.
##
## 기존 HUD 라벨 넷(Label·Timer·Board·Over)은 `main.tscn` 에 그대로 둔다 —
## 판정 T8 이 그 넷을 이름으로 찾고, 게임오버 문구는 이미 `main.gd` 가 채운다.
## 여기서는 **덧붙이기만** 한다.

const FONT := preload("res://assets/fonts/hud_kr.ttf")

## 크기 레벨 구간. 반경이 이 문턱을 넘을 때마다 레벨이 오른다.
## hole.io 의 핵심 피드백 장치는 "점수" 가 아니라 **"내가 커지고 있다"** 이고,
## 반경 숫자(1.50)만으로는 그것이 읽히지 않는다.
## 시작 반경 1.5 에서 1레벨, 지도를 비울 만한 45 에서 10레벨이다.
const LEVEL_R := [1.5, 2.5, 4.0, 6.0, 9.0, 13.0, 18.0, 25.0, 34.0, 45.0]

## 킬 피드가 한 줄을 띄워 두는 시간(초).
const FEED_SEC := 3.0
## 점수 팝업이 떠 있는 시간(초).
const POP_SEC := 1.0
## 가상 조이스틱의 베이스·노브 반경(픽셀). 노브가 베이스 밖으로 나가지 않게
## 이동량을 (베이스 - 노브) 로 자른다.
const STICK_R := 56.0
const STICK_KNOB_R := 24.0

## 화면 문구. **여기의 한글 음절은 전부 `tools/font_subset.mjs` 의 집합 안에 있어야
## 한다** — 없는 글자는 에러 없이 사라진다. 문구를 고치면 폰트를 다시 굽고
## 판정기의 SPEC_HUD_CHARS 도 함께 고친다.
const TXT_TITLE := "HOLE.IO"
const TXT_SUB := "도시를 삼켜라"
const TXT_START := "시작"
const TXT_HINT := "이동   WASD   화살표   드래그"   # 마우스는 누른 채 커서 쪽으로
const TXT_AGAIN := "다시 하기"
const TXT_HOME := "홈으로"

var _main: Node3D
var _dim: ColorRect
var _title: Label
var _sub: Label
var _hint: Label
var _start_btn: Button
var _again_btn: Button
var _home_btn: Button
var _level: Label
var _bar: ProgressBar
var _feed: Label
var _pop: Label
var _stick_base: Panel
var _stick_knob: Panel

var _feed_t := 0.0
var _pop_t := 0.0
var _last_score := 0


func _ready() -> void:
	_main = get_parent()
	layer = 2                                   # 기존 HUD(기본 1) 위에 그린다
	build()
	# 판정 모드에서는 시작 화면이 없다. 1a~4b 판정 전부가 "부팅 즉시 플레이 상태" 를
	# 전제하므로, 여기서 화면 하나를 끼워 넣으면 스물아홉 종이 통째로 깨진다.
	if _main.judging:
		hide_all()
	set_process(not _main.judging)


func build() -> void:
	_dim = ColorRect.new()
	_dim.name = "_dim"
	_dim.color = Color(0.05, 0.06, 0.09, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_title = make_label("_title", TXT_TITLE, 64, Vector2(0.5, 0.28), Color(1, 1, 1))
	_sub = make_label("_sub", TXT_SUB, 26, Vector2(0.5, 0.42), Color(0.75, 0.82, 0.95))
	_hint = make_label("_hint", TXT_HINT, 18, Vector2(0.5, 0.78), Color(0.62, 0.68, 0.78))

	_start_btn = make_button("_start_btn", TXT_START, Vector2(0.5, 0.55), Vector2(220, 62), 28)
	_start_btn.pressed.connect(_on_start)
	_again_btn = make_button("_again_btn", TXT_AGAIN, Vector2(0.5, 0.66), Vector2(220, 56), 24)
	_again_btn.pressed.connect(_on_again)
	_home_btn = make_button("_home_btn", TXT_HOME, Vector2(0.5, 0.78), Vector2(220, 56), 24)
	_home_btn.pressed.connect(_on_home)

	# 인게임: 크기 레벨 진행 바. 기존 점수 라벨 바로 위에 얹는다.
	_level = make_label("_level", "", 18, Vector2.ZERO, Color(1, 0.93, 0.6))
	_level.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_level.offset_left = 14.0
	_level.offset_top = -92.0
	_level.offset_right = 260.0
	_level.offset_bottom = -68.0
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_bar = ProgressBar.new()
	_bar.name = "_bar"
	# **Control 의 기본 mouse_filter 는 STOP 이다.** 그대로 두면 좌하단 246x12 px —
	# 휴대폰 엄지가 놓이기 쉬운 자리 — 에서 시작한 터치가 `_unhandled_input` 에
	# 도달하지 못해 구멍이 움직이지 않는다. 딤·라벨은 IGNORE 인데 이것만 빠져 있었다.
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.offset_left = 14.0
	_bar.offset_top = -66.0
	_bar.offset_right = 260.0
	_bar.offset_bottom = -54.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.14, 0.2, 0.85)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.78, 0.25)
	fg.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fg)
	add_child(_bar)

	# 킬 피드: 구멍이 구멍을 먹은 것을 알린다. 화살표는 ASCII `->` 다 —
	# U+2192 는 서브셋 밖이라 동적 문구에서만 나타나 T8 의 정적 검사를 빠져나간다.
	_feed = make_label("_feed", "", 20, Vector2.ZERO, Color(1, 0.72, 0.55))
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -300.0
	_feed.offset_top = 220.0
	_feed.offset_right = -12.0
	_feed.offset_bottom = 250.0
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_pop = make_label("_pop", "", 30, Vector2.ZERO, Color(1, 0.95, 0.5))
	_pop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pop.size = Vector2(160, 40)
	_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 가상 조이스틱의 시각 피드백. 플로팅이라 원점이 매번 다른데 아무것도 안 그리면
	# **어디를 기준으로 미는지도, 데드존 안인지도 보이지 않는다.**
	# 원은 StyleBoxFlat 의 모서리 반경을 절반으로 줘서 만든다 — 이미지 에셋이 필요 없다.
	_stick_base = make_ring("_stick_base", STICK_R, Color(1, 1, 1, 0.16))
	_stick_knob = make_ring("_stick_knob", STICK_KNOB_R, Color(1, 1, 1, 0.34))


func make_ring(nm: String, r: float, col: Color) -> Panel:
	var p := Panel.new()
	p.name = nm
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(r * 2.0, r * 2.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


## 노드 이름은 **판정과의 계약**이다(§26). 코드로 만든 노드는 이름을 안 주면
## `@Label@7` 같은 기계 이름을 받는데, 그러면 판정기가 역할별로 찾을 수 없고
## 자식 순서에 기대게 된다 — 순서는 레이아웃을 손볼 때마다 바뀐다.
func make_label(nm: String, t: String, size: int, anchor: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.name = nm
	l.text = t
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if anchor != Vector2.ZERO:
		l.set_anchors_preset(Control.PRESET_CENTER_TOP)
		l.anchor_left = anchor.x
		l.anchor_right = anchor.x
		l.anchor_top = anchor.y
		l.anchor_bottom = anchor.y
		l.offset_left = -400.0
		l.offset_right = 400.0
		l.offset_top = 0.0
		l.offset_bottom = float(size) * 1.4
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func make_button(nm: String, t: String, anchor: Vector2, sz: Vector2, size: int) -> Button:
	var b := Button.new()
	b.name = nm
	b.text = t
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.44, 0.86) if st == "normal" \
			else (Color(0.24, 0.55, 0.95) if st == "hover" else Color(0.12, 0.34, 0.68))
		sb.set_corner_radius_all(10)
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		b.add_theme_stylebox_override(st, sb)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = -sz.x * 0.5
	b.offset_right = sz.x * 0.5
	b.offset_top = 0.0
	b.offset_bottom = sz.y
	add_child(b)
	return b


## 판정 모드용. 이 노드가 그리는 것을 전부 숨긴다.
func hide_all() -> void:
	for c in get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false


func _on_start() -> void:
	_main.begin_round()


func _on_again() -> void:
	_main.restart()


func _on_home() -> void:
	_main.restart()
	_main.state = _main.State.HOME
	_main.set_ai(false)
	_main.set_holes_physics(false)     # 시작 화면에서 세계가 계속 먹지 않게


func kill_feed(eater: String, prey: String) -> void:
	_feed.text = "%s -> %s" % [eater, prey]
	_feed_t = FEED_SEC


func _process(dt: float) -> void:
	if _main == null:
		return
	var st: int = _main.state
	var home: bool = st == _main.State.HOME
	var over: bool = st == _main.State.OVER
	_dim.visible = home or over
	_title.visible = home
	_sub.visible = home
	_hint.visible = home
	_start_btn.visible = home
	_again_btn.visible = over
	_home_btn.visible = over

	# 기존 HUD(레이어 1)는 이 CanvasLayer(2) 아래에 그려진다. 그대로 두면
	#   · 시작 화면 뒤로 점수·타이머·순위판이 비치고
	#   · 결과 문구가 딤에 깔려 읽히지 않는다.
	# 홈에서는 통째로 감추고, 결과에서는 **레이어를 딤 위로 올린 뒤** 인게임 지표만 끈다.
	var hr: CanvasLayer = _main.hud_root
	hr.visible = not home
	hr.layer = 3 if over else 1
	_main.hud.visible = not over
	_main.hud_timer.visible = not over
	_main.hud_board.visible = not over

	# 인게임 요소는 플레이 중에만.
	var play: bool = not home and not over
	_level.visible = play
	_bar.visible = play
	if play and _main.player_alive():
		var r: float = float(_main.hole.radius)
		var lv := 1
		for i in LEVEL_R.size():
			if r >= float(LEVEL_R[i]):
				lv = i + 1
		_level.text = "레벨 %d" % lv
		var lo: float = float(LEVEL_R[lv - 1])
		var hi: float = float(LEVEL_R[mini(lv, LEVEL_R.size() - 1)])
		_bar.value = 1.0 if lv >= LEVEL_R.size() else clampf((r - lo) / maxf(hi - lo, 1e-3), 0.0, 1.0)

	# 가상 조이스틱: 손가락이 눌려 있는 동안만 보인다. 원점은 main.gd 가 쥐고 있고
	# 여기서는 그리기만 한다 — 입력을 해석하는 자리는 하나여야 한다.
	var stick: bool = play and int(_main._touch_id) >= 0
	_stick_base.visible = stick
	_stick_knob.visible = stick
	if stick:
		var o: Vector2 = _main._touch_start
		var d: Vector2 = _main._touch_cur - o
		if d.length() > STICK_R - STICK_KNOB_R:
			d = d.normalized() * (STICK_R - STICK_KNOB_R)
		_stick_base.position = o - Vector2(STICK_R, STICK_R)
		_stick_knob.position = o + d - Vector2(STICK_KNOB_R, STICK_KNOB_R)

	_feed_t = maxf(_feed_t - dt, 0.0)
	_feed.visible = _feed_t > 0.0 and play

	# 점수 팝업: 점수가 오른 만큼을 구멍 위에 띄운다. 신호를 따로 만들지 않고
	# 차이를 읽는다 — 삼킴은 한 프레임에 여럿 일어날 수 있고, 그때는 합쳐 보이는 편이 낫다.
	var sc: int = int(_main.score)
	if play and sc > _last_score:
		_pop.text = "+%d" % (sc - _last_score)
		_pop_t = POP_SEC
	_last_score = sc
	_pop_t = maxf(_pop_t - dt, 0.0)
	_pop.visible = _pop_t > 0.0 and play and _main.player_alive()
	if _pop.visible:
		var cam: Camera3D = _main.cam
		var p: Vector3 = _main.hole.global_position
		if not cam.is_position_behind(p):
			_pop.position = cam.unproject_position(p) - Vector2(80.0, 60.0 + (1.0 - _pop_t) * 30.0)
		_pop.modulate.a = clampf(_pop_t / POP_SEC, 0.0, 1.0)
```

---

## §27. 도로 위를 실제로 달리는 차 (구현·검증 완료, rev.26)

유저 지적 (2) 의 첫 줄이다 — **"도로의 차들이 움직여야 함".** §13 이후 도시의 차는 전부 세워져 있었고, 움직이는 것은 구멍 여섯 개뿐이었다.

### 주차와 주행은 같은 자리를 쓸 수 없다

계획(PLAN2 B1)이 감사에서 정정받은 자리이고, 실제로 수치가 그렇다. 대로의 옛 정차 자리 셋을 중앙선 기준 |u| 로 펴 보면

| 자리 | 중심 | 차지하는 띠 |
|---|---|---|
| 안쪽 | 2.4125 | [1.05, 3.775] |
| 가운데 | 3.775 | [1.05, 6.5] |
| 바깥 | 5.1375 | [3.775, 6.5] |

주행 차선을 어디에 놓아도 앞의 둘과 겹친다. **정차 차량은 frozen 강체라 충돌 해소가 없고, 주행차가 그것을 그대로 뚫고 지나간다.** 바깥 자리 하나만 남기고 주행은 [1.05, 3.775] 를 쓴다.

일반 도로(폭 8m)는 손대지 않았다. 그 폭에 주행과 노상 주차는 공존할 수 없고(주차차가 |u| ∈ [0, 4] 를 다 쓴다), 그렇다고 주차를 걷어내면 도시의 차가 대부분 사라진다. 그래서 **교통은 대로에만 흐른다** — 넓은 간선은 살아 움직이고, 주택가는 조용히 주차돼 있다. 도시로서 어색하지 않은 분업이다.

### 좁게 잡은 규격 둘

- **차선 그래프를 저장하지 않는다.** 대로(중심선 mod 3 == 0)와 §25 의 도로 마스크에서 유도한다. 지도를 고치면 교통이 저절로 따라온다.
- **교차로에서 꺾지 않는다.** 꺾으려면 교차로 점유와 출구 여유를 관리해야 하고, 정지 차량이 하나라도 있으면 막힘이 전파되는 그리드락이 생긴다(감사가 지적한 모드다). 직진만 하면 그 상태 공간이 통째로 사라진다. 차는 대로를 끝까지 달리고 반대편 입구에서 다시 난다.

우측통행이다. 진행 방향 d 의 오른쪽은 `(-d.z, d.x)` 이므로 **축마다 부호가 뒤집힌다** — 동서 도로는 +x 로 갈 때 u = +안쪽, 남북 도로는 +z 로 갈 때 u = -안쪽. 이것이 `driving_lanes` 가 축을 인자로 받는 이유다.

### 판정이 세 가지를 잡았다

**① 형제 순서에 기댄 스폰.** `Traffic._ready` 에서 차를 냈더니 **판정 모드에서도 차가 났다.** 노드 `_ready` 는 자식 → 부모 순서인데, 씬에서 Traffic 이 Judge 보다 앞에 있어 `judging` 이 세워지기 전에 돌았다. M4 가 잡았다. 이제 `Main._ready` 가 부른다 — 그것은 **모든 자식보다 늦게** 도는 것이 보장된다.

**② 전 구간이 닫힌 차선.** 바다 테두리에 접한 대로(±6)는 한쪽 셀이 늘 수역이라 §25 의 마스크가 전 구간을 걷어낸다. 그런데 그것을 차선 목록에 넣어 두어, 차가 **없는 도로 위를 달렸다.** M3 가 프레임마다 잡았다. 한 칸도 열리지 않은 차선은 버린다.

**③ 판정 자신의 비대칭.** M2(결정성)가 정상 빌드에서 탈락했다. 두 실행의 위치가 차마다 0.1~0.2m 씩 달랐는데, 그 값이 **정확히 한 물리 프레임 × 그 차의 속도** 였다 — M1 실행은 M3 표본을 끼고 돌아 대기 구조가 한 칸 어긋나 있었다. 재현성의 질문은 "같은 시드가 같은 흐름을 내는가" 이지 "판정의 대기 구조가 같은가" 가 아니다. 대칭인 헬퍼를 두 번 부르게 고쳤다.

### 눈으로 본 것이 또 틀렸다

두 프레임을 찍어 보고 "버스가 진행 방향 기준 왼쪽 차선에 있다" 고 읽었다. 그래서 **M6(우측통행)** 을 세웠는데 — 정상 빌드가 통과했다. 차선을 맞바꾸는 주입에서만 탈락한다. 육안 판단이 틀렸던 것이다(`screenshot-is-not-measurement` 가 또 맞았다).

다만 M6 자체는 남길 값어치가 있다. M3 는 오프셋의 **크기**만 보므로, 두 차선을 통째로 맞바꾼 빌드 — 마주 오는 차끼리 같은 차선을 쓰는 도시 — 를 그대로 통과시킨다.

### 새 기준 — 전부 고장 주입으로 검증했다

| 기준 | 묻는 것 | 주입 | 결과 |
|---|---|---|---|
| M1 | 차가 실제로 움직인다(300프레임 평균 변위 ≥ 20m) | 컨트롤러 틱을 끈다 | F ✓ |
| M2 | 같은 시드면 같은 흐름 | (대칭 헬퍼 두 번 비교) | — |
| M3 | 매 프레임 규격 차선 위 · 걷힌 세그먼트 위 0대 | 도로 마스크를 무시한다 | F ✓ |
| M4 | 전용 요청 없이는 판정에 동적 개체 0 | 판정 모드에서도 스폰한다 | F ✓ |
| M5 | 달리는 차가 구멍에 삼켜져 점수가 된다 | (컨트롤러 끄기에 함께 걸린다) | F ✓ |
| M6 | 우측통행 | 좌우 차선을 맞바꾼다 | F ✓ |
| E7b개정 | 정차차가 주행 차선을 침범하지 않는다 | 주차를 옛 안쪽 자리로 되돌린다 | F ✓ (172건) |

E7b 는 "규격 자리 셋이 전부 쓰였는가" 였다. 주차 자리가 하나로 줄어 그 질문이 의미를 잃었으므로, **계획이 경고한 결함 자체**를 묻도록 바꿨다: 대로의 정차 프롭은 |u| 하한이 주행 차선 밖이어야 한다.

### G7 을 고쳤다 — 배치의 운을 묻고 있었다

G7 은 AI 마다 "이만큼 움직였고 **자랐는가**" 를 물었다. 대로 주차를 주행 차선 밖으로 옮기자 대로 위에 난 AI 가 15초 동안 굶어 `dR=+0.000` 으로 탈락했다. 43.6m 를 돌아다녔는데도 그렇다.

이동은 그 AI 의 조종자가 살아 있는가라 개체마다 물어야 한다. 성장은 다르다 — 흡입은 모든 구멍이 **공유하는** 기계이므로 그것이 망가지면 아무도 자라지 못한다. 개체마다 요구하면 "그 AI 근처에 먹이가 있었는가" 라는 배치의 운을 묻게 된다. **이동은 개체마다, 성장은 합으로** 본다. 조종자를 죽이는 주입은 여전히 탈락한다.

### 계측

3c 에 "교통 on" 지점을 더했다. 동적 개체는 그리기뿐 아니라 **매 물리 프레임 위치를 다시 쓰는 비용**이 있어서, 정적 도시의 계측만으로는 예산을 말할 수 없다.

| 지점 | avg | worst |
|---|---|---|
| dense | 1.52ms | 2.17ms |
| boul | 1.47ms | 2.21ms |
| **traffic (36대)** | **1.56ms** | **2.17ms** |

예산 16.67ms 대비 여유가 크다. `car_count` 를 올릴 여지가 있지만, 데스크톱 RTX 4060 Ti 의 수치이므로 모바일 GPU 를 근거로 삼을 수는 없다.

### 재유도한 상수

`lane_slots` 가 바뀌며 배치가 통째로 다시 흔들렸다.

| 상수 | 옛값 | 새값 |
|---|---|---|
| `RESTART_PROPS` | 2236 | **2125** |
| `MIN_BOUL_ROAD` | 164 | **88** |
| `MIN_BOUL_WALK` | 152 | **162** |
| `MIN_CANOPY_PROPS` | 343 | **354** |

### 회귀

**데스크톱 Forward+ 열두 종 · 데스크톱 Compatibility 열두 종 · 브라우저 게이트 열한 종 — 서른다섯 번 전부 PASS.** 신규 주입 11종(M1~M7 + E7b + G7)을 더해 누적 118종이다.

### 독립 감사가 찾은 것 — 판정 둘이 위약이었고 코드 결함 넷이 남아 있었다

감사(61/100 불합격)가 짚은 자리다. 판정을 통과한 채로 배포된 것들이라 특히 뼈아프다.

**① `E7b` 가 통과식에 연결돼 있지 않았다.** 새 카운터를 세기만 하고 옛 조건(`자리 셋이 전부 쓰였는가`)을 지우지 않았다. 그런데 주입 실행에서 **옛 조건이 우연히 걸린 것을 새 기준이 잡은 것으로 오독했다** — 출력의 `E7=F` 만 보고 판단한 것이다. **통과식에 들어가지 않는 카운터는 판정력이 0 이다.** 판정기의 `spec_lane_slots` 사본도 옛 세 자리로 남아 있었다.

**② M1 은 주행이 아니라 순간이동을 재고 있었다.** 300프레임(5초)에 물리적 상한은 12 m/s × 5s = 60m 인데 M1 은 평균 137.1m 를 보고했다 — 절반 이상이 재스폰 도약이었다. 그러면 **속도를 0.01 로 낮춘 빌드도 통과한다**(주입으로 확인했다). 도약을 버리는 **경로장 누적**으로 바꾸고, 평균이 아니라 **중앙값**을 본다(스물넷 중 스물이 굳어도 평균은 넘어간다). 고친 뒤 43.2m — 9 m/s × 5s 와 맞는다.

**③ 인계된 차가 영원히 방치됐다.** 구멍이 스쳐 지나가기만 하면 `hold_awake(false)` 가 freeze 를 되돌리지 않고(그것은 의도된 것이다) 교통도 다시 인수하지 않는다. 주행 차선 한복판에 자유 강체가 남는데, 주행차는 매 프레임 순간이동하므로 스윕 없이 그것을 관통한다 — **§27 이 주차 자리를 줄여 가며 없애려던 상황이 판 중반부터 스스로 되살아난다.** 멈춰 선 고아를 치운다.

**④ 버스·스쿨버스·구급차가 차선보다 넓었다.** 주행 차선 반폭은 1.3625 인데 그 셋의 폭반값은 1.49~1.73 이다. §18 이 이미 같은 산술로 "가장 넓은 도로가 가장 큰 차를 거절하는 규격 오류" 라 적어 두었는데, 교통을 얹으며 그 표를 다시 밟았다. 주행 목록에서 뺐다 — 큰 차는 주차 자리에 그대로 있다.

**⑤ `restart()` 가 교통을 되돌리지 않았다.** 그 함수는 "되돌린 결과가 최초와 같다" 를 단언하는데, 차의 위치·속도·차선이 판을 넘겨 이어졌다.

덤으로 판정 둘을 조였다. M6 가 재스폰 프레임을 역주행으로 오독해 약 1% 확률로 **정상 빌드를 떨어뜨릴 수 있었고**(도약 표본을 건너뛴다), G7 의 총 성장에 하한이 없어 다섯 중 넷이 죽어도 통과했다.

### 판정이 스스로 잡은 품질 결함 둘

M7 을 세우고 순간이동을 세었더니 **900프레임에 708회**가 나왔다. 정상 재스폰이라면 열 번대여야 한다.

원인은 **추종 클램프가 차를 뒤로 밀고 있었다**는 것이다. 앞차가 바로 앞에 나거나 재스폰으로 끼어들면 `limit` 이 현재 위치보다 뒤가 되는데, 그대로 두면 차가 후진한다 — 지도 끝 밖으로 밀려 나가면 재스폰이 걸리고 다음 프레임에 또 밀려 **매 프레임 순간이동**이 된다. "뒤로는 가지 않는다" 한 줄로 708 → **15** 가 됐다.

같은 검사가 ① 의 인덱스 밀림도 잡는다(105회). 잘못 옮겨 앉은 자리도 **유효한 차선**이라 규격 검사(M3)로는 보이지 않고, 보이는 것은 그 도약뿐이다.

### 남긴 한계

- **교차로에서 직교 관통한다.** 꺾지 않는다고 충돌이 사라지지는 않는다 — 동서 차선과 남북 차선은 대로 교차마다 네 점에서 만나고, 점유 관리가 없으므로 같은 순간 같은 점을 지나면 서로를 통과한다. 직진만 하므로 순환 대기가 없어 **예약 방식으로 그리드락 없이 풀 수 있다.** 넣지 않은 것은 범위의 문제다.
- **차의 앞뒤 방향을 판정하지 않는다.** yaw 를 AABB 긴 축에서만 유도하므로 모델의 코가 어느 쪽인지는 반영되지 않는다. 일부 모델이 후진하는 모습으로 달릴 수 있다(육안 판단은 이 프로젝트에서 이미 두 번 뒤집혔으므로 단정하지 않는다).
- **시민은 아직 없다.** 유저 지적 (2) 의 둘째 줄("시민 등 동적 오브젝트")은 다음이다. 절차 생성 미니피규어로 계획해 두었다(PLAN2 B2).
- **차가 꺾지 않는다.** 위의 근거로 좁힌 규격이다. 교차로에서 갈라지는 것을 넣으려면 그리드락 회피를 함께 설계해야 한다.
- **신호등은 여전히 장식이다.** 교통과 연동돼 있지 않다.
- **차가 구멍을 피하지 않는다.** 시민은 도망치도록 계획했지만 차는 그대로 빨려든다 — hole.io 의 결도 그러하므로 의도한 것이다.
- **계측은 데스크톱 하나다.** 모바일 GPU 에서 36대가 어떤지는 이 판정이 말해 주지 않는다.

### `scripts/traffic.gd` (전문)

```gdscript
extends Node3D

## §27: 도로 위를 실제로 달리는 차.
##
## 유저 지적 (2) 의 첫 줄이다 — "도로의 차들이 움직여야 함". §13 이후 도시의 차는
## 전부 세워져 있었고, 움직이는 것은 구멍 여섯 개뿐이었다.
##
## **차선 그래프를 따로 저장하지 않는다.** 대로(중심선 인덱스 mod 3 == 0)와 §25 의
## 도로 마스크에서 유도한다 — 지도를 고치면 교통이 저절로 따라온다.
##
## 규격을 좁게 잡은 자리 둘, 근거와 함께 남긴다.
##   · **교통은 대로에만 흐른다.** 일반 도로는 폭 8m 라 노상 주차와 주행이 공존할 수
##     없고, 주차를 걷어내면 도시의 차가 대부분 사라진다(§27 의 lane_slots 참조).
##   · **교차로에서 꺾지 않는다.** 꺾으려면 교차로 점유·출구 여유를 관리해야 하고,
##     정지 차량이 하나라도 있으면 막힘이 전파되는 그리드락이 생긴다. 직진만 하면
##     그 상태 공간이 통째로 사라진다. 차는 대로를 끝까지 달리고 반대편에서 다시 난다.

const CITY := preload("res://scripts/city.gd")

## 판정 모드에서는 아무것도 만들지 않는다(PLAN2 P3). 동적 개체를 시험하는 판정만
## `spawn_for_judge()` 로 명시적으로 요청한다 — §20 의 판정 픽스처와 같은 패턴의
## 역방향이다("게임에만 존재하되, 전용 판정이 부를 때만 판정에도 존재한다").
@export var enabled := true
@export var traffic_seed := 20260730
## 동시에 달리는 차의 수. 프레임 예산의 첫 번째 손잡이다(§27 계측 참조).
@export var car_count := 36
@export var base_speed := 9.0
@export var speed_var := 3.0
## 앞차 뒤에 서는 최소 간격(m). 차 길이(최대 반길이 4.24)보다 넉넉해야 한다.
@export var follow_gap := 11.0
## 주행 차량으로 쓸 에셋. 트래픽콘은 뺀다 — 그것은 달리는 물건이 아니다.
##
## **버스·스쿨버스·구급차도 뺐다.** 편도 띠 [1.05, 6.5] 를 2등분한 주행 차선의
## 반폭은 1.3625 인데 그 셋의 폭반값은 1.49~1.73 이라, 달리면 중앙선 도색을 밟고
## 주차 띠 하단을 최대 37cm 파고든다. §18 이 이미 같은 산술로 "가장 넓은 도로가
## 가장 큰 차를 거절하는 규격 오류" 라 적어 두었는데, 교통을 얹으며 그 표를 다시
## 밟았다(독립 감사가 잡았다). 큰 차는 **주차 자리**에 그대로 남아 있다.
const MODELS := [
	{ "path": "res://assets/cars/Taxi.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/Cop.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/NormalCar1.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/NormalCar2.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/SUV.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/SportsCar.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/SportsCar2.obj", "scale": 1.0 },
]

var _city: Node3D
var _rng := RandomNumberGenerator.new()
## 각 원소: { rb, lane, s, speed }. lane 은 _lanes 의 인덱스다.
var _cars := []
var _lanes := []


## **`_ready` 에서 스폰하지 않는다.** 노드 _ready 는 자식 → 부모 순서라 형제 사이의
## 순서에 기대게 되는데, Judge 가 `judging` 을 세우기 전에 Traffic 이 먼저 돌면
## 판정 모드에서도 차가 난다(실제로 그렇게 났고 M4 가 잡았다).
## Main._ready 는 **모든 자식보다 늦게** 도는 것이 보장되므로 거기서 부른다.
## 참조만 잡는다. **스폰은 하지 않는다** — 여기서 하면 형제 순서에 기대게 된다.
## 판정이 `spawn_for_judge()` 로 직접 부르는 길도 이 참조가 있어야 열린다.
func _ready() -> void:
	_city = get_parent().get_node_or_null("City")


func boot() -> void:
	if enabled:
		spawn_all()


## 차선 목록. 대로 중심선마다 두 축 × 두 방향이다.
## 중심선 인덱스는 셀 경계이므로 범위가 셀보다 하나 넓다(-7 .. 7).
##
## **한 칸도 열려 있지 않은 차선은 버린다.** 바다 테두리에 접한 대로(±6)는 한쪽 셀이
## 늘 수역이라 전 구간이 걷혀 있는데, 그것을 차선으로 잡으면 차가 없는 도로 위를
## 달린다(M3 가 프레임마다 잡았다).
func build_lanes() -> Array:
	var out := []
	for k in range(CITY.CELL_MIN, CITY.CELL_MAX + 2):
		if not CITY.is_boulevard(k):
			continue
		for axis in ["x", "z"]:
			var open := false
			for c in range(CITY.CELL_MIN, CITY.CELL_MAX + 1):
				var lane := { "axis": axis, "line": k }
				if lane_open(lane, c):
					open = true
					break
			if not open:
				continue
			for l in CITY.driving_lanes(k, axis):
				out.append({ "axis": axis, "line": k, "u": float(l[0]), "dir": float(l[1]) })
	return out


## 이 차선에서 셀 c 구간의 도로가 존재하는가. §25 의 마스크를 그대로 쓴다 —
## 공원 안이나 다리 없는 강 위를 달리지 않는다.
func lane_open(lane: Dictionary, c: int) -> bool:
	if str(lane["axis"]) == "x":
		return CITY.seg_ew(int(lane["line"]), c)
	return CITY.seg_ns(int(lane["line"]), c)


## 차선에서 진행 방향의 **출발 셀**. dir 이 +1 이면 가장 낮은 유효 셀, -1 이면 가장 높은 셀.
func lane_entry(lane: Dictionary) -> int:
	var rng_from := CITY.CELL_MIN
	var rng_to := CITY.CELL_MAX
	if float(lane["dir"]) > 0.0:
		for c in range(rng_from, rng_to + 1):
			if lane_open(lane, c):
				return c
		return rng_from
	for c in range(rng_to, rng_from - 1, -1):
		if lane_open(lane, c):
			return c
	return rng_to


## 차선 좌표 s(월드 축 위의 위치) → 월드 좌표.
func lane_pos(lane: Dictionary, s: float) -> Vector3:
	var w := float(lane["line"]) * CITY.PITCH + float(lane["u"])
	if str(lane["axis"]) == "x":
		return Vector3(s, 0.0, w)
	return Vector3(w, 0.0, s)


func spawn_all() -> void:
	_rng.seed = traffic_seed
	_lanes = build_lanes()
	if _lanes.is_empty() or _city == null:
		return
	for i in car_count:
		var li := _rng.randi_range(0, _lanes.size() - 1)
		var lane: Dictionary = _lanes[li]
		# 유효 구간 안의 임의 지점. 없는 구간에 났으면 첫 프레임에 재배치된다.
		var c := _rng.randi_range(CITY.CELL_MIN, CITY.CELL_MAX)
		var s := float(c) * CITY.PITCH + _rng.randf() * CITY.PITCH
		var m: Dictionary = MODELS[_rng.randi_range(0, MODELS.size() - 1)]
		var rb: RigidBody3D = make_car(m, lane, s, i)
		if rb == null:
			continue
		add_child(rb)
		_cars.append({ "rb": rb, "lane": li, "s": s,
			"speed": base_speed + _rng.randf_range(-speed_var, speed_var) })


## 판정용. 판정 모드에서도 교통을 켠다 — M 계열이 이것을 명시적으로 요청한다.
func spawn_for_judge(n: int) -> void:
	car_count = n
	spawn_all()


func make_car(m: Dictionary, lane: Dictionary, s: float, idx: int) -> RigidBody3D:
	var h: Vector2 = _city.half_extent(str(m["path"]), float(m["scale"]))
	# 긴 축이 주행 축과 나란해지는 회전. 모델마다 X 로 눕기도 Z 로 눕기도 한다.
	var long_is_z: bool = h.y >= h.x
	var want_z: bool = str(lane["axis"]) == "z"
	var yaw: float = 0.0 if long_is_z == want_z else PI * 0.5
	# 진행 방향이 반대면 180도 돌린다.
	if float(lane["dir"]) < 0.0:
		yaw += PI
	var ex: Vector2 = _city.axis_extent(h, yaw)
	var it := { "path": m["path"], "scale": m["scale"], "zone": "road",
		"pos": lane_pos(lane, s), "ex": ex, "yaw": yaw }
	return _city.make_prop(it, 100000 + idx)


func _physics_process(dt: float) -> void:
	if _cars.is_empty():
		return
	# 1D 추종: 같은 차선의 차를 진행 순서로 늘어놓고 앞차와의 간격을 지킨다.
	# 차선별로 모아 두면 비교가 O(차선 안 차 수)로 줄고, 무엇보다 **다른 차선의 차를
	# 앞차로 오인하지 않는다** — 반대 방향 차선이 바로 옆에 있다.
	var by_lane := {}
	for i in _cars.size():
		var c: Dictionary = _cars[i]
		if not is_instance_valid(c["rb"]):
			continue
		if not by_lane.has(c["lane"]):
			by_lane[c["lane"]] = []
		by_lane[c["lane"]].append(i)

	# **루프 도중에 `_cars` 를 건드리지 않는다.** `by_lane` 이 인덱스를 들고 있어서,
	# 중간에서 하나를 지우면 그 뒤의 인덱스가 전부 한 칸씩 어긋난다 — 남은 차가
	# 엉뚱한 원소를 움직이고, 마지막 인덱스는 범위 밖으로 나간다.
	# 넘길 것을 모아 두었다가 **루프가 끝난 뒤 높은 인덱스부터** 처리한다.
	var to_release := []
	for li in by_lane:
		var lane: Dictionary = _lanes[li]
		var dir: float = float(lane["dir"])
		var idxs: Array = by_lane[li]
		# 진행 방향 기준으로 앞선 차가 뒤에 오도록 정렬한다.
		idxs.sort_custom(func(a: int, b: int) -> bool:
			return float(_cars[a]["s"]) * dir < float(_cars[b]["s"]) * dir)
		var ahead := INF                      # 바로 앞차의 s (진행 방향 좌표)
		for n in range(idxs.size() - 1, -1, -1):
			var i: int = idxs[n]
			var c: Dictionary = _cars[i]
			var rb: RigidBody3D = c["rb"]
			# 구멍이 감지 범위에 넣은 차는 물리에 넘긴다. hold_awake 가 freeze 를
			# 풀어 두므로 그것이 신호다. 넘길 때 주행 속도를 실어 관성을 잇는다.
			if not rb.freeze:
				to_release.append(i)
				continue
			var cur: float = float(c["s"])
			var want: float = cur + dir * float(c["speed"]) * dt
			# 앞차 뒤에 선다.
			var limit := ahead - follow_gap
			if want * dir > limit:
				want = limit * dir
			# **뒤로는 가지 않는다.** 앞차가 바로 앞에 나거나 재스폰으로 끼어들면
			# limit 이 현재 위치보다 뒤가 되는데, 그대로 두면 차가 후진한다 —
			# 지도 끝 밖으로 밀려 나가면 재스폰이 걸리고, 그 다음 프레임에 또 밀려
			# **매 프레임 순간이동**이 된다(실측: 900프레임에 708회).
			if want * dir < cur * dir:
				want = cur
			c["s"] = want
			ahead = want * dir
			var cell := int(floor(want / CITY.PITCH))
			if cell < CITY.CELL_MIN or cell > CITY.CELL_MAX or not lane_open(lane, cell):
				respawn(i)
			else:
				rb.global_position = lane_pos(lane, want)

	to_release.sort()
	for n in range(to_release.size() - 1, -1, -1):
		release(int(to_release[n]))
	# 사라진 차(재시작 등으로 노드가 해제된 것)를 정리한다. 그대로 두면 죽은 참조가
	# 쌓이고 car_total() 이 실제보다 많게 보고한다.
	for n in range(_cars.size() - 1, -1, -1):
		if not is_instance_valid(_cars[n]["rb"]):
			_cars.remove_at(n)
	sweep_orphans()


## 인계했으나 **삼켜지지 않은** 차. 구멍이 스쳐 지나가기만 하면 `hold_awake(false)` 가
## freeze 를 되돌리지 않으므로(의도된 것이다 — 되돌리면 구멍 옆에서 기울어진 채 굳는다)
## 아무도 그 차를 다시 인수하지 않는다. 그대로 두면 **주행 차선 한복판에 자유 강체가
## 영구히 남고**, 주행차는 매 프레임 순간이동하므로 스윕 없이 그것을 관통한다 —
## §27 이 주차 자리를 줄여 가며 없애려던 상황이 판 중반부터 스스로 되살아난다.
## 낙하하지 않았고 멈춰 섰으면 치운다.
var _orphans := []
const ORPHAN_STILL := 0.35


func sweep_orphans() -> void:
	for n in range(_orphans.size() - 1, -1, -1):
		var rb = _orphans[n]
		if not is_instance_valid(rb):
			_orphans.remove_at(n)
			continue
		if rb.falling:                                  # 구멍이 삼켰다 — 그쪽이 처리한다
			_orphans.remove_at(n)
			continue
		if rb.linear_velocity.length() < ORPHAN_STILL:
			_orphans.remove_at(n)
			rb.queue_free()


## 구멍에 잡힌 차를 교통에서 빼고 물리에 넘긴다.
func release(i: int) -> void:
	var c: Dictionary = _cars[i]
	var rb: RigidBody3D = c["rb"]
	var lane: Dictionary = _lanes[c["lane"]]
	var v := Vector3.ZERO
	if str(lane["axis"]) == "x":
		v.x = float(lane["dir"]) * float(c["speed"])
	else:
		v.z = float(lane["dir"]) * float(c["speed"])
	rb.linear_velocity = v
	_orphans.append(rb)
	_cars.remove_at(i)
	# 총량을 지킨다. 빠진 만큼 차선 입구에서 새로 낸다.
	spawn_one()


## 차선 끝에 닿았거나 없는 구간에 들어간 차를 반대편 입구로 되돌린다.
func respawn(i: int) -> void:
	var c: Dictionary = _cars[i]
	var lane: Dictionary = _lanes[c["lane"]]
	var entry := lane_entry(lane)
	var s := float(entry) * CITY.PITCH + CITY.PITCH * 0.5
	c["s"] = s
	if is_instance_valid(c["rb"]):
		c["rb"].global_position = lane_pos(lane, s)


func spawn_one() -> void:
	if _lanes.is_empty() or _city == null:
		return
	var li := _rng.randi_range(0, _lanes.size() - 1)
	var lane: Dictionary = _lanes[li]
	var entry := lane_entry(lane)
	var s := float(entry) * CITY.PITCH + CITY.PITCH * 0.5
	var m: Dictionary = MODELS[_rng.randi_range(0, MODELS.size() - 1)]
	var rb: RigidBody3D = make_car(m, lane, s, _rng.randi_range(0, 99999))
	if rb == null:
		return
	add_child(rb)
	_cars.append({ "rb": rb, "lane": li, "s": s,
		"speed": base_speed + _rng.randf_range(-speed_var, speed_var) })


## 판정용: 지금 교통이 조종하고 있는 차의 수.
func car_total() -> int:
	return _cars.size()


## 판정용: 차 i 의 월드 위치.
func car_pos(i: int) -> Vector3:
	return (_cars[i]["rb"] as Node3D).global_position


## 판정용: 차 i 의 개체 식별자. **인덱스는 프레임마다 달라진다**(먹힌 차가 빠지고
## 새 차가 뒤에 붙는다) — 프레임을 가로질러 같은 차를 따라가려면 이것이 필요하다.
func car_id(i: int) -> int:
	return (_cars[i]["rb"] as Node).get_instance_id()


## 판을 되돌린다. `main.gd` 의 restart() 가 부른다 — 그 함수는 "되돌린 결과가 최초와
## 같아야 한다" 를 단언하는데, 교통을 그대로 두면 위치·속도·차선이 판을 넘겨 이어지고
## 방치된 자유 강체도 누적된다.
func reset() -> void:
	for c in get_children():
		c.free()
	_cars.clear()
	_orphans.clear()
	boot()
```

---

## §28. 보도를 걷는 시민 (구현·검증 완료, rev.27)

유저 지적 (2) 의 둘째 줄이다 — "시민 등 동적 오브젝트 추가 필요". 이것으로 유저가 지적한 네 축 중 **(1) 도시 디자인 · (2) 정적인 배경 · (3) 게임 UI** 가 닫힌다.

### 에셋을 조달하지 않고 절차로 만든다

저장소에 사람 모델이 없다. 외부 팩을 들이면 라이선스·임포트·스케일 맞추기가 따라오고, 그 셋 다 이 프로젝트에서 이미 비용을 치른 항목이다. **캡슐 몸통 + 구 머리** 둘이면 이 카메라 고도에서 충분히 사람으로 읽힌다. 걷기 애니메이션 대신 **위아래 흔들림(bob)** 과 진행 방향 기울임을 준다 — 뼈대 없이 움직임이 읽히는 가장 싼 방법이다.

옷 색은 지구의 함수다. 도심은 무채색 정장, 주거는 알록달록하다. 지구제(§25)가 배치뿐 아니라 **분위기**에도 쓰인 첫 자리다.

키는 한 번 고쳤다. 처음 1.52m 로 잡았더니 화면에서 승용차와 키가 비슷해 "사람" 으로 안 읽혔다 — 1.665m 로 올렸다. 이것은 기계가 답할 질문이 아니라 **눈으로 보고 고친 것**이고, 전역 원칙 §1 이 말하는 휴먼 검수의 자리다.

### 이동은 교통과 같은 1D 다

보도 중심선 위를 오가고 구간 끝에서 **되돌아선다**(교통은 재스폰하지만 사람은 돌아서는 편이 자연스럽다). 구간은 §25 의 도로 마스크에서 유도한다 — **걷힌 도로의 보도는 맨땅**이고, 거기를 걸으면 허공을 걷는 것으로 보인다.

구멍이 자기 반경의 3.5배 안에 들어오면 **반대 방향으로 도망친다.** hole.io 의 재미가 여기 있다 — 도시가 나를 무서워하는 것이 보여야 한다. 겁먹는 거리를 절대값이 아니라 **구멍 반경의 배수**로 둔 이유: 절대 거리면 작은 구멍이 지도 반대편 사람까지 놀래거나, 큰 구멍이 코앞에 와도 안 놀란다.

**보도를 벗어나지는 않는다.** 자유 2D 로 풀면 건물·차도로 파고들고, 그것을 막으려면 충돌 회피가 통째로 필요해진다. 도망은 "돌아서서 빨리 걷는다" 로 표현한다.

### 수를 두 번 잡았다

90명으로 시작했는데 **한 화면에 한 명도 안 보였다.** 384×384m 도시에 90명은 밀도가 아니라 희소성이다. 260명으로 올렸다. 프레임 예산에 여유가 컸기에 가능한 선택이다.

| 지점 | avg | worst |
|---|---|---|
| dense (정적) | 1.53ms | 2.14ms |
| boul (정적) | 1.50ms | 2.60ms |
| **dynamic (차 36 + 시민 258)** | **1.92ms** | **4.07ms** |

예산 16.67ms 대비 여유가 여전히 크다.

### 새 기준 — 전부 고장 주입으로 검증했다

`--judge9` 에 셋을 더했다.

| 기준 | 묻는 것 | 주입 | 결과 |
|---|---|---|---|
| M4확장 | 전용 요청 없이는 판정에 **시민도** 0 | 판정 모드에서도 시민을 낸다 | F ✓ (258 검출) |
| M8 | 실제로 걷는가(도약 제외 경로장 중앙값 ≥ 4m) | 이동 틱을 끈다 | F ✓ |
| M9 | 규격 보도 위인가 · 걷힌 도로의 보도를 걷지 않는가 | 보도 마스크를 무시한다 | F ✓ |
| M10 | **겁먹은 사람이 실제로 멀어지는가** · 도망 중에도 보도 위인가 | 구멍 쪽으로 달려들게 한다 / 보도를 벗어나게 한다 | F ✓ (둘 다) |
| M4·M8·M9 | Citizens 노드 자체가 있는가 | 노드를 지운다 | F ✓ |

M8 은 M1 과 같은 이유로 **도약을 버린 경로장의 중앙값**을 본다 — 직선 변위를 재면 되돌아서는 왕복이 상쇄되어 굳은 사람과 구분되지 않고, 평균은 다수가 굳어도 통과시킨다.

### 회귀

**데스크톱 Forward+ 열두 종 · 데스크톱 Compatibility 열두 종 · 브라우저 게이트 열한 종 — 서른다섯 번 전부 PASS.** 신규 주입 6종(M4확장·M8·M9·M10 둘·노드 부재)을 더해 누적 124종이다.

### 독립 감사가 찾은 것 — 도망에 판정 커버리지가 0 이었다

감사(66/100 불합격)의 지적이다.

**① §28 의 간판 기능인 도망을 어떤 판정도 검사하지 않았다.** M8·M9 가 구멍을 지도 구석(−176,−176)에 두고 도는데, 그 자리에서 가장 가까운 보도까지 8.5m 이고 겁먹는 반경은 1.5 × 3.5 = 5.25m 다 — **도망 분기가 한 번도 실행되지 않는다.** 감사가 "구멍 쪽으로 달려들게" + "보도를 벗어나게" 를 **동시에** 주입하고도 판정을 통과시켰다. M10 을 세웠다: 구멍을 크게 놓아 fear 를 확보하고, 겁먹은 사람이 실제로 멀어지는가와 도망 중에도 보도 위인가를 묻는다. 그 두 주입이 이제 전부 탈락한다.

**② 인구가 단조 감소했다.** `fit_radius` 0.28 은 시작 반경 1.5 에도 한참 못 미쳐 닿은 사람은 사실상 전부 삼켜지는데 재스폰이 없었다 — 구멍 여섯이 2분간 훑으면 도시가 비고, **"도시가 살아 있다" 는 §28 의 존재 이유가 판 후반에 스스로 무너진다.** 빠진 만큼 **구멍에서 먼 자리**에 새로 낸다(눈앞에서 사람이 튀어나오면 그것이 더 눈에 띈다).

**③ 인계한 시민을 아무도 회수하지 않았다.** §27 이 차에서 고쳤던 것과 같은 누수다. `_orphans` 스윕을 붙였다.

**④ 시민이 보도 프롭을 관통했다.** §13 이 가로등·신호등·표지판을 **정확히 보도 중심선 위**에 세워 두었는데 시민도 같은 오프셋을 걸었다. 둘 다 frozen 강체라 충돌 해소가 없다. 시민을 차도 쪽 `road_half + 0.5` 로 옮겼다 — 프롭은 중앙에 남는다.

**⑤ `Citizens` 노드가 없으면 세 기준이 조용히 통과했다.** `cz == null` 을 통과로 두면 노드를 지운 빌드에서 M4확장·M8·M9 가 전부 P 로 인쇄된다 — **"기능이 아예 없다" 가 가장 센 고장인데 그것을 못 잡는다.**

덤: M8 의 문턱 근거가 틀렸다. "왕복이 섞여 짧아진다" 로 4.0 을 정당화했는데 **상쇄되는 것은 변위이고 경로장은 왕복에 영향받지 않는다.** 실제 하한 7.2m 에 맞춰 6.0 으로 올렸다. `scare` 도 목록의 마지막 구멍이 아니라 **가장 가까운** 구멍을 고르게 했다.

### 남긴 한계

- **시민이 서로를 피하지 않는다.** 같은 보도 구간에서 겹쳐 지나간다(교통의 1D 추종에 해당하는 것이 없다). 사람은 차보다 작고 겹침이 덜 눈에 띄지만, 밀도를 더 올리면 보일 것이다.
- **횡단보도를 건너지 않는다.** 한 보도 구간 안에서만 오간다 — 구간을 갈아타려면 교차로 통과 규칙이 필요하고, 그것은 교통의 교차로 문제와 같은 크기다.
- **도망이 축 방향으로만 일어난다.** 구멍이 보도에 수직으로 다가오면 방향 전환이 약하게 읽힌다.
- **키·비율·옷 색은 휴먼 검수의 몫이다**(전역 원칙 §1). 판정이 보는 것은 "걷는가 · 규격 위인가 · 판정에 안 섞이는가" 셋뿐이다.

### `scripts/citizens.gd` (전문)

```gdscript
extends Node3D

## §28: 보도를 걷는 시민.
##
## 유저 지적 (2) 의 둘째 줄이다 — "시민 등 동적 오브젝트 추가 필요".
##
## **에셋을 조달하지 않고 절차로 만든다.** 저장소에 사람 모델이 없고, 외부 팩을 들이면
## 라이선스·임포트·스케일 맞추기가 따라온다. 캡슐 몸통 + 구 머리 둘이면 이 카메라
## 고도에서 충분히 "사람" 으로 읽힌다. 걷기 애니메이션 대신 **위아래 흔들림(bob)** 과
## 진행 방향 기울임을 준다 — 뼈대 없이 움직임이 읽히는 가장 싼 방법이다.
##
## 이동 모형은 교통(§27)과 같은 1D 다. 보도 중심선 위를 오가고, 구간 끝에서 **되돌아선다**
## (교통은 재스폰하지만 사람은 돌아서는 편이 자연스럽다).
##
## 구멍이 다가오면 **반대 방향으로 도망친다.** hole.io 의 재미가 여기 있다 — 도시가
## 나를 무서워하는 것이 보여야 한다. 다만 보도를 벗어나지는 않는다: 자유 2D 로 풀면
## 건물·차도로 파고들고, 그것을 막으려면 충돌 회피가 통째로 필요해진다.

const CITY := preload("res://scripts/city.gd")
const SWALLOWABLE := preload("res://scripts/swallowable.gd")

@export var enabled := true
@export var citizen_seed := 20260731
@export var citizen_count := 260
@export var walk_speed := 1.8
## 도망칠 때의 배속. 걷기와 확연히 달라야 "놀랐다" 로 읽힌다.
@export var flee_mult := 2.6
## 구멍이 **자기 반경의 이 배수** 안에 들어오면 도망친다. 절대 거리로 두면 작은 구멍이
## 지도 반대편 시민까지 놀래거나, 큰 구멍이 코앞에 와도 안 놀란다.
@export var fear_k := 3.5
## 시야 밖(구멍에서 이 거리 이상)은 네 프레임에 한 번만 갱신한다.
@export var lod_dist := 80.0

## 몸 치수(m). 총 키 = BODY_H + HEAD_R*1.75 = 1.665 — 승용차 지붕(1.4)보다 확실히 크다.
## 처음 1.52 로 잡았더니 화면에서 승용차와 키가 비슷해 "사람" 으로 안 읽혔다.
const BODY_R := 0.20
const BODY_H := 1.28
const HEAD_R := 0.22

## 지구별 옷 색. 도심은 무채색 정장, 주거는 알록달록하다.
const COATS := {
	0: [Color(0.22, 0.24, 0.30), Color(0.30, 0.31, 0.34), Color(0.16, 0.18, 0.24)],
	1: [Color(0.72, 0.36, 0.28), Color(0.28, 0.44, 0.62), Color(0.66, 0.58, 0.26)],
	2: [Color(0.80, 0.42, 0.44), Color(0.36, 0.62, 0.44), Color(0.74, 0.66, 0.36)],
	3: [Color(0.36, 0.60, 0.38), Color(0.70, 0.52, 0.30), Color(0.44, 0.50, 0.68)],
}
const SKIN := Color(0.85, 0.70, 0.58)

var _rng := RandomNumberGenerator.new()
## 각 원소: { rb, mesh, axis, line, u, lo, hi, s, dir, speed, phase }
var _people := []
## 인계했으나 삼켜지지 않은 사람. 멈춰 섰으면 치운다(§27 의 교통과 같은 이유).
var _orphans := []
const ORPHAN_STILL := 0.35
var _tick := 0


func sweep_orphans() -> void:
	for n in range(_orphans.size() - 1, -1, -1):
		var rb = _orphans[n]
		if not is_instance_valid(rb):
			_orphans.remove_at(n)
			continue
		if rb.falling:                                  # 구멍이 삼켰다 — 그쪽이 처리한다
			_orphans.remove_at(n)
			continue
		if rb.linear_velocity.length() < ORPHAN_STILL:
			_orphans.remove_at(n)
			rb.queue_free()


func _ready() -> void:
	pass


func boot() -> void:
	if enabled:
		spawn_all()


## 보도 구간 목록. 도로가 **존재하는** 세그먼트의 양쪽 보도만 쓴다(§25 마스크) —
## 걷힌 도로의 보도는 맨땅이고, 거기를 걸으면 허공을 걷는 것으로 보인다.
## 한 구간은 [축, 중심선 인덱스, 보도 오프셋, 시작 셀, 끝 셀] 이다.
## 보도 안에서 시민이 걷는 오프셋. **보도 중심선이 아니다** — 거기에는 §13 이
## 가로등·신호등·표지판·덤불을 정확히 그 자리(walk_center_at)에 세워 두었다.
## 둘 다 frozen 강체라 충돌 해소가 없고 시민은 매 프레임 위치를 덮어쓰므로,
## 중심선을 걸으면 **가로등을 그대로 통과한다**(감사가 잡았다).
## 보도 폭이 2.0 이므로 차도 쪽에 붙여 [+0.3, +0.7] 를 점유한다 — 프롭은 중앙에 남는다.
static func walk_lane_u(k: int) -> float:
	return CITY.road_half_at(k) + 0.5


func build_walks() -> Array:
	var out := []
	for k in range(CITY.CELL_MIN, CITY.CELL_MAX + 2):
		var wc := walk_lane_u(k)
		for axis in ["x", "z"]:
			# 열린 셀이 이어지는 구간마다 하나씩 만든다.
			var run_lo := 9999
			for c in range(CITY.CELL_MIN, CITY.CELL_MAX + 2):
				var open: bool = c <= CITY.CELL_MAX and (
					CITY.seg_ew(k, c) if axis == "x" else CITY.seg_ns(k, c))
				if open and run_lo == 9999:
					run_lo = c
				elif not open and run_lo != 9999:
					for side in [-1.0, 1.0]:
						out.append({ "axis": axis, "line": k, "u": side * wc,
							"lo": float(run_lo) * CITY.PITCH + 2.0,
							"hi": float(c) * CITY.PITCH - 2.0 })
					run_lo = 9999
	# 너무 짧은 구간은 버린다 — 한 걸음에 양 끝을 오가면 제자리에서 떠는 것으로 보인다.
	var keep := []
	for w in out:
		if float(w["hi"]) - float(w["lo"]) >= 12.0:
			keep.append(w)
	return keep


func walk_pos(p: Dictionary, s: float) -> Vector3:
	var w := float(p["line"]) * CITY.PITCH + float(p["u"])
	if str(p["axis"]) == "x":
		return Vector3(s, 0.0, w)
	return Vector3(w, 0.0, s)


func spawn_all() -> void:
	_rng.seed = citizen_seed
	var walks := build_walks()
	if walks.is_empty():
		return
	for i in citizen_count:
		var w: Dictionary = walks[_rng.randi_range(0, walks.size() - 1)]
		var s := _rng.randf_range(float(w["lo"]), float(w["hi"]))
		var pos := walk_pos(w, s)
		# 판정 광장은 비운다(§13 과 같은 이유 — 판정 시나리오에 섞이면 안 된다).
		if Vector2(pos.x, pos.z).length() < CITY.PLAZA_R:
			continue
		var dz := CITY.zone_at(CITY.cell_of(pos.x), CITY.cell_of(pos.z))
		var rb := make_person(dz, pos, i)
		add_child(rb)
		_people.append({ "rb": rb, "mesh": rb.get_child(0),
			"axis": w["axis"], "line": w["line"], "u": w["u"],
			"lo": w["lo"], "hi": w["hi"], "s": s,
			"dir": 1.0 if _rng.randf() < 0.5 else -1.0,
			"speed": walk_speed * _rng.randf_range(0.8, 1.25),
			"phase": _rng.randf() * TAU })


## 새 시민이 날 자리. **구멍에서 먼 구간**을 고른다 — 눈앞에서 사람이 튀어나오면
## 그것이 더 눈에 띈다. 시행 횟수를 고정해 난수 소비량을 결과와 분리한다.
func here_far_from(holes: Array) -> Dictionary:
	var walks := build_walks()
	var best := {}
	var best_d := -1.0
	for _i in 6:
		if walks.is_empty():
			break
		var w: Dictionary = walks[_rng.randi_range(0, walks.size() - 1)]
		var s := _rng.randf_range(float(w["lo"]), float(w["hi"]))
		var pos := walk_pos(w, s)
		var d := INF
		for h in holes:
			if is_instance_valid(h):
				d = minf(d, Vector2(pos.x - h.global_position.x,
					pos.z - h.global_position.z).length())
		if d > best_d:
			best_d = d
			best = { "w": w, "s": s }
	return best


## 한 명을 낸다. 자리는 here_far_from 이 고른다.
func spawn_one(spot: Dictionary) -> void:
	if spot.is_empty():
		return
	var w: Dictionary = spot["w"]
	var s: float = float(spot["s"])
	var pos := walk_pos(w, s)
	if Vector2(pos.x, pos.z).length() < CITY.PLAZA_R:
		return
	var dz := CITY.zone_at(CITY.cell_of(pos.x), CITY.cell_of(pos.z))
	var rb := make_person(dz, pos, _rng.randi_range(0, 99999))
	add_child(rb)
	_people.append({ "rb": rb, "mesh": rb.get_child(0),
		"axis": w["axis"], "line": w["line"], "u": w["u"],
		"lo": w["lo"], "hi": w["hi"], "s": s,
		"dir": 1.0 if _rng.randf() < 0.5 else -1.0,
		"speed": walk_speed * _rng.randf_range(0.8, 1.25),
		"phase": _rng.randf() * TAU })


## 판정용. 판정 모드에서도 시민을 낸다 — M 계열이 명시적으로 요청한다.
func spawn_for_judge(n: int) -> void:
	citizen_count = n
	spawn_all()


func make_person(dz: int, pos: Vector3, idx: int) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(SWALLOWABLE)
	body.collision_layer = 2
	body.collision_mask = 1 | 2
	body.name = "Citizen_%d" % idx
	body.position = pos
	body.add_to_group("swallowable")
	body.start_frozen = true

	# 몸통과 머리를 한 노드 아래 묶는다. 흔들림은 이 노드만 움직이므로
	# 콜라이더는 제자리에 있고 **접지 판정(E5)이 흔들리지 않는다.**
	var pivot := Node3D.new()
	pivot.name = "Body"
	body.add_child(pivot)

	var coat: Color = (COATS[dz] if COATS.has(dz) else COATS[2])[idx % 3]
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = BODY_R
	cm.height = BODY_H
	torso.mesh = cm
	torso.position.y = BODY_H * 0.5
	var mt := StandardMaterial3D.new()
	mt.albedo_color = coat
	torso.material_override = mt
	pivot.add_child(torso)

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = HEAD_R
	sm.height = HEAD_R * 2.0
	head.mesh = sm
	head.position.y = BODY_H + HEAD_R * 0.75
	var mh := StandardMaterial3D.new()
	mh.albedo_color = SKIN
	head.material_override = mh
	pivot.add_child(head)

	# 콜라이더는 몸 전체를 덮는 상자 하나다. 캡슐로 두면 구멍 가장자리에서 굴러
	# 나가고, 삼킴 판정(§23)이 보는 것은 **꼭대기 높이**뿐이라 상자로 충분하다.
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var top := BODY_H + HEAD_R * 1.75
	box.size = Vector3(BODY_R * 2.0, top, BODY_R * 2.0)
	cs.shape = box
	cs.position.y = top * 0.5
	body.add_child(cs)

	body.mass = 3.0
	return body


func _physics_process(dt: float) -> void:
	sweep_orphans()
	if _people.is_empty():
		return
	_tick += 1
	var holes: Array = get_node("/root/HoleRegistry").holes()
	for n in range(_people.size() - 1, -1, -1):
		var p: Dictionary = _people[n]
		var rb: RigidBody3D = p["rb"]
		if not is_instance_valid(rb):
			_people.remove_at(n)
			continue
		# 구멍이 붙잡은 사람은 물리에 넘긴다(§27 의 차와 같은 신호).
		# **넘긴 뒤를 챙겨야 한다.** 구멍이 스쳐 지나가기만 하면 `hold_awake(false)` 가
		# freeze 를 되돌리지 않으므로(의도된 것이다) 아무도 그 사람을 다시 인수하지
		# 않는다 — 보도 위에 자유 강체가 영구히 남는다. §27 이 차에서 겪은 것과 같다.
		if not rb.freeze:
			_orphans.append(rb)
			_people.remove_at(n)
			# **총량을 지킨다.** 시민에게는 재스폰이 없었는데, fit_radius 0.28 은 시작
			# 반경 1.5 에도 한참 못 미쳐 닿은 사람은 사실상 전부 삼켜진다 — 구멍 여섯이
			# 2분간 훑으면 인구가 단조 감소하고, "도시가 살아 있다" 는 §28 의 존재 이유가
			# 판 후반에 스스로 무너진다(감사가 잡았다). 빠진 만큼 **화면 밖에서** 새로 낸다.
			spawn_one(here_far_from(holes))
			continue
		var here := walk_pos(p, float(p["s"]))
		# 멀리 있는 사람은 네 프레임에 한 번만 갱신한다. 갱신할 때 네 배로 걸으므로
		# 평균 속도는 같다 — 가까이 왔을 때 갑자기 위치가 튀지 않는다.
		var far := true
		var scare := Vector3.ZERO
		var near := INF
		for h in holes:
			if not is_instance_valid(h):
				continue
			var d := Vector2(here.x - h.global_position.x, here.z - h.global_position.z)
			if d.length() < lod_dist:
				far = false
			# **가장 가까운 위협**을 고른다. 그냥 덮어쓰면 목록의 마지막 구멍이 이기고,
			# 코앞의 구멍을 두고 멀리 있는 구멍의 반대쪽으로 달아나는 일이 생긴다.
			if d.length() < float(h.radius) * fear_k \
					and (scare == Vector3.ZERO or d.length() < near):
				near = d.length()
				scare = Vector3(d.x, 0.0, d.y)
		if far and _tick % 4 != 0:
			continue
		var step: float = float(p["speed"]) * dt * (4.0 if far else 1.0)
		if scare != Vector3.ZERO:
			# 구멍 반대쪽으로 돈다. 보도를 벗어나지 않으므로 진행 축의 성분만 본다.
			var away: float = scare.x if str(p["axis"]) == "x" else scare.z
			if away != 0.0:
				p["dir"] = signf(away)
			step *= flee_mult
		var s: float = float(p["s"]) + float(p["dir"]) * step
		if s < float(p["lo"]):
			s = float(p["lo"])
			p["dir"] = 1.0
		elif s > float(p["hi"]):
			s = float(p["hi"])
			p["dir"] = -1.0
		p["s"] = s
		rb.global_position = walk_pos(p, s)
		# 진행 방향으로 돌려 세우고, 걸음에 맞춰 위아래로 흔든다.
		var yaw: float = 0.0
		if str(p["axis"]) == "x":
			yaw = PI * 0.5 if float(p["dir"]) > 0.0 else -PI * 0.5
		else:
			yaw = 0.0 if float(p["dir"]) > 0.0 else PI
		rb.rotation.y = yaw
		var mesh: Node3D = p["mesh"]
		var t: float = float(_tick) * 0.18 + float(p["phase"])
		mesh.position.y = absf(sin(t)) * 0.06
		mesh.rotation.x = sin(t * 2.0) * 0.05


## 판을 되돌린다. main.gd 의 restart() 가 부른다(§27 의 교통과 같은 이유).
func reset() -> void:
	for c in get_children():
		c.free()
	_people.clear()
	_orphans.clear()
	boot()


## 판정용.
func citizen_total() -> int:
	return _people.size()


func citizen_pos(i: int) -> Vector3:
	return (_people[i]["rb"] as Node3D).global_position


func citizen_id(i: int) -> int:
	return (_people[i]["rb"] as Node).get_instance_id()
```

## §29. 카메라가 멀미를 만들지 않는다 — 회전 상수·후퇴 감속 (구현·검증 완료, rev.28)

유저가 배포본을 **휴대폰으로 플레이하고** 준 피드백 4건 중 첫째다 — "멀미가 난다". 플레이 불가에 가까운 문제라 가장 먼저 닫는다.

### 원인은 추정하지 않고 실측했다

카메라를 계측 하네스로 몰았다(구멍을 14 m/s 로 스크립트 구동, 고정 dt 1/60). 후보였던 시민 bob 은 진폭 0.06m 로 배제, FOV 75 는 픽셀 판정 전체의 프레이밍 전제라 이번에 안 건드린다(유저 재검 후 멀미가 남으면 2차 후보). 남은 둘이 실측으로 확정됐다.

| 기제 | 실측 | 원인 |
|---|---|---|
| **회전 흔들림** | 방향 반전 시 최대 **86 °/s**, 등속 주행 시작 43~49 °/s | `look_at` 이 매 프레임 재조준 + 위치 lerp 지연(v/smooth ≈ 2.3m) → 이동 상태가 바뀔 때마다 시야 전체가 기울었다 돌아온다 |
| **성장 후퇴 스파이크** | grow_by(5.0) 에서 **83 m/s** (주행 추적 14 m/s 의 6배) | 반경이 계단으로 뛰는데 배율 k 가 즉시 목표를 따라간다 |

터치 조이스틱은 방향 변화가 잦다 — 회전 흔들림이 휴대폰에서 **상시** 발생하는 이유이고, 시야 회전은 전정계 불일치의 전형적 기제다.

### 세 가지를 고쳤다 (`camera_rig.gd`)

1. **회전을 상수로 고정.** `look_at(target)` 을 지우고 `Basis.looking_at(-base_offset)` 을 대입한다. 카메라가 목표 지점(want)에 정확히 있을 때의 look_at 과 같은 회전이므로(want − target = base_offset·k, 방향은 k 와 무관) **판정 모드(snap)의 스크린샷 프레이밍은 픽셀 판정이 구분하지 못하는 수준에서 동일하다**(픽셀 판정 26종 통과로 실증) — H9 의 앙각 40.24° 전제가 그대로다. 이동 중에는 구멍이 화면 중심에서 ~2.3m 상당 벗어났다 복귀하는 순수 병진만 남는다. 수평선이 고정된다.
2. **성장 후퇴 감속.** 배율 `_k` 를 시정수 `grow_smooth = 1.5/s` 로 지수 평활한다. snap 은 즉시 대입(판정 보존). 해석 피크 후퇴 속도 13.1 m/s — 주행 추적(14) 아래로 내려온다. 판정 실측 13.11 m/s 로 일치.
3. **프레임률 독립 평활.** lerp 계수 `clampf(smooth·dt)` → `1 − exp(−smooth·dt)`. 옛 식은 프레임률에 따라 수렴 곡선 자체가 달라진다 — 휴대폰의 가변 프레임률에서 카메라 반응이 프레임마다 출렁이던 자리다.

### 새 판정 `--judge10` (V1~V4) — 전부 고장 주입으로 실증했다

판정기가 게임 루프의 카메라 호출을 재현한다(판정 모드에서는 `main._process` 가 follow 를 안 부른다). 시간은 전부 **합성 dt** 로 센다 — 브라우저 rAF 의 실측 dt 를 쓰면 저프레임 기기에서 목표점의 계단(ZOH) 간격이 커져 정상 빌드가 속도 상한을 넘는다(해석 상계: 20fps 에서 16.7 > 16 m/s). 합성 dt 로는 세 플랫폼에서 궤적이 **허용오차 안에서** 결정적이고(wasm 과 네이티브는 libm 이 달라 비트 동일까지는 주장하지 않는다), 브라우저 게이트는 wasm 코드패스 검증만 진다. 기대값은 규격 사본(`SPEC_CAM_*`·`SPEC_START_R`·`SPEC_GROWTH_K`)으로만 계산한다 — 구현체를 읽으면 시정수를 바꾼 빌드가 자기 값끼리 일치해 통과한다.

| 기준 | 묻는 것 | 주입 | 결과 |
|---|---|---|---|
| V1 | 주행·반전·정지·성장 전 구간에서 회전이 상수인가 (율 ≤ 0.1 °/s **그리고** 누적 편차 ≤ 0.01°) | A: look_at 복원 | F ✓ (86.6 °/s) |
| V1 전제 | 구멍이 규격 경로를 실제로 달렸는가 (세그먼트 끝마다 누적 위치 대조 — 막히면 정지 카메라가 공허하게 통과한다) | F: move_to 무력화 | F ✓ (0.0 ≠ 21.0) |
| V2 상한 | 성장 후퇴 속도 ≤ 16 m/s (규격 선언 — 주행 추적 14 + 여유) | B: _k 평활 제거 | F ✓ (79.3 m/s) |
| V2 하한 | 그러면서 2.5초 안에 목표점 1m 이내로 **수렴하는가** | D: grow_smooth 0.1 | F ✓ (잔차 11.0m) |
| V3 위치 | snap 이 규격 위치를 정확히 재현하는가 (H 계열 전제) | C: snap 배율 ×0.9 | F ✓ (오차 2.17m) |
| V3 앙각 | snap 후 앙각 40.236°±0.01 · 구멍 조준 | E′: basis 방향 오염 | F ✓ (38.93°) |
| V4 | 계단 응답 잔차가 두 dt(1/30·1/120)에서 똑같이 D·e^(−6T) 인가 | E: clampf 식 복원 | F ✓ (0.352 ≠ 0.498) |

V4 는 목표가 **정지한** 계단 응답이라 ZOH 오차가 없다 — 지수 평활이면 잔차가 dt 와 무관하게 정확히 0.4979 이고(실측 두 dt 모두 0.4979), 옛 clampf 식은 1/30 에서 0.3518 로 확실히 걸린다. V2 는 상한과 하한을 함께 단언한다 — 상한만 물으면 안 움직이는 카메라가 통과한다.

주입은 계획 감사(1차 77 → 반영 후 94/100)가 요구한 지도 그대로다: 단언별 1:1 대응(A→V1, B→V2상한, C→V3위치, D→V2하한, E→V4, E′→V3앙각). 감사가 함께 잡은 것: 판정 중 구멍 물리를 안 끄면 대본 경로의 프롭이 흡입돼 기대 종점이 오염된다(`set_physics_process(false)`), V4 순간이동은 착지 전제를 단언해야 한다(move_to 는 통행 불가 지점에서 미끄러진다 — §25).

코드 감사(91/100 합격)가 둘을 더 잡았다: **① V1 의 주행 전제가 단언되지 않았다** — 배치가 바뀌어 원점 주변이 막히면 구멍이 서고, V1 은 정지 카메라를 상수 회전으로 오판해 look_at 회귀조차 못 잡는 상태로 초록이 된다(§28 의 "도망 커버리지 0" 과 같은 부류). 세그먼트 끝마다 규격 누적 위치와 대조한다 — 대본이 원점 복귀 대칭이라 끝점만 보면 못 잡는다(주입 F 로 실증). **② 율 상한만으로는 누적 회전을 못 잡는다** — 0.09 °/s 로 일정하게 돌면 대본 11초에 0.66° 가 쌓여도 통과한다. 시작 basis 대비 총 편차 ≤ 0.01° 를 함께 단언한다.

계측 하네스(cam_diag)는 지웠다 — 같은 대본을 judge10 이 흡수했고, 규격을 두 벌로 두지 않는다.

### 회귀

**데스크톱 Forward+ 열세 종 · 데스크톱 Compatibility 열세 종 · 브라우저 게이트 열두 종 — 서른여덟 번 전부 PASS.** 신규 주입 7종(A·B·C·D·E·E′·F)을 더해 누적 131종이다.

### 남긴 한계

- **멀미는 생리 반응이다.** 기계 판정이 지키는 것은 "회전 0 · 후퇴 상한/수렴 · 프레임률 독립" 이라는 대리 규격이고, 최종 검증은 유저의 휴대폰 재플레이다.
- FOV 75 는 그대로다. 유저 재검에서 멀미가 남으면 첫 번째 후보이지만, 픽셀 판정 전체의 프레이밍 전제라 별도 절로 다뤄야 한다.
- 이동 중 구멍이 화면 정중앙에서 살짝 벗어난다(최대 ~2.3m 상당). 원작 hole.io 도 고정 카메라다 — 중심 고정보다 수평선 고정이 멀미에 압도적으로 유리하다.

## §30. 구멍은 삼킬 수 없는 것을 끌지 않는다 — 흡입 크기 게이트 (구현·검증 완료, rev.29)

유저 플레이 피드백 3 — "자석 효과가 너무 강하다. 작은 구멍이 트럭을 끌고 다닌다."

### 원인 — 흡입이 크기를 모른다

`pull()` 은 감지 범위(Area 반경 = 구멍 반경)에 콜라이더가 걸친 모든 물체에 가속 26 m/s² 를 가했다. `rb.mass` 를 곱하므로 가속도가 질량과 무관하다(§4-D 의 의도 — 트래픽콘과 22톤 급이 같은 속도로 끌려온다). 계획 감사가 실코드 경로로 전 차량을 계측했다:

| 차량 | fit | 외접 | mass | 시작 반경 1.5 에서 |
|---|---|---|---|---|
| Taxi / Cop / Normal / Sports | 0.786~0.885 | 1.82~2.27 | 1.6~2.5 | 흡입 유지 (회색 지대 — 의도) |
| SUV | 1.016 | 2.322 | 3.4 | 흡입 유지 (회색 지대 — 의도) |
| **Ambulance** | **1.583** | 3.351 | 13.7 | **차단** (q=0.947) |
| **Bus** | **1.804** | 4.354 | 22.5 | **차단** (q=0.832) |
| **SchoolBus** | **1.867** | 4.578 | 29.6 | **차단** (q=0.803) |

에셋에 "트럭" 은 없다 — 유저가 트럭이라 부른 것은 주차된 구급차·버스·스쿨버스다(주행 함대에는 대형차가 없다, §27). 셋 다 게이트에 걸린다. 택시·SUV 는 fit < R < 외접의 **회색 지대**라 여전히 흡입된다 — 얹힌 채 잠깐 끌리다 기울어 삼켜지는 것은 §23 의 의도된 거동이고, 유저 재검에서 이것이 다시 신고되면 그때 별도로 다룬다.

### 규격 — 계단형 게이트

**`fit_radius > radius` 이면 흡입력 0, 아니면 기존 흡입 그대로.** (`hole.gd pull()` 한 자리)

- §23 두 경계 계약과 정합: 반드시 삼켜지는 집합(외접 < R)은 외접 ≥ fit 이라 항상 흡입을 유지하고, 절대 안 삼켜지는 집합(fit > R)이 정확히 흡입 0 집합이다.
- 경사(램프)가 아니라 계단인 이유: 문턱을 1 위로 올리면 보장 집합 경계가 흡입을 잃고, 아래로 내리면 구급차(q=0.947)가 부분 흡입을 받아 문제가 남는다. R 은 단조 증가라 경계 깜빡임도 없다.
- 흡입 세기(26)·질량 무관 가속은 유지 — 불만은 "끌려오면 안 되는 것이 끌려온다" 이지 "삼켜질 것이 빨리 온다" 가 아니다.
- 낙하물 회수 안전: 낙하 시점에 fit < R 이었고 `set_radius` 호출자(grow_by·bite)는 둘 다 비감소다.

### 새 판정 — judge6 에 K7·K8 (양방향, 고장 주입 실증)

| 기준 | 묻는 것 | 주입 | 결과 |
|---|---|---|---|
| K7 견인 금지 | fit 3.162 > R 2.0 인 wide 를 구멍 옆(x=4)에 세우면 240프레임 동안 XZ 변위 < 0.10m. 전제: 감지에 실제로 들어갔다(림 전환 = mask 8비트) — 안 걸치면 공허 통과 | G1: 게이트 제거 | F ✓ (4.01m 견인) |
| K8 옆-흡입 보장 | 2×2×2(fit 1.414, q=1.414)를 구멍 옆(x=2.5)에 세우면 흡입이 끌어와 삼킨다(실측 111프레임) | G2: 게이트를 fit×1.5 로 과욕 | F ✓ (흡입 0, 생존) |

K1~K6 은 픽스처를 구멍 **정중앙**에 놓아 흡입이 1e-6 가드로 no-op 이다 — 견인·옆-흡입은 K7·K8 이 처음 묻는 질문이다. fall_run 에 위치 인자를 추가했고 기존 다섯 시행은 기본값(중심)으로 무변경이다.

### K8 이 캔 것 — 경계 5% 는 기하로는 통과, 물리로는 쐐기

K8 을 보장 집합의 경계(q=1.053, 여유 5%)에 붙이려던 첫 시도는 **실측이 기각했다**: 외접 1.9 < R 2.0 인 정육면체가 옆에서 끌려오다 **기울면 투영 반경이 커져** 최저 y −0.3 에서 끼었다. 여유 15%(q=1.176)도 같았다. 옆-흡입 보장이 성립하는 조건은 외접이 아니라 **공간 대각 반경 < R** 이다 — 2×2×2 는 1.732 < 2.0 이라 어떤 자세로 굴러도 낄 수 없다. §23 의 "외접 < R 이면 반드시 삼켜진다" 는 **정중앙 낙하**(K1 이 단언하는 것)에서 성립하고, 옆-흡입 경로의 보장은 더 좁다. 게이트 판별 정밀도는 그래서 [q=0.63(K7), q=1.41(K8)] 괄호까지다 — 그 사이의 어긋난 문턱은 두 기준이 못 가른다.

### 회귀

**데스크톱 Forward+ 열세 종 · Compatibility 열세 종 · 브라우저 게이트 열두 종 — 서른여덟 번 전부 PASS.** 신규 주입 2종(G1·G2)을 더해 누적 133종이다. 계획 감사 93/100.

### 남긴 한계

- 회색 지대(택시·SUV 등 fit < R < 외접)의 잔존 견인은 의도다 — 유저가 재차 신고하면 그때 다룬다.
- 게이트 경계 판별은 [0.63, 1.41] 괄호 밖만 보장한다.
- 대형차가 걸린 채 흡입만 0 이 되므로, 림 위에 얹혀 덜컹이는 시각 효과는 남는다(§23 림의 거동 — 의도).
