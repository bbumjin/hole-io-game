#!/usr/bin/env bash
# Vercel 빌드에서 Godot Web export 를 수행한다 — git push 하면 이 스크립트가 돌아 프로덕션이 갱신된다.
#
# 왜 이런 모양인가:
#   Vercel 빌드 이미지에는 Godot 이 없다. 그래서 빌드마다 에디터 + Web export template 을 내려받는다.
#   export template 번들(.tpz)은 1.22GB 인데 실제로 필요한 건 web_* 멤버 몇 개(~84MB)뿐이다.
#   전체를 내려받으면 매 배포마다 1.22GB 다운로드 + 2GB 압축해제가 붙으므로,
#   HTTP Range 로 zip 중앙 디렉터리만 읽고 필요한 멤버만 뽑는다(아래 fetch_web_templates).
#   Range 가 막히면 전체 .tpz 폴백 — 느리지만 배포는 성공한다.
#
# 산출물(build/)은 git 에 커밋하지 않는다. 여기서 생성되고 Vercel 이 그대로 서빙한다.
set -euo pipefail

GODOT_VERSION="4.7.1-stable"          # project.godot 의 config/features = "4.7" 계열 최신 패치
GODOT_TEMPLATE_DIR="4.7.1.stable"     # export_templates 아래 디렉터리명 규칙
GODOT_BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
REL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}"

WORK="$(pwd)/.godot-vercel"
# Godot 은 export template 을 $XDG_DATA_HOME/godot 에서 찾는다. $HOME 쓰기 가능성에 기대지 않고 고정한다.
export XDG_DATA_HOME="${WORK}/share"
TEMPLATE_DIR="${XDG_DATA_HOME}/godot/export_templates/${GODOT_TEMPLATE_DIR}"

mkdir -p "$WORK" "$TEMPLATE_DIR"

# unzip 이 없는 이미지를 대비해 python3 로 폴백한다.
extract_zip() {  # <zip> <dest>
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$1" -d "$2"
  else
    python3 -m zipfile -e "$1" "$2"
  fi
}

echo "==> Godot ${GODOT_VERSION} 에디터 다운로드"
curl -fsSL --retry 3 --retry-delay 2 -o "${WORK}/godot.zip" "${REL}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
extract_zip "${WORK}/godot.zip" "${WORK}"
GODOT="${WORK}/${GODOT_BIN_NAME}"
chmod +x "$GODOT"
"$GODOT" --version

echo "==> Web export template 다운로드 (필요한 멤버만)"
fetch_web_templates() {
  python3 - "$1" "$2" <<'PY'
import io, sys, zipfile, urllib.request

url, dest = sys.argv[1], sys.argv[2]

class HttpRangeFile(io.RawIOBase):
    """zipfile 이 요구하는 seek/read 를 HTTP Range 요청으로 흉내낸다."""
    def __init__(self, url):
        self.url, self.pos = url, 0
        req = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            cr = r.headers.get("Content-Range")
            if not cr:
                raise RuntimeError("서버가 Range 를 지원하지 않는다")
            self.length = int(cr.split("/")[-1])
    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.pos
    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1 else self.length + off)
        return self.pos
    def read(self, n=-1):
        if n is None or n < 0:
            n = self.length - self.pos
        if n <= 0 or self.pos >= self.length:
            return b""
        end = min(self.pos + n, self.length) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        self.pos += len(data)
        return data

zf = zipfile.ZipFile(HttpRangeFile(url))
# 어느 web 변형이 쓰일지(nothreads / dlink 조합) export preset 해석에 의존하지 않도록 web_* 전부 받는다.
wanted = [n for n in zf.namelist()
          if n.startswith("templates/web") and n.endswith(".zip")] + ["templates/version.txt"]
total = 0
for name in wanted:
    try:
        data = zf.read(name)
    except KeyError:
        continue
    out = f"{dest}/{name.split('/')[-1]}"
    with open(out, "wb") as f:
        f.write(data)
    total += len(data)
    print(f"    {name.split('/')[-1]} {len(data)}B")
print(f"    합계 {total}B")
if total == 0:
    raise SystemExit("web export template 을 하나도 못 받았다")
PY
}

if ! fetch_web_templates "${REL}/Godot_v${GODOT_VERSION}_export_templates.tpz" "$TEMPLATE_DIR"; then
  echo "    Range 방식 실패 → 전체 .tpz 폴백"
  curl -fsSL --retry 3 -o "${WORK}/templates.tpz" "${REL}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  extract_zip "${WORK}/templates.tpz" "${WORK}/tpz"
  mv "${WORK}"/tpz/templates/* "$TEMPLATE_DIR"/
fi
ls -la "$TEMPLATE_DIR"

echo "==> 리소스 임포트 (.godot/ 은 gitignore 라 체크아웃에 없다)"
# 첫 임포트는 의존 순서 때문에 비정상 종료할 수 있다. 두 번 돌리고 종료코드는 무시한다.
"$GODOT" --headless --import --path . || true
"$GODOT" --headless --import --path . || true

echo "==> Web export"
mkdir -p build   # export 는 출력 디렉터리를 만들어주지 않는다
"$GODOT" --headless --export-release "Web" build/index.html

echo "==> 산출물 검증"
for f in build/index.html build/index.js build/index.wasm build/index.pck; do
  [ -s "$f" ] || { echo "FAIL: $f 이 없거나 0바이트다"; ls -la build || true; exit 1; }
  printf '    %-24s %s bytes\n' "$f" "$(stat -c %s "$f")"
done
echo "==> OK"
