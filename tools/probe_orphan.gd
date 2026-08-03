extends SceneTree

## §35 사전 조사 — ORPHAN_GRACE(60) 가 실제로 도는 경로가 있는가.
##
## 핸드오프 감사가 남긴 지적: "여섯 시나리오 전부 still_frames 최댓값이 0 이었다" —
## 접근 후 정지(K)·개구부 안(A/G)은 전부 hold_awake 후 그대로 낙하하거나 계속 잡혀
## 있어 still_frames 가 오를 틈이 없다. **정지하지 않고 스쳐 지나가면** 다르다 —
## `_on_body_exited` 가 exit_rim() 을 부르고 GroundBody(레이어1) 지면이 늘 존재하므로
## (실제로 뚫린 것이 아니라 레이어 마스크 트릭이다), 구멍이 멀어져 감지 Area 를 벗어나면
## 그 순간 y 위치에서 즉시 지면에 다시 걸린다. 낙하로 전환되기 전에 벗어나면 **진짜
## 고아**(전신 하나, 낙하도 삼킴도 없이 서 있거나 넘어져 멈춤)가 남을 것이다.
##
##   godot --path . --script res://tools/probe_orphan.gd
##
## 창 모드가 기본이다(물리를 실제로 재현해야 한다).

const CITIZEN_START_R := 1.5


func _init() -> void:
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("arena", false)
	main.set("judging", true)
	root.add_child(main)
	await process_frame
	await process_frame

	var hole: Node3D = main.get_node("Hole")
	var cz: Node = main.get_node("Citizens")
	print("--- §35 고아 유도 실측 ---")

	# 옵셋 배열: 시민을 지나칠 때 옆으로 얼마나 벗어나는가(중심거리 근사).
	for offset_v in [1.55, 1.65, 1.75, 1.85, 2.0, 2.2, 2.5]:
		await run_pass(hole, cz, float(offset_v))
	quit(0)


func run_pass(hole: Node3D, cz: Node, lateral: float) -> void:
	cz.citizen_count = 40
	cz.reset()
	await self.physics_frame
	var best := -1
	var best_d := INF
	for i in int(cz.citizen_total()):
		var d: float = flat_dist(cz.citizen_pos(i), Vector3.ZERO)
		if d < best_d:
			best_d = d
			best = i
	var target: Vector3 = cz.citizen_pos(best)
	var rb: RigidBody3D = cz.citizen_body(best)
	hole.set_radius(CITIZEN_START_R)
	# 시민을 Z 로 lateral 만큼 벗어난 직선을 -X 에서 +X 로 계속 통과한다(정지 없음).
	var line_z: float = target.z + lateral
	var start := Vector3(target.x - 20.0, 0.0, line_z)
	var stop_at := Vector3(target.x + 20.0, 0.0, line_z)
	hole.move_to(start)
	var hr: Node = hole.get_node("/root/HoleRegistry")
	hr.flush()

	var held_frames := 0
	var max_still := 0
	var still_started_at := -1
	var removed_at := -1
	var fell_at := -1
	var score0: int = hole.score
	var cur := start
	var last_valid_pos := target
	var last_valid_tilt := 0.0
	for f in 400:
		if cur.x < stop_at.x:
			cur.x = minf(cur.x + 14.0 / 60.0, stop_at.x)
			hole.move_to(cur)
		await self.physics_frame
		if not is_instance_valid(rb):
			removed_at = f
			break
		if rb.held_by_hole():
			held_frames += 1
		max_still = maxi(max_still, int(rb.still_frames))
		if still_started_at < 0 and int(rb.still_frames) == 1:
			still_started_at = f
		if fell_at < 0 and rb.falling:
			fell_at = f
		last_valid_pos = rb.global_position
		var up: Vector3 = rb.global_transform.basis.y
		last_valid_tilt = rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
	var got: int = hole.score - score0
	var alive := is_instance_valid(rb)
	print(("옵셋=%.2f 잡힌프레임=%-3d still_frames최대=%-3d 시작f=%-3d " +
		"제거f=%-4d 낙하f=%-4d 점수=%-3d 생존=%s y=%.2f tilt=%.1f°")
		% [lateral, held_frames, max_still, still_started_at, removed_at, fell_at,
		   got, str(alive), last_valid_pos.y, last_valid_tilt])


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
