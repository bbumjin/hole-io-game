extends Camera3D

## 구멍을 고정 오프셋으로 추적한다. 거리는 반경에 비례해 늘어난다(2단계 성장 대비).
## base_radius 에서 오프셋이 정확히 base_offset 이므로 1a 의 판정 수치가 보존된다.
##
## §29: **회전은 상수다.** 매 프레임 look_at(target) 을 하면 위치 lerp 의 지연과
## 결합해 방향 전환마다 시야 전체가 기울었다 돌아온다 — 실측 최대 86°/s 로,
## 휴대폰 멀미 피드백의 주 기제였다. 카메라가 목표 지점(want)에 정확히 있을 때의
## look_at 과 같은 회전이므로(want - target = base_offset·k, 방향은 k 와 무관)
## 판정 모드(snap)의 스크린샷 프레이밍은 변하지 않는다.

@export var base_offset := Vector3(0.0, 22.0, 26.0)
@export var base_radius := 5.0
@export var smooth := 6.0
## 카메라 최저 높이. **§37 이전에는** 반경에 정비례만 시키면 시작 반경 1.5 에서
## 높이가 6.6m 로 내려가 12~14m 짜리 건물이 시야를 막았고, 그래서 14.0 으로 올려
## 막았다 — 그런데 유저 피드백은 반대였다: "hole.io 처럼 시작은 훨씬 좁은 시야로
## zoom in 되어야 한다." §37 가림 투명화(occluders.gd)가 이제 큰 건물이 실제로
## 카메라를 가리는 모든 경우를 잡아 주므로(카메라 높이와 무관하게 스케일 불변으로
## 작동한다 — occluders.gd 상단 주석), 높이로 건물을 피하는 이 안전장치는 더는
## 필요 없다 — **그렇다고 반경 1.5 의 자연값(0.3 배율 → 6.6m)까지는 못 낮춘다.**
## 이 값과 무관한 두 가지 다른 바닥이 있다:
##  ① 지면이 448×448 유한 평면이라, 앙각(40.236°)·FOV(75°) 가 고정인 채로 카메라가
##     너무 낮아지면 화면 맨 위 시선조차 지면 가장자리(반폭 224)를 못 넘어서고, 배경
##     (하늘)이 화면에서 아예 사라진다 — 실측 10.0 에서 처음 발생(judge1 "bg FAIL").
##  ② `probe_blocks()`(screenshot.gd)의 블록 탐색이 화면 프레이밍에 기대는데, 카메라가
##     그 이하로 가까워지면 후보 블록이 화면 밖/서브픽셀로 밀려 D1 지면 판정 전체가
##     후보를 못 찾는다 — 같은 실측 경계.
## 두 바닥 모두 10.1 에서 통과하기 시작하지만 여유가 0에 가까워 그 값을 그대로 쓰지
## 않는다 — 11.0 로 안전 여유를 두고 낮췄다(14.0 대비 21% 더 zoom in). 판정으로
## 확인한 값이지 추측이 아니다: 10.0 이하 전부 재현 가능하게 실패한다.
@export var min_height := 11.0
## §29: 성장 후퇴 감속. 반경은 삼킬 때 계단으로 뛰므로 배율을 즉시 따라가면
## 카메라가 최대 83 m/s(주행 추적 14 m/s 의 6배)로 튀어 물러난다(실측).
## 배율 _k 를 이 시정수로 지수 평활하면 피크 후퇴 속도가 주행 추적 아래로 온다
## (해석: grow_by(5.0) 에서 13.1 m/s, 판정 V2 의 상한 16 m/s).
@export var grow_smooth := 1.5

## 현재 적용 중인 오프셋 배율. main 이 _ready/restart 에서 항상 snap 을 먼저
## 부르므로 0 인 채로 비스냅 경로에 들어가는 일은 없다.
var _k := 0.0

## §37: 카메라를 가리는 프롭을 비운다. main 이 `_ready` 에서 도시를 물린다.
const OCCLUDERS := preload("res://scripts/occluders.gd")
var occluders := OCCLUDERS.new()


func follow(target: Node3D, radius: float, snap: bool, dt := 0.0) -> void:
	var k_target: float = maxf(radius / base_radius, min_height / base_offset.y)
	if snap:
		_k = k_target
		global_position = target.global_position + base_offset * _k
	else:
		# 평활 계수는 1-exp(-rate·dt) — clampf(rate·dt) 는 프레임률에 따라
		# 수렴 곡선 자체가 달라진다(§29 판정 V4 가 두 dt 로 단언한다).
		_k = k_target + (_k - k_target) * exp(-grow_smooth * dt)
		var want := target.global_position + base_offset * _k
		global_position = global_position.lerp(want, 1.0 - exp(-smooth * dt))
	global_basis = Basis.looking_at(-base_offset)
	# §37: **여기가 유일한 호출 자리다.** main 3곳과 판정 13곳이 전부 `follow` 로 오므로
	# 여기 걸면 판정 스크린샷에도 자동으로 반영된다 — 판정 모드에서는 `main._process` 가
	# 일찍 반환해 `follow` 말고는 도는 것이 없다. `judge_flag()` 와 같은 원칙이다.
	# **실제 카메라 위치(`self`)를 넘긴다** — 이상 오프셋을 쓰면 횡이동 중 정상상태 지연
	# 2.33m(= v/smooth = 14/6) 만큼 원뿔이 어긋나 가림을 놓친다.
	occluders.update(self, target.global_position, radius, snap, dt)
