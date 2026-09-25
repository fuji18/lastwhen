# 設計: アプリアイコンとロゴの差し替え(Issue #35)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **スコープ判断(司令塔)**: P1。P0 はすべてクローズ済み。未決事項はユーザーが決定済み(`requirements.md`)
> - **新規依存の追加を含むため Codex に委託しない**(sandbox はネットワーク無効で `pub get` ができない)
> - **Dart のアプリコード(`lib/`)は変更しない。** 変更はプラットフォームの生成物・設定ファイル・docs のみ
> - 追加するのは**生成ツール 2 つの dev 依存だけ**。アプリ本体にパッケージは入らない(「追加の UI パッケージを入れない」に抵触しない)

## 0. 全体像

```
assets/branding/            ← 生成の入力(司令塔が用意済み。実装者は作り直さない)
  app_icon.png              1254×1254  docs/ideas/lastwhen_icon.png の複製
  splash_logo.png            800×197   ロゴの文字部分を切り出して縮小(背景 #FEFBF4 近傍のクリーム)
  splash_android12.png      1152×1152  app_icon.png の縮小(Android 12+ の中央画像)

flutter_launcher_icons.yaml  → dart run flutter_launcher_icons   → android/.../mipmap-* , ios/.../AppIcon.appiconset
flutter_native_splash.yaml   → dart run flutter_native_splash:create → android/.../drawable*, values*, ios/.../LaunchImage 等
```

- `assets/branding/` は**生成ツールの入力置き場**であり、アプリにバンドルしない。**`pubspec.yaml` の `flutter: assets:` に登録しない**
- 素材 3 枚は司令塔が作成済み(ワーキングツリーに未コミットで存在する)。**実装者は画像を加工・再生成しない**

## 判断1: 依存の追加

```bash
flutter pub add --dev flutter_launcher_icons flutter_native_splash
```

- `pub add` が書くキャレット指定(`^x.y.z`)をそのまま使う。バージョンを手で書き換えない
- `pubspec.yaml` の `dev_dependencies` で、`flutter_lints` の**前**に次のコメントと共に並べる(既存の `# Drift のコード生成(#4 で使う)` と同じ書き方):

  ```yaml
    # ランチャーアイコンとネイティブのスプラッシュの生成(#35 で使う。設定はルートの *.yaml)
    flutter_launcher_icons: ^x.y.z
    flutter_native_splash: ^x.y.z
  ```

  `pub add` がアルファベット順の別位置に入れた場合は上の位置へ移す
- `pubspec.lock` の差分はそのままコミット対象
- **`flutter_native_splash` を `dependencies` に入れない。** `FlutterNativeSplash.preserve()` などのランタイム API は使わない(起動処理を変えない)

## 判断2: アイコンの生成設定(ルートに `flutter_launcher_icons.yaml` を新規作成)

```yaml
# ランチャーアイコンの生成設定(#35)。変更したら次を実行して生成物ごとコミットする:
#   dart run flutter_launcher_icons
# 入力画像の置き場は assets/branding/(アプリにはバンドルしない)。
flutter_launcher_icons:
  image_path: "assets/branding/app_icon.png"
  android: true
  ios: true
  min_sdk_android: 26
  remove_alpha_ios: true
  # アダプティブアイコン: 画像全体を前景にし、背景は画像外周の紙色の無地にする。
  # 前景の inset 16% で、端末の切り抜き(丸・角丸)でも中央の絵が欠けない。
  adaptive_icon_foreground: "assets/branding/app_icon.png"
  adaptive_icon_background: "#E6CBA8"
  adaptive_icon_foreground_inset: 16
```

- `android: true` で既定名 `ic_launcher` を**上書き**する。`AndroidManifest.xml` の `android:icon="@mipmap/ic_launcher"` は変更しない
- モノクロ(`adaptive_icon_monochrome`)・iOS のダーク/ティント版・web/windows/macos は**設定しない**(スコープ外)
- 実行: `dart run flutter_launcher_icons`
- ツールが `android/app/src/main/res/values/colors.xml` を新規作成・追記するのは想定どおり(背景色の定義)。そのままコミットする

## 判断3: スプラッシュの生成設定(ルートに `flutter_native_splash.yaml` を新規作成)

```yaml
# ネイティブのスプラッシュ(起動画面)の生成設定(#35)。変更したら次を実行して生成物ごとコミットする:
#   dart run flutter_native_splash:create
# 背景色はロゴ画像の地の色に合わせる(ロゴは地の色込みの画像なので、ずれると四角く浮く)。
flutter_native_splash:
  color: "#FEFBF4"
  image: assets/branding/splash_logo.png
  android: true
  ios: true
  web: false

  # Android 12 以降は中央に円形に切り抜かれたアイコンしか出せないため、
  # 中央はカメレオン、ロゴは下部のブランディング画像として出す。
  android_12:
    color: "#FEFBF4"
    image: assets/branding/splash_android12.png
    branding: assets/branding/splash_logo.png
```

- **ダークモード用の値(`color_dark` / `image_dark` 等)は設定しない。** 端末がダークでもスプラッシュはクリーム地のまま(ロゴ画像に地の色が焼き込まれているため、暗い背景にすると四角く浮く)。スコープ外として受け入れる
- `fullscreen` / `android_gravity` / `ios_content_mode` / `branding_mode` など上に無いキーは**書かない**(既定値に任せる)
- 実行: `dart run flutter_native_splash:create`
- ツールが次を書き換える・新規作成するのは想定どおり。**手で直さず**そのままコミットする:
  - `android/app/src/main/res/drawable*/launch_background.xml` / `background.png` / `splash.png` / `branding.png`
  - `android/app/src/main/res/values*/styles.xml`(`values-v31` / `values-night-v31` 等の新設を含む)
  - `ios/Runner/Assets.xcassets/LaunchImage.imageset/*` / `LaunchBackground.imageset/*` / `BrandingImage.imageset/*`(出るものだけ)
  - `ios/Runner/Base.lproj/LaunchScreen.storyboard` / `ios/Runner/Info.plist`
- **ツールが `lib/main.dart` を書き換えた場合は元に戻す**(`git checkout -- lib/main.dart`)。ランタイム API は使わない(判断1)

## 判断4: 表示名

| ファイル | 変更前 | 変更後 |
| --- | --- | --- |
| `android/app/src/main/AndroidManifest.xml` | `android:label="lastwhen"` | `android:label="LastWhen"` |
| `ios/Runner/Info.plist` の `CFBundleDisplayName` | `Lastwhen` | `LastWhen` |

- `CFBundleName`(`lastwhen`)・applicationId・bundle identifier・`pubspec.yaml` の `name` は**変えない**(内部識別子であり、変えると別アプリ扱いになる)
- `lib/app.dart` の `title: 'LastWhen'` はすでに一致しているので触らない
- **判断3 の生成で `Info.plist` が書き換わるため、表示名の編集は生成の後に行い、最後に `CFBundleDisplayName` が `LastWhen` であることを確かめる**

## 判断5: ドキュメントの更新

### `docs/architecture.md`

1. 「開発ツール」表(`build_runner` + `drift_dev` の行の直後)に 1 行足す:

   ```
   | `flutter_launcher_icons` / `flutter_native_splash` | アイコンとスプラッシュの生成 | 各 OS の多数のサイズ・密度を 1 枚の元画像と設定ファイルから再生成できる。dev 依存でアプリには入らない |
   ```

2. 「依存関係管理」表(`flutter_lints` の行の直後)に 1 行足す:

   ```
   | `flutter_launcher_icons` / `flutter_native_splash` | アイコン・スプラッシュの生成 | キャレット(dev 依存)。**生成物はコミットする**(CI で生成しない) |
   ```

### `docs/repository-structure.md`

1. 冒頭のツリーで、`├── docs/` の行の直前に次の行を足す(桁揃えは周囲に合わせる):

   ```
   ├── assets/branding/          # アイコン・スプラッシュ生成の入力画像(アプリにはバンドルしない)
   ```

2. 「### 設定ファイル」の表で、`analysis_options.yaml` の行の直後に 2 行足す:

   ```
   | `flutter_launcher_icons.yaml` | ランチャーアイコンの生成設定。変更後は `dart run flutter_launcher_icons` を実行し、生成物ごとコミットする |
   | `flutter_native_splash.yaml` | ネイティブのスプラッシュの生成設定。変更後は `dart run flutter_native_splash:create` を実行し、生成物ごとコミットする |
   ```

## 判断6: 検証

- `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` が通ること(Dart コードは変えないので、壊れていないことの確認)
- `flutter build apk --debug` が通ること(生成したリソース・styles の整合確認)。**ビルド成果物(`build/`)はコミットしない**
- iOS は devcontainer でビルドできない。**生成物の差分があることの確認まで**とし、`AppIcon.appiconset/Contents.json` に 1024 のエントリがあることを確かめる
- テストは追加しない(Dart のロジック変更が無い)

## 判断7: コミット対象の確認

生成後、`git status --short` の内容が次の範囲に収まっていること。**範囲外の変更が出たら止めて司令塔に報告する**:

- `pubspec.yaml` / `pubspec.lock` / `flutter_launcher_icons.yaml` / `flutter_native_splash.yaml`
- `assets/branding/*`(司令塔が用意済み)/ `docs/ideas/lastwhen_icon.png`(ユーザーが差し替え済み)
- `android/app/src/main/res/**` / `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Assets.xcassets/**` / `ios/Runner/Base.lproj/LaunchScreen.storyboard` / `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj` の `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` → `AppIcon`(Debug / Release)。**追記(司令塔・実装中の判断待ちへの回答)**: `flutter_launcher_icons` 0.14 系が iOS 生成時に必ず行う書き換え。戻しても次回の再生成で再び入るため、生成物として受け入れる
- `docs/architecture.md` / `docs/repository-structure.md` / `.steering/20260925-issue35-app-icon/*`
