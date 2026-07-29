# HUD 폰트 — `hud_kr.ttf`

웹 빌드에는 시스템 폰트 폴백이 없다. 한글 HUD 를 그리려면 폰트를 **번들해야** 한다
(그래서 rev.16 에서 HUD 를 영문으로 바꿔 두었다 — §21 에서 되돌렸다).

- 원본: **Nanum Gothic Regular** (NHN Corporation, SIL Open Font License 1.1)
  - 출처: `https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic/NanumGothic-Regular.ttf`
  - 라이선스 전문: 이 폴더의 `OFL.txt`
- 번들본은 **서브셋**이다: 2,054,744 → **70,420 바이트**.

## 서브셋 문자 집합

ASCII `0x20`~`0x7E` 전부 + HUD 가 쓰는 한글 음절 26자:

```
점수크기삼킴먹힘순위이름시간종료혔다승리패배나키로작
```

**HUD 문자열에 새 음절을 쓰면 그 글자는 화면에서 사라진다.** 판정 T8 이
`font.has_char()` 로 현재 HUD 가 그리는 모든 문자를 검사하므로 조용히 넘어가지는
않지만, 문구를 바꿀 때는 아래로 폰트를 다시 만들어야 한다.

## 재생성

```bash
npm i subset-font                      # harfbuzz(wasm) 기반, 파이썬 불필요
curl -sL -o NanumGothic-Regular.ttf \
  https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic/NanumGothic-Regular.ttf
node sub.mjs NanumGothic-Regular.ttf hud_kr.ttf
```

`sub.mjs` 는 위 문자 집합을 `subsetFont(src, chars, { targetFormat: 'truetype' })`
에 넘기는 열 줄짜리 스크립트다. `targetFormat` 을 woff2 로 두면 Godot 이 읽기는
하지만 pck 안에서 다시 압축되므로 이득이 없다.
