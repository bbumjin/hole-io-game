extends Node

const CITY := preload("res://scripts/city.gd")

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
## 무진전 감지(§25). 강이 생기면서 "목표가 강 건너" 가 일상이 됐다 — 축별 슬라이드는
## 둑을 따라 미끄러지게 해 주지만, 목표가 계속 강 건너면 둑을 영원히 밀며 정지한다.
## **배회 지점만 다시 뽑는 것으로는 부족하다**: choose_target 이 sight(70) 안의 최근접
## 먹이를 다시 고르는데 강폭이 32 뿐이라 강 건너 먹이가 최근접인 상황이 흔하다.
## 그래서 목표도 함께 일정 시간 제외한다. 경로 탐색은 도입하지 않는다 —
## 이 게임의 AI 는 조언 수준이면 충분하다.
@export var stuck_frames := 120
@export var stuck_dist := 0.5
@export var ban_frames := 600

var _rng := RandomNumberGenerator.new()
var _hole: Node3D
var _reg: Node
var _target: Node3D = null
var _wander := Vector3.ZERO
var _tick := 0
var _stuck_ref := Vector3.ZERO
## 인스턴스 ID -> 이 틱까지 목표에서 제외
var _banned := {}
## §39: 재선정 위상. 구멍 다섯이 `_tick` 을 0 에서 함께 세면 **같은 물리 프레임에 다섯 번**
## 목표를 고른다 — 한 번 2.1 ms 라 그 프레임이 23 ms 로 튀었다(실측, 초당 3회). 시드에서
## 위상을 뽑아 서로 다른 프레임에 흩는다(시드 1000+i → 0,7,14,1,8).
var _phase := 0
## 지금 목표의 인스턴스 ID (0 = 목표 없음). "목표를 **잃었다**" 와 "원래 **없었다**" 를
## 가르는 데 쓴다 — 없는 상태에서 매 프레임 다시 고르면 2.1 ms 가 매 프레임 든다(§39 감사).
var _target_id := 0
var _city: Node = null


func _ready() -> void:
	_hole = get_parent()
	_reg = get_node("/root/HoleRegistry")
	_rng.seed = ai_seed
	_phase = posmod(ai_seed * 7, retarget_frames)
	_wander = pick_wander()
	var arena := _hole.get_parent()
	_city = arena.get_node_or_null("City") if arena != null else null
	if _city != null and not _city.has_method("food_near"):
		_city = null


func _physics_process(_dt: float) -> void:
	if _hole == null or not is_instance_valid(_hole):
		return
	_tick += 1
	var force := false
	# 무진전이면 배회 지점을 다시 뽑고 지금 목표를 한동안 제외한다(§25).
	if _tick % stuck_frames == 0:
		if _hole.global_position.distance_to(_stuck_ref) < stuck_dist:
			_wander = pick_wander()
			if is_instance_valid(_target):
				_banned[_target.get_instance_id()] = _tick + ban_frames
			_target = null
			force = true
		_stuck_ref = _hole.global_position
	# 주기가 됐거나, 쫓던 목표가 **방금 사라졌으면**(삼켜짐) 다시 고른다. 목표가 원래 없던
	# 상태는 주기를 기다린다 — 그동안은 배회 지점으로 간다.
	var lost := _target_id != 0 and not is_instance_valid(_target)
	if force or lost or (_tick + _phase) % retarget_frames == 0:
		_target = choose_target()
		_target_id = _target.get_instance_id() if _target != null else 0
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
		if h == _hole or not is_instance_valid(h) or is_banned(h):
			continue
		if float(_hole.radius) < float(h.radius) * float(_hole.hole_bite_ratio):
			continue
		var d: float = flat_dist(h.global_position, _hole.global_position)
		if d < sight and d < bd:
			bd = d
			best = h
	if best != null:
		return best
	# §39: 후보 = 시야 안 버킷의 정적 도시 프롭 + 움직이는 것들(`swallowable_dyn`).
	# 도시가 없으면(판정 픽스처만 있는 씬 등) 옛 전수 경로로 간다.
	var here := _hole.global_position
	var cands: Array
	if _city != null:
		cands = _city.food_near(here, sight)
		cands.append_array(get_tree().get_nodes_in_group("swallowable_dyn"))
	else:
		cands = get_tree().get_nodes_in_group("swallowable")
	for o in cands:
		if not is_instance_valid(o):
			continue
		# 거리를 **먼저** 본다 — 후보 대부분이 시야 밖이고, 스크립트 속성 읽기보다 싸다.
		var d2: float = flat_dist(o.global_position, here)
		if d2 >= sight or d2 >= bd:
			continue
		if o.falling or is_banned(o):
			continue
		# 척도는 좁은 쪽 반폭이다(§23) — 외접반경으로 고르면 원 안에 들어가는
		# 길쭉한 물체를 AI 가 통째로 무시한다.
		if not _hole.can_swallow(float(o.fit_radius)):
			continue
		bd = d2
		best = o
	return best


## 무진전 때 제외한 목표인가. 지난 것은 그 자리에서 정리한다.
func is_banned(n: Node) -> bool:
	var id := n.get_instance_id()
	if not _banned.has(id):
		return false
	if _tick >= int(_banned[id]):
		_banned.erase(id)
		return false
	return true


## 지면 안의 임의 지점. 반경에 여유를 두어 가장자리에 붙지 않게 한다.
## §25: 수역은 배회 지점이 될 수 없다 — 도달할 수 없는 곳을 향해 둑을 밀게 된다.
## 시행 횟수를 고정해야 재현성이 유지된다(난수 소비량이 결과에 따라 달라지면 안 된다).
func pick_wander() -> Vector3:
	var lim: float = float(_hole.ground_half) * 0.8
	var out := Vector3.ZERO
	var got := false
	for _i in 8:
		var p := Vector3(_rng.randf_range(-lim, lim), 0.0, _rng.randf_range(-lim, lim))
		if not got and CITY.passable(p):
			out = p
			got = true
	return out


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
