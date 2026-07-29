extends CanvasLayer

## §26: 게임 UI — 시작 화면 · 인게임 보강 · 결과 화면.
##
## 노드를 **코드로 만든다.** `.tscn` 손작성은 이 프로젝트가 반복해서 밟은 함정이고
## (§0-D 의 V1~V3b), 화면 셋의 레이아웃을 손으로 직렬화할 이유가 없다. 도시 프롭이
## 코드 생성인 것과 같은 판단이다.
##
## 기존 HUD 라벨 넷(Label·Timer·Board·Over)은 `main.tscn` 에 그대로 둔다 —
## 판정 T8 이 그 넷을 이름으로 찾고, 게임오버 문구는 이미 `main.gd` 가 채운다.
## 여기서는 **덧붙이기만** 한다.

const FONT := preload("res://assets/fonts/hud_kr.ttf")

## 크기 레벨 구간. 반경이 이 문턱을 넘을 때마다 레벨이 오른다.
## hole.io 의 핵심 피드백 장치는 "점수" 가 아니라 **"내가 커지고 있다"** 이고,
## 반경 숫자(1.50)만으로는 그것이 읽히지 않는다.
## 시작 반경 1.5 에서 1레벨, 지도를 비울 만한 45 에서 10레벨이다.
const LEVEL_R := [1.5, 2.5, 4.0, 6.0, 9.0, 13.0, 18.0, 25.0, 34.0, 45.0]

## 킬 피드가 한 줄을 띄워 두는 시간(초).
const FEED_SEC := 3.0
## 점수 팝업이 떠 있는 시간(초).
const POP_SEC := 1.0

## 화면 문구. **여기의 한글 음절은 전부 `tools/font_subset.mjs` 의 집합 안에 있어야
## 한다** — 없는 글자는 에러 없이 사라진다. 문구를 고치면 폰트를 다시 굽고
## 판정기의 SPEC_HUD_CHARS 도 함께 고친다.
const TXT_TITLE := "HOLE.IO"
const TXT_SUB := "도시를 삼켜라"
const TXT_START := "시작"
const TXT_HINT := "이동   WASD   화살표   드래그"
const TXT_AGAIN := "다시 하기"
const TXT_HOME := "홈으로"

var _main: Node3D
var _dim: ColorRect
var _title: Label
var _sub: Label
var _hint: Label
var _start_btn: Button
var _again_btn: Button
var _home_btn: Button
var _level: Label
var _bar: ProgressBar
var _feed: Label
var _pop: Label

var _feed_t := 0.0
var _pop_t := 0.0
var _last_score := 0


func _ready() -> void:
	_main = get_parent()
	layer = 2                                   # 기존 HUD(기본 1) 위에 그린다
	build()
	# 판정 모드에서는 시작 화면이 없다. 1a~4b 판정 전부가 "부팅 즉시 플레이 상태" 를
	# 전제하므로, 여기서 화면 하나를 끼워 넣으면 스물아홉 종이 통째로 깨진다.
	if _main.judging:
		hide_all()
	set_process(not _main.judging)


func build() -> void:
	_dim = ColorRect.new()
	_dim.name = "_dim"
	_dim.color = Color(0.05, 0.06, 0.09, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_title = make_label("_title", TXT_TITLE, 64, Vector2(0.5, 0.28), Color(1, 1, 1))
	_sub = make_label("_sub", TXT_SUB, 26, Vector2(0.5, 0.38), Color(0.75, 0.82, 0.95))
	_hint = make_label("_hint", TXT_HINT, 18, Vector2(0.5, 0.78), Color(0.62, 0.68, 0.78))

	_start_btn = make_button("_start_btn", TXT_START, Vector2(0.5, 0.55), Vector2(220, 62), 28)
	_start_btn.pressed.connect(_on_start)
	_again_btn = make_button("_again_btn", TXT_AGAIN, Vector2(0.5, 0.66), Vector2(220, 56), 24)
	_again_btn.pressed.connect(_on_again)
	_home_btn = make_button("_home_btn", TXT_HOME, Vector2(0.5, 0.78), Vector2(220, 56), 24)
	_home_btn.pressed.connect(_on_home)

	# 인게임: 크기 레벨 진행 바. 기존 점수 라벨 바로 위에 얹는다.
	_level = make_label("_level", "", 18, Vector2.ZERO, Color(1, 0.93, 0.6))
	_level.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_level.offset_left = 14.0
	_level.offset_top = -92.0
	_level.offset_right = 260.0
	_level.offset_bottom = -68.0
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_bar = ProgressBar.new()
	_bar.name = "_bar"
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.offset_left = 14.0
	_bar.offset_top = -66.0
	_bar.offset_right = 260.0
	_bar.offset_bottom = -54.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.14, 0.2, 0.85)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.78, 0.25)
	fg.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fg)
	add_child(_bar)

	# 킬 피드: 구멍이 구멍을 먹은 것을 알린다. 화살표는 ASCII `->` 다 —
	# U+2192 는 서브셋 밖이라 동적 문구에서만 나타나 T8 의 정적 검사를 빠져나간다.
	_feed = make_label("_feed", "", 20, Vector2.ZERO, Color(1, 0.72, 0.55))
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -300.0
	_feed.offset_top = 220.0
	_feed.offset_right = -12.0
	_feed.offset_bottom = 250.0
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_pop = make_label("_pop", "", 30, Vector2.ZERO, Color(1, 0.95, 0.5))
	_pop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pop.size = Vector2(160, 40)
	_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 노드 이름은 **판정과의 계약**이다(§26). 코드로 만든 노드는 이름을 안 주면
## `@Label@7` 같은 기계 이름을 받는데, 그러면 판정기가 역할별로 찾을 수 없고
## 자식 순서에 기대게 된다 — 순서는 레이아웃을 손볼 때마다 바뀐다.
func make_label(nm: String, t: String, size: int, anchor: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.name = nm
	l.text = t
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if anchor != Vector2.ZERO:
		l.set_anchors_preset(Control.PRESET_CENTER_TOP)
		l.anchor_left = anchor.x
		l.anchor_right = anchor.x
		l.anchor_top = anchor.y
		l.anchor_bottom = anchor.y
		l.offset_left = -400.0
		l.offset_right = 400.0
		l.offset_top = 0.0
		l.offset_bottom = float(size) * 1.4
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func make_button(nm: String, t: String, anchor: Vector2, sz: Vector2, size: int) -> Button:
	var b := Button.new()
	b.name = nm
	b.text = t
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.44, 0.86) if st == "normal" \
			else (Color(0.24, 0.55, 0.95) if st == "hover" else Color(0.12, 0.34, 0.68))
		sb.set_corner_radius_all(10)
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		b.add_theme_stylebox_override(st, sb)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = -sz.x * 0.5
	b.offset_right = sz.x * 0.5
	b.offset_top = 0.0
	b.offset_bottom = sz.y
	add_child(b)
	return b


## 판정 모드용. 이 노드가 그리는 것을 전부 숨긴다.
func hide_all() -> void:
	for c in get_children():
		(c as CanvasItem).visible = false


func _on_start() -> void:
	_main.begin_round()


func _on_again() -> void:
	_main.restart()


func _on_home() -> void:
	_main.restart()
	_main.state = _main.State.HOME
	_main.set_ai(false)


func kill_feed(eater: String, prey: String) -> void:
	_feed.text = "%s -> %s" % [eater, prey]
	_feed_t = FEED_SEC


func _process(dt: float) -> void:
	if _main == null:
		return
	var st: int = _main.state
	var home: bool = st == _main.State.HOME
	var over: bool = st == _main.State.OVER
	_dim.visible = home or over
	_title.visible = home
	_sub.visible = home
	_hint.visible = home
	_start_btn.visible = home
	_again_btn.visible = over
	_home_btn.visible = over

	# 기존 HUD(레이어 1)는 이 CanvasLayer(2) 아래에 그려진다. 그대로 두면
	#   · 시작 화면 뒤로 점수·타이머·순위판이 비치고
	#   · 결과 문구가 딤에 깔려 읽히지 않는다.
	# 홈에서는 통째로 감추고, 결과에서는 **레이어를 딤 위로 올린 뒤** 인게임 지표만 끈다.
	var hr: CanvasLayer = _main.hud_root
	hr.visible = not home
	hr.layer = 3 if over else 1
	_main.hud.visible = not over
	_main.hud_timer.visible = not over
	_main.hud_board.visible = not over

	# 인게임 요소는 플레이 중에만.
	var play: bool = not home and not over
	_level.visible = play
	_bar.visible = play
	if play and _main.player_alive():
		var r: float = float(_main.hole.radius)
		var lv := 1
		for i in LEVEL_R.size():
			if r >= float(LEVEL_R[i]):
				lv = i + 1
		_level.text = "레벨 %d" % lv
		var lo: float = float(LEVEL_R[lv - 1])
		var hi: float = float(LEVEL_R[mini(lv, LEVEL_R.size() - 1)])
		_bar.value = 1.0 if lv >= LEVEL_R.size() else clampf((r - lo) / maxf(hi - lo, 1e-3), 0.0, 1.0)

	_feed_t = maxf(_feed_t - dt, 0.0)
	_feed.visible = _feed_t > 0.0 and play

	# 점수 팝업: 점수가 오른 만큼을 구멍 위에 띄운다. 신호를 따로 만들지 않고
	# 차이를 읽는다 — 삼킴은 한 프레임에 여럿 일어날 수 있고, 그때는 합쳐 보이는 편이 낫다.
	var sc: int = int(_main.score)
	if play and sc > _last_score:
		_pop.text = "+%d" % (sc - _last_score)
		_pop_t = POP_SEC
	_last_score = sc
	_pop_t = maxf(_pop_t - dt, 0.0)
	_pop.visible = _pop_t > 0.0 and play and _main.player_alive()
	if _pop.visible:
		var cam: Camera3D = _main.cam
		var p: Vector3 = _main.hole.global_position
		if not cam.is_position_behind(p):
			_pop.position = cam.unproject_position(p) - Vector2(80.0, 60.0 + (1.0 - _pop_t) * 30.0)
		_pop.modulate.a = clampf(_pop_t / POP_SEC, 0.0, 1.0)
