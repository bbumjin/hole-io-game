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
## 카메라 최저 높이. 반경에 정비례만 시키면 시작 반경 1.5 에서 높이가 6.6m 로
## 내려가 12~14m 짜리 건물이 시야를 막는다. 배율을 통째로 clamp 하므로
## 앙각(40.2°)은 그대로 유지된다 — H9·판정 전제가 반경과 무관해진다.
@export var min_height := 14.0
## §29: 성장 후퇴 감속. 반경은 삼킬 때 계단으로 뛰므로 배율을 즉시 따라가면
## 카메라가 최대 83 m/s(주행 추적 14 m/s 의 6배)로 튀어 물러난다(실측).
## 배율 _k 를 이 시정수로 지수 평활하면 피크 후퇴 속도가 주행 추적 아래로 온다
## (해석: grow_by(5.0) 에서 13.1 m/s, 판정 V2 의 상한 16 m/s).
@export var grow_smooth := 1.5

## 현재 적용 중인 오프셋 배율. main 이 _ready/restart 에서 항상 snap 을 먼저
## 부르므로 0 인 채로 비스냅 경로에 들어가는 일은 없다.
var _k := 0.0


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
