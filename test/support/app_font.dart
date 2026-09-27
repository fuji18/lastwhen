import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/ui/theme/app_fonts.dart';

/// 同梱フォントの 3 ウェイトを実際に読み込む。
///
/// ウィジェットテストは既定で全文字を同じ幅の四角で描くため、書体に依存するレイアウトを
/// 実寸で検査するファイルだけが `setUpAll(loadAppFont)` で呼ぶ(#56 design.md 判断 E)。
Future<void> loadAppFont() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader(AppFonts.family);
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/ZenMaruGothic-$weight.ttf'));
  }
  await loader.load();
}
