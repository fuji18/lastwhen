# 要求: 委託禁止領域の抽出規約の違反を検出する(Issue #28)

## 背景

`.claude/scripts/lib-forbidden.sh` は `AGENTS.md` §4 のマーカー(`<!-- kickoff:delegation-forbidden-paths -->`)内から
**バックティック囲みの文字列をすべて**抽出し、委託の出口検査の対象に加えている。§4 自身が
「この節のバックティックは禁止領域そのもののパスにだけ使う」と宣言しているが、同梱の文章自身がこれを破っており、
`--print-forbidden` に `/kickoff` `<!-- verify-probe: ... -->` `delegate-codex.sh` `exists` `npx` `python3` が混ざる。

実在検査で落ちるため今は無害だが、規約違反が**過剰(地の文の語が実在パスと衝突して誤爆)**にも
**過少(バックティックなしで書いたパスが静かに保護から外れる)**にも、誰にも通知されない。

## ユーザーの決定(2026-09-25)

| 論点 | 決定 |
| --- | --- |
| テンプレート所有の `lib-forbidden.sh` をどこで直すか | **このリポジトリで直し、同じ修正を上流(`fuji18/claude-codex-template`)へ Issue で起票して追跡する** |

- 上流は `fuji18/claude-codex-template`(`lib-forbidden.sh` は手元と同一内容・未修正・関連 Issue なし)
- 上流に入るまでは `/sync-template` で `lib-forbidden.sh` が旧版に戻るリスクがある。上流 Issue に明記する

## スコープ

1. `lib-forbidden.sh` の抽出を「箇条書き行の、説明ダッシュ(` — `)より前のコードスパン」に狭める
2. 規約違反を**警告として表に出す**(過剰方向・過少方向の両方)
3. `AGENTS.md` §4 マーカー内の地の文からバックティックを外す
4. `/kickoff` の記入指示に書式の規約を明記する(`.claude/commands/kickoff.md` とその写し)
5. `docs/template-dev/CHANGELOG.md` に記録する
6. 上流へ Issue を起票する(司令塔)

## スコープ外

- 出口検査の判定方式(内容ハッシュ比較)の変更
- `FORBIDDEN_PATHS` 配列(汎用項目)の中身の変更
- `.harness/codex-runs/` の扱い
- `.claude/template-manifest.json` の `templateRepo` が `claude-template` を指している件(実際の上流は `claude-codex-template`)。別件として報告のみ

## 受け入れ条件(Issue #28)

- [ ] `bash .claude/scripts/delegate-codex.sh --print-forbidden` の出力が**パスだけ**になる
- [ ] マーカー内にパスに見えない語がバックティックで書かれていたら、警告が出る
- [ ] マーカー内にバックティックなしのパスらしき行があったら、警告が出る(過少方向)
- [ ] `bash .claude/scripts/check-forbidden-paths-doc.sh` が引き続き exit 0
- [ ] マーカーが片方しか無いときのフェイルオープン挙動が従来どおり(警告して抽出スキップ)
- [ ] 既存の禁止領域(汎用 13 項目 + `lib/data/database/` + `lib/data/migrations/`)がすべて抽出される
