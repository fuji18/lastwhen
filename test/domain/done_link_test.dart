import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/done_link.dart';
import 'package:lastwhen/domain/item.dart';

void main() {
  test('doneLinkFor は lastwhen://done/<id> を作る', () {
    expect(
      doneLinkFor(ItemId('abc-123')).toString(),
      'lastwhen://done/abc-123',
    );
  });

  test('作ったリンクを parseDoneLink で ID に戻せる', () {
    final id = ItemId('abc-123');
    expect(parseDoneLink(doneLinkFor(id)), id);
  });

  test('末尾のスラッシュは無視する', () {
    expect(parseDoneLink(Uri.parse('lastwhen://done/abc/')), ItemId('abc'));
  });

  test('形式が違うリンクは null', () {
    for (final text in [
      'lastwhen://done',
      'lastwhen://done/',
      'lastwhen://done/a/b',
      'lastwhen://other/abc',
      'https://done/abc',
    ]) {
      expect(parseDoneLink(Uri.parse(text)), isNull, reason: text);
    }
  });

  test('isAppLink はスキームだけを見る', () {
    expect(isAppLink(Uri.parse('lastwhen://x')), isTrue);
    expect(isAppLink(Uri.parse('https://example.com')), isFalse);
  });
}
