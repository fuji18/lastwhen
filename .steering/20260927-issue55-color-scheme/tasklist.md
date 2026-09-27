# タスクリスト: 配色を画面イメージに合わせる(Issue #55)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。未完了タスク(`[ ]`)を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ。`- [x] ~~タスク名~~(理由: ...)` の形で残す
- `design.md` に無い設計判断が必要になったら、推測せず止めて報告する

---

## フェーズ0: 計画時に司令塔が実施済み

- [x] 画面イメージから色を採取し、コントラストを実測して値を確定(design.md §1)
- [x] `docs/ui-design-guidelines.md` §7 のデザイントークン行を更新
- [x] `docs/functional-design.md`「色の使い方」に配色表を追記

## フェーズ1: テーマ

- [x] `lib/ui/theme/app_theme.dart` を design.md §2 のとおり書き換える(シード色・`_lightScheme` / `_darkScheme`・FAB テーマ・doc コメント)

## フェーズ2: テスト

- [x] `test/widget_test.dart` の「同じ 1 つのシード色から生成」テストを §3-1 のとおり差し替える
- [x] `test/ui/accessibility_test.dart` のコントラストのペアを §3-2 のとおり更新する
- [x] `test/ui/theme/app_theme_test.dart` を新規作成する(§3-3)

## フェーズ3: 検証

- [x] `lib/` に生の色(`Color(0x` / `Colors.`)が `lib/ui/theme/app_theme.dart` 以外に無いことを grep で確認する(§4)
- [x] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` が通る
