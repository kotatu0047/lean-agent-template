#!/bin/bash
# 証明のゲート：これが通ることだけを「証明済み」とする（ビルドが通った補題の本数は進捗ではない）。
#
#   bash spec/check.sh          すべて（CI とコミット前のフックから）
#   bash spec/check.sh --quick  カーネルでの再検査を飛ばす（Claude Code の Stop フックから）
#
# 1. lake build：ライブラリと Spec（凍結した主張との型の一致と、公理が標準の3つだけであること）
# 2. ライブラリのソースに sorry・axiom・native_decide などがないこと
# 3. 凍結した主張ごとに、照合と公理の検査がそろっていること（照合していない主張は一覧に出す）
# 4. leanchecker：.olean をカーネルで検査し直す（メタプログラムで環境を書き換える手を弾く）
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
export PATH="$HOME/.elan/bin:$PATH"
source spec/config.sh

quick=0
[ "${1:-}" = "--quick" ] && quick=1

fail() { echo "× ゲートに通りません：$1" >&2; exit 1; }

lake build "$LIB" Spec >/dev/null 2>&1 || {
  lake build "$LIB" Spec 2>&1 | grep -E "error|sorry" | head -20 >&2
  fail "lake build（主張の不一致・許可していない公理・ビルドの誤り）"
}
echo "○ ビルドと、凍結した主張・公理の検査"
python3 spec/scan.py || fail "禁止した書き方"
python3 spec/coverage.py || fail "照合の書き方"
if [ $quick = 0 ]; then
  lake env leanchecker "$LIB" Spec || fail "leanchecker（カーネルでの再検査）"
  echo "○ カーネルでの再検査（leanchecker）"
fi
echo "== ゲートを通りました"
