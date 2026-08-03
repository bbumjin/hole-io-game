extends SceneTree

## §35 사전 조사 — traffic.gd 에도 시민과 같은 결함이 있는가.
##
## `sweep_orphans()` 가 traffic.gd 에는 `held_by_hole()`/`y<0.0` 게이트도 유예도 없다
## (citizens.gd 는 있다). 차를 **스치기만 하고 지나가면** 같은 결함(닿으면 사라짐)이
## 재현되는지 실측한다. 대상 참조는 **인계 전에** instance_from_id 로 잡아 둔다 —
## `_cars` 인덱스는 인계 순간 바뀐다(핸드오프가 남긴 함정).
##
##   godot --path . --script res://tools/probe_orphan_car.gd

const HOLE_SPEED := 14.0
const APPROACH := 15.0


func _init() -> void:
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("arena", false)
	main.set("judging", true)
	root.add_child(main)
	await process_frame
	await process_frame

	var hole: Node3D = main.get_node("Hole")
	var tr: Node = main.get_node("Traffic")
	tr.spawn_for_judge(24)
	await physics_frame
	print("--- §35 차량 고아 유도 실측 ---")

	for offset_v in [0.0, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
		await run_pass(hole, tr, float(offset_v))
	quit(0)


func run_pass(hole: Node3D, tr: Node, offset: float) -> void:
	var best := -1
	var best_d := INF
	for i in int(tr.car_total()):
		var d: float = flat_dist(tr.car_pos(i), Vector3.ZERO)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		print("옵셋=%.2f 차가 없다" % offset)
		return
	var rb := instance_from_id(int(tr.car_id(best))) as RigidBody3D
	var p0: Vector3 = rb.global_position
	await physics_frame
	var p1: Vector3 = rb.global_position

	var v := (p1 - p0) * 60.0        # m/s (물리 60Hz 전제)
	var speed: float = Vector2(v.x, v.z).length()
	if speed < 0.5:
		print("옵셋=%.2f 차 속도 미검출(%.2f) — 건너뜀" % [offset, speed])
		return
	var dir := Vector3(v.x, 0.0, v.z).normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)

	var t_gate := APPROACH / HOLE_SPEED
	var gate_dir: float = p1.dot(dir) + speed * t_gate + offset
	var gate_cross: float = p1.dot(perp)

	var start: Vector3 = dir * gate_dir + perp * (gate_cross - APPROACH)
	var stop_at: Vector3 = dir * gate_dir + perp * (gate_cross + APPROACH)
	hole.set_radius(1.5)
	hole.move_to(start)
	hole.get_node("/root/HoleRegistry").flush()

	var still_frames_max := 0
	var still_started_at := -1
	var removed_at := -1
	var fell_at := -1
	var handed_at := -1
	var score0: int = hole.score
	var cur := start
	var travel: Vector3 = stop_at - start
	var step: Vector3 = travel.normalized() * (HOLE_SPEED / 60.0)
	var total_len: float = travel.length()
	var traveled := 0.0
	var last_y := 0.0
	var last_tilt := 0.0
	var min_center_d := INF
	for f in 400:
		if traveled < total_len:
			cur += step
			traveled += step.length()
			hole.move_to(cur)
		await physics_frame
		if not is_instance_valid(rb):
			removed_at = f
			break
		if handed_at < 0 and rb.get("freeze") == false:
			handed_at = f
		min_center_d = minf(min_center_d, flat_dist(cur, rb.global_position))
		still_frames_max = maxi(still_frames_max, int(rb.still_frames))
		if still_started_at < 0 and int(rb.still_frames) == 1:
			still_started_at = f
		if fell_at < 0 and rb.falling:
			fell_at = f
		last_y = rb.global_position.y
		var up: Vector3 = rb.global_transform.basis.y
		last_tilt = rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
	var got: int = hole.score - score0
	print(("옵셋=%.2f 최소중심거리=%.2f 인계f=%-4d still최대=%-3d 시작f=%-3d 제거f=%-4d " +
		"낙하f=%-4d 점수=%-3d y=%.2f tilt=%.1f°")
		% [offset, min_center_d, handed_at, still_frames_max, still_started_at,
		   removed_at, fell_at, got, last_y, last_tilt])


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
