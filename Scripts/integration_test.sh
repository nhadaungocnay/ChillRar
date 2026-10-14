#!/usr/bin/env bash
# Integration tests for the chillrar CLI (and therefore RarKit + libunrar).
# Requires the RAR command line tool to create fixtures:
#   RAR_BIN=/path/to/rar make test     (default: /tmp/rartool/rar/rar)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/build/chillrar"
RAR="${RAR_BIN:-/tmp/rartool/rar/rar}"
RAR4="${RAR4_BIN:-/tmp/rartool6/rar/rar}"
WORK="$(mktemp -d /tmp/chillrar-test.XXXXXX)"
PASS=0; FAIL=0

if [[ ! -x "$RAR" ]]; then
  echo "SKIP integration tests: rar binary not found ($RAR)"
  echo "  curl -L https://www.rarlab.com/rar/rarmacos-arm-723.tar.gz | tar -xz -C /tmp/rartool"
  exit 0
fi

ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---------- fixtures ----------
SRC="$WORK/src/Bộ sưu tập"
mkdir -p "$SRC/Tài liệu/sâu hơn" "$SRC/empty dir"
echo "Xin chào thế giới 🌏" > "$SRC/Tài liệu/ghi chú.txt"
echo "nested" > "$SRC/Tài liệu/sâu hơn/a.txt"
head -c 3000000 /dev/urandom > "$SRC/random.bin"
yes "compressible line" | head -n 200000 > "$SRC/text.log"

cd "$WORK/src"
R() { "$RAR" a -idq -r "$@" >/dev/null; }
# RAR 7 dropped RAR4 creation (-ma4, -vn); use RAR 6.x for those fixtures.
R4() { "$RAR4" a -idq -r "$@" >/dev/null; }
R "$WORK/basic.rar" "Bộ sưu tập"
R -s "$WORK/solid.rar" "Bộ sưu tập"
R -pSecret123 "$WORK/pw.rar" "Bộ sưu tập"
R -hpSecret123 "$WORK/hp.rar" "Bộ sưu tập"
R -v1m "$WORK/multi.rar" "Bộ sưu tập"
HAVE_RAR4=0
if [[ -x "$RAR4" ]]; then
  HAVE_RAR4=1
  R4 -ma4 "$WORK/rar4.rar" "Bộ sưu tập"
  R4 -ma4 -pSecret123 "$WORK/pw4.rar" "Bộ sưu tập"
  R4 -ma4 -hpSecret123 "$WORK/hp4.rar" "Bộ sưu tập"
  R4 -ma4 -v1m -vn "$WORK/oldvol.rar" "Bộ sưu tập"
fi
(cd "$SRC" && "$RAR" a -idq "$WORK/single.rar" "random.bin" >/dev/null)
mkdir -p "$WORK/broken" && cp "$WORK"/multi.part*.rar "$WORK/broken/"
LAST=$(ls "$WORK/broken"/multi.part*.rar | sort | tail -1); rm "$LAST"
cd "$WORK"

same() { diff -r "$SRC" "$1/Bộ sưu tập" >/dev/null 2>&1 || diff -r "$SRC" "$1" >/dev/null 2>&1; }
x()    { local out="$WORK/out-$1"; rm -rf "$out"; mkdir -p "$out"; shift
         "$CLI" x "$@" -o "$out" >/dev/null 2>"$WORK/err.txt"; }

echo "== Listing"
check "list RAR5 shows unicode names" "'$CLI' l basic.rar | grep -q 'ghi chú.txt'"
check "list multi-volume total"       "'$CLI' l multi.part2.rar | grep -q 'multi-volume'"
"$CLI" l hp.rar >/dev/null 2>&1; check "list encrypted headers w/o password -> exit 3" "[[ $? == 3 ]]"
"$CLI" l hp.rar -p wrong >/dev/null 2>&1; check "list encrypted headers wrong password -> exit 3" "[[ $? == 3 ]]"
check "list encrypted headers with password" "'$CLI' l hp.rar -p Secret123 | grep -q 'random.bin'"

echo "== Extraction"
x basic basic.rar;   check "RAR5 content identical"  "same out-basic"
x solid solid.rar;   check "solid content identical" "same out-solid"
check "empty dir preserved" "[[ -d 'out-basic/Bộ sưu tập/empty dir' ]]"

echo "== Passwords"
x pw0 pw.rar;                  check "RAR5 missing password -> exit 3" "[[ $? == 3 ]]"
x pw1 pw.rar -p wrong;         check "RAR5 wrong password -> exit 3"   "[[ $? == 3 ]] && grep -q 'không đúng' err.txt"
check "wrong password leaves no partial output" "[[ -z \$(ls -A out-pw1) ]]"
x pw2 pw.rar -p Secret123;     check "RAR5 right password"             "same out-pw2"
x hp hp.rar -p Secret123;      check "encrypted headers right password" "same out-hp"

echo "== Multi-volume"
x mv multi.part3.rar;          check "start from part3 -> full content" "same out-mv"
x br broken/multi.part1.rar;   check "missing last volume -> error"     "[[ $? != 0 ]] && grep -q 'Thiếu' err.txt"

if [[ $HAVE_RAR4 == 1 ]]; then
  echo "== RAR4 (legacy format)"
  check "list RAR4" "'$CLI' l rar4.rar | grep -q 'sâu hơn/a.txt'"
  x rar4 rar4.rar;               check "RAR4 content identical"          "same out-rar4"
  x pw3 pw4.rar;                 check "RAR4 missing password -> exit 3" "[[ $? == 3 ]]"
  x pw3 pw4.rar -p wrong;        check "RAR4 wrong password -> exit 3"   "[[ $? == 3 ]]"
  check "RAR4 wrong password leaves no partial output" "[[ -z \$(ls -A out-pw3) ]]"
  x pw4 pw4.rar -p Secret123;    check "RAR4 right password"             "same out-pw4"
  "$CLI" l hp4.rar -p wrong >/dev/null 2>&1; check "RAR4 enc headers wrong password -> exit 3" "[[ $? == 3 ]]"
  x hp4 hp4.rar -p Secret123;    check "RAR4 enc headers right password" "same out-hp4"
  x ov oldvol.r01;               check "old naming .r01 -> full content"  "same out-ov"
else
  echo "== RAR4 tests skipped (set RAR4_BIN to a RAR 6.x binary)"
fi

echo "== Layout"
x sg single.rar;               check "single item placed directly"      "[[ -f out-sg/random.bin ]]"
"$CLI" x single.rar -o out-sg >/dev/null 2>&1
check "no overwrite -> 'random 2.bin'" "[[ -f 'out-sg/random 2.bin' ]]"
x fd single.rar --folder;      check "--folder wraps in archive name"   "[[ -f out-fd/single/random.bin ]]"
check "no temp folders left" "[[ -z \$(find '$WORK' -name '.chillrar-*') ]]"

echo
echo "Passed: $PASS  Failed: $FAIL   (work dir: $WORK)"
[[ $FAIL == 0 ]] && rm -rf "$WORK"
exit $FAIL
