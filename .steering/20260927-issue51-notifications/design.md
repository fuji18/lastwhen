# 設計: 基準間隔にもとづく通知(F11 / Issue #51)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れない。** スキーマは変えない
> - **依存の追加はこの設計の §0 の 2 つだけ**。それ以外を足さない
> - **`docs/` は司令塔が更新済み**(`functional-design.md`「通知(F11 / #51)」節が仕様の正)。実装者は `docs/` を触らない
> - 文言は下の表記どおりに書く(用語集: 項目 / 記録する / 経過日数)

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | しきい値は相対経過度 **1.5**(`AgingStage.aged` の下端)。定数で持ち、`agingStageOf(しきい値) == aged` をテストで固定する | ユーザー判断 |
| B | 通知時刻は、しきい値に達した暦日の**ローカル 19:00** | ユーザー判断 |
| C | オフは OS の通知設定に任せる。**アプリ内に設定・保存先を持たない** | ユーザー判断。スキーマ変更を避ける |
| D | 予約は OS に張る(`zonedSchedule`)。`AndroidScheduleMode.inexactAllowWhileIdle`(正確なアラーム権限を要さない。「控えめ」なので数分のずれは許容) | アプリを開かない期間でも鳴らす |
| E | `watchAll()` が流れるたびに **未配信の予約を全部取り消し(`cancelAllPendingNotifications`)→ 計画を全部張り直す** | 記録・取り消し・編集・削除・過去日付すべてに追従。差分管理を持たない |
| F | 予定時刻が現在以前の項目は計画に入れない | 過ぎた予定を後から鳴らさない = 1 項目 1 回 |
| G | 通知 ID は項目 ID 文字列の **FNV-1a 32bit を `& 0x7fffffff`** した値 | 張り直しで同じ項目は同じ ID |
| H | 予約は予定時刻の早い順に最大 **60 件** | iOS の予約上限 64 |
| I | 権限は、計画が **1 件以上になった最初の同期で 1 回だけ**要求する(`NotificationSync` のインスタンスにつき 1 回)。**結果にかかわらず予約は張る** | 初回起動で要求しない。後から OS で許可すれば鳴る |
| J | 同期は `main()` で起動する(`App` では起動しない) | `App` を pump する既存ウィジェットテストがプラグインに触れないようにする |
| K | 通知の文言は `state/` で組み立てる。`NotificationScheduler` は組み立て済みの文字列を受け取るだけ | `domain/` に表示文字列を置かず、`data/` は `ui/` を参照できないため |
| L | 同期の失敗(プラグインの例外)は握りつぶし、`dart:developer` の `log` に残す。アプリの他機能に波及させない | 権限拒否・プラグイン未初期化でもアプリは動く |
| M | `integration_test` は導入しない。`data/` の実装(プラグイン呼び出し)はユニットテストしない | docs/architecture.md に記載済み。OS 配信は実機で手動確認 |

---

## 0. 依存の追加と端末設定

### 0-1. pubspec

```bash
flutter pub add flutter_local_notifications:^22.3.1 timezone:^0.11.1
```

`dependencies:` の中で、既存の書き方に合わせて 1 行コメントを上に付ける:

- `flutter_local_notifications`: `# ローカル通知の予約(F11 / #51)`
- `timezone`: `# zonedSchedule が要求する TZDateTime(#51)`

### 0-2. Android(`android/app/build.gradle.kts`)

`compileOptions` に `isCoreLibraryDesugaringEnabled = true` を足し、ファイル末尾(`flutter { ... }` の後)に次を足す
(既に `dependencies { }` ブロックがあればその中に 1 行足す):

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

`multiDexEnabled` は足さない(minSdk 26 で不要)。

### 0-3. Android(`android/app/src/main/AndroidManifest.xml`)

`<manifest>` 直下(`<application>` の前)に:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

`<application>` の中(`flutterEmbedding` の meta-data の前)に:

```xml
<!-- ローカル通知の予約(F11 / #51)。再起動・更新後も予約を復元する -->
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

`INTERNET` 権限は足さない。

### 0-4. Android の通知アイコン(`android/app/src/main/res/drawable/ic_stat_notification.xml`)

ステータスバー用の単色アイコン(Material Icons「history」)。ランチャーアイコンは多色で白く潰れるため使わない:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- 通知のステータスバー用アイコン(F11 / #51)。単色で描く(Android は色を無視して白で塗る) -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M13,3c-4.97,0 -9,4.03 -9,9L1,12l3.89,3.89 0.07,0.14L9,12L6,12c0,-3.87 3.13,-7 7,-7s7,3.13 7,7 -3.13,7 -7,7c-1.93,0 -3.68,-0.79 -4.94,-2.06l-1.42,1.42C8.27,19.99 10.51,21 13,21c4.97,0 9,-4.03 9,-9s-4.03,-9 -9,-9zM12,8v5l4.28,2.54 0.72,-1.21 -3.5,-2.08L13.5,8L12,8z" />
</vector>
```

### 0-5. iOS(`ios/Runner/AppDelegate.swift`)

`import UserNotifications` を足し、`didFinishLaunchingWithOptions` の `return` の前に 1 行足す(アプリが前面にあるときも通知を出すため):

```swift
    // ローカル通知(F11 / #51)。前面表示のときも通知を出すため、プラグインに委譲先を渡す
    UNUserNotificationCenter.current().delegate = self
```

iOS のビルドは devcontainer でできない。構文だけ上のとおりに書く(確認は macOS 側)。

---

## 1. `lib/domain/notification_plan.dart`(新規・純関数)

import は `aging_stage.dart` を使わない(定数の整合はテストで見る)。`baseline_interval.dart` と `item.dart` を import する。

```dart
/// 通知する相対経過度のしきい値。経年ステージ「経過」(aged)の下端と同じ。
const double notificationRelativeElapsedThreshold = 1.5;

/// 通知する時刻(ローカルの時)。
const int notificationHourOfDay = 19;

/// 一度に予約する通知の上限。iOS の予約上限(64)に余裕を残す。
const int maxScheduledNotifications = 60;

/// 予約する通知 1 件。
final class PlannedNotification {
  const PlannedNotification({
    required this.itemId,
    required this.itemName,
    required this.elapsedDays,
    required this.fireAt,
  });
  final ItemId itemId;
  final String itemName;
  /// 通知する暦日の経過日数(最終実施日の暦日からの差)。
  final int elapsedDays;
  /// 通知する時刻(UTC)。
  final DateTime fireAt;
  // == / hashCode を全フィールドで実装する(テストの比較用)
}
```

### 1-1. `int daysUntilNotification(double baselineIntervalDays)`

`n / baseline >= threshold` を満たす最小の整数 n(1 以上)を返す。

```dart
var n = (notificationRelativeElapsedThreshold * baselineIntervalDays).ceil();
// 浮動小数の誤差で 1 つ大きくなった場合の補正
while (n > 1 && (n - 1) / baselineIntervalDays >= notificationRelativeElapsedThreshold) { n--; }
return n < 1 ? 1 : n;
```

公開関数にする(テストで直接確かめる)。

### 1-2. `List<PlannedNotification> planNotifications(List<Item> items, {required DateTime now})`

各項目について:

1. `item.lastDoneAt` が null → 除外
2. `baselineIntervalDays(item.recentDoneAts)` が null → 除外
3. `n = daysUntilNotification(baseline)`
4. `final last = item.lastDoneAt!.toLocal();`
   `final fireAt = DateTime(last.year, last.month, last.day + n, notificationHourOfDay).toUtc();`
   (ローカルのコンストラクタで日を足す。夏時間でも暦日どおりになる)
5. `!fireAt.isAfter(now)` → 除外
6. `PlannedNotification(itemId: item.id, itemName: item.name, elapsedDays: n, fireAt: fireAt)`

最後に `fireAt` の昇順(同時刻なら `itemId.value` の昇順)に並べ、先頭 `maxScheduledNotifications` 件を返す。

### 1-3. `int notificationIdOf(ItemId id)`

```dart
/// 項目 ID から通知 ID を導く。FNV-1a(32bit)の下位 31bit。
int notificationIdOf(ItemId id) {
  var hash = 0x811c9dc5;
  for (final unit in id.value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
```

---

## 2. `lib/domain/notification_scheduler.dart`(新規・インターフェース)

```dart
/// OS に張る通知 1 件(文言は組み立て済み)。
final class ScheduledNotification {
  const ScheduledNotification({required this.id, required this.title, required this.body, required this.fireAt});
  final int id;
  final String title;
  final String body;
  /// UTC。
  final DateTime fireAt;
  // == / hashCode を全フィールドで実装する
}

/// 通知の予約。実装はデータレイヤーに置く(`ItemRepository` と同じ依存性逆転)。
abstract interface class NotificationScheduler {
  /// 通知の権限を要求する。許可されたら true。要求できない環境では false。
  Future<bool> requestPermission();

  /// 未配信の予約をすべて取り消し、[notifications] を予約し直す。
  Future<void> replaceAll(List<ScheduledNotification> notifications);
}
```

---

## 3. `lib/data/local_notification_scheduler.dart`(新規・実装)

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
```

- `final class LocalNotificationScheduler implements NotificationScheduler`
- コンストラクタ: `LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})`、未指定なら `FlutterLocalNotificationsPlugin()`
- `Future<void>? _initializing;` と `Future<void> _ensureInitialized() => _initializing ??= _initialize();`
- `_initialize()`:
  - `tz_data.initializeTimeZones();`
  - `await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notification'), iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)));`
- `requestPermission()`:
  - `await _ensureInitialized();`
  - Android: `_plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()` が非 null なら `requestNotificationsPermission()` の結果(`?? false`)
  - iOS: `IOSFlutterLocalNotificationsPlugin` が非 null なら `requestPermissions(alert: true, sound: true)` の結果(`?? false`)。バッジは要求しない
  - どちらも null なら false
- `replaceAll(notifications)`:
  - `await _ensureInitialized();`
  - `await _plugin.cancelAllPendingNotifications();`
  - 各件に `await _plugin.zonedSchedule(id: n.id, title: n.title, body: n.body, scheduledDate: tz.TZDateTime.from(n.fireAt, tz.UTC), notificationDetails: _details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);`
- `_details`(`static const NotificationDetails`):
  - android: `AndroidNotificationDetails('aged_items', 'いつもより間が空いた項目', channelDescription: 'いつもより間が空いた項目を 1 回だけ知らせます', importance: Importance.defaultImportance, priority: Priority.defaultPriority)`
  - iOS: `DarwinNotificationDetails(presentBadge: false)`

API の名前・引数がこのとおりでない場合(22.x で変わっている等)は、pub キャッシュ内の
`flutter_local_notifications` のソースを見て**同じ意味の API に合わせる**。同じ意味の API が無ければ停止して報告する。

---

## 4. `lib/state/notification_sync.dart`(新規)

### 4-1. 文言

```dart
/// 通知の本文。[elapsedDays] は通知する暦日の経過日数。
String notificationBodyOf(int elapsedDays) => '最後：$elapsedDays日前。いつもより間が空いているかも。';
```

`最後：` のコロンは全角(詳細シートと同じ)。タイトルは項目名そのまま。

### 4-2. `NotificationSync`

```dart
final class NotificationSync {
  NotificationSync({required NotificationScheduler scheduler, required Clock clock});

  /// 項目の一覧が変わったときに呼ぶ。直列に処理し、処理中に来た分は最新の 1 回だけにまとめる。
  /// 返す Future は、その時点で溜まっている分を処理し終えたら完了する。
  Future<void> onItemsChanged(List<Item> items);
}
```

実装:

- フィールド: `List<Item>? _pending; Future<void>? _draining; bool _permissionRequested = false;`
- `onItemsChanged(items)`: `_pending = items; return _draining ??= _drain().whenComplete(() => _draining = null);`
- `_drain()`: `while (_pending != null) { final items = _pending!; _pending = null; await _syncOnce(items); }`
- `_syncOnce(items)`: 全体を `try { ... } catch (error, stackTrace) { developer.log('通知の予約に失敗しました', error: error, stackTrace: stackTrace, name: 'NotificationSync'); }` で包む(判断 L。**項目名をログに出さない**)
  1. `final plan = planNotifications(items, now: _clock.now());`
  2. `if (plan.isNotEmpty && !_permissionRequested) { _permissionRequested = true; await _scheduler.requestPermission(); }`(結果は使わない。判断 I)
  3. `await _scheduler.replaceAll([for (final p in plan) ScheduledNotification(id: notificationIdOf(p.itemId), title: p.itemName, body: notificationBodyOf(p.elapsedDays), fireAt: p.fireAt)]);`

`import 'dart:developer' as developer;` を使う(`package:flutter/` は state で禁止)。

### 4-3. Provider

`lib/state/providers.dart` に足す(`LocalNotificationScheduler` を import):

```dart
/// 通知の予約。テストは `FakeNotificationScheduler` に差し替える。
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => LocalNotificationScheduler(),
);
```

`notification_sync.dart` に:

```dart
/// 項目の一覧を購読し、変わるたびに通知の予約を張り直す。**`main()` で 1 度 read して起動する。**
final notificationSyncProvider = Provider<NotificationSync>((ref) {
  final sync = NotificationSync(
    scheduler: ref.watch(notificationSchedulerProvider),
    clock: ref.watch(clockProvider),
  );
  final subscription = ref.watch(itemRepositoryProvider).watchAll().listen(
    sync.onItemsChanged,
    onError: (Object error, StackTrace stackTrace) => developer.log('項目の購読に失敗しました', error: error, stackTrace: stackTrace, name: 'NotificationSync'),
  );
  ref.onDispose(subscription.cancel);
  return sync;
});
```

---

## 5. `lib/main.dart`

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // 通知の予約を項目の変化に追従させる(F11 / #51)。App では起動しない(design.md 判断 J)
  container.read(notificationSyncProvider);
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
```

---

## 6. テスト

### 6-1. `test/support/fake_notification_scheduler.dart`(新規)

- `requestPermissionCount`(int)、`permissionResult`(bool、既定 true)、`replaced`(`List<List<ScheduledNotification>>`、呼ばれるたびに追加)、`failWith`(Object?、非 null なら `replaceAll` で throw)
- `get last => replaced.last`

### 6-2. `test/domain/notification_plan_test.dart`(新規)

時刻は `DateTime(2026, 9, 1, 8).toUtc()` のように**ローカルで組んで UTC に直す**(実行環境のタイムゾーンに依存させない)。

| テスト | 期待 |
| --- | --- |
| しきい値は aged の下端 | `agingStageOf(notificationRelativeElapsedThreshold) == AgingStage.aged` かつ `agingStageOf(notificationRelativeElapsedThreshold - 0.001) == AgingStage.dueSoon` |
| `daysUntilNotification` | 1→2、2→3、4→6、5→8、6.5→10、7→11、30→45 |
| 各 n で相対経過度が初めて 1.5 以上 | 上の各値で `n / b >= 1.5` かつ `(n - 1) / b < 1.5` |
| 未実施は除外 | lastDoneAt null → 空 |
| 記録 1 件は除外 | recentDoneAts 1 件 → 空 |
| 同じ暦日に 2 件は除外 | 基準間隔 null → 空 |
| 基準間隔 7 日 | 9/1 08:00 と 8/25 に記録 → fireAt == `DateTime(2026, 9, 12, 19).toUtc()`、elapsedDays 11 |
| 最終実施が夜でも暦日で数える | 9/1 23:30 最終 → 同じく 9/12 19:00 |
| 予定時刻を過ぎたら除外 | now = 9/12 19:00 ちょうど → 空。18:59 → 1 件 |
| 月をまたぐ | 最終 1/28、基準 4 日 → 2/3 19:00 |
| 並びと上限 | 61 件の項目 → 60 件、fireAt の昇順 |
| 同時刻は itemId 順 | fireAt 同じ 2 件 → itemId.value の昇順 |
| `notificationIdOf` | 同じ ID は同じ値、0 以上 0x7fffffff 以下、`ItemId('a')` の値が FNV-1a の期待値 `0xe40c292c & 0x7fffffff` と一致 |

### 6-3. `test/state/notification_sync_test.dart`(新規)

`NotificationSync` を直接作る(Provider を介さない)テストと、`ProviderContainer`(`itemRepositoryProvider` を `FakeItemRepository`、`clockProvider` を `FakeClock`、`notificationSchedulerProvider` を Fake に override)で `notificationSyncProvider` を read するテストの両方:

| テスト | 期待 |
| --- | --- |
| 計画が空なら権限を要求しない | 未実施のみ → `requestPermissionCount == 0`、`replaceAll([])` は呼ばれる |
| 計画が 1 件以上で権限を 1 回だけ要求 | 2 回同期しても `requestPermissionCount == 1` |
| 拒否されても予約は張る | `permissionResult = false` → `last.length == 1` |
| 文言 | title = 項目名、body = `最後：11日前。いつもより間が空いているかも。` |
| ID | `id == notificationIdOf(item.id)` |
| 例外を外に出さない | `failWith` 設定 → `onItemsChanged` が正常完了 |
| まとめる | 1 回目の完了前に 2・3 回目を呼ぶ → 最後の items で必ず張られ、呼び出し回数は 3 未満 |
| Provider 経由: 記録で張り直す | FakeItemRepository で markDone(2 回目の記録)すると `replaced` が増え、その項目の予約が入る |
| Provider 経由: 削除で消える | delete 後の `last` にその ID が無い |
| Provider 経由: 編集で文言が変わる | edit で名前を変えると `last` の title が新しい名前 |

Provider 経由のテストで非同期の完了を待つには、`await Future<void>.delayed(Duration.zero)` を必要回数挟むか、`container.read(notificationSyncProvider)` を取っておいて `pumpEventQueue()` を使う(`flutter_test` にある)。

### 6-4. 既存テストへの影響

`App` を pump するテストは `main()` を通らないため、override の追加は不要。`test/architecture/layer_dependency_test.dart` は変えない(新ファイルが規則に従っていれば通る)。
