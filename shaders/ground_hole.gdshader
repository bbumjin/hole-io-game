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

uniform vec3 road_color   : source_color = vec3(0.36, 0.37, 0.40);
uniform vec3 curb_color   : source_color = vec3(0.72, 0.72, 0.70);
uniform vec3 lane_color   : source_color = vec3(0.88, 0.80, 0.25);
uniform vec3 cross_color  : source_color = vec3(0.90, 0.90, 0.87);

// --- 지구제·수계 (§25) -----------------------------------------------------
// 존 지도는 city.gd 가 구운 14x14 RG8 텍스처 하나가 원천이다(R=존, G=병합 그룹 §33). 셀당 zone_code*51 이
// 들어 있고 51/255 = 0.2 간격이라 복호가 8비트 양자화·필터 오차에 견고하다.
// **판정기는 이 텍스처를 읽지 않는다** — 자기 사본을 들고 같은 지도를 독립으로 계산한다.
uniform sampler2D zone_tex : filter_nearest, repeat_disable;
uniform float ground_half = 224.0;

// 존별 지면색. 휘도는 전부 [아스팔트 0.37 + 여유, 커브 0.72 - 여유] 안에 둔다 —
// 벗어나면 D1(인접 표면 휘도차)·D4(우물보다 밝다)가 무너진다. 아래 값은 렌더 후에도
// 어느 채널도 1.0 에 붙지 않도록 낮춰 잡았다(클리핑되면 채널 차가 뭉개져 Z1 이 흐려진다).
uniform vec3 zone_d_color : source_color = vec3(0.46, 0.44, 0.42);   // 도심: 무채색 콘크리트
uniform vec3 zone_c_color : source_color = vec3(0.47, 0.53, 0.38);   // 상업: 약한 녹조
uniform vec3 zone_r_color : source_color = vec3(0.39, 0.58, 0.31);   // 주거: 잔디
uniform vec3 zone_p_color : source_color = vec3(0.26, 0.55, 0.19);   // 공원: 짙은 녹지
uniform vec3 water_color  : source_color = vec3(0.13, 0.28, 0.47);   // 강
uniform vec3 ocean_color  : source_color = vec3(0.08, 0.19, 0.36);   // 지도 테두리 바다
uniform vec3 bank_color   : source_color = vec3(0.62, 0.58, 0.42);   // 기슭
uniform float bank_w = 2.4;
// §31 수변 산책로: 물과 접한 육지 셀 가장자리의 포장 띠. 기슭 띠(물 쪽)와 대칭이다.
uniform vec3 prom_color   : source_color = vec3(0.44, 0.43, 0.39);
uniform float prom_w = 2.0;

// 존 지도의 규격 상수. city.gd 의 CELL_MIN·CELL_COUNT·ZONE_TEX_STEP 과 같은 값이다.
const int ZMIN = -7;
const int ZN = 14;
const float ZSTEP = 51.0;
const int Z_D = 0;
const int Z_C = 1;
const int Z_R = 2;
const int Z_P = 3;
const int Z_W = 4;

int zone_at(int k, int j) {
	ivec2 t = ivec2(clamp(k - ZMIN, 0, ZN - 1), clamp(j - ZMIN, 0, ZN - 1));
	return int(texelFetch(zone_tex, t, 0).r * 255.0 / ZSTEP + 0.5);
}

// §33 병합 그룹 id (0 = 비병합). city.gd 의 zone_texture 가 G 채널에 굽는다.
int group_at(int k, int j) {
	ivec2 t = ivec2(clamp(k - ZMIN, 0, ZN - 1), clamp(j - ZMIN, 0, ZN - 1));
	return int(texelFetch(zone_tex, t, 0).g * 255.0 + 0.5);
}

// 교량. city.gd 의 BRIDGES 와 **같은 집합**이어야 한다 — 여기만 고치면 도로는 그려지는데
// 구멍이 못 지나가고, 저기만 고치면 그 반대가 된다. 강이 열 k=2 라 셀 인덱스는 2 다.
bool is_bridge_ew(int jl, int kc) {
	return kc == 2 && (jl == -3 || jl == 0 || jl == 3);
}

// 도로 세그먼트가 존재하는가. city.gd 의 seg_rule 과 같은 규칙이다.
float seg_rule(int a, int b, bool bridge) {
	if (a == Z_W || b == Z_W) { return bridge ? 1.0 : 0.0; }
	return (a == Z_P && b == Z_P) ? 0.0 : 1.0;
}
// §32 수변 끝 조항: 끝 너머 두 셀이 모두 물이고 그 너머가 교량이 아니면 걷는다.
// city.gd 의 seg_ew/seg_ns 와 같은 조항이다 — 한쪽만 고치면 그리는 도로와
// 걷는 도로가 어긋난다.
float seg_ew(int jl, int kc) {
	if (seg_rule(zone_at(kc, jl - 1), zone_at(kc, jl), is_bridge_ew(jl, kc)) < 0.5) { return 0.0; }
	// §33: 같은 병합 그룹 안의 내부 도로는 없다.
	int g = group_at(kc, jl - 1);
	if (g != 0 && g == group_at(kc, jl)) { return 0.0; }
	if (zone_at(kc + 1, jl - 1) == Z_W && zone_at(kc + 1, jl) == Z_W && !is_bridge_ew(jl, kc + 1)) { return 0.0; }
	if (zone_at(kc - 1, jl - 1) == Z_W && zone_at(kc - 1, jl) == Z_W && !is_bridge_ew(jl, kc - 1)) { return 0.0; }
	return 1.0;
}
float seg_ns(int kl, int jc) {
	if (seg_rule(zone_at(kl - 1, jc), zone_at(kl, jc), false) < 0.5) { return 0.0; }
	int g = group_at(kl - 1, jc);
	if (g != 0 && g == group_at(kl, jc)) { return 0.0; }
	if (zone_at(kl - 1, jc + 1) == Z_W && zone_at(kl, jc + 1) == Z_W) { return 0.0; }
	if (zone_at(kl - 1, jc - 1) == Z_W && zone_at(kl, jc - 1) == Z_W) { return 0.0; }
	return 1.0;
}

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

	// --- 지구 지면색과 수계 (§25) -----------------------------------------
	// 프래그먼트를 **품는 셀**(중심선이 아니라 칸)의 존이 지면색을 정한다.
	int kc = int(floor(p.x / block_pitch));
	int jc = int(floor(p.y / block_pitch));
	int zc = zone_at(kc, jc);

	vec3 base;
	if (zc == Z_W) {
		// 기슭 띠는 **물 쪽에만** 그린다. 그러면 육지 픽셀(지도의 대부분)은
		// 이 네 번의 texelFetch 를 아예 건너뛴다.
		float ex = p.x - float(kc) * block_pitch;
		float ez = p.y - float(jc) * block_pitch;
		float bank = 0.0;
		if (zone_at(kc - 1, jc) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, ex)); }
		if (zone_at(kc + 1, jc) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, block_pitch - ex)); }
		if (zone_at(kc, jc - 1) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, ez)); }
		if (zone_at(kc, jc + 1) != Z_W) { bank = max(bank, 1.0 - smoothstep(0.0, bank_w, block_pitch - ez)); }
		// 지도 가장자리로 갈수록 깊어진다 — 강과 바다를 한 장의 지도로 잇는다.
		float deep = smoothstep(0.72, 1.0, max(abs(p.x), abs(p.y)) / ground_half);
		base = mix(mix(water_color, ocean_color, deep), bank_color, bank);
	} else if (zc == Z_D) {
		base = zone_d_color;
	} else if (zc == Z_C) {
		base = zone_c_color;
	} else if (zc == Z_R) {
		base = zone_r_color;
	} else {
		base = zone_p_color;
	}

	// --- §31 수변 산책로 (육지 쪽) --------------------------------------------
	// 도로보다 **먼저** 섞는다 — 뒤의 도로·보도 띠가 이 위에 덮여 "도로 > 산책로 >
	// 존색" 우선순위가 된다(교량 접근부의 아스팔트에 가로 띠가 생기면 안 된다).
	// 셀 가장자리에서 prom_w 이내인 픽셀만 이웃을 읽는다. 물가만이 아니라 **모든**
	// 내부 셀 경계 근처(육지 픽셀의 ~2할)에서 fetch 가 도는 것은 맞다 — §25 의
	// 완전 회피에는 못 미치는 완화이고, 예산 준수는 3c 가 최종 판정한다(실측 PASS).
	if (zc != Z_W) {
		float px = p.x - float(kc) * block_pitch;
		float pz = p.y - float(jc) * block_pitch;
		float m = min(min(px, block_pitch - px), min(pz, block_pitch - pz));
		if (m < prom_w) {
			float prom = 0.0;
			if (zone_at(kc - 1, jc) == Z_W) { prom = max(prom, 1.0 - smoothstep(prom_w - 0.3, prom_w, px)); }
			if (zone_at(kc + 1, jc) == Z_W) { prom = max(prom, 1.0 - smoothstep(prom_w - 0.3, prom_w, block_pitch - px)); }
			if (zone_at(kc, jc - 1) == Z_W) { prom = max(prom, 1.0 - smoothstep(prom_w - 0.3, prom_w, pz)); }
			if (zone_at(kc, jc + 1) == Z_W) { prom = max(prom, 1.0 - smoothstep(prom_w - 0.3, prom_w, block_pitch - pz)); }
			base = mix(base, prom_color, prom);
		}
	}

	// 도로 마스크. 남북 도로는 자기가 걸친 z-셀로, 동서 도로는 x-셀로 존재를 묻는다.
	// 마스크가 0 인 자리에서는 아스팔트·보도·중앙선·횡단보도가 전부 사라지고
	// 그 자리의 존 지면색이 그대로 드러난다.
	float ens = seg_ns(int(kx), jc);
	float enw = seg_ew(int(kz), kc);

	vec3 col = base;
	col = mix(col, curb_color, max(aa_band(ux, cx) * ens, aa_band(uz, cz) * enw));
	col = mix(col, road_color, max(aa_band(ux, rx) * ens, aa_band(uz, rz) * enw));

	// 중앙선은 도로 중심선 위에 그리되 교차로에서는 끊는다.
	// 대로는 한 줄이 아니라 ±lane_gap 두 줄이다. abs(ux) 를 aa_band 에 넘기면 그
	// 꺾임점(= 대로 한가운데)에서 fwidth 가 튀어 1픽셀 얼룩이 생긴다 — 부호 있는
	// 인자 두 개의 max 로 푼다. aa_band 주석의 경고와 같은 이유다.
	// 한쪽 도로가 없으면 교차로도 없다(inter=0) — 남은 도로의 중앙선이 이어져야 한다.
	float inter = step(abs(ux), rx) * step(abs(uz), rz) * ens * enw;
	float lx = mix(aa_band(ux, lane_half),
		max(aa_band(ux - lane_gap, lane_half), aa_band(ux + lane_gap, lane_half)), bx) * ens;
	float lz = mix(aa_band(uz, lane_half),
		max(aa_band(uz - lane_gap, lane_half), aa_band(uz + lane_gap, lane_half)), bz) * enw;
	col = mix(col, lane_color, max(lx, lz) * (1.0 - inter));

	// 횡단보도: 교차로 바로 바깥의 도로 위 줄무늬. 중앙선 위에 덮인다.
	// 축이 섞인다 — "자기 도로 안(자기 축의 반폭)" × "교차로 밖~띠 안(교차 축의 반폭)".
	// 띠는 보도를 넘지 않는다: 대로 [6.5, 8.1] < 8.5, 일반 [4.0, 5.6] < 6.0.
	// 건널 상대가 없으면(교차 도로가 걷혔으면) 횡단보도도 그리지 않는다 — ens*enw.
	float cw_x = step(abs(ux), rx)
		* step(rz, abs(uz)) * step(abs(uz), rz + cross_w) * ens * enw;
	float cw_z = step(abs(uz), rz)
		* step(rx, abs(ux)) * step(abs(ux), rx + cross_w) * ens * enw;
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
