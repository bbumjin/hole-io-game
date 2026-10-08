extends SceneTree

## §39 P0-2 검수: 구운 메시가 원본과 **같게 그려지는가**를 프롭별로 픽셀 대조한다.
##
##   godot --path . --script res://tools/probe_bake_diff.gd                         (Forward+)
##   godot --path . --rendering-driver opengl3 --script res://tools/probe_bake_diff.gd (웹과 같은 백엔드)
##
## 게임과 같은 조명(Sun -55/-35 · 그림자 · 주변광 0.35)에서 원본과 구운 것을 같은 자리·같은
## 카메라로 번갈아 찍어 채널 차를 잰다. LOD 는 끈다(`mesh_lod_threshold = 0`) — LOD 는 거리에
## 따라 원본도 다르게 고르므로 여기서 재는 것은 **굽기 자체**(정점 색·서피스 병합)의 차다.
## 결과: 프롭별 평균 절대차(0~1)와 2/255 를 넘는 픽셀 비율, 마지막 줄에 최악값과 판정.
##
## **고장 주입은 Forward+ 에서 한다.** `vertex_color_is_srgb = false` 주입이 Compatibility 에서는
## 차 0.00067 로 **그대로 통과**했다 — Compatibility 는 sRGB 공간에서 바로 그려 그 플래그를 아예
## 안 탄다(원본·주입본 화면이 바이트 수준으로 같았다). Forward+(선형)에서는 평균차 0.054 로
## 즉시 탈락한다. 두 드라이버 모두 통과해야 하는 이유다 — 웹은 Compatibility 지만 플래그의
## 정오는 Forward+ 만 가린다.

const CITY := preload("res://scripts/city.gd")
const BAKE := preload("res://tools/bake_meshes.gd")
## 허용치. 정점 색은 8비트로 양자화되므로(albedo 는 float) 1/255 수준의 차는 생길 수 있다.
const MEAN_MAX := 0.004
const FRAC_MAX := 0.01


func _init() -> void:
	await process_frame
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	w.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40.0
	w.add_child(cam)
	cam.current = true
	root.mesh_lod_threshold = 0.0
	var mi := MeshInstance3D.new()
	w.add_child(mi)

	var worst_mean := 0.0
	var worst_frac := 0.0
	var n := 0
	var seen := {}
	for e in CITY.CATALOG:
		var p := String(e["path"])
		if seen.has(p):
			continue
		seen[p] = true
		var bp := BAKE.baked_path(p)
		if not ResourceLoader.exists(bp):
			continue
		var orig := load(p) as Mesh
		var baked := load(bp) as Mesh
		var ab := orig.get_aabb()
		var c := ab.get_center()
		var r := ab.size.length() * 0.5
		cam.global_position = c + Vector3(0.0, r * 1.2, r * 2.2)
		cam.look_at(c)
		mi.mesh = orig
		var a := await shot()
		mi.mesh = baked
		var b := await shot()
		var d := diff(a, b)
		if n < 2:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
			a.save_png("res://shots/bakediff_%d_orig.png" % n)
			b.save_png("res://shots/bakediff_%d_baked.png" % n)
		n += 1
		worst_mean = maxf(worst_mean, d.x)
		worst_frac = maxf(worst_frac, d.y)
		print("BAKEDIFF %-48s mean=%.5f over2=%.4f %s" % [p, d.x, d.y,
			"P" if d.x <= MEAN_MAX and d.y <= FRAC_MAX else "F"])
	var ok := n > 0 and worst_mean <= MEAN_MAX and worst_frac <= FRAC_MAX
	print("BAKEDIFF RESULT n=%d worst_mean=%.5f worst_over2=%.4f driver=%s -> %s" % [n,
		worst_mean, worst_frac, RenderingServer.get_current_rendering_driver_name(),
		"PASS" if ok else "FAIL"])
	quit(0 if ok else 1)


func shot() -> Image:
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## (평균 절대 채널차, 어느 채널이든 2/255 를 넘는 픽셀 비율)
func diff(a: Image, b: Image) -> Vector2:
	var sum := 0.0
	var over := 0
	var cnt := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var m := maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))
			sum += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) / 3.0
			if m > 2.0 / 255.0:
				over += 1
			cnt += 1
	return Vector2(sum / cnt, float(over) / cnt)
