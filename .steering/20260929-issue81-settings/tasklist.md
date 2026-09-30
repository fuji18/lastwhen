# タスクリスト: 下部ナビの「設定」と設定画面(Issue #81)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: docs(司令塔)

- [x] `docs/product-requirements.md` F31 行を「ホーム / 図鑑 / 設定」に更新する
- [x] `docs/functional-design.md` の画面遷移図・その説明・F13 節の入口・図鑑(F31)節に設定を反映し、「設定(#81)」節を足す
- [x] `docs/glossary.md` に「設定(SettingsScreen)」を足す
- [x] `docs/repository-structure.md` に `settings_screen.dart` / `app_info.dart` / テストを足す
- [x] `docs/development-guidelines.md`「バージョンの運用」に `AppInfo.version` の更新を足す

## フェーズ2: 実装(委託)

- [x] `lib/ui/app_info.dart` を作る(design §1)
- [x] `lib/ui/screens/settings_screen.dart` を作る(design §2)
- [x] `lib/ui/screens/home_shell.dart` に設定タブを足す(design §3)
- [x] `lib/ui/screens/item_list_screen.dart` からカテゴリ管理のボタンを外す(design §4)
- [x] `test/ui/app_info_test.dart` と `test/ui/screens/settings_screen_test.dart` を書く(design §5.1 / §5.2)
- [x] 既存テストを直す(design §5.3)
- [x] format と analyze を通す(design §6)

## フェーズ3: 検収(司令塔)

- [ ] `/check` を通す
- [ ] `code-reviewer` に ui-design-guidelines §6 と §7 の追加項目を当てる
