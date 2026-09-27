# タスクリスト: 丸ゴシック系フォントを同梱する(Issue #56)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。未完了タスク(`[ ]`)を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ。`- [x] ~~タスク名~~(理由: ...)` の形で残す
- `design.md` に無い設計判断が必要になったら、推測せず止めて報告する

---

## フェーズ0: 計画時に司令塔が実施済み

- [x] 書体とウェイトを決める(Zen Maru Gothic / Regular・Medium・Bold / サブセット化しない)
- [x] フォント 3 ファイルと `ZenMaruGothic-OFL.txt` を `assets/fonts/` に取得(design.md §1)
- [x] `docs/architecture.md`「同梱フォント」節と `docs/ui-design-guidelines.md` §7 の「書体」行を追記
- [x] 変更前(`origin/main`)の release APK サイズを計測

## フェーズ1: 同梱とテーマ

- [x] `pubspec.yaml` の `flutter:` に `fonts:` と `assets:` を追加する(§2)
- [x] `lib/ui/theme/app_fonts.dart` を新規作成する(§3)
- [x] `lib/ui/theme/app_theme.dart` の `ThemeData` に `fontFamily` を渡し、doc コメントを更新する(§4)
- [x] `lib/main.dart` で `AppFonts.registerLicenses()` を呼ぶ(§5)

## フェーズ2: テスト

- [x] `test/support/app_font.dart` を新規作成する(§6-1)
- [x] `test/ui/theme/app_fonts_test.dart` を新規作成する(§6-2)
- [x] `test/ui/accessibility_test.dart` の `main()` 冒頭で同梱フォントを読み込む(§6-3)

## フェーズ3: 検証

- [x] `lib/` に `fontFamily` の指定が `lib/ui/theme/` 以外に無いことを grep で確認する(§7)
- [x] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` が通る

## フェーズ4: 司令塔(実装後)

- [x] 変更後の release APK サイズを計測し、増加分を PR に記載する(73,219,962 → 79,704,978 bytes / +6,485,016 bytes ≈ +6.5MB)

---

## 実装後の振り返り

- 実装完了日: 2026-09-27
- 計画との差分: ほぼ無し。fork は `app_fonts_test.dart` に `package:flutter/foundation.dart` の import を補った(design.md §6-2 の列挙に含めていたもの)。判断待ち 0・往復 1 回
- APK(`flutter build apk --release`、3 ABI 同梱の fat APK): 73,219,962 → 79,704,978 bytes(**+6,485,016 bytes ≈ +6.5MB**)。TTF 3 本の合計 11.4MB が APK の圧縮で約 57% に縮んだ。フォントは ABI 非依存なので、AAB で端末ごとに配信しても増分はほぼ同じ
- 200% のレイアウト検査は、`accessibility_test.dart` で実フォントを読み込んでも既存の期待値のまま全件通った
- 申し送り:
  - **アプリにライセンス一覧の入口が無い。** フォントに限らず、依存パッケージ(drift / riverpod 等)のライセンスも現状アプリから見られない。マイページ等の入口を作るときに `showLicensePage` を置く(別チケット候補)
  - サイズを削りたくなったら、次の一手はサブセット化ではなく Medium の削除(500 は 400 に落ちる)。サブセット化は自由入力の項目名で字面が混ざるため採らない
