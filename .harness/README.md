# .harness/

司令塔(メインセッション)の運用状態と、横断的な判断の記録を置く。

**ここは「既存体系に受け皿が無いもの」だけを置く場所。** 進捗・仕様・履歴を二重管理しないこと。

## ファイル

| ファイル | git | 役割 |
| --- | --- | --- |
| `decisions.jsonl` | 追跡 | チケット単位の実測記録(委託先・往復回数・検収の指摘数・週枠使用率)。**1 行 1 JSON・追記のみ・削除禁止** |
| `state.json` | 追跡 | 司令塔のモデルと Agent Teams 設定。「モデル更新時の棚卸し」の記録先 |
| `README.md` | 追跡 | このファイル |
| `mode` | 無視 | ハーネスモードの単一ソース(`normal` / `econ` / `degraded`)。**無ければ `normal`** |
| `codex-runs/` | 無視 | Codex 委託の run record(`codex-run.sh` が管理) |

`.gitignore` が無視するのは `mode` と `codex-runs/` だけ。**`.harness/` を丸ごと無視しないこと。**

## ここに自作しないもの

| 置きたくなるもの | 正しい置き場 |
| --- | --- |
| 進捗ダッシュボード | `.steering/[日付]-[タスク名]/tasklist.md` + `/resume-work` |
| 仕様・要求・設計 | `docs/`(永続) / `.steering/*/requirements.md` `design.md`(作業単位) |
| 振り返り・申し送り | `steering` スキル モード3(tasklist.md へ追記) |
| ロールバック用スナップショット | 組み込み checkpointing + `/rewind`。**バックアップコピーを自作しない** |
| セッション横断の学び | memory(`~/.claude/projects/.../memory/`) |
| ハーネス層の変更履歴 | `docs/template-dev/CHANGELOG.md`(CI の `record-hygiene` が要求する) |

## decisions.jsonl の書き方

**書くのは PR を出す前**(検収が終わり、往復回数と指摘数が確定した時点)。マージ後に回すと記録そのものが落ちる。

`ticket` ラベル付き Issue を `Closes #N` でクローズする PR には、`"issue": N` の行が必須。
CI(`.github/workflows/record-hygiene.yml` / 実体は `.claude/scripts/check-record-hygiene.sh`)が機械的に検査する。
記録が不要な場合は `no-decision-record` ラベルで免除する(**理由を添えて司令塔が付ける**。既定の回避手段ではない)。

判断基準は `.claude/rules/lead/delegation-policy.md`「実測の記録」、設計は `docs/template-dev/econ-measurement.md`。

## ハーネスモード

読み取りの実体は `.claude/scripts/harness-mode.sh`。読む順序は固定で
**`CODEX_HARNESS_MODE` > `.harness/mode` > `normal`**。**推測せず必ずこれを通す。**

| モード | 値 | 概要 | 注入されるルール |
| --- | --- | --- | --- |
| A 通常 | (ファイル無し) / `normal` | 司令塔が検収(`/check` + `code-reviewer`)を回す | 無し |
| B 節約 | `econ` | 検収を CI に預け、PR は draft で積む | `.claude/rules/mode/econ.md` |
| C 縮退 | `degraded` | Claude が動かない期間。Codex が成果を積み、復帰時に検収する | `.claude/rules/mode/degraded.md` |

`normal` 以外のとき、SessionStart hook が該当ルールをメインセッションに注入する。

**切替を宣言するのは人間。** Claude は自動で降格も復帰もせず、自分の判断で `.harness/mode` を書き換えない。
