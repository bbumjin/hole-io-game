extends SceneTree

## §39 P0-2: 다중 서피스 OBJ 를 **단일 서피스 + 버텍스 컬러** 메시로 굽는다.
##
##   godot --headless --path . --script res://tools/bake_meshes.gd
##
## 왜: Compatibility(웹) 렌더러는 3D 를 자동 배칭하지 않아 **드로우콜 = 서피스 × 인스턴스 ×
## 패스**다. 차는 서피스가 11~14개, 건물은 5~7개라 그림자 패스까지 곱해 프레임당 7600 콜이
## 났다. 런타임 시험 굽기에서 서피스를 합치자 모든 줌에서 −67~69% 였다(§39 실측).
##
## **외형이 바뀌지 않는 근거.** 임포트된 머티리얼은 전부 roughness 1 · metallic 0.5 ·
## specular 0.5 · 불투명 · 텍스처 없음이고 **albedo 만 다르다**(전수 확인 — 아래 `same_params`
## 가 다르면 굽지 않고 실패한다). 그 albedo 를 정점 색으로 옮기면 같은 셰이딩이다.
## albedo 는 sRGB 값이므로 `vertex_color_is_srgb = true` 로 같은 변환을 탄다.
##
## **LOD 를 다시 만든다.** 원본 임포트는 `generate_lods=true` 라 서피스마다 LOD 를 들고 있다.
## 그냥 합치면 LOD 가 사라져 프리미티브가 1.8M → 2.3M 으로 늘었다(시험 굽기 실측).
## ImporterMesh 로 합친 뒤 임포터와 같은 `generate_lods` 를 돈다. (임포터의 그림자 메시 생성은
## 스크립트에 노출돼 있지 않다 — 단일 서피스라 그림자 패스도 이미 콜 하나다.)
##
## 산출물은 `res://assets/baked/<팩>_<이름>.res` 다(Taxi·House2 는 팩마다 같은 이름이 있다).
## **저장소에 넣지 않는다** — 원본에서 언제든 재생성되고(.godot/ 와 같은 성격), Vercel 빌드가
## export 전에 이 도구를 돌리고 개수를 하드 게이트로 본다(scripts/vercel-build.sh).

const CITY := preload("res://scripts/city.gd")
const OUT_DIR := "res://assets/baked/"


static func baked_path(src: String) -> String:
	return OUT_DIR + src.get_base_dir().get_file() + "_" + src.get_file().get_basename() + ".res"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var paths := {}
	for e in CITY.CATALOG:
		paths[String(e["path"])] = true
	var made := 0
	var skipped := 0
	var bad := 0
	for p in paths:
		var m := load(p) as ArrayMesh
		if m == null:
			push_error("bake: 로드 실패 %s" % p)
			bad += 1
			continue
		if m.get_surface_count() <= 1:
			skipped += 1
			continue
		var out := bake(m, p)
		if out == null:
			bad += 1
			continue
		var err := ResourceSaver.save(out, baked_path(p), ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("bake: 저장 실패 %s (%d)" % [p, err])
			bad += 1
			continue
		made += 1
		print("BAKE %-48s %2d surf -> 1  verts %d" % [p, m.get_surface_count(),
			(out.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])
	print("BAKE RESULT made=%d single=%d bad=%d" % [made, skipped, bad])
	quit(1 if bad > 0 else 0)


## 셰이딩에 영향을 주는 albedo 외 파라미터가 같은가. 다르면 정점 색으로 못 합친다.
static func same_params(a: StandardMaterial3D, b: StandardMaterial3D) -> bool:
	return a.roughness == b.roughness and a.metallic == b.metallic \
		and a.metallic_specular == b.metallic_specular and a.transparency == b.transparency \
		and a.shading_mode == b.shading_mode and a.cull_mode == b.cull_mode \
		and a.albedo_texture == null and b.albedo_texture == null \
		and a.emission_enabled == b.emission_enabled and a.albedo_color.a == b.albedo_color.a


func bake(m: ArrayMesh, p: String) -> ArrayMesh:
	var m0 := m.surface_get_material(0) as StandardMaterial3D
	if m0 == null:
		push_error("bake: StandardMaterial3D 아님 %s" % p)
		return null
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for si in m.get_surface_count():
		var mat := m.surface_get_material(si) as StandardMaterial3D
		if mat == null or not same_params(m0, mat):
			push_error("bake: %s surf%d 의 머티리얼이 albedo 외에도 다르다 — 정점 색으로 못 합친다" % [p, si])
			return null
		var arr := m.surface_get_arrays(si)
		var base := v.size()
		var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		v.append_array(sv)
		nrm.append_array(arr[Mesh.ARRAY_NORMAL])
		var c := mat.albedo_color
		var cs := PackedColorArray()
		cs.resize(sv.size())
		cs.fill(c)
		col.append_array(cs)
		var si_idx = arr[Mesh.ARRAY_INDEX]
		if si_idx == null or (si_idx as PackedInt32Array).is_empty():
			for i in sv.size():
				idx.append(base + i)
		else:
			for i in (si_idx as PackedInt32Array):
				idx.append(base + i)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nrm
	a[Mesh.ARRAY_COLOR] = col
	a[Mesh.ARRAY_INDEX] = idx
	var mat_out: StandardMaterial3D = m0.duplicate()
	mat_out.albedo_color = Color(1, 1, 1, m0.albedo_color.a)
	mat_out.vertex_color_use_as_albedo = true
	mat_out.vertex_color_is_srgb = true
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, mat_out, "baked")
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()
