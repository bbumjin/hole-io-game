# HUD 폰트 — `hud_kr.ttf`

웹 빌드에는 시스템 폰트 폴백이 없다. 한글 HUD 를 그리려면 폰트를 **번들해야** 한다
(그래서 rev.16 에서 HUD 를 영문으로 바꿔 두었다 — §21 에서 되돌렸다).

- 원본: **Nanum Gothic Regular** (NHN Corporation, SIL Open Font License 1.1)
  - 출처: `https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic/NanumGothic-Regular.ttf`
  - 라이선스 전문: 이 폴더의 `OFL.txt`
- 번들본은 **서브셋**이다: 2,054,744 → **76,832 바이트**.

## 서브셋 문자 집합

ASCII `0x20`~`0x7E` 전부 + UI 가 쓰는 한글 음절 **42자**.
**집합의 원천은 `tools/font_subset.mjs` 하나다** — 여기 다시 적지 않는다.
§21 은 "열 줄짜리 스크립트" 라고만 적고 저장소에 넣지 않았고, 그러면 재생성이
사람의 기억에 의존한다. §26 에서 도구가 집합을 들게 했다.

**UI 문자열에 새 음절을 쓰면 그 글자는 화면에서 사라진다.** 판정 T8 이
`font.has_char()` 로 HUD 와 시작·결과 화면이 그리는 모든 문자를 검사하므로 조용히
넘어가지는 않지만, 문구를 바꿀 때는 아래로 폰트를 다시 만들어야 한다.
화살표 같은 **기호도 함께 본다** — `->` 는 ASCII 라 안전하지만 `→`(U+2192)는 서브셋
밖이고, 동적 문구에만 나타나면 정적 검사를 빠져나간다.

## 재생성

```bash
npm i --no-save subset-font            # harfbuzz(wasm) 기반, 파이썬 불필요
curl -sL -o /tmp/NanumGothic-Regular.ttf \
  https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic/NanumGothic-Regular.ttf
node tools/font_subset.mjs /tmp/NanumGothic-Regular.ttf assets/fonts/hud_kr.ttf
```

그 뒤 **임포트 캐시를 비워야 한다.** Godot 은 `.godot/imported/` 의 옛 서브셋을 계속
쓰므로, 폰트만 다시 구우면 새 글자가 여전히 없다(실측: T8 이 새 음절 16자를 전부
"글리프 없음" 으로 잡았다).

```bash
rm -f .godot/imported/hud_kr.ttf-*
godot --headless --path . --import
```

`targetFormat` 을 woff2 로 두면 Godot 이 읽기는 하지만 pck 안에서 다시 압축되므로
이득이 없다.
