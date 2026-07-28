extends RigidBody3D

## 흡입 가능 오브젝트. 레이어 전환·수면 처리는 hole.gd 가 주도하고
## 이 스크립트는 자기 크기와 낙하 상태만 안다.

## XZ 외접반경. 0 이하이면 _ready 에서 콜라이더 AABB 로 산출한다.
## §17 이후 도시 프롭의 콜라이더는 **밑동**에서 따므로, 이 값은 곧 밑동 반경이다.
@export var radius := 0.0
## 수관(가지)까지 포함한 XZ 외접반경 — **보이는 메시** 기준. 0 이하이면 _ready 에서
## 메시 AABB 로 산출한다. 나무처럼 위가 넓은 모델에서만 `radius` 보다 크고,
## 그 차이가 §19 의 걸림(마찰) 모형이 쓰는 유일한 입력이다.
## 둘이 같으면(상자·건물·차량) 걸림 모형은 통째로 무효화된다 — 회귀가 없다는 뜻이다.
@export var snag_radius := 0.0
## 점수. 0 이하이면 단면적에 비례해 산출한다(큰 것을 삼킬수록 많이 받는다).
@export var score_value := 0
## 구멍이 다가올 때까지 정적으로 세워 둘 것인가.
## 이유는 **성능 하나**다 — 도시 프롭 수백 개를 매 프레임 시뮬레이션할 이유가 없다.
## (자세를 지키기 위한 것이 아니다. 고정을 해제해도 180 물리 프레임 동안 최대
##  이동 0.9mm·기울기 0.0001rad 로 멀쩡히 서 있다 — 실측. 초기 스크린샷에서
##  가로등이 넘어진 것처럼 보였던 것은 광각 원근의 착시였다.)
@export var start_frozen := false

var falling := false

var _can_sleep_default := true


func _ready() -> void:
	_can_sleep_default = can_sleep
	if radius <= 0.0:
		radius = auto_radius()
	# 수관은 밑동보다 작을 수 없다. 메시가 없는 오브젝트(콜라이더만 있는 픽스처)는
	# 여기서 radius 로 올라와 걸림 모형이 자동으로 무효가 된다.
	if snag_radius <= 0.0:
		snag_radius = auto_snag_radius()
	snag_radius = maxf(snag_radius, radius)
	if score_value <= 0:
		score_value = int(round(radius * radius * 100.0))
	if start_frozen:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true


## 셰이프가 여럿이면 각각의 XZ 외접반경 중 최대값을 쓴다(보수적 = 안전한 방향).
## XZ 최대 절반값이 아니라 대각선의 절반이다 — 2x2x2 박스에서 1.0 이 아니라 1.414.
## 전자를 쓰면 통과 조건이 최대 41% 일찍 참이 되어 구멍 옆 지면 속으로 가라앉는다.
func auto_radius() -> float:
	# owned=false 가 필수다. 기본값(true)은 owner 가 설정된 노드만 돌려주는데,
	# 코드로 만든 노드(3b 의 도시 프롭)는 owner 가 null 이라 전부 걸러진다
	# — 실측: 도시 프롭 541개가 전부 "CollisionShape3D 가 없다" 로 죽었다.
	var cols := find_children("", "CollisionShape3D", false, false)
	assert(not cols.is_empty(), "swallowable 에 CollisionShape3D 가 없다")
	var r := 0.0
	for c in cols:
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		r = maxf(r, Vector2(s.x, s.z).length() * 0.5)
	return r


## 수관 반경을 **보이는 메시**에서 잰다. 밑동 반경(콜라이더)과 같은 척도여야 하므로
## 여기서도 대각선의 절반을 쓴다. 메시의 XZ 중심 오프셋은 무시한다 — city.gd 가
## 피벗을 모델의 XZ 중심으로 정규화하므로 오프셋은 이미 0 이다(E5 가 그것을 지킨다).
func auto_snag_radius() -> float:
	var r := 0.0
	for m in find_children("", "MeshInstance3D", false, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var s := mi.get_aabb().size * mi.scale.abs()
		r = maxf(r, Vector2(s.x, s.z).length() * 0.5)
	return r


## 구멍 안으로 완전히 들어왔을 때 hole.gd 가 호출한다.
## 지면(layer 1)과 다른 오브젝트(layer 2) 양쪽에서 떨어져 나온다.
## Godot 충돌 판정은 OR 이므로 mask 만 0 으로 해서는 지면을 통과하지 못한다.
func begin_fall() -> void:
	if falling:
		return
	falling = true
	collision_layer = 4
	collision_mask = 0
	sleeping = false


## hole.gd 가 Area3D 진입/이탈에서 호출한다. 정적으로 세워 둔 프롭은
## 구멍이 다가온 이 순간에 비로소 강체가 된다 — 한 번 풀리면 되돌리지 않는다
## (다시 얼리면 구멍 옆에서 반쯤 기울어진 채로 굳는다).
func hold_awake(on: bool) -> void:
	if on and freeze:
		freeze = false
	can_sleep = _can_sleep_default and not on
	if on:
		sleeping = false
