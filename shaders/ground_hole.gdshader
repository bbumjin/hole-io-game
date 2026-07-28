shader_type spatial;
render_mode cull_back, alpha_to_coverage_and_one, depth_prepass_alpha;

uniform int hole_count = 0;
uniform vec4 holes[16];   // xyz = 월드 중심, w = 반지름

// --- 3단계 도시 격자 규격 -------------------------------------------------
// 도로·보도·노면표시는 별도 메시가 아니라 이 셰이더 안에서 그린다(§1).
// 별도 메시로 얹으면 그 머티리얼에도 구멍 SDF 를 복제해야 하고, 두께가 있으면
// 구멍 가장자리에서 단면이 드러난다. 여기서 그리면 ALPHA 하나가 전부를 뚫는다.
// screenshot.gd 는 이 uniform 을 읽지 않고 같은 수를 SPEC_* 로 따로 들고 있다.
uniform float block_pitch = 32.0;   // 도로 중심선 간격
uniform float road_half   = 4.0;    // 일반 도로 아스팔트 반폭
uniform float curb_half   = 6.0;    // 일반 도로 보도 바깥 경계 반폭
uniform float lane_half   = 0.30;   // 중앙선 반폭 (60cm — 실제 도로보다 굵다.
                                    // 게임 카메라 거리에서 판독되려면 이 정도가 필요하다:
                                    // 0.18 에서는 블록 하나 건너면 화면 2.3px 로 뭉갠다)
uniform float cross_w     = 1.6;    // 교차로 바깥 횡단보도 띠 폭
uniform float cross_pitch = 1.2;    // 횡단보도 줄무늬 주기

// --- 도로 위계 (§18) -------------------------------------------------------
// 균질한 격자는 "도로가 너무 격자" 로 읽힌다(플레이 피드백 4). boul_every 번째
// 중심선을 대로로 승격시켜 아스팔트 반폭을 **선 인덱스의 함수**로 만든다.
// 보도 폭(curb_half - road_half)은 위계와 무관하게 일정하다 — 대로만 넓어진다.
uniform float boul_every  = 3.0;    // 몇 번째 중심선마다 대로인가 (k mod 3 == 0)
uniform float boul_half   = 6.5;    // 대로 아스팔트 반폭
uniform float lane_gap    = 0.75;   // 대로 이중 중앙선의 중심 오프셋.
                                    // 선 반폭 0.30 이므로 두 줄 사이 빈 간격은 0.9 다

uniform vec3 ground_color : source_color = vec3(0.45, 0.65, 0.35);
uniform vec3 road_color   : source_color = vec3(0.36, 0.37, 0.40);
uniform vec3 curb_color   : source_color = vec3(0.72, 0.72, 0.70);
uniform vec3 lane_color   : source_color = vec3(0.88, 0.80, 0.25);
uniform vec3 cross_color  : source_color = vec3(0.90, 0.90, 0.87);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 경계를 화면 1픽셀 폭으로 부드럽게 만든다. MSAA 는 지오메트리 엣지만 덮으므로
// 절차적 색 경계는 여기서 직접 AA 하지 않으면 원거리에서 지글거린다.
// 폭을 fwidth(abs(u)) 가 아니라 fwidth(u) 로 재는 이유: abs 의 꺾임점(u=0)에서
// fwidth 가 튀어 중앙선 자리에 1픽셀 얼룩이 생긴다.
float aa_band(float u, float edge) {
	float w = max(fwidth(u), 1e-6);
	// 화면 미분이 특징 폭에 근접하면 그 특징은 서브픽셀이 되어 지글거린다.
	// aa_band 의 전이폭이 edge 를 넘어서면 띠가 화면 전체를 덮어 버리므로,
	// 그 전에 특징 자체를 걷어낸다(밉맵의 수동 구현에 해당).
	float fade = 1.0 - smoothstep(0.35 * edge, 1.0 * edge, w);
	return (1.0 - smoothstep(-w, w, abs(u) - edge)) * fade;
}

// 중심선 인덱스 k 가 대로인가 (1.0 = 대로). GLSL 의 mod 는 음수 인덱스에서도
// [0, n) 을 돌려주므로 k = -3, -6 도 0 이 되어 GDScript 의 posmod 와 **같은 집합**
// {…, -6, -3, 0, 3, 6, …} 을 만든다. 이 일치가 규격의 전제다.
float boulevard(float k) {
	return 1.0 - step(0.5, mod(k, boul_every));
}

void fragment() {
	vec2 p = world_pos.xz;
	float hp = block_pitch * 0.5;
	// 가장 가까운 도로 중심선의 **인덱스**와 그 선까지의 부호 있는 거리.
	// ux 는 남북 도로(x = kx*pitch), uz 는 동서 도로(z = kz*pitch) 기준이다.
	// ux = p.x - kx*pitch 는 옛 mod(p.x + hp, pitch) - hp 와 항등이다(음수 좌표 포함):
	//   mod(a, P) - hp = a - P*floor(a/P) - hp,  a = p.x + hp  →  p.x - P*floor((p.x+hp)/P)
	// 인덱스를 따로 꺼내는 이유는 반폭이 그 함수이기 때문이다.
	// kx 는 floor 라 블록 경계 쿼드에서 픽셀마다 달라지고 그때 fwidth(ux) 가 pitch 만큼
	// 튄다. 그 지점은 |ux| ≈ 16 이라 어떤 띠(최대 curb 8.5)에서도 멀어 무해하다 —
	// 옛 mod 식도 같은 성질이었다.
	float kx = floor((p.x + hp) / block_pitch);
	float kz = floor((p.y + hp) / block_pitch);
	float ux = p.x - kx * block_pitch;
	float uz = p.y - kz * block_pitch;

	// 위계. 보도 폭은 두 등급이 공유한다.
	float walk_w = curb_half - road_half;
	float bx = boulevard(kx);
	float bz = boulevard(kz);
	float rx = mix(road_half, boul_half, bx);
	float rz = mix(road_half, boul_half, bz);
	float cx = rx + walk_w;
	float cz = rz + walk_w;

	vec3 col = ground_color;
	col = mix(col, curb_color, max(aa_band(ux, cx), aa_band(uz, cz)));
	col = mix(col, road_color, max(aa_band(ux, rx), aa_band(uz, rz)));

	// 중앙선은 도로 중심선 위에 그리되 교차로에서는 끊는다.
	// 대로는 한 줄이 아니라 ±lane_gap 두 줄이다. abs(ux) 를 aa_band 에 넘기면 그
	// 꺾임점(= 대로 한가운데)에서 fwidth 가 튀어 1픽셀 얼룩이 생긴다 — 부호 있는
	// 인자 두 개의 max 로 푼다. aa_band 주석의 경고와 같은 이유다.
	float inter = step(abs(ux), rx) * step(abs(uz), rz);
	float lx = mix(aa_band(ux, lane_half),
		max(aa_band(ux - lane_gap, lane_half), aa_band(ux + lane_gap, lane_half)), bx);
	float lz = mix(aa_band(uz, lane_half),
		max(aa_band(uz - lane_gap, lane_half), aa_band(uz + lane_gap, lane_half)), bz);
	col = mix(col, lane_color, max(lx, lz) * (1.0 - inter));

	// 횡단보도: 교차로 바로 바깥의 도로 위 줄무늬. 중앙선 위에 덮인다.
	// 축이 섞인다 — "자기 도로 안(자기 축의 반폭)" × "교차로 밖~띠 안(교차 축의 반폭)".
	// 띠는 보도를 넘지 않는다: 대로 [6.5, 8.1] < 8.5, 일반 [4.0, 5.6] < 6.0.
	float cw_x = step(abs(ux), rx)
		* step(rz, abs(uz)) * step(abs(uz), rz + cross_w);
	float cw_z = step(abs(uz), rz)
		* step(rx, abs(ux)) * step(abs(ux), rx + cross_w);
	float cw_fade = 1.0 - smoothstep(0.15 * cross_pitch, 0.5 * cross_pitch,
		max(fwidth(p.x), fwidth(p.y)));
	float stripe = cw_x * step(fract(p.x / cross_pitch), 0.55)
		+ cw_z * step(fract(p.y / cross_pitch), 0.55);
	col = mix(col, cross_color, clamp(stripe, 0.0, 1.0) * cw_fade);

	int n = min(hole_count, 16);          // V7: 배열 범위 밖 인덱스 방지
	float d = 1e9;
	for (int i = 0; i < n; i++) {
		d = min(d, distance(p, holes[i].xz) - holes[i].w);
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	ALPHA = clamp(d / max(fwidth(d), 1e-6), 0.0, 1.0);   // 부호거리 → 1픽셀 폭 AA
}
