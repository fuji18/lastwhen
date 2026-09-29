# タスクリスト: プライバシーポリシーとデータセーフティの申告(Issue #70)

<!-- main-edit-ok -->
> **司令塔が直接書く。** 成果物はポリシーの文言・申告の判断・docs・ワークフロー 1 本で、アプリのコードに触れない。文言そのものが判断なので、`design.md` に全文を書いて委託すると同じものを二度書くことになる。ワークフローは委託禁止領域(`.github/workflows/`)。

## フェーズ1: 成果物

- [x] `site/privacy-policy/index.html` を書く(design §2)
- [x] `.github/workflows/pages.yml` を書く(design §3)
- [x] `docs/store/google-play-data-safety.md` を書く

## フェーズ2: docs

- [x] PRD「未決事項」#5 を決定に移す
- [x] architecture「セキュリティ制約」に置き場所を添える
- [x] repository-structure に `site/` と `docs/store/` を足す
- [x] `docs/template-dev/CHANGELOG.md` にワークフローの追加を書く

## フェーズ3: 検証と PR

- [x] ~~`/check`~~(アプリのコードに変更がなく、モード B(econ)でもあるため CI に委ねる。HTML のタグの対応と secretlint だけ手元で確かめた)
- [x] Pages を有効化する(source = GitHub Actions)
- [x] `decisions.jsonl` に 1 行追記する

## 人手の作業(マージ後)

- [x] ~~マージ後に Pages のデプロイが成功し、ログアウトした状態で URL を開けることを確かめる~~(マージ後の人手の作業。PR ボディに書いた)

## 実装後の振り返り

- 実装完了日: 2026-09-29
- 計画との差分: なし。Pages はワークフローが main で走るまでページが出ないので、URL の確認はマージ後になる
- 申し送り: #81 の「このアプリについて」から上の URL へ導線を張る。#68 で依存(共有・ファイル選択)を足したら `docs/store/google-play-data-safety.md` の「根拠の確かめ方」を回し直す
