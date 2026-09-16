# タスクリスト: データ層(Issue #4)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**
`pubspec.yaml` に依存を足す必要が出たときも同じく止める。

## 実装

- [x] `lib/data/database/app_database.dart` を作成する(`Items` テーブル / `AppDatabase` / `_openConnection`。design.md §2.1)
- [x] `lib/data/migrations/migrations.dart` を作成する(`buildMigrationStrategy`。§2.2)
- [x] `dart run build_runner build --delete-conflicting-outputs` を実行し、`app_database.g.dart` を生成する(§3)
- [x] `lib/data/item_repository_impl.dart` を作成する(`ItemRepositoryImpl` と変換ヘルパ。§2.3)
- [x] `lib/data/.gitkeep` を削除する

## テスト

- [x] `test/support/fake_item_repository.dart` を作成する(§2.4)
- [x] `test/data/item_repository_impl_test.dart` の共有シナリオ 1〜8 を書く(§2.5。**実装とフェイクの両方に流す**)
- [x] 同ファイルの実装専用 group 9〜14 を書く(§2.5。生の SQL で保存形式を検証する)

## 検証

- [x] `dart format .` を実行し、差分が出ない状態にする
- [x] `flutter analyze --fatal-infos` が通る
- [x] `flutter test` が通る
- [x] `git status` で `lib/data/database/app_database.g.dart` が追跡対象になっていることを確認する(`.gitignore` で除外されていないこと)

## 振り返り(申し送り)

<!-- 実装後に司令塔が記入する -->

### 実装時の差異(design.md からの逸脱)

- `test/data/item_repository_impl_test.dart` のテスト13(`watchAll は書き込みのたびに再送出される`)は
  design.md §2.5 のコード片どおりに書くと再現性のある失敗になった。`repository.watchAll()` を
  `expectLater` で購読した直後に `add` を連続実行すると、drift の初回フェッチ(非同期)が完了する前に
  書き込みが走り、初回の空リストと 1 回目の更新が 1 通のイベントに合流して欠落する(2 回連続で
  同一失敗を確認済み、テスト単体実行でも再現)。テストコードにのみ `await pumpEventQueue();` を
  `expectLater` 呼び出しの直後・最初の `add` の前に追加して購読確立の猶予を与えた。本番コード
  (`item_repository_impl.dart` の `watchAll`)は design.md のとおりで変更していない。

- `import 'package:drift/drift.dart'` と `flutter_test` が両方 `isNull` を公開しており、
  テストファイルで曖昧性エラーになる。`hide isNull` で解消した(**#5 以降で
  drift の型をテストに持ち込むときも同じ衝突が起きる**)

### 司令塔の申し送り

- **モード B(econ)のため検収(`/check` / `code-reviewer`)を回していない。** 機械的検証は
  CI の `quality` ジョブに預け、スペック整合のレビューは枠が戻ってからの一括レビューに回す。
  PR は draft で積む(`.claude/rules/mode/econ.md`)
- **委託禁止領域のチケットは、モード B でも司令塔セッション内で fork を回すことになる。**
  モード B の手順は「実装委託は人間がターミナルから `delegate-codex.sh` を叩く」前提だが、
  `lib/data/database/` と `lib/data/migrations/` は Codex に渡せないため経路が無い。
  **禁止領域チケットはモード B の節約効果が効かない**ことを、優先順位を決めるときに織り込む
- **#3 と同じ種類の欠陥が design.md に再発した。** 「計画に書いたコード片の具体値が、
  実際の実行環境では成立しない」形(#3 はタイムゾーン、今回は drift の Stream 購読タイミング)。
  **計画に実行順序を含むコード片を書くときは、非同期の確立待ちまで書き切る。**
  今回は fork が 1 回の往復内で自力回避できたため差し戻しは発生していない
