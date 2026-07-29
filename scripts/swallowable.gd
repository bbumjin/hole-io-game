extends RigidBody3D

## 흡입 가능 오브젝트. 레이어 전환·수면 처리는 hole.gd 가 주도하고
## 이 스크립트는 자기 크기와 낙하 상태만 안다.

## XZ 외접반경. 0 이하이면 _ready 에서 콜라이더 AABB 로 산출한다.
## §17 이후 도시 프롭의 콜라이더는 **밑동**에서 따므로, 이 값은 곧 밑동 반경이다.
@export var radius := 0.0
## 원형 구멍을 통과하는 데 필요한 반경 — 콜라이더의 **좁은 쪽 반폭**이다(§23).
## `radius`(외접반경)로 이것을 대신하면 길쭉한 물체가 부당하게 거절된다:
## 택시는 외접반경 2.27 이지만 폭은 0.85 이고, 원 안에 들어와 보이는데도 안 먹혔다
## (플레이 피드백). AI 목표 선정이 이 값을 쓴다.
@export var fit_radius := 0.0
## 점수. 0 이하이면 단면적에 비례해 산출한다(큰 것을 삼킬수록 많이 받는다).
@export var score_value := 0
## 구멍이 다가올 때까지 정적으로 세워 둘 것인가.
## 이유는 **성능 하나**다 — 도시 프롭 수백 개를 매 프레임 시뮬레이션할 이유가 없다.
## (자세를 지키기 위한 것이 아니다. 고정을 해제해도 180 물리 프레임 동안 최대
##  이동 0.9mm·기울기 0.0001rad 로 멀쩡히 서 있다 — 실측. 초기 스크린샷에서
##  가로등이 넘어진 것처럼 보였던 것은 광각 원근의 착시였다.)
@export var start_frozen := false

var falling := false
## 콜라이더의 가장 높은 점(원점 기준). "구멍 안으로 들어갔다" 를 이 값으로 판단한다 —
## 원점만 보면 **키 큰 물체가 가지도 닿기 전에 낙하로 전환된다**(실측: 수관 픽스처가
## 밑동 0.6m 만 잠기고도 충돌을 잃어 그대로 통과했다).
var top_height := 0.0

var _can_sleep_default := true
## 이 물체를 감지 범위에 두고 있는 구멍의 수(§23).
var _rim_refs := 0


func _ready() -> void:
	_can_sleep_default = can_sleep
	if radius <= 0.0:
		radius = auto_radius()
	if fit_radius <= 0.0:
		fit_radius = auto_fit_radius()
	top_height = auto_top_height()
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


## 통과 반경 = **가장 잘 눕혔을 때의 외접반경**.
##
## 좁은 쪽 반폭만 보면 안 된다 — 한 변 2.6 인 정육면체는 폭이 1.3 이지만 대각선이
## 3.68 이라 지름 3.4 인 구멍에 **모서리로 얹힌다**(실측: 그래서 한 개도 안 빠졌다).
## 반대로 외접반경만 보면 길쭉한 차가 부당하게 거절된다(택시 2.27, 실제 폭 0.85).
## 물체를 가장 유리하게 눕히면 통과 단면은 **가장 작은 두 반extent** 가 만드는
## 직사각형이므로, 그 외접반경이 규격이다: sqrt(h1^2 + h2^2), h1 <= h2 <= h3.
func auto_fit_radius() -> float:
	var r := INF
	for c in find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		var h := [s.x * 0.5, s.y * 0.5, s.z * 0.5]
		h.sort()
		r = minf(r, sqrt(h[0] * h[0] + h[1] * h[1]))
	return radius if is_inf(r) else r


## 콜라이더 전체의 꼭대기 높이(원점 기준).
func auto_top_height() -> float:
	var t := 0.0
	for c in find_children("", "CollisionShape3D", false, false):
		var col := c as CollisionShape3D
		if col.shape == null:
			continue
		var s := col.shape.get_debug_mesh().get_aabb().size
		t = maxf(t, col.position.y + s.y * 0.5)
	return t


## 림 바닥판을 딛기 시작한다 — 지면(레이어 1) 대신 림(레이어 8)과 충돌한다(§23).
## 구멍 위에는 바닥이 없으므로, 여기서부터는 물체가 스스로 기울고 빠진다.
## 구멍 두 개의 감지 범위에 동시에 들어갈 수 있어 **횟수를 센다** — 하나가 떠났다고
## 지면을 되돌리면 나머지 구멍 위에서 지면을 딛고 서 있게 된다.
func enter_rim() -> void:
	_rim_refs += 1
	if not falling:
		collision_mask = (collision_mask & ~1) | 8


func exit_rim() -> void:
	_rim_refs = maxi(_rim_refs - 1, 0)
	if _rim_refs == 0 and not falling:
		collision_mask = (collision_mask & ~8) | 1


## 지면 아래로 확실히 내려갔을 때 hole.gd 가 호출한다(§23 이후로는 **물리가**
## 그 시점을 정한다 — 통과 조건을 기하로 흉내내지 않는다).
## 지면(layer 1)·림(layer 8)·다른 오브젝트(layer 2) 어느 쪽과도 더는 부딪히지 않는다.
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
