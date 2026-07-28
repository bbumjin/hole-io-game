extends Node

var _mat: ShaderMaterial = null
var _holes: Array[Node3D] = []
var _buf := PackedVector4Array()


func _ready() -> void:
	_buf.resize(16)


func set_target_material(m: ShaderMaterial) -> void:
	_mat = m


func register(h: Node3D) -> void:
	if not _holes.has(h):
		_holes.append(h)


func unregister(h: Node3D) -> void:
	_holes.erase(h)


func holes() -> Array[Node3D]:
	return _holes


func hole_count() -> int:
	return mini(_holes.size(), 16)


func flush() -> void:
	if _mat == null:
		return
	# 해제된 구멍이 남아 있으면 아래 global_position 접근이 매 프레임 터진다.
	# 4단계(AI 구멍 소멸)에서 unregister 를 빠뜨려도 여기서 회수된다.
	for i in range(_holes.size() - 1, -1, -1):
		if not is_instance_valid(_holes[i]):
			_holes.remove_at(i)
	var n := hole_count()
	for i in 16:
		if i < n:
			var p: Vector3 = _holes[i].global_position
			_buf[i] = Vector4(p.x, p.y, p.z, _holes[i].radius)
		else:
			_buf[i] = Vector4(0, 0, 0, 0)
	_mat.set_shader_parameter("holes", _buf)      # 내용만 바꾸면 반영 안 됨
	_mat.set_shader_parameter("hole_count", n)
