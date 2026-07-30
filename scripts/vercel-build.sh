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

GODOT_VERSION="4.7.1-stable"          # project.godot 의 config/features 와 같은 계열이어야 한다(아래 검사)
GODOT_TEMPLATE_DIR="4.7.1.stable"     # export_templates 아래 디렉터리명 규칙
GODOT_BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
REL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}"
# preset 이 thread_support=false / extensions_support=false 라서 실제로 쓰이는 템플릿.
# 이게 없으면 export 가 조용히 다른 변형을 쓰거나 실패하므로 명시적으로 검사한다.
REQUIRED_TEMPLATE="web_nothreads_release.zip"

# 엔진 핀과 프로젝트가 어긋나면 "낡은 엔진으로 조용히 빌드된 다른 게임"이 배포된다.
# 로컬에서 상위 버전으로 열어 저장하면 config/features 가 올라가므로 여기서 막는다.
PROJECT_FEATURE="$(sed -n 's/^config\/features=PackedStringArray("\([0-9]*\.[0-9]*\)".*/\1/p' project.godot)"
if [ -z "$PROJECT_FEATURE" ]; then
  echo "FAIL: project.godot 에서 config/features 버전을 못 읽었다"; exit 1
fi
case "$GODOT_VERSION" in
  "$PROJECT_FEATURE".*|"$PROJECT_FEATURE"-*) ;;
  *) echo "FAIL: project.godot features=\"$PROJECT_FEATURE\" 인데 CI 는 $GODOT_VERSION 로 빌드한다."
     echo "      scripts/vercel-build.sh 의 GODOT_VERSION/GODOT_TEMPLATE_DIR 를 맞춰라."; exit 1 ;;
esac
echo "==> 엔진 핀 확인: project.godot features=$PROJECT_FEATURE / CI=$GODOT_VERSION"

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
  # ⚠ set -e 는 `if !` 조건 안에서 함수 본문에 적용되지 않는다.
  #   본문이 여러 줄로 늘어나도 실패가 삼켜지지 않게 종료코드를 직접 돌려준다.
  local rc=0
  python3 - "$1" "$2" <<'PY' || rc=$?
import io, sys, time, zipfile, urllib.request

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
        # 한 번의 네트워크 순간장애가 1.28GB 폴백으로 번지지 않게 재시도한다
        # (에디터 다운로드의 `curl --retry 3` 과 같은 수준을 맞춘다).
        last = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = r.read()
                break
            except Exception as e:      # noqa: BLE001 — 네트워크 계열 전부 재시도 대상
                last = e
                if attempt == 2:
                    raise
                time.sleep(2 * (attempt + 1))
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
  return "$rc"
}

if ! fetch_web_templates "${REL}/Godot_v${GODOT_VERSION}_export_templates.tpz" "$TEMPLATE_DIR"; then
  echo "    Range 방식 실패 → 전체 .tpz 폴백"
  curl -fsSL --retry 3 -o "${WORK}/templates.tpz" "${REL}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  extract_zip "${WORK}/templates.tpz" "${WORK}/tpz"
  mv "${WORK}"/tpz/templates/* "$TEMPLATE_DIR"/
fi
ls -la "$TEMPLATE_DIR"
# preset 이 실제로 요구하는 변형이 왔는지 확인한다. 목록이 줄어도 "합계>0" 은 통과하므로 따로 본다.
[ -s "${TEMPLATE_DIR}/${REQUIRED_TEMPLATE}" ] || {
  echo "FAIL: ${REQUIRED_TEMPLATE} 가 없다 — preset(thread_support=false)이 쓰는 템플릿이다"; exit 1; }

echo "==> 리소스 임포트 (.godot/ 은 gitignore 라 체크아웃에 없다)"
# 앞의 두 번은 의존 순서 때문에 비정상 종료할 수 있어 종료코드를 무시한다.
# 세 번째는 반드시 성공해야 한다 — `|| true` 만 두면 OOM(137)·디스크풀·SIGSEGV 가
# 전부 조용히 넘어가고, 메시 40개 빠진 pck 도 뒤의 존재검사는 통과한다.
"$GODOT" --headless --import --path . || true
"$GODOT" --headless --import --path . || true
"$GODOT" --headless --import --path .

# 임포트 산출물 수 점검. 2026-07-30 실측으로 77/77 정확히 일치하는 것을 확인했으므로
# 하드 게이트로 둔다 — 에셋이 조용히 빠진 채 초록으로 배포되는 것을 막는 자리다.
want=$(find . -name '*.import' -not -path './.godot-vercel/*' | wc -l)
got=$(ls -1 .godot/imported/*.md5 2>/dev/null | wc -l || echo 0)
echo "    .import 파일 ${want}개 / .godot/imported/*.md5 ${got}개"
[ "$got" -ge "$want" ] || {
  echo "FAIL: 임포트 산출물 ${got} < .import 파일 ${want} — 에셋이 누락된 채 export 된다"; exit 1; }

echo "==> Web export"
mkdir -p build   # export 는 출력 디렉터리를 만들어주지 않는다
"$GODOT" --headless --export-release "Web" build/index.html

echo "==> 산출물 검증"
for f in build/index.html build/index.js build/index.wasm build/index.pck; do
  [ -s "$f" ] || { echo "FAIL: $f 이 없거나 0바이트다"; ls -la build || true; exit 1; }
  printf '    %-24s %s bytes\n' "$f" "$(stat -c %s "$f")"
done

# 존재검사만으로는 "임포트가 반쯤 죽어 알맹이 빠진 pck" 를 못 잡는다.
# 매직바이트로 형식을, 하한선으로 내용 누락을 본다(현재 실측: wasm 39.5MB / pck 11.9MB).
[ "$(head -c4 build/index.pck)" = "GDPC" ] || { echo "FAIL: index.pck 매직이 GDPC 가 아니다"; exit 1; }
head -c4 build/index.wasm | od -An -tx1 | grep -q '00 61 73 6d' || { echo "FAIL: index.wasm 매직이 \\0asm 이 아니다"; exit 1; }
PCK_MIN=$((10 * 1024 * 1024))
pck=$(stat -c %s build/index.pck)
[ "$pck" -ge "$PCK_MIN" ] || { echo "FAIL: index.pck ${pck}B < 하한 ${PCK_MIN}B — 에셋이 통째로 빠졌다"; exit 1; }
WASM_MIN=$((30 * 1024 * 1024))
wasm=$(stat -c %s build/index.wasm)
[ "$wasm" -ge "$WASM_MIN" ] || { echo "FAIL: index.wasm ${wasm}B < 하한 ${WASM_MIN}B"; exit 1; }

# 생성된 index.html 이 참조하는 아이콘들. preset 에서 export_icon 을 끌 수도 있으니 경고만 한다.
for f in build/index.png build/index.icon.png build/index.apple-touch-icon.png; do
  [ -s "$f" ] || echo "    WARN: $f 없음 (index.html 이 참조한다)"
done
echo "==> OK"
