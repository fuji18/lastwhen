import 'mark_done_result.dart';

/// リンク(NFC タグ)からの記録の結果(F32)。**例外を投げない。**
sealed class LinkMarkDoneResult {
  const LinkMarkDoneResult();
}

/// 記録した。[undo] を取り消し導線へ渡す。
final class LinkMarkDoneSucceeded extends LinkMarkDoneResult {
  const LinkMarkDoneSucceeded({required this.itemName, required this.undo});

  final String itemName;
  final MarkDoneUndo undo;
}

/// 今日(ローカル暦日)すでに記録済みだった。**書き込みを試みていない**(判断6)。
final class LinkMarkDoneAlreadyToday extends LinkMarkDoneResult {
  const LinkMarkDoneAlreadyToday({required this.itemName});

  final String itemName;
}

/// 項目が見つからなかった(削除済み・ID 不正)。**書き込みを試みていない。**
final class LinkMarkDoneNotFound extends LinkMarkDoneResult {
  const LinkMarkDoneNotFound();
}

/// 一覧の読み込みか書き込みに失敗した。
final class LinkMarkDoneFailed extends LinkMarkDoneResult {
  const LinkMarkDoneFailed();
}
