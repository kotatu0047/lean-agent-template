import Lean
import Spec.Statements

/-!
# 検査：ライブラリの定理が凍結した主張を証明していること

各行の `theorem` は、ライブラリの定理の型が `Spec.Statements` の主張と一致するときだけ通る
（命題のすり替え・余計な仮定を弾く）。`#assert_std_axioms` は、使う公理が `propext`・`Classical.choice`・
`Quot.sound` だけであることを確かめる（`sorry`＝`sorryAx`、独自の `axiom`、`native_decide`＝`Lean.ofReduceBool` を弾く）。

主張1本につき、次の2行を足す（`spec/coverage.py` が、主張と照合と公理の検査がそろっているかを確かめる）。

```
theorem rev_rev : Spec.rev_rev := @MyLib.rev_rev
#assert_std_axioms Spec.Checked.rev_rev
```
-/

open Lean Elab Command in
/-- 定数 `id` が使う公理が、標準の3つだけであることを確かめる -/
elab "#assert_std_axioms " id:ident : command => do
  let n ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
  let axs ← liftCoreM <| collectAxioms n
  let ok := [``propext, ``Classical.choice, ``Quot.sound]
  let bad := axs.filter (fun a => !ok.contains a)
  unless bad.isEmpty do
    throwError "許可していない公理を使っています（{n}）：{bad}"

namespace Spec.Checked

end Spec.Checked
