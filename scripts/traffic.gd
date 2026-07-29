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
const MODELS := [
	{ "path": "res://assets/cars/Taxi.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/Cop.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/NormalCar1.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/NormalCar2.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/SUV.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/SportsCar.obj", "scale": 1.0 },
	{ "path": "res://assets/cars/SportsCar2.obj", "scale": 1.0 },
	{ "path": "res://assets/transport/Ambulance.obj", "scale": 1.05 },
	{ "path": "res://assets/transport/Bus.obj", "scale": 1.96 },
	{ "path": "res://assets/transport/SchoolBus.obj", "scale": 1.84 },
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
				release(i, dt)
				continue
			var want: float = float(c["s"]) + dir * float(c["speed"]) * dt
			# 앞차 뒤에 선다.
			var limit := ahead - follow_gap
			if want * dir > limit:
				want = limit * dir
			c["s"] = want
			ahead = want * dir
			var cell := int(floor(want / CITY.PITCH))
			if cell < CITY.CELL_MIN or cell > CITY.CELL_MAX or not lane_open(lane, cell):
				respawn(i)
			else:
				rb.global_position = lane_pos(lane, want)


## 구멍에 잡힌 차를 교통에서 빼고 물리에 넘긴다.
func release(i: int, _dt: float) -> void:
	var c: Dictionary = _cars[i]
	var rb: RigidBody3D = c["rb"]
	var lane: Dictionary = _lanes[c["lane"]]
	var v := Vector3.ZERO
	if str(lane["axis"]) == "x":
		v.x = float(lane["dir"]) * float(c["speed"])
	else:
		v.z = float(lane["dir"]) * float(c["speed"])
	rb.linear_velocity = v
	_cars.remove_at(i)
	# 총량을 지킨다. 빠진 만큼 차선 입구에서 새로 낸다.
	spawn_one()


## 차선 끝에 닿았거나 없는 구간에 들어간 차를 반대편 입구로 되돌린다.
func respawn(i: int) -> void:
	var c: Dictionary = _cars[i]
	var lane: Dictionary = _lanes[c["lane"]]
	var entry := lane_entry(lane)
	var s := float(entry) * CITY.PITCH + (0.5 if float(lane["dir"]) > 0.0 else 0.5) * CITY.PITCH
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
