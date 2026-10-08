extends Camera3D

## 구멍을 고정 오프셋으로 추적한다. 시작은 가까이 잡고, 반경이 커질수록 거리를 늘린다.
## base_radius 에서 오프셋이 정확히 base_offset 이다.
##
## §29: **회전은 상수다.** 매 프레임 look_at(target) 을 하면 위치 lerp 의 지연과
## 결합해 방향 전환마다 시야 전체가 기울었다 돌아온다 — 실측 최대 86°/s 로,
## 휴대폰 멀미 피드백의 주 기제였다. 카메라가 목표 지점(want)에 정확히 있을 때의
## look_at 과 같은 회전이므로(want - target = base_offset·k, 방향은 k 와 무관)
## 판정 모드(snap)의 스크린샷 프레이밍은 변하지 않는다.

@export var base_offset := Vector3(0.0, 22.0, 26.0)
@export var base_radius := 5.0
@export var smooth := 6.0
## 시작 프레이밍. R=1.5 의 배율 0.5 는 카메라 높이 11.0 이다. 실측상 10.0 이하는
## 유한 지면의 하늘이 사라지고 블록 판정 후보도 놓치므로, 원격 변경이 확정한 안전
## 하한을 그대로 지킨다. 예전 min_height clamp 처럼 작은 구멍 구간을 고정하지 않고
## base_radius 의 1.0 배율까지 선형으로 이어 첫 성장부터 조금씩 줌아웃되게 한다.
@export var start_radius := 1.5
@export var start_scale := 0.5
## §29: 성장 후퇴 감속. 반경은 삼킬 때 계단으로 뛰므로 배율을 즉시 따라가면
## 카메라가 최대 83 m/s(주행 추적 14 m/s 의 6배)로 튀어 물러난다(실측).
## 배율 _k 를 이 시정수로 지수 평활하면 피크 후퇴 속도가 주행 추적 아래로 온다
## (판정 V2 는 큰 성장 이벤트에서도 후퇴 속도 16 m/s 이하를 요구한다.)
@export var grow_smooth := 1.3

## 현재 적용 중인 오프셋 배율. main 이 _ready/restart 에서 항상 snap 을 먼저
## 부르므로 0 인 채로 비스냅 경로에 들어가는 일은 없다.
var _k := 0.0

## §37: 카메라를 가리는 프롭을 비운다. main 이 `_ready` 에서 도시를 물린다.
const OCCLUDERS := preload("res://scripts/occluders.gd")
var occluders := OCCLUDERS.new()

## §39: 그림자 거리를 줌에 맞춘다. 방향광 그림자는 **카메라에서** 최대 거리(기본 100m)까지만
## 그려지는데, 카메라-구멍 거리는 `|base_offset|·k` = 34.06·k 라 k ≥ 3(R ≥ 15)부터 **구멍
## 주변의 그림자가 통째로 사라졌다**(감사가 잡은 기존 결함). 구멍 너머 여유를 더해 키우되
## 기본값 아래로는 내리지 않는다 — 작은 줌의 화면과 비용은 그대로다.
## 거리를 키우면 그림자 패스가 그리는 것이 늘어 드로우콜이 k=4 에서 +72% 였다(실측, 여유 60m·
## 4분할). 멀어진 화면은 그림자 텍셀이 덜 필요하므로 **기본값을 넘는 동안은 2분할**로 내리고
## 여유도 30m 로 줄인다.
## main 이 `_ready` 에서 Sun 을 물린다. 없으면 아무것도 안 한다(판정 픽스처 씬 등).
const SHADOW_MIN := 100.0
const SHADOW_PAD := 30.0
var sun: DirectionalLight3D = null


func shadow_distance(k: float) -> float:
	return maxf(SHADOW_MIN, base_offset.length() * k + SHADOW_PAD)


func zoom_scale(radius: float) -> float:
	if radius <= start_radius:
		return start_scale
	if radius >= base_radius:
		return radius / base_radius
	var t := (radius - start_radius) / (base_radius - start_radius)
	return lerpf(start_scale, 1.0, t)


func follow(target: Node3D, radius: float, snap: bool, dt := 0.0) -> void:
	var k_target := zoom_scale(radius)
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
	if sun != null:
		# 바뀔 때만 쓴다 — 세터가 매번 빛의 종속자에 알리고 모드 세터는 속성 목록 갱신까지 낸다.
		var sd := snappedf(shadow_distance(_k), 0.5)
		if sun.directional_shadow_max_distance != sd:
			sun.directional_shadow_max_distance = sd
		var mode := DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS \
			if sd <= SHADOW_MIN else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		if sun.directional_shadow_mode != mode:
			sun.directional_shadow_mode = mode
	# §37: **여기가 유일한 호출 자리다.** main 3곳과 판정 13곳이 전부 `follow` 로 오므로
	# 여기 걸면 판정 스크린샷에도 자동으로 반영된다 — 판정 모드에서는 `main._process` 가
	# 일찍 반환해 `follow` 말고는 도는 것이 없다. `judge_flag()` 와 같은 원칙이다.
	# **실제 카메라 위치(`self`)를 넘긴다** — 이상 오프셋을 쓰면 횡이동 중 정상상태 지연
	# 2.33m(= v/smooth = 14/6) 만큼 원뿔이 어긋나 가림을 놓친다.
	occluders.update(self, target.global_position, radius, snap, dt)
