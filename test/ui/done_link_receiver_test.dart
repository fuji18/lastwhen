import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/ui/done_link_receiver.dart';

RouteInformation _route(String url) => RouteInformation(uri: Uri.parse(url));

void main() {
  late List<ItemId?> received;
  setUp(() => received = []);

  test('初期ルートのリンクは attach 時に 1 回渡る', () {
    DoneLinkReceiver(initialRoute: 'lastwhen://done/abc').attach(received.add);
    expect(received, [ItemId('abc')]);
  });

  test('初期ルートが / や null なら何も渡らない', () {
    DoneLinkReceiver(initialRoute: '/').attach(received.add);
    DoneLinkReceiver().attach(received.add);
    expect(received, isEmpty);
  });

  test('形式が不正なリンクは null が渡る', () {
    DoneLinkReceiver(initialRoute: 'lastwhen://other/x').attach(received.add);
    expect(received, [null]);
  });

  test('attach 済みなら push されたリンクが即座に渡り true を返す', () async {
    final receiver = DoneLinkReceiver()..attach(received.add);
    expect(
      await receiver.didPushRouteInformation(_route('lastwhen://done/x')),
      isTrue,
    );
    expect(received, [ItemId('x')]);
  });

  test('attach 前に push されたリンクは溜まり、attach 時に順に渡る', () async {
    final receiver = DoneLinkReceiver();
    await receiver.didPushRouteInformation(_route('lastwhen://done/a'));
    await receiver.didPushRouteInformation(_route('lastwhen://done/b'));
    expect(received, isEmpty);
    receiver.attach(received.add);
    expect(received, [ItemId('a'), ItemId('b')]);
  });

  test('他のリンクは false を返し、何も渡らない', () async {
    final receiver = DoneLinkReceiver()..attach(received.add);
    expect(
      await receiver.didPushRouteInformation(_route('https://example.com')),
      isFalse,
    );
    expect(received, isEmpty);
  });

  test('detach 後の push は溜まる', () async {
    final receiver = DoneLinkReceiver()
      ..attach(received.add)
      ..detach();
    await receiver.didPushRouteInformation(_route('lastwhen://done/x'));
    expect(received, isEmpty);
    receiver.attach(received.add);
    expect(received, [ItemId('x')]);
  });
}
