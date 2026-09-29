# 要求: Android リリースビルドの整備(Issue #72)

## 背景

release ビルドが debug 鍵で署名されている(`android/app/build.gradle.kts`)。Play に出すには、アップロード鍵で署名した AAB が要る。

## 司令塔の決定(2026-09-29)

| 論点 | 決定 | 理由 |
| --- | --- | --- |
| 署名の読み込み | `android/key.properties`(`storePassword` / `keyPassword` / `keyAlias` / `storeFile`)があれば release 署名に使う | Flutter 公式の手順どおり。鍵の実体と値をリポジトリの外に置ける |
| `key.properties` が無いとき | release は **debug 鍵にフォールバックし、Gradle の警告を出す** | devcontainer・CI で `flutter run --release` / `flutter build apk --release`(性能計測)を壊さない。**Play は debug 署名のアップロードを拒否する**ので、誤って出すことはない |
| 鍵の保管 | リポジトリの外に置き、**控えを 2 箇所**に取る(パスワードマネージャ + オフライン媒体)。`storeFile` は絶対パスで書く | 鍵をなくすと、アップロード鍵のリセット手続きが要る(Play App Signing 前提) |
| 難読化 | **使わない**(`--obfuscate` / `--split-debug-info` を付けない) | 守るべき秘密がコードに無い(外部通信なし・API キーなし)。クラッシュ収集も無いので、シンボルファイルを保管する手間だけが残る |
| targetSdk | `flutter.targetSdkVersion` = **36** のまま | Play の要件は「2026-08-31 以降、新規アプリと更新は API 36 以上」。満たしている |
| バージョン | `pubspec.yaml` の `version: x.y.z+N`。N(versionCode)は Play にアップロードするたびに必ず 1 以上増やす | Play は同じ versionCode を二度受け付けない |
| ログ | `developer.log` は release では VM サービスが無く出力されない。実機の `adb logcat` で確認する | functional-design「セキュリティ考慮事項」 |

## 要求

| # | 要求 | 出典 |
| --- | --- | --- |
| R1 | `key.properties` があれば release をアップロード鍵で署名する | 受け入れ条件 1 |
| R2 | `key.properties` が無くても `flutter test` / `flutter build apk --debug` が通る | 受け入れ条件 3 |
| R3 | 鍵の保管方針・バージョンの運用・リリースビルドの手順を development-guidelines に書く | 受け入れ条件 2 / 7 |
| R4 | 鍵と `key.properties` が追跡対象外であることを確かめる | 受け入れ条件 2 |
| R5 | 鍵の作成・AAB の証明書確認・ログ確認・実機スモークを行い、PR に載せる | 受け入れ条件 1 / 4 / 5 / 6(**人手の作業**) |

## スコープ外

- Play Console へのアップロード(#73 / #74)
- CI での自動リリース
