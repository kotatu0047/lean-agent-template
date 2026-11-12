#!/bin/bash
# テンプレートを、このプロジェクトの Lean ライブラリに合わせる。人が一度だけ実行する。
#
#   bash tools/init.sh <ライブラリ名>     例：bash tools/init.sh Demo
#
# 1. spec/ の中の MyLib を、ライブラリの名前に置き換える
# 2. lakefile.toml に Spec のライブラリを足す（lakefile.lean なら、足す内容を表示するだけ）
# 3. スクリプトに実行の権限を付け、コミット前のフック（.githooks/）を有効にする
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

lib=${1:-}
if ! [[ "$lib" =~ ^[A-Z][A-Za-z0-9_]*$ ]]; then
  echo "使い方：bash tools/init.sh <ライブラリ名>（大文字で始まる Lean のモジュール名。例：Demo）" >&2
  exit 1
fi
[ -f "$lib.lean" ] || [ -d "$lib" ] || echo "！ $lib.lean も $lib/ も見つかりません。先に lake init $lib lib などでライブラリを作ってください。" >&2

sed -i "s/^LIB=.*/LIB=$lib/" spec/config.sh
sed -i "s/\bMyLib\b/$lib/g" spec/Spec/Statements.lean spec/Spec/Check.lean
echo "○ spec/ をライブラリ $lib に合わせました"

snippet='
[[lean_lib]]
name = "Spec"
srcDir = "spec"
globs = ["Spec.+"]'
if [ -f lakefile.toml ]; then
  if grep -q '^name = "Spec"' lakefile.toml; then
    echo "○ lakefile.toml には Spec のライブラリがすでにあります"
  else
    printf '%s\n' "$snippet" >> lakefile.toml
    echo "○ lakefile.toml に Spec のライブラリを足しました"
  fi
else
  echo "！ lakefile.toml がありません。lakefile.lean なら、次と同じ内容を手で足してください：$snippet" >&2
fi

chmod +x spec/*.sh spec/*.py tools/*.sh tools/*.py .claude/hooks/*.py .githooks/*
git config core.hooksPath .githooks
mkdir -p .claude-history
echo "○ コミット前のフックを有効にしました（git config core.hooksPath .githooks）"
echo
echo "次に：spec/Spec/Statements.lean に主張を書き、bash spec/check.sh が通ることを確かめてください。"
