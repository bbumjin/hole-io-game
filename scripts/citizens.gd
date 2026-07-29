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
