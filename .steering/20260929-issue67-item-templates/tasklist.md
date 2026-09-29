# タスクリスト: よくある項目のワンタップ追加(F17 / Issue #67)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: ドメイン

- [ ] `lib/domain/item_template.dart` を作る(design §1)
- [ ] `test/domain/item_template_test.dart` を作る(§6-1)

## フェーズ2: UI

- [ ] `lib/ui/widgets/item_template_chips.dart` を作る(§2)
- [ ] `EmptyState` を StatefulWidget にしてよくある項目を足し、`item_list_screen.dart` から `onTemplatePressed` を渡す(§3)
- [ ] 登録画面によくある項目の欄と `_applyTemplate` を足す(§4)

## フェーズ3: テスト

- [ ] `item_list_screen_test.dart` に「よくある項目(F17)」group を足す(§6-2)
- [ ] `item_add_screen_test.dart` にテストを 3 件足す(§6-3)
- [ ] `accessibility_test.dart` に 200% のテストを足す(§6-5)
- [ ] チップと衝突する既存テストの finder を絞る(§6-4。変更箇所をここに列挙する。無ければ「なし」)

## フェーズ4: docs

- [ ] `docs/product-requirements.md`(§5)
- [ ] `docs/functional-design.md`(§5)
- [ ] `docs/glossary.md`(§5)

## フェーズ5: 検証

- [ ] `dart format` / `flutter analyze --fatal-infos` を通す
- [ ] `flutter test` を通す(委託先で実行できない場合は「ホスト委任」と記録して検収側に委ねる)
- [ ] `lib/data/` / `lib/state/` / `pubspec.yaml` に差分が無いことを確認する(§7)

## 実装後の振り返り

(司令塔が記入)
