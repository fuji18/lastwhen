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

- [ ] `pubspec.yaml` の `flutter:` に `fonts:` と `assets:` を追加する(§2)
- [ ] `lib/ui/theme/app_fonts.dart` を新規作成する(§3)
- [ ] `lib/ui/theme/app_theme.dart` の `ThemeData` に `fontFamily` を渡し、doc コメントを更新する(§4)
- [ ] `lib/main.dart` で `AppFonts.registerLicenses()` を呼ぶ(§5)

## フェーズ2: テスト

- [ ] `test/support/app_font.dart` を新規作成する(§6-1)
- [ ] `test/ui/theme/app_fonts_test.dart` を新規作成する(§6-2)
- [ ] `test/ui/accessibility_test.dart` の `main()` 冒頭で同梱フォントを読み込む(§6-3)

## フェーズ3: 検証

- [ ] `lib/` に `fontFamily` の指定が `lib/ui/theme/` 以外に無いことを grep で確認する(§7)
- [ ] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` が通る

## フェーズ4: 司令塔(実装後)

- [ ] 変更後の release APK サイズを計測し、増加分を PR に記載する

---

## 実装後の振り返り

(全タスク完了後に司令塔が記入する)
