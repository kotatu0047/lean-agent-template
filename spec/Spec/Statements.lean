import MyLib

/-!
# 凍結した主張（人がレビューする仕様）

「証明済み」と言いたい定理の主張を、ここに `def 名前 : Prop := …` の形で書いて凍結する。
`Spec/Check.lean` が、ライブラリの定理の型がこの主張とちょうど一致すること、使う公理が標準の3つだけであることを
検査する。

- このファイルは人がレビューして変える。エージェントは変えない（`.claude/settings.json` で書き込みを禁止）
- 主張に出てくる定義はライブラリ側にある。定義を変えると主張の意味も変わるので、定義の変更は別にレビューする
  （`CLAUDE.md`）
-/

namespace Spec

/-! ## 主張

例（ライブラリに `MyLib.rev : List α → List α` があるとき）：

```
/-- リストを2回反転すると元に戻る -/
def rev_rev : Prop := ∀ (xs : List Nat), MyLib.rev (MyLib.rev xs) = xs
```
-/

end Spec
