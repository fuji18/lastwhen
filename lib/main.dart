import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/notification_sync.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // 通知の予約を項目の変化に追従させる(F11 / #51)。App では起動しない(design.md 判断 J)
  container.read(notificationSyncProvider);
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
