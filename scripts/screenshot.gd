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
const MIN_BOUL_ROAD := 164
const MIN_BOUL_WALK := 152
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
const OVERLAP_FRAMES := 300                        # G6 시나리오: 사냥이 성사될 때까지

# --- 4b 게임 루프 판정 ----------------------------------------------------
const ROUND_TEST_SEC := 4.0                        # T1: 판정용 짧은 라운드
const ROUND_TEST_FRAMES := 600                     # T1: 그 라운드를 덮고도 남는 프레임 수
const TIMER_TOL := 0.25                            # T1: 판정기 시계와의 허용 오차(초)
const FREEZE_FRAMES := 120                         # T3: 종료 후 상태 고정을 확인하는 프레임
const RESTART_HOLES := 6                           # T5: 재시작 후 구멍 수 (플레이어 + AI 5)
## T5: 재시작 후 도시 프롭 수 (시드 고정). §22 에서 3804 → 3876 이었고,
## §25 에서 3876 → 2236 으로 줄었다. 줄어든 것이 규격이다 — 바다 테두리(52셀)와
## 강(14셀)에는 아무것도 놓지 않고, 공원 9셀은 수퍼블록 셋으로 합쳐 한 번만 채우며,
## 걷힌 도로 위의 보도·차도 프롭이 사라졌다.
const RESTART_PROPS := 2236
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
const MIN_CANOPY_PROPS := 343

# --- §21 한글 HUD 판정 -----------------------------------------------------
## 번들 폰트의 경로. 라벨이 이것을 쓰지 않으면 데스크톱에서는 시스템 폴백으로
## 멀쩡히 그려지고 **웹에서만** 글자가 사라진다 — 판정기가 도는 환경에서는 보이지
## 않는 결함이므로 출처를 직접 묻는다.
const HUD_FONT_PATH := "res://assets/fonts/hud_kr.ttf"
## HUD 문구 규격의 한글 음절 전부. 구현체의 문자열만 검사하면 문구를 통째로 영문으로
## 되돌린 빌드가 "쓰는 글자가 전부 있다" 로 통과한다 — 판정기가 따로 들어야 한다.
## 폰트 서브셋(assets/fonts/README.md)과 같은 집합이어야 한다.
const SPEC_HUD_CHARS := "점수크기삼킴먹힘순위이름시간종료혔다승리패배나키로작"
## T8③: 한글 26자를 그린 라벨이 남겨야 할 최소 잉크 픽셀. 실측 2568 의 1/4 이다.
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
const JUDGE_ORDER := ["--judge7", "--judge6", "--judge5", "--judge4", "--judge3c",
	"--judge3b", "--judge3", "--judge2", "--judge1b", "--judge"]


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
					why.append("(%.0f,%.0f)sz%.0f:도로없음" % [b.x, b.z, sz])
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
					if not spec_seg_ns(spec_line_index(b.x + sx * half), jc):
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
func spec_lane_slots(k: int) -> Array:
	var m := spec_median(k)
	var w := spec_road_half(k) - m
	return [m + w * 0.25, m + w * 0.5, m + w * 0.75]


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
		return ["road", nearest_lane_slot(kz, (az.x + az.y) * 0.5)]
	if spec_is_boulevard(kx) and ax.y <= rx and ax.x >= spec_median(kx) \
			and az.x >= rz + SPEC_CROSS_W:
		return ["road", nearest_lane_slot(kx, (ax.x + ax.y) * 0.5)]
	if spec_is_boulevard(kz) and az.x >= rz and az.y <= spec_curb_half(kz) \
			and ax.x >= rx:
		return ["walk", -1]
	if spec_is_boulevard(kx) and ax.x >= rx and ax.y <= spec_curb_half(kx) \
			and az.x >= rz:
		return ["walk", -1]
	return ["", -1]


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
	var e7: bool = boul_n["road"] >= MIN_BOUL_ROAD and boul_n["walk"] >= MIN_BOUL_WALK \
		and boul_bands.size() >= 3
	# E8: §19 의 걸림 모형이 실제로 입력을 갖는가. 두 질문을 함께 묻는다.
	#   ① 수관이 넓은 프롭에 수관 셰이프가 달려 있는가 (셰이프 개수)
	#   ② 그런 프롭이 하한 이상 있는가 — 밑동 셰이프를 다시
	#      메시 전체로 되돌리면 둘이 같아져 걸림이 조용히 사라진다.
	var e8: bool = e8_bad == 0 and canopy_n >= MIN_CANOPY_PROPS
	var ok: bool = e1 and e2 and e3 and e4 and e5 and e6 and e7 and e8
	print("JUDGE 3b props=%d catalog=%d albedos=%d zones road=%d walk=%d block=%d"
		% [props.size(), cat.size(), albedos.size(),
		   zone_n["road"], zone_n["walk"], zone_n["block"]])
	print("JUDGE 3b E7 대로전용자리: road=%d(>=%d) walk=%d(>=%d) 차선자리=%s(3개 전부)"
		% [boul_n["road"], MIN_BOUL_ROAD, boul_n["walk"], MIN_BOUL_WALK,
		   str(boul_bands.keys())])
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
		and int(_main.state) == 0 \
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
	var k5 := true
	for r in [flat, wide, pole, tree, tree_big]:
		k5 = k5 and int(r["sink_bad"]) == 0
	var k6: bool = bool(pole["gone"])

	var ok: bool = k1 and k2 and k3 and k4 and k5 and k6
	print("JUDGE 6 K1=%s K2=%s K3=%s K4=%s K5=%s K6=%s -> %s"
		% [pf(k1), pf(k2), pf(k3), pf(k4), pf(k5), pf(k6), ("PASS" if ok else "FAIL")])
	print("JUDGE RESULT -> %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## 시행 하나. 구멍을 r 로 되돌려 원점에 세우고, 픽스처를 **구멍 한가운데**에 놓은 뒤
## 구멍을 움직이지 않고 예산만큼 돌린다. 가운데에 놓는 것이 가장 강한 시험이다 —
## "가운데 놓아도 안 빠진다" 와 "가운데 놓으면 빠진다" 를 각각 단언할 수 있다.
##
## 반환: gone(삼켜졌는가) / frames(삼켜진 프레임) / sink_bad(구멍 밖 지면 관통 횟수)
func fall_run(hole: Node3D, tag: String, r: float, boxes: Array) -> Dictionary:
	hole.set_radius(r)
	hole.move_to(Vector3.ZERO)
	var body := fall_fixture("Fall_" + tag, boxes)
	_main.add_child(body)
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
## Z4: 교량 위 표본. 강 셀(k=2, x ∈ [64,96]) 한가운데를 지나는 동서 대로 z = 0·96 이다.
const BRIDGE_ON := [Vector3(72.0, 0.0, 0.0), Vector3(88.0, 0.0, 0.0),
	Vector3(72.0, 0.0, 96.0), Vector3(88.0, 0.0, 96.0)]
## Z4: 교량이 아닌 강 위. 여기에도 도로가 있으면 강을 통째로 덮은 것이다.
const BRIDGE_OFF := [Vector3(72.0, 0.0, 32.0), Vector3(88.0, 0.0, 64.0),
	Vector3(72.0, 0.0, -64.0)]
## 아스팔트로 인정할 상한 둘. 물과 아스팔트를 가르는 것은 휘도가 아니라 색이다 —
## 둘 다 어둡지만 물만 파랗다(실측: 물 0.255 / 아스팔트 0.035). 임계는 그 중간이다.
## 초록 쪽도 함께 막는다: 파랑만 보면 **교량 자리가 잔디로 바뀐 빌드**가 통과한다
## (잔디는 파랗지 않다). 아스팔트는 무채색이라 두 우세도가 모두 0 근처여야 한다.
const ROAD_B_MAX := 0.14
const ROAD_G_MAX := 0.06


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
	for spot in ZONE_SPOTS:
		top_down(spot[2])
		for _i in 3:
			await get_tree().process_frame
		var shot := await capture("zone_%s" % spot[0])
		var ch := chroma(shot, spot[2])
		gd[int(spot[1])] = ch.x
		bd[int(spot[1])] = ch.y
		print("JUDGE 7 존 %s at (%.0f,%.0f) 초록우세=%.4f 파랑우세=%.4f"
			% [spot[0], float((spot[2] as Vector3).x), float((spot[2] as Vector3).z),
			   ch.x, ch.y])
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
	var z2 := true
	var park_ref := chroma(park, Vector3(-176.0, 0.0, 16.0)).x
	for p in PARK_INNER:
		# 아스팔트·보도는 무채색이라 초록 우세도가 잔디보다 확 낮다.
		var gg := chroma(park, p).x
		var ok := gg >= park_ref - ZONE_G_MARGIN * 2.0
		z2 = z2 and ok
		print("JUDGE 7 공원내부 (%.0f,%.0f) 초록우세=%.4f (잔디 %.4f) %s"
			% [(p as Vector3).x, (p as Vector3).z, gg, park_ref, pf(ok)])

	# --- Z4: 교량은 있고, 교량이 아닌 강 위에는 도로가 없다 -------------------
	var z4 := true
	for p in BRIDGE_ON:
		top_down(p)
		for _i in 3:
			await get_tree().process_frame
		var img := await capture("zone_bridge_%d_%d" % [int((p as Vector3).x), int((p as Vector3).z)])
		var ch := chroma(img, p)
		var ok: bool = ch.y < ROAD_B_MAX and absf(ch.x) < ROAD_G_MAX   # 무채색 아스팔트다
		z4 = z4 and ok
		print("JUDGE 7 교량위 (%.0f,%.0f) 파랑우세=%.4f 초록우세=%.4f %s"
			% [(p as Vector3).x, (p as Vector3).z, ch.y, ch.x, pf(ok)])
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
		["교량 z=0", Vector3(80.0, 0.0, 0.0), true],
		["교량 z=96", Vector3(80.0, 0.0, 96.0), true],
	]
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

	print("JUDGE 7 Z1=%s Z2=%s Z3=%s Z4=%s Z5=%s (수역프롭=%d)"
		% [pf(z1), pf(z2), pf(z3), pf(z4), pf(z5), in_water])
	var ok := z1 and z2 and z3 and z4 and z5
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
	# ① 폰트 출처
	var src_ok := true
	for k in labels:
		var f: Font = (labels[k] as Label).get_theme_font("font")
		var p := "" if f == null else f.resource_path
		if p != HUD_FONT_PATH:
			src_ok = false
			print("JUDGE 5 T8 %s 의 폰트가 번들본이 아니다: '%s'" % [k, p])
	# ② 글리프 커버리지
	var font: Font = (labels["Label"] as Label).get_theme_font("font")
	var shown := ""
	for k in labels:
		shown += str((labels[k] as Label).text)
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
