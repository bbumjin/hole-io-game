// 브라우저(WASM+WebGL2) 안에서 기계 판정을 돌리는 하네스 (§24).
//
// 데스크톱 판정은 Godot 이 종료 코드로 결과를 낸다. 브라우저에는 종료 코드가 없어서
// screenshot.gd 의 비컨(web_beacon)이 판정 줄과 최종 결과를 이 서버로 되돌려 보낸다.
// 이 프로그램은 두 가지를 한다.
//   ① build/ 를 정적으로 서빙한다 (no-store — 다시 익스포트한 것이 반드시 실린다).
//   ② POST /judge-result 를 받아 기록하고, 기대한 판정이 전부 오면 종료 코드를 낸다.
//
// **결과가 오지 않는 것은 PASS 가 아니다.** 기다리던 판정 중 하나라도 시간 안에
// 도착하지 않으면 그 판정은 FAIL 이고 전체도 FAIL 이다 — 페이지가 아예 안 뜬 것과
// "지적사항 없음" 을 절대 같은 값으로 읽지 않는다. 하네스가 이 구분을 못 하면
// 판정 전체가 위약이 된다(판정기가 구현체를 믿으면 안 된다 — PLAN.md §10).
//
//   node tools/web_judge.mjs --expect --judge6,--judge5 [--port 8177] [--timeout 900]
//
// 서버는 열어 둔 채 기다린다. 각 판정은 아래 URL 을 브라우저로 여는 것으로 시작한다.
// 하나가 끝나기 전에 다음 URL 로 넘어가면 그 판정은 죽는다 — 순서대로 돌린다.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, sep } from 'node:path';

const ARGV = process.argv.slice(2);
const opt = (name, def) => {
	const i = ARGV.indexOf('--' + name);
	return i >= 0 && i + 1 < ARGV.length ? ARGV[i + 1] : def;
};

const DIR = normalize(opt('dir', 'build'));
const PORT = Number(opt('port', '8177'));
const TIMEOUT_S = Number(opt('timeout', '900'));
// 중복은 지운다. 같은 이름을 두 번 기다리면 두 번째 결과가 영영 오지 않아
// (한 판정은 한 번만 결과를 낸다) 정상 빌드가 시간 초과로 떨어진다.
const EXPECT = [...new Set(
	String(opt('expect', '--judge')).split(',').map((s) => s.trim()).filter(Boolean))];

// 판정 이름은 screenshot.gd 의 화이트리스트와 같은 집합이어야 한다. 여기서 한 번 더
// 거르는 것은 오타로 "영원히 오지 않는 판정" 을 기다리는 사고를 막기 위해서다.
const KNOWN = ['--judge', '--judge1b', '--judge2', '--judge3', '--judge3b',
	'--judge3c', '--judge4', '--judge5', '--judge6', '--judge7', '--judge8'];
for (const f of EXPECT) {
	if (!KNOWN.includes(f)) {
		console.error(`[web_judge] 모르는 판정 이름: ${f}`);
		process.exit(2);
	}
}

const MIME = {
	'.html': 'text/html; charset=utf-8',
	'.js': 'text/javascript; charset=utf-8',
	'.mjs': 'text/javascript; charset=utf-8',
	'.json': 'application/json; charset=utf-8',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.svg': 'image/svg+xml',
	'.ico': 'image/x-icon',
};

/** 판정 이름 -> {result, lines, ua} */
const got = new Map();
/** 이미 브라우저로 내보낸 판정. 결과 POST 가 늦게 도착해도 같은 판정을 두 번 보내지 않는다. */
const sent = new Set();

const url = (flag) => `/index.html?judge=${flag.slice('--judge'.length)}`;
const full = (flag) => `http://127.0.0.1:${PORT}${url(flag)}`;

function finish() {
	let allOk = true;
	console.log('');
	for (const flag of EXPECT) {
		const r = got.get(flag);
		const verdict = r ? r.result : 'FAIL(무응답)';
		if (verdict !== 'PASS') allOk = false;
		console.log(`WEB JUDGE ${flag} -> ${verdict}`);
	}
	console.log(`WEB JUDGE RESULT -> ${allOk ? 'PASS' : 'FAIL'}`);
	process.exit(allOk ? 0 : 1);
}

// 시간 초과는 **판정 하나마다** 잰다. 전체에 한 번만 걸면 앞의 판정이 오래 걸릴수록
// 뒤의 판정에 남는 시간이 줄어, 같은 빌드가 실행할 때마다 다른 결과를 낸다.
let timer = null;
function arm() {
	clearTimeout(timer);
	timer = setTimeout(() => {
		console.log(`\n[web_judge] ${TIMEOUT_S}초 동안 결과가 오지 않았다 — 시간 초과.`);
		finish();
	}, TIMEOUT_S * 1000);
}

function record(payload) {
	const flag = String(payload.flag ?? '');
	// 이전 실행에서 남은 탭이 늦게 결과를 던지는 일이 있다. 기대 목록 밖의 이름과
	// 이미 받은 이름은 버린다 — 안 그러면 다른 판정의 결과가 이 판정의 값이 된다.
	if (!EXPECT.includes(flag)) {
		console.log(`[web_judge] 기대 밖의 판정 결과를 버린다: ${flag}`);
		return;
	}
	if (got.has(flag)) {
		console.log(`[web_judge] 이미 받은 판정이라 버린다: ${flag}`);
		return;
	}
	const lines = Array.isArray(payload.lines) ? payload.lines : [];
	got.set(flag, { result: String(payload.result ?? ''), lines, ua: String(payload.ua ?? '') });
	console.log(`\n===== ${flag} (${lines.length}줄) =====`);
	for (const l of lines) console.log(l);
	console.log(`===== ${flag} -> ${payload.result} =====`);
	if (got.size >= EXPECT.length) {
		clearTimeout(timer);
		finish();
	} else {
		arm();
	}
}

const server = createServer(async (req, res) => {
	if (req.method === 'POST' && req.url === '/judge-result') {
		const chunks = [];
		req.on('data', (c) => chunks.push(c));
		req.on('end', () => {
			res.writeHead(204).end();
			try {
				record(JSON.parse(Buffer.concat(chunks).toString('utf8')));
			} catch (e) {
				console.log(`[web_judge] 결과 파싱 실패: ${e}`);
			}
		});
		return;
	}
	const u = new URL(req.url, 'http://x');
	// 순서는 서버가 쥔다. 판정이 끝난 페이지가 `/next?after=…` 로 돌아오면 다음
	// 판정으로 넘긴다 — 판정마다 브라우저를 손으로 여는 단계를 없앤다. 브라우저는
	// 처음 한 번만 띄우면 되고, 그 시작 URL 도 `/next` 다.
	if (u.pathname === '/next') {
		const after = u.searchParams.get('after');
		if (after) sent.add(after);
		const next = EXPECT.find((f) => !sent.has(f) && !got.has(f));
		if (next) {
			sent.add(next);
			console.log(`[web_judge] 다음 판정으로 넘어간다: ${next}`);
			res.writeHead(302, { Location: url(next), 'Cache-Control': 'no-store' }).end();
		} else {
			console.log('[web_judge] 내보낼 판정이 더 없다 — 남은 결과를 기다린다.');
			res.writeHead(200, { 'Content-Type': MIME['.html'], 'Cache-Control': 'no-store' })
				.end('<title>WEB JUDGE DONE</title><h1>WEB JUDGE DONE</h1>');
		}
		return;
	}
	const path = decodeURIComponent(u.pathname);
	const rel = normalize(path === '/' ? 'index.html' : path.slice(1));
	// build/ 밖으로 나가는 경로는 서빙하지 않는다.
	if (rel.startsWith('..') || rel.includes(sep + '..')) {
		res.writeHead(403).end();
		return;
	}
	try {
		const body = await readFile(join(DIR, rel));
		// 무엇이 받아갔는지 남긴다. 결과가 안 오는 이유가 "판정이 도는 중" 인지
		// "페이지가 아예 안 떴다" 인지는 이 줄이 없으면 구분할 수 없다.
		console.log(`[web_judge] GET ${rel} (${body.length}B)`);
		res.writeHead(200, {
			'Content-Type': MIME[extname(rel).toLowerCase()] ?? 'application/octet-stream',
			// 다시 익스포트한 빌드를 판정하는데 브라우저가 옛 wasm/pck 를 재사용하면
			// 고장 주입이 통과해 버린다. 캐시를 아예 막는다.
			'Cache-Control': 'no-store, no-cache, must-revalidate',
		});
		res.end(body);
	} catch {
		res.writeHead(404).end();
	}
});

server.listen(PORT, '127.0.0.1', () => {
	console.log(`[web_judge] ${DIR}/ 서빙 · 기다리는 판정 ${EXPECT.length}종 · 시간 초과 ${TIMEOUT_S}초`);
	for (const f of EXPECT) console.log(`[web_judge]   ${f}  ${full(f)}`);
	console.log(`[web_judge] 브라우저를 여기로 한 번만 띄운다: http://127.0.0.1:${PORT}/next`);
	arm();
});
