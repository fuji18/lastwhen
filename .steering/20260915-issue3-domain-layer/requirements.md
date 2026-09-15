# 要求: ドメイン層(Item・項目名の検証・経過日数の算出)

対象 Issue: #3(P0 / フェーズ1)
根拠: `docs/functional-design.md`「データモデル定義」「コンポーネント設計」「アルゴリズム設計」「テスト戦略」/ `docs/glossary.md`「経過日数の算出」「表記ゆれの禁止一覧」/ `docs/architecture.md`「ドメインレイヤー」/ `docs/development-guidelines.md`「エラーハンドリング」「テスト戦略」

## 背景

「最後にやったのは何日前か」の算出はこのプロダクトの中心価値そのもの。壊れてもクラッシュせず
「静かに 1 日ずれる」形で出るため、テストでしか気づけない。UI・データ層より先に純 Dart の
ドメイン層として切り出し、境界条件を網羅したテストで固める。

## スコープ(やること)

| 成果物 | 内容 |
| --- | --- |
| `lib/domain/item.dart` | `Item` エンティティ、`ItemId`(extension type) |
| `lib/domain/item_name.dart` | 項目名の検証。**例外を投げず結果型で返す** |
| `lib/domain/clock.dart` | `Clock` インターフェースと `SystemClock` |
| `lib/domain/elapsed_days.dart` | `elapsedDays` / `calendarDateOf` / `ElapsedLabel` と分類関数 |
| `lib/domain/item_repository.dart` | リポジトリの**インターフェースのみ** |
| `test/domain/` | 上記すべてのテスト |
| `test/support/fake_clock.dart` | 任意の時刻を返す `Clock` のフェイク |
| `test/architecture/layer_dependency_test.dart` | `lib/domain/` の import 依存を検査(受け入れ条件1の機械的検証) |

## スコープ外(やらないこと)

- Drift・SQLite・永続化(#4)
- Riverpod の Provider 定義・`ItemView`・`ItemListNotifier`(#5)
- 表示用の文字列整形(`42日前` の組み立ては UI 層の責務)
- 目安期間・状態判定・履歴(P1)
- `lib/ui/` → `lib/data/` の依存検査(検査対象のコードがまだ無い。#5 以降で同ファイルに追記する)

## 受け入れ条件(Issue #3 より)

- [ ] `lib/domain/` が Flutter・Drift・Riverpod のいずれにも import 依存していない(純 Dart)
- [ ] `elapsedDays` が両方の日時をローカル時刻に変換し、**暦日を `DateTime.utc` の点として取り直してから**差を取る
- [ ] 境界の全ケースがテストされている(同日 / 24 時間未満で 1 日 / 今日 23:59 / 月またぎ / うるう年 / 年またぎ / 夏時間 / 巻き戻し)
- [ ] `ElapsedLabel` が `NeverDone` / `Today` / `Yesterday` / `DaysAgo` に分類される
- [ ] `lastDoneAt` が null のとき `NeverDone` になる
- [ ] 項目名の検証: 空・空白のみは不可 / 前後の空白をトリム / トリム後 1〜50 文字 / 51 文字は不可
- [ ] ドメイン層のテストカバレッジが 100%
- [ ] `flutter analyze --fatal-infos` が通る

## 制約

- **追加依存を入れない**(モックライブラリも含む。フェイクは手書き)
- 用語は `docs/glossary.md`「表記ゆれの禁止一覧」に従う(項目 / 記録する / 最終実施日 / 経過日数 / 未実施)
- テスト内で `DateTime.now()` を呼ばない(唯一の例外は `SystemClock` 自体のテスト。design.md 判断6)
- `dart format` の出力が正(80 桁)
