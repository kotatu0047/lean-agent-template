#!/usr/bin/env python3
"""Claude Code の PreToolUse フック（Bash）：守るファイルを書き換えそうなコマンドを止める。

settings.json の permissions.deny は Edit・Write ツールにしか効かず、sed -i やリダイレクトでは書き換えられるので、
その穴をふさぐ。守るファイルの一覧は .claude/settings.json の deny の Edit(...) から読む（一覧は1か所だけ）。
コマンドの文面から推測するだけなので完全ではない（最後の防御は CI とレビュー）。
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR") or Path(__file__).resolve().parent.parent)


def protected() -> list[str]:
    """守るファイル・ディレクトリの名前に当たる正規表現（spec なら spec と spec/… に当たり、inspect や spec.md には当たらない）"""
    deny = json.loads((ROOT / ".claude/settings.json").read_text(encoding="utf-8"))["permissions"]["deny"]
    out = []
    for rule in deny:
        m = re.fullmatch(r"Edit\(/(.+)\)", rule)
        if m:
            path = m.group(1)
            path = path[:-3] if path.endswith("/**") else path
            out.append(r"(?<![\w.-])" + re.escape(path) + r"(?![\w.-])")
    return out


# 守るファイルを使うだけのコマンド（読む・実行する）。コマンドの先頭（; & | の後も）にあるときだけ外す。
# 引数の位置（git checkout -- tools/check-all.sh など）や書き込み先（> spec/check.sh）にあるときは外さない。
ALLOWED = [
    r"(?:bash\s+)?spec/check\.sh(\s+--quick)?",
    r"python3\s+spec/(scan|coverage)\.py",
    r"(?:bash\s+)?tools/check-all\.sh",
    r"python3\s+tools/scan-history\.py(\s+--all)?",
]
# 何も書き換えないリダイレクト
HARMLESS = [r"\d*>&\d", r"&?\d*>\s*/dev/null"]
WRITE = [
    r">", r"\btee\b", r"\bsed\b[^|;&]*\s-i", r"\bperl\b[^|;&]*\s-[a-z]*i", r"\bmv\b", r"\bcp\b", r"\brm\b",
    r"\bln\b", r"\bchmod\b", r"\btruncate\b", r"\bdd\b", r"\binstall\b", r"\btouch\b", r"\bpython3?\b", r"\bnode\b",
    r"\bgit\s+(checkout|restore|reset|apply|am|stash|mv|rm|revert|cherry-pick|merge|rebase|pull)\b", r"\bpatch\b",
]

cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
rest = cmd
for a in HARMLESS:
    rest = re.sub(a, " ", rest)
for a in ALLOWED:
    rest = re.sub(r"(^|[;&|(])\s*" + a + r"(?=\s|$|[;&|)])", r"\1 ", rest)
if any(re.search(p, rest) for p in protected()) and any(re.search(w, rest) for w in WRITE):
    print("守るファイル（.claude/settings.json の deny にあるもの）を書き換えうるコマンドは実行できません。"
          "変更が必要なら、案をユーザーに示して頼んでください（CLAUDE.md）。", file=sys.stderr)
    sys.exit(2)
