# 要求内容

Issue #92「ホームの AppBar のアプリ名をロゴにする」(P1 / フェーズ5)。

## 背景

実機確認(#90)で出た要望。一覧(ホーム)の AppBar 左上がテキストの「LastWhen」で、アプリとしての見た目が弱い。ロゴに置き換える。

## スコープ

- `lib/ui/screens/item_list_screen.dart` の AppBar `title`(`Text('LastWhen')`)をロゴ画像に置き換える
- ロゴのアセットを `assets/branding/` に置き、`pubspec.yaml` に登録する
- 読み上げではアプリ名(`AppInfo.name`)が読まれる
- ライト・ダーク両テーマで判読できる

## スコープ外

- アプリアイコン・スプラッシュの変更
- `MaterialApp.title` / `AppInfo.name` の変更
- 図鑑・設定タブの AppBar

## ユーザー確認済みの事項(2026-09-30)

- **素材**: `docs/ideas/LastWhen_logo_haikeinashi.png`(ユーザー自作の文字ロゴ・背景透過・単色の焦げ茶)。権利はユーザー自作で確認済み
- **形式**: PNG。`flutter_svg` は足さない(新規依存なし)
- **ダークテーマ**: 画像は 1 枚。両テーマとも `ColorScheme.onSurface` で着色する

## 受け入れ条件

- [ ] ホームの AppBar 左上にロゴが出る
- [ ] ライト・ダークの両テーマでロゴが判読できる
- [ ] 文字サイズを最大にしても AppBar からはみ出さない
- [ ] 読み上げで「LastWhen」と読まれる
- [ ] ロゴの権利(自作・ライセンス)が確認できている
- [ ] docs/ui-design-guidelines.md §6 のチェックリストを code-reviewer で当てている
- [ ] ウィジェットテストがある(ロゴの表示と読み上げラベル)
