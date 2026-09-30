# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。理由なくスキップしない
- スキップが許されるのは技術的理由のみ。`- [x] ~~タスク名~~(理由)` の形で残す
- **`design.md` に書かれていない設計判断が要ったら、その場で停止して報告する**
- `assets/branding/logo_wordmark.png` は司令塔が用意済み。作り直さない・加工しない

---

## フェーズ0: 素材(司令塔が実施済み)

- [x] `assets/branding/logo_wordmark.png` を作る(design 判断1)

## フェーズ1: 実装

- [x] `lib/ui/widgets/app_logo.dart` を新規作成(design §1)
- [x] `lib/ui/screens/item_list_screen.dart` の AppBar タイトルを `AppLogo` に(design §2)
- [x] `pubspec.yaml` にアセットを登録(design §3)

## フェーズ2: テスト

- [x] `test/ui/widgets/app_logo_test.dart` にテスト A〜D(design §4)
- [x] `test/ui/item_list_screen_test.dart` にテスト E・F
- [x] `test/ui/accessibility_test.dart` にテスト G

## フェーズ3: docs

- [x] `docs/repository-structure.md` の `assets/branding/` 行(design §5)
- [x] `docs/architecture.md` に「同梱画像(#92)」節
- [x] `docs/functional-design.md` の AppBar の行の直後に 1 行

## フェーズ3.5: 追補(Codex 委託 1 回目の検収で判明)

- [x] `lib/ui/widgets/app_logo.dart` に `appLogoAspectRatio` と `width` を足す(design 判断10)
- [x] テスト D・F の `SemanticsHandle` を本文末尾で破棄する(design 判断11)
- [x] テスト C に幅の検査を足す(design 判断12)
- [x] `docs/architecture.md`「同梱画像(#92)」節の箇条書きの末尾に 1 行足す: `- 読み込み前から幅を確保するため、`AppLogo` は画像の縦横比(`appLogoAspectRatio`)で幅も固定する。画像を差し替えたらこの値も直す`

## フェーズ4: 自己検証

- [x] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / 変更したテストファイルの `flutter test` が通る

  - Codex 検証: 変更した Dart 5 ファイルの直接 SDK による analyze --fatal-infos と format --output=none --set-exit-if-changed は pass。git diff --check も pass。
  - AGENTS.md に従い全体フォーマットと Flutter ラッパーは使用しない。関連テストは sandbox では実行できないためホストに委ねた。ホストで変更したテスト 3 ファイルを実行後、この項目を完了にする。
  - ホスト検証: `dart format` / `flutter analyze --fatal-infos`(変更 5 ファイル)は問題なし。`flutter test test/ui/widgets/app_logo_test.dart test/ui/item_list_screen_test.dart test/ui/accessibility_test.dart` は 77 件全て pass。
