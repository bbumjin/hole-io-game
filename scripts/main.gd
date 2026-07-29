extends Node3D

const MOVE_SPEED := 14.0
const GROUND_HALF := 224.0           # PlaneMesh size 448 의 절반 (14x14 도시 블록)
const HOLE_SCENE := preload("res://scenes/hole.tscn")
const HOLE_AI := preload("res://scripts/hole_ai.gd")
const CITY := preload("res://scripts/city.gd")

## 4a: 경쟁 구멍 수. 0 이면 1단계~3단계와 같은 단독 구멍 씬이다.
@export var ai_count := 5
## AI 구멍이 등장하는 각도(원점 기준). 시드 대신 고정 배치로 두어 재현 가능하다.
@export var ai_spawn_radius := 128.0

@onready var registry := get_node("/root/HoleRegistry")
@onready var cam: Camera3D = $Camera3D
@onready var ground: MeshInstance3D = $Ground
@onready var hole: Node3D = $Hole

# screenshot.gd 가 판정하는 동안 uniform 갱신·입력·카메라 추적을 멈추기 위한 플래그.
# set_process(false) 를 쓰면 안 된다 — 엔진이 부모 _ready 직전에 다시 켠다(V20).
# @onready 로 선언해도 안 된다 — Main._ready 직전 대입이 Judge._ready 의 설정을 덮는다.
var judging := false

# 1a~3단계의 판정은 전부 "구멍 하나" 를 전제로 세워졌다. AI 구멍이 있으면
# judge_static 이 화면 밖 구멍까지 판정하고, AI 가 광장의 판정 대상을 먹어
# C1·C3 의 기대값이 깨진다. Judge._ready 가 Main._ready 보다 먼저 도는 것을 이용해
# 단독 구멍 판정에서는 이 플래그를 내린다(judging 과 같은 이유로 @onready 금지).
var arena := true

var ai_holes: Array[Node3D] = []

@onready var hud_root: CanvasLayer = $HUD
@onready var hud: Label = $HUD/Label
@onready var hud_timer: Label = $HUD/Timer
@onready var hud_board: Label = $HUD/Board
@onready var hud_over: Label = $HUD/Over

# --- 4b: 게임 루프 ---------------------------------------------------------
enum State { PLAYING, OVER }
## 한 판의 길이(초). 판정기가 짧게 줄여 종료까지 돌린다.
@export var round_seconds := 120.0
var state := State.PLAYING
var time_left := 0.0
## 승자의 label 과 그때의 점수. 판정기가 독립 계산한 최댓값과 대조한다.
var winner := ""
var winner_score := 0
## 종료 사유 — "time"(시간 만료) 또는 "eaten"(플레이어가 먹힘).
var over_reason := ""

## §20. 판정 대상 8개(소형 6 + 대형 2). **판정 모드에서만** 스폰한다.
##
## 원래는 main.tscn 에 손으로 놓여 있었다. 그러나 이것들은 1a 의 스케일 기준용
## 픽스처이지 게임의 일부가 아니다 — 노랑·파랑 큐브가 광장에 서서 **시작 화면에
## 그대로 보였고**, 도시 에셋과 이질적이었다. §17 이 같은 이유로 `RefBox` 를 지운
## 것과 같은 판단이다. 다만 이쪽은 1b·2·3b·5 판정의 시나리오가 통째로 이 8개 위에
## 서 있으므로 지울 수는 없고, **판정에만 존재하도록** 옮겼다.
##
## 치수·자리를 바꾸면 안 된다. C2 는 "소형 6개를 다 먹어야 대형의 게이트가 열린다"
## 를 시험하고(R 5 → 6.73, 게이트 3.03 > 대형 r 2.83), B1 은 MOVED_TO 가 이것들에서
## 충분히 멀다는 전제 위에 있다(§17).
const JUDGE_SET := [
	["res://scenes/swallowable.tscn", "S0", Vector3(-6.0, 1.31, -8.0)],
	["res://scenes/swallowable.tscn", "S1", Vector3(0.0, 1.31, -9.0)],
	["res://scenes/swallowable.tscn", "S2", Vector3(6.0, 1.31, -9.0)],
	["res://scenes/swallowable.tscn", "S3", Vector3(11.0, 1.31, -4.0)],
	["res://scenes/swallowable.tscn", "S4", Vector3(-11.0, 1.31, -5.0)],
	["res://scenes/swallowable.tscn", "S5", Vector3(3.0, 1.31, -14.0)],
	["res://scenes/swallowable_big.tscn", "B0", Vector3(16.0, 2.0, -2.0)],
	["res://scenes/swallowable_big.tscn", "B1", Vector3(14.0, 2.0, -12.0)],
]

## 플레이어 점수. 구멍이 진실 원천이고 여기서는 되읽기만 한다
## (2단계 판정의 C3 가 이 이름으로 읽는다).
var score: int:
	get:
		return hole.score if is_instance_valid(hole) else 0

var swallowed_total: int:
	get:
		return hole.swallowed_count if is_instance_valid(hole) else 0


func _ready() -> void:
	var gmat: ShaderMaterial = ground.get_surface_override_material(0)
	registry.set_target_material(gmat)
	# 존 지도를 셰이더로 넘긴다(§25). City._ready 가 먼저 도는 것과 무관하게
	# 지도는 상수라 언제든 구울 수 있다. 판정 모드에서도 반드시 걸어야 한다 —
	# 안 걸면 셰이더가 빈 텍스처를 읽어 지도 전체가 도심색이 된다.
	gmat.set_shader_parameter("zone_tex", CITY.zone_texture())
	gmat.set_shader_parameter("ground_half", GROUND_HALF)
	hole.ground_half = GROUND_HALF
	hole.label = "P"
	# 포식 해소는 그 프레임의 이동이 **끝난 뒤** 돌아야 한다. 기본 순서(부모 먼저)
	# 로는 AI 조종자가 Main 다음에 움직여, 이번 프레임에 겹친 쌍이 다음 프레임까지
	# 그대로 남는다 — 그 한 프레임 동안 우물이 서로 파고든 채 그려진다(실측 G6=1).
	process_physics_priority = 100
	registry.register(hole)        # 플레이어가 항상 0번이다(판정기가 [0] 을 쓴다)
	hole.swallowed.connect(_on_swallowed)
	if arena:
		spawn_ai()
	cam.follow(hole, hole.radius, true)
	spawn_judge_set()
	time_left = round_seconds
	update_hud()


## 판정 대상 8개를 규격대로 세운다. **판정 모드가 아니면 아무것도 만들지 않는다** —
## 게임에는 이 픽스처가 존재하지 않는다.
##
## `judging` 은 Judge._ready 가 Main._ready 보다 먼저(자식 → 부모) 세워 두므로
## 여기서 읽을 수 있다. 판정 플래그 없이 실행하면 Judge 는 아무 일도 하지 않고
## 이 함수도 빈손으로 돌아간다.
##
## _ready 와 restart() 가 **같은 함수**를 부른다. 둘 중 하나만 조건을 걸면
## "게임에서는 없는데 재시작하면 나타난다" 가 된다.
func spawn_judge_set() -> void:
	var box := get_node_or_null("Swallowables")
	if box == null or not judging:
		return
	for spec in JUDGE_SET:
		var n: Node3D = load(spec[0]).instantiate()
		n.name = spec[1]
		box.add_child(n)
		n.position = spec[2]


## AI 구멍을 원점 둘레에 고르게 배치한다. 위치를 난수로 뽑지 않는 이유는
## 판정이 같은 시작 배치를 몇 번이든 다시 만들 수 있어야 하기 때문이다.
func spawn_ai() -> void:
	for i in ai_count:
		var h: Node3D = HOLE_SCENE.instantiate()
		var a := TAU * float(i) / float(ai_count)
		h.name = "AI%d" % i
		# 원둘레 위의 이상적 위치를 **격자 교차로로 스냅**한다. 그냥 원 위에 놓으면
		# 구멍이 건물 밑에서 시작해, 그 건물이 착시 판정의 표본을 가린다(실측:
		# 6개 중 3개가 H2 로 탈락). 교차로는 도시 배치가 비워 두는 자리다.
		h.position = snap_to_grid(Vector3(cos(a), 0.0, sin(a)) * ai_spawn_radius)
		add_child(h)
		h.ground_half = GROUND_HALF
		h.label = "AI%d" % (i + 1)
		var drv := Node.new()
		drv.set_script(HOLE_AI)
		drv.ai_seed = 1000 + i
		h.add_child(drv)
		registry.register(h)
		ai_holes.append(h)


## 플레이어 구멍이 아직 살아 있는가. 4단계에서는 플레이어도 먹힐 수 있으므로
## 구멍이 살아 있다는 전제를 두는 모든 곳이 이것을 먼저 물어야 한다
## (실측: 이 가드가 없으면 플레이어가 먹힌 프레임에 `previously freed` 로 죽는다).
func player_alive() -> bool:
	return is_instance_valid(hole)


## 가장 가까운 도로 교차로. 격자 주기는 city.gd 의 규격과 같은 값이다.
func snap_to_grid(p: Vector3) -> Vector3:
	var pitch := 32.0
	return Vector3(round(p.x / pitch) * pitch, 0.0, round(p.z / pitch) * pitch)


func _process(dt: float) -> void:
	if judging:
		return
	registry.flush()
	if state == State.PLAYING:
		time_left = maxf(time_left - dt, 0.0)
		if time_left <= 0.0:
			end_game("time")
	if Input.is_key_pressed(KEY_R) and state == State.OVER:
		restart()
		return
	if not player_alive():
		update_hud()
		return
	if state == State.PLAYING:
		move_hole(dt)
	cam.follow(hole, hole.radius, false, dt)
	update_hud()


## 판을 끝낸다. 승자는 점수 최댓값이며, 동점이면 반경으로 가른다.
## 끝난 뒤에는 모든 구멍의 물리 처리를 멈춘다 — AI 만 세우면 낙하 중이던
## 오브젝트가 계속 소멸하며 점수가 더 올라, "끝났다" 가 상태로 성립하지 않는다.
func end_game(reason: String) -> void:
	if state == State.OVER:
		return
	state = State.OVER
	over_reason = reason
	set_ai(false)
	var best: Node3D = null
	for h in registry.holes():
		if not is_instance_valid(h):
			continue
		h.set_physics_process(false)
		if best == null or int(h.score) > int(best.score) \
				or (int(h.score) == int(best.score) and float(h.radius) > float(best.radius)):
			best = h
	winner = str(best.label) if best != null else ""
	winner_score = int(best.score) if best != null else 0
	update_hud()


## 끝난 판을 **재시작 없이** 진행 상태로 되돌린다.
## 4a 판정이 포식 시나리오에서 플레이어를 잃은 뒤(= 판이 끝난 뒤) 아레나 자유
## 실행을 이어가야 해서 필요하다. end_game 이 멈춘 것을 정확히 되돌린다.
func resume() -> void:
	state = State.PLAYING
	over_reason = ""
	winner = ""
	winner_score = 0
	for h in registry.holes():
		if is_instance_valid(h):
			h.set_physics_process(true)
	set_ai(true)
	hud_over.visible = false


## 판을 처음 상태로 되돌린다. 씬 전체를 reload 하지 않는 이유는 Judge 노드가
## Main 의 자식이라 함께 사라져 재시작을 판정할 수 없기 때문이다.
## 도시는 시드 고정(E4)이고 AI 스폰도 고정 배치라, 되돌린 결과가 최초와 같아야 한다.
func restart() -> void:
	for h in registry.holes().duplicate():
		if is_instance_valid(h):
			registry.unregister(h)
			h.free()
	ai_holes.clear()

	hole = HOLE_SCENE.instantiate()
	hole.name = "Hole"
	add_child(hole)
	hole.ground_half = GROUND_HALF
	hole.label = "P"
	registry.register(hole)
	hole.swallowed.connect(_on_swallowed)
	if arena:
		spawn_ai()

	var city := get_node_or_null("City")
	if city != null:
		for c in city.get_children():
			c.free()
		city.build(city.plan(city.city_seed))

	var box := get_node_or_null("Swallowables")
	if box != null:
		for c in box.get_children():
			c.free()
	spawn_judge_set()

	state = State.PLAYING
	time_left = round_seconds
	winner = ""
	winner_score = 0
	over_reason = ""
	hud_over.visible = false
	cam.follow(hole, hole.radius, true)
	update_hud()


## AI 조종자를 일괄로 켜고 끈다. 판정이 특정 두 구멍만 두고 시나리오를 돌릴 때
## 나머지가 끼어들지 못하게 한다.
func set_ai(on: bool) -> void:
	for h in ai_holes:
		if not is_instance_valid(h):
			continue
		for c in h.get_children():
			if c is Node and c.get_script() == HOLE_AI:
				c.set_physics_process(on)


## 구멍끼리의 포식. 큰 구멍이 작은 구멍을 온전히 덮으면 흡수한다.
## 여기서 도는 이유: 레지스트리는 uniform 버퍼만 책임지고, 승패는 아레나의 일이다.
func _physics_process(_dt: float) -> void:
	if judging or state == State.OVER:
		return
	# 판이 끝난 뒤에도 돌면 구멍끼리 계속 잡아먹어 "끝났다" 가 상태로 성립하지 않는다
	# (실측: T3 가 종료 후 120프레임 동안 레지스트리 변동을 잡았다).
	resolve_bites()


## 성립하는 포식이 남지 않을 때까지 돈다. 한 프레임에 한 쌍만 처리하면 남은 쌍이
## 다음 프레임까지 겹친 채로 남아, 그 프레임의 착시가 깨진다.
## 한 번 삼킬 때마다 구멍이 하나 사라지므로 반드시 끝난다.
## 반환값은 이번에 삼켜진 구멍 수.
func resolve_bites() -> int:
	var n := 0
	# 구멍 수만큼만 돌면 충분하다 — 한 번 삼킬 때마다 하나가 사라진다.
	# (while true 는 GDScript 파서가 반환 경로를 증명하지 못해 거부한다)
	for _guard in registry.holes().size() + 1:
		var eaten: Node3D = null
		var eater: Node3D = null
		for a in registry.holes():
			if not is_instance_valid(a):
				continue
			for b in registry.holes():
				if not is_instance_valid(b) or a == b:
					continue
				if a.can_bite(b):
					eater = a
					eaten = b
					break
			if eaten != null:
				break
		if eaten == null:
			return n
		eater.bite(eaten)
		registry.unregister(eaten)
		ai_holes.erase(eaten)
		var was_player: bool = eaten == hole
		eaten.queue_free()
		n += 1
		if was_player:
			end_game("eaten")      # 플레이어가 먹히면 그 자리에서 판이 끝난다
			return n
	return n


## InputMap 을 쓰지 않는다 — project.godot 에 InputEventKey 를 손으로 직렬화하는 것은
## 오류가 잦다. 1단계 한정이며 2단계에서 InputMap 으로 정식화한다.
func move_hole(dt: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if v == Vector3.ZERO:
		return
	set_hole_position(hole.global_position + v.normalized() * MOVE_SPEED * dt)


## 구멍이 지면 밖으로 나가면 우물이 허공에 뜨고 판정 전제도 깨진다.
func set_hole_position(p: Vector3) -> void:
	hole.move_to(p)


func _on_swallowed(_node: Node3D) -> void:
	update_hud()


## HUD 문구는 한글이다(§21). 쓰는 음절은 `assets/fonts/hud_kr.ttf` 에 서브셋으로
## 들어 있고, **여기에 새 음절을 쓰면 그 글자는 화면에서 사라진다** — 판정 T8 이
## 현재 HUD 가 그리는 모든 문자에 글리프가 있는지 본다. 문구를 바꾸면
## `assets/fonts/README.md` 의 재생성 절차로 폰트를 다시 만들어야 한다.
func update_hud() -> void:
	if player_alive():
		hud.text = "점수 %d    크기 %.2f    삼킴 %d" % [score, hole.radius, swallowed_total]
	else:
		hud.text = "점수 %d    (먹힘)" % score
	hud_timer.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	hud_board.text = leaderboard_text()
	hud_over.visible = state == State.OVER
	if state == State.OVER:
		var head := "시간 종료" if over_reason == "time" else "먹혔다"
		var mine := "승리" if winner == "P" else "패배"
		hud_over.text = "%s\n1위  %s   %d\n나: %s (%d)\nR 키로 다시 시작"\
			% [head, winner, winner_score, mine, score]


## 리더보드. 점수 내림차순, 동점이면 반경 순.
## 구멍이 진실 원천이므로 여기서는 정렬해 문자열로 만들기만 한다.
func leaderboard_text() -> String:
	var hs := []
	for h in registry.holes():
		if is_instance_valid(h):
			hs.append(h)
	hs.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return float(a.radius) > float(b.radius))
	var lines := PackedStringArray([" 순위  이름    점수    크기"])
	for i in hs.size():
		var h: Node3D = hs[i]
		lines.append("%2d.  %-4s %6d  %5.1f" % [i + 1, h.label, h.score, h.radius])
	return "\n".join(lines)
