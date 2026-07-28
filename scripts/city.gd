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
