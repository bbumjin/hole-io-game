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
static func lane_slots(k: int) -> Array:
	var m := median_at(k)
	var w := road_half_at(k) - m
	if not is_boulevard(k):
		return [[-(m + w * 0.5), 0.0], [m + w * 0.5, 0.0]]
	return [[-(m + w * 0.5), 2.5], [m + w * 0.5, 2.5],
		[-(m + w * 0.25), 0.0], [m + w * 0.25, 0.0],
		[-(m + w * 0.75), 0.0], [m + w * 0.75, 0.0]]


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


## 블록의 사용 가능 구간 [lo, hi]. 대로가 한쪽에만 붙은 블록은 좌우 여백이 다르므로
## (8.5 대 6.0) 가장 가까운 중심선 하나로 재면 대로 쪽 보도를 침범한다.
static func block_span(w: float) -> Vector2:
	var k := floori(w / PITCH)
	return Vector2(float(k) * PITCH + curb_half_at(k) + BLOCK_SETBACK,
		float(k + 1) * PITCH - curb_half_at(k + 1) - BLOCK_SETBACK)


## 블록 내부. 큰 건물 한 채를 먼저 시도하고 남는 자리를 작은 것으로 채운다.
## 자리가 되는지는 add_slot 이 판단한다 — 레이아웃마다 기하를 손으로 맞추지 않는다.
func plan_block(rng: RandomNumberGenerator, b: Vector3, out: Array) -> void:
	# 블록 중앙 자리는 큰 것 전용이다. min_ext 를 안 걸면 이 한 번뿐인 기회를
	# 덤불이 차지해 대형 건물이 도시 전체에서 한두 채로 줄어든다(실측).
	# 대로가 한쪽에 붙은 블록은 격자 중앙과 사용 가능 구간의 중앙이 1.25m 어긋난다.
	# 중앙 슬롯뿐 아니라 산포의 기준점도 함께 옮겨야 한다 — 중앙만 옮기면 나머지
	# 16개가 대로 보도 쪽으로 편향된 채 전부 거절된다.
	var sx := block_span(b.x)
	var sz := block_span(b.z)
	var c := Vector3((sx.x + sx.y) * 0.5, 0.0, (sz.x + sz.y) * 0.5)
	if rng.randf() < 0.45:
		add_slot(rng, c, "block", out, "", 3.5)
	# 산포 반경을 **사용 가능 구간에서 유도한다**(§22). 상수 8.5 를 그대로 쓰면 대로가
	# 붙은 블록(반폭 7.95)에서 축당 6.5% 의 시도가 구간 밖으로 나가 add_slot 이 조용히
	# 거절한다 — 지도의 92%(196블록 중 180)가 그런 블록이라 그만큼 덜 찬다.
	# 구간 반폭을 그대로 쓰지 않고 상한을 씌우는 이유: 이 값은 **중심**의 범위이고
	# 에셋에는 폭이 있어서, 구간 끝까지 벌리면 가장자리 시도가 폭만큼 거절된다.
	#
	# **이 변경은 도시 전체를 다시 흔든다.** 산포 반경이 달라진 블록에서 add_slot 이
	# 고르는 후보가 달라지고, 후보 수에 따라 난수 소비량이 달라져 그 뒤의 시드 흐름이
	# 통째로 어긋나기 때문이다. 대로가 안 붙은 블록(16개)의 산포 반경은 8.5 그대로인데도
	# 블록당 프롭이 6.38 → 5.69 로 바뀐 것이 그 증거다(실측). 계측 결과는 §22 에 있다.
	var spread := Vector2(minf(SPREAD_MAX, (sx.y - sx.x) * 0.5),
		minf(SPREAD_MAX, (sz.y - sz.x) * 0.5))
	for _i in 16:
		add_slot(rng, c + Vector3(rng.randf_range(-spread.x, spread.x), 0.0,
			rng.randf_range(-spread.y, spread.y)), "block", out)


## 보도: 블록 네 변의 중앙선 위에 일정 간격으로 놓는다.
## 변마다 인접 도로의 등급이 다를 수 있으므로 중심선을 변마다 계산한다.
func plan_walk(rng: RandomNumberGenerator, b: Vector3, out: Array) -> void:
	var half: float = PITCH * 0.5
	for side in [-1.0, 1.0]:
		var wz: float = b.z + side * (half - walk_center_at(line_index(b.z + side * half)))
		for t in [-8.0, -3.0, 3.0, 8.0]:
			if rng.randf() < 0.55:
				continue
			add_slot(rng, Vector3(b.x + t, 0.0, wz), "walk", out)
		var wx: float = b.x + side * (half - walk_center_at(line_index(b.x + side * half)))
		for t in [-8.0, -3.0, 3.0, 8.0]:
			if rng.randf() < 0.55:
				continue
			add_slot(rng, Vector3(wx, 0.0, b.z + t), "walk", out)


## 차도: 블록의 -x·-z 쪽 도로만 담당한다. 그래야 인접 블록과 중복 생성되지 않는다.
## 차량은 도로 축 방향으로 세운다 — 방향은 카탈로그에 적지 않고 모델 AABB 의
## 긴 축에서 유도한다(팩마다 모델이 X 로 눕기도, Z 로 눕기도 한다).
## 차선 수와 정차 자리는 둘 다 도로 등급의 함수다 — 대로에는 차가 더 많이, 더 넓게 선다.
func plan_road(rng: RandomNumberGenerator, b: Vector3, out: Array) -> void:
	var half: float = PITCH * 0.5
	var kz := line_index(b.z - half)          # 블록 -z 쪽 동서 도로
	var kx := line_index(b.x - half)          # 블록 -x 쪽 남북 도로
	var tz := road_slots(kx)                  # 동서 도로를 가로지르는 것은 남북 도로다
	var tx := road_slots(kz)
	for i in 4:
		for slot in lane_slots(kz):
			if rng.randf() < 0.55:
				continue
			add_slot(rng, Vector3(b.x + float(tz[i]), 0.0, b.z - half + float(slot[0])),
				"road", out, "x", float(slot[1]))
		for slot in lane_slots(kx):
			if rng.randf() < 0.55:
				continue
			add_slot(rng, Vector3(b.x - half + float(slot[0]), 0.0, b.z + float(tx[i])),
				"road", out, "z", float(slot[1]))


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
## u = 가장 가까운 도로 중심선까지의 거리. 반폭은 그 선의 **등급**에 따라 다르다(§18).
func in_zone(pos: Vector3, ex: Vector2, zone: String) -> bool:
	var kx := line_index(pos.x)
	var kz := line_index(pos.z)
	var ux: float = absf(pos.x - float(kx) * PITCH)
	var uz: float = absf(pos.z - float(kz) * PITCH)
	var rx := road_half_at(kx)
	var rz := road_half_at(kz)
	match zone:
		"road":
			# 동서 도로 또는 남북 도로 중 한쪽에 온전히 들어가면 된다. 세 조건이다:
			#  ① 아스팔트 안   ② 중앙 분리대 밖   ③ 교차로·횡단보도 밖.
			# ②가 없으면 대로 안쪽 자리의 차가 반extent 4.09 까지 허용되어 이중 중앙선을
			#   넘어 반대 차선까지 뻗는다. 일반 도로는 median 이 0 이라 기존과 동일하다.
			# ③은 자리 중심이 아니라 **프롭의 실제 길이**로 잰다. 중심만 빼는 방식은
			#   버스(반길이 4.24)의 차체가 교차로 안에 남는 것을 못 막는다.
			var on_z: bool = uz + ex.y <= rz and uz - ex.y >= median_at(kz) \
				and ux - ex.x >= rx + CROSS_W
			var on_x: bool = ux + ex.x <= rx and ux - ex.x >= median_at(kx) \
				and uz - ex.y >= rz + CROSS_W
			return on_z or on_x
		"walk":
			# 한 축은 보도 띠 안, 다른 축은 교차 도로를 침범하지 않아야 한다.
			var on_z: bool = uz - ex.y >= rz and uz + ex.y <= curb_half_at(kz) \
				and ux - ex.x >= rx
			var on_x: bool = ux - ex.x >= rx and ux + ex.x <= curb_half_at(kx) \
				and uz - ex.y >= rz
			return on_z or on_x
		_:
			# 대로가 한쪽에만 붙은 블록은 좌우 여백이 다르다 — 구간으로 본다.
			var sx := block_span(pos.x)
			var sz := block_span(pos.z)
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
