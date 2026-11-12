#!/bin/bash
# コミットの前と同じ検査をすべて順に実行する。コミット前のフック（.githooks/pre-commit）からも呼ばれる。
#
#   1. 証明のゲート（spec/check.sh）
#   2. tools/check-extra.sh があれば、それも（プロジェクトごとのテストなど。守るファイルではない）
#
# 途中で1つでも失敗したら、そこで止めて終了コード 1 を返す。
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
export PATH="$HOME/.elan/bin:$PATH"

start=$(date +%s)
step() {
  local name=$1; shift
  local t0=$(date +%s)
  echo "== $name"
  if ! "$@"; then
    echo "× 失敗：$name" >&2
    exit 1
  fi
  echo "○ $name（$(( $(date +%s) - t0 )) 秒）"
}

step "証明のゲート（spec/check.sh）" bash spec/check.sh
if [ -f tools/check-extra.sh ]; then
  step "追加の検査（tools/check-extra.sh）" bash tools/check-extra.sh
fi
echo "== すべて成功（$(( $(date +%s) - start )) 秒）"
