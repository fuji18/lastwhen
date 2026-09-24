import 'package:flutter/material.dart';

import '../domain/item_icon.dart';

/// 未選択の項目に描く既定アイコン。
const IconData defaultItemIconData = Icons.event_repeat;

/// アイコンの描画データ。[icon] が null なら [defaultItemIconData]。
IconData itemIconData(ItemIcon? icon) => switch (icon) {
  null => defaultItemIconData,
  ItemIcon.cleaning => Icons.cleaning_services,
  ItemIcon.bath => Icons.bathtub,
  ItemIcon.trash => Icons.delete,
  ItemIcon.laundry => Icons.local_laundry_service,
  ItemIcon.bed => Icons.bed,
  ItemIcon.kitchen => Icons.kitchen,
  ItemIcon.airConditioner => Icons.air,
  ItemIcon.lightbulb => Icons.lightbulb,
  ItemIcon.battery => Icons.battery_charging_full,
  ItemIcon.plant => Icons.local_florist,
  ItemIcon.garden => Icons.yard,
  ItemIcon.pet => Icons.pets,
  ItemIcon.haircut => Icons.content_cut,
  ItemIcon.beauty => Icons.face,
  ItemIcon.medicine => Icons.medication,
  ItemIcon.hospital => Icons.local_hospital,
  ItemIcon.vaccine => Icons.vaccines,
  ItemIcon.exercise => Icons.fitness_center,
  ItemIcon.reading => Icons.menu_book,
  ItemIcon.car => Icons.directions_car,
  ItemIcon.fuel => Icons.local_gas_station,
  ItemIcon.shopping => Icons.shopping_cart,
  ItemIcon.clothes => Icons.checkroom,
  ItemIcon.cafe => Icons.local_cafe,
};

/// 選択肢の読み上げ・ツールチップに使う日本語名。
String itemIconLabel(ItemIcon icon) => switch (icon) {
  ItemIcon.cleaning => '掃除',
  ItemIcon.bath => '風呂',
  ItemIcon.trash => 'ゴミ出し',
  ItemIcon.laundry => '洗濯',
  ItemIcon.bed => '寝具',
  ItemIcon.kitchen => '冷蔵庫',
  ItemIcon.airConditioner => 'エアコン',
  ItemIcon.lightbulb => '電球',
  ItemIcon.battery => '電池',
  ItemIcon.plant => '植物',
  ItemIcon.garden => '庭',
  ItemIcon.pet => 'ペット',
  ItemIcon.haircut => '美容院',
  ItemIcon.beauty => '美容',
  ItemIcon.medicine => '薬',
  ItemIcon.hospital => '病院',
  ItemIcon.vaccine => '予防接種',
  ItemIcon.exercise => '運動',
  ItemIcon.reading => '読書',
  ItemIcon.car => '車',
  ItemIcon.fuel => '給油',
  ItemIcon.shopping => '買い物',
  ItemIcon.clothes => '衣類',
  ItemIcon.cafe => 'カフェ',
};
