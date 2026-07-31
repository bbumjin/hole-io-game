extends SceneTree

## §36 녹지 에셋 측정·계약 확인 도구 — 저장소에 **남긴다**.
##
##   godot --headless --path . --script res://tools/measure_nature.gd
##
## 두 가지를 한다.
##
## **① 임포트 계약.** 원본 OBJ 를 개명해 넣을 때 `mtllib` 줄을 함께 고쳐야 하는데,
## 그것이 어긋나면 머티리얼이 통째로 날아간다. 그런데 그 고장은 **어떤 판정에도 안 걸린다**
## — E1 은 서피스가 있으면 통과하고 `MIN_ALBEDOS`(12)는 색 몇 개가 사라져도 안 걸린다
## (실측 49색). 이 저장소는 이미 한 번 데였다: 클립 이름 오타에 기준 15개가 전부 통과했다.
## 그래서 **서피스 수를 계약으로 못 박고 여기서 확인한다.**
##
## **② §36 이 유도에 쓴 수를 재현 가능하게 남긴다.** 표를 문서에만 적어 두면 다음 사람이
## 재현할 수 없고, 재현할 수 없는 수는 규격이 아니다(`measure_char.gd` 와 같은 취지).

const CITY := preload("res://scripts/city.gd")

## 임포트 계약. 개명 대조: StreetTree1 <- CommonTree_3, StreetTree2 <- CommonTree_Autumn_3,
## Shrub1 <- Bush_1, Shrub2 <- Bush_2, Shrub3 <- BushBerries_1 (Quaternius Ultimate Nature Pack).
const SURFACE_CONTRACT := {
	"res://assets/nature/StreetTree1.obj": 3,   # Wood / Green / DarkGreen
	"res://assets/nature/StreetTree2.obj": 3,   # Wood / Orange / LightOrange
	"res://assets/nature/Shrub1.obj": 1,        # Green
	"res://assets/nature/Shrub2.obj": 1,        # Green
	"res://assets/nature/Shrub3.obj": 2,        # Green / Berry
}

## 개명 대조. **서피스 수만으로는 출처를 못 지킨다** — 실제로 `License.txt` 가 계획 1판의
## 대조표(`StreetTree1 <- BirchTree_5`)를 그대로 달고 커밋 직전까지 갔고, 서피스 계약은
## 전부 통과했다(코드 감사가 잡았다). OBJ 는 Blender 헤더에 원본 파일명을 지니므로
## 그것을 읽어 대조한다. 이 저장소가 이미 데인 자리다 — "에셋에 X 가 있는가" 와
## "코드가 X 를 쓰는가" 와 "그것이 우리가 말한 X 인가" 는 서로 다른 질문이다.
const ORIGIN_CONTRACT := {
	"res://assets/nature/StreetTree1.obj": "CommonTree_3",
	"res://assets/nature/StreetTree2.obj": "CommonTree_Autumn_3",
	"res://assets/nature/Shrub1.obj": "Bush_1",
	"res://assets/nature/Shrub2.obj": "Bush_2",
	"res://assets/nature/Shrub3.obj": "BushBerries_1",
}

## E9 의 가로수 판별 축. 판정기 사본과 같은 값을 여기서도 **자기 값으로** 적는다.
const SPEC_TREE_MIN_H := 4.0
const SPEC_TREE_MIN_HALF := 0.60

## 시민 규격(§34). 판정기 사본과 같은 값을 여기서도 **자기 값으로** 적는다.
const CITIZEN_TOP := 1.665
const CITIZEN_LANE := 0.5          # citizens.gd walk_lane_u = road_half + 0.5
const CITIZEN_ARM_HALF := 0.49335  # 팔 span 0.9867 의 절반
## §34 규약: 프롭 반폭은 **월드 y [0.6, 1.4]** 에서 잰다.
const ARM_LO := 0.6
const ARM_HI := 1.4


func _init() -> void:
	var bad := 0
	print("--- ① 임포트 계약(서피스 수) ---")
	for path in SURFACE_CONTRACT:
		var m := load(path) as Mesh
		if m == null:
			print("  %s: 로드 실패" % path)
			bad += 1
			continue
		var want: int = SURFACE_CONTRACT[path]
		var got := m.get_surface_count()
		var tex := 0
		for i in got:
			var sm := m.surface_get_material(i) as StandardMaterial3D
			if sm == null or sm.albedo_texture != null:
				tex += 1
		# 개명 대조: OBJ 의 Blender 헤더에서 원본 파일명을 읽는다.
		var want_src: String = String(ORIGIN_CONTRACT.get(path, ""))
		var got_src := "?"
		var fh := FileAccess.open(path, FileAccess.READ)
		if fh != null:
			for _n in 4:                       # 헤더는 앞 몇 줄 안에 있다
				var ln := fh.get_line()
				var at := ln.find("OBJ File: '")
				if at >= 0:
					got_src = ln.substr(at + 11).get_slice("'", 0).get_basename()
					break
			fh.close()
		var okp: bool = got == want and tex == 0 and got_src == want_src
		if not okp:
			bad += 1
		print("  %-20s 서피스 %d (계약 %d) 텍스처참조 %d  출처 %-20s (계약 %-20s)  %s"
			% [path.get_file(), got, want, tex, got_src, want_src,
			   "OK" if okp else "**FAIL**"])

	print("")
	print("--- ② 보도 규격 대비 실측 ---")
	print("  보도 띠 [road_half, +%.2f] · 중심선 +%.2f · 오버행 +%.2f -> 허용 반extent %.4f"
		% [CITY.SIDEWALK_W, CITY.WALK_CENTER, CITY.WALK_OVERHANG,
		   minf(CITY.WALK_CENTER, CITY.SIDEWALK_W - CITY.WALK_CENTER + CITY.WALK_OVERHANG)])
	print("  시민 점유 바깥끝 %.5f (= %.2f + %.5f) · 시민 콜라이더 꼭대기 %.3f"
		% [CITIZEN_LANE + CITIZEN_ARM_HALF, CITIZEN_LANE, CITIZEN_ARM_HALF, CITIZEN_TOP])
	print("")
	print("  %-14s %6s %7s %8s %8s %8s %8s %8s %8s %7s"
		% ["에셋", "스케일", "높이", "반ext최대", "차도여유", "커브초과",
		   "수관하단", "잎온셋", "팔여유", "좁은반축"])
	for e in CITY.CATALOG:
		var kind := String(e["kind"])
		if kind != "tree" and kind != "bush":
			continue
		report(String(e["path"]), float(e["scale"]), String(e["zone"]))

	print("")
	print("--- ③ 배치 실측 (city.plan, 시드 고정) ---")
	# E9 의 `MIN_STREET_TREES` 와 `RESTART_PROPS` 가 여기서 나온다. 판정기는 씬에서
	# 세고 이 도구는 계획에서 센다 — 두 수가 같아야 한다.
	var city := CITY.new()
	city.enabled = false
	var items: Array = city.plan(city.city_seed)
	var by_path := {}
	var by_zone := {"block": 0, "walk": 0, "road": 0}
	for it in items:
		var k := String(it["path"]).get_file().get_basename()
		by_path[k] = int(by_path.get(k, 0)) + 1
		var z := String(it["zone"])
		if by_zone.has(z):
			by_zone[z] += 1
	var trees: int = int(by_path.get("StreetTree1", 0)) + int(by_path.get("StreetTree2", 0))
	print("  총 %d 개 · block %d · walk %d · road %d (난간 등 %d)"
		% [items.size(), by_zone["block"], by_zone["walk"], by_zone["road"],
		   items.size() - by_zone["block"] - by_zone["walk"] - by_zone["road"]])
	print("  가로수 StreetTree1=%d + StreetTree2=%d = **%d**"
		% [int(by_path.get("StreetTree1", 0)), int(by_path.get("StreetTree2", 0)), trees])
	print("  관목  Shrub1=%d Shrub2=%d Shrub3=%d"
		% [int(by_path.get("Shrub1", 0)), int(by_path.get("Shrub2", 0)),
		   int(by_path.get("Shrub3", 0))])
	# **폴이 가로수로 세어지지 않는지 확인한다.** E9(c)의 판별 축이 실제로 갈라내는가.
	# 높이 하나로는 못 가른다 — 보도의 4m 초과 폴 수를 함께 인쇄해 그것을 보인다.
	print("  보도 폴의 좁은 반축(가로수 문턱 %.2f 미만이어야 한다):" % SPEC_TREE_MIN_HALF)
	var tall_poles := 0
	for e in CITY.CATALOG:
		if String(e["zone"]) != "walk" or String(e["kind"]) == "tree":
			continue
		var m2 := load(String(e["path"])) as Mesh
		if m2 == null:
			continue
		var sz: Vector3 = m2.get_aabb().size * float(e["scale"])
		var half2: float = minf(sz.x, sz.z) * 0.5
		var nm := String(e["path"]).get_file().get_basename()
		var cnt: int = int(by_path.get(nm, 0))
		if sz.y >= SPEC_TREE_MIN_H:
			tall_poles += cnt
		print("    %-22s 높이 %6.3f  좁은 반축 %.4f  배치 %3d%s"
			% [nm, sz.y, half2, cnt,
			   ("  ← 문턱 초과!" if half2 >= SPEC_TREE_MIN_HALF
				and sz.y >= SPEC_TREE_MIN_H else "")])
	print("    → 높이 %.1f 를 넘는 폴이 **%d개**. 높이만 보는 E9(c)는 가로수 %d 를 여기에"
		% [SPEC_TREE_MIN_H, tall_poles, trees])
	print("      묻어 버려 공허해진다. 좁은 반축 %.2f 가 그것을 가른다." % SPEC_TREE_MIN_HALF)

	# ④ **작은 구멍의 먹이 밀도.** §17 이 "첫 끼니는 광장 밖의 트래픽콘·덤불·표지판" 이라고
	# 적었다. §23 이후 통과 여부는 물리가 정하므로 게이트 상수는 없지만, 실제로 삼켜지려면
	# **밑동이 개구부를 지나고 수관이 림에 안 걸려야** 한다(§19·§23). 그래서 두 반경을
	# 따로 센다. 보도 녹지를 덤불에서 가로수로 바꾸면 이 분포가 움직인다 — 판정 4 의 G7
	# (AI 성장)이 그것을 잡는다.
	print("  작은 구멍이 먹을 수 있는 프롭 수 (밑동 외접반경 / 수관 외접반경 기준):")
	for r in [1.5, 2.0, 3.0]:
		var n_base := 0
		var n_full := 0
		for it in items:
			var p2 := String(it["path"])
			if p2 == CITY.RAIL_PATH:
				continue
			var m3 := load(p2) as Mesh
			if m3 == null:
				continue
			var ab3 := m3.get_aabb()
			var s3: float = float(it["scale"])
			var be: Vector4 = city.base_extent(p2, ab3)
			var rb := Vector2(be.x, be.y).length() * s3
			var rf := Vector2(ab3.size.x, ab3.size.z).length() * 0.5 * s3
			if rb < r:
				n_base += 1
			if rf < r:
				n_full += 1
		print("    R=%.1f : 밑동통과 %d · 수관까지통과 %d" % [r, n_base, n_full])
	city.free()

	print("")
	print("계약 위반 %d 건" % bad)
	quit(1 if bad > 0 else 0)


## 한 에셋의 보도 규격 대비 실측. 반extent 는 `city.half_extent` 와 같은 정의(메시 AABB)이고,
## 팔 여유는 §34 규약(`WALK_CENTER - 반폭 - 시민바깥끝`)이다. **반폭은 회전 4방향 최악값**을
## 쓴다 — `make_prop` 이 피벗을 메시 XZ 중심으로 정규화하므로, 줄기가 중심에서 벗어난
## 모델은 90° 회전 넷 중 하나에서 그만큼 차도 쪽으로 밀린다. 이것을 빼먹으면 여유가
## 실제보다 크게 나온다(계획 감사가 잡았다).
func report(path: String, s: float, zone: String) -> void:
	var mesh := load(path) as Mesh
	if mesh == null:
		print("  %s: 로드 실패" % path.get_file())
		return
	var ab := mesh.get_aabb()
	var h := Vector2(ab.size.x, ab.size.z) * 0.5 * s
	var hi := maxf(h.x, h.y)
	var lo := minf(h.x, h.y)
	var cen := Vector2(ab.position.x + ab.size.x * 0.5, ab.position.z + ab.size.z * 0.5)
	# 팔 높이대의 회전 최악 반폭: 메시 XZ 중심에서의 최대 |x|, |z|.
	var arm := 0.0
	# 잎 온셋: **줄기(Wood) 가 아닌 서피스의 최저점.** 수관 셰이프 하단(0.35·H)과 다르다 —
	# 셰이프는 높이의 순수 함수라 잎이 낮은 메시로 갈아 끼워도 안 움직인다. 시민과의
	# **겉보기 관통**을 좌우하는 것은 이쪽이므로 함께 인쇄한다(코드 감사 지적).
	var leaf := INF
	for i in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(i)
		var mat := mesh.surface_get_material(i) as StandardMaterial3D
		var is_wood: bool = mat != null and mat.resource_name.begins_with("Wood")
		for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var w: float = (v.y - ab.position.y) * s
			if w >= ARM_LO and w <= ARM_HI:
				arm = maxf(arm, maxf(absf(v.x - cen.x), absf(v.z - cen.y)) * s)
			if not is_wood:
				leaf = minf(leaf, w)
	var band := ""
	if zone == "walk":
		band = "%8.4f %8.4f %8.4f %8.4f %8.4f" % [
			CITY.WALK_CENTER - hi,                              # 차도 쪽 여유
			CITY.WALK_CENTER + hi - CITY.SIDEWALK_W,            # 커브 초과
			ab.size.y * s * CITY.BASE_FRAC,                     # 수관 셰이프 하단
			(0.0 if is_inf(leaf) else leaf),                    # 잎 메시 온셋
			CITY.WALK_CENTER - arm - (CITIZEN_LANE + CITIZEN_ARM_HALF)]  # 팔 여유
	else:
		band = "%8s %8s %8s %8s %8s" % ["-", "-", "-", "-", "-"]
	print("  %-14s %6.2f %7.3f %8.4f %s %7.4f"
		% [path.get_file().get_basename(), s, ab.size.y * s, hi, band, lo])
