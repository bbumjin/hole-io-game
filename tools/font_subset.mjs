// HUD 폰트 서브셋 생성기 (§21 · §26).
//
// 웹 빌드에는 시스템 폰트 폴백이 없다. 번들한 글리프에 없는 문자는 **에러 없이
// 화면에서 사라진다.** 그래서 UI 문구를 바꿀 때마다 여기의 집합을 고치고 다시 굽는다.
//
// §21 은 이 스크립트를 "열 줄짜리" 라고만 적고 저장소에 넣지 않았다. 그러면 재생성이
// 사람의 기억에 의존하고, 다음 사람이 같은 집합으로 굽는다는 보장이 없다 —
// 이 프로젝트가 반복해서 배운 것과 같은 실패다. 이제 도구가 집합을 들고 있다.
//
//   npm i subset-font
//   curl -sL -o /tmp/NanumGothic-Regular.ttf \
//     https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic/NanumGothic-Regular.ttf
//   node tools/font_subset.mjs /tmp/NanumGothic-Regular.ttf assets/fonts/hud_kr.ttf
//
// **판정기는 이 파일을 읽지 않는다.** `screenshot.gd` 의 SPEC_HUD_CHARS 가 같은 집합을
// 따로 들고 있고, 어긋나면 T8 이 글리프 없음으로 탈락시킨다.

import { readFile, writeFile } from 'node:fs/promises';
import subsetFont from 'subset-font';

/** ASCII 0x20~0x7E 전부. 숫자·기호·영문 이름(AI1 …)·화살표 대용 `->` 가 여기 있다. */
const ASCII = Array.from({ length: 0x7e - 0x20 + 1 }, (_, i) => String.fromCharCode(0x20 + i)).join('');

/**
 * UI 가 쓰는 한글 음절 전부. **문구를 바꾸면 여기부터 고친다.**
 *   앞 26자 — §21 의 인게임 HUD (점수·크기·삼킴·순위판·게임오버)
 *   뒤 16자 — §26 이 더한 시작 화면·결과 화면·조작 안내·레벨 표시
 */
const SYLLABLES = '점수크기삼킴먹힘순위이름시간종료혔다승리패배나키로작'
	+ '도를켜라동화살표드래그레벨하홈으';

const [src, dst] = process.argv.slice(2);
if (!src || !dst) {
	console.error('사용법: node tools/font_subset.mjs <원본.ttf> <출력.ttf>');
	process.exit(2);
}

const chars = ASCII + SYLLABLES;
const out = await subsetFont(await readFile(src), chars, { targetFormat: 'truetype' });
await writeFile(dst, out);
console.log(`[font_subset] 음절 ${SYLLABLES.length}자 + ASCII ${ASCII.length}자 -> ${dst} (${out.length} 바이트)`);
