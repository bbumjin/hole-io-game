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

## §33 병합 블록 [k0, j0, k1, j1] (경계 포함). 계획도시라도 모든 블록이 같은 크기는
## 아니다 — 내부 도로 없이 크게 병합된 그리드가 중간중간 있어야 실제 도시로 읽힌다
## (유저 지시). 각 rect 는 ① 존 균일 ② **대로 밴드 안**(내부 제거 선이 전부 일반
## 도로 — 대로는 교통이 달린다) ③ 물·공원·플라자·판정 블록 회피. 전부 감사가
## 지도로 전수 검증했다. 공원 수퍼블록(존-인접 병합)과는 셀이 겹치지 않는다.
const MERGES := [
	[-4, -2, -4, -1],   # A: C 지구 1×2
	[-2, -2, -1, -2],   # B: D 지구 2×1
	[4, -6, 5, -5],     # C: R 지구 2×2 (북동 해안)
	[-6, 4, -5, 5],     # D: R 지구 2×2 (남서 해안)
	[4, 1, 5, 2],       # E: R 지구 2×2 (동안 내륙)
	[-6, -6, -5, -5],   # F: R 지구 2×2 (북서 해안)
]


## 셀이 속한 병합 그룹 (0 = 비병합, 1.. = MERGES 인덱스+1).
static func merge_group(k: int, j: int) -> int:
	for i in MERGES.size():
		var m: Array = MERGES[i]
		if k >= int(m[0]) and k <= int(m[2]) and j >= int(m[1]) and j <= int(m[3]):
			return i + 1
	return 0

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

## 셰이더로 넘길 존 지도의 채널 간격. zone_code * 51 을 RG8 의 R 채널에 담는다
## (G 채널은 §33 병합 그룹 id).
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
	# 공원 전용 관목(§36). 옛 Bush1~3 은 머티리얼이 Leaves + **Tree** 로 줄기가 있어
	# 형태가 "축소된 나무" 였다 — 유저가 보도에서 그것을 "축소된 가로수" 로 봤다.
	# 이 셋은 머티리얼이 Green(+Berry) 하나뿐이라 줄기가 없다. 수관비 1.00~1.03 이므로
	# make_prop 이 셰이프를 하나만 단다(그게 맞다 — 덩어리에는 가지가 없다).
	# "bush" 는 P 의 kinds 에만 있으므로 D·C·R 블록에는 나타나지 않는다.
	{ "path": "res://assets/nature/Shrub1.obj", "scale": 1.0, "zone": "block", "kind": "bush" },
	{ "path": "res://assets/nature/Shrub2.obj", "scale": 1.0, "zone": "block", "kind": "bush" },
	{ "path": "res://assets/nature/Shrub3.obj", "scale": 1.0, "zone": "block", "kind": "bush" },
	# --- 가로 시설물: 보도 ---
	{ "path": "res://assets/streets/Streetlight_Single.obj", "scale": 7.3, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Streetlight_Double.obj", "scale": 7.3, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/TrafficLight.obj", "scale": 5.2, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Sign_Stop.obj", "scale": 4.4, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Sign_NoParking.obj", "scale": 4.4, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/streets/Sign_Triangle.obj", "scale": 4.4, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/transport/TrafficSign1.obj", "scale": 1.6, "zone": "walk", "kind": "street" },
	{ "path": "res://assets/transport/TrafficSign2.obj", "scale": 1.6, "zone": "walk", "kind": "street" },
	# --- 가로수: 보도 (§36) ---
	# 보도의 녹지는 **진짜 나무 크기**다(유저 지시). 스케일 1.46 은 고른 값이 아니라
	# 좁은 창의 한가운데다 — 아래는 `s >= 1.4425`(수관 셰이프 하단이 시민 키 1.665 위로
	# 0.08 이상), 위는 `s <= 1.4856`(반extent <= WALK_OVERHANG 이 허용하는 1.16).
	# **폭이 0.043(2.9%)뿐이라 "조금만 키우자" 가 곧바로 E2 를 깬다.** 판정 E9 가 양끝을 문다.
	# 두 종은 정점 데이터가 byte-identical 이고 잎 색만 다르다 — 실측 한 벌이 둘 다에 맞는다.
	{ "path": "res://assets/nature/StreetTree1.obj", "scale": 1.46, "zone": "walk", "kind": "tree" },
	{ "path": "res://assets/nature/StreetTree2.obj", "scale": 1.46, "zone": "walk", "kind": "tree" },
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
	plan_rails(out)      # §31: 수변 난간 — plan 안에 있어야 T5·E4 가 공짜로 덮는다
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


## 보도 프롭의 중심선. **보도의 한가운데가 아니라 커브 쪽 67% 지점**이다(§34).
##
## §33 까지는 한가운데(road_half + 1.0)였다. §34 의 시민이 캡슐(폭 0.4)에서 실제 캐릭터
## 모델(팔 포함 폭 0.9867)로 바뀌면서 그 자리가 성립하지 않는다: 차도 쪽 정차 차량이
## road_half 까지 쓸 수 있으므로(in_zone 의 "road") 시민이 쓸 수 있는 띠는 커브 쪽으로
## **가로등 기둥 안쪽 모서리까지 0.758** 뿐인데 팔 span 이 0.9867 이다 — 어떤 오프셋으로도
## 안 들어간다. 중심선을 밀어 프롭을 비켜 준다.
##
## **§36 주의**: 아래 유도는 보도에 덤불이 서 있던 시절의 것이다. 그 덤불(Bush1~3)은
## §36 에서 보도를 떠났고(가로수로 교체) 저장소에서도 지웠다. 값은 **그대로 둔다** —
## 가로수가 이 자리에서 성립하고(팔 높이대 시민 여유 −0.190 → **+0.122**), 옮기면
## `RESTART_PROPS` 와 E7c 규격을 다시 유도해야 한다. 아래는 그 값이 어떻게 나왔는지의 기록이다.
##
## **1.34 인 이유.** [1.24, 1.44] 는 배치가 완전히 같은 고원이다(총 프롭 2099 · walk 630 ·
## boul_walk 244 로 불변 — 실측). 1.46 부터 Bush1(반extent 0.537)이 보도 축 자격을 잃고
## 1.50 에서 구성이 무너진다(Bush1 80→21). 고원 안에서 **시민 여유**(신호등 기둥까지
## +0.075)와 **절벽까지 거리**(0.12)를 함께 확보하는 값이 1.34 다(균등화 지점 1.363).
##
## 시민이 2.5배 넓어지는데도 오늘보다 모든 프롭에서 여유가 커진다(팔 높이대 실측 반폭
## 기준): 가로등 +0.058 → **+0.105**, 신호등 +0.028 → **+0.075**, 덤불 겹침 −0.237 → **−0.190**.
## 덤불은 보도 폭 2.0 에 덤불 1.074 + 시민 0.987 = 2.06 이라 기하적으로 못 피한다.
##
## **이 상수를 바꾸면 `RESTART_PROPS` 를 다시 유도해야 한다** — in_zone("walk") 의
## `uz - ex.y >= rz` 가 함께 느슨해져 Streetlight_Double(반extent 1.152)의 편입 여부가
## 바뀐다(임계 1.152). §34 에서 2100 → 2099 가 된 것이 그 자리다.
const WALK_CENTER := 1.34
static func walk_center_at(k: int) -> float:
	return road_half_at(k) + WALK_CENTER


## 보도 프롭이 커브 **바깥쪽(블록 쪽)** 으로 걸칠 수 있는 양. 차도 쪽은 0 이다(§36).
##
## §35 까지 보도 프롭은 띠 [road_half, curb_half] 안에 온전히 들어가야 했다. 그 규격에서
## 허용 반extent 는 `min(WALK_CENTER, SIDEWALK_W - WALK_CENTER)` = **0.66** 이고, 팩의 나무를
## 거기에 맞추면 **가장 큰 것이 2.62m** 다(Tree1, 좁은 축 기준). 가로등 7.96m 옆에서 그것은
## 나무가 아니라 덤불이라, 보도의 녹지가 "축소된 가로수" 로 읽혔다(유저 피드백).
##
## **실제 가로수의 수관은 보도 밖으로 나간다 — 지면에 닿는 것은 밑동뿐이다.** 이 저장소는
## 이미 그 구분 위에 서 있다(§17·§19·§23 의 밑동/수관, `BASE_FRAC`, `base_extent`).
##
## **값을 고르지 않고 유도한다.** 블록 여백(`BLOCK_SETBACK` 0.8)에서 생성 시점 간격
## (`GAP` 0.3)을 뺀다. 그러면 보도 프롭의 바깥 끝이 최대 `curb_half + 0.5` 이고 블록 구간은
## `curb_half + 0.8` 에서 시작하므로 **수관이 블록 프롭에 원리적으로 못 닿는다** — 간격이
## 정확히 `GAP` 이라 `fits()` 의 `absf(d) < ex + o + GAP` 가 부등호로 성립하지 않는다.
##
## 차도 쪽을 열지 않는 것이 이 상수의 요점이다. 열면 수관이 정차·주행 차량 위로 나가고,
## 그때는 `fits()`·E3 가 2D 라서 **차를 거절하거나 겹침을 통과시키거나** 둘 중 하나가 된다.
## 안 열면 둘 다 손댈 필요가 없다(현행 최대 반extent 1.1400 < WALK_CENTER 1.34).
const WALK_OVERHANG := BLOCK_SETBACK - GAP     # 0.5


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


# --- §31 수변 난간 -----------------------------------------------------------
## 물과 접한 육지 셀 가장자리를 난간이 따라간다. 강 특례가 아니라 **존 지도의
## 함수**다 — 강 양안과 바다 안쪽 테두리가 같은 규칙으로 처리된다.
## 유저 피드백 4("도로가 물속으로 들어간다")의 대책: 걷힌 도로 자리(빈 띠)를
## 난간이 가로질러 동서 도로 dead-end 의 끝단 처리를 겸한다.
const RAIL_PATH := "proc://rail"   # 카탈로그 밖 절차 생성 — make_prop 이 분기한다
const RAIL_LEN := 4.0              # 조각 배치 간격
const RAIL_BODY := 3.8             # 벽 길이. 0.2 간격이 E3(생성 시점 겹침 배제)를 지킨다
const RAIL_H := 0.9
const RAIL_T := 0.18
const RAIL_INSET := 0.5            # 물 경계에서 육지 쪽으로
const RAIL_TRIM := 1.0             # 직교 난간과 만나는 모서리 여백 — 겹침 방지


## 교량 어귀 개구 반폭. 교량 보도 바깥(curb)보다 넓어야 진입(차·시민)을 안 막는다.
static func rail_open_half(jl: int) -> float:
	return curb_half_at(jl) + 1.0


## 난간 조각 전체를 계획한다. 난수가 없다 — 배치가 순수하게 지도의 함수다.
static func plan_rails(out: Array) -> void:
	for k in range(CELL_MIN, CELL_MAX + 1):
		for j in range(CELL_MIN, CELL_MAX + 1):
			if zone_at(k, j) == Z_WATER:
				continue
			rail_edge(out, k, j, 1, 0)
			rail_edge(out, k, j, -1, 0)
			rail_edge(out, k, j, 0, 1)
			rail_edge(out, k, j, 0, -1)


## 셀 (k,j) 의 (dk,dj) 쪽 이웃이 물이면 그 가장자리를 따라 조각을 놓는다.
## 지도 밖 이웃은 zone_at 의 클램프가 자기 자신(육지)을 돌려주므로 자연히 걸러진다.
static func rail_edge(out: Array, k: int, j: int, dk: int, dj: int) -> void:
	if zone_at(k + dk, j + dj) != Z_WATER:
		return
	var along_x := dj != 0                       # 물이 남북 쪽 → 난간은 x 축을 따라 눕는다
	# 난간 선: 셀 경계에서 육지 쪽으로 RAIL_INSET.
	var line: float
	if dk != 0:
		line = float(k + maxi(dk, 0)) * PITCH - float(dk) * RAIL_INSET
	else:
		line = float(j + maxi(dj, 0)) * PITCH - float(dj) * RAIL_INSET
	# 스팬: 셀의 직교 방향 구간. 양 끝의 직교 이웃도 물이면(모서리) 직교 난간과
	# 겹치지 않게 물린다.
	var s0: float = float(k if along_x else j) * PITCH
	var s1: float = s0 + PITCH
	if along_x:
		if zone_at(k - 1, j) == Z_WATER:
			s0 += RAIL_TRIM
		if zone_at(k + 1, j) == Z_WATER:
			s1 -= RAIL_TRIM
	else:
		if zone_at(k, j - 1) == Z_WATER:
			s0 += RAIL_TRIM
		if zone_at(k, j + 1) == Z_WATER:
			s1 -= RAIL_TRIM
	# 교량 개구: 강 양안(남북 방향 난간)에서만 성립한다 — 교량은 전부 동서 대로다.
	var opens := []
	if not along_x:
		for b in BRIDGES:
			if k + dk == int(b[1]):
				opens.append([float(int(b[0])) * PITCH, rail_open_half(int(b[0]))])
	var c: float = s0 + RAIL_LEN * 0.5
	while c + RAIL_LEN * 0.5 <= s1 + 0.001:
		var blocked := false
		for o in opens:
			if absf(c - float(o[0])) < float(o[1]) + RAIL_LEN * 0.5:
				blocked = true
				break
		if not blocked:
			var pos := Vector3(c, 0.0, line) if along_x else Vector3(line, 0.0, c)
			var ex := Vector2(RAIL_BODY * 0.5, RAIL_T * 0.5) if along_x \
				else Vector2(RAIL_T * 0.5, RAIL_BODY * 0.5)
			out.append({ "path": RAIL_PATH, "scale": 1.0, "zone": "rail",
				"pos": pos, "ex": ex, "yaw": 0.0 if along_x else PI * 0.5 })
		c += RAIL_LEN


## 도로 세그먼트가 존재하는가. **존 지도에서 파생되는 순수 함수**이고 별도 데이터가 없다.
##   · 어느 한쪽이 수역이면 → 교량 목록에 있을 때만 존재한다.
##   · 양쪽이 모두 공원이면 → 없다(수퍼블록 내부 관통 도로를 걷어낸다).
##     한쪽만 공원이면 남는다 — 공원은 도로로 둘러싸인 것이 자연스럽다.
static func seg_rule(a: int, b: int, bridge: bool) -> bool:
	if a == Z_WATER or b == Z_WATER:
		return bridge
	return not (a == Z_PARK and b == Z_PARK)


## 동서 도로(중심선 z = PITCH*jl)의, x 가 셀 kc 에 걸친 구간.
## §32 수변 끝 조항: 어느 한쪽 끝의 너머 두 셀이 모두 물이고 그 너머 세그먼트가
## 교량이 아니면 걷는다 — "실제 도시에는 물로 이어진 도로는 존재할 수 없다"(유저 지시).
## 걷힌 뒤 도로는 물가 한 블록 전의 T 교차로에서 끝난다. 조항이 존 지도·교량표의
## 순수 함수라 제거가 제거를 연쇄시키지 않는다(계획 감사가 증명).
static func seg_ew(jl: int, kc: int) -> bool:
	if not seg_rule(zone_at(kc, jl - 1), zone_at(kc, jl), is_bridge_ew(jl, kc)):
		return false
	# §33: 같은 병합 그룹 안의 내부 도로는 없다(P-P 규칙과 동형).
	var g := merge_group(kc, jl - 1)
	if g != 0 and g == merge_group(kc, jl):
		return false
	for d in [1, -1]:
		if zone_at(kc + d, jl - 1) == Z_WATER and zone_at(kc + d, jl) == Z_WATER \
				and not is_bridge_ew(jl, kc + d):
			return false
	return true


## 남북 도로(중심선 x = PITCH*kl)의, z 가 셀 jc 에 걸친 구간.
## 강이 남북이라 이를 건너는 교량은 없다 — 남북 도로는 수역을 만나면 항상 끊긴다.
## §32: 수변 끝 조항도 교량 분기 없이 대칭 적용된다(바다로 뻗던 스텁이 걷힌다).
static func seg_ns(kl: int, jc: int) -> bool:
	if not seg_rule(zone_at(kl - 1, jc), zone_at(kl, jc), false):
		return false
	var g := merge_group(kl - 1, jc)
	if g != 0 and g == merge_group(kl, jc):
		return false
	for d in [1, -1]:
		if zone_at(kl - 1, jc + d) == Z_WATER and zone_at(kl, jc + d) == Z_WATER:
			return false
	return true


## 구멍이 이 자리에 있을 수 있는가(§25). 수역은 막고, 교량 아스팔트 위는 연다.
## 판정하는 것은 **구멍 중심** 하나다 — 원반 절반이 물 위에 걸치는 것은 허용이다
## ("강기슭이 파인" 연출이고, 반경 마진으로 막으면 교량 진입로까지 막힌다).
static func passable(p: Vector3) -> bool:
	var k := cell_of(p.x)
	if zone_at(k, cell_of(p.z)) != Z_WATER:
		return true
	var jl := line_index(p.z)
	return is_bridge_ew(jl, k) and absf(p.z - float(jl) * PITCH) <= road_half_at(jl)


## 축별 병합 범위 [최소 셀, 최대 셀]. 공원은 존-인접 병합(§25), §33 의 병합 rect 는
## MERGES 로 직접 지정된다 — 두 기구는 셀이 겹치지 않는다(rect 조건 ③).
## 경계에서 멈추지 않으면 zone_at 이 테두리를 잘라 같은 값을 돌려주어 무한 루프가 된다.
static func merge_k(k: int, j: int) -> Vector2i:
	var g := merge_group(k, j)
	if g != 0:
		return Vector2i(int(MERGES[g - 1][0]), int(MERGES[g - 1][2]))
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
	var g := merge_group(k, j)
	if g != 0:
		return Vector2i(int(MERGES[g - 1][1]), int(MERGES[g - 1][3]))
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


## 셀 (k, j) 의 배치 가능 구간. 공원·병합 rect(§33)면 **병합 구간**이다 — 셰이더에서
## 내부 도로를 지우기만 하고 이 구간을 셀 단위로 두면, 프롭이 옛 도로 띠를 계속 피해
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
	# §33: G 채널에 병합 그룹 id 를 함께 굽는다(0 = 비병합). 런타임 생성 텍스처라
	# 임포트·압축 함정이 없고, 셰이더는 texelFetch 정수 조회로 읽는다(보간 금지 —
	# R 채널과 같은 규약).
	var img := Image.create(CELL_COUNT, CELL_COUNT, false, Image.FORMAT_RG8)
	for j in range(CELL_MIN, CELL_MAX + 1):
		for k in range(CELL_MIN, CELL_MAX + 1):
			var v := float(zone_at(k, j) * ZONE_TEX_STEP) / 255.0
			var g := float(merge_group(k, j)) / 255.0
			img.set_pixel(k - CELL_MIN, j - CELL_MIN, Color(v, g, 0.0))
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
	# 공원·병합 rect 는 수퍼블록 하나를 통째로 쓴다 — 대표 셀에서 한 번만 돈다(§33).
	if (dz == Z_PARK or merge_group(k, j) != 0) and not is_super_root(k, j):
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
			# **차도 쪽(`- ex >= r`)과 블록 쪽(`+ ex <= curb`)은 대칭이 아니다**(§36):
			# 차도 쪽으로는 한 뼘도 못 나가고, 블록 쪽으로는 `WALK_OVERHANG` 만큼 수관이
			# 걸친다. 그 여백은 어차피 `BLOCK_SETBACK` 이 비워 둔 자리다.
			var on_z: bool = uz - ex.y >= rz \
				and uz + ex.y <= curb_half_at(kz) + WALK_OVERHANG \
				and ux - ex.x >= rx and seg_ew(kz, kc)
			var on_x: bool = ux - ex.x >= rx \
				and ux + ex.x <= curb_half_at(kx) + WALK_OVERHANG \
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
	rebuild_occluders()


# --- §37 가림 후보 색인 -------------------------------------------------------
## 카메라와 구멍 사이에 든 프롭을 찾으려면 매 프레임 무언가를 훑어야 하는데, 2112개를
## 전수로 필터하면 **프레임당 0.123 ms** 다(계획 감사 실측 — 예산의 0.7% 지만 현재 F1
## 평균 1.52 ms 의 8% 이고 wasm 은 2~5배 느리다). 도시가 이미 32m 격자이므로 그 격자로
## 버킷팅해 수십 개로 줄인다.
##
## **압축하지 않는다.** 버킷이 인덱스를 들기 때문에 소멸 프롭을 제자리 압축하면 모든
## 버킷이 어긋난다. 소멸한 자리는 묘비(`null`)로 남기고 질의에서 건너뛴다 — 프롭은 라운드
## 중 줄기만 하므로 묘비는 삼킨 수로 유계이고, `build()`/`rebuild_occluders()` 가 전면
## 재구축한다.
##
## **중심·반extent 를 배열로 들지 않는다.** 질의는 노드에서 그 프레임의 AABB 를 다시 읽으므로
## (`occluders._coverage`) 캐시가 필요 없고, 들고 있으면 흡입 중 움직이는 프롭에 대해
## **색인과 실제가 어긋난 두 벌**이 생긴다. 버킷 키를 만드는 데만 쓰고 버린다.
var _occ_node: Array[Node3D] = []
var _occ_bucket := {}                     # Vector2i -> PackedInt32Array
## 질의 pad 와 탐침용. `occ_max_h` 는 `tools/probe_occlude.gd` 가 읽는다.
var occ_max_ext := 0.0
var occ_max_h := 0.0


## 판정이 픽스처를 세운 뒤에도 부른다 — 그러지 않으면 **정상 구현이 픽스처를 절대
## 투명화하지 않아 판정이 자기 자신을 탈락시킨다**(계획 감사가 잡았다).
func rebuild_occluders() -> void:
	_occ_node.clear()
	_occ_bucket.clear()
	occ_max_ext = 0.0
	occ_max_h = 0.0
	for c in get_children():
		var n := c as Node3D
		if n == null:
			continue
		var mi: MeshInstance3D = null
		for g in n.get_children():
			var m := g as MeshInstance3D
			if m != null and m.mesh != null:
				mi = m
				break
		if mi == null:
			continue
		var wab: AABB = mi.global_transform * mi.mesh.get_aabb()
		var half := Vector3(wab.size.x * 0.5, wab.size.y, wab.size.z * 0.5)
		var idx := _occ_node.size()
		_occ_node.append(n)
		occ_max_ext = maxf(occ_max_ext, maxf(half.x, half.z))
		occ_max_h = maxf(occ_max_h, half.y)
		var key := Vector2i(floori((wab.position.x + half.x) / PITCH),
			floori((wab.position.z + half.z) / PITCH))
		# **`PackedInt32Array` 는 값 타입이다** — `_occ_bucket[key].append(i)` 는 사전이
		# 돌려준 **임시 사본**에 붙어 조용히 사라진다(실측: 버킷 132개가 전부 0개였고,
		# 후보가 0 이라 기능이 통째로 죽어 있었다). 꺼내서 붙이고 다시 넣는다.
		var arr: PackedInt32Array = _occ_bucket.get(key, PackedInt32Array())
		arr.append(idx)
		_occ_bucket[key] = arr


## 카메라와 구멍 원판 사이에 들 수 있는 프롭들.
##
## 유도: 그림자 점은 `Q = C + (P−C)·t`, `t ≥ 1` 이므로 `Q ∈ 원판` 이면
## **`P.xz ∈ hull(C.xz, 원판)`** 이다. 다만 그것이 보장하는 것은 프롭의 **어떤 점**이지
## **중심**이 아니므로, 껍질의 AABB 를 **네 방향 모두** `occ_max_ext` 만큼 부풀린다.
## 원판만 부풀리면 z 상한이 정확히 `C.z` 가 되어 **카메라가 건물 footprint 안에 든 도심
## 배치**를 놓친다 — 화면이 통째로 막히는 바로 그 배치다(계획 감사 반례).
func occluder_candidates(cam_p: Vector3, hole_p: Vector3, r: float) -> Array:
	var out := []
	if _occ_node.is_empty():
		return out
	var pad := occ_max_ext
	var lo := Vector2(minf(cam_p.x, hole_p.x - r), minf(cam_p.z, hole_p.z - r)) \
		- Vector2(pad, pad)
	var hi := Vector2(maxf(cam_p.x, hole_p.x + r), maxf(cam_p.z, hole_p.z + r)) \
		+ Vector2(pad, pad)
	var k0 := Vector2i(floori(lo.x / PITCH), floori(lo.y / PITCH))
	var k1 := Vector2i(floori(hi.x / PITCH), floori(hi.y / PITCH))
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			var key := Vector2i(kx, kz)
			if not _occ_bucket.has(key):
				continue
			for i in (_occ_bucket[key] as PackedInt32Array):
				var n: Node3D = _occ_node[i]
				if n == null or not is_instance_valid(n):
					_occ_node[i] = null          # 묘비
					continue
				# 지면 아래로 내려간 것만 뺀다. `freeze == false` 나 `held_by_hole()` 로
				# 거르면 **구멍이 커질수록 기능이 꺼진다** — 감지 Area 반경이 곧 구멍
				# 반경이라 이웃 블록 전체가 제외되고, 그 블록이 곧 가장 크게 가리는
				# 것들이다(계획 감사 실측: R=6.73 에서 15개 중 12개, 덮임 100% 포함).
				if n.get("falling") == true:
					continue
				out.append(n)
	return out


## §31 난간 조각. 에셋이 아니라 절차 생성이다(팩에 난간이 없다 — §28 의 시민과 같은
## 판단). 나지막한 콘크리트 난간벽 하나 — 이 카메라 고도에서 "여기서 길이 끝난다" 로
## 읽히는 가장 싼 형태다. 형상·색의 미감은 휴먼 검수의 몫(전역 원칙 §1).
func make_rail(it: Dictionary, idx: int) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(SWALLOWABLE)
	body.collision_layer = 2
	body.collision_mask = 1 | 2
	body.name = "rail_%d" % idx          # 이름은 판정과의 계약이다(§26) — E2·Z7 이 읽는다
	body.position = it["pos"]
	body.rotation.y = it["yaw"]
	body.add_to_group("swallowable")
	body.start_frozen = true

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(RAIL_BODY, RAIL_H, RAIL_T)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.66, 0.66, 0.62)
	bm.material = mat
	mi.mesh = bm
	mi.position.y = RAIL_H * 0.5
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RAIL_BODY, RAIL_H, RAIL_T)
	cs.shape = box
	cs.position.y = RAIL_H * 0.5
	body.add_child(cs)

	body.mass = clampf(RAIL_BODY * RAIL_H * RAIL_T * 0.25, 0.5, 400.0)
	return body


func make_prop(it: Dictionary, idx: int) -> RigidBody3D:
	if it["path"] == RAIL_PATH:
		return make_rail(it, idx)
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
