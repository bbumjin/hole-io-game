extends Node3D

## §28: 보도를 걷는 시민.
##
## 유저 지적 (2) 의 둘째 줄이다 — "시민 등 동적 오브젝트 추가 필요".
##
## **§34 에서 실제 캐릭터 모델로 바꿨다.** §28 은 "에셋을 조달하지 않는다 — 라이선스·임포트·
## 스케일이 따라온다" 며 캡슐 몸통 + 구 머리로 갔고, 유저 피드백이 그 결정을 뒤집었다
## ("실제 hole.io 는 다양한 복장·모션의 시민 모델을 쓴다"). Kenney Blocky Characters(CC0).
##
## **군중이라서 이 팩이다.** 시민은 260명이고 아래 총량 유지 규칙까지 있다. 화풍이 더 맞는
## Quaternius 팩은 캐릭터당 15,349 정점 · **62본 스키닝**이라 260벌을 WASM 단일 스레드
## gl_compatibility 에서 돌릴 수 없다(LOD 로 줄지 않는 종류의 비용이다). 이 팩은 143 정점 ·
## **스킨 없음** — 애니메이션이 6개 노드의 TRS 뿐이라 스키닝 비용이 0 이다.
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

## 모델 원본 치수(팩 단위). 18종 전부 동일하다(임포트 후 AABB 실측):
## 팔 포함 폭 1.6 · 키 2.7 · 깊이 0.8 · 몸통 0.8×0.6 · **발 발자국 0.8×0.4**.
## 발이 정확히 y=0 에 있어 원점 배치가 그대로 접지다.
const MODEL_H := 2.7
const FOOT_SPAN := Vector2(0.8, 0.4)

## 총 키 1.665 — §28 이 "승용차 지붕(1.4)보다 확실히 커야 사람으로 읽힌다" 로 유도한 값이다
## (처음 1.52 로 잡았더니 화면에서 승용차와 키가 비슷해 안 읽혔다). 그 키를 그대로 지킨다.
const TOP := 1.665
const SCALE := TOP / MODEL_H          # 0.6166667

## 애니메이션 클립 길이(초). **GLB 원본에서 유도한다** — 임포트본을 읽으면 임포터의 키
## 최적화 결과에 규격을 얹게 된다.
const WALK_LEN := 0.6666667
const SPRINT_LEN := 0.5

## 배역은 아래 `ZONE_WARDROBE` 의 합집합이 **유일한 원천**이다(a b c e f j k m p q, 10종).
## 팩 18종 중 도시 보행자로 쓸 것만 골랐다 — 나머지는 로봇·기사·오크·뱀파이어·닌자이고,
## `i` 는 시민처럼 생겼지만 18종 중 **혼자만 KHR_materials_unlit 이 아니라** 그것만 조명을
## 받는다(전수 파싱으로 확인). 열 명 중 하나만 다르게 보이므로 뺐다.
##
## **배역을 되돌리는 것은 상수 하나가 아니다** — 여기 옷장, 판정기의 `SPEC_ZONE_WARDROBE`
## 와 `SPEC_CITIZEN_CAST`, 그리고 §34 가 유도한 채도 축(0.0316)의 재유도까지 따라온다.
## 별도 배역 목록 상수를 두지 않는 이유가 이것이다 — 안 쓰이는 사본이 있으면 그것만
## 고치고 아무 일도 안 일어난다.

## 지구별 복장. §28 은 `COATS` 로 "**도심은 무채색, 나머지는 알록달록**" 이라는 판별 축을
## 세웠고, 그 축은 지켜야 한다(전역 아트 규율의 "판별 축 회귀" 는 치명이다).
##
## **버킷은 PNG 채도가 아니라 렌더 채도로 나눈다** — 플레이어가 보는 것이 관측값이고 두
## 순서는 실제로 어긋난다(PNG 는 f=m=0.17 < j=0.20 인데 렌더는 j 0.390 < f=m 0.422).
## 유도는 `tools/measure_char.gd` 가 재현한다.
##
##   Z0 [0.234 q, 0.390 j]   Z1 [0.422 f, 0.423 m, 0.461 p]
##   Z2 [0.468 e, 0.470 c, 0.484 a]   Z3 [0.527 k, 0.574 b]
##
## **Z0 를 두 종으로 좁힌 이유.** 셋으로 하면(q·j·f) 도심 상한이 나머지 하한과 붙어 축이
## 0.0007 로 무너진다 — 현행 §28(0.0149)보다 나쁘다. 둘이면 0.0316 으로 **오늘의 2.1배**다.
## 하나(q)면 0.156 까지 넓어지지만 도심 시민이 전원 같은 옷이 된다. 가짓수와 축의 맞바꿈에서
## "축을 개선하면서 가짓수 2 를 지키는" 자리를 골랐다.
##
## **10종은 메시가 완전히 같다**(기하 지문 전수 일치). "정장" 도 "제복" 도 그려진 것이지
## 모델링된 것이 아니다 — 실루엣은 열 명 모두 같은 블록 사람이고, **판별은 전적으로 색이
## 진다.** 그래서 이 축을 지켜야 한다.
const ZONE_WARDROBE := {
	0: ["q", "j"],
	1: ["f", "m", "p"],
	2: ["e", "c", "a"],
	3: ["k", "b"],
}

## 배역 씬. 경로가 판정과의 계약이다 — M15 는 구현체의 자기 신고가 아니라 시민 노드에서
## 읽은 `scene_file_path` 를 규격 집합과 대조한다.
static func model_path(letter: String) -> String:
	return "res://assets/characters/character-%s.glb" % letter

var _rng := RandomNumberGenerator.new()
## 각 원소: { rb, mesh, axis, line, u, lo, hi, s, dir, speed, phase }
var _people := []
## 인계했으나 삼켜지지 않은 사람. 멈춰 섰으면 치운다(§27 의 교통과 같은 이유).
var _orphans := []
const ORPHAN_STILL := 0.35
## 멈춘 채 이만큼 이어져야 치운다(§35). 유예가 없으면 구멍이 스쳐 지나간 시민이 **접촉
## 1프레임 만에** 점수도 없이 사라진다 — 유저가 "닿으면 사라진다" 로 본 것이 그것이다.
## §35 실측(`tools/probe_orphan.gd`): 스치기만 한 시민은 `still_frames` 가 정확히
## `ORPHAN_GRACE − 1`(=59)까지 관측된 뒤 제거된다 — judge9 M16c 가 그 등식을 그대로 묻는다.
const ORPHAN_GRACE := 60
## 접촉 관통으로 y 가 살짝 음수가 되는 잡음을 "우물 안" 으로 오판하지 않게 하는 여유.
## 림 위에 정지한 순간 접촉이 아주 조금 파고들 수 있다 — 그것을 낙하로 잘못 읽으면
## `still_frames` 가 영원히 0 으로 묶인다(§35, 지금은 §0.5-A 실측 경로가 이 자리를
## 밟지 않아 무증상이지만, 다음 물리 튜닝이 밟지 않도록 규격에 못박는다).
const ORPHAN_Y_EPS := 0.02
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
		# **구멍이 아직 잡고 있거나 이미 우물 안이면 손대지 않는다.**
		if rb.held_by_hole() or rb.global_position.y < -ORPHAN_Y_EPS:
			rb.still_frames = 0
			continue
		if rb.linear_velocity.length() < ORPHAN_STILL:
			rb.still_frames += 1
			if rb.still_frames >= ORPHAN_GRACE:
				_orphans.remove_at(n)
				rb.queue_free()
		else:
			rb.still_frames = 0


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
##
## §34 에서 시민이 캡슐(폭 0.4)에서 실제 모델(팔 포함 0.9867)로 넓어졌다. 이 값은
## **바꾸지 않았다** — 대신 `city.walk_center_at` 을 +1.0 → +1.34 로 밀었다. 차도 쪽
## 빈 띠가 0.758 뿐이라 어떤 오프셋으로도 팔이 안 들어가기 때문이다. 그 결과 점유가
## [+0.30, +0.70] → **[+0.007, +0.993]** 로 넓어지는데도 가로등까지 여유는 0.058 →
## **0.105** 로 늘었다(덤불 겹침은 0.237 → 0.190). 자세한 산술은 PLAN.md §34.
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
		# **난수 소비 순서를 지킨다** — dir → speed → phase. 하나만 빼도 스트림이 밀려
		# 260명이 통째로 다른 자리에 선다(§34 가 bob 을 지우면서 phase 를 남긴 이유다).
		var dir := 1.0 if _rng.randf() < 0.5 else -1.0
		var speed := walk_speed * _rng.randf_range(0.8, 1.25)
		var phase := _rng.randf() * TAU
		_people.append({ "rb": rb, "anim": anim_of(rb), "clip": "", "t": anim_t0(phase),
			"axis": w["axis"], "line": w["line"], "u": w["u"],
			"lo": w["lo"], "hi": w["hi"], "s": s,
			"dir": dir, "speed": speed, "phase": phase })


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
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var speed := walk_speed * _rng.randf_range(0.8, 1.25)
	var phase := _rng.randf() * TAU
	_people.append({ "rb": rb, "anim": anim_of(rb), "clip": "", "t": anim_t0(phase),
		"axis": w["axis"], "line": w["line"], "u": w["u"],
		"lo": w["lo"], "hi": w["hi"], "s": s,
		"dir": dir, "speed": speed, "phase": phase })


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

	# **variant 는 난수를 쓰지 않는다.** §28 의 `COATS[dz][idx % 3]` 과 같은 결이다 —
	# 여기서 `_rng` 를 한 번이라도 당기면 스트림이 밀려 260명의 배치·방향·속도가 전부
	# 달라진다(스폰 루프가 사람마다 정해진 횟수만 소비하는 것을 전제로 서 있다).
	var wardrobe: Array = ZONE_WARDROBE[dz] if ZONE_WARDROBE.has(dz) else ZONE_WARDROBE[2]
	var letter: String = wardrobe[idx % wardrobe.size()]
	var model := (load(model_path(letter)) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3(SCALE, SCALE, SCALE)
	body.add_child(model)

	# 콜라이더는 **발 발자국**이다(§34).
	#
	# §17 의 절차(하위 35% 밴드의 XZ bbox)를 그대로 돌리면 안 된다 — 시민은 팔이 y=0.8
	# 까지 내려와 컷(0.945) 아래에 들어가고, 산출이 발 0.8x0.4 가 아니라 **팔 포함
	# 1.6x0.5** 가 된다(성장 기여 +234%, 실측). 전이되는 것은 절차가 아니라 취지다:
	# "지면에 닿아 있는 부분이 곧 지지면". 시민이 닿는 것은 발이다.
	#
	# 이 선택은 밸런스를 사실상 그대로 둔다 — score_value 8 로 §28 과 **같고**, 성장 기여는
	# 0.0800 → 0.0761(−4.9%)이다. 머리 발자국으로 키우면 점수 +50% · 성장 +52% 로 260명
	# 규모에서 판 진행 속도가 바뀐다.
	#
	# **Y 는 전체 키다.** 삼킴 판정(§23)이 보는 것은 `top_height` 이고 그것이 콜라이더
	# 꼭대기에서 나오므로, 여기를 발 높이로 줄이면 사람이 반쯤 잠긴 채 삼켜진다.
	#
	# 상자는 **물리 프록시이지 실루엣이 아니다** — 팔 좌우 각 0.247, 머리 앞뒤 각 0.123,
	# 걸음 중 다리 앞뒤 각 0.498 이 밖에 있다. 이 저장소의 도시 프롭도 전부 같은 성질이다.
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FOOT_SPAN.x * SCALE, TOP, FOOT_SPAN.y * SCALE)
	cs.shape = box
	cs.position.y = TOP * 0.5
	body.add_child(cs)

	body.mass = 3.0
	return body


## 이 시민의 AnimationPlayer. 임포트본은 모델 루트의 **자식**으로 하나를 둔다.
static func anim_of(body: Node) -> AnimationPlayer:
	var model := body.get_node_or_null("Model")
	if model == null:
		return null
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer


## 판정용. M15 는 구현체가 신고하는 variant 가 아니라 **실제 로드된 씬 경로**를 본다 —
## 그래야 "옷장이 한 칸 밀려 A 자리에 B 가 들어간" 결함이 걸린다.
func citizen_scene_path(i: int) -> String:
	var model: Node = (_people[i]["rb"] as Node).get_node_or_null("Model")
	return "" if model == null else model.scene_file_path


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
		var s0: float = float(p["s"])
		var s: float = s0 + float(p["dir"]) * step
		if s < float(p["lo"]):
			s = float(p["lo"])
			p["dir"] = 1.0
		elif s > float(p["hi"]):
			s = float(p["hi"])
			p["dir"] = -1.0
		p["s"] = s
		rb.global_position = walk_pos(p, s)
		# 진행 방향으로 돌려 세운다. **모델은 +Z 를 본다** — Godot 관례(-Z)와 반대이고,
		# 육안이 아니라 렌더 대비로 정했다(머리 밴드의 휘도 표준편차. 얼굴은 밝은 피부 위
		# 어두운 눈이라 대비가 크고 뒤통수는 고르다 — 처음에 "어두운 픽셀 수" 로 물었더니
		# **검은 머리 뒤통수가 얼굴을 이겨서** 지표를 바꿨다).
		# 그래서 이 식에 오프셋이 붙지 않는다: yaw θ 는 +Z 를 (sinθ, 0, cosθ) 로 보내므로
		# θ=+PI/2 → +X 이고 그것이 `axis=="x", dir>0` 의 진행 방향과 같다.
		var yaw: float = 0.0
		if str(p["axis"]) == "x":
			yaw = PI * 0.5 if float(p["dir"]) > 0.0 else -PI * 0.5
		else:
			yaw = 0.0 if float(p["dir"]) > 0.0 else PI
		rb.rotation.y = yaw
		pose(p, absf(s - s0), scare != Vector3.ZERO)


## 걸음을 팩의 애니메이션으로 그린다(§34 — §28 의 사인 bob 을 대신한다).
##
## **AnimationPlayer 를 스스로 돌리지 않는다.** `play` → `pause` → 매 프레임 `seek` 다.
## 그래야 ① 시간이 물리 dt 에서만 오고(결정성) ② 아래 LOD 게이트를 그대로 타며
## ③ **공유 리소스를 건드리지 않는다** — loop_mode 나 머티리얼을 런타임에 고치면 그것은
## 배역 열 종이 나눠 쓰는 리소스라, "최초 1회" 로 세팅하는 순간 한 종만 맞고 아홉 종이
## 어긋난다(그리고 판정이 한 종만 표본하면 초록으로 통과한다).
func pose(p: Dictionary, moved: float, fleeing: bool) -> void:
	var ap: AnimationPlayer = p["anim"]
	if ap == null:
		return
	var clip := "sprint" if fleeing else "walk"
	var clip_len: float = SPRINT_LEN if fleeing else WALK_LEN
	# 클립을 갈아탈 때만 play 한다. **pause() 가 `current_animation` 을 빈 문자열로 만들므로**
	# 그 값으로 물으면 매 프레임 play 가 다시 돈다 — 상태를 따로 기억한다(실측).
	if str(p["clip"]) != clip:
		ap.play(clip)
		ap.pause()
		p["clip"] = clip
	# 애니메이션 시간은 **걸은 거리**에서 나온다(t += 거리 / 규격 속도). 실시각을 쓰면
	# 결정성이 깨지고, dt 만 쓰면 속도가 ±25% 흩어진 시민들의 발이 미끄러진다.
	# LOD 가 네 프레임에 한 번 갱신할 때는 moved 가 네 배이므로 평균이 그대로 맞는다.
	var nominal: float = walk_speed * (flee_mult if fleeing else 1.0)
	var t := fmod(float(p["t"]) + moved / maxf(nominal, 0.001), clip_len)
	p["t"] = t
	# 임포트본은 `loop_mode == LOOP_NONE` 인데 고치지 않는다(공유 리소스다).
	# `fmod` 로 항상 [0, len) 안이라 끝 포즈에 고정될 일이 없다 — 넘겨서 seek 하면 고정된다.
	ap.seek(t, true)


## 시민마다 걸음 위상을 흩어 놓는다. 안 그러면 260명이 발을 맞춰 걷는다.
## §28 이 bob 에 쓰던 `phase` 난수를 그대로 재사용한다 — 지우면 `_rng` 스트림이 밀린다.
static func anim_t0(phase: float) -> float:
	return fmod(phase / TAU, 1.0) * WALK_LEN


## 판을 되돌린다. main.gd 의 restart() 가 부른다(§27 의 교통과 같은 이유).
func reset() -> void:
	for c in get_children():
		c.free()
	_people.clear()
	_orphans.clear()
	# **틱도 되돌린다.** LOD 게이트가 `_tick % 4` 로 갈리므로, 여기를 안 되돌리면 새 판의
	# 시민 갱신 위상이 **직전 판이 얼마나 길었느냐**에 달린다 — 같은 시드로 두 번 돌려도
	# 90프레임 뒤 위치가 달라진다(§34 의 M14 결정성이 잡았다).
	_tick = 0
	boot()


## 판정용.
func citizen_total() -> int:
	return _people.size()


func citizen_pos(i: int) -> Vector3:
	return (_people[i]["rb"] as Node3D).global_position


func citizen_id(i: int) -> int:
	return (_people[i]["rb"] as Node).get_instance_id()


## 판정용. 강체 자체를 넘긴다 — 치수·콜라이더·다리 회전은 **구현체의 신고가 아니라
## 노드에서 직접** 재야 한다(§34 의 M12·M14).
func citizen_body(i: int) -> Node3D:
	return _people[i]["rb"] as Node3D
