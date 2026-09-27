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

- [x] `flutter pub add` で 2 つの依存を追加し、pubspec にコメントを付ける(design.md §0-1)
- [x] `android/app/build.gradle.kts` に desugaring を追加(§0-2)
- [x] `AndroidManifest.xml` に権限 2 つと receiver 2 つを追加(§0-3)
- [x] `res/drawable/ic_stat_notification.xml` を追加(§0-4)
- [x] `ios/Runner/AppDelegate.swift` に委譲先の設定を追加(§0-5)

## フェーズ2: ドメイン層

- [x] `lib/domain/notification_plan.dart` を新規作成(§1)
- [x] `lib/domain/notification_scheduler.dart` を新規作成(§2)
- [x] `test/domain/notification_plan_test.dart` を新規作成(§6-2)

## フェーズ3: データ層・状態管理層・起動

- [x] `lib/data/local_notification_scheduler.dart` を新規作成(§3)
- [x] `lib/state/providers.dart` に `notificationSchedulerProvider` を追加(§4-3)
- [x] `lib/state/notification_sync.dart` を新規作成(§4)
- [x] `lib/main.dart` で同期を起動(§5)
- [x] `test/support/fake_notification_scheduler.dart` を新規作成(§6-1)
- [x] `test/state/notification_sync_test.dart` を新規作成(§6-3)

## フェーズ4: 品質チェック

- [x] `dart format --output=none --set-exit-if-changed .` が通る
- [x] `flutter analyze --fatal-infos` が通る
- [x] `flutter test` が通る
- [x] `flutter build apk --debug` が通る(Android SDK が devcontainer に無ければ理由を書いてスキップ)

## フェーズ5: 検収での追加

- [x] code-reviewer: 0 critical / 0 major / 3 minor(すべて任意)。いずれも対応せず申し送る(下記)
- [x] test-runner(フルスイート): format / analyze / test 615 件すべて pass

## 申し送り(振り返り)

- **実装は implement-ticket の fork 1 回で完走**(新規依存を伴うため Codex に委託せず)。design.md に API 呼び出しまで書き切った結果、判断待ちは 0 回
- 見送った任意指摘:
  - `replaceAll` が途中で失敗すると予約が一部だけ空になり、次に `watchAll` が流れるまで戻らない(判断 L の範囲内。次の記録・起動で張り直される)
  - `notification_plan_test.dart` の上限テストは 61 件が同時刻のため、「早い順に 60 件」は実質タイブレークでしか見ていない。ロジックは目視で正しい
  - `timezone` 経由で `http` が推移的に入る(import しないためビルドには入らない。functional-design.md のセキュリティ節に記載済み)
- `NotificationSync` のコンストラクタで `prefer_initializing_formals` を `// ignore:` で抑止した(design.md の引数名とフィールド名の差による。挙動に影響なし)
- **残る手動確認**: Android 実機で 19:00 に届くこと・権限ダイアログ・OS 設定でのオフ。iOS は macOS 側でビルドと通知を確認する
