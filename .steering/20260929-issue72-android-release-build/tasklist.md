# タスクリスト: Android リリースビルドの整備(Issue #72)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: docs(司令塔)

- [x] `docs/development-guidelines.md` に「リリースビルド(Android)」節を足す(署名・鍵の保管方針・バージョンの運用・難読化を使わない理由・証明書の確認・ログの確認)
- [x] `docs/architecture.md`「機密情報管理」から上の節へ参照を張る

## フェーズ2: release 署名(実装者)

- [x] `android/app/build.gradle.kts` に `key.properties` の読み込みと release 署名を足す(design §1)
- [x] design §2 の 1〜4 を実行し、結果をこのファイルの末尾に書く

## フェーズ3: 検証(司令塔)

- [x] ~~`/check`(format / analyze / test)~~(モード B(econ)のため回さず CI に委ねる)
- [x] `decisions.jsonl` に 1 行追記する

## 人手の作業

- [x] ~~アップロード鍵を作り、`android/key.properties` を書き、控えを 2 箇所に取る~~(人手の作業のため Issue #85「人手の作業」ラベルへ移した)
- [x] ~~`flutter build appbundle --release` を実行し、`keytool -printcert -jarfile` の結果を PR に載せる~~(人手の作業のため Issue #85「人手の作業」ラベルへ移した)
- [x] ~~実機スモーク(登録 / 記録と取り消し / 記録の詳細 / 削除 / 再起動後もデータが残る / 通知が届く)と、`adb logcat` に項目名が出ないことを確認して PR に載せる。Doze 下での 19:00 通知の遅れも見る~~(人手の作業のため Issue #85「人手の作業」ラベルへ移した)

## design §2 の検証結果(フェーズ2)

1. `test -f android/key.properties` → 存在しない(exit 1)ことを確認した
2. `flutter build apk --debug` → 成功(`build/app/outputs/flutter-apk/app-debug.apk`)
3. `flutter build apk --release` → 成功(`build/app/outputs/flutter-apk/app-release.apk`, 79.7MB)。`flutter build` の既定出力には出ないため `cd android && ./gradlew :app:assembleRelease --console=plain` で確認したところ、`android/key.properties が無いため、release を debug 鍵で署名します` の警告が出力された
4. `git check-ignore -v android/key.properties android/app/upload-keystore.jks` → 2 行とも無視対象と表示された(`android/.gitignore:12:key.properties` / `android/.gitignore:14:**/*.jks`)
5. Kotlin スクリプトのため format / analyze の対象外。`flutter test` は CI が回す(未実行)

## 実装後の振り返り

- 実装完了日: 2026-09-29
- 計画との差分:
  - 鍵の作成・AAB の証明書確認・実機スモーク・logcat の確認は、ユーザーの指示で #85(「人手の作業」ラベル)に切り出した。#73 の depends に #85 を足した
  - release の警告は `flutter build` の出力に出ないため、fork が `./gradlew :app:assembleRelease --console=plain` で確認した
  - 選定時に #70 → #68 → #81 → #70 の依存の循環が見つかり、ユーザーの判断で #70 から #68 を外した
  - モード B(econ)なので `/check` と code-reviewer は回さず CI に委ねた
