# タスクリスト: 公開前の決定事項の確定(Issue #69)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: docs(司令塔)

- [x] `docs/product-requirements.md` の「未決事項」#1 / #2 / #3 を更新する
- [x] `docs/architecture.md` に「配布(Android)」節を足し、applicationId と Play Console のアカウント種別を記録する

## フェーズ2: applicationId の変更(実装者)

- [x] `android/app/build.gradle.kts` の `namespace` / `applicationId` とコメントを直す(design §1)
- [x] `MainActivity.kt` を新しいパッケージのディレクトリへ移し、`package` 宣言を直す(design §1)
- [x] design §2 の 1〜3 を実行し、結果をこのファイルの末尾に書く

## フェーズ3: 検証(司令塔)

- [x] ~~`/check`(format / analyze / test)~~(モード B(econ)のため回さず CI に委ねる)
- [x] `decisions.jsonl` に 1 行追記する

## 人手の作業

- [x] ~~Play Console に組織アカウントで登録する(D-U-N-S 番号が要る)~~(人手の作業のため Issue #83「人手の作業」ラベルへ移した)
- [x] ~~連絡先メールアドレスを決め、Issue #69 にコメントで共有する~~(同上。共有先は #83 のコメント)

## design §2 検証結果(フェーズ2)

1. `grep -rn "com.lastwhen" android/ --exclude-dir=build --exclude-dir=.gradle` → 0 件
2. `flutter build apk --debug` → 成功(`build/app/outputs/flutter-apk/app-debug.apk`)。初回実行時は旧パッケージ名の中間生成物と衝突して失敗したため `flutter clean` してから再実行し、成功を確認した
3. `aapt2 dump badging` でパッケージ名を確認 → `package: name='com.github.fuji18.lastwhen' ...`

## 実装後の振り返り

- 実装完了日: 2026-09-29
- 計画との差分:
  - 収益化(未決事項 #1)は、ユーザーの判断で方針を未決のまま残した。初回公開を無料・広告なしで出すことだけを決めた
  - applicationId は提案の `io.github.*` ではなく、ユーザーの指定で `com.github.fuji18.lastwhen` にした
  - 人手の作業は #69 から #83 に切り出し、新設の「人手の作業」ラベルを付けた。#73 の depends に #83 を足した
  - モード B(econ)なので `/check` は回さず CI に委ねた(一度起動してしまい、途中で止めた)
  - 旧パッケージの中間生成物が残っていてデバッグビルドが一度失敗した。`flutter clean` で解消した
- 申し送り:
  - 組織アカウントなので、#73 のクローズドテストの要件は外れる見込み。着手時にスコープを見直す
  - 着手前に `.harness/mode` を確かめること

