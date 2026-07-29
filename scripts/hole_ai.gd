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


func _ready() -> void:
	_hole = get_parent()
	_reg = get_node("/root/HoleRegistry")
	_rng.seed = ai_seed
	_wander = pick_wander()


func _physics_process(_dt: float) -> void:
	if _hole == null or not is_instance_valid(_hole):
		return
	_tick += 1
	# 무진전이면 배회 지점을 다시 뽑고 지금 목표를 한동안 제외한다(§25).
	if _tick % stuck_frames == 0:
		if _hole.global_position.distance_to(_stuck_ref) < stuck_dist:
			_wander = pick_wander()
			if is_instance_valid(_target):
				_banned[_target.get_instance_id()] = _tick + ban_frames
			_target = null
		_stuck_ref = _hole.global_position
	if _tick % retarget_frames == 0 or not is_instance_valid(_target):
		_target = choose_target()
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
	for o in get_tree().get_nodes_in_group("swallowable"):
		if not is_instance_valid(o) or o.falling or is_banned(o):
			continue
		# 척도는 좁은 쪽 반폭이다(§23) — 외접반경으로 고르면 원 안에 들어가는
		# 길쭉한 물체를 AI 가 통째로 무시한다.
		if not _hole.can_swallow(float(o.fit_radius)):
			continue
		var d2: float = flat_dist(o.global_position, _hole.global_position)
		if d2 < sight and d2 < bd:
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
