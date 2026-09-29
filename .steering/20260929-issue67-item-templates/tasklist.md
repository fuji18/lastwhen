# タスクリスト: よくある項目のワンタップ追加(F17 / Issue #67)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: ドメイン

- [x] `lib/domain/item_template.dart` を作る(design §1)
- [x] `test/domain/item_template_test.dart` を作る(§6-1)

## フェーズ2: UI

- [x] `lib/ui/widgets/item_template_chips.dart` を作る(§2)
- [x] `EmptyState` を StatefulWidget にしてよくある項目を足し、`item_list_screen.dart` から `onTemplatePressed` を渡す(§3)
- [x] 登録画面によくある項目の欄と `_applyTemplate` を足す(§4)

## フェーズ3: テスト

- [x] `item_list_screen_test.dart` に「よくある項目(F17)」group を足す(§6-2)
- [x] `item_add_screen_test.dart` にテストを 3 件足す(§6-3)
- [x] `accessibility_test.dart` に 200% のテストを足す(§6-5)
- [x] チップと衝突する既存テストの finder を絞る(§6-4。変更箇所: なし。既存の同名削除・改名検証は項目が残る一覧を対象としており、空状態のチップとは衝突しない)

## フェーズ4: docs

- [x] `docs/product-requirements.md`(§5)
- [x] `docs/functional-design.md`(§5)
- [x] `docs/glossary.md`(§5)

## フェーズ5: 検証

- [x] `dart format` / `flutter analyze --fatal-infos` を通す(変更した Dart 9 ファイルをキャッシュ内 Dart SDK で format・analyze --fatal-infos: 問題なし)
- [x] `flutter test` を通す(ホスト委任: AGENTS.md に従い sandbox では実行せず、追加したドメイン・UI テストと既存テストの実行を検収側に委ねる)
- [x] `lib/data/` / `lib/state/` / `pubspec.yaml` に差分が無いことを確認する(§7)

## 実装後の振り返り

- 実装完了日: 2026-09-29
- 計画と実績の差分: なし。Codex への 1 回の全体委託で tasklist 15/15(判断待ち 0)。初回は `.claude/settings.local.json` が機密検査に掛かり `exit 2`、ユーザーが内容を確認して ACK し再実行した
- 検証: 委託先は変更した Dart ファイルの format・analyze を通過。`flutter test` は sandbox で回せないため未実施。モード B のため `/check` と `code-reviewer` も回さず CI に委ねる
- 学んだこと: `design.md` にコード断片・テスト手順・既存テストへの影響(finder の衝突)まで書くと、UI を含むチケットでも 1 回で通る
- 次回への改善提案: `.claude/settings.local.json` は常に存在するため、委託のたびに ACK が要る。denylist の扱い(内容で判定するか)を検討する
