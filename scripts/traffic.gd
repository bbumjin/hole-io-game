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
## 낙하하지 않았고 멈춰 섰으면 정리한다.
##
## §35: **citizens.gd 와 글자 그대로 같은 게이트를 쓴다.** `tools/probe_orphan_car.gd`
## 실측으로 이 파일에 정확히 같은 결함이 재현됐다 — 차가 인계된 뒤 낙하도 삼킴도 없이
## 65~79프레임 뒤 속도가 `ORPHAN_STILL` 아래로 떨어지자마자 **유예 없이** 제거됐다
## (citizens.gd 수정 전과 같은 모양. 관성 때문에 늦게 사라질 뿐 유예가 없는 것은 같다).
## 공통 함수로 뽑지 않는다 — 두 파일은 독립된 스윕 리스트(`_cars`/`_people`)를 관리하고,
## `ORPHAN_STILL` 상수도 이미 두 파일에 중복돼 있다(이 저장소의 기존 관례).
##
## **§0.6: citizens.gd 와 같은 이유로 정리 = 삭제가 아니라 재동결이다** — 구멍이 스치기만
## 하고 지나간 차가 1초 뒤 화면에서 사라지는 것은 "쓰러진 행인 방치 시 사라짐" 과 같은
## 뿌리다. 그 자리에서 얼려 두면 도로 위의 정적 장애물로 영구히 남고, 나중에 어떤
## 구멍이든 다가오면 `hold_awake(true)` 가 다시 풀어 준다. 재동결된 차가 **두 번째로**
## 스치기만 하면 그 뒤로는 다시 얼지도 `_orphans` 로 돌아오지도 않는다 — 그 시점부터는
## 이 저장소의 일반 도시 프롭과 같은 처지가 된다(citizens.gd 의 같은 주석 참고).
var _orphans := []
const ORPHAN_STILL := 0.35
const ORPHAN_GRACE := 60
const ORPHAN_Y_EPS := 0.02


func sweep_orphans() -> void:
	for n in range(_orphans.size() - 1, -1, -1):
		var rb = _orphans[n]
		if not is_instance_valid(rb):
			_orphans.remove_at(n)
			continue
		if rb.falling:                                  # 구멍이 삼켰다 — 그쪽이 처리한다
			_orphans.remove_at(n)
			continue
		# **구멍이 아직 잡고 있거나 이미 우물 안이면 손대지 않는다.**
		if rb.held_by_hole() or rb.global_position.y < -ORPHAN_Y_EPS:
			rb.still_frames = 0
			continue
		if rb.linear_velocity.length() < ORPHAN_STILL:
			rb.still_frames += 1
			if rb.still_frames >= ORPHAN_GRACE:
				_orphans.remove_at(n)
				rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				rb.freeze = true
		else:
			rb.still_frames = 0


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
