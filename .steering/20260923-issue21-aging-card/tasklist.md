# タスクリスト: 相対経過度でカードが古びていく表示(Issue #21 / F28)

> 設計は `design.md`。判断番号はそちらを参照。**順序を守る**(リネームを先に済ませてから描画を足す)。

## フェーズ1: 土台(機械的)

- [x] 1. `ItemRow` → `ItemCard` のリネームと参照箇所の追従(判断1)。この時点で format / analyze / 既存テストが通ること(format / analyze pass。既存テストは AGENTS.md §2 に従いホストに委ねた)
- [x] 2. `lib/domain/aging_stage.dart` とユニットテストを書く(判断2・判断7-1)
- [x] 3. `ItemView` に `agingStage` を足し、テストを追記する(判断3・判断7-2)

## フェーズ2: 紙の描画

- [x] 4. `AgingPaperColors` / `AgingPalette` を `app_theme.dart` に足し、テーマに登録する。パレットのテストを書く(判断4・判断7-3)
- [x] 5. `lib/ui/widgets/aged_paper.dart`(`stableSeedOf` / `AgedPaperPainter`)とテストを書く(判断5・判断7-4)
- [x] 6. `ItemCard` に紙・テキスト色の明示・読み上げを組み込み、ウィジェットテストを書く。既存テストの追従(判断6・判断7-5・判断7-6)

## フェーズ3: ドキュメントと検証

- [x] 7. PRD / 機能設計 / UI ガイドライン §7 / 用語集を追記する(判断8)
- [x] 8. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断9)。変更した Dart 17 ファイルの format / キャッシュ内 Dart SDK による analyze --fatal-infos は pass。テストは sandbox では実行できないため、AGENTS.md §2 に従いホストに委ねた。ホスト側の検収(test-runner)で format / analyze / flutter test 289 件すべて pass を確認済み

## 申し送り(振り返りで記入)
