import 'package:flutter/material.dart';

import '../../state/item_view.dart';
import '../item_icon_glyph.dart';
import '../theme/app_theme.dart';
import 'aged_paper.dart';
import 'item_card.dart' show agingStageSemanticsText, itemCardStackThreshold;

/// 図鑑のカードで描くアイコンの一辺(dp)。
const double collectionCardIconSize = 40;

/// 図鑑のカードの内側の余白(dp)。
const double collectionCardPadding = 12;

/// 基準間隔の表示(`平均7日` / `学習中`)。**四捨五入**する(`double.round()`)。
/// 画面上の呼び名は「平均」、null は「学習中」(`docs/glossary.md`「基準間隔」)。
String collectionIntervalText(double? baselineIntervalDays) =>
    baselineIntervalDays == null ? '学習中' : '平均${baselineIntervalDays.round()}日';

/// 列数。文字倍率が [itemCardStackThreshold] 以上なら 2 列、未満なら 3 列。
/// 判定は一覧のカードと同じ方法(基準 16dp を拡大して比べる)で行う。
int collectionColumnCount(TextScaler textScaler) =>
    textScaler.scale(16) >= 16 * itemCardStackThreshold ? 2 : 3;

/// カード 1 枚の高さ(dp)。文字倍率に合わせて伸ばし、200% でもはみ出さないようにする。
///
/// 余白 × 2 + アイコン + 8 + 項目名 2 行 + 4 + 平均 1 行 + 余裕 8。
double collectionCardExtent(TextTheme textTheme, TextScaler textScaler) {
  double lineHeight(TextStyle? style) {
    final fontSize = style?.fontSize ?? 14;
    // height が未指定のテーマでも日本語の行が収まるよう、既定を大きめに取る。
    return textScaler.scale(fontSize) * (style?.height ?? 1.5);
  }

  return collectionCardPadding * 2 +
      collectionCardIconSize +
      8 +
      lineHeight(textTheme.titleSmall) * 2 +
      4 +
      lineHeight(textTheme.bodySmall) +
      8;
}

/// 読み上げ文。`項目名、平均7日` / `項目名、学習中`。経年ステージが fresh 以外なら
/// `、状態は{agingStageSemanticsText}` を足す(一覧のカードと同じ語)。
String collectionCardSemanticsLabel(ItemView item) {
  final label =
      '${item.name}、${collectionIntervalText(item.baselineIntervalDays)}';
  final stageText = agingStageSemanticsText(item.agingStage);
  return stageText == null ? label : '$label、状態は$stageText';
}

/// 図鑑のカード。記録済みの項目だけを表示する(未実施は図鑑に載らない)。
///
/// **経過日数・最終実施日・「やった」ボタンを出さない**(図鑑は眺める場所。記録の入口は
/// 置かない)。古びは紙の面とアイコンの掠れだけ。テキストの色は変えない(一覧のカードと
/// 同じ方針)。
class CollectionCard extends StatelessWidget {
  /// カードを作る。
  const CollectionCard({required this.item, required this.onTap, super.key});

  /// 表示する項目。
  final ItemView item;

  /// カードそのもののタップ時の処理(詳細シートを開く)。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AgingPalette.of(context);
    return CustomPaint(
      painter: AgedPaperPainter(
        stage: item.agingStage,
        colors: palette.colorsOf(item.agingStage),
        seed: stableSeedOf(item.id.value),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(agedPaperCornerRadius),
          child: Padding(
            padding: const EdgeInsets.all(collectionCardPadding),
            child: Semantics(
              label: collectionCardSemanticsLabel(item),
              excludeSemantics: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    itemIconData(item.icon),
                    size: collectionCardIconSize,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: agingIconOpacity(item.agingStage),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    collectionIntervalText(item.baselineIntervalDays),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
