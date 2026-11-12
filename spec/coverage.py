#!/usr/bin/env python3
"""凍結した主張（Statements.lean）と、その照合（Check.lean）がそろっているかを確かめる。

- Check.lean の照合（theorem X : Spec.X := …）には、どれも #assert_std_axioms Spec.Checked.X がなければならない
  （ないと、sorry や独自の公理で証明した定理でも照合だけは通ってしまう）。なければ終了コード 1。
- まだ照合していない主張は「未証明」として一覧に出す（ゲートは止めない。証明が途中の主張がありうるため）。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = r"[A-Za-z_][A-Za-z0-9_?'!]*"


def code(path: Path) -> str:
    """コメント（入れ子の /- -/ と --）を除く。行の区切りは保つ"""
    src = path.read_text(encoding="utf-8")
    out, i, n, depth = [], 0, len(src), 0
    while i < n:
        if depth == 0 and src.startswith("--", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif src.startswith("/-", i):
            depth += 1; i += 2
        elif depth > 0 and src.startswith("-/", i):
            depth -= 1; i += 2
        else:
            if depth == 0 or src[i] == "\n":
                out.append(src[i])
            i += 1
    return "".join(out)


stmts = re.findall(rf"(?m)^\s*(?:noncomputable\s+)?def\s+({NAME})\s*:\s*Prop\b", code(ROOT / "spec/Spec/Statements.lean"))
check = code(ROOT / "spec/Spec/Check.lean")
checked = dict(re.findall(rf"(?m)^\s*theorem\s+({NAME})\s*:\s*Spec\.({NAME})\s*:=", check))
asserted = set(re.findall(rf"(?m)^\s*#assert_std_axioms\s+Spec\.Checked\.({NAME})\s*$", check))

bad = [f"{t}（Spec.{s} の照合）に #assert_std_axioms Spec.Checked.{t} がない" for t, s in checked.items() if t not in asserted]
bad += [f"#assert_std_axioms Spec.Checked.{a} に対応する照合がない" for a in sorted(asserted - set(checked))]
if bad:
    print("照合の書き方に問題があります：", file=sys.stderr)
    print("\n".join("  " + b for b in bad), file=sys.stderr)
    sys.exit(1)

todo = [s for s in stmts if s not in set(checked.values())]
print(f"○ 凍結した主張 {len(stmts)} 本のうち {len(stmts) - len(todo)} 本を照合済み")
if todo:
    print("  未証明（照合していない主張）：" + "・".join(todo))
