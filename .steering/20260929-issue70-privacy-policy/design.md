# 設計書: プライバシーポリシーとデータセーフティの申告(Issue #70)

<!-- status: ready -->

> 決定と理由は `requirements.md`。成果物はすべて文書とワークフローで、アプリのコード(`lib/` / `android/`)には触れない。

## 1. ファイル

| パス | 内容 |
| --- | --- |
| `site/privacy-policy/index.html` | ポリシー本文。**原稿はこの HTML 1 つだけ**(Markdown の複製を作らない) |
| `.github/workflows/pages.yml` | `site/` を GitHub Pages にデプロイする |
| `docs/store/google-play-data-safety.md` | データセーフティの回答案と根拠 |

## 2. ページ(`site/privacy-policy/index.html`)

- `lang="ja"`、`<meta name="viewport">`、`<meta name="robots">` は付けない(検索に載ってよい)
- CSS はインラインで持つ。本文幅 40rem、`prefers-color-scheme: dark` に対応する。外部のフォント・スクリプトを読み込まない(ポリシーのページ自体が第三者へ通信しない)
- 節: はじめに / 収集する情報 / 端末に保存する情報 / OS のバックアップ / データの書き出し / 通知 / 第三者への提供 / データの削除 / ポリシーの変更 / お問い合わせ / 制定日・改定日
- 用語は glossary に従う(**項目** / **記録**)

## 3. ワークフロー(`.github/workflows/pages.yml`)

- トリガ: `push`(`main`、`paths: site/**` と自分自身)+ `workflow_dispatch`
- 権限: ワークフロー既定は `contents: read`。deploy ジョブだけ `pages: write` / `id-token: write`
- `concurrency: group: pages, cancel-in-progress: false`(公式の推奨どおり、進行中のデプロイを打ち切らない)
- ジョブ 1 本: `actions/checkout@v7` → `actions/configure-pages@v6` → `actions/upload-pages-artifact@v5`(`path: site`)→ `actions/deploy-pages@v5`。`environment: github-pages`
- リポジトリ側の設定: Pages の source を「GitHub Actions」にする(`gh api -X POST repos/fuji18/lastwhen/pages -f build_type=workflow`)。PR の作成時に司令塔が実行する

## 4. docs の更新

- PRD「未決事項」: #5 を表から外し、「決定済み」に #70 の節を足す
- architecture「セキュリティ制約」: 「プライバシーポリシーとストアのデータ収集申告に明記する」に、両者の置き場所を添える
- repository-structure: ツリーに `site/` と `docs/store/` を足し、`site/` の説明節を置く
- `docs/template-dev/CHANGELOG.md`: ワークフローの追加を記録する(record-hygiene の要求)
