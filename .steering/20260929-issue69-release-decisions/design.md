# 設計書: 公開前の決定事項の確定(Issue #69)

<!-- status: ready -->

> 決定の中身は `requirements.md`。ここには実装者が手を動かす部分(applicationId の変更)だけを書く。
> docs の更新(tasklist フェーズ1)は司令塔が済ませてから渡す。

## 1. applicationId の変更

新しい値: **`com.github.fuji18.lastwhen`**

| ファイル | 変更 |
| --- | --- |
| `android/app/build.gradle.kts` | `namespace = "com.github.fuji18.lastwhen"`、`applicationId = "com.github.fuji18.lastwhen"`。`applicationId` の上にある `// TODO: Specify your own unique Application ID ...` の 1 行を消し、代わりに `// 公開後は変えられない(docs/architecture.md「配布(Android)」)。` を置く |
| `android/app/src/main/kotlin/com/lastwhen/lastwhen/MainActivity.kt` | `git mv` で `android/app/src/main/kotlin/com/github/fuji18/lastwhen/MainActivity.kt` へ移し、1 行目を `package com.github.fuji18.lastwhen` にする。空になった `kotlin/com/lastwhen/` は消す |

- `AndroidManifest.xml` は `.MainActivity` の相対指定なので変更不要。念のため `grep -rn "com.lastwhen" android/` が 0 件になることを確かめる(`android/build/` などの生成物は除く)
- **`ios/` は触らない**(Bundle ID は #75 の範囲)
- `release` の `signingConfig`(debug 鍵)と付随する TODO コメントは #72 の範囲なので触らない

## 2. 検証

1. `grep -rn "com.lastwhen" android/ --exclude-dir=build --exclude-dir=.gradle` が 0 件
2. `flutter build apk --debug` が成功する
3. `aapt2`/`apkanalyzer` が手元にあれば、生成した APK のパッケージ名が `com.github.fuji18.lastwhen` であることを確かめる(例: `$ANDROID_HOME/build-tools/*/aapt2 dump badging build/app/outputs/flutter-apk/app-debug.apk | head -1`)。無ければ省略してよい
4. 変更したファイルは Dart ではないので format / analyze の対象外。`flutter test` は `/check` が回す

## 3. エラー時

- ビルドが `namespace` と `package` の不一致などで失敗したら、同じ修正を 2 回試して通らなければ止めて報告する
