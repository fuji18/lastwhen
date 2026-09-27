# タスクリスト: 基準間隔にもとづく通知(F11 / Issue #51)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。未完了タスク(`[ ]`)を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ。`- [x] ~~タスク名~~(理由: ...)` の形で残す
- `design.md` に無い設計判断が必要になったら、推測せず止めて報告する

---

## フェーズ0: 計画時に司令塔が実施済み

- [x] `docs/product-requirements.md` の F9 / F10 取り下げ・F11 の前提を F27 に・権限の行
- [x] `docs/architecture.md` の依存表・ユーザー設定・拡張表・`integration_test` の再検討結果
- [x] `docs/functional-design.md`「通知(F11 / #51)」節・セキュリティの権限行
- [x] `docs/repository-structure.md` の新規ファイルと data の依存

## フェーズ1: 依存と端末設定

- [ ] `flutter pub add` で 2 つの依存を追加し、pubspec にコメントを付ける(design.md §0-1)
- [ ] `android/app/build.gradle.kts` に desugaring を追加(§0-2)
- [ ] `AndroidManifest.xml` に権限 2 つと receiver 2 つを追加(§0-3)
- [ ] `res/drawable/ic_stat_notification.xml` を追加(§0-4)
- [ ] `ios/Runner/AppDelegate.swift` に委譲先の設定を追加(§0-5)

## フェーズ2: ドメイン層

- [ ] `lib/domain/notification_plan.dart` を新規作成(§1)
- [ ] `lib/domain/notification_scheduler.dart` を新規作成(§2)
- [ ] `test/domain/notification_plan_test.dart` を新規作成(§6-2)

## フェーズ3: データ層・状態管理層・起動

- [ ] `lib/data/local_notification_scheduler.dart` を新規作成(§3)
- [ ] `lib/state/providers.dart` に `notificationSchedulerProvider` を追加(§4-3)
- [ ] `lib/state/notification_sync.dart` を新規作成(§4)
- [ ] `lib/main.dart` で同期を起動(§5)
- [ ] `test/support/fake_notification_scheduler.dart` を新規作成(§6-1)
- [ ] `test/state/notification_sync_test.dart` を新規作成(§6-3)

## フェーズ4: 品質チェック

- [ ] `dart format --output=none --set-exit-if-changed .` が通る
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る
- [ ] `flutter build apk --debug` が通る(Android SDK が devcontainer に無ければ理由を書いてスキップ)

## フェーズ5: 検収での追加
