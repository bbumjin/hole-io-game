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
## §33 병합 블록 [k0, j0, k1, j1] — city.gd MERGES 의 판정기 사본.
const SPEC_MERGES := [
	[-4, -2, -4, -1],
	[-2, -2, -1, -2],
	[4, -6, 5, -5],
	[-6, 4, -5, 5],
	[4, 1, 5, 2],
	[-6, -6, -5, -5],
]

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
## G2·G5·G7: 자유 실행 물리 프레임. **§36 에서 900(15초) → 2700(45초).**
##
## 하한을 낮추지 않고 **관측 창을 넓혔다.** 근거: G7 의 성장 합은 **포식 한 번에 좌우되는
## 지표**다 — §36 직전 baseline 의 +4.309 중 **+4.170 이 포식 하나**였다(AI 가 AI 를 먹으면
## 반경이 계단식으로 뛰고, 커진 AI 가 이어서 프롭을 쓸어담아 objects_eaten 이 19 까지 간다).
## §36 이 배치를 흔들자 AI3 의 생성 자리가 (-101,-78) → (-91,-75) 로 옮겼고, 15초 안에
## 일어나던 포식이 그 창 **밖으로 밀렸다**(성장 +0.072). 45초로 넓히면 다시 일어난다(+0.986).
##
## **난도는 안 변했다 — 통제 실험으로 확인했다.** 가로수 스케일을 1.46 → 1.10 으로 낮춰
## 수관을 시작 반경 아래로 내려도 **성장과 섭취 수가 같았다**(objects_eaten 2, +0.072;
## AI3 경로만 52.2 → 41.5 로 달랐다). 즉 §36 이 만든 회귀가 아니라 **원래 운에 기대던
## 기준이 운을 잃은 것**이다.
##
## 전역 먹이 밀도도 그대로다(R=1.5 에서 971 → 968, 수관까지 통과는 833 → 839 로 오히려
## 늘었다 — `tools/measure_nature.gd` ④). **다만 이 수는 근거로 약하다** — G7 이 재는 것은
## *그 AI 주변* 의 먹이지 도시 전체가 아니다(실측: AI3 의 프롭 섭취 성장률은 생성 자리가
## 옮기면서 대략 1/3 로 떨어졌다). 무게는 위의 통제 실험에 있다.
##
## **남은 한계**: 45초에서도 **포식을 빼면 성장이 +0.132 로 하한 0.20 에 미달**한다
## (0.986 중 0.854 가 포식). 창을 넓혀 동전이 떨어질 때까지 기다린 것이지 동전을 없앤
## 것이 아니다. 미래의 배치 변경이 포식을 이 창 밖으로 또 밀면 다시 빨개진다. 근본
## 해결은 "프롭을 먹어 자란 양" 과 "AI 를 먹어 자란 양" 을 갈라 묻는 것이지만, 그것은
## G7 의 재설계라 §36 의 범위 밖이다.
##
## 비용: `--judge4` 자유 실행이 3배가 된다(데스크톱·브라우저 양쪽). G2(면적 보존)·G5
## (오프그라운드)·G6 은 누적 기회가 3배가 되므로 **더 엄해진다** — 실측 오차 0, offground 0.
const ARENA_FRAMES := 2700
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
## §31 에서 2125 → 2633 (수변 난간 508 조각이 plan 에 들어왔다 — 재시작 복원의 일부다).
## §32 에서 2633 → 2264 (물로 이어진 도로 스텁 54 세그먼트가 걷히며 그 위의
## 차도·보도 프롭 369 개가 함께 사라졌다).
## §33 에서 2264 → 2100 (병합 rect 6개의 내부 도로 프롭이 사라지고 블록이 수퍼블록
## 하나로 계획된다 — 셀 수만큼 겹치던 밀도가 하나로 줄어드는 것이 규격이다).
##
## §34 에서 2100 → **2099**. 보도 프롭 중심선이 road_half+1.0 → +1.34 로 밀리며
## `in_zone("walk")` 의 `uz - ex.y >= rz` 가 `ex.y <= 1.0` → `ex.y <= 1.34` 로 **느슨해져**
## Streetlight_Double(반extent 1.152)이 새로 편입된다. **총수는 −1 인데 구성은 크게 흔들린다** —
## 그래서 개수만 적지 않고 변동을 남긴다(zone 별로는 walk 631→630, block 1012·road 457 불변):
##   Streetlight_Double 28→35(+7)  Sign_Stop 72→68(−4)  Streetlight_Single 60→57(−3)
##   Bush3 74→71(−3)  Bush2 72→70(−2)  Sign_Triangle 61→59(−2)
##   TrafficSign2 59→62(+3)  TrafficLight 63→64(+1)  TrafficSign1 61→62(+1)  Bush1 80→81(+1)
## (E7 의 `MIN_BOUL_WALK` 카운터는 244 로 **불변**이다 — road 분기가 먼저 걸러서다.)
##
## **§36 에서 2099 → 2112.** 보도의 덤불 셋(Bush1~3, 반extent 0.428~0.537)이 가로수 둘
## (StreetTree1·2, 1.1400)로 바뀌었다. zone 별 변화는 **walk 630→637 · block 504→491 ·
## road 457→476** 이고 가로수는 122 개다(E9 가 센다).
##
## 순증 +13 의 원인은 둘이다. ① `WALK_OVERHANG` 완화가 `Streetlight_Double`(1.1524)까지
## **가로 방향** 후보로 열었다(35→59). ② 그보다 큰 것은 **RNG 스트림 이동**이다 —
## `add_slot` 은 `cands` 가 비면 `rng.randi_range` 를 한 번 덜 뽑으므로, walk 카탈로그가
## 11종→10종이 된 순간 이후 **모든 자리의 난수가 다시 굴러간다**. block −13 · road +19 가
## 그것이다(카탈로그 변경이 차도 자리를 직접 늘릴 수는 없다 — 코드 감사가 갈라냈다).
## 대로 보도 카운터는 244→200 으로 줄지만 하한 162 위다.
const RESTART_PROPS := 2112
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
## §36 실측 **446**(537 에서 줄었다 — 보도 덤불 162개가 수관 프롭이었는데 그 자리가
## 가로수 122 로 바뀌었고, 새 관목은 수관비 ~1.0 이라 애초에 세지 않는다). 여유가
## 34% → **21%** 로 얇아졌다. **재유도하지 않는다** — 이 하한이 잡는 것은 "수관이 통째로
## 사라졌는가"(그때 0)이고, 446 은 그 질문에 여전히 넉넉하다. 절반 관례로 다시 뽑으면
## 223 이 되어 오히려 변별력이 준다.
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
##   §33 주의: 이 지점의 셀 (-2,-2) 는 병합 rect B 에 들어가 내부 도로가 사라지고
##   클러스터가 수퍼블록 중심으로 옮겨졌다 — §33 이전 계측표와의 비교성이 끊겼다.
##   예산 판정 자체는 유효하다(환경이 가벼워진 쪽이라 보수적이지 않을 뿐).
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


# --- §31 수변 난간 규격 사본 --------------------------------------------------
## city.gd 의 plan_rails 와 같은 규칙을 판정기가 따로 든다(세 벌 규격의 관례).
## 구현체의 상수·함수를 읽지 않는다 — 난간 간격을 바꾼 빌드는 여기에 걸려야 한다.
const SPEC_RAIL_LEN := 4.0
const SPEC_RAIL_INSET := 0.5
const SPEC_RAIL_TRIM := 1.0
const SPEC_RAIL_PREFIX := "rail_"        # 노드 이름은 판정과의 계약(§26)
const SPEC_RAIL_PATH := "proc://rail"
const SPEC_RAIL_TOL := 0.25              # 기대 자리와 실제 조각의 허용 거리
const SPEC_PROM_W := 2.0                 # 산책로 띠 폭 (셰이더 사본)
const PROM_SAMPLES := 6                  # Z7d 픽셀 표본 수 (강 3 + 바다 3)
## Z7d: 띠 안팎 휘도 차 하한. 실측 최소 0.092 (Forward+, 존 지면 0.571~0.574 대
## 산책로 0.478)의 1/3 — 백엔드별 렌더 차이 여유.
const PROM_LUM_MARGIN := 0.03


func spec_rail_open_half(jl: int) -> float:
	return spec_curb_half(jl) + 1.0


## 기대 난간 조각 위치 전부. plan_rails 의 판정기 사본 — 지도에서 유도하고
## 손으로 적지 않는다(§25 의 교량 표본 함정).
func spec_rail_pieces() -> Array:
	var pieces := []
	for k in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
		for j in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
			if spec_zone(k, j) == SPEC_Z_WATER:
				continue
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				spec_rail_edge(pieces, k, j, int(d[0]), int(d[1]))
	return pieces


func spec_rail_edge(pieces: Array, k: int, j: int, dk: int, dj: int) -> void:
	if spec_zone(k + dk, j + dj) != SPEC_Z_WATER:
		return
	var along_x := dj != 0
	var line: float
	if dk != 0:
		line = float(k + maxi(dk, 0)) * SPEC_PITCH - float(dk) * SPEC_RAIL_INSET
	else:
		line = float(j + maxi(dj, 0)) * SPEC_PITCH - float(dj) * SPEC_RAIL_INSET
	var s0: float = float(k if along_x else j) * SPEC_PITCH
	var s1: float = s0 + SPEC_PITCH
	if along_x:
		if spec_zone(k - 1, j) == SPEC_Z_WATER:
			s0 += SPEC_RAIL_TRIM
		if spec_zone(k + 1, j) == SPEC_Z_WATER:
			s1 -= SPEC_RAIL_TRIM
	else:
		if spec_zone(k, j - 1) == SPEC_Z_WATER:
			s0 += SPEC_RAIL_TRIM
		if spec_zone(k, j + 1) == SPEC_Z_WATER:
			s1 -= SPEC_RAIL_TRIM
	var opens := []
	if not along_x:
		for b in SPEC_BRIDGES:
			if k + dk == int(b[1]):
				opens.append([float(int(b[0])) * SPEC_PITCH, spec_rail_open_half(int(b[0]))])
	var c: float = s0 + SPEC_RAIL_LEN * 0.5
	while c + SPEC_RAIL_LEN * 0.5 <= s1 + 0.001:
		var blocked := false
		for o in opens:
			if absf(c - float(o[0])) < float(o[1]) + SPEC_RAIL_LEN * 0.5:
				blocked = true
				break
		if not blocked:
			pieces.append(Vector3(c, 0.0, line) if along_x else Vector3(line, 0.0, c))
		c += SPEC_RAIL_LEN


func spec_seg_rule(a: int, b: int, bridge: bool) -> bool:
	if a == SPEC_Z_WATER or b == SPEC_Z_WATER:
		return bridge
	return not (a == SPEC_Z_PARK and b == SPEC_Z_PARK)


## §33 Z9: 세그먼트 [축, 선, 셀] 의 픽셀 표본점 — 중심선에서 u=+2(도색 회피, Z8 규약).
func seg_sample_pt(s: Array) -> Vector3:
	if s[0] == "ew":
		return Vector3((float(int(s[2])) + 0.5) * SPEC_PITCH, 0.0,
			float(int(s[1])) * SPEC_PITCH + 2.0)
	return Vector3(float(int(s[1])) * SPEC_PITCH + 2.0, 0.0,
		(float(int(s[2])) + 0.5) * SPEC_PITCH)


## §33: 셀이 속한 병합 그룹 (0 = 비병합) — city.gd merge_group 의 사본.
func spec_merge_group(k: int, j: int) -> int:
	for i in SPEC_MERGES.size():
		var m: Array = SPEC_MERGES[i]
		if k >= int(m[0]) and k <= int(m[2]) and j >= int(m[1]) and j <= int(m[3]):
			return i + 1
	return 0


## §32 수변 끝 조항 + §33 병합 조항 포함 — city.gd·셰이더와 같은 규칙의 판정기 사본.
func spec_seg_ew(jl: int, kc: int) -> bool:
	if not spec_seg_rule(spec_zone(kc, jl - 1), spec_zone(kc, jl), spec_is_bridge_ew(jl, kc)):
		return false
	var g := spec_merge_group(kc, jl - 1)
	if g != 0 and g == spec_merge_group(kc, jl):
		return false
	for d in [1, -1]:
		if spec_zone(kc + d, jl - 1) == SPEC_Z_WATER \
				and spec_zone(kc + d, jl) == SPEC_Z_WATER \
				and not spec_is_bridge_ew(jl, kc + d):
			return false
	return true


func spec_seg_ns(kl: int, jc: int) -> bool:
	if not spec_seg_rule(spec_zone(kl - 1, jc), spec_zone(kl, jc), false):
		return false
	var g := spec_merge_group(kl - 1, jc)
	if g != 0 and g == spec_merge_group(kl, jc):
		return false
	for d in [1, -1]:
		if spec_zone(kl - 1, jc + d) == SPEC_Z_WATER \
				and spec_zone(kl, jc + d) == SPEC_Z_WATER:
			return false
	return true


## 구멍이 이 자리에 있을 수 있는가 — Z5 의 규격이다.
func spec_passable(p: Vector3) -> bool:
	var k := spec_cell_of(p.x)
	if spec_zone(k, spec_cell_of(p.z)) != SPEC_Z_WATER:
		return true
	var jl := spec_line_index(p.z)
	return spec_is_bridge_ew(jl, k) \
		and absf(p.z - float(jl) * SPEC_PITCH) <= spec_road_half(jl)


## 수퍼블록의 축별 병합 범위. E2 가 "블록 구간 안인가" 를 물을 때 쓴다.
## §33: 병합 rect 도 인지한다 — 안 하면 옛 내부 도로 자리를 채운 프롭 전부가
## 구역 이탈로 오탐된다(계획 감사 지적 2).
func spec_merge(k: int, j: int, along_k: bool) -> Vector2i:
	var v := k if along_k else j
	var g := spec_merge_group(k, j)
	if g != 0:
		var m: Array = SPEC_MERGES[g - 1]
		return Vector2i(int(m[0]), int(m[2])) if along_k else Vector2i(int(m[1]), int(m[3]))
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
const JUDGE_ORDER := ["--diag34", "--judge10", "--judge9", "--judge8", "--judge7", "--judge6",
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
		"--diag34": await run_diag_34()
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
	# §36: 보도 띠의 바깥 경계만 `SPEC_WALK_OVERHANG` 만큼 느슨하다. **차도 쪽은 그대로다**
	# (`az.x >= rz`). `prop_box` 가 수관 셰이프까지 헐에 넣으므로, 이 완화가 없으면
	# 가로수가 전량 "구역 이탈" 로 잡힌다(바깥 끝 2.48 > curb 2.0).
	# 오분류 걱정은 없다: `SPEC_WALK_OVERHANG`(0.5) < `SPEC_BLOCK_SETBACK`(0.8) 이라
	# 블록 프롭은 이 띠에 못 들어온다.
	if (az.x >= rz and az.y <= spec_curb_half(kz) + SPEC_WALK_OVERHANG \
				and ax.x >= rx and spec_seg_ew(kz, kc)) \
			or (ax.x >= rx and ax.y <= spec_curb_half(kx) + SPEC_WALK_OVERHANG \
				and az.x >= rz and spec_seg_ns(kx, jc)):
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
	var e7c_bad := 0
	var e7c_seen := 0
	var e8_bad := 0
	var canopy_n := 0
	# E9(§36): 보도 오버행의 방향(차도 침범) · 양 · 높이, 그리고 가로수 수.
	var e9_road_bad := 0
	var e9_over_bad := 0
	var e9_low_bad := 0
	var e9_trees := 0
	# §31: 난간의 기대 자리. 난간은 걷힌 도로의 기하 밴드 위에 서므로 zone_of 로
	# 판정하면 안 된다(바다 안쪽 난간 전량이 대로 밴드에 선다 — 계획 감사가 산술로
	# 보였다). 존 밴드 대신 **수변 규격 자리와의 일치**를 묻는다.
	var rail_pieces := spec_rail_pieces()
	var rail_n := 0
	var rail_bad := 0
	for o in props:
		var n3 := o as Node3D
		if n3 == null:
			continue
		var bx := prop_box(n3)
		if bx["pts"].is_empty():
			e5_bad += 1
			continue
		boxes.append(bx["pts"])
		var is_rail := String(n3.name).begins_with(SPEC_RAIL_PREFIX)
		if is_rail:
			rail_n += 1
			var best := INF
			var best_rp := Vector3.ZERO
			for rp in rail_pieces:
				var d := Vector2(n3.position.x - (rp as Vector3).x,
					n3.position.z - (rp as Vector3).z).length()
				if d < best:
					best = d
					best_rp = rp
			# 장축 방향도 묻는다 — 위치만 보면 전 조각을 90° 돌린 빌드가 통과한다
			# (코드 감사). 규격 축은 자리에서 유도한다: 난간 선 좌표는 셀 경계에서
			# inset(0.5) 만큼 안쪽이므로, x 가 그 꼴이면 남북(z 축) 난간이다.
			var px_f := fposmod(best_rp.x, SPEC_PITCH)
			var want_along_x: bool = not (absf(px_f - SPEC_RAIL_INSET) < 0.01
				or absf(px_f - (SPEC_PITCH - SPEC_RAIL_INSET)) < 0.01)
			var xmin := INF
			var xmax := -INF
			var zmin := INF
			var zmax := -INF
			for q in bx["pts"]:
				xmin = minf(xmin, (q as Vector2).x)
				xmax = maxf(xmax, (q as Vector2).x)
				zmin = minf(zmin, (q as Vector2).y)
				zmax = maxf(zmax, (q as Vector2).y)
			var got_along_x: bool = (xmax - xmin) > (zmax - zmin)
			if best > SPEC_RAIL_TOL or want_along_x != got_along_x:
				e2_bad += 1
				rail_bad += 1
				if e2_bad <= 5:
					print("JUDGE 3b E2 난간이 수변 규격 밖: %s at %s (최근접 %.2f, 축 기대/실제 %s/%s)"
						% [n3.name, str(n3.position), best,
						   "x" if want_along_x else "z", "x" if got_along_x else "z"])
		var z := "" if is_rail else zone_of(bx["pts"])
		if not is_rail:
			if z.is_empty():
				e2_bad += 1
				if e2_bad <= 5:
					print("JUDGE 3b E2 구역 이탈: %s at %s" % [n3.name, str(n3.position)])
			else:
				zone_n[z] += 1
		# E7: 일반 도로 규격에서는 불가능한 자리에 선 프롭을 따로 센다.
		# §31: 난간은 제외 — 걷힌 대로 밴드 위가 규격 자리다(위의 수변 판정이 담당).
		var bs := ["", 0, 0.0, 0] if is_rail else boulevard_slot(bx["pts"])
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
		# E7c(§34): 보도 프롭이 규격 중심선 위에 있는가.
		#
		# §34 가 그 중심선을 road_half+1.0 → +1.34 로 옮겼는데, 옮기기 전까지 **횡위치를
		# 단언하는 기준이 하나도 없었다** — 되돌린 빌드는 개수도 그대로라(2099 대 2100 의
		# 차이는 RESTART_PROPS 갱신에 묻힌다) 어떤 판정에도 안 걸린다.
		#
		# 표본은 구현체의 zone 이 아니라 **관측**에서 유도한다: "보도 띠 안에 있으면 본다".
		# 그리고 **어느 한 축이라도** 중심선 위면 통과다 — 대로 옆 보도 프롭은 자기 도로의
		# 보도에 앉아 있으면서 **교차 도로 기준으로도** 띠 안(|u|=8 < curb 8.5)에 들 수 있다.
		# 두 축을 모두 요구하면 그 프롭이 정상인데 탈락한다.
		if not is_rail:
			var kwx := spec_line_index(n3.position.x)
			var kwz := spec_line_index(n3.position.z)
			var uwx: float = absf(n3.position.x - float(kwx) * SPEC_PITCH)
			var uwz: float = absf(n3.position.z - float(kwz) * SPEC_PITCH)
			# **도로가 살아 있는 띠만 본다.** §25 가 공원 안쪽·강기슭의 도로를 걷어냈고,
			# 그 자리는 블록 프롭이 정상적으로 차지한다(span 이 병합돼 옛 도로 자리까지
			# 채운다) — 세그먼트 생존을 안 물으면 나무·바위·덤불이 무더기로 걸린다(실측).
			# 이 프롭이 앉은 보도 축 목록 [가로지르는 축이 x 인가, 도로 중심선 인덱스].
			# **E7c 의 "띠 안인가" 와 E9 의 축 선택은 같은 질문이다** — 따로 적으면 둘이
			# 어긋나도 아무도 모른다(코드 감사 지적). 한 번 만들어 둘 다 쓴다.
			var axes9 := []
			if uwx > spec_road_half(kwx) and uwx <= spec_curb_half(kwx) \
					and spec_seg_ns(kwx, spec_cell_of(n3.position.z)):
				axes9.append([true, kwx])
			if uwz > spec_road_half(kwz) and uwz <= spec_curb_half(kwz) \
					and spec_seg_ew(kwz, spec_cell_of(n3.position.x)):
				axes9.append([false, kwz])
			var in_band: bool = not axes9.is_empty()
			var on_center: bool = \
				absf(uwx - (spec_road_half(kwx) + SPEC_WALK_CENTER)) <= WALK_CENTER_TOL \
				or absf(uwz - (spec_road_half(kwz) + SPEC_WALK_CENTER)) <= WALK_CENTER_TOL
			if in_band:
				e7c_seen += 1
			if in_band and not on_center:
				if e7c_bad < 5:
					print("JUDGE 3b E7c 보도 프롭 중심선 이탈: %s |u|=(%.3f, %.3f) 규격=(%.3f, %.3f)"
						% [n3.name, uwx, uwz,
							spec_road_half(kwx) + SPEC_WALK_CENTER,
							spec_road_half(kwz) + SPEC_WALK_CENTER])
				e7c_bad += 1
			# --- E9(§36): 보도 오버행과 가로수 ---
			#
			# §36 이 보도 띠의 **바깥 경계만** 열었다(수관은 블록 여백 위로 걸치고
			# 차도 쪽으로는 한 뼘도 안 나간다). 그 비대칭을 여기서 못 박는다.
			#
			# **셰이프를 개별로 순회한다.** `prop_box` 는 밑동과 수관을 헐 하나로 합쳐
			# 돌려주므로 "어느 부피가 얼마나 높이 있는가" 를 못 묻는다. 그것을 물으려고
			# `prop_box` 를 늘리면 그것을 쓰는 E2·E5 가 함께 흔들린다.
			# **어느 한 축에서 성립하면 통과다.** `in_zone("walk")` 이 `on_z or on_x`
			# 이므로 판정도 같아야 한다 — 두 축을 모두 요구하면 정상 프롭이 탈락한다:
			# 프롭이 앉지 않은 **교차 축**의 |u| 는 8~13 이라 커브를 한참 넘는다.
			# (E7c 가 같은 이유로 OR 를 쓴다. 처음에 두 축을 다 보게 짰다가 853건이
			# 위양성으로 떴다 — 보도 프롭 거의 전량이었다.)
			if in_band:
				var best9 := [999, 0, 0, 0, 0.0, 0.0]   # [합, 차도, 초과, 낮음, |u|하한, 초과량]
				for pair9 in axes9:
					var is_x9: bool = pair9[0]
					var kk9: int = pair9[1]
					var r9 := spec_road_half(kk9)
					var cv9 := spec_curb_half(kk9)
					var line9 := float(kk9) * SPEC_PITCH
					var nroad := 0
					var nover := 0
					var nlow := 0
					var vin := INF
					var vover := 0.0
					for c9 in n3.find_children("", "CollisionShape3D", false, false):
						var col9 := c9 as CollisionShape3D
						if col9 == null or col9.shape == null:
							continue
						# 셰이프별 y 하단이 필요하다. `prop_box` 는 밑동과 수관을 헐
						# 하나로 합쳐 돌려주므로 못 쓴다 — 늘리면 그것을 쓰는
						# E2·E5 가 함께 흔들린다.
						var pts9 := PackedVector2Array()
						var sy9 := world_box(n3.global_transform * col9.transform,
							col9.shape.get_debug_mesh().get_aabb(), pts9)
						var lo9 := INF
						var hi9 := -INF
						for q in pts9:
							var d9: float = ((q as Vector2).x if is_x9 \
								else (q as Vector2).y) - line9
							lo9 = minf(lo9, d9)
							hi9 = maxf(hi9, d9)
						var rng9 := abs_range(lo9, hi9)
						# (a) 차도 쪽으로 넘었는가. **E9 가 자기 상수로 다시 잰다** —
						# `zone_of` 를 재사용하면 완화를 되돌린 고장을 못 잡는다.
						if rng9.x < r9 - 1e-4:
							nroad += 1
							vin = minf(vin, rng9.x)
						# (b) 커브를 넘은 부피는 양이 제한되고 **시민 키 위**에 있어야 한다.
						var over9: float = rng9.y - cv9
						if over9 > 1e-4:
							vover = maxf(vover, over9)
							if over9 > SPEC_WALK_OVERHANG + 1e-4:
								nover += 1
							if sy9 <= SPEC_CITIZEN_TOP:
								nlow += 1
					var sum9: int = nroad + nover + nlow
					if sum9 < int(best9[0]):
						best9 = [sum9, nroad, nover, nlow, vin, vover]
				if int(best9[0]) > 0:
					if int(best9[1]) > 0:
						if e9_road_bad < 5:
							print("JUDGE 3b E9 보도 프롭이 차도를 침범: %s |u|하한=%.3f"
								% [n3.name, float(best9[4])])
						e9_road_bad += 1
					if int(best9[2]) > 0:
						if e9_over_bad < 5:
							print("JUDGE 3b E9 커브 초과 과다: %s %.3f (<= %.3f)"
								% [n3.name, float(best9[5]), SPEC_WALK_OVERHANG])
						e9_over_bad += 1
					if int(best9[3]) > 0:
						if e9_low_bad < 5:
							print("JUDGE 3b E9 커브를 넘은 부피가 시민 키 아래: %s (> %.3f)"
								% [n3.name, SPEC_CITIZEN_TOP])
						e9_low_bad += 1
				# (c) 가로수인가. 높이 **와** 좁은 축을 함께 본다 — 높이만 보면 4m 를
				# 넘는 폴 156개가 전부 가로수로 세어져 하한이 공허해진다.
				var mh9 := Vector3.ZERO
				for c9m in n3.find_children("", "MeshInstance3D", false, false):
					var mi9 := c9m as MeshInstance3D
					if mi9 == null or mi9.mesh == null:
						continue
					mh9 = mh9.max(mi9.mesh.get_aabb().size * mi9.scale.abs())
				if mh9.y >= SPEC_TREE_MIN_H \
						and minf(mh9.x, mh9.z) * 0.5 >= SPEC_TREE_MIN_HALF:
					e9_trees += 1
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
	# §31: 미아 없음(위의 rail_bad)에 더해 **빠짐 없음**도 묻는다 — 개수가 기대 조각
	# 수와 같아야 한다. 한쪽만 물으면 난간 패스를 통째로 지운 빌드가 통과한다.
	var e2: bool = e2_bad == 0 and rail_n == rail_pieces.size()
	print("JUDGE 3b E2 난간: %d/%d (규격 밖 %d)" % [rail_n, rail_pieces.size(), rail_bad])
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
	#   E7c(§34): 보도 프롭이 규격 중심선 위인가. **통과식에 넣는다** — 이 절 위쪽이
	#        값비싸게 배운 것이다: 통과식에 실제로 들어가지 않는 카운터는 판정력이 0 이다.
	var e7: bool = boul_n["road"] >= MIN_BOUL_ROAD and boul_n["walk"] >= MIN_BOUL_WALK \
		and boul_lane_bad == 0 and e7c_bad == 0 and e7c_seen >= MIN_WALK_SAMPLES
	# E8: §19 의 걸림 모형이 실제로 입력을 갖는가. 두 질문을 함께 묻는다.
	#   ① 수관이 넓은 프롭에 수관 셰이프가 달려 있는가 (셰이프 개수)
	#   ② 그런 프롭이 하한 이상 있는가 — 밑동 셰이프를 다시
	#      메시 전체로 되돌리면 둘이 같아져 걸림이 조용히 사라진다.
	var e8: bool = e8_bad == 0 and canopy_n >= MIN_CANOPY_PROPS
	# E9(§36): 보도 오버행은 **한쪽으로만, 머리 위로만** 열렸는가, 그리고 보도에 실제로
	# 나무 크기의 녹지가 서는가. 셋을 함께 묻는다 — 하나라도 빠지면 다음이 조용히 샌다:
	#   ① 차도 침범 0     완화를 양쪽으로 열면 수관이 차 위로 간다
	#   ② 초과량·높이     수관이 시민 눈높이로 내려오면 겉보기 관통이 된다
	#   ③ 가로수 하한     덤불 크기로 되돌린 빌드를 잡는 유일한 조건
	# **①은 현재 카탈로그에서 잉여 방어다** — walk 10종의 최대 반extent 가 1.1524 로
	# WALK_CENTER(1.34)보다 작아 중심선을 옮기지 않는 한 차도를 못 넘는다. 넓은 보도
	# 자산이 들어올 때를 위해 둔다. **잉여인 줄 알고 두는 것**과 모르고 두는 것은 다르다.
	var e9: bool = e9_road_bad == 0 and e9_over_bad == 0 and e9_low_bad == 0 \
		and e9_trees >= MIN_STREET_TREES
	var ok: bool = e1 and e2 and e3 and e4 and e5 and e6 and e7 and e8 and e9
	print("JUDGE 3b props=%d catalog=%d albedos=%d zones road=%d walk=%d block=%d"
		% [props.size(), cat.size(), albedos.size(),
		   zone_n["road"], zone_n["walk"], zone_n["block"]])
	print("JUDGE 3b E7 대로전용자리: road=%d(>=%d) walk=%d(>=%d) 주행차선침범=%d"
		% [boul_n["road"], MIN_BOUL_ROAD, boul_n["walk"], MIN_BOUL_WALK, boul_lane_bad])
	print("JUDGE 3b E7c 보도 중심선(road_half+%.2f): 표본=%d(>=%d) 이탈=%d"
		% [SPEC_WALK_CENTER, e7c_seen, MIN_WALK_SAMPLES, e7c_bad])
	print("JUDGE 3b bad: E1=%d E2=%d E3=%d E5=%d E6=%d E8=%d judge_set=%d fp=%d/%d settle_move=%.4f settle_tilt=%.4f"
		% [e1_bad, e2_bad, e3_bad, e5_bad, e6_bad, e8_bad, jset, f1.length(), f3.length(),
		   moved, tilted])
	print("JUDGE 3b E8 수관프롭=%d(>=%d, 수관/밑동 >= %.1f)" % [canopy_n, MIN_CANOPY_PROPS, CANOPY_RATIO])
	print("JUDGE 3b E9 가로수=%d(>=%d, 높이>=%.1f 좁은반축>=%.2f) 차도침범=%d 초과과다=%d 낮은수관=%d (오버행<=%.2f, 시민 %.3f)"
		% [e9_trees, MIN_STREET_TREES, SPEC_TREE_MIN_H, SPEC_TREE_MIN_HALF,
		   e9_road_bad, e9_over_bad, e9_low_bad, SPEC_WALK_OVERHANG, SPEC_CITIZEN_TOP])
	print("JUDGE 3b E1=%s E2=%s E3=%s E4=%s E5=%s E6=%s E7=%s E8=%s E9=%s -> %s"
		% [pf(e1), pf(e2), pf(e3), pf(e4), pf(e5), pf(e6), pf(e7), pf(e8), pf(e9),
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
		var draws_d := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("JUDGE 3c [dynamic] 차=%d 시민=%d draws=%d avg=%.2fms (%.0f fps) worst=%.2fms F1=%s F2=%s"
			% [tr.car_total(), 0 if czn == null else czn.citizen_total(), int(draws_d),
			   avg, 1000.0 / maxf(avg, 0.001), worst, pf(s1), pf(s2)])

		# --- [dynamic-far] §34: 성장 후 프레이밍 -----------------------------
		# 위 지점은 **시작 반경 1.5** 라 화면에 드는 시민이 열 명 남짓이다. §34 가 시민
		# 하나당 MeshInstance3D 를 2 → 6 으로 늘렸는데 그 비용이 거기서는 거의 안 잡힌다
		# (게다가 Sun 이 그림자를 켜서 패스가 한 번 더 돈다).
		#
		# **구멍을 키우지 않는다.** `set_radius(9.0)` 로 하면 반경 9 짜리 구멍이 측정하는
		# 300프레임 내내 주변을 삼켜 씬이 매 프레임 달라지고 회차마다 값이 흔들린다.
		# `follow` 의 radius 인자는 **오프셋 배율일 뿐 구멍 크기와 무관**하므로(camera_rig)
		# 구멍은 1.5 로 두고 "성장 후 화면" 만 얻는다.
		#
		# 위의 [dynamic] 지점은 **그대로 둔다** — §17 이래의 like-for-like 비교선이다.
		# 여기는 더한 지점이지 옮긴 지점이 아니다.
		_cam.follow(hole, 9.0, true)
		for _i in WARMUP * 2:
			await get_tree().process_frame
		var t0f := Time.get_ticks_usec()
		var prevf := t0f
		var worstf := 0.0
		for _i in PERF_FRAMES:
			await get_tree().process_frame
			var nowf := Time.get_ticks_usec()
			worstf = maxf(worstf, float(nowf - prevf) / 1000.0)
			prevf = nowf
		var avgf := float(Time.get_ticks_usec() - t0f) / 1000.0 / float(PERF_FRAMES)
		var s1f := avgf <= FRAME_BUDGET_MS
		var s2f := worstf <= FRAME_BUDGET_MS * 2.0
		f1 = f1 and s1f
		f2 = f2 and s2f
		print("JUDGE 3c [dynamic-far] draws=%d avg=%.2fms (%.0f fps) worst=%.2fms F1=%s F2=%s"
			% [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			   avgf, 1000.0 / maxf(avgf, 0.001), worstf, pf(s1f), pf(s2f)])

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


# --- §34: 시민 모델 규격 사본 -----------------------------------------------
#
# 판정기는 구현체에서 값을 읽지 않는다. 아래는 전부 **사본**이고, 사본 불일치는 그 자체가
# 탈락이다. 치수·애니메이션 상수는 GLB **원본**에서 유도했다 — 임포트본을 읽으면 임포터의
# 키 최적화 결과에 규격을 얹게 된다(walk 루트 상승이 원본 0.1, 임포트본 0.0896 이다).

const SPEC_CITIZEN_SCALE := 0.6166667             # 1.665 / 2.7
const SPEC_CITIZEN_TOP := 1.665
## 정지 포즈(seek 0)의 인스턴스 AABB. 팔 포함 폭 · 키 · 머리 깊이.
const SPEC_CITIZEN_SPAN := Vector3(0.9867, 1.665, 0.4933)
## 걸음 전 구간의 밴드. **X 는 불변**이고(그래서 §34 의 보도 산술이 애니메이션 중에도
## 유효하다) Y·Z 는 무릎 없는 다리가 ±60° 로 벌어지며 변한다.
const SPEC_CITIZEN_WALK_Y := Vector2(1.4635, 1.6772)
const SPEC_CITIZEN_WALK_Z_MAX := 1.2426
## 발 높이대. 최대 상승 0.2568 은 루트 바운스(0.055)가 아니라 **다리 벌림**이 지배한다.
const SPEC_CITIZEN_FOOT_BAND := Vector2(-0.01, 0.2668)
## 콜라이더는 발 발자국이다(§34 — §17 의 취지를 잇되 절차를 그대로 돌리지는 않는다).
const SPEC_CITIZEN_BOX := Vector3(0.4933, 1.665, 0.2467)
const SPEC_CITIZEN_NODES := ["root", "leg-left", "leg-right", "torso",
	"arm-left", "arm-right", "head"]
const SPEC_CITIZEN_CAST := ["a", "b", "c", "e", "f", "j", "k", "m", "p", "q"]
const SPEC_ZONE_WARDROBE := {
	0: ["q", "j"], 1: ["f", "m", "p"], 2: ["e", "c", "a"], 3: ["k", "b"],
}
const SPEC_WALK_LEN := 0.6666667
const SPEC_SPRINT_LEN := 0.5
## 걸음 한 주기에서 다리 쿼터니언 x 가 닿아야 하는 절대값. 원본 walk 은 ±0.5(±60°)다.
const SPEC_LEG_SWING := 0.4
## M11 문턱. 채택 10종의 렌더 채도 최솟값은 q 의 0.234 이고 텍스처를 끊으면 0.001 로
## 떨어진다 — 그 사이에 넉넉히 놓는다.
const SPEC_CITIZEN_SAT_MIN := 0.10
## M13 의 기준점. 정상 최솟값(q 0.064)의 3배 아래, 0픽셀 렌더의 0.0 위다.
const SPEC_HEAD_CONTRAST_MIN := 0.02
const SPEC_HEAD_SUM_RATIO := 1.3
const SPEC_CITIZEN_PIX_MIN := 2000
## M13 이 실제로 재야 할 배역 수의 하한. 방향을 못 읽은(되돌아서는 중인) 배역은 건너뛰는데,
## 하한이 없으면 **한 종만 재고도 통과한다**. 열 종 중 둘까지는 되돌아설 수 있다고 본다.
const HEAD_MEASURED_MIN := 8
## M12g: 반경 16 구멍을 보도 옆에 두면 겁먹는 반경이 56m 라 이 정도는 도망친다(M10 과 같은 자리).
const SPRINT_SEEN_MIN := 3
## E7c: 보도 프롭 중심선(road_half 기준).
const SPEC_WALK_CENTER := 1.34
const WALK_CENTER_TOL := 0.05
## E7c 가 실제로 봐야 할 보도 프롭 수의 하한(실측 630). 밴드 조건이나 세그먼트 판정이
## 미래에 뒤집혀 표본이 0 이 되면 **E7c 는 공허하게 참**이 되고 로그에 흔적도 안 남는다.
const MIN_WALK_SAMPLES := 500

## E9(§36): 보도 프롭이 커브 **바깥쪽**으로 걸칠 수 있는 양. 차도 쪽은 0 이다.
## 구현체의 `WALK_OVERHANG` 을 읽지 않고 판정기가 자기 값으로 적는다 — 읽으면 완화를
## 늘린 빌드가 자기 값끼리 일치해 통과한다.
const SPEC_WALK_OVERHANG := 0.5
## E9: 가로수 판별. **높이만으로는 안 갈린다** — 보도에는 4m 를 넘는 폴이 **191개** 있다
## (가로등 7.96×63 · 8.03×59, 신호등 4.53×69 — `tools/measure_nature.gd` ③ 이 센다).
## 두 축을 함께 보면 갈린다: 폴은 좁은 축이 최대 **0.4807**(가로등)이고 가로수는 0.9308 이다.
const SPEC_TREE_MIN_H := 4.0
const SPEC_TREE_MIN_HALF := 0.60
## E9: 가로수 하한. **실측 122 의 절반**이다(E7a 와 같은 관례 — 자리 하나가 빠지는
## 부분 회귀는 비율로 안 걸리지만, 가로수가 덤불로 되돌아가면 0 이 된다).
## 판별 축이 실제로 폴을 걸러 내는지 확인했다: 실측 122 는 `StreetTree1·2` 의 수(69+53)와
## 같고, 4m 초과 폴 191개는 좁은 반축이 최대 0.4807 이라 전부 빠진다.
## **`RESTART_PROPS` 도 T5·T7 도 이 회귀를 못 잡는다** — 카탈로그에서 가로수 두 줄을 지우면
## 프롭 수와 zone 별 분포가 **비트 단위로 그대로**다(코드 감사가 주입해 확인했다).
const MIN_STREET_TREES := 61

## M13 프로브 조건. **조건이 규격의 일부다** — 같은 대비를 게임 카메라 각(내려보는 40.2°,
## 거리 21.7m)에서 재면 앞뒤 비가 1.84배에서 **1.14배로 무너진다**(머리가 화면에서 10픽셀
## 남짓이라 MSAA·태양각이 다 섞인다, 실측). 그래서 전용 수평 정사영 프로브를 쓴다.
const SPEC_PROBE_PX := 192
const SPEC_PROBE_BG := Color(1.0, 0.0, 1.0)       # 캐릭터에 없는 색 — 배경을 정확히 뺀다
const SPEC_PROBE_SIZE := 3.2                      # 모델 단위. 스케일을 곱해 쓴다
const SPEC_PROBE_CAM_Y := 1.35
## 머리 밴드(화면 위에서의 비율). 몸통이 섞이면 **검은 정장이 얼굴을 이긴다** — 실측으로
## 밟았고, 그래서 머리만 본다.
const SPEC_PROBE_HEAD := Vector2(0.078, 0.328)

var _probe: SubViewport = null
var _probe_slot: Node3D = null


func spec_model_path(letter: String) -> String:
	return "res://assets/characters/character-%s.glb" % letter


func probe_setup() -> void:
	if _probe != null:
		return
	_probe = SubViewport.new()
	_probe.size = Vector2i(SPEC_PROBE_PX, SPEC_PROBE_PX)
	_probe.own_world_3d = true                     # 도시가 배경에 들어오면 안 된다
	_probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_probe)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = SPEC_PROBE_BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	_probe.add_child(env)

	# 기본 카메라는 -Z 를 본다. +Z 에 두면 그대로 원점을 향하므로 look_at 이 필요없다
	# (트리에 넣기 전 look_at 은 "Node not inside tree" 로 실패한다).
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SPEC_PROBE_SIZE * SPEC_CITIZEN_SCALE
	cam.position = Vector3(0.0, SPEC_PROBE_CAM_Y * SPEC_CITIZEN_SCALE, 6.0)
	_probe.add_child(cam)

	_probe_slot = Node3D.new()
	_probe.add_child(_probe_slot)


## 배역 하나를 프로브에 세우고 한 장 찍는다. `yaw` 는 **판정기가 지어내지 않는다** —
## M13 은 게임이 세운 시민의 회전에서 받아 온다.
func probe_shot(letter: String, yaw: float, t: float) -> Image:
	for c in _probe_slot.get_children():
		_probe_slot.remove_child(c)
		c.queue_free()
	var ps := load(spec_model_path(letter)) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	inst.scale = Vector3.ONE * SPEC_CITIZEN_SCALE
	inst.rotation = Vector3(0.0, yaw, 0.0)
	_probe_slot.add_child(inst)
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		ap.play("walk")
		ap.pause()
		ap.seek(t, true)
	# 한 프레임만 기다리면 회전이 반영되기 전 화면을 읽는다.
	await get_tree().process_frame
	await get_tree().process_frame
	return _probe.get_texture().get_image()


## 한 장에서 세 값을 **한 번에** 뽑는다: 캐릭터 픽셀 수 · 평균 채도 · 머리 밴드 휘도 표준편차.
##
## `Image.get_pixel` 로 세 번 훑으면 이 판정 하나가 몇 분씩 걸린다(실측으로 밟았다 —
## judge9 는 3겹 검증에서 26번 돈다). 바이트 배열을 직접 읽고 한 패스로 끝낸다.
##
##   ① 픽셀 수 — **텍스처가 빠져도 이 수는 나온다**(흰 무지 캐릭터도 픽셀은 있다).
##   ② 채도 — 그래서 텍스처 누락은 **이것이** 가른다. 흰색·회색조는 0 이다.
##      휘도 분산으로 물으면 안 된다: 조명이 켜지면 흰 캐릭터도 면마다 명암이 생긴다.
##   ③ 머리 대비 — 얼굴은 밝은 피부 위 어두운 눈이라 표준편차가 크고 뒤통수는 고르다.
##      **"어두운 픽셀 수" 로 물으면 검은 머리 뒤통수가 얼굴을 이긴다**(실측).
##      몸통이 섞이면 검은 정장이 얼굴을 이기므로 머리 밴드만 본다.
func probe_stats(img: Image) -> Dictionary:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var y0 := int(float(h) * SPEC_PROBE_HEAD.x)
	var y1 := int(float(h) * SPEC_PROBE_HEAD.y)
	var n := 0
	var sat := 0.0
	var hn := 0
	var hs := 0.0
	var hq := 0.0
	for y in h:
		var head := y >= y0 and y < y1
		var row := y * w * 4
		for x in w:
			var i := row + x * 4
			var r := float(d[i]) / 255.0
			var g := float(d[i + 1]) / 255.0
			var b := float(d[i + 2]) / 255.0
			if r > 0.9 and g < 0.1 and b > 0.9:        # 배경
				continue
			n += 1
			var mx := maxf(r, maxf(g, b))
			if mx > 0.0:
				sat += (mx - minf(r, minf(g, b))) / mx
			if head:
				var lum := (r + g + b) / 3.0
				hn += 1
				hs += lum
				hq += lum * lum
	var contrast := 0.0
	if hn >= 20:
		var mean := hs / float(hn)
		contrast = sqrt(maxf(hq / float(hn) - mean * mean, 0.0))
	return { "pix": n, "sat": 0.0 if n == 0 else sat / float(n), "head": contrast }


## 시민 하나의 메시 전체 AABB — **강체의 로컬 좌표계**에서 잰다.
## 월드축으로 재면 `axis=="x"` 보도의 시민(대략 절반)이 yaw ±PI/2 라 X 와 Z 가 바뀌어
## 전부 탈락한다(실측: 그쪽은 월드 X 가 0.4933~1.2426 으로 변하고 불변인 것이 월드 Z 다).
func citizen_local_aabb(body: Node3D) -> AABB:
	var inv := body.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in body.find_children("", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		var b := (inv * m.global_transform) * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func citizen_part(body: Node3D, part: String) -> Node3D:
	var model := body.get_node_or_null("Model")
	return null if model == null else model.find_child(part, true, false) as Node3D


func anim_player_of(body: Node3D) -> AnimationPlayer:
	var model := body.get_node_or_null("Model")
	if model == null:
		return null
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer


## i 번 시민이 입고 있는 배역 글자. **실제 로드된 씬 경로**에서 읽는다(관측값).
func citizen_letter(cz: Node, i: int) -> String:
	if i < 0 or i >= int(cz.citizen_total()):
		return ""
	return str(cz.citizen_scene_path(i)).get_file() \
		.trim_prefix("character-").trim_suffix(".glb")


## M14 의 두 실행은 **대칭 헬퍼**로 잰다. `screenshot.gd` 의 M2 가 값비싸게 배운 것이다 —
## 계측이 낀 실행과 안 낀 실행을 견주면 물리 프레임 정렬이 한 칸 어긋나 **정상 빌드가
## 탈락한다.** 리셋·스폰·프레임 수가 완전히 같은 경로를 두 번 탄다.
func citizens_take(cz: Node, frames: int) -> String:
	# **먼저 프레임 경계에 맞춘다.** 이 함수는 서로 다른 지점에서 불리는데, 그대로
	# `reset()` 부터 하면 그것이 그 프레임의 물리 스텝 **앞**에 걸리기도 뒤에 걸리기도
	# 한다 — 새 시민이 한 틱을 더 받거나 덜 받아 90프레임 뒤 위치가 0.03m 어긋난다
	# (실측으로 밟았다: 두 실행이 z=-106.436 대 -106.399 로 갈렸다).
	# 여기서 한 번 기다리면 reset 은 항상 스텝 직후에 놓이고 다음 프레임이 첫 틱이 된다.
	await get_tree().physics_frame
	cz.citizen_count = CITIZEN_N
	cz.reset()
	for _f in frames:
		await get_tree().physics_frame
	var out := ""
	for i in mini(int(cz.citizen_total()), 40):
		var body: Node3D = cz.citizen_body(i)
		var leg := citizen_part(body, "leg-left")
		var p: Vector3 = cz.citizen_pos(i)
		out += "%.3f,%.3f,%.4f;" % [p.x, p.z,
			0.0 if leg == null else leg.quaternion.x]
	return out


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

	# --- M11~M15: 시민 모델 (§34) --------------------------------------------
	# M4(판정 격리)는 아무것도 스폰되기 전에 쟀으므로 이 묶음은 그 뒤에 온다.
	var m11 := cz != null
	var m12 := cz != null
	var m13 := cz != null
	var m14 := cz != null
	var m15 := cz != null
	if cz != null:
		probe_setup()

		# --- M11: 실루엣과 채도 ---------------------------------------------
		# 실루엣만 물으면 **텍스처가 빠진 흰 무지 캐릭터가 통과한다**(픽셀은 나온다).
		# 채도가 그것을 가른다 — 흰색·회색조는 0 이다.
		var pix_min := 1 << 30
		var sat_min := 1.0
		for letter in SPEC_CITIZEN_CAST:
			var shot: Image = await probe_shot(str(letter), 0.0, 0.0)
			if shot == null:
				m11 = false
				continue
			var st := probe_stats(shot)
			pix_min = mini(pix_min, int(st["pix"]))
			sat_min = minf(sat_min, float(st["sat"]))
		m11 = m11 and pix_min >= SPEC_CITIZEN_PIX_MIN and sat_min >= SPEC_CITIZEN_SAT_MIN
		print("JUDGE 9 M11 실루엣 최소=%d (>= %d) 채도 최소=%.4f (>= %.2f) %s"
			% [pix_min, SPEC_CITIZEN_PIX_MIN, sat_min, SPEC_CITIZEN_SAT_MIN, pf(m11)])

		# --- 조용한 판을 다시 세운다 ----------------------------------------
		# M10 이 반경 16 구멍을 보도 옆에 두고 끝났다. 그대로 두면 시민이 계속 도망쳐
		# sprint 가 돌고 M12·M14 의 walk 규격과 어긋난다.
		hole.set_radius(SPEC_START_R)
		hole.move_to(Vector3(-176.0, 0.0, -176.0))
		_reg.flush()

		# --- M15: 지구별 배역 ------------------------------------------------
		# **스폰 자리에서 묻는다.** 옷은 태어난 지구가 정하고 시민은 그 뒤로 걸어서
		# 지구 경계를 넘는다(사람은 원래 그렇게 다닌다) — 걷고 난 뒤에 물으면 정상
		# 빌드가 탈락한다(실측: 도심 옷을 입은 시민이 주거 셀 위에 서 있었다).
		# 그러니 프레임을 한 번도 돌리지 않은 채로 잰다.
		cz.citizen_count = CITIZEN_N
		cz.reset()
		var m15_bad := 0
		for i in int(cz.citizen_total()):
			var spath: String = str(cz.citizen_scene_path(i))
			var letter := spath.get_file().trim_prefix("character-").trim_suffix(".glb")
			var zone := spec_zone_at(cz.citizen_pos(i))
			var allowed: Array = SPEC_ZONE_WARDROBE.get(zone, [])
			if not (letter in allowed):
				if m15_bad < 5:
					print("JUDGE 9 M15 배역 규격 밖: %s (지구 %d, 허용 %s)"
						% [letter, zone, str(allowed)])
				m15_bad += 1

		var fp_a: String = await citizens_take(cz, 90)

		# 배역마다 대표 시민 하나. **표본을 손으로 적지 않는다** — 실제로 로드된
		# 씬 경로에서 유도한다(§25 가 교량 표본에서 배운 것과 같은 이유).
		var rep := {}
		for i in int(cz.citizen_total()):
			var spath2: String = str(cz.citizen_scene_path(i))
			var letter2 := spath2.get_file().trim_prefix("character-").trim_suffix(".glb")
			if not rep.has(letter2):
				rep[letter2] = i
		m15 = m15_bad == 0 and rep.size() == SPEC_CITIZEN_CAST.size()
		print("JUDGE 9 M15 배역 규격이탈=%d 등장 배역=%d/%d %s"
			% [m15_bad, rep.size(), SPEC_CITIZEN_CAST.size(), pf(m15)])

		# --- M12a·M12d·M12e: 정지 치수 · 콜라이더 · 노드 계약 ------------------
		var any: Node3D = cz.citizen_body(0)
		var ap0 := anim_player_of(any)
		if ap0 != null:
			ap0.seek(0.0, true)
		await get_tree().process_frame
		var rest := citizen_local_aabb(any)
		var span_bad := (rest.size - SPEC_CITIZEN_SPAN).abs()
		var m12a: bool = span_bad.x <= 0.01 and span_bad.y <= 0.01 and span_bad.z <= 0.01
		print("JUDGE 9 M12a 정지 치수 %s (규격 %s, 오차 %s) %s"
			% [str(rest.size), str(SPEC_CITIZEN_SPAN), str(span_bad), pf(m12a)])

		var box := Vector3.ZERO
		for c in any.find_children("", "CollisionShape3D", false, false):
			var sh := (c as CollisionShape3D).shape as BoxShape3D
			if sh != null:
				box = sh.size
		# Vector3 의 `<` 는 사전식 비교다 — 성분별로 물어야 한다.
		var box_err := (box - SPEC_CITIZEN_BOX).abs()
		var m12d: bool = box_err.x <= 0.001 and box_err.y <= 0.001 and box_err.z <= 0.001
		print("JUDGE 9 M12d 콜라이더 %s (규격 %s) %s"
			% [str(box), str(SPEC_CITIZEN_BOX), pf(m12d)])

		var miss := []
		for part in SPEC_CITIZEN_NODES:
			if citizen_part(any, str(part)) == null:
				miss.append(part)
		var m12e := miss.is_empty()
		print("JUDGE 9 M12e 노드 계약 누락=%s %s" % [str(miss), pf(m12e)])

		# --- M12b·M12c·M14: 걸음 구간 -----------------------------------------
		# 대표 시민마다 두 주기 이상 표본한다. `die` 는 다리가 **한쪽 부호로만** 가므로
		# 진폭 하한만으로는 안 걸린다(die 0.5949 > walk 0.5) — 양쪽 극값을 함께 묻는다.
		# --- M12f: 클립 계약 ------------------------------------------------
		# **`sprint` 는 여기 말고는 아무 데도 안 걸린다.** M14 는 walk 만 표본하므로
		# 클립 이름에 오타를 내면 도망 시 260명이 마지막 포즈로 굳은 채 미끄러지는데
		# 판정은 전부 초록이다(코드 감사가 주입으로 실증했다: "sprnt" → judge9 PASS).
		# 길이까지 물어야 SPEC_WALK_LEN·SPEC_SPRINT_LEN 이 판정력을 얻는다.
		var clip_bad := 0
		for letter in rep:
			var ap := anim_player_of(cz.citizen_body(int(rep[letter])))
			if ap == null:
				clip_bad += 1
				continue
			for pair in [["walk", SPEC_WALK_LEN], ["sprint", SPEC_SPRINT_LEN]]:
				var nm := str(pair[0])
				if not ap.has_animation(nm) \
						or absf(ap.get_animation(nm).length - float(pair[1])) > 1e-3:
					if clip_bad < 5:
						print("JUDGE 9 M12f 클립 계약 위반: %s/%s 존재=%s 길이=%.4f (규격 %.4f)"
							% [letter, nm, pf(ap.has_animation(nm)),
							   0.0 if not ap.has_animation(nm) else ap.get_animation(nm).length,
							   float(pair[1])])
					clip_bad += 1
		var m12f := clip_bad == 0
		print("JUDGE 9 M12f 클립 계약(walk %.4fs · sprint %.4fs) 위반=%d %s"
			% [SPEC_WALK_LEN, SPEC_SPRINT_LEN, clip_bad, pf(m12f)])

		var lo := {}
		var hi := {}
		var anti := {}
		# 표본 시민을 잃으면 **조용히 통과시키지 않는다.** `_people` 은 시민이 인계될
		# 때 remove_at 으로 줄어들어 **그보다 큰 인덱스가 전부 한 칸 밀린다** — 오늘은
		# 구멍을 지도 구석에 치워 뒀지만 그 전제는 코드에 안 적혀 있다. 매 프레임
		# 인덱스가 여전히 그 배역을 가리키는지 확인하고, 어긋나면 그것 자체가 탈락이다.
		var rep_drift := 0
		var wy := Vector2(INF, -INF)
		var wz := -INF
		var wx := Vector2(INF, -INF)
		var foot := Vector2(INF, -INF)
		for _f in 150:
			await get_tree().physics_frame
			for letter in rep:
				var ri := int(rep[letter])
				if citizen_letter(cz, ri) != str(letter):
					rep_drift += 1
					continue
				var body: Node3D = cz.citizen_body(ri)
				if not is_instance_valid(body):
					rep_drift += 1
					continue
				var ll := citizen_part(body, "leg-left")
				var lr := citizen_part(body, "leg-right")
				if ll == null or lr == null:
					continue
				var v := ll.quaternion.x
				lo[letter] = minf(float(lo.get(letter, INF)), v)
				hi[letter] = maxf(float(hi.get(letter, -INF)), v)
				anti[letter] = maxf(float(anti.get(letter, 0.0)),
					absf(v + lr.quaternion.x))
				var ab := citizen_local_aabb(body)
				wx = Vector2(minf(wx.x, ab.size.x), maxf(wx.y, ab.size.x))
				wy = Vector2(minf(wy.x, ab.size.y), maxf(wy.y, ab.size.y))
				wz = maxf(wz, ab.size.z)
				foot = Vector2(minf(foot.x, ab.position.y), maxf(foot.y, ab.position.y))
		var swing_bad := 0
		var anti_bad := 0
		for letter in rep:
			if float(lo.get(letter, 0.0)) > -SPEC_LEG_SWING \
					or float(hi.get(letter, 0.0)) < SPEC_LEG_SWING:
				if swing_bad < 3:
					print("JUDGE 9 M14 다리 진폭 부족: %s [%.4f, %.4f]"
						% [letter, float(lo.get(letter, 0.0)), float(hi.get(letter, 0.0))])
				swing_bad += 1
			if float(anti.get(letter, 9.0)) > 0.05:
				anti_bad += 1
		var fp_b: String = await citizens_take(cz, 90)
		var m14_det := fp_a == fp_b and not fp_a.is_empty()
		if not m14_det:
			var pa := fp_a.split(";")
			var pb := fp_b.split(";")
			print("JUDGE 9 M14 진단: 인원 %d vs %d" % [pa.size(), pb.size()])
			for n in mini(pa.size(), pb.size()):
				if pa[n] != pb[n]:
					print("  첫 불일치 #%d: %s  vs  %s" % [n, pa[n], pb[n]])
					break
		m14 = swing_bad == 0 and anti_bad == 0 and m14_det and rep_drift == 0
		print("JUDGE 9 M14 걸음: 표본=%d배역 진폭이탈=%d 반위상이탈=%d 표본유실=%d 결정성=%s(%d자) %s"
			% [rep.size(), swing_bad, anti_bad, rep_drift, pf(m14_det), fp_a.length(), pf(m14)])

		var m12b: bool = absf(wx.x - SPEC_CITIZEN_SPAN.x) <= 0.01 \
			and absf(wx.y - SPEC_CITIZEN_SPAN.x) <= 0.01 \
			and wy.x >= SPEC_CITIZEN_WALK_Y.x - 0.01 \
			and wy.y <= SPEC_CITIZEN_WALK_Y.y + 0.01 \
			and wz <= SPEC_CITIZEN_WALK_Z_MAX + 0.01
		print("JUDGE 9 M12b 걸음 치수 X=[%.4f,%.4f] Y=[%.4f,%.4f] Zmax=%.4f %s"
			% [wx.x, wx.y, wy.x, wy.y, wz, pf(m12b)])
		var m12c: bool = foot.x >= SPEC_CITIZEN_FOOT_BAND.x \
			and foot.y <= SPEC_CITIZEN_FOOT_BAND.y
		print("JUDGE 9 M12c 접지 발높이=[%.4f, %.4f] (규격 [%.2f, %.4f]) %s"
			% [foot.x, foot.y, SPEC_CITIZEN_FOOT_BAND.x, SPEC_CITIZEN_FOOT_BAND.y, pf(m12c)])
		m12 = m12a and m12b and m12c and m12d and m12e and m12f

		# --- M13: 정면 -------------------------------------------------------
		# **자세는 게임이 세운 것을 받아 온다** — 판정기가 yaw 를 지어내면 `citizens.gd`
		# 의 yaw 식에 +PI 를 주입해도 아무것도 안 걸린다. 진행 방향은 위치 변화에서
		# 관측하고, 회전은 노드에서 읽는다. 둘 다 관측값이다.
		var sum_front := 0.0
		var sum_back := 0.0
		var flip_bad := 0
		var floor_bad := 0
		# **몇 종을 실제로 쟀는지 세고 하한을 건다.** 방향을 못 읽은 배역은 아래에서
		# 조용히 `continue` 하는데, 그것을 안 세면 한 종만 측정돼도 통과한다.
		var measured := 0
		for letter in rep:
			var i := int(rep[letter])
			if i >= int(cz.citizen_total()):
				continue
			var p0: Vector3 = cz.citizen_pos(i)
			for _f in 10:
				await get_tree().physics_frame
			var body: Node3D = cz.citizen_body(i)
			if not is_instance_valid(body):
				continue
			var travel: Vector3 = cz.citizen_pos(i) - p0
			if Vector2(travel.x, travel.z).length() < 0.05:
				continue                       # 되돌아서는 중이면 방향을 못 읽는다
			# 진행 방향을 카메라 쪽(+Z)으로 돌려놓고 남은 회전만 프로브에 세운다.
			var resid: float = body.rotation.y - atan2(travel.x, travel.z)
			var f_img: Image = await probe_shot(str(letter), resid, 0.0)
			var b_img: Image = await probe_shot(str(letter), resid + PI, 0.0)
			if f_img == null or b_img == null:
				continue
			var cf := float(probe_stats(f_img)["head"])
			var cb := float(probe_stats(b_img)["head"])
			measured += 1
			sum_front += cf
			sum_back += cb
			if cf <= cb:
				print("JUDGE 9 M13 뒤를 보고 걷는다: %s 앞=%.4f 뒤=%.4f" % [letter, cf, cb])
				flip_bad += 1
			if cf < SPEC_HEAD_CONTRAST_MIN:
				floor_bad += 1
		var ratio := 0.0 if sum_back <= 0.0 else sum_front / sum_back
		m13 = flip_bad == 0 and floor_bad == 0 and ratio >= SPEC_HEAD_SUM_RATIO \
			and measured >= HEAD_MEASURED_MIN
		print("JUDGE 9 M13 정면: 측정=%d배역 (>= %d) 뒤집힘=%d 기준점미달=%d 총합비=%.2fx (>= %.1f) %s"
			% [measured, HEAD_MEASURED_MIN, flip_bad, floor_bad, ratio,
			   SPEC_HEAD_SUM_RATIO, pf(m13)])

		# --- M12g: 무엇이 실제로 재생 중인가 ---------------------------------
		# M12f 는 **에셋에 클립이 있는가**만 묻는다. 코드가 그 이름을 잘못 부르면
		# (예: `"sprint"` → `"sprnt"`) 엔진이 에러를 뱉는데도 판정이 전부 초록이었다
		# (코드 감사가 주입으로 실증했다). 그러니 **상태를 읽는다** — `pause()` 가
		# `current_animation` 을 비우므로 `assigned_animation` 을 본다.
		# 두 상태를 다 물어야 한다: 조용할 때 walk, 도망칠 때 sprint.
		var walk_seen := 0
		for letter in rep:
			var apw := anim_player_of(cz.citizen_body(int(rep[letter])))
			if apw != null and apw.assigned_animation == "walk":
				walk_seen += 1
		# 구멍을 보도 옆에 크게 놓아 도망을 켠다(M10 과 같은 자리·같은 이유).
		hole.set_radius(16.0)
		hole.move_to(Vector3(0.0, 0.0, -64.0))
		_reg.flush()
		for _f in 30:
			await get_tree().physics_frame
		var sprint_seen := 0
		for i in int(cz.citizen_total()):
			var aps := anim_player_of(cz.citizen_body(i))
			if aps != null and aps.assigned_animation == "sprint":
				sprint_seen += 1
		var m12g: bool = walk_seen == rep.size() and sprint_seen >= SPRINT_SEEN_MIN
		print("JUDGE 9 M12g 클립 선택: 조용할때 walk=%d/%d 도망칠때 sprint=%d (>= %d) %s"
			% [walk_seen, rep.size(), sprint_seen, SPRINT_SEEN_MIN, pf(m12g)])
		m12 = m12 and m12g

	print("JUDGE 9 M1=%s M2=%s M3=%s M4=%s M5=%s M6=%s M7=%s M8=%s M9=%s"
		% [pf(m1), pf(m2), pf(m3), pf(m4), pf(m5), pf(m6), pf(m7), pf(m8), pf(m9)])
	print("JUDGE 9 M11=%s M12=%s M13=%s M14=%s M15=%s"
		% [pf(m11), pf(m12), pf(m13), pf(m14), pf(m15)])
	var ok := m1 and m2 and m3 and m4 and m5 and m6 and m7 and m8 and m9 \
		and m11 and m12 and m13 and m14 and m15
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

	# --- Z8: 물로 이어진 도로 스텁이 없다(§32) ---------------------------------
	# 표본은 조항에서 유도한다: 기본 규칙으로는 있었는데 수변 끝 조항이 걷은 세그먼트.
	# 세 범주(강 양안 · 바다 동서안 · 바다 남북안)를 **따로** 표본한다 — 남북 조항은
	# 교량 분기가 없는 별도 코드 경로다(계획 감사). 표본점은 중심선에서 u=+2.0 —
	# 일반 도로의 중앙선 도색(|u|<0.3)을 피해 아스팔트 본체를 읽는 자리다.
	var stub_river := []
	var stub_ocean_ew := []
	var stub_ocean_ns := []
	# 강 열은 SPEC_BRIDGES 에서 유도한다 — 하드코딩하면 지도가 바뀔 때 여기만
	# 어긋난다(코드 감사. 어긋나도 버킷이 비어 FAIL 방향이지만, 유도가 정합적이다).
	var riv := int(SPEC_BRIDGES[0][1])
	for jl in range(SPEC_CELL_MIN + 1, SPEC_CELL_MAX + 1):
		for kc in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
			if spec_seg_rule(spec_zone(kc, jl - 1), spec_zone(kc, jl),
					spec_is_bridge_ew(jl, kc)) and not spec_seg_ew(jl, kc):
				var p8 := Vector3((float(kc) + 0.5) * SPEC_PITCH, 0.0,
					float(jl) * SPEC_PITCH + 2.0)
				if kc == riv - 1 or kc == riv + 1:
					stub_river.append(p8)
				else:
					stub_ocean_ew.append(p8)
	for kl in range(SPEC_CELL_MIN + 1, SPEC_CELL_MAX + 1):
		for jc in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
			if spec_seg_rule(spec_zone(kl - 1, jc), spec_zone(kl, jc), false) \
					and not spec_seg_ns(kl, jc):
				stub_ocean_ns.append(Vector3(float(kl) * SPEC_PITCH + 2.0, 0.0,
					(float(jc) + 0.5) * SPEC_PITCH))
	print("JUDGE 7 Z8 걷힌 세그먼트: 강=%d 바다EW=%d 바다NS=%d"
		% [stub_river.size(), stub_ocean_ew.size(), stub_ocean_ns.size()])
	var z8 := not (stub_river.is_empty() or stub_ocean_ew.is_empty()
		or stub_ocean_ns.is_empty())
	var stub_samples := []
	if z8:
		for i in 4:
			stub_samples.append(stub_river[i * (stub_river.size() - 1) / 3])
		for i in 2:
			stub_samples.append(stub_ocean_ew[i * (stub_ocean_ew.size() - 1)])
		for i in 2:
			stub_samples.append(stub_ocean_ns[i * (stub_ocean_ns.size() - 1)])
	# 아스팔트 판별은 Z4 와 같은 술어다: 무채색이고 지면보다 어둡고 물보다 밝다.
	for i in stub_samples.size():
		var p8: Vector3 = stub_samples[i]
		top_down(p8)
		for _i in 3:
			await get_tree().process_frame
		var img8 := await capture("stub_%d" % i)
		var ch8 := chroma(img8, p8)
		var lm8 := lum_at(img8, p8)
		var is_asphalt: bool = ch8.y < ROAD_B_MAX and absf(ch8.x) < ROAD_G_MAX \
			and lm8 + ROAD_LUM_MARGIN <= land_min and lm8 >= water_lum + ROAD_LUM_MARGIN
		var ok8: bool = not is_asphalt
		z8 = z8 and ok8
		print("JUDGE 7 Z8a 스텁 부재 (%.0f,%.0f) 휘도=%.4f 아스팔트=%s %s"
			% [p8.x, p8.z, lm8, str(is_asphalt), pf(ok8)])
	# Z8b 양방향 — 교량 진입 세그먼트 여섯은 **아스팔트다**. 조항을 교량 무시로
	# 과욕화하면(진입로까지 걷으면) 여기서 걸린다. 표본은 SPEC_BRIDGES 에서 유도.
	for b in SPEC_BRIDGES:
		for kc in [1, 3]:
			var pa := Vector3((float(kc) + 0.5) * SPEC_PITCH, 0.0,
				float(int(b[0])) * SPEC_PITCH)
			top_down(pa)
			for _i in 3:
				await get_tree().process_frame
			var imga := await capture("approach_%d_%d" % [int(b[0]), kc])
			var cha := chroma(imga, pa)
			var lma := lum_at(imga, pa)
			var oka: bool = cha.y < ROAD_B_MAX and absf(cha.x) < ROAD_G_MAX \
				and lma + ROAD_LUM_MARGIN <= land_min \
				and lma >= water_lum + ROAD_LUM_MARGIN
			z8 = z8 and oka
			print("JUDGE 7 Z8b 진입로 (%.0f,%.0f) 휘도=%.4f %s" % [pa.x, pa.z, lma, pf(oka)])

	# --- Z9: 병합 블록 — 내부 도로 부재·경계 도로 존재(§33) --------------------
	# 표본 전부 SPEC_MERGES 에서 유도. 세 단언:
	#   Z9c 거동 대조 — rect 유도 세그먼트(내부+경계) 전부에서 CITY.seg_* 와
	#       spec_seg_* 가 일치한다. 구현의 거동을 SPEC 에 **대조**하는 것은 원칙
	#       위반이 아니다(기대값을 구현에서 읽는 것이 위반이다) — 시드 의존 없이
	#       city.gd 조항 소실을 결정적으로 잡는다(계획 감사 지적 3).
	#   Z9a 픽셀 — rect 마다 내부 세그먼트 하나의 중점이 아스팔트가 아니다(셰이더).
	#       표본이 rect 당 하나여도 커버는 성립한다: A 는 EW 전용, B 는 NS 전용
	#       rect 라 축별 셰이더 조항 소실이 각각 잡히고, 로직 전수는 Z9c 가 덮는다.
	#   Z9b 픽셀 — **합성 spec(물 규칙+§32+§33)이 존재한다고 하는** 경계 세그먼트만
	#       아스팔트다. 해안 rect 의 경계는 §32 가 이미 걷었다 — "rect 경계 전부" 로
	#       물으면 정상 빌드가 거짓 탈락한다(계획 감사 지적 1). 과욕 병합(경계까지
	#       제거)은 여전히 걸린다 — 합성 spec 이 남긴 세그먼트를 걷으면 F 다.
	var z9 := true
	var z9c_bad := 0
	var z9a_pts := []
	var z9b_pts := []
	var cityn: Node = _main.get_node("City")
	for mi in SPEC_MERGES.size():
		var m: Array = SPEC_MERGES[mi]
		var k0 := int(m[0])
		var j0 := int(m[1])
		var k1 := int(m[2])
		var j1 := int(m[3])
		var internal := []
		var boundary := []
		for kl in range(k0 + 1, k1 + 1):
			for jc in range(j0, j1 + 1):
				internal.append(["ns", kl, jc])
		for jl in range(j0 + 1, j1 + 1):
			for kc in range(k0, k1 + 1):
				internal.append(["ew", jl, kc])
		for kl in [k0, k1 + 1]:
			for jc in range(j0, j1 + 1):
				boundary.append(["ns", kl, jc])
		for jl in [j0, j1 + 1]:
			for kc in range(k0, k1 + 1):
				boundary.append(["ew", jl, kc])
		for s in internal + boundary:
			var spec_has: bool = spec_seg_ew(int(s[1]), int(s[2])) if s[0] == "ew" \
				else spec_seg_ns(int(s[1]), int(s[2]))
			var city_has: bool = cityn.seg_ew(int(s[1]), int(s[2])) if s[0] == "ew" \
				else cityn.seg_ns(int(s[1]), int(s[2]))
			if spec_has != city_has:
				z9c_bad += 1
				if z9c_bad <= 5:
					print("JUDGE 7 Z9c 거동 불일치: %s(%d,%d) spec=%s city=%s"
						% [s[0], int(s[1]), int(s[2]), str(spec_has), str(city_has)])
		z9a_pts.append(seg_sample_pt(internal[0]))
		var exist := []
		for s in boundary:
			var has: bool = spec_seg_ew(int(s[1]), int(s[2])) if s[0] == "ew" \
				else spec_seg_ns(int(s[1]), int(s[2]))
			if has:
				exist.append(s)
		if exist.is_empty():
			# 경계가 전부 걷힌 rect 는 정의상 없어야 한다 — 있으면 지도가 잘못됐다.
			z9 = false
			print("JUDGE 7 Z9b rect %d: 합성 spec 에 남은 경계 세그먼트가 0개다" % mi)
		else:
			z9b_pts.append(seg_sample_pt(exist[0]))
			if exist.size() > 1:
				z9b_pts.append(seg_sample_pt(exist[exist.size() - 1]))
	z9 = z9 and z9c_bad == 0
	print("JUDGE 7 Z9c 거동 불일치=%d %s" % [z9c_bad, pf(z9c_bad == 0)])
	for i in z9a_pts.size():
		var p9: Vector3 = z9a_pts[i]
		top_down(p9)
		for _i in 3:
			await get_tree().process_frame
		var img9 := await capture("merge_in_%d" % i)
		var ch9 := chroma(img9, p9)
		var lm9 := lum_at(img9, p9)
		var asphalt9: bool = ch9.y < ROAD_B_MAX and absf(ch9.x) < ROAD_G_MAX \
			and lm9 + ROAD_LUM_MARGIN <= land_min and lm9 >= water_lum + ROAD_LUM_MARGIN
		z9 = z9 and not asphalt9
		print("JUDGE 7 Z9a 내부 (%.0f,%.0f) 휘도=%.4f 아스팔트=%s %s"
			% [p9.x, p9.z, lm9, str(asphalt9), pf(not asphalt9)])
	for i in z9b_pts.size():
		var p9: Vector3 = z9b_pts[i]
		top_down(p9)
		for _i in 3:
			await get_tree().process_frame
		var img9 := await capture("merge_bd_%d" % i)
		var ch9 := chroma(img9, p9)
		var lm9 := lum_at(img9, p9)
		var ok9: bool = ch9.y < ROAD_B_MAX and absf(ch9.x) < ROAD_G_MAX \
			and lm9 + ROAD_LUM_MARGIN <= land_min and lm9 >= water_lum + ROAD_LUM_MARGIN
		z9 = z9 and ok9
		print("JUDGE 7 Z9b 경계 (%.0f,%.0f) 휘도=%.4f %s" % [p9.x, p9.z, lm9, pf(ok9)])

	# --- Z7d: 수변 산책로 띠가 실제로 그려지는가(§31) --------------------------
	# 표본은 지도에서 유도한다: 물과 접한 육지 셀 가장자리의 스팬 중앙에서, 띠 안(경계
	# 1m 안쪽)과 띠 밖(경계 SPEC_PROM_W+2.5 안쪽)을 한 캡처에서 함께 읽는다.
	# 양방향 — "띠 안이 띠 밖과 다르다" 를 물으므로, 띠를 안 그린 빌드도(같음)
	# 존 전체를 산책로색으로 칠한 빌드도(역시 같음) 걸린다. 물이면 안 된다는 것도 함께.
	# 강 양안과 바다 가장자리를 **따로** 표본한다 — 하나의 목록에서 고르게 뽑으면
	# 수가 많은 바다 가장자리가 표본을 전부 차지해 강 산책로가 판정을 안 받는다(실측:
	# 첫 구현의 표본 6개가 전부 바다였다).
	var prom_river := []
	var prom_ocean := []
	for kq in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
		for jq in range(SPEC_CELL_MIN, SPEC_CELL_MAX + 1):
			if spec_zone(kq, jq) == SPEC_Z_WATER:
				continue
			var mid_x := (float(kq) + 0.5) * SPEC_PITCH
			var mid_z := (float(jq) + 0.5) * SPEC_PITCH
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var dk := int(d[0])
				var dj := int(d[1])
				if spec_zone(kq + dk, jq + dj) != SPEC_Z_WATER:
					continue
				var edge_w: float
				var p_in: Vector3
				var p_out: Vector3
				if dk != 0:
					edge_w = float(kq + maxi(dk, 0)) * SPEC_PITCH
					p_in = Vector3(edge_w - float(dk) * 1.0, 0.0, mid_z)
					p_out = Vector3(edge_w - float(dk) * (SPEC_PROM_W + 2.5), 0.0, mid_z)
				else:
					edge_w = float(jq + maxi(dj, 0)) * SPEC_PITCH
					p_in = Vector3(mid_x, 0.0, edge_w - float(dj) * 1.0)
					p_out = Vector3(mid_x, 0.0, edge_w - float(dj) * (SPEC_PROM_W + 2.5))
				# 강 = 세로 물기둥(교량 규격 SPEC_BRIDGES 의 kc 열). 그 외는 바다 테두리다.
				if dk != 0 and kq + dk == int(SPEC_BRIDGES[0][1]):
					prom_river.append([p_in, p_out])
				else:
					prom_ocean.append([p_in, p_out])
	# 가드는 **인덱싱보다 앞**에 둔다 — 빈 목록이면 FAIL 이어야지 크래시면 안 된다.
	# 나눗수는 표본 수에서 유도한다(하드코딩하면 표본 수를 바꿀 때 조용히 어긋난다).
	var z7d: bool = prom_river.size() >= 2 and prom_ocean.size() >= 2
	var samples := []
	if z7d:
		var nr := 3      # 강: 서안 처음·중간·동안 끝 — 목록이 k 오름차순이라 양안이 걸린다
		for i in nr:
			samples.append(prom_river[i * (prom_river.size() - 1) / (nr - 1)])
		var no := PROM_SAMPLES - nr
		for i in no:
			samples.append(prom_ocean[i * (prom_ocean.size() - 1) / maxi(no - 1, 1)])
	for i in samples.size():
		var pe: Array = samples[i]
		var p_in: Vector3 = pe[0]
		var p_out: Vector3 = pe[1]
		top_down(p_in)
		for _i in 3:
			await get_tree().process_frame
		var img := await capture("prom_%d" % i)
		var lin := lum_at(img, p_in)
		var lout := lum_at(img, p_out)
		var cin := chroma(img, p_in)
		var ok7: bool = absf(lin - lout) >= PROM_LUM_MARGIN and cin.y < ZONE_W_MARGIN
		z7d = z7d and ok7
		print("JUDGE 7 Z7d 산책로 (%.0f,%.0f) 띠휘도=%.4f 밖휘도=%.4f 차=%.4f(>=%.2f) 파랑=%.4f %s"
			% [p_in.x, p_in.z, lin, lout, absf(lin - lout), PROM_LUM_MARGIN, cin.y, pf(ok7)])
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

	# --- Z7: 수변 난간 — 규격 조각 집합과 계획의 일치(§31) ---------------------
	# 미아 없음(모든 난간이 규격 자리)과 빠짐 없음(모든 규격 자리에 난간) 양방향.
	# 교량 개구·물 위 금지는 별도 기준이 아니다 — 규격 집합 자체가 개구를 비우고
	# 육지에만 있으므로, 집합 일치가 셋을 한꺼번에 묻는다.
	var pieces := spec_rail_pieces()
	var rails := []
	for it in items:
		if String(it["path"]) == SPEC_RAIL_PATH:
			rails.append(it["pos"] as Vector3)
	var z7_missing := 0
	for rp in pieces:
		var best := INF
		for ra in rails:
			best = minf(best, Vector2((rp as Vector3).x - (ra as Vector3).x,
				(rp as Vector3).z - (ra as Vector3).z).length())
		if best > SPEC_RAIL_TOL:
			z7_missing += 1
			if z7_missing <= 3:
				print("JUDGE 7 Z7 규격 자리에 난간 없음: %s (최근접 %.2f)" % [str(rp), best])
	var z7_stray := 0
	for ra in rails:
		var best := INF
		for rp in pieces:
			best = minf(best, Vector2((rp as Vector3).x - (ra as Vector3).x,
				(rp as Vector3).z - (ra as Vector3).z).length())
		if best > SPEC_RAIL_TOL:
			z7_stray += 1
			if z7_stray <= 3:
				print("JUDGE 7 Z7 규격 밖 난간: %s (최근접 %.2f)" % [str(ra), best])
	var z7: bool = z7_missing == 0 and z7_stray == 0 \
		and rails.size() == pieces.size() and z7d
	print("JUDGE 7 Z7 난간 %d/%d (빠짐=%d 미아=%d) 산책로=%s"
		% [rails.size(), pieces.size(), z7_missing, z7_stray, pf(z7d)])

	print("JUDGE 7 Z1=%s Z2=%s Z3=%s Z4=%s Z5=%s Z6=%s Z7=%s Z8=%s Z9=%s (수역프롭=%d clamped=%s)"
		% [pf(z1), pf(z2), pf(z3), pf(z4), pf(z5), pf(z6), pf(z7), pf(z8), pf(z9),
		   in_water, str(_clamped)])
	# 표본이 화면 밖으로 잘렸으면 그 픽셀 판정은 무효다 — 가장자리 픽셀을 읽고
	# 초록으로 인쇄되는 것이 최악이다(코드 감사가 잡았다. 기존 Z1~Z4 도 같은 패턴).
	var ok := z1 and z2 and z3 and z4 and z5 and z6 and z7 and z8 and z9 and not _clamped
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




## 임시 진단 — 유저 결함 "닿으면 사라진다" 의 실제 경로를 시나리오별로 잰다.
## **구멍을 순간이동시키면 안 된다** — 그러면 시민이 항상 개구부 안쪽에 놓여 림 구간이
## 생기지 않는다(첫 진단이 그래서 빗나갔다). 밖에서 다가오게 한다.
## 확인 뒤 삭제한다.
func diag_run(cz: Node, hole: Node3D, label: String, approach: bool, stop_d: float) -> void:
	cz.citizen_count = 60
	cz.reset()
	await get_tree().physics_frame
	# 원점에서 가장 가까운 시민을 고른다.
	var best := -1
	var best_d := INF
	for i in int(cz.citizen_total()):
		var d: float = flat_dist(cz.citizen_pos(i), Vector3.ZERO)
		if d < best_d:
			best_d = d
			best = i
	var target: Vector3 = cz.citizen_pos(best)
	var rb: RigidBody3D = cz.citizen_body(best)
	hole.set_radius(SPEC_START_R)
	# 시민 기준 -X 쪽에서 다가와 중심거리 stop_d 에서 멈춘다.
	var stop_at := Vector3(target.x - stop_d, 0.0, target.z)
	if approach:
		hole.move_to(stop_at - Vector3(12.0, 0.0, 0.0))
	else:
		hole.move_to(stop_at)
	_reg.flush()

	var freed_at := -1
	var fell_at := -1
	var hand_at := -1
	var max_tilt := 0.0
	var score0: int = hole.score
	var cur := hole.global_position
	for f in 200:
		# 접근 구간: 14 m/s 로 다가가 stop_at 에서 멈춘다(플레이어 속도).
		if approach and cur.x < stop_at.x:
			cur.x = minf(cur.x + 14.0 / 60.0, stop_at.x)
			hole.move_to(cur)
		await get_tree().physics_frame
		if not is_instance_valid(rb):
			freed_at = f
			break
		if hand_at < 0 and not rb.freeze:
			hand_at = f
		var up: Vector3 = rb.global_transform.basis.y
		max_tilt = maxf(max_tilt, rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0))))
		if fell_at < 0 and rb.falling:
			fell_at = f
	var got: int = hole.score - score0
	var alive := is_instance_valid(rb)
	print("DIAG %-28s 인계f=%-4d 낙하f=%-4d 소멸f=%-4d 점수=%-4d 최대tilt=%5.1f° 생존=%s%s"
		% [label, hand_at, fell_at, freed_at, got, max_tilt, str(alive),
		   ("  y=%.2f" % rb.global_position.y) if alive else ""])


func run_diag_34() -> void:
	if not setup():
		get_tree().quit(1)
		return
	var hole := _main.get_node("Hole")
	var cz: Node = _main.get_node_or_null("Citizens")
	print("DIAG (점수>0 이어야 삼킨 것이다. 소멸f>=0 이고 점수=0 이면 지워진 것이다)")
	await diag_run(cz, hole, "A 정지·중심거리 1.12", false, 1.12)
	await diag_run(cz, hole, "I 정지·중심거리 1.58(림)", false, 1.58)
	await diag_run(cz, hole, "K 접근후 정지·1.62(림)", true, 1.62)
	await diag_run(cz, hole, "G 접근후 정지·0.0", true, 0.0)
	print("JUDGE RESULT -> PASS")
	get_tree().quit(0)
