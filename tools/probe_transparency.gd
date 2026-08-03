extends SceneTree

## §37 사전 조사 — **두 렌더러에서 무엇이 실제로 반투명해지는가**를 픽셀로 재는 탐침.
##
##   godot --path . --script res://tools/probe_transparency.gd
##   godot --path . --rendering-driver opengl3 --script res://tools/probe_transparency.gd
##
## **`--headless` 로 돌리면 안 된다** — 렌더 결과를 읽는다.
##
## 왜 필요한가: 웹 배포본은 `gl_compatibility` 다(§22). `GeometryInstance3D.transparency`
## 는 Forward+/Mobile 전용이라는 말이 있는데, 그 말이 이 버전에서도 맞는지 **문서가 아니라
## 엔진에서** 확인해야 한다. 틀리면 데스크톱만 초록인 채 웹에서 건물이 안 사라진다 —
## 이 저장소가 가장 경계하는 종류의 결함이다(§22·§24 가 그래서 생겼다).
##
## 빨간 상자를 마젠타 배경 앞에 두고 세 방식으로 반투명을 시도한 뒤 중앙 픽셀을 읽는다.
## 완전 불투명이면 순수 빨강, 반투명이면 배경이 섞여 파랑 성분이 올라온다.

const PX := 64
const BG := Color(1.0, 0.0, 1.0)      # 마젠타 — 상자 색(빨강)에 없는 파랑 성분이 섞임의 증거
const ALBEDO := Color(1.0, 0.0, 0.0)


func _init() -> void:
	var driver := "gl_compatibility" if str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method")) == "gl_compatibility" else "?"
	print("--- 반투명 탐침 (렌더러=%s) ---" % RenderingServer.get_video_adapter_api_version())
	print("  rendering_method(project)=%s" % driver)
	for mode in ["기준(불투명)", "GeometryInstance3D.transparency=0.6",
			"material_override 알파=0.4", "surface_override 알파=0.4",
			"ShaderMaterial + 전역 uniform discard"]:
		var c := await shot(mode)
		# 파랑 성분이 곧 배경이 비친 양이다.
		print("  %-38s rgb=(%.3f, %.3f, %.3f)  배경혼합=%.3f  %s"
			% [mode, c.r, c.g, c.b, c.b,
			   ("반투명 O" if c.b > 0.05 else "불투명")])
	quit(0)


## 대안 (d) 평가용. 건물 셰이더가 **전역 uniform**(구멍 위치·반경)을 읽어 프래그먼트를
## discard 하려면 `global uniform` 이 Compatibility 에서도 도달해야 한다. 계획 감사가
## "확인 못 함" 으로 남긴 자리다 — 기각하든 채택하든 **재고 나서** 정해야 한다.
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded;
global uniform float probe_cut;
void fragment() {
	if (probe_cut > 0.5) { discard; }
	ALBEDO = vec3(1.0, 0.0, 0.0);
}
"""


func shot(mode: String) -> Color:
	var vp := SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.position = Vector3(0, 0, 4)
	vp.add_child(cam)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2, 2, 0.2)
	mi.mesh = bm
	var base := StandardMaterial3D.new()
	base.albedo_color = ALBEDO
	base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = base
	vp.add_child(mi)

	match mode:
		"GeometryInstance3D.transparency=0.6":
			mi.transparency = 0.6
		"material_override 알파=0.4":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(ALBEDO.r, ALBEDO.g, ALBEDO.b, 0.4)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = m
		"surface_override 알파=0.4":
			var m2 := StandardMaterial3D.new()
			m2.albedo_color = Color(ALBEDO.r, ALBEDO.g, ALBEDO.b, 0.4)
			m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.set_surface_override_material(0, m2)
		"ShaderMaterial + 전역 uniform discard":
			if not ProjectSettings.has_setting("shader_globals/probe_cut"):
				ProjectSettings.set_setting("shader_globals/probe_cut",
					{ "type": "float", "value": 0.0 })
			RenderingServer.global_shader_parameter_set("probe_cut", 1.0)
			var sh := Shader.new()
			sh.code = GHOST_SHADER
			var sm := ShaderMaterial.new()
			sm.shader = sh
			mi.set_surface_override_material(0, sm)

	root.add_child(vp)
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	var c := img.get_pixel(PX / 2, PX / 2)
	vp.queue_free()
	return c
