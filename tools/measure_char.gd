extends SceneTree

## §34 캐릭터 측정 도구 — 저장소에 **남긴다**.
##
## `citizens.gd` 의 `ZONE_WARDROBE` 버킷과 판정기의 `SPEC_CITIZEN_SAT_MIN` ·
## `SPEC_HEAD_CONTRAST_MIN` 은 전부 여기서 나온 관측값이다. 표를 문서에만 적어 두면
## 다음 사람이 재현할 수 없고, 재현할 수 없는 수는 규격이 아니다.
##
##   godot --path . --script res://tools/measure_char.gd
##
## **`--headless` 로 돌리면 안 된다** — 렌더 결과를 읽는다.
##
## 두 가지를 잰다.
##   ① 렌더 평균 채도 — 배역을 지구 버킷에 넣는 순서의 원천이자 M11 문턱의 원천.
##      PNG 채도가 아니라 **렌더** 채도다. 둘의 순서는 실제로 어긋난다
##      (PNG 는 f=m=0.17 < j=0.20 인데 렌더는 j 0.390 < f=m 0.422).
##      플레이어가 보는 것이 관측값이다.
##   ② 머리 대비(앞/뒤) — 모델의 정면 축과 M13 문턱의 원천.
##      "어두운 픽셀 수" 로 물으면 **검은 머리 뒤통수가 얼굴을 이긴다**(실측). 얼굴은
##      밝은 피부 위에 어두운 눈이 있어 **대비**가 크다 — 그래서 표준편차로 잰다.
##
## 측정 조건은 규격의 일부다(게임 카메라 각 40.2° 에서 재면 앞뒤 비가 1.14배로
## 무너진다 — 머리가 화면에서 10픽셀 남짓이라 MSAA·태양각이 섞인다).
## 조건을 바꾸면 위 문턱들을 전부 다시 유도해야 한다.

## 팩 18종 전부. 배역 채택분은 `citizens.gd` 의 CAST 가 정한다 — 여기서는 전부 잰다.
const LETTERS := ["a", "b", "c", "d", "e", "f", "g", "h", "i",
	"j", "k", "l", "m", "n", "o", "p", "q", "r"]

## 배경은 캐릭터에 없는 색이어야 배경 픽셀을 정확히 뺄 수 있다.
const BG := Color(1.0, 0.0, 1.0)
## 직교 세로 시야(월드 단위). 캐릭터 키 2.7 을 y=1.35 에 맞춘다 →
## 화면은 월드 y −0.25 ~ 2.95 다.
const ORTHO_SIZE := 3.2
const CAM_Y := 1.35
const CAM_Z := 6.0
## 머리 밴드. 머리는 모델 y 1.9~2.7 → 화면 위에서 7.8% ~ 32.8%.
## 몸통이 섞이면 검은 정장이 얼굴을 이긴다(실측으로 밟았다).
const HEAD_TOP := 0.078
const HEAD_BOT := 0.328


func _init() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)

	# 기본 카메라는 −Z 를 본다. +Z 에 두면 그대로 원점을 향하므로 look_at 이 필요없다
	# (트리에 넣기 전 look_at 은 "Node not inside tree" 로 실패한다).
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO_SIZE
	cam.position = Vector3(0.0, CAM_Y, CAM_Z)
	world.add_child(cam)

	# 채택 모델은 전부 unlit 이라 광원은 결과에 안 들어간다. 그래도 비-unlit 인 종
	# (팩의 i)을 함께 재려면 조명 조건이 고정돼 있어야 하므로 명시해 둔다.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	world.add_child(env)

	print("ch  unlit  픽셀      채도평균   머리대비앞   머리대비뒤   비")
	var rows := []
	for ch in LETTERS:
		var ps := load("res://assets/characters/character-%s.glb" % ch) as PackedScene
		if ps == null:
			print("%s  LOAD FAIL" % ch)
			continue
		var inst := ps.instantiate() as Node3D
		world.add_child(inst)

		inst.rotation = Vector3.ZERO
		await settle()
		var front := root.get_viewport().get_texture().get_image()
		var pix := body_pixels(front)
		var sat := mean_saturation(front)
		var c_front := head_contrast(front)

		inst.rotation = Vector3(0.0, PI, 0.0)
		await settle()
		var c_back := head_contrast(root.get_viewport().get_texture().get_image())

		var ratio := 0.0 if c_back <= 0.0 else c_front / c_back
		print("%s   %-5s  %6d   %.4f     %.4f       %.4f      %.2fx"
			% [ch, str(is_unlit(inst)), pix, sat, c_front, c_back, ratio])
		rows.append({"ch": ch, "sat": sat, "front": c_front, "back": c_back})

		inst.queue_free()
		await process_frame

	# 문턱 유도에 쓰는 요약. 배역을 바꾸면 이 수들이 움직인다.
	var sat_min := INF
	var front_min := INF
	var ratio_min := INF
	var sum_f := 0.0
	var sum_b := 0.0
	for r in rows:
		sat_min = minf(sat_min, float(r["sat"]))
		front_min = minf(front_min, float(r["front"]))
		sum_f += float(r["front"])
		sum_b += float(r["back"])
		if float(r["back"]) > 0.0:
			ratio_min = minf(ratio_min, float(r["front"]) / float(r["back"]))
	print("")
	print("전 18종 요약: 채도 최솟값=%.4f  앞대비 최솟값=%.4f  앞/뒤 최소비=%.2fx  총합비=%.2fx"
		% [sat_min, front_min, ratio_min, 0.0 if sum_b <= 0.0 else sum_f / sum_b])
	print("(SPEC_CITIZEN_SAT_MIN·SPEC_HEAD_CONTRAST_MIN 은 **배역 채택분**의 최솟값에서")
	print(" 유도한다 — 위 요약은 팩 전체다. 채택분만 보려면 CAST 로 걸러 다시 읽어라.)")
	quit()


## 두 프레임 기다린다. 한 프레임만 기다리면 회전이 반영되기 전 화면을 읽는다.
func settle() -> void:
	await process_frame
	await process_frame


func is_unlit(n: Node) -> bool:
	for mi in n.find_children("", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null or m.get_surface_count() == 0:
			continue
		var mat := m.surface_get_material(0) as StandardMaterial3D
		if mat != null:
			return mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	return false


func is_bg(c: Color) -> bool:
	return c.r > 0.9 and c.g < 0.1 and c.b > 0.9


## 캐릭터가 화면에 실제로 그려졌는가. **텍스처가 빠져도 픽셀은 나온다** —
## 그것은 채도가 가른다(흰색은 채도 0).
func body_pixels(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if not is_bg(img.get_pixel(x, y)):
				n += 1
	return n


func mean_saturation(img: Image) -> float:
	var s := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if is_bg(c):
				continue
			s += c.s
			n += 1
	return 0.0 if n == 0 else s / float(n)


## 머리 밴드 안 캐릭터 픽셀의 휘도 표준편차.
func head_contrast(img: Image) -> float:
	var h := img.get_height()
	var y0 := int(float(h) * HEAD_TOP)
	var y1 := int(float(h) * HEAD_BOT)
	var vals := PackedFloat32Array()
	for y in range(y0, y1):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if is_bg(c):
				continue
			vals.append((c.r + c.g + c.b) / 3.0)
	if vals.size() < 20:
		return 0.0
	var mean := 0.0
	for v in vals:
		mean += v
	mean /= float(vals.size())
	var sq := 0.0
	for v in vals:
		sq += (v - mean) * (v - mean)
	return sqrt(sq / float(vals.size()))
