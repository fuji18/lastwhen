# 要求: アプリアイコンとロゴの差し替え(Issue #35)

## 背景

アプリアイコンとロゴの画像が揃ったので、Flutter 既定のアイコンとスプラッシュから差し替える。

- アプリアイコン: `docs/ideas/lastwhen_icon.png`(本を読むカメレオン。1254×1254 / RGB / アルファなし)
- ロゴ: `docs/ideas/LastWhen_logo.png`(1774×887 / RGB。クリーム地に茶色の文字)

## Issue の未決事項に対するユーザーの決定(2026-09-25)

| 未決事項 | 決定 |
| --- | --- |
| アイコン生成ツール | **`flutter_launcher_icons`(dev 依存)を導入する** |
| iOS の 1024px 要件 | **ユーザーが 1254px の元画像に差し替え済み**(`docs/ideas/lastwhen_icon.png`) |
| アダプティブアイコン | **画像全体を前景にし、背景は無地の色**(素材を分けない) |
| ロゴの表示先 | **スプラッシュに出す**(`flutter_native_splash` を dev 依存で導入する) |

## スコープ

1. Android のランチャーアイコン(従来型 + アダプティブ)と iOS の AppIcon を差し替える
2. ネイティブのスプラッシュ(起動画面)にロゴを出す(iOS / Android 8〜11 / Android 12 以降)
3. アプリの表示名を **`LastWhen`** に揃える(Android `android:label` と iOS `CFBundleDisplayName`)
4. 依存の追加に合わせて `docs/architecture.md` の依存表と `docs/repository-structure.md` を更新する

## スコープ外

- アプリ内画面(ホームの見出しなど)へのロゴ表示
- Android 13 のテーマアイコン(モノクロ)、iOS 18 のダーク/ティント版アイコン
- ダークモード専用のスプラッシュ
- Web / Windows / macOS のアイコン(プラットフォーム自体が無い)

## 受け入れ条件

- [ ] `android/app/src/main/res/mipmap-*` のランチャーアイコンと `mipmap-anydpi-v26` のアダプティブアイコン定義が新しいアイコンから生成されている
- [ ] `ios/Runner/Assets.xcassets/AppIcon.appiconset` が新しいアイコンから生成されている(1024px を含む・アルファなし)
- [ ] ネイティブのスプラッシュにロゴが出る設定が Android / iOS に生成されている
- [ ] 表示名が Android / iOS ともに `LastWhen`
- [ ] `dart format` / `flutter analyze --fatal-infos` / `flutter test` が通る
- [ ] Android の debug ビルド(`flutter build apk --debug`)が通る
- iOS はビルドを devcontainer で検証できない(Xcode が要る)。生成物の差分確認までとし、実機確認は macOS で行う(PR に明記する)
