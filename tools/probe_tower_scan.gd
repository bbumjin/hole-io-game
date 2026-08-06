extends SceneTree

## §37 가림 후보 실측 — kind=="tower"(§0.6 이후 가림의 유일한 후보 종류)로 태그된
## 프롭의 실제 월드 좌표를 나열한다. `--judge3c` [dynamic-cam] 의 주행 시작점을
## 고를 때(어디를 지나야 타워를 몇 개나 스치는지) 이 출력을 근거로 삼는다.
##
##   godot --headless --path . --script res://tools/probe_tower_scan.gd

func _init() -> void:
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("arena", false)
	main.set("judging", true)
	root.add_child(main)
	await process_frame
	await process_frame

	var city: Node3D = main.get_node("City")
	var towers := []
	for c in city.get_children():
		var n := c as Node3D
		if n == null:
			continue
		if String(n.get_meta("kind", "")) == "tower":
			towers.append(n.global_position)
	towers.sort_custom(func(a, b): return a.x < b.x)
	print("tower count = %d" % towers.size())
	for t in towers:
		print("(%.1f, %.1f)" % [t.x, t.z])
	quit(0)
