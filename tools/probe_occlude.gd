extends SceneTree

## §37 동작 확인 — 실제 도시에서 가림 투명화가 도는지 재고, 계획이 유도에 쓴 수를
## 재현 가능하게 남긴다.
##
##   godot --path . --script res://tools/probe_occlude.gd
##
## `--headless` 로도 돌지만(픽셀을 안 읽는다) 창 모드가 기본이다.

const CITY := preload("res://scripts/city.gd")
const OCC := preload("res://scripts/occluders.gd")


func _init() -> void:
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("arena", false)
	main.set("judging", true)          # 게임 루프를 재우고 우리가 직접 몬다
	root.add_child(main)
	await process_frame
	await process_frame

	var city: Node3D = main.get_node("City")
	var cam: Camera3D = main.get_node("Camera3D")
	var hole: Node3D = main.get_node("Hole")
	print("--- §37 가림 투명화 실측 ---")
	print("  도시 프롭 %d · 가림 색인 %d · 최대 반extent %.2f · 최대 높이 %.2f"
		% [city.get_child_count(), city._occ_node.size(),
		   city.occ_max_ext, city.occ_max_h])

	# 계획이 쓴 지점들. 판정 스크린샷 지점과 성능 계측 지점을 함께 본다.
	var spots := {
		"origin": Vector3(0, 0, 0),
		"CITY road (-32,16)": Vector3(-32, 0, 16),
		"CITY block (-16,16)": Vector3(-16, 0, 16),
		"CITY inter (-32,32)": Vector3(-32, 0, 32),
		"PERF boul (-48,-80)": Vector3(-48, 0, -80),
		"PERF dense (-48,-48)": Vector3(-48, 0, -48),
		"도심 (16,-16)": Vector3(16, 0, -16),
	}
	for r in [1.5, 6.73, 12.0, 20.0]:
		var worst := 0
		var line := ""
		for name in spots:
			hole.global_position = spots[name]
			hole.set("radius", r)
			cam.follow(hole, r, true)
			var g: int = cam.occluders.last_ghosted
			var c: int = cam.occluders.last_candidates
			worst = maxi(worst, g)
			if r == 1.5:
				line += "\n      %-22s 후보 %3d -> 투명 %d" % [name, c, g]
		print("  R=%5.2f  지점당 최대 동시 투명 = **%d**%s" % [r, worst, line])

	# 성능: 한 프레임의 update() 비용.
	hole.global_position = Vector3(-16, 0, 16)
	hole.set("radius", 12.0)
	var t0 := Time.get_ticks_usec()
	for i in 200:
		cam.follow(hole, 12.0, true)
	var us := float(Time.get_ticks_usec() - t0) / 200.0
	print("  follow+update 200회 평균 = %.4f ms/프레임 (R=12, 후보 %d)"
		% [us / 1000.0, cam.occluders.last_candidates])
	quit(0)
