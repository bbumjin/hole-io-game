extends RefCounted

## §37 가림 투명화 — 카메라와 구멍 사이에 든 프롭을 비운다.
##
## 유저 피드백: "hole이 큰 건물 뒤로 가면 안 보임. 카메라 앞에 큰 건물이 들어와 hole을
## 가리면 투명화 처리 필요"
##
## **왜 생기나.** 카메라는 회전이 상수다(§29) — 앙각 40.236° 고정. 시선 높이는 수평거리 d 에
## 대해 `y = (22/26)·d` 이므로 **높이 h 인 프롭은 구멍에서 카메라 쪽으로 1.1818·h 안에 있으면
## 가린다**(Hospital 19.219m → 22.71m). 배율 `_k` 는 방향에 안 들어가므로 **가림은 스케일
## 불변**이다 — 구멍이 커져도 카메라가 멀어져도 저절로 풀리지 않는다.
##
## **두 함정을 실측으로 피했다**(`tools/probe_transparency.gd`).
##   ① `GeometryInstance3D.transparency` 는 **Compatibility 에서 완전히 무시된다**
##      (배경혼합 Forward+ 0.800 대 Compatibility **0.000**). 웹 배포본이 gl_compatibility 라
##      그것을 썼으면 데스크톱만 초록인 채 웹에서 아무 일도 안 일어난다. → **머티리얼 알파**.
##   ② 물리 질의로는 건물을 못 찾는다 — `make_prop` 의 콜라이더는 높이의 **35%**(BASE_FRAC)
##      뿐이라(Hospital 19.219 → 4.983) 정작 시야를 막는 위쪽 2/3 를 통째로 놓친다.
##      → **보이는 메시 AABB 로 해석적으로** 찾는다.
##
## **검출은 면적으로 한다.** 처음에는 구멍 중심+림 4점에서 선분을 쐈는데, 카메라가 R 에
## 비례해 물러나 표본 간격이 R 로 벌어지는 반면 건물 반extent 는 2~6m 로 고정이라
## **건물이 표본 사이로 빠진다** — 계획 감사 실측으로 R=6.73 에서 75%, R=20 에서 86% 를
## 놓쳤다. 대신 카메라에서 AABB 를 지면에 투영해 **그 프롭이 실제로 가리는 지면 영역**을
## 만들고 원판과의 겹침 **면적**을 잰다. 표본 밀도에 의존하는 항이 없어 R 과 무관하다.

const CITY := preload("res://scripts/city.gd")

## 가려진 프롭의 알파. 0 이 아닌 이유: 도시의 형태가 남아야 방향감이 산다.
const GHOST_ALPHA := 0.20
## 알파 평활 계수. 0.20 까지 약 0.13초 — 팝도 지연도 안 느껴지는 대역.
const FADE_RATE := 12.0

## 켬/끔 문턱(원판 면적 대비 덮임 비율). **히스테리시스**다.
## 면적 판정은 정확해서 스치기만 해도 프롭 전체가 반투명이 된다 — 문턱이 없으면 R=20 에서
## 투명화 219개 중 147개가 원판의 1% 미만을 덮어 **도시가 녹아내린다**(계획 감사 실측).
const COVER_ON := 0.03
const COVER_OFF := 0.015
## 원판 근사 각수. 16각은 참값 대비 최대 1.45%p 틀리는데 문턱 간격이 1.5%p 라 실질 문턱이
## 흐려진다. 32각이면 절반으로 준다(비용 차이는 무시할 수준).
const DISC_SEGMENTS := 32
## 값싼 조기 탈출용 반경 배수. **결정권은 없다** — 결정은 면적이 한다.
const R_EARLY := 0.85

## 투영 안정화. ε 로 y 를 자르는 방식은 **양쪽에서 조인다**: 작으면(1e-4 이하) float32 가
## 무너져 오검출이 생기고(껍질 좌표 1e7), 크면 카메라에 가까운 프롭의 그림자가 원판까지
## 못 뻗는다. 게다가 **카메라가 건물 안에 있으면 어떤 ε 도 안전하지 않다**(도심에서 실제로
## 일어난다 — 카메라는 구멍 뒤 16.5m·높이 14m 이고 타워는 반extent 6m·높이 19m 다).
## 대신 **투영점의 거리를 클램프**한다. 두 방향 모두 안전하고 좌표가 유계다.
const EPS_Y := 0.05
const MAX_PROJ := 2000.0        # 지도 대각선 634 의 3배

var city: Node3D = null

## 프롭별 상태. 키는 instance_id.
##   alpha  현재 알파(1.0 = 불투명)
##   on     지금 가림으로 판정돼 있는가(히스테리시스 상태 비트)
##   mats   서피스별 반투명 사본(재사용)
var _state := {}
## 판정·성능 확인용. `update()` 한 번의 관측값이다.
var last_candidates := 0
var last_ghosted := 0


## `camera_rig.follow()` 가 부른다 — main 3곳과 판정 13곳이 전부 그리로 오므로,
## 여기 걸면 **판정 스크린샷에도 자동으로 반영된다**(판정 모드에서는 `main._process` 가
## 일찍 반환해 `follow` 말고는 도는 것이 없다). `judge_flag()` 와 같은 원칙 —
## 고르는 자리를 하나로 둔다.
func update(cam: Camera3D, hole_pos: Vector3, radius: float, snap: bool, dt: float) -> void:
	if city == null or not is_instance_valid(city):
		return
	var cpos := cam.global_position
	if cpos.y <= EPS_Y:
		return
	var disc := _disc(hole_pos, radius)
	var want := {}
	var cand: Array = city.occluder_candidates(cpos, hole_pos, radius)
	last_candidates = cand.size()
	for n in cand:
		var mi := _mesh_of(n)
		if mi == null:
			continue
		# **캐시 위치를 쓰지 않는다.** 후보는 수십 개뿐이라 그 프레임의 실제 AABB 를 읽는
		# 편이 싸고, 흡입되다 구멍이 떠나 그 자리에 놓인 프롭까지 통째로 정확해진다.
		var wab: AABB = mi.global_transform * mi.mesh.get_aabb()
		var id: int = n.get_instance_id()
		var prev: bool = bool(_state[id]["on"]) if _state.has(id) else false
		var cover := _coverage(cpos, wab, hole_pos, radius, disc)
		var thr: float = COVER_OFF if prev else COVER_ON
		if cover > thr:
			want[id] = n
	last_ghosted = want.size()
	_apply(want, snap, dt)


## 원판을 32각 다각형으로. 넓이 비교의 분모도 이 다각형에서 낸다 — 참값(πR²)을 쓰면
## 근사 오차가 문턱에 그대로 실린다.
func _disc(c: Vector3, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in DISC_SEGMENTS:
		var a := TAU * float(i) / float(DISC_SEGMENTS)
		out.append(Vector2(c.x + cos(a) * r, c.z + sin(a) * r))
	return out


## 프롭이 원판을 덮는 비율. 카메라에서 AABB 여덟 꼭짓점을 지면(y=0)에 투영해
## **그 프롭이 실제로 가리는 지면 영역**(볼록 껍질)을 만들고 원판과 교차시킨다.
func _coverage(cam_p: Vector3, wab: AABB, hole_p: Vector3, r: float,
		disc: PackedVector2Array) -> float:
	var y0 := wab.position.y
	var y1 := wab.position.y + wab.size.y
	var hc := Vector2(hole_p.x, hole_p.z)
	var cxz := Vector2(cam_p.x, cam_p.z)
	var b0 := Vector2(wab.position.x, wab.position.z)
	var b1 := b0 + Vector2(wab.size.x, wab.size.z)

	# **투영하기 전에 반려한다.** 그림자는 `t ∈ [1, tmax]` 로 카메라에서 멀어지며 늘어난
	# 상자들의 합집합이므로, 원본 상자와 `tmax` 로 늘린 상자의 **성분별 합집합** 안에 있다
	# — 곱셈 네 번이면 그 경계를 얻는다. 이 반려가 없으면 후보 187개가 전부 여덟 점 투영과
	# `convex_hull` + `intersect_polygons` 를 타서 **프레임당 0.9 ms** 가 든다(실측).
	# 카메라보다 높은 프롭(도심 타워 소수)은 `tmax` 가 발산하므로 반려를 건너뛰고
	# 정확 경로로 보낸다 — 보수적이라 놓치지 않는다.
	if y1 < cam_p.y - 1.0:
		var tmax: float = cam_p.y / (cam_p.y - y1)
		var s0 := cxz + (b0 - cxz) * tmax
		var s1 := cxz + (b1 - cxz) * tmax
		var lo := b0.min(b1).min(s0.min(s1))
		var hi := b0.max(b1).max(s0.max(s1))
		var near := Vector2(clampf(hc.x, lo.x, hi.x), clampf(hc.y, lo.y, hi.y))
		if near.distance_squared_to(hc) > r * r:
			return 0.0

	var pts := PackedVector2Array()
	for i in 8:
		pts.append(_ground(cam_p, Vector3(
			wab.position.x + wab.size.x * float(i & 1),
			y0 if (i & 2) == 0 else y1,
			wab.position.z + wab.size.z * float((i >> 2) & 1))))
	var hull := Geometry2D.convex_hull(pts)
	# `convex_hull` 은 첫 점을 끝에 되풀이한 **닫힌** 다각형을 돌려준다.
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	if hull.size() < 3:
		return 0.0                      # 넓이가 0 인 그림자는 덮을 수 없다
	var inter := Geometry2D.intersect_polygons(hull, disc)
	if inter.is_empty():
		return 0.0
	var a := 0.0
	for poly in inter:
		a += absf(_area(poly))
	var whole := absf(_area(disc))
	return 0.0 if whole <= 0.0 else a / whole


## 카메라에서 점 p 를 지나는 광선이 지면(y=0)과 만나는 곳.
func _ground(c: Vector3, p: Vector3) -> Vector2:
	var t: float = c.y / maxf(c.y - p.y, EPS_Y)
	var d := Vector2(p.x - c.x, p.z - c.z) * t
	if d.length() > MAX_PROJ:
		d = d.normalized() * MAX_PROJ
	return Vector2(c.x, c.z) + d


## shoelace. `Geometry2D.polygon_area` 는 Godot 4.7 에 없다(감사가 has_method 로 확인).
func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var n := poly.size()
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		s += p.x * q.y - q.x * p.y
	return s * 0.5


func _mesh_of(n: Node3D) -> MeshInstance3D:
	for c in n.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			return mi
	return null


## 목표 알파로 평활하고, 1.0 에 닿으면 override 를 걷는다 — 불투명 경로로 돌려놔야
## 투명 패스 비용과 정렬 문제가 안 남는다.
func _apply(want: Dictionary, snap: bool, dt: float) -> void:
	for id in want:
		if not _state.has(id):
			_state[id] = { "alpha": 1.0, "on": false, "mats": null }
		_state[id]["on"] = true
	var drop := []
	for id in _state:
		var st: Dictionary = _state[id]
		if not want.has(id):
			st["on"] = false
		var node := instance_from_id(id) as Node3D
		if node == null or not is_instance_valid(node):
			drop.append(id)
			continue
		var target: float = GHOST_ALPHA if bool(st["on"]) else 1.0
		var a: float = float(st["alpha"])
		a = target if snap else target + (a - target) * exp(-FADE_RATE * dt)
		if absf(a - target) < 0.004:
			a = target
		st["alpha"] = a
		var mi := _mesh_of(node)
		if mi == null:
			# 메시가 없으면 칠할 것도 없다 — **그냥 `continue` 하면 그 항목이 영원히 안
			# 지워져** `_state` 가 무한히 자란다(오늘은 `update()` 가 메시 있는 것만 넣어
			# 도달 불가지만, 유일한 누수 경로다).
			drop.append(id)
			continue
		if a >= 1.0:
			_clear(mi)
			if not bool(st["on"]):
				drop.append(id)
		else:
			_paint(mi, st, a)
	for id in drop:
		_state.erase(id)


## 서피스별 반투명 사본을 건다. `material_override` 는 프롭 전체를 한 색으로 뭉개므로
## (건물은 서피스가 최대 7개다) 서피스마다 원본을 복제해 알파만 바꾼다.
func _paint(mi: MeshInstance3D, st: Dictionary, a: float) -> void:
	var mats: Array = st["mats"] if st["mats"] != null else []
	if mats.is_empty():
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				mats.append(null)
				continue
			var m: StandardMaterial3D = src.duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mats.append(m)
		st["mats"] = mats
	for i in mats.size():
		var m2: StandardMaterial3D = mats[i]
		if m2 == null:
			continue
		var c := m2.albedo_color
		c.a = a
		m2.albedo_color = c
		if mi.get_surface_override_material(i) != m2:
			mi.set_surface_override_material(i, m2)


func _clear(mi: MeshInstance3D) -> void:
	for i in mi.get_surface_override_material_count():
		if mi.get_surface_override_material(i) != null:
			mi.set_surface_override_material(i, null)
