import 'package:flutter/widgets.dart';

import '../domain/done_link.dart';
import '../domain/item.dart';

/// 記録のリンク(F32)を受け取る。項目 ID が null のリンクは「形式が不正」を表す(判断5)。
typedef DoneLinkHandler = void Function(ItemId? id);

/// `lastwhen://` のリンクを OS から受け取り、[attach] した処理へ渡す(F32)。
///
/// **`main()` で `runApp` の前に `WidgetsBinding.instance.addObserver` すること**(判断3)。
/// `WidgetsApp` より後に登録すると、リンクが `pushNamed` されてエラーになる。
/// 処理が [attach] される前に届いたリンク(コールドスタートの初期ルートを含む)は溜めておき、
/// [attach] の時点で届いた順に渡す。
class DoneLinkReceiver with WidgetsBindingObserver {
  /// [initialRoute] はコールドスタートの初期ルート(`PlatformDispatcher.defaultRouteName`)。
  DoneLinkReceiver({String? initialRoute}) {
    final uri = initialRoute == null ? null : Uri.tryParse(initialRoute);
    if (uri != null && isAppLink(uri)) {
      _pending.add(parseDoneLink(uri));
    }
  }

  final List<ItemId?> _pending = [];
  DoneLinkHandler? _handler;

  /// リンクの処理を登録し、溜まっていたリンクを渡す。
  void attach(DoneLinkHandler handler) {
    _handler = handler;
    final pending = List<ItemId?>.of(_pending);
    _pending.clear();
    for (final id in pending) {
      handler(id);
    }
  }

  /// 処理の登録を外す。以降のリンクは次の [attach] まで溜める。
  void detach() {
    _handler = null;
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    if (!isAppLink(uri)) {
      return false;
    }
    final id = parseDoneLink(uri);
    final handler = _handler;
    if (handler == null) {
      _pending.add(id);
    } else {
      handler(id);
    }
    return true;
  }
}
