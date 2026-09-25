# タスクリスト: 委託禁止領域の抽出規約の違反を検出する(Issue #28)

> 設計は `design.md`。判断番号はそちらを参照。**`.claude/scripts/` を触るため Codex に委託しない。**

## フェーズ1: 実装

- [x] 1. `lib-forbidden.sh` の抽出ブロックを判断2 の実装に置き換え、直前のコメントを書き換える(判断1・2)
- [x] 2. `AGENTS.md` §4 マーカー内の地の文からバックティックを外し、規約の段落をマーカー直後へ移す(判断3)
- [x] 3. `kickoff.md` とその写しに書式の規約を足す(判断4)
- [x] 4. `docs/template-dev/CHANGELOG.md` に 2026-09-25 節を足す(判断5)

## フェーズ2: 検証

- [x] 5. `--print-forbidden` がパス 17 種だけ・stderr 空であることを確認する(判断6-1)
- [x] 6. `check-forbidden-paths-doc.sh` が exit 0(判断6-2)
- [x] 7. 一時コピーで警告 4 種とマーカー片方の挙動を確認する(判断6-3・6-4)
- [x] 8. `bash -n` / `shellcheck` を通す(判断6-5)(shellcheck はこの環境に未インストールのため `bash -n` のみ実施。指摘なし)
- [x] 9. `git status --short` が判断7 の範囲に収まっていることを確認する(判断7)

## フェーズ3: 検収の追加(判断8)

- [x] 10. `delegate-codex.sh` 入口検査0 に awk を加え、関連コメント 2 箇所を直す(判断8)
- [x] 11. `bash -n` と `--print-forbidden`(stdout 32 行・stderr 空)を再確認し、`git status --short` が判断7 の範囲に収まることを確認する

## 申し送り

- shellcheck がこの devcontainer に未インストールだったため、判断6-5 は `bash -n` のみで確認した(指摘なし)。CI 側に shellcheck ジョブがあれば別途確認されたい
- `lib-forbidden.sh` はテンプレート所有(design.md 冒頭・判断5 に記載のとおり)。上流(`fuji18/claude-codex-template`)への同修正の起票は司令塔の担当
- 検収で司令塔が判断8 を追加(fork 往復 2 回目): 抽出が awk 依存になったのに入口検査0 が awk を確認しておらず、awk 不在時に固有パスの保護だけが黙って外れる経路があった。code-reviewer は指摘 0 件(所見として同じ経路を挙げた)
- **モード B(econ)中だったが code-reviewer を 1 回実施した**(作法からの逸脱。`.claude/scripts/` の検査ロジック変更で、CI が機械的に見ない領域のため)
- 上流 Issue に載せる範囲: lib-forbidden.sh の抽出と警告・入口検査0 の awk・kickoff.md の書式規約・AGENTS.md テンプレート本文の地の文。**上流に入るまで /sync-template で lib-forbidden.sh / delegate-codex.sh / kickoff.md が旧版に戻る**
- 別件: `.claude/template-manifest.json` の templateRepo が `claude-template` を指しているが、スクリプト群の実際の上流は `claude-codex-template`(前者には lib-forbidden.sh が存在しない)
