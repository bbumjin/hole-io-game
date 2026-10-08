extends CanvasLayer

## §39 성능 계측. 웹 성능에는 게이트가 없다(§24 — rAF 가 fps 를 묶는다). 그래서 **같은
## 절차를 데스크톱·브라우저·실기기에서 그대로 돌리는** 계측을 게임 안에 둔다.
##
##   웹:      ?perf=1      실시간 오버레이 (fps · 프레임 ms · 드로우콜)
##            ?perf=bench  고정 경로 자동 주행 → 결과표
##   데스크톱: -- --perf / -- --perf-bench
##
## **판정 모드에서는 붙지 않는다**(main.gd 가 judging 이면 만들지 않는다).
##
## 벤치 절차는 **프레임 기준**이다 — 매 프레임 같은 거리(14/60 m)를 민다. dt 로 밀면 느린
## 기기는 같은 경로를 적은 프레임으로 지나가 표본이 기기마다 달라진다. 이렇게 하면 느린
## 기기는 더 오래 걸릴 뿐 **같은 자리에서 같은 수의 프레임**을 잰다.
## 반경은 4 단계로 강제한다(set_radius) — 줌 배율 k 가 0.5 / 1 / 2 / 4 를 지나야 줌에
## 따라 비용이 뒤집히는 최적화(§39 감사: 고정 거리 그림자)를 잡을 수 있다.
## AI 는 돌리되 **아무도 삼키지 못하게** 한다 — 벤치 도중 플레이어가 먹히면 절차가 끊긴다.

const ROUTE := [Vector3(0, 0, 0), Vector3(-48, 0, -48), Vector3(-48, 0, -96),
	Vector3(-140, 0, -96), Vector3(-140, 0, 60), Vector3(60, 0, 60)]
const RADII := [1.5, 5.0, 10.0, 20.0]
const STEP := 14.0 / 60.0
const WARMUP := 30

var bench := false
var _main: Node3D
var _label: Label
var _last := 0
var _win := PackedFloat32Array()
var _fps_t := 0.0
var _fps_n := 0
var _fps := 0.0


func _ready() -> void:
	_main = get_parent()
	layer = 10
	_label = Label.new()
	_label.name = "_perf"
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_last = Time.get_ticks_usec()
	if bench:
		run_bench()


static func draws() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _process(dt: float) -> void:
	if bench:
		return
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	_win.append(ms)
	if _win.size() > 120:
		_win.remove_at(0)
	_fps_t += dt
	_fps_n += 1
	if _fps_t >= 1.0:
		_fps = _fps_n / _fps_t
		_fps_t = 0.0
		_fps_n = 0
	var s := _win.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	var r: float = float(_main.hole.radius) if _main.player_alive() else 0.0
	_label.text = "fps %.0f  avg %.1fms  p99 %.1f  worst %.1f\ndraws %d  R %.2f" % [
		_fps, sum / s.size(), s[int(s.size() * 0.99)], s[s.size() - 1], draws(), r]


## 한 구간의 통계. 결과 줄 형식은 데스크톱·웹 공통이다(사람이 그대로 붙여 넣는다).
static func stats(ms: PackedFloat32Array, dr: PackedInt32Array) -> Dictionary:
	var s := ms.duplicate()
	s.sort()
	var sum := 0.0
	var over := 0
	for v in s:
		sum += v
		if v > 33.4:
			over += 1
	var dsum := 0
	for d in dr:
		dsum += d
	return { "n": s.size(), "avg": sum / s.size(), "p95": s[int(s.size() * 0.95)],
		"p99": s[int(s.size() * 0.99)], "worst": s[s.size() - 1], "over33": over,
		"draws": dsum / maxi(dr.size(), 1) }


func run_bench() -> void:
	var tree := get_tree()
	var boot_ms := Time.get_ticks_msec()
	# 데스크톱 A/B 용. vsync 에 묶이면 여유분이 안 보인다(브라우저는 어차피 못 끈다).
	if OS.get_cmdline_user_args().has("--perf-novsync"):
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for _i in 10:
		await tree.process_frame
	if _main.state == _main.State.HOME:
		_main.begin_round()
	for h in _main.ai_holes:
		if is_instance_valid(h):
			h.hole_bite_ratio = 1e9
	var lines := PackedStringArray(["PERF BENCH  %s" % OS.get_name(),
		"boot %d ms (engine start -> first frame)" % boot_ms,
		"R     k     avg    p95    p99    worst  >33ms  draws"])
	var results := []
	for r in RADII:
		if not _main.player_alive():
			lines.append("player lost — abort")
			break
		var hole: Node3D = _main.hole
		hole.set_radius(r)
		_main.cam.follow(hole, hole.radius, true)
		var ms := PackedFloat32Array()
		var dr := PackedInt32Array()
		var seg := 0
		var t := 0.0
		var frame := 0
		_last = Time.get_ticks_usec()
		while seg < ROUTE.size() - 1 and _main.player_alive():
			_main.time_left = _main.round_seconds         # 벤치 중 판이 끝나지 않게
			var p0: Vector3 = ROUTE[seg]
			var p1: Vector3 = ROUTE[seg + 1]
			var len := p0.distance_to(p1)
			t += STEP
			if t >= len:
				t = 0.0
				seg += 1
				continue
			_main.hole.move_to(p0.lerp(p1, t / len))
			await tree.process_frame
			var now := Time.get_ticks_usec()
			frame += 1
			if frame > WARMUP:
				ms.append((now - _last) / 1000.0)
				dr.append(draws())
			_last = now
			_label.text = "\n".join(lines) + "\nrunning R=%.1f  %d%%" % [r,
				int(100.0 * float(seg) / float(ROUTE.size() - 1))]
		var st := stats(ms, dr)
		var k: float = float(_main.cam.zoom_scale(r))
		lines.append("%-5.1f %-5.2f %-6.2f %-6.2f %-6.2f %-6.1f %-6d %d" % [r, k, st["avg"],
			st["p95"], st["p99"], st["worst"], st["over33"], st["draws"]])
		st["R"] = r
		results.append(st)
	var t0 := Time.get_ticks_usec()
	_main.restart()
	lines.append("restart %d ms" % int((Time.get_ticks_usec() - t0) / 1000.0))
	var out := "\n".join(lines)
	_label.text = out + "\n(done — screenshot this)"
	for l in lines:
		print("PERF ", l)
	print("PERF JSON ", JSON.stringify(results))
	if OS.get_cmdline_user_args().has("--perf-quit"):
		tree.quit(0)
