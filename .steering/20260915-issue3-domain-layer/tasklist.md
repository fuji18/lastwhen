# タスクリスト: ドメイン層(Issue #3)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**

## 実装

- [x] `lib/domain/item.dart` を作成する(`ItemId` / `Item`。design.md §2.1)
- [x] `lib/domain/item_name.dart` を作成する(`validateItemName` と結果型。§2.2)
- [x] `lib/domain/clock.dart` を作成する(`Clock` / `SystemClock`。§2.3)
- [x] `lib/domain/elapsed_days.dart` を作成する(`calendarDateOf` / `elapsedDays` / `ElapsedLabel` / `elapsedLabel`。§2.4)
- [x] `lib/domain/item_repository.dart` を作成する(**インターフェースのみ**。§2.5)
- [x] `lib/domain/.gitkeep` を削除する

## テスト

- [x] `test/support/fake_clock.dart` を作成する(§2.6)
- [x] `test/domain/elapsed_days_test.dart` を作成する(§3.1 の 3 グループ・全ケース)
- [x] `test/domain/item_name_test.dart` を作成する(§3.2)
- [x] `test/domain/clock_test.dart` を作成する(§3.3)
- [x] `test/domain/item_test.dart` を作成する(§3.4。`==` の分岐を 1 つずつ潰す)
- [x] `test/architecture/layer_dependency_test.dart` を作成する(§3.5。domain の検査のみ)

## 検証

- [x] `dart format .` を実行し、差分が出ない状態にする
- [x] `flutter analyze --fatal-infos` が通る
- [x] `flutter test` が通る
- [x] `flutter test --coverage` + §4 の awk で `lib/domain/` の未カバー行が 0 であることを確認する
- [x] `coverage/` が `.gitignore` にあることを確認する(無ければ追記)

## 検収の指摘対応(2026-09-15 / code-reviewer Major 1 件)

- [x] `test/domain/elapsed_days_test.dart` の「日付をまたぐと 24 時間未満でも 1 日」「同じ日の 23:59 は 0 日」を、`DateTime.utc(...)` ではなく**ローカルリテラル `DateTime(...)`** で書き直す(design.md §3.1 の注記)。理由のコメントを 1 行添える
- [x] `TZ=Asia/Tokyo flutter test` が通ることを確認する(UTC 環境だけでは JST 依存の欠陥が見えない)
- [x] `flutter test` / `flutter analyze --fatal-infos` / `dart format .` / カバレッジ 100% を再確認する

## 振り返り(申し送り)

- **`design.md` のテスト入力表そのものにタイムゾーン依存の欠陥が混入した。** §3.1 の直下に
  「00:00 前後や 15:00 以降の時刻を使わないこと」と書いた本人が、同じ表の
  「日付をまたぐと 24 時間未満でも 1 日」に `23:00 UTC → 翌 02:00 UTC` と書いていた。
  JST では両方が同じ暦日に丸まり `0` が返る(`TZ=Asia/Tokyo flutter test` で実測)。
  **計画で注記を書いたら、同じ計画の中の具体値を 1 件ずつその注記に照らして検算する。**
  実装 fork は design.md に忠実だったため逸脱ではなく、**計画の欠陥がそのままテストへ写った**
- **時刻テストの書き分け(#5 以降へ申し送り)**: 両方の時刻帯が同じケースは UTC リテラル
  (タイムゾーンが変わっても両方の暦日が一様にずれるので差は保たれる)。**深夜をまたぐ検証は
  ローカルリテラル `DateTime(...)`** で書く(`elapsedDays` は内部で `.toLocal()` するため恒等変換になる)
- **夏時間の受け入れ条件は「DST のある環境で回す」形では担保できない。** devcontainer / CI は UTC、
  開発者の端末は JST で、どちらも夏時間を持たない。バグのある実装も同じ値を返すため、
  DST をまたぐ入力を与えるテストは**通っても何も証明しない**。代わりに
  `calendarDateOf(...).isUtc == true` の回帰テストで「ローカルの `DateTime` に戻す改変」を
  どの環境でも落とせるようにした(`design.md` 判断5)。**同種の時刻ロジックを足すときはこの形を使う**
- **検証コマンドに `TZ=Asia/Tokyo flutter test` を足した**(`design.md` §4)。CI の `quality` ジョブは
  UTC でしか回らないため、**この層はローカル検証にしか存在しない**。CI にタイムゾーンの
  マトリクスを足すかは別途判断する(`.github/workflows/` は委託禁止領域。→ 別チケット候補)
- **extension type の `const` コンストラクタはカバレッジ計測で未実行扱いになる。** `const ItemId('a')`
  と書くとコンパイル時に畳み込まれ、`extension type const ItemId(...)` の行が 0 ヒットになる。
  非 const のローカル変数経由で生成すると計上される(実装 fork が実測して回避)
