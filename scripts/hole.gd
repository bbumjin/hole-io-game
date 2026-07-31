extends Node3D

const CITY := preload("res://scripts/city.gd")

## 구멍 반경의 단일 진실 원천(SSOT). 우물의 반경과 깊이가 모두 여기서 파생된다.
## 시작값 1.5 — 크기 게이트(R × 0.45 = 0.675)가 트래픽콘·덤불·표지판만 열어 준다.
## (§23 에서 그 게이트는 사라지고 통과를 물리가 정한다. §36 에서 보도의 덤불이 가로수로
## 바뀌었지만 **먹이 밀도는 안 변했다** — 삼킬 수 있는 프롭은 R=1.5 에서 971 → 968 이고
## 수관까지 통과는 833 → 839 로 오히려 늘었다. `tools/measure_nature.gd` ④ 가 잰다.)
## 5.0 은 시작부터 나무가 걸림 없이 삼켜지고 90초에 지도를 비웠다(플레이 피드백).
@export var radius := 1.5
## 우물 벽 반경 배율. 1.02 가 이음새가 닫히는 최소값(V21), 1.03 은 여유분.
@export var wall_scale := 1.03
## 우물 벽 여유의 절대 하한(월드 단위). 배율만 쓰면 작은 반경에서 여유가
## 서브픽셀로 줄어 이음새가 샌다(V23: radius 1.0 에서 림 전체에 마젠타 프린지).
@export var wall_margin_min := 0.15
## 우물 깊이 = radius * depth_ratio. 5.0 * 2.4 = 12.0 (실측 구성과 동일).
## 근측 림 시선이 바닥에 닿지 않으려면 depth >= 2R*tan(카메라 앙각) 이어야 한다(H9).
@export var depth_ratio := 2.4
## 흡입력(중심 방향). 가장자리에서 덜덜 떨다 빨려드는 느낌을 만든다.
@export var suction := 26.0
## 낙하 오브젝트를 소멸시키는 깊이 = well_depth * kill_ratio.
@export var kill_ratio := 0.8
## AI 목표 선정용 상한(§23). 흡입을 막는 게이트가 **아니다** — 무엇이 들어가는지는
## 이제 물리가 정한다. AI 가 자기보다 큰 것을 쫓느라 굳지 않게 하는 조언일 뿐이다.
## 척도는 물체의 **좁은 쪽 반폭**(fit_radius)이다: 원형 구멍을 통과하는 데 필요한
## 것은 대각선이 아니라 좁은 쪽이다(실측: 택시는 외접반경 2.27 이지만 폭은 0.85).
@export var swallow_ratio := 0.9
## 림 바닥판의 바깥 반경 = radius + 이 값. 구멍 둘레에서 지면을 대신하는 판이므로,
## 감지 범위에 걸친 가장 큰 프롭(반extent 8.2)을 덮고도 남아야 한다.
@export var rim_outer := 30.0
## 림 바닥판의 분할 수. 48 은 우물 메시(radial_segments 48)와 같은 값이라
## 물리 경계와 그려지는 림이 어긋나 보이지 않는다.
@export var rim_segments := 48
## 이 깊이보다 내려가면 "구멍에 빠졌다" 로 본다. 지면 아래로 확실히 내려간 값이어야
## 한다 — 0 으로 두면 림 위에서 덜컹이는 것도 낙하로 오인한다.
@export var fall_depth := 0.6
## 감지 Area 바닥이 낙하 문턱보다 이만큼 더 깊어야 한다(§35). 물체가 기울면 꼭대기가
## 낮아져 문턱이 얕아지므로, 가장 크게 기운 경우에도 문턱을 넘기 전에 Area 를 벗어나지
## 않을 만큼 여유가 있어야 한다. 시민 기준: 직립 문턱 −2.265 · 완전히 누운 문턱 −1.093,
## 둘 다 바닥 −1.8 보다 얕다.
@export var area_fall_margin := 1.2

## 성장: 면적 보존 법칙. R' = sqrt(R^2 + growth_k * r^2)
## 1.0 = 삼킨 단면적을 **그대로** 더한다(순수 면적 보존). 4.0 은 체감이 너무 빨랐다.
@export var growth_k := 1.0
## 지면 반폭. move_to() 가 구멍을 지면 안에 붙잡아 두는 데 쓴다.
## main.gd 가 스폰 시 GROUND_HALF 를 넣어 준다 — 값의 진실 원천은 거기 하나다.
@export var ground_half := 224.0
## 다른 구멍을 삼키려면 이 배수만큼 커야 한다. 동률에서 서로 삼키는 것을 막는다.
@export var hole_bite_ratio := 1.05
## 상대가 이 비율만큼 내 원반 안으로 들어와야 삼킨다(0 = 중심만, 1 = 온전히 포함).
## 중심 포함(0)은 서로 반쯤 걸친 상태에서 죽어 "접촉만 해도 사망" 으로 읽힌다.
@export var bite_depth := 0.8
## 리더보드 표시용 이름.
@export var label := "P"

## 이 구멍이 벌어들인 점수와 삼킨 개수. 4단계의 리더보드가 구멍별로 읽는다.
var score := 0
var swallowed_count := 0

signal swallowed(node: Node3D)
signal grew(from_radius: float, to_radius: float)

@onready var well: MeshInstance3D = $Well
@onready var area: Area3D = $Area
@onready var area_shape: CollisionShape3D = $Area/Shape
## §23. 구멍 둘레의 **물리적 바닥판**(가운데가 뚫린 원판). 감지 범위에 들어온
## 오브젝트는 지면 대신 이것을 딛는다 — 구멍 위에는 바닥이 없으므로 물체가
## 스스로 기울고 빠진다. 통과 조건을 기하로 흉내내지 않는 이유가 이것이다.
@onready var rim_shape: CollisionShape3D = $Rim/Shape

## Area3D 안에 있으나 아직 통과 조건을 만족하지 못한 후보.
var _candidates: Array[RigidBody3D] = []
## 통과 조건을 만족해 레이어를 전환한 낙하 중 오브젝트.
var _falling: Array[RigidBody3D] = []


func _ready() -> void:
	# 공유 sub_resource 를 건드리지 않도록 한 번만 복제해 두고 이후로는 값만 바꾼다.
	well.mesh = well.mesh.duplicate()
	area_shape.shape = area_shape.shape.duplicate()
	rebuild()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


## 반경이 바뀔 때마다 우물 메시·Area3D 셰이프를 SSOT 에서 다시 파생시킨다.
## 하나라도 빠뜨리면 착시가 깨지거나(H7) 감지 범위가 어긋난다.
func rebuild() -> void:
	var m: CylinderMesh = well.mesh
	m.top_radius = wall_radius()
	m.bottom_radius = wall_radius()
	m.height = well_depth()
	well.position.y = -m.height * 0.5     # 상단이 지면 y=0 에 일치

	# 반경 R 짜리 구를 지면 높이에 두면 지면 위에 얹힌 박스(중심 y>0)를 놓치므로
	# 세로로 긴 원기둥을 쓴다. 치수도 전부 SSOT 파생이다.
	#
	# §35: **아래쪽은 낙하 문턱보다 깊어야 한다.** 옛 치수(바닥 = −0.4R)는 R=1.5 에서
	# `fall_depth`(0.6)와 **정확히 같아 여유가 0** 이었다 — 직립 물체가 "꼭대기가 Area
	# 바닥에 닿는 그 프레임" 에 문턱을 넘는 우연으로만 성립했다. 물체가 기울면 꼭대기가
	# 낮아져 문턱에 닿기 전에 Area 를 벗어나고, `_on_body_exited` 가 후보에서 지워
	# `begin_fall` 에 영영 못 닿는다 → 아무도 인수하지 않는 **영구 낙하 개체**가 남는다
	# (실측: 넘어진 시민이 y=−37 까지 떨어져도 삼켜지지 않았다).
	# 큰 반경에서는 −0.4R 이 이미 더 깊으므로 둘 중 깊은 쪽을 쓴다.
	var s: CylinderShape3D = area_shape.shape
	var top_y := radius * 1.2
	var bot_y := minf(-radius * 0.4, -(fall_depth + area_fall_margin))
	s.radius = radius
	s.height = top_y - bot_y
	area_shape.position.y = (top_y + bot_y) * 0.5

	rim_shape.shape.set_faces(rim_faces())


## 림 바닥판의 삼각형들. 안쪽 반경 = 구멍 반경(그려지는 림과 같은 자리),
## 바깥 반경 = radius + rim_outer. 지면(y=0)과 같은 높이라 딛는 면이 이어진다.
##
## 안쪽을 구멍 반경보다 **넓게** 잡으면 물체가 림에 얹히기 전에 빠지고, **좁게**
## 잡으면 눈에 보이는 구멍 위에 투명한 바닥이 생긴다. 시각과 물리의 경계는 같아야 한다.
func rim_faces() -> PackedVector3Array:
	var f := PackedVector3Array()
	var ro: float = radius + rim_outer
	for i in rim_segments:
		var a0: float = TAU * float(i) / float(rim_segments)
		var a1: float = TAU * float(i + 1) / float(rim_segments)
		var i0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var i1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var o0 := Vector3(cos(a0) * ro, 0.0, sin(a0) * ro)
		var o1 := Vector3(cos(a1) * ro, 0.0, sin(a1) * ro)
		# 반시계 방향(위에서 볼 때)으로 감아 법선이 +Y 를 향하게 한다.
		f.append_array([i0, o0, o1])
		f.append_array([i0, o1, i1])
	return f


func set_radius(r: float) -> void:
	radius = r
	rebuild()
	# 자란 뒤에는 지면 여유가 줄어든다. 다시 붙잡아 두지 않으면 경계에 붙어 있던
	# 구멍이 삼킬 때마다 조금씩 지면 밖으로 밀려난다(실측: G5 위반 1회).
	if is_inside_tree():
		move_to(global_position)


## 면적 보존 성장. 삼킨 오브젝트의 단면적이 구멍 단면적에 더해진다.
func grow_by(obj_radius: float) -> void:
	var before := radius
	set_radius(sqrt(radius * radius + growth_k * obj_radius * obj_radius))
	grew.emit(before, radius)


## AI 조언용. 흡입을 막지 않는다(§23) — 무엇이 들어가는지는 물리가 정한다.
func can_swallow(obj_fit_radius: float) -> bool:
	return obj_fit_radius <= radius * swallow_ratio


## 구멍을 지면 안에 붙잡아 이동시킨다. 밖으로 나가면 우물이 허공에 뜨고
## 판정 전제도 깨진다. 플레이어와 AI 가 같은 함수를 쓴다.
##
## §25: 수역도 같은 방식으로 막는다. 막을 때는 **축별로 미끄러뜨린다** — 두 축을 함께
## 거절하면 강기슭에 대각으로 다가간 구멍이 그 자리에 못 박힌다. 한 축씩 시도하면
## 둑을 따라 흐르듯 움직여, 교량 진입로까지 자연스럽게 미끄러져 간다.
func move_to(p: Vector3) -> void:
	var lim: float = ground_half - radius * 1.15
	var t := Vector3(clampf(p.x, -lim, lim), 0.0, clampf(p.z, -lim, lim))
	if CITY.passable(t):
		global_position = t
		return
	var sx := Vector3(t.x, 0.0, global_position.z)
	if CITY.passable(sx):
		global_position = sx
		return
	var sz := Vector3(global_position.x, 0.0, t.z)
	if CITY.passable(sz):
		global_position = sz


## 다른 구멍을 삼킬 수 있는가 — 상대가 `bite_depth` 만큼 내 원반 안으로 들어와야 한다.
##
## 이 조건은 두 번 조정했다.
##   ① `d + Rb <= Ra` (온전히 포함): 거의 성립하지 않아 자유 실행 900프레임에서
##      포식이 0회였고, 비슷한 크기의 구멍들이 우물을 서로 파고든 채 공존했다.
##   ② `d <= Ra` (중심 포함): 성립은 하지만, 비슷한 크기끼리는 중심이 닿는 순간
##      상대의 절반이 아직 밖에 있어 **"접촉만 해도 죽었다"** 로 읽힌다(플레이 피드백).
## 지금은 그 사이다: `d + Rb*0.8 <= Ra` — 상대가 8할쯤 들어와야 삼킨다.
func can_bite(other: Node3D) -> bool:
	if other == self or not is_instance_valid(other):
		return false
	if radius < float(other.radius) * hole_bite_ratio:
		return false
	var d := Vector2(global_position.x - other.global_position.x,
		global_position.z - other.global_position.z).length()
	return d + float(other.radius) * bite_depth <= radius


## 다른 구멍을 흡수한다. 면적을 그대로 더한다 — 오브젝트 흡입의 growth_k 는
## 체감 조정 계수이지만, 구멍끼리는 실제 단면적이므로 보정 없이 R' = sqrt(Ra^2 + Rb^2) 다.
func bite(other: Node3D) -> void:
	var before := radius
	set_radius(sqrt(radius * radius + float(other.radius) * float(other.radius)))
	score += int(other.score)
	swallowed_count += int(other.swallowed_count)
	grew.emit(before, radius)


func _exit_tree() -> void:
	get_node("/root/HoleRegistry").unregister(self)
	# 이 구멍이 사라질 때 우물 안에서 떨어지던 것들을 함께 정리한다.
	# 그러지 않으면 레이어 4·마스크 0 인 채로 **아무와도 부딪히지 않고 영원히 낙하하는**
	# 개체가 남는다 — 아무도 인수하지 않으므로 해제되지도, 점수가 되지도 않는다.
	# **후보도 함께 되돌린다**(§35). 옛 주석은 "Area3D 가 사라질 때 body_exited 가 발화해
	# exit_rim 이 돈다" 고 했지만, 그것에 기대면 신호 순서에 규격이 얹힌다 — 구멍은 서로
	# 잡아먹으므로(bite) 판 중에 실제로 사라지고, 그때 후보가 지면 충돌 없이 남으면
	# 아무 데도 못 딛는 개체가 된다. 여기서 명시적으로 돌려준다.
	for rb in _candidates:
		if is_instance_valid(rb) and rb.has_method("hold_awake"):
			rb.hold_awake(false)
			rb.exit_rim()
	for rb in _falling:
		if is_instance_valid(rb):
			rb.queue_free()


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func wall_radius() -> float:
	return radius + maxf(radius * (wall_scale - 1.0), wall_margin_min)


## 1b 의 kill_depth 등이 참조한다.
func well_depth() -> float:
	return radius * depth_ratio


func swallow_count() -> int:
	return _falling.size()


# --- 흡입 로직 -------------------------------------------------------------

## body_entered 는 등록만 한다. 여기서 곧바로 레이어를 전환하면,
## Area3D 반경 = 구멍 반경이라 중심이 구멍 밖인데 콜라이더만 걸친 오브젝트가
## 지면 충돌을 잃고 구멍 옆 단단한 지면 속으로 가라앉는다.
func _on_body_entered(body: Node3D) -> void:
	if not (body is RigidBody3D) or not body.has_method("begin_fall"):
		return
	var rb := body as RigidBody3D
	if rb.falling or _candidates.has(rb):
		return
	_candidates.append(rb)
	rb.hold_awake(true)      # 지면에 놓인 바디는 수 초 뒤 잠든다(V19)
	rb.enter_rim()           # 지면 대신 림 바닥판을 딛는다(§23)


## 레이어가 4 로 바뀌면 Area3D 가 더 이상 감지하지 않아 body_exited 가 반드시
## 발화한다. 낙하 중인 오브젝트의 이탈 신호는 무시해야 한다.
func _on_body_exited(body: Node3D) -> void:
	if not (body is RigidBody3D):
		return
	var rb := body as RigidBody3D
	if rb.falling:
		return
	_candidates.erase(rb)
	if is_instance_valid(rb) and rb.has_method("hold_awake"):
		rb.hold_awake(false)
		rb.exit_rim()        # 다시 지면을 딛는다


func _physics_process(_dt: float) -> void:
	var here := global_position

	# 후보: 림 바닥판을 딛고 있는 것들. 통과 여부를 기하로 판단하지 않는다 —
	# **지면 아래로 내려갔는가**만 본다. 기울어 빠지는 것도, 걸쳐서 안 빠지는 것도
	# 물리가 정한다(§23).
	for i in range(_candidates.size() - 1, -1, -1):
		var rb := _candidates[i]
		if not is_instance_valid(rb):
			_candidates.remove_at(i)
			continue
		# **꼭대기까지** 지면 아래로 내려갔을 때만 낙하로 본다. 원점만 보면 키 큰
		# 물체가 가지도 림에 닿기 전에 충돌을 잃고 그대로 빠진다(실측).
		#
		# §35: 꼭대기를 **월드 공간**에서 잰다. `top_height` 는 직립 기준 상수라, 넘어진
		# 물체에 그것을 요구하면 실제 형상보다 한참 깊이 내려가야 하고 그 전에 감지 Area 를
		# 벗어난다. 누우면 꼭대기가 낮아지는 것이 물리적으로 맞다.
		if rb.global_position.y + world_top(rb) < -fall_depth:
			rb.begin_fall()          # 확실히 구멍 안 → 서로에 대한 충돌만 끊는다
			_candidates.remove_at(i)
			_falling.append(rb)
		else:
			pull(rb, here)

	var kill_y := -well_depth() * kill_ratio
	for i in range(_falling.size() - 1, -1, -1):
		var rb := _falling[i]
		if not is_instance_valid(rb):
			_falling.remove_at(i)
			continue
		# 소멸은 **우물 안에서만** 일어난다. 구멍이 떠나 버려 우물 밖에 있는 낙하물은
		# 흡입으로 다시 끌어온 뒤에 사라진다 — 지면 아래 아무 데서나 없어지면
		# "먹지도 않았는데 점수가 오른다" 가 된다.
		# **깊이만으로 지우면 안 된다**(§35 에서 실증). 여기에 `y < kill_y*2` 같은 하한을
		# 두면 아직 구멍 밖에 있던 낙하물이 **점수 없이** 사라진다 — judge2 C1 이 기대
		# 성장 5.06 대 실측 3.47, 점수 2028 대 676 으로 즉시 잡았다. 소멸은 아래처럼
		# **우물 안에 있을 때만** 일어나야 하고, 밖으로 밀린 것은 흡입이 끌어온다.
		if rb.global_position.y < kill_y \
				and flat_dist(rb.global_position, here) < radius:
			_falling.remove_at(i)
			# 구멍 둘이 겹쳐 있으면 같은 개체가 양쪽의 _falling 에 들어 있다.
			# 먼저 삼킨 쪽만 세고, 늦은 쪽은 조용히 넘긴다 — 소멸을 기다리면
			# `queue_free` 가 프레임 끝에 도는 사이에 양쪽이 다 세어 버린다.
			if rb.consumed:
				continue
			rb.consumed = true
			grow_by(rb.radius)
			score += int(rb.score_value)
			swallowed_count += 1
			swallowed.emit(rb)
			rb.queue_free()
			kill_y = -well_depth() * kill_ratio      # 성장으로 우물이 깊어졌다
		else:
			pull(rb, here)


func pull(rb: RigidBody3D, here: Vector3, scale := 1.0) -> void:
	# §30: 구멍은 자기가 삼킬 수 없는 물체를 끌지 않는다. 통과 반경이 구멍보다 큰
	# 물체(fit_radius > radius)는 절대 안 삼켜지는 집합(§23)인데 흡입은 받고 있어서,
	# 시작 반경 1.5 구멍이 주차된 구급차·버스를 지도 위로 끌고 다녔다(플레이 피드백 —
	# 가속 26 이 질량 무관이라 22톤 급도 트래픽콘과 같이 끌려온다).
	# 반드시 삼켜지는 집합(외접 < R)은 외접 >= fit 이라 항상 fit < R 이므로 보장은
	# 그대로다. 회색 지대(fit < R < 외접)도 그대로 — 통과는 물리가 정한다.
	# 낙하물 회수도 안전하다: 낙하 시점에 fit < R 이었고 R 은 줄지 않는다.
	# 경사(램프)가 아니라 계단인 이유 — 원칙이 있는 문턱은 fit = R 하나뿐이다(§23 의
	# 집합 경계). 위로 올리면 통과 가능한 것이 흡입을 잃고, 아래로 내리면
	# 구급차(q=0.947)가 부분 흡입을 받아 문제가 남는다.
	if float(rb.fit_radius) > radius:
		return
	var to_center := Vector3(here.x - rb.global_position.x, 0.0, here.z - rb.global_position.z)
	if to_center.length_squared() < 1e-6:
		return
	rb.apply_central_force(to_center.normalized() * suction * scale * rb.mass)


## 콜라이더의 **월드 공간 꼭대기**(강체 원점 기준 높이). 직립이면 `top_height` 와 같고
## 누우면 낮아진다 — §23 의 삼킴 문턱이 회전을 알아야 하는 이유는 `_on_body_exited` 의
## 주석에 적었다. 셰이프가 여럿이면 가장 높은 것을 쓴다(보수적 = 안전한 방향).
func world_top(rb: Node3D) -> float:
	var t := 0.0
	for c in rb.find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var ab: AABB = (rb.global_transform * col.transform) \
			* col.shape.get_debug_mesh().get_aabb()
		t = maxf(t, ab.end.y - rb.global_position.y)
	return t
