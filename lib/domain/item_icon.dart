/// 項目に付けるアイコンの種類。**表示順 = 宣言順。**
///
/// [key] は DB(`items.icon`)に保存する値。**一度出荷したキーは変えない・消さない。**
/// 候補を減らすときも enum 値は残す(保存済みの項目が未選択に落ちるため)。
enum ItemIcon {
  cleaning('cleaning'),
  bath('bath'),
  trash('trash'),
  laundry('laundry'),
  bed('bed'),
  kitchen('kitchen'),
  airConditioner('air_conditioner'),
  lightbulb('lightbulb'),
  battery('battery'),
  plant('plant'),
  garden('garden'),
  pet('pet'),
  haircut('haircut'),
  beauty('beauty'),
  medicine('medicine'),
  hospital('hospital'),
  vaccine('vaccine'),
  exercise('exercise'),
  reading('reading'),
  car('car'),
  fuel('fuel'),
  shopping('shopping'),
  clothes('clothes'),
  cafe('cafe');

  const ItemIcon(this.key);

  /// DB に保存する不変のキー。
  final String key;

  /// 保存値から戻す。**null・未知のキーは null(未選択)にする。例外にしない。**
  static ItemIcon? fromKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final value in ItemIcon.values) {
      if (value.key == key) {
        return value;
      }
    }
    return null;
  }
}
