import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/notification_sync.dart';
import 'ui/done_link_receiver.dart';
import 'ui/theme/app_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 同梱フォントのライセンスを一覧に載せる(#56)
  AppFonts.registerLicenses();
  final container = ProviderContainer();
  // 通知の予約を項目の変化に追従させる(F11 / #51)。App では起動しない(design.md 判断 J)
  container.read(notificationSyncProvider);
  // 記録のリンク(F32)。WidgetsApp より先に登録する(design.md 判断3)。
  final doneLinks = DoneLinkReceiver(
    initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );
  WidgetsBinding.instance.addObserver(doneLinks);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: App(doneLinks: doneLinks),
    ),
  );
}
