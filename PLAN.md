# hole.io 클론 — 구현 계획 + 1a~4b 구현 · 플레이 재조정 (rev.16)

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
> **1a·1b·2·3a·3b·3c·4a·4b는 구현 완료 상태다 — 로드맵의 전 단계가 끝났다.** `project.godot` / `scenes` / `scripts` / `shaders` / `assets`가 이 문서와 함께 저장소에 있고, 이 문서의 모든 코드 블록은 그 파일들과 **바이트 단위로 동일**하다(기계 대조 — rev.16에서 12개 파일 전부 재확인).
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
| 3a | 도로·보도·노면표시를 지면 셰이더에 통합 + 도시 격자 + 판정기 정비 | **완료** — D1~D5 PASS, 고장 주입 7종 검증(§12). 지면은 §17에서 320×320으로 확대 |
| 3b | Quaternius 에셋 임포트 + 절차적 도시 배치(건물·차량·가로시설물·녹지) | **완료** — E1~E6 PASS, 프롭 **3832개**(§17), 고장 주입 7종 검증(§13) |
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
[gd_scene load_steps=13 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]
[ext_resource type="Shader" path="res://shaders/ground_hole.gdshader" id="2"]
[ext_resource type="PackedScene" path="res://scenes/hole.tscn" id="3"]
[ext_resource type="Script" path="res://scripts/screenshot.gd" id="4"]
[ext_resource type="Script" path="res://scripts/camera_rig.gd" id="5"]
[ext_resource type="PackedScene" path="res://scenes/swallowable.tscn" id="6"]
[ext_resource type="PackedScene" path="res://scenes/swallowable_big.tscn" id="7"]
[ext_resource type="Script" path="res://scripts/city.gd" id="8"]

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

[node name="S0" parent="Swallowables" instance=ExtResource("6")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -6, 1.31, -8)

[node name="S1" parent="Swallowables" instance=ExtResource("6")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.31, -9)

[node name="S2" parent="Swallowables" instance=ExtResource("6")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 6, 1.31, -9)

[node name="S3" parent="Swallowables" instance=ExtResource("6")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 11, 1.31, -4)

[node name="S4" parent="Swallowables" instance=ExtResource("6")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -11, 1.31, -5)

[node name="S5" parent="Swallowables" instance=ExtResource("6")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3, 1.31, -14)

[node name="City" type="Node3D" parent="."]
script = ExtResource("8")

[node name="Judge" type="Node" parent="."]
script = ExtResource("4")

[node name="B0" parent="Swallowables" instance=ExtResource("7")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 16, 2, -2)

[node name="B1" parent="Swallowables" instance=ExtResource("7")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 14, 2, -12)

[node name="HUD" type="CanvasLayer" parent="."]

[node name="Label" type="Label" parent="HUD"]
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 14.0
offset_top = -44.0
offset_right = 460.0
offset_bottom = -12.0

[node name="Timer" type="Label" parent="HUD"]
anchor_left = 0.5
anchor_right = 0.5
offset_left = -80.0
offset_top = 10.0
offset_right = 80.0
offset_bottom = 42.0
horizontal_alignment = 1

[node name="Board" type="Label" parent="HUD"]
anchor_left = 1.0
anchor_right = 1.0
offset_left = -230.0
offset_top = 10.0
offset_right = -12.0
offset_bottom = 210.0

[node name="Over" type="Label" parent="HUD"]
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

### A. 지면 셰이더 (`shaders/ground_hole.gdshader`)

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
uniform float road_half   = 4.0;    // 아스팔트 반폭
uniform float curb_half   = 6.0;    // 보도 바깥 경계 반폭
uniform float lane_half   = 0.30;   // 중앙선 반폭 (60cm — 실제 도로보다 굵다.
                                    // 게임 카메라 거리에서 판독되려면 이 정도가 필요하다:
                                    // 0.18 에서는 블록 하나 건너면 화면 2.3px 로 뭉갠다)
uniform float cross_w     = 1.6;    // 교차로 바깥 횡단보도 띠 폭
uniform float cross_pitch = 1.2;    // 횡단보도 줄무늬 주기

uniform vec3 ground_color : source_color = vec3(0.45, 0.65, 0.35);
uniform vec3 road_color   : source_color = vec3(0.36, 0.37, 0.40);
uniform vec3 curb_color   : source_color = vec3(0.72, 0.72, 0.70);
uniform vec3 lane_color   : source_color = vec3(0.88, 0.80, 0.25);
uniform vec3 cross_color  : source_color = vec3(0.90, 0.90, 0.87);

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

void fragment() {
	vec2 p = world_pos.xz;
	float hp = block_pitch * 0.5;
	// 가장 가까운 도로 중심선까지의 부호 있는 축별 거리.
	// ux 는 남북 도로(x = k*pitch), uz 는 동서 도로(z = j*pitch) 기준이다.
	float ux = mod(p.x + hp, block_pitch) - hp;
	float uz = mod(p.y + hp, block_pitch) - hp;

	vec3 col = ground_color;
	col = mix(col, curb_color, max(aa_band(ux, curb_half), aa_band(uz, curb_half)));
	col = mix(col, road_color, max(aa_band(ux, road_half), aa_band(uz, road_half)));

	// 중앙선은 도로 중심선 위에 그리되 교차로에서는 끊는다.
	float inter = step(abs(ux), road_half) * step(abs(uz), road_half);
	col = mix(col, lane_color,
		max(aa_band(ux, lane_half), aa_band(uz, lane_half)) * (1.0 - inter));

	// 횡단보도: 교차로 바로 바깥의 도로 위 줄무늬. 중앙선 위에 덮인다.
	float cw_x = step(abs(ux), road_half)
		* step(road_half, abs(uz)) * step(abs(uz), road_half + cross_w);
	float cw_z = step(abs(uz), road_half)
		* step(road_half, abs(ux)) * step(abs(ux), road_half + cross_w);
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

### B. 우물 (`scenes/hole.tscn`의 `Well`) / `scripts/hole.gd`

```gdscript
extends Node3D

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
## 흡입 가능 상한: obj_radius <= radius * swallow_ratio 인 것만 반응한다.
## 이 게이트가 없으면 구멍보다 큰 오브젝트가 통과 조건을 영원히 만족하지 못한 채
## 림에서 계속 떤다(§4-D-2 의 한계).
@export var swallow_ratio := 0.45
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


func can_swallow(obj_radius: float) -> bool:
	return obj_radius <= radius * swallow_ratio


## 구멍을 지면 안에 붙잡아 이동시킨다. 밖으로 나가면 우물이 허공에 뜨고
## 판정 전제도 깨진다. 플레이어와 AI 가 같은 함수를 쓴다.
func move_to(p: Vector3) -> void:
	var lim: float = ground_half - radius * 1.15
	global_position = Vector3(clampf(p.x, -lim, lim), 0.0, clampf(p.z, -lim, lim))


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


func _physics_process(_dt: float) -> void:
	var here := global_position

	for i in range(_candidates.size() - 1, -1, -1):
		var rb := _candidates[i]
		if not is_instance_valid(rb):
			_candidates.remove_at(i)
			continue
		# 크기 게이트는 매 프레임 재평가한다 — 구멍이 자라면 전에 막혔던 것이 열린다.
		# 막힌 오브젝트에는 흡입력도 주지 않는다(주면 림에서 영원히 떤다).
		if not can_swallow(rb.radius):
			continue
		var d := Vector2(rb.global_position.x - here.x, rb.global_position.z - here.z)
		if d.length() + rb.radius < radius:
			# 완전히 구멍 안 → 지면·서로에 대한 충돌을 끊고 낙하시킨다
			rb.begin_fall()
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
		if rb.global_position.y < kill_y:
			_falling.remove_at(i)
			grow_by(rb.radius)
			score += int(rb.score_value)
			swallowed_count += 1
			swallowed.emit(rb)
			rb.queue_free()
			kill_y = -well_depth() * kill_ratio      # 성장으로 우물이 깊어졌다
		else:
			pull(rb, here)


func pull(rb: RigidBody3D, here: Vector3) -> void:
	var to_center := Vector3(here.x - rb.global_position.x, 0.0, here.z - rb.global_position.z)
	if to_center.length_squared() < 1e-6:
		return
	rb.apply_central_force(to_center.normalized() * suction * rb.mass)
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
@export var radius := 0.0
## 점수. 0 이하이면 단면적에 비례해 산출한다(큰 것을 삼킬수록 많이 받는다).
@export var score_value := 0
## 구멍이 다가올 때까지 정적으로 세워 둘 것인가.
## 이유는 **성능 하나**다 — 도시 프롭 수백 개를 매 프레임 시뮬레이션할 이유가 없다.
## (자세를 지키기 위한 것이 아니다. 고정을 해제해도 180 물리 프레임 동안 최대
##  이동 0.9mm·기울기 0.0001rad 로 멀쩡히 서 있다 — 실측. 초기 스크린샷에서
##  가로등이 넘어진 것처럼 보였던 것은 광각 원근의 착시였다.)
@export var start_frozen := false

var falling := false

var _can_sleep_default := true


func _ready() -> void:
	_can_sleep_default = can_sleep
	if radius <= 0.0:
		radius = auto_radius()
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


## 구멍 안으로 완전히 들어왔을 때 hole.gd 가 호출한다.
## 지면(layer 1)과 다른 오브젝트(layer 2) 양쪽에서 떨어져 나온다.
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

@export var base_offset := Vector3(0.0, 22.0, 26.0)
@export var base_radius := 5.0
@export var smooth := 6.0
## 카메라 최저 높이. 반경에 정비례만 시키면 시작 반경 1.5 에서 높이가 6.6m 로
## 내려가 12~14m 짜리 건물이 시야를 막는다. 배율을 통째로 clamp 하므로
## 앙각(40.2°)은 그대로 유지된다 — H9·판정 전제가 반경과 무관해진다.
@export var min_height := 14.0


func follow(target: Node3D, radius: float, snap: bool, dt := 0.0) -> void:
	var k: float = maxf(radius / base_radius, min_height / base_offset.y)
	var want := target.global_position + base_offset * k
	if snap:
		global_position = want
	else:
		global_position = global_position.lerp(want, clampf(smooth * dt, 0.0, 1.0))
	look_at(target.global_position)
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

@onready var hud_root: CanvasLayer = $HUD
@onready var hud: Label = $HUD/Label
@onready var hud_timer: Label = $HUD/Timer
@onready var hud_board: Label = $HUD/Board
@onready var hud_over: Label = $HUD/Over

# --- 4b: 게임 루프 ---------------------------------------------------------
enum State { PLAYING, OVER }
## 한 판의 길이(초). 판정기가 짧게 줄여 종료까지 돌린다.
@export var round_seconds := 120.0
var state := State.PLAYING
var time_left := 0.0
## 승자의 label 과 그때의 점수. 판정기가 독립 계산한 최댓값과 대조한다.
var winner := ""
var winner_score := 0
## 종료 사유 — "time"(시간 만료) 또는 "eaten"(플레이어가 먹힘).
var over_reason := ""

## 재시작 때 판정 대상 8개를 원래 자리에 되살리기 위한 기록.
## _ready 에서 한 번만 찍어 두고 이후에는 읽기만 한다.
var _judge_set_spec: Array = []

## 플레이어 점수. 구멍이 진실 원천이고 여기서는 되읽기만 한다
## (2단계 판정의 C3 가 이 이름으로 읽는다).
var score: int:
	get:
		return hole.score if is_instance_valid(hole) else 0

var swallowed_total: int:
	get:
		return hole.swallowed_count if is_instance_valid(hole) else 0


func _ready() -> void:
	registry.set_target_material(ground.get_surface_override_material(0))
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
	record_judge_set()
	time_left = round_seconds
	update_hud()


## 판정 대상(씬에 손으로 놓은 8개)의 원본 씬과 위치를 기록한다.
## restart() 가 이것으로 되살린다 — 삼켜져 free 된 것은 되돌릴 방법이 없다.
func record_judge_set() -> void:
	var box := get_node_or_null("Swallowables")
	if box == null:
		return
	for c in box.get_children():
		_judge_set_spec.append([c.scene_file_path, c.name, (c as Node3D).transform])


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
		for spec in _judge_set_spec:
			var n: Node3D = load(spec[0]).instantiate()
			n.name = spec[1]
			box.add_child(n)
			n.transform = spec[2]

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
	if judging or state == State.OVER:
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
		registry.unregister(eaten)
		ai_holes.erase(eaten)
		var was_player: bool = eaten == hole
		eaten.queue_free()
		n += 1
		if was_player:
			end_game("eaten")      # 플레이어가 먹히면 그 자리에서 판이 끝난다
			return n
	return n


## InputMap 을 쓰지 않는다 — project.godot 에 InputEventKey 를 손으로 직렬화하는 것은
## 오류가 잦다. 1단계 한정이며 2단계에서 InputMap 으로 정식화한다.
func move_hole(dt: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if v == Vector3.ZERO:
		return
	set_hole_position(hole.global_position + v.normalized() * MOVE_SPEED * dt)


## 구멍이 지면 밖으로 나가면 우물이 허공에 뜨고 판정 전제도 깨진다.
func set_hole_position(p: Vector3) -> void:
	hole.move_to(p)


func _on_swallowed(_node: Node3D) -> void:
	update_hud()


func update_hud() -> void:
	if player_alive():
		hud.text = "SCORE %d    R %.2f    삼킴 %d" % [score, hole.radius, swallowed_total]
	else:
		hud.text = "SCORE %d    (먹힘)" % score
	hud_timer.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	hud_board.text = leaderboard_text()
	hud_over.visible = state == State.OVER
	if state == State.OVER:
		var head := "시간 종료" if over_reason == "time" else "먹혔다"
		var mine := "승리" if winner == "P" else "패배"
		hud_over.text = "%s\n1위 %s  %d점\n당신: %s (%d점)\nR 키로 다시 시작"\
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
	var lines := PackedStringArray(["순위  이름   점수    R"])
	for i in hs.size():
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
; 이 오버라이드가 없으면 브라우저에서 렌더러 초기화가 실패한다.
; 실측: Compatibility 에서도 착시는 성립한다 — `--rendering-driver opengl3` 로
; 1a 판정을 돌려 H1·H2·H7·H8(rim_aa=16/32)·H9 가 전부 통과했다.
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
- 판정 플래그는 여덟 가지다: `--judge`(1a) / `--judge1b` / `--judge2` / `--judge3`(3a) / `--judge3b`(도시 배치) / `--judge3c`(성능) / `--judge4`(아레나) / `--judge5`(게임 루프). 하나라도 실패하면 회귀다 — 3a의 도시 지면 기준(D1·D2·D4)은 정적 판정을 쓰는 네 가지 전부에 상시 포함된다.
- **`--judge3c` 는 다른 것과 같이 돌리지 않는다.** vsync 를 끄고 프레임 시간을 재므로, 판정 중 다른 창이 GPU 를 쓰면 수치가 흔들린다.

### `scripts/screenshot.gd` (전문 — 실행 검증본)

```gdscript
extends Node

## 1a 기계 판정. `-- --judge` 로 실행할 때만 동작하고, 그 외에는 아무것도 하지 않는다.

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
const SPEC_ROAD_HALF := 4.0                        # 아스팔트 반폭
const SPEC_CURB_HALF := 6.0                        # 보도 바깥 경계 반폭
const SPEC_LANE_HALF := 0.30                       # 중앙선 반폭 (가장 가는 특징)
const SPEC_CROSS_W := 1.6                          # 횡단보도 띠 폭
const SPEC_CROSS_PITCH := 1.2                      # 횡단보도 줄무늬 주기
const SURF_DIFF_MIN := 0.05                        # D1: 인접 표면 휘도차 하한
const PERIOD_TOL := 0.05                           # D3: 다른 블록에서 같은 표면의 휘도 허용 편차
const CROSS_GROUPS_MIN := 3                        # D2: 횡단보도 띠에서 세어야 할 엣지 그룹 수
const PROBE_MARGIN_PX := 12                        # 표본이 화면 가장자리에서 떨어져 있어야 할 여유
const PROBE_HOLE_K := 1.6                          # 표본이 구멍 중심에서 떨어져 있어야 할 반경 배수
# 규격 중앙선이 화면에서 이보다 가늘어진 블록은 표본에서 제외한다. 먼 지면에서
# 노면표시가 서브픽셀이 되어 사라지는 것은 결함이 아니라 셰이더의 정상적인 페이드다
# (실측: 64m 지점의 중앙선 휘도 = 아스팔트와 완전히 동일). 폭은 판정기의 SPEC 로
# 계산하므로 중앙선을 아예 안 그린 빌드도 이 필터를 그대로 통과해 D1 에서 걸린다.
const LANE_MIN_PX := 3.0
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
const MIN_PROPS := 300                             # E1: 도시가 실제로 생성됐는가
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
## 속도 12 로 15초면 최대 180m 다 — 30m 는 "멈춰 있지 않다" 를 보는 낮은 문턱이다.
const AI_MIN_PATH := 30.0
const OVERLAP_FRAMES := 300                        # G6 시나리오: 사냥이 성사될 때까지

# --- 4b 게임 루프 판정 ----------------------------------------------------
const ROUND_TEST_SEC := 4.0                        # T1: 판정용 짧은 라운드
const ROUND_TEST_FRAMES := 600                     # T1: 그 라운드를 덮고도 남는 프레임 수
const TIMER_TOL := 0.25                            # T1: 판정기 시계와의 허용 오차(초)
const FREEZE_FRAMES := 120                         # T3: 종료 후 상태 고정을 확인하는 프레임
const RESTART_HOLES := 6                           # T5: 재시작 후 구멍 수 (플레이어 + AI 5)
const RESTART_PROPS := 3832                        # T5: 재시작 후 도시 프롭 수 (시드 고정)
## §10 의 성장 계수. 구현체의 hole.growth_k 를 읽으면 계수만 바꾼 빌드가
## 자기 값끼리 일치해 그대로 통과한다 — 규격에서 판정기가 직접 들고 있어야 한다.
const SPEC_GROWTH_K := 1.0

# --- 3c 성능 예산 ---------------------------------------------------------
const PERF_SPOT := Vector3(-48.0, 0.0, -48.0)      # 도시가 빽빽한 지점
const PERF_FRAMES := 300
const FRAME_BUDGET_MS := 16.67                     # 60fps
const OVERLAP_EPS := 0.02                          # E3: SAT 수치 여유
# D5: 구멍을 옮겨 재판정할 규격 지점 (오브젝트가 없는 -x/+z 쪽)
const CITY_SPOTS := {
	"inter": Vector3(-32.0, 0.0, 32.0),            # 교차로 중심 (|ux|=0, |uz|=0)
	"road": Vector3(-32.0, 0.0, 16.0),             # 도로 위·교차로 밖 (|ux|=0, |uz|=16)
	"block": Vector3(-16.0, 0.0, 16.0),            # 블록 중앙 (|ux|=16, |uz|=16)
}

var _main: Node3D
var _cam: Camera3D
var _mat: ShaderMaterial
var _reg: Node
var _clamped := false                              # px() 가 화면 밖을 잘라냈는가
var _was_falling := {}                             # B3: 낙하 전환을 한 번만 채점한다
var _r_cache := {}                                 # true_radius 캐시(get_debug_mesh 는 비싸다)
var _blocks_ok := {}                               # D3: D1·D2 를 통과한 서로 다른 블록


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not ("--judge" in args or "--judge1b" in args or "--judge2" in args
			or "--judge3" in args or "--judge3b" in args or "--judge3c" in args
			or "--judge4" in args or "--judge5" in args):
		return
	_main = get_parent()
	_main.judging = true          # main.gd._ready 보다 먼저 실행된다 (자식 → 부모)
	# 1a~3단계 판정은 전부 "구멍 하나" 를 전제로 세워졌다. 4단계 판정에서만 아레나를 켠다.
	_main.arena = "--judge4" in args or "--judge5" in args
	process_mode = Node.PROCESS_MODE_ALWAYS    # 정적 판정 중 트리를 멈춰도 자신은 돈다
	if "--judge5" in args:
		await run_judge_5()
	elif "--judge4" in args:
		await run_judge_4()
	elif "--judge3c" in args:
		await run_judge_3c()
	elif "--judge3b" in args:
		await run_judge_3b()
	elif "--judge3" in args:
		await run_judge_3()
	elif "--judge2" in args:
		await run_judge_2()
	elif "--judge1b" in args:
		await run_judge_1b()
	else:
		await run_judge()


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
		print("JUDGE %sbg FAIL: 탐침 프레임의 네 모서리가 모두 배경이 아니다" % prefix)
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
				# 오브젝트 반경은 구현체의 값을 믿지 않고 콜라이더에서 직접 잰다.
				# 구현이 잘못된 산출식을 쓰면 판정도 같은 값으로 오염되어 검출력이 사라진다
				# (실측: XZ 최대 절반값으로 바꾼 빌드가 그대로 통과했다).
				var margin: float = hole.radius - (dxz + true_radius(o))
				worst = minf(worst, margin)
				if margin < 0.0:
					sink += 1
					print("JUDGE 1b  early-convert: dist=%.3f + r=%.3f > R=%.3f (margin %.3f, 구현이 쓴 r=%.3f)"
						% [dxz, true_radius(o), hole.radius, margin, o.radius])
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
			elif not o.falling and o.global_position.y < SINK_LIMIT:
				sink += 1     # 전환 없이 지면을 뚫고 내려갔다
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
	var ok: bool = h1 and h2 and h6 and h7 and h8 and h9

	print("JUDGE hole%d px c=%s | lum c=%.4f ring[%.4f..%.4f] g=%.4f bg=%.4f dRing=%.4f dCB=%.4f inside=%s"
		% [idx, str(p_c), lum_c, lum_lo, lum_hi, lum_g, lum_bg,
		   lum_hi - lum_lo, absf(lum_c - lum_bg), inside])
	print("JUDGE hole%d groups %d->%d (H3 폐기, 진단용) | leak=%d/%d rim_aa=%d/%d depth=%.2f/%.2f"
		% [idx, g_base, g_shot, leak, tol, aa.x, aa.y, depth, need_depth])
	print("JUDGE hole%d H1=%s H2=%s H6=%s H7=%s H8=%s H9=%s -> %s"
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
func check_pipeline() -> bool:
	var code: String = _mat.shader.code
	var ok := code.contains("alpha_to_coverage") and code.contains("depth_prepass_alpha")
	ok = ok and int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)) > 0
	ok = ok and str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "forward_plus"
	return ok


# --- 3단계: 도시 지면 판정 --------------------------------------------------

## 블록 중앙 b 에서 파생되는 규격 표면 4종의 대표점.
## sz(±1)는 네 변 중 어느 쪽 도로를 보는가다. 한쪽으로 고정하면 구멍의 위치에 따라
## 표본이 카메라에서 16m 더 멀어져 중앙선이 서브픽셀이 된다(실측: judge3 의
## road·block 지점에서 유효 블록 0개). 규격은 네 변이 대칭이므로 양쪽을 다 시도한다.
## 좌표를 전부 SPEC_* 에서 계산하므로, 셰이더가 다른 주기·폭을 쓰면 표본이
## 엉뚱한 표면에 떨어져 D1 이 무너진다 — 그것이 이 기준의 검출력이다.
func surf_points(b: Vector3, sz: float) -> Array:
	var half := SPEC_PITCH * 0.5
	return [
		b,                                                                          # 블록   |uz| = 16
		b + Vector3(0, 0, sz * (half - (SPEC_ROAD_HALF + SPEC_CURB_HALF) * 0.5)),   # 보도   |uz| = 5
		b + Vector3(0, 0, sz * (half - SPEC_ROAD_HALF * 0.5)),                      # 아스팔트 |uz| = 2
		b + Vector3(0, 0, sz * half),                                               # 중앙선 |uz| = 0
	]


## 횡단보도 띠를 가로지르는 선분의 두 끝점.
## (sx, sz) 가 가리키는 교차로의 바깥쪽 — |ux| = road_half + cross_w/2 (띠 안),
## |uz| <= 3 (도로 위). 점 하나로는 줄무늬의 틈에 떨어질 수 있으므로 선분으로 본다.
func cross_segment(b: Vector3, sx: float, sz: float) -> Array:
	var half := SPEC_PITCH * 0.5
	var x := b.x + sx * (half - (SPEC_ROAD_HALF + SPEC_CROSS_W * 0.5))
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
func lane_width_px(b: Vector3, sz: float) -> float:
	var z := b.z + sz * SPEC_PITCH * 0.5
	var a := Vector3(b.x, 0.0, z - SPEC_LANE_HALF)
	var c := Vector3(b.x, 0.0, z + SPEC_LANE_HALF)
	if _cam.is_position_behind(a) or _cam.is_position_behind(c):
		return 0.0
	return _cam.unproject_position(a).distance_to(_cam.unproject_position(c))


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
			var b := Vector3(float(k0 + dk) * SPEC_PITCH + half, 0.0,
				float(j0 + dj) * SPEC_PITCH + half)
			for sz in [-1.0, 1.0]:
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
		var l := []
		for p in surf_points(b, sz):
			l.append(lum_at(shot, p))
		var seg: Array = cross_segment(b, sx, sz)
		var groups := edge_groups_line(sample_line(shot,
			_cam.unproject_position(seg[0]), _cam.unproject_position(seg[1])))
		var b1: bool = absf(l[0] - l[1]) >= SURF_DIFF_MIN \
			and absf(l[1] - l[2]) >= SURF_DIFF_MIN \
			and absf(l[2] - l[3]) >= SURF_DIFF_MIN
		var b2 := groups >= CROSS_GROUPS_MIN
		var b4: bool = l[1] > l[0] * 0.5 and l[2] > l[0] * 0.5 and l[3] > l[0] * 0.5
		d1 = d1 and b1
		d2 = d2 and b2
		d4 = d4 and b4
		if b1 and b2:
			_blocks_ok[Vector2i(roundi(b.x), roundi(b.z))] = true
		print("JUDGE %scity b(%.0f,%.0f)s(%.0f,%.0f) block=%.4f curb=%.4f road=%.4f lane=%.4f cross=%d lanepx=%.1f D1=%s D2=%s D4=%s"
			% [prefix, b.x, b.z, sx, sz, l[0], l[1], l[2], l[3], groups,
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
func background_pixel(probe: Image) -> Vector2i:
	var w := probe.get_width()
	var h := probe.get_height()
	for y in range(2, h / 2, 4):
		for x in range(2, w, 16):
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
	var all_ok := ok and d3
	print("JUDGE 3 D5=%s D3=%s blocks_ok=%s -> %s"
		% [pf(ok), pf(d3), str(_blocks_ok.keys()), ("PASS" if all_ok else "FAIL")])
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
func zone_of(pts: PackedVector2Array) -> String:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	# 가장 가까운 도로 중심선을 기준으로 편차를 잰다. 오브젝트가 한 주기보다
	# 작으므로 이 기준에서는 mod 의 접힘을 걱정할 필요가 없다.
	var cx: float = round(c.x / SPEC_PITCH) * SPEC_PITCH
	var cz: float = round(c.y / SPEC_PITCH) * SPEC_PITCH
	var xlo := INF
	var xhi := -INF
	var zlo := INF
	var zhi := -INF
	for p in pts:
		xlo = minf(xlo, p.x - cx)
		xhi = maxf(xhi, p.x - cx)
		zlo = minf(zlo, p.y - cz)
		zhi = maxf(zhi, p.y - cz)
	var ax := abs_range(xlo, xhi)
	var az := abs_range(zlo, zhi)
	if az.y <= SPEC_ROAD_HALF or ax.y <= SPEC_ROAD_HALF:
		return "road"
	if (az.x >= SPEC_ROAD_HALF and az.y <= SPEC_CURB_HALF and ax.x >= SPEC_ROAD_HALF) \
			or (ax.x >= SPEC_ROAD_HALF and ax.y <= SPEC_CURB_HALF and az.x >= SPEC_ROAD_HALF):
		return "walk"
	if ax.x >= SPEC_CURB_HALF and az.x >= SPEC_CURB_HALF:
		return "block"
	return ""                                  # 어느 구역에도 온전히 안 들어간다


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
	var ok: bool = e1 and e2 and e3 and e4 and e5 and e6
	print("JUDGE 3b props=%d catalog=%d albedos=%d zones road=%d walk=%d block=%d"
		% [props.size(), cat.size(), albedos.size(),
		   zone_n["road"], zone_n["walk"], zone_n["block"]])
	print("JUDGE 3b bad: E1=%d E2=%d E3=%d E5=%d E6=%d judge_set=%d fp=%d/%d settle_move=%.4f settle_tilt=%.4f"
		% [e1_bad, e2_bad, e3_bad, e5_bad, e6_bad, jset, f1.length(), f3.length(),
		   moved, tilted])
	print("JUDGE 3b E1=%s E2=%s E3=%s E4=%s E5=%s E6=%s -> %s"
		% [pf(e1), pf(e2), pf(e3), pf(e4), pf(e5), pf(e6),
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
		if int(_main.state) == 0:
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
	var board: String = _main.hud_board.text
	var rows := board.split("\n", false)
	var t2: bool = rows.size() == scored.size() + 1
	for i in scored.size():
		if not t2:
			break
		# 판정기가 정렬한 순서대로 이름이 그 줄에 있어야 한다
		t2 = t2 and rows[i + 1].contains(str(scored[i][0])) \
			and rows[i + 1].contains(str(scored[i][1]))
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
		and int(_main.state) == 0 \
		and absf(float(_main.time_left) - ROUND_TEST_SEC) < 0.2 \
		and fp0 == city.fingerprint(city.plan(city.city_seed))
	print("JUDGE 5 T5: 구멍=%d(기대 %d) R=5 %s 점수0 %s 프롭=%d(기대 %d) 판정대상=%d state=%d 남은시간=%.2f"
		% [hs.size(), RESTART_HOLES, pf(radii_ok), pf(score_ok), props, RESTART_PROPS,
		   jset, _main.state, _main.time_left])

	# --- T6: 플레이어가 먹히면 그 자리에서 끝난다 ---
	var t6r := await judge_player_eaten()
	var t6: bool = bool(t6r["over"]) and str(t6r["reason"]) == "eaten"
	print("JUDGE 5 T6: state=%d reason=%s" % [t6r["state"], t6r["reason"]])

	_main.judging = true
	var ok: bool = t1 and t2 and t3 and t4 and t5 and t6
	print("JUDGE 5 T1=%s T2=%s T3=%s T4=%s T5=%s T6=%s -> %s"
		% [pf(t1), pf(t2), pf(t3), pf(t4), pf(t5), pf(t6), ("PASS" if ok else "FAIL")])
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
		if int(_main.state) == 1:
			break
	return { "over": int(_main.state) == 1, "reason": str(_main.over_reason),
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
	for h in alive:
		if not is_instance_valid(h) or str(h.label) == "P":
			continue
		g7_n += 1
		var id: int = h.get_instance_id()
		var moved: float = float(path.get(id, 0.0))
		var grew: float = float(h.radius) - float(r_start.get(id, 0.0))
		var okh: bool = moved >= AI_MIN_PATH and grew > 0.0
		g7 = g7 and okh
		print("JUDGE 4 G7 %s: path=%.1f (>= %.0f) dR=%+.3f -> %s"
			% [h.label, moved, AI_MIN_PATH, grew, pf(okh)])
	g7 = g7 and g7_n > 0

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


## G5: 지면 밖으로 나간 구멍 수. 한계는 판정기의 SPEC_GROUND_HALF 로 계산한다.
func offground_holes() -> int:
	var n := 0
	for h in _reg.holes():
		if not is_instance_valid(h):
			continue
		var lim: float = SPEC_GROUND_HALF - float(h.radius) * RING_K + EDGE_SLACK
		var p: Vector3 = h.global_position
		if absf(p.x) > lim or absf(p.z) > lim or absf(p.y) > EDGE_SLACK:
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
	_main.set_hole_position(PERF_SPOT)
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
	var props: int = _main.get_node("City").get_child_count()

	var f1 := avg <= FRAME_BUDGET_MS
	var f2 := worst <= FRAME_BUDGET_MS * 2.0
	var ok := f1 and f2
	print("JUDGE 3c props=%d draws=%d prims=%d active_bodies=%d"
		% [props, int(draws), int(prims), int(phys)])
	print("JUDGE 3c avg=%.2fms (%.0f fps) worst=%.2fms budget=%.2fms"
		% [avg, 1000.0 / maxf(avg, 0.001), worst, FRAME_BUDGET_MS])
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
## C2: 크기 게이트 — 상한을 넘는 오브젝트는 삼켜지지도, 가라앉지도 않는다.
##     그리고 구멍이 자라 상한을 넘기면 그때는 삼켜진다.
## C3: 스코어가 삼킨 오브젝트의 기여 합과 일치하는가
## C4: 성장한 반경에서도 착시가 유지되는가 (우물·Area3D 가 SSOT 를 따라갔는가)
func run_judge_2() -> void:
	if not setup():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var hole: Node3D = _reg.holes()[0]
	hole.set_radius(FIXTURE_R)          # 성장 시나리오도 픽스처 반경에서 돈다
	var r0: float = hole.radius
	var objs: Array = get_tree().get_nodes_in_group("judge_set")

	# 시작 시점의 참반경·점수를 판정기가 독립적으로 기록해 둔다
	var r_of := {}
	var score_of := {}
	var big: Array = []
	var small: Array = []
	for o in objs:
		var id: int = o.get_instance_id()
		r_of[id] = true_radius(o)
		# 점수도 판정기가 규격대로 직접 계산한다 — 구현체의 score_value 를 믿으면
		# 산출식을 통째로 바꾼 빌드가 자기 값끼리 일치해 그대로 통과한다(실측).
		score_of[id] = int(round(float(r_of[id]) * float(r_of[id]) * 100.0))
		# 게이트 분류도 can_swallow() 에 묻지 않는다 — 게이트를 제거한 빌드에서는
		# 그 함수가 항상 true 라 검사 대상이 사라진다(실측).
		if float(r_of[id]) <= r0 * hole.swallow_ratio:
			small.append(o)
		else:
			big.append(o)
	print("JUDGE 2 start R=%.4f objects=%d over_gate=%d (gate=%.4f)"
		% [r0, objs.size(), big.size(), r0 * hole.swallow_ratio])

	# --- 0차: 반경이 작은 상태로 큰 오브젝트 위에 머문다 ---
	# 이 단계가 없으면 시나리오가 게이트를 한 번도 건드리지 않아,
	# 게이트를 통째로 제거한 빌드도 그대로 통과한다(실측).
	var gate_violation := 0
	for b in big:
		gate_violation += await hover(hole, objs, b, HOVER_FRAMES)

	# --- 1차: 게이트를 통과하는 작은 것만 삼킨다 ---
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
	# 1차에서 큰 것들은 하나도 사라지지 않아야 한다
	var c2a := true
	for o in big:
		c2a = c2a and is_instance_valid(o)

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
		if true_radius(o) > hole.radius * hole.swallow_ratio:
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

	var c2 := c2a and c2b and gate_violation == 0 and left == 0
	var ok := c1 and c2 and c3 and c4
	print("JUDGE 2 final R=%.4f score=%d left=%d gate_violations=%d"
		% [hole.radius, _main.score, left, gate_violation])
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
		# 게이트 위반 감시: 상한을 넘는 오브젝트는 낙하하지도 가라앉지도 않아야 한다
		for o in objs:
			if not is_instance_valid(o):
				continue
			if true_radius(o) <= hole.radius * hole.swallow_ratio:
				continue
			if o.falling or o.global_position.y < SINK_LIMIT:
				violations += 1
				print("JUDGE 2  gate breach: r=%.3f > R*%.2f=%.3f falling=%s y=%.3f"
					% [true_radius(o), hole.swallow_ratio,
					   hole.radius * hole.swallow_ratio, o.falling, o.global_position.y])
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


## 상한을 넘는 오브젝트가 낙하했거나 지면 아래로 내려갔는가.
## 판정 기준을 can_swallow() 에 묻지 않는다 — 게이트를 제거한 빌드에서는 항상 true 다.
func gate_breaches(hole: Node3D, objs: Array) -> int:
	var n := 0
	for o in objs:
		if not is_instance_valid(o):
			continue
		if true_radius(o) <= hole.radius * hole.swallow_ratio:
			continue
		if o.falling or o.global_position.y < SINK_LIMIT:
			n += 1
			print("JUDGE 2  gate breach: r=%.3f > R*%.2f=%.3f falling=%s y=%.3f"
				% [true_radius(o), hole.swallow_ratio,
				   hole.radius * hole.swallow_ratio, o.falling, o.global_position.y])
	return n
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
  shaders/
    ground_hole.gdshader (§4-A 전문)
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
| `road_half` | 4.0 | 아스팔트 폭 8 (2차선) |
| `curb_half` | 6.0 | 보도 폭 2 (도로 양옆) |
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

| 구역 | 조건 | 내용 |
|---|---|---|
| 차도 | `|u| ≤ 4` | 승용차 7종, Bus·SchoolBus·Ambulance, TrafficCone. 차선(`|u| = 2`) 위, 도로 축 방향 |
| 보도 | `4 ≤ |u| ≤ 6` | 가로등, 신호등, 표지판, 덤불 |
| 블록 | `|u| ≥ 6 + 1.5` | 건물 19종, 나무·바위 |
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
## 건물·녹지는 커브에서 이만큼 물러난다. 판정기가 |u| = CURB_HALF + 1 에서
## 블록 지면을 표본하므로, 이 여백이 없으면 표본이 건물 위에 떨어진다.
const BLOCK_SETBACK := 0.8
## 보도 프롭의 중심선. 도로와 커브의 한가운데다.
const WALK_U := (ROAD_HALF + CURB_HALF) * 0.5
## 차선 중심. 도로 폭 8 의 2차선.
const LANE_U := ROAD_HALF * 0.5
const GROUND_HALF := 224.0
## 판정 시나리오(1b·2단계의 흡입·성장)가 도는 영역. 여기에는 아무것도 생성하지 않는다.
## 이 광장이 없으면 도시 오브젝트가 시나리오에 섞여 들어 C1·C3 의 기대값이 깨진다.
const PLAZA_R := 26.0
## 오브젝트 사이에 두는 최소 여유(월드 단위).
const GAP := 0.3

@export var city_seed := 20260728
@export var enabled := true

## 카탈로그. scale 은 팩마다 제각각인 모델 치수를 실측(§13)에서 실제 크기로 맞춘 값이다.
## zone: "block"(블록 내부) / "walk"(보도) / "road"(차도)
const CATALOG := [
	# --- 건물: 블록 내부 ---
	{ "path": "res://assets/buildings/Building1_Large.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/Building1_Small.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/Building2_Large.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/Building2_Small.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/Building3_Big.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/Building3_Small.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/Building4.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/House1.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/buildings/House2.obj", "scale": 2.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/Bank.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/Flat.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/Flat2.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/Hospital.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/House.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/House2.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/House3.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/House4.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/House5.obj", "scale": 3.0, "zone": "block" },
	{ "path": "res://assets/simplebuildings/Shop.obj", "scale": 3.0, "zone": "block" },
	# --- 녹지: 블록 내부 ---
	{ "path": "res://assets/nature/Tree1.obj", "scale": 1.5, "zone": "block" },
	{ "path": "res://assets/nature/Tree2.obj", "scale": 1.2, "zone": "block" },
	{ "path": "res://assets/nature/Tree3.obj", "scale": 1.5, "zone": "block" },
	{ "path": "res://assets/nature/Tree4.obj", "scale": 1.0, "zone": "block" },
	{ "path": "res://assets/nature/Rock1.obj", "scale": 1.0, "zone": "block" },
	{ "path": "res://assets/nature/Rock2.obj", "scale": 1.0, "zone": "block" },
	{ "path": "res://assets/nature/Rock3.obj", "scale": 1.0, "zone": "block" },
	# --- 가로 시설물: 보도 ---
	{ "path": "res://assets/streets/Streetlight_Single.obj", "scale": 7.3, "zone": "walk" },
	{ "path": "res://assets/streets/Streetlight_Double.obj", "scale": 7.3, "zone": "walk" },
	{ "path": "res://assets/streets/TrafficLight.obj", "scale": 5.2, "zone": "walk" },
	{ "path": "res://assets/streets/Sign_Stop.obj", "scale": 4.4, "zone": "walk" },
	{ "path": "res://assets/streets/Sign_NoParking.obj", "scale": 4.4, "zone": "walk" },
	{ "path": "res://assets/streets/Sign_Triangle.obj", "scale": 4.4, "zone": "walk" },
	{ "path": "res://assets/transport/TrafficSign1.obj", "scale": 1.6, "zone": "walk" },
	{ "path": "res://assets/transport/TrafficSign2.obj", "scale": 1.6, "zone": "walk" },
	{ "path": "res://assets/nature/Bush1.obj", "scale": 1.0, "zone": "walk" },
	{ "path": "res://assets/nature/Bush2.obj", "scale": 1.0, "zone": "walk" },
	{ "path": "res://assets/nature/Bush3.obj", "scale": 1.0, "zone": "walk" },
	# --- 차량: 차도 ---
	{ "path": "res://assets/cars/Taxi.obj", "scale": 1.0, "zone": "road" },
	{ "path": "res://assets/cars/Cop.obj", "scale": 1.0, "zone": "road" },
	{ "path": "res://assets/cars/NormalCar1.obj", "scale": 1.0, "zone": "road" },
	{ "path": "res://assets/cars/NormalCar2.obj", "scale": 1.0, "zone": "road" },
	{ "path": "res://assets/cars/SUV.obj", "scale": 1.0, "zone": "road" },
	{ "path": "res://assets/cars/SportsCar.obj", "scale": 1.0, "zone": "road" },
	{ "path": "res://assets/cars/SportsCar2.obj", "scale": 1.0, "zone": "road" },
	{ "path": "res://assets/transport/Ambulance.obj", "scale": 1.05, "zone": "road" },
	{ "path": "res://assets/transport/Bus.obj", "scale": 1.96, "zone": "road" },
	{ "path": "res://assets/transport/SchoolBus.obj", "scale": 1.84, "zone": "road" },
	{ "path": "res://assets/transport/TrafficCone.obj", "scale": 0.6, "zone": "road" },
]

## 콜라이더 XZ 를 딸 밑동의 높이 비율. 나무의 몸통은 잡고 가지는 놓아준다.
const BASE_FRAC := 0.35

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
	for b in block_centers():
		plan_block(rng, b, out)
		plan_walk(rng, b, out)
		plan_road(rng, b, out)
	return out


## 블록 중앙 목록. 도로 중심선이 PITCH 의 배수이므로 블록 중앙은 그 중간이다.
## 순서를 고정해야 시드가 같을 때 결과가 같다.
func block_centers() -> Array:
	var out := []
	var n := int(GROUND_HALF / PITCH)          # 224/32 = 7
	for k in range(-n, n):
		for j in range(-n, n):
			out.append(Vector3(float(k) * PITCH + PITCH * 0.5, 0.0,
				float(j) * PITCH + PITCH * 0.5))
	return out


## 블록 내부. 큰 건물 한 채를 먼저 시도하고 남는 자리를 작은 것으로 채운다.
## 자리가 되는지는 add_slot 이 판단한다 — 레이아웃마다 기하를 손으로 맞추지 않는다.
func plan_block(rng: RandomNumberGenerator, b: Vector3, out: Array) -> void:
	# 블록 중앙 자리는 큰 것 전용이다. min_ext 를 안 걸면 이 한 번뿐인 기회를
	# 덤불이 차지해 대형 건물이 도시 전체에서 한두 채로 줄어든다(실측).
	if rng.randf() < 0.45:
		add_slot(rng, b, "block", out, "", 3.5)
	for _i in 16:
		add_slot(rng, b + Vector3(rng.randf_range(-8.5, 8.5), 0.0,
			rng.randf_range(-8.5, 8.5)), "block", out)


## 보도: 블록 네 변의 중앙선 위에 일정 간격으로 놓는다.
func plan_walk(rng: RandomNumberGenerator, b: Vector3, out: Array) -> void:
	var edge: float = PITCH * 0.5 - WALK_U                          # 11.0
	for side in [-1.0, 1.0]:
		for t in [-8.0, -3.0, 3.0, 8.0]:
			if rng.randf() < 0.55:
				continue
			add_slot(rng, b + Vector3(t, 0.0, side * edge), "walk", out)
		for t in [-8.0, -3.0, 3.0, 8.0]:
			if rng.randf() < 0.55:
				continue
			add_slot(rng, b + Vector3(side * edge, 0.0, t), "walk", out)


## 차도: 블록의 -x·-z 쪽 도로만 담당한다. 그래야 인접 블록과 중복 생성되지 않는다.
## 차량은 도로 축 방향으로 세운다 — 방향은 카탈로그에 적지 않고 모델 AABB 의
## 긴 축에서 유도한다(팩마다 모델이 X 로 눕기도, Z 로 눕기도 한다).
func plan_road(rng: RandomNumberGenerator, b: Vector3, out: Array) -> void:
	var half: float = PITCH * 0.5
	for t in [-10.0, -3.5, 3.5, 10.0]:
		for lane in [-LANE_U, LANE_U]:
			if rng.randf() < 0.55:
				continue
			add_slot(rng, Vector3(b.x + t, 0.0, b.z - half + lane), "road", out, "x")
		for lane in [-LANE_U, LANE_U]:
			if rng.randf() < 0.55:
				continue
			add_slot(rng, Vector3(b.x - half + lane, 0.0, b.z + t), "road", out, "z")


## 한 자리에 들어갈 에셋을 고른다.
##  (1) 판정 광장·지면 밖이면 아무것도 놓지 않는다.
##  (2) 그 자리·그 방향에서 **구역 밖으로 한 뼘도 나가지 않는** 에셋만 후보다.
##  (3) 이미 놓인 것과 상자가 겹치면 놓지 않는다 — 겹침을 생성 시점에 배제한다.
##
## (2)를 외접원으로 판단하면 안 된다. 길쭉한 것은 대각선이 폭보다 훨씬 커서
## 차선(폭 4m)에 들어가는 차가 전부 탈락한다 — 실측: 승용차 7종 중 1종만 남고
## 버스·구급차는 전멸했다. 회전이 90° 단위이므로 축방향 반extent 로 정확히 잰다.
func add_slot(rng: RandomNumberGenerator, pos: Vector3, zone: String, out: Array,
		road_axis := "", min_ext := 0.0) -> void:
	if Vector2(pos.x, pos.z).length() < PLAZA_R:
		return                                                      # 판정 광장
	if absf(pos.x) > GROUND_HALF - 2.0 or absf(pos.z) > GROUND_HALF - 2.0:
		return
	# 회전 후보를 먼저 정한다. 차량은 도로 축에 맞춰 두 방향, 나머지는 90° 네 방향.
	var spin := rng.randi_range(0, 3)
	var cands := []
	for e in CATALOG:
		if e["zone"] != zone:
			continue
		var h := half_extent(e)
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
			cands.append({ "e": e, "yaw": yaw, "ex": ex })
	if cands.is_empty():
		return
	var pick: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
	if not fits(pos, pick["ex"], out):
		return
	var e: Dictionary = pick["e"]
	out.append({ "path": e["path"], "scale": e["scale"], "zone": zone,
		"pos": pos, "ex": pick["ex"], "yaw": pick["yaw"] })


## 회전(90° 단위)을 반영한 월드 축방향 반extent.
func axis_extent(h: Vector2, yaw: float) -> Vector2:
	var swapped := absf(sin(yaw)) > 0.5
	return Vector2(h.y, h.x) if swapped else h


## pos 에 반extent ex 로 놓았을 때 구역 안에 온전히 들어가는가.
## u = 가장 가까운 도로 중심선까지의 거리. 도로는 |u|<=ROAD_HALF, 보도는
## [ROAD_HALF, CURB_HALF], 블록은 |u|>=CURB_HALF 다.
func in_zone(pos: Vector3, ex: Vector2, zone: String) -> bool:
	var hp: float = PITCH * 0.5
	var ux: float = absf(fmod(pos.x + hp + PITCH * 1000.0, PITCH) - hp)
	var uz: float = absf(fmod(pos.z + hp + PITCH * 1000.0, PITCH) - hp)
	match zone:
		"road":
			# 동서 도로 또는 남북 도로 중 한쪽에 온전히 들어가면 된다.
			return (uz + ex.y <= ROAD_HALF) or (ux + ex.x <= ROAD_HALF)
		"walk":
			# 한 축은 보도 띠 안, 다른 축은 교차 도로를 침범하지 않아야 한다.
			var on_z: bool = uz - ex.y >= ROAD_HALF and uz + ex.y <= CURB_HALF \
				and ux - ex.x >= ROAD_HALF
			var on_x: bool = ux - ex.x >= ROAD_HALF and ux + ex.x <= CURB_HALF \
				and uz - ex.y >= ROAD_HALF
			return on_z or on_x
		_:
			return ux - ex.x >= CURB_HALF + BLOCK_SETBACK \
				and uz - ex.y >= CURB_HALF + BLOCK_SETBACK
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
func half_extent(e: Dictionary) -> Vector2:
	var key: String = e["path"]
	if not _r_cache.has(key):
		var s: Vector3 = mesh_of(key).get_aabb().size
		_r_cache[key] = Vector2(s.x, s.z) * 0.5
	return (_r_cache[key] as Vector2) * float(e["scale"])


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
	box.size = Vector3(base.x * 2.0 * s, ab.size.y * s, base.y * 2.0 * s)
	cs.shape = box
	cs.position = Vector3(base.z * s, ab.size.y * s * 0.5, base.w * s)
	body.add_child(cs)

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

var _rng := RandomNumberGenerator.new()
var _hole: Node3D
var _reg: Node
var _target: Node3D = null
var _wander := Vector3.ZERO
var _tick := 0


func _ready() -> void:
	_hole = get_parent()
	_reg = get_node("/root/HoleRegistry")
	_rng.seed = ai_seed
	_wander = pick_wander()


func _physics_process(_dt: float) -> void:
	if _hole == null or not is_instance_valid(_hole):
		return
	_tick += 1
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
		if h == _hole or not is_instance_valid(h):
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
		if not is_instance_valid(o) or o.falling:
			continue
		if not _hole.can_swallow(float(o.radius)):
			continue
		var d2: float = flat_dist(o.global_position, _hole.global_position)
		if d2 < sight and d2 < bd:
			bd = d2
			best = o
	return best


## 지면 안의 임의 지점. 반경에 여유를 두어 가장자리에 붙지 않게 한다.
func pick_wander() -> Vector3:
	var lim: float = float(_hole.ground_half) * 0.8
	return Vector3(_rng.randf_range(-lim, lim), 0.0, _rng.randf_range(-lim, lim))


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

### 남은 것 — 도로 위계

피드백 4번의 "도로가 너무 격자"는 미해결이다. 계획: **4번째 도로 중심선마다 대로**(아스팔트 반폭 6.5, 이중 중앙선)를 두어 균질한 격자를 깬다. 셰이더의 `road_half`가 선 인덱스의 함수가 되므로 **판정기의 `SPEC_ROAD_HALF`도 같은 함수로 바꿔야 한다** — D1의 표본 좌표가 전부 거기서 나온다.
