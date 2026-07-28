extends Camera3D

## 구멍을 고정 오프셋으로 추적한다. 거리는 반경에 비례해 늘어난다(2단계 성장 대비).
## base_radius 에서 오프셋이 정확히 base_offset 이므로 1a 의 판정 수치가 보존된다.

@export var base_offset := Vector3(0.0, 22.0, 26.0)
@export var base_radius := 5.0
@export var smooth := 6.0
## 카메라 최저 높이. 반경에 정비례만 시키면 시작 반경 1.5 에서 높이가 6.6m 로
## 내려가 12~14m 짜리 건물이 시야를 막는다. 배율을 통째로 clamp 하므로
## 앙각(40.2°)은 그대로 유지된다 — H9·판정 전제가 반경과 무관해진다.
@export var min_height := 14.0


func follow(target: Node3D, radius: float, snap: bool, dt := 0.0) -> void:
	var k: float = maxf(radius / base_radius, min_height / base_offset.y)
	var want := target.global_position + base_offset * k
	if snap:
		global_position = want
	else:
		global_position = global_position.lerp(want, clampf(smooth * dt, 0.0, 1.0))
	look_at(target.global_position)
