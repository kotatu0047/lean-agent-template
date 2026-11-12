# AI エージェントに Lean で証明させるためのテンプレート

AI エージェント（Claude Code）に Lean のコードと証明を書かせるときに、「通ったふり」をできないようにする外枠です。
Lean のプロジェクトの中身（`lakefile`・ライブラリのソース）は含みません。どの Lean のプロジェクトにも足せます。

カードゲームのルールを Lean で書いて証明するプロジェクト（[yuugi-lean](https://github.com/kotatu0047/yuugi-lean)）の
進め方を切り出したものです。

## 何を防ぐか

エージェントは、詰まると「通す」ために次のようなことをしがちです。それぞれを別の仕組みで止めます。

| すり抜け方 | 止める仕組み |
|---|---|
| `sorry`・独自の `axiom`・`native_decide` で証明を済ませる | `spec/Spec/Check.lean` の公理の検査と `spec/scan.py` |
| 命題を弱める・仮定を足す・別の命題にすり替える | 人が凍結した主張（`spec/Spec/Statements.lean`）と、型での照合 |
| 検査やその設定自体を書き換える | `.claude/settings.json` の書き込み禁止と `spec/guard.py`（Bash のフック） |
| メタプログラムで環境を書き換える | `leanchecker` によるカーネルでの再検査 |
| 「証明できました」と言って終える | Stop フック（`spec/stop-gate.sh`）がゲートを走らせ、通らなければ差し戻す |
| 手元の検査を飛ばしてコミットする | コミット前のフックと CI（`.github/workflows/spec.yml`） |

ほかに、会話を `.claude-history/` に Markdown で残し、コミットの前に秘密の情報が混じっていないか調べます。

## 「証明済み」の意味

**`bash spec/check.sh` が通り、その主張が `spec/Spec/Check.lean` で照合されていること**だけを「証明済み」とします。

1. 人が、証明したい主張を `spec/Spec/Statements.lean` に `def 名前 : Prop := …` で書いて凍結する
2. エージェントが、ライブラリの中でその定理を証明する
3. `spec/Spec/Check.lean` に照合の2行を足す（エージェントが案を出し、人が足す）

   ```lean
   theorem rev_rev : Spec.rev_rev := @MyLib.rev_rev
   #assert_std_axioms Spec.Checked.rev_rev
   ```

   1行目は、定理の型が凍結した主張とちょうど一致しないと通りません。2行目は、使う公理が `propext`・
   `Classical.choice`・`Quot.sound` だけでないと通りません。

## ファイル

```
CLAUDE.md                     エージェントへの決まり（「プロジェクトの前提」は自分で書く）
spec/
  config.sh                   ライブラリの名前
  Spec/Statements.lean        凍結した主張（人が書く）
  Spec/Check.lean             主張とライブラリの定理の照合（人が足す）
  check.sh                    証明のゲート
  scan.py                     禁止した書き方の検査
  coverage.py                 照合と公理の検査がそろっているか。未証明の主張の一覧
  guard.py                    Bash で守るファイルを書き換えるコマンドを止めるフック
  stop-gate.sh                応答を終える前にゲートを走らせるフック
.claude/
  settings.json               守るファイルの一覧（permissions.deny）とフックの登録
  hooks/save-history.py       会話を .claude-history/ に保存するフック
.githooks/pre-commit          コミット前の検査
.github/workflows/spec.yml    CI でのゲート
tools/
  init.sh                     テンプレートをプロジェクトに合わせる（最初に一度）
  check-all.sh                コミット前と同じ検査（ゲート ＋ tools/check-extra.sh）
  scan-history.py             会話記録に秘密の情報がないかの検査
  scan-history.allow          その検査で、本物の秘密でないと分かった文字列
.claude-history/              会話記録
```

守るファイル（エージェントが変えないもの）の一覧は `.claude/settings.json` の `permissions.deny` だけです。
`spec/guard.py` もそこから読みます。

## 使い方

必要なもの：[elan](https://github.com/leanprover/elan)（Lean）、Python 3、git、Claude Code。

### 新しいプロジェクトを始める

1. GitHub で「Use this template」から新しいリポジトリを作り、手元に clone する
2. Lean のライブラリを作る（例：`lake init Demo lib`）
3. `bash tools/init.sh Demo` を実行する（`spec/` の `MyLib` を置き換え、`lakefile.toml` に Spec のライブラリを足し、
   コミット前のフックを有効にする）
4. `bash spec/check.sh` が通ることを確かめる
5. `CLAUDE.md` の「プロジェクトの前提」と、この README を自分のプロジェクトのものに書き換える

### 今あるプロジェクトに足す

`lakefile` と `lean-toolchain` 以外のファイルをすべてプロジェクトにコピーし、上の 3〜5 を行います。

- `CLAUDE.md`・`.claude/settings.json`・`.gitignore` がすでにある場合は、手でまとめてください
- `lakefile.lean` の場合は、`tools/init.sh` が表示する内容（Spec のライブラリ）を手で足してください

### プロジェクトごとの検査を足す

C# のテストやドキュメントのビルドなど、ゲート以外にコミット前に走らせたいものは `tools/check-extra.sh` に書きます。
このファイルは守るファイルではないので、エージェントも変えられます。

## 限界

- `spec/guard.py` はコマンドの文面から推測するだけです。最後の防御は CI と、`spec/` の差分のレビューです。
- 主張が使う定義（ライブラリ側）を変えると、主張の文面は同じでも意味が変わります。定義の変更はレビューしてください。
- 会話記録の検査はパターンに合う文字列だけを拾います。普通の文章に書かれた秘密は見逃すことがあります。
