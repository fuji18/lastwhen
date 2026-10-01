import 'item.dart';

/// 記録のリンク(F32)のスキーム。Android の intent-filter と揃える。
const String doneLinkScheme = 'lastwhen';

/// 記録のリンクの host(動作名)。
const String doneLinkHost = 'done';

/// [id] を記録するリンク(`lastwhen://done/<id>`)を作る。NFC タグに書き込む URL。
Uri doneLinkFor(ItemId id) =>
    Uri(scheme: doneLinkScheme, host: doneLinkHost, pathSegments: [id.value]);

/// このアプリ宛てのリンクか(スキームだけを見る)。形式の正否は問わない。
bool isAppLink(Uri uri) => uri.scheme == doneLinkScheme;

/// 記録のリンクから項目 ID を取り出す。形式が違えば null(判断5)。
///
/// 末尾のスラッシュ(空のパス段)は無視する。クエリ・フラグメントは見ない。
ItemId? parseDoneLink(Uri uri) {
  if (uri.scheme != doneLinkScheme || uri.host != doneLinkHost) {
    return null;
  }
  final segments = [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.length != 1) {
    return null;
  }
  return ItemId(segments.single);
}
