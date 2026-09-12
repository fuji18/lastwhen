# 設計: プロジェクトキックオフ(Flutter 化)

<!-- status: ready -->

## 方針: Node は「ハーネス専用」に縮退させ、削除しない

テンプレートのガードレールは 2 系統が npm に依存している。

| 依存 | 何に使われているか | 代替の有無 |
| --- | --- | --- |
| `husky` | `core.hooksPath=.husky` の設定(強制 2・3 層の起動経路) | 手動設定で代替可だが再現性が落ちる |
| `lint-staged` | `.husky/pre-commit` から起動する差分検査 | 代替なし |
| `secretlint` | 機密の混入検出(pre-commit と CI の 2 層) | Dart エコシステムに同等品なし |

Flutter 化で npm を完全に抜くと、**保護ブランチ検査の強制 2・3 層と、pre-commit の機密検出が
同時に失われる**。一方 devcontainer の Node feature は Claude Code 本体と Codex CLI の
インストール経路なので**どのみち残る**。したがって追加コストは実質ゼロであり、
`package.json` を**ハーネス専用の 3 依存だけに削る**方針を採る。

アプリのツールチェーン(lint / format / 型 / テスト)はすべて Dart 側に移す。

| 役割 | 置換前 | 置換後 |
| --- | --- | --- |
| lint | `eslint` | `flutter analyze` |
| 型チェック | `tsc --noEmit` | `flutter analyze`(Dart は分離不可) |
| フォーマット | `prettier` | `dart format` |
| テスト | `vitest` | `flutter test` |
| 機密検出 | `secretlint` | `secretlint`(据え置き) |

## 変更対象ファイル

### 1. 削除する(TypeScript ツールチェーン)

- `tsconfig.json`
- `vitest.config.ts`
- `eslint.config.js`
- `.prettierrc` / `.prettierignore`
- `src/index.ts` / `src/index.test.ts`

### 2. `package.json`(ハーネス専用に縮退)

- `name` を `lastwhen` に、`description` / `keywords` をプロダクトのものに差し替える
- `type: module` は残す(設定ファイルを持たないので影響はないが、将来の Node 製補助スクリプト用)
- `scripts` は `prepare: husky` と `secretlint` だけを残す。
  **`lint` / `typecheck` / `format:check` / `test` は Flutter 用に置き換えない** ——
  npm 経由で Flutter を呼ぶ間接層は、CI からもローカルからも直接 `flutter` を叩けるので不要
- `devDependencies` は `husky` / `lint-staged` / `secretlint` /
  `@secretlint/secretlint-rule-preset-recommend` の 4 つだけにする
- `lint-staged` を Dart 向けに書き換える:

  ```json
  "lint-staged": {
    "*.dart": ["dart format"],
    "*": ["secretlint"]
  }
  ```

  **`dart analyze` は lint-staged に入れない。** Dart の解析はファイル単位ではなく
  パッケージ単位で、ステージ済みファイルのパスを渡してもプロジェクト全体を解析するため、
  コミットのたびに数秒〜十数秒を払うことになる。解析は CI の `quality` ジョブと
  PostToolUse hook(編集直後)で担保する。
- `engines.node` は残す(devcontainer / CI と揃える)

### 3. `.github/workflows/ci.yml` の `quality` ジョブ

**ジョブ名 `quality` は変えない**(ルールセットの required status check が context 名で紐づく)。
ステップを次の順に置き換える:

1. `actions/checkout@v7`
2. `subosito/flutter-action@v2`(`channel: stable`、`cache: true`)
3. `flutter pub get`
4. `dart format --output=none --set-exit-if-changed .`(フォーマット検査)
5. `flutter analyze --fatal-infos`(lint + 型チェック)
6. `flutter test`
7. Secret scan: Node をセットアップして `npx secretlint "**/*"`
   —— secretlint は npm 依存なので、このステップの直前に `actions/setup-node@v7` を置く
8. `Dependency audit` ステップは削除する(`npm audit` 相当が pub に無い。
   依存の脆弱性は Dependabot の `pub` ecosystem が担う)

### 4. `.github/dependabot.yml`(プロダクト向けプロファイルと Flutter 化を同時に行う)

- `npm` ecosystem は**残す**(ハーネス専用の 3 依存を追従させる)。ただし `weekly` → `monthly`
- `pub` ecosystem を追加(`monthly`)
- `github-actions` / `devcontainers` を `monthly` に落とす
- minor / patch をグループ化し、major は個別 PR にする
- `typescript` の ignore ルールを削除する(依存自体が消えるため)
- セキュリティ更新は interval と無関係に即時 PR が出るため、monthly でも対応は遅れない

### 5. `.claude/scripts/lint-on-edit.sh`

対象拡張子を `*.dart` だけにし、検査を `dart format --output=none --set-exit-if-changed`(該当
ファイルのみ)+ `dart analyze`(プロジェクト全体、出力は編集ファイル行だけ通し残りは件数に畳む)
に置き換える。flock による多重起動の待ち合わせと、出力を 20 行に制限する構造はそのまま残す
—— これらはスタック非依存の設計で、変える理由がない。

`ESLINT` / `TSC` の `node_modules/.bin` 直指定は、`dart` / `flutter` の PATH 解決に置き換える。
**`command -v dart` が無ければ黙って exit 0** にする(Flutter 未導入の環境で
Edit のたびにエラーを出さない = フェイルオープンを維持する)。

### 6. `.claude/settings.json`

- PostToolUse インライン hook の `npx --no-install prettier --write --ignore-unknown "$f"` を
  **`dart format "$f"`(`*.dart` のときだけ)** に置き換える。
  `|| true` のフェイルオープンは維持する
- `permissions.allow` の `npm test:*` / `npm run:*` / `npx tsc:*` / `npx vitest:*` /
  `npx eslint:*` / `npx prettier:*` を、
  `flutter:*` / `dart:*` に置き換える。`npm ci:*` は**残す**(ハーネス依存の導入に要る)
- `permissions.ask` の `npm install:*` は残す

### 7. `.claude/hooks/session-start.sh`

- リモート環境の依存インストール: `npm install` の後に `flutter pub get` を足す
  (`pubspec.yaml` があり `.dart_tool/` が無いときだけ)
- serena 規模検知の対象拡張子 `*.ts` / `*.tsx` → `*.dart`

### 8. `.devcontainer/`

- `devcontainer.json` の `name` を `lastwhen` に
- Flutter SDK を入れる。`ghcr.io/devcontainers/features/node` と
  `ghcr.io/devcontainers/features/github-cli` は**残す**
- Flutter は公式 devcontainer feature が無いため、コミュニティ feature
  `ghcr.io/jvalkeal/devcontainer-features/flutter:0` ではなく、
  **`post_create.sh` でのインストールを採る**(feature の供給元が 1 人メンテで、
  サプライチェーン上の依存を増やしたくないため)。
  `git clone -b stable --depth 1 https://github.com/flutter/flutter.git` を `/opt/flutter` に置き、
  PATH を `containerEnv` で通す
- `post_create.sh` の Playwright 判定(`package.json` に playwright があるか)は残す
  —— ハーネス専用 package.json でも誤爆しない(常にスキップされる)
- VS Code 拡張に `Dart-Code.dart-code` / `Dart-Code.flutter` を追加する

### 9. `.gitignore`

Node 専用エントリのうち `node_modules/` と各種 log は**残す**(ハーネスが npm を使うため)。
`dist/` / `build/` / `*.tsbuildinfo` / `coverage/` / `.nyc_output/` を Flutter の成果物に置き換える:

```
.dart_tool/
.packages
build/
*.g.dart の生成物は追跡する(Drift のコード生成物はコミットする方針)
ios/Pods/
ios/.symlinks/
android/.gradle/
android/local.properties
*.iml
```

**Drift の生成物(`*.g.dart` / `*.drift.dart`)は追跡する。** CI でコード生成を回さずに済み、
生成物の差分がレビューで見えるため。

### 10. Flutter プロジェクトの雛形

`flutter create` はこのフェーズでは**実行しない**。最初の P0 チケット(プロジェクト初期化)の
実装として行う。理由は 2 つ:

- `flutter create` は 100 ファイル近い雛形(ios/ android/ web/ 等)を生成し、
  キックオフのコミットに混ぜるとレビュー不能になる
- devcontainer のリビルド(Flutter SDK の導入)が先に必要で、本セッション内では完結しない

このフェーズでは `pubspec.yaml` も作らない。CI の `quality` ジョブは `pubspec.yaml` が
無い間は失敗するため、**最初の P0 チケットがマージされるまで required status check を
一時的に外すか、そのチケットで同時に満たす**。後者を採る(チケットの受け入れ条件に含める)。

## 委託禁止領域(プロジェクト固有パス)

MVP は端末内完結で認証・決済が無いため、追加するのはデータ層のみ:

| パス | 理由 |
| --- | --- |
| `lib/data/database/` | Drift のスキーマとマイグレーション定義。誤った変更がユーザーの記録を不可逆に壊す |
| `lib/data/migrations/` | 同上。マイグレーションは一度出荷すると修正できない |

## 検証

置換の完了は次で確認する(Flutter 未導入の段階では 1・2 のみ実行可能):

1. `bash .claude/scripts/check-guard-integrity.sh` が無出力
2. `npx secretlint "**/*"` が通る
3. (Flutter 導入後)`dart format` / `flutter analyze` / `flutter test` が通る
