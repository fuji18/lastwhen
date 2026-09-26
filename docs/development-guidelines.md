# 開発ガイドライン (Development Guidelines)

## コーディング規約

### 命名規則

#### 変数・関数

- ローワーキャメルケース(`lastDoneAt`・`elapsedDays`)
- **真偽値は述語にする**: `isDone` / `hasRecord` / `canUndo`。`flag` や `status` にしない
- **単位を名前に入れる**: `intervalDays` であって `interval` ではない。
  日数と時刻を取り違える事故がこのアプリでは致命的
- 省略しない。`itm` ではなく `item`、`cnt` ではなく `count`
- `DateTime` を持つ変数は `〜At` で終える(`createdAt`・`lastDoneAt`)。
  日付だけを表す場合は `〜Date`(`lastDoneDate`)と区別する

#### クラス・インターフェース

- アッパーキャメルケース(`ItemListNotifier`)
- **インターフェースに `I` を付けない**。Dart の慣習に反する。
  実装側に `Impl` を付ける(`ItemRepository` / `ItemRepositoryImpl`)
- sealed class の派生は状態そのものを名乗る(`NeverDone` / `Today` / `DaysAgo`)

#### 型で意味を守る

項目 ID を素の `String` で回さない。

```dart
extension type const ItemId(String value) {}
```

引数の取り違え(`rename(name, id)`)がコンパイルエラーになる。
**ID・名前・日数のように「同じ素の型を持つが混ぜてはいけない値」には型を付ける。**

### コードフォーマット

- **`dart format` の出力が正**。設定項目はなく、議論もしない
- 行長は `dart format` の既定(80 桁)に従う
- 保存時に自動整形される(devcontainer の設定と PostToolUse hook)
- CI は `dart format --output=none --set-exit-if-changed .` で検査する

### コメント規約

**書くのは「なぜ」だけ。「何を」はコードが語る。**

```dart
// ❌ 悪い例: コードを読めば分かる
// lastDoneAt をローカル時刻に変換する
final last = lastDoneAt.toLocal();

// ✅ 良い例: 判断の理由が書いてある
// ローカルの DateTime 同士の difference は実時間差になる。DST のある地域では
// 1 日が 23/25 時間になり inDays がずれるため、暦日を UTC 上の点として持ち直す。
final lastDate = DateTime.utc(last.year, last.month, last.day);
```

- 公開 API には dartdoc(`///`)で**責務と制約**を書く
- **却下した選択肢を書き残す**。「なぜ A ではなく B にしたか」は、
  半年後の自分が同じ議論を繰り返さないための唯一の防御
- TODO コメントには Issue 番号を添える(`// TODO(#12): ...`)。番号のない TODO は残さない

### エラーハンドリング

**原則: 失敗を成功に見せない。**

| 状況 | 扱い |
| --- | --- |
| 入力バリデーション | 例外にしない。結果型で返し、呼び出し元が表示する |
| DB 書き込み失敗 | 例外を捕捉し、**状態を変更せず**にユーザーへ伝える |
| 想定外の例外 | 握りつぶさない。`catch (_) {}` を書かない |
| 到達しないはずの分岐 | `throw StateError` で落とす。黙って既定値を返さない |

```dart
// ❌ 悪い例: 失敗が成功に見える
try {
  await repository.markDone(id, now);
} catch (_) {}

// ❌ 悪い例: 一覧そのものが消える
// state は AsyncNotifier<List<ItemView>>。エラーにすると UI は一覧を失い、
// 「保存失敗時も行は元の値のまま」という要件を満たせない。
try {
  await repository.markDone(id, now);
} on Exception catch (e, s) {
  state = AsyncError(e, s);
}

// ✅ 良い例: 一覧は触らず、失敗を別チャネルへ持ち上げる
try {
  await repository.markDone(id, now);
} on Exception catch (e, s) {
  _log.warning('markDone failed', e, s);
  // 一覧は watchAll() の購読結果だけを反映させる。state は変更しない。
  ref.read(writeErrorProvider.notifier).state = '保存できませんでした。もう一度お試しください';
}
```

**`state` を `AsyncError` にしてよいのは、一覧そのものを表示できない場合だけ**
(DB オープン失敗・購読の切断)。個々の書き込み失敗では state を触らない。

- **楽観的 UI 更新を採らない。** 書き込み成功を待ってから画面を変える。
  ローカル SQLite では 100ms 要件を満たせる(技術仕様「パフォーマンス制約」)
- ユーザー向けメッセージに例外の文言・スタックトレースを出さない
- リリースビルドで項目名をログに出さない

## Git運用ルール

### ブランチ戦略

**単一ソースは `.claude/branch-policy.json`。** 以下は人間向けの説明で、
値が食い違ったらポリシーファイルが正。

| 項目 | 値 |
| --- | --- |
| 戦略 | GitHub Flow(`main` 単一) |
| ベースブランチ | `main` |
| 保護ブランチ | `main` |
| 使えるプレフィックス | `feature/` `fix/` `release/` `hotfix/` `claude/` `dependabot/` |

**`main` で直接作業しない。** 強制は 3 層 + 情報提供 1 層:

| 層 | 実体 | 効く範囲 |
| --- | --- | --- |
| 情報提供 | SessionStart hook | Claude セッションの開始時に現在地を表示 |
| 強制1 | PreToolUse hook | Claude 経由の操作のみ |
| 強制2 | `.husky/pre-commit` | `git commit` / `--amend`。**ベンダー非依存** |
| 強制3 | `.husky/prepare-commit-msg` | `git revert` / `git cherry-pick`。`--no-verify` で迂回できない |
| 最終検証 | CI の `branch-policy` ジョブ | PR の base とブランチ名 |

さらに GitHub のルールセット `protect-main` が、直接 push の禁止・PR 必須・
force push と削除の禁止・required status checks(`branch-policy` / `harness-integrity` /
`quality`)を強制する。**bypass list は空**で、リポジトリ管理者も迂回できない。

### コミットメッセージ規約

Conventional Commits に従う。

```
<type>: <日本語の要約>

<本文: なぜこの変更が要るのか。何をしたかではなく>

Co-Authored-By: ...
```

| type | 用途 |
| --- | --- |
| `feat` | 機能の追加 |
| `fix` | バグ修正 |
| `refactor` | 挙動を変えない内部変更 |
| `test` | テストの追加・修正 |
| `docs` | ドキュメントのみ |
| `chore` | ビルド・依存・ハーネス |
| `perf` | パフォーマンス改善 |

- 要約は 50 文字程度。**何をしたかではなく、何が変わるか**を書く
- 本文に「なぜ」を書く。差分を見れば分かることを繰り返さない
- 1 コミット 1 論点。無関係な変更を混ぜない

### プルリクエストプロセス

1. `feature/` ブランチを切る
2. 実装し、`/check` で lint・解析・テストを通す
3. PR を作る。ボディに `Closes #N` を書く(マージ時に Issue が自動で閉じる)
4. CI の 3 ジョブ(`branch-policy` / `harness-integrity` / `quality`)が通るまでマージしない
5. `main` 向け PR のオープン時に Claude の自動レビューが 1 回だけ走る

**PR ボディのテンプレート**は `.github/pull_request_template.md` にある。
「検証」節には実際に回した検査だけをチェックする。回していないものにチェックを付けない。

### 記録の義務(CI が検査する)

| 検査 | 落ちる条件 | 逃げ道ラベル |
| --- | --- | --- |
| CHANGELOG | `.claude/` `.husky/` `.codex/` `.github/workflows/` `AGENTS.md` を変更した PR で `docs/template-dev/CHANGELOG.md` が未更新 | `no-changelog` |
| decisions.jsonl | `ticket` ラベル付き Issue を `Closes #N` で閉じる PR に対応する行が無い | `no-decision-record` |

逃げ道ラベルは理由を添えて付ける。既定の回避手段ではない。

## テスト戦略

### テストの種類

#### ユニットテスト

- **対象**: `lib/domain/` 全体、`lib/state/`(リポジトリをフェイクに差し替える)
- **カバレッジの目安**: ドメイン 100%、状態管理 80% 以上。
  **CI では検査しない**(`quality` ジョブは `flutter test` のみ)。数値は目安であり、
  合否の判定はレビューが行う —— **ドメインの分岐にテストが無い変更は通さない**
- **速度**: Flutter に依存しないため数ミリ秒で回る。実装中に繰り返し回す前提

**必ず書くもの**:

```dart
group('経過日数の算出', () {
  test('同じ日なら 0 日', () { ... });
  test('日付をまたぐと 24 時間未満でも 1 日', () { ... });
  test('月末をまたぐ', () { ... });
  test('うるう年の 2月28日 → 3月1日 は 2 日', () { ... });
  test('年をまたぐ', () { ... });
  test('夏時間の切替日をまたいでも暦日どおり', () { ... });
  test('端末時計が巻き戻っても負数を返さない', () { ... });
});
```

> **経過日数のテストは削らない。** これがプロダクトの中心ロジックで、
> 壊れてもクラッシュせず「静かに 1 日ずれる」形で出る。テストでしか気づけない。

#### レイヤー依存の検査

レイヤー違反は静かに増えるため、レビューではなくテストで止める。
`test/architecture/layer_dependency_test.dart` が `lib/` のソースを読み、
禁止された import が無いことを確認する(**追加依存は使わない**)。

```dart
test('domain は Flutter / Drift / Riverpod に依存しない', () {
  final files = Directory('lib/domain')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final f in files) {
    final src = f.readAsStringSync();
    for (final banned in const [
      "import 'package:flutter/",
      "import 'package:drift/",
      "import 'package:flutter_riverpod/",
    ]) {
      expect(src, isNot(contains(banned)), reason: f.path);
    }
  }
});
```

`ui → data` の禁止も同じ形で書く。`flutter test` で回るので、CI の `quality` ジョブが
そのまま最終ゲートになる。

#### 統合テスト

- **方法**: Drift のインメモリ DB(`NativeDatabase.memory()`)
- **対象**: リポジトリ実装の CRUD 一巡、記録と取り消し、100 件投入、
  **旧バージョンのスキーマからのマイグレーション**
- スキーマを変更する PR では、移行テストを必ず追加する

#### ウィジェットテスト

- **対象**: 一覧の空状態、「やった」タップで確認ダイアログが出ないこと、
  取り消し導線(4 秒間・直近 1 件のみ)、保存失敗時に一覧が消えないこと、
  削除の確認、フォントサイズ 200% でのレイアウト
- 通常操作の画面 3 つの主要導線を覆う。網羅は狙わない(起動失敗のエラー画面は対象外)

#### E2E テスト

**MVP では書かない。** ウィジェットテストで主要導線を覆えるため、
`integration_test` の維持コストが見合わない。P1 で通知が入る段階で再検討する。

### テスト命名規則

- グループ名は「何の話か」(`group('経過日数の算出', ...)`)
- テスト名は「条件 → 期待」を日本語の 1 文で
  (`test('日付をまたぐと 24 時間未満でも 1 日', ...)`)
- `should` や `test1` のような中身のない名前を使わない

### モック・スタブの使用

- **モックライブラリを入れない。** 手書きのフェイクで足りる規模
- フェイクは `test/support/` に置く(`FakeClock`・`FakeItemRepository`)
- **`Clock` は必ず差し替える。** テスト内で `DateTime.now()` を呼ぶと、
  実行した瞬間によって結果が変わるテストになる

## パフォーマンス計測手順(実機)

**devcontainer では実機性能を測れない。** Android 端末・エミュレータ・`adb` が無く、
検出されるのは Linux desktop のみ。デバッグビルドは遅いため、以下の基準は
**リリースビルド**で測る(`docs/product-requirements.md`「非機能要件 / パフォーマンス」)。

| 計測項目 | 基準 |
| --- | --- |
| コールドスタートから一覧表示 | 1.5 秒以内 |
| 「やった」から画面反映 | 100ms 以内 |
| 100 件の一覧スクロール | フレーム落ちなし |
| 100 件の初回描画 | 300ms 以内 |

1. ミドルレンジ Android 実機を USB 接続する。
2. `flutter build apk --release` でリリースビルドを作る。
3. 項目 20 件・100 件の 2 条件を用意する。
4. アプリを終了した状態から `flutter run --release --trace-startup` で起動時間を測る。
5. 「やった」操作と一覧スクロールを行い、DevTools のタイムラインで画面反映と
   フレーム時間を確認する。

**結果は PR ボディに、計測環境(端末名 / OS バージョン / ビルド種別)とともに記載する。**
項目数と各計測値を併記し、基準を満たしたか分かるようにする。

devcontainer で回せる代替は `test/ui/performance_test.dart`。
遅延生成・クエリ本数を検証し、初回描画の参考時間を `[perf]` 付きで出力する。
この値はデバッグ JIT とホスト性能の影響を受け、**実機基準の代わりにはならない**。
参考時間の assert は 5 秒の安全網のみとし、PR ボディでも実機計測値と区別する。

## コードレビュー基準

### レビューポイント

優先度の高い順:

1. **経過日数と日時の扱い** —— タイムゾーン・暦日・境界条件。ここの誤りは静かに出る
2. **データの消失リスク** —— マイグレーション、削除、書き込み失敗時の扱い
3. **レイヤー違反** —— `ui` から `data` を直接触っていないか、`domain` が何かに依存していないか
4. **失敗の隠蔽** —— `catch (_) {}`、握りつぶし、失敗時に画面だけ更新していないか
5. **スコープ** —— チケットと `design.md` に無い機能を足していないか(P1/P2 の前倒し)
6. **UI 品質** —— `docs/ui-design-guidelines.md` §6 のチェックリスト。
   タッチターゲット、コントラスト、色だけに頼っていないか、文字サイズ 200%
7. **テストの有無** —— ドメインロジックの変更にテストが付いているか

### レビューコメントの書き方

```
## ✅ 良い例
`elapsedDays` が `inDays` を正規化前の DateTime に対して使っています。
夏時間のある地域(このアプリは日本語のみですが、端末のタイムゾーンは
ユーザーが自由に設定できます)で 1 日ずれます。
`functional-design.md` のステップ2 のとおり深夜 0 時へ正規化してください。

## ❌ 悪い例
ここバグってます
```

- **何が問題か・なぜ問題か・どう直すか**の 3 点を書く
- 根拠になるドキュメントの節を指す
- 好みの問題は「好みですが」と明示し、ブロッカーと区別する

## 開発環境セットアップ

### 必要なツール

| ツール | バージョン | 備考 |
| --- | --- | --- |
| Docker / Dev Containers | — | devcontainer で開く前提 |
| Flutter | stable | `post_create.sh` が `/opt/flutter` に入れる |
| Node.js | 24 | devcontainer feature。ハーネス専用 |
| JDK | 17 | Android Gradle Plugin の要求 |
| Xcode | 最新 | **iOS ビルドのみ。macOS が必要で devcontainer では動かない** |

### セットアップ手順

```bash
# 1. リポジトリをクローンし、devcontainer で開く
#    postCreateCommand が Flutter・ハーネス依存・Claude Code・Codex CLI を入れる

# 2. Dart 依存を取得する
flutter pub get

# 3. Drift の生成物を作る(スキーマを変えたときも同じ)
dart run build_runner build --delete-conflicting-outputs

# 4. 検証が通ることを確かめる
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

**git hook が効いているかの確認**:

```bash
git config core.hooksPath   # .husky/_ が返れば有効
```

空なら `npm ci` を実行する。これが無いと保護ブランチ検査と機密検出が動かない。

### iOS ビルドについて

**devcontainer では iOS をビルドできない。** Linux コンテナに Xcode を置けないため。

| 作業 | 環境 |
| --- | --- |
| ユニット / ウィジェットテスト | devcontainer |
| 静的解析・フォーマット | devcontainer |
| Android ビルド・実機確認 | devcontainer(USB 接続は要ホスト設定) |
| iOS ビルド・実機確認・ストア申請 | **macOS + Xcode** |

ストア申請の準備段階までに macOS 環境を確保する必要がある。
これはリリース計画上の制約として残っている。

## 開発フロー

```
/next-ticket           # 次のチケットを選び、design.md まで書く
  ↓
実装(委託)            # Codex または implement-ticket の fork
  ↓
/check                 # lint・解析・テストを一括実行
  ↓
code-reviewer          # スペック整合とコード品質のレビュー
  ↓
/commit → push → PR    # Closes #N を書く
  ↓
CI(3 ジョブ)+ Claude 自動レビュー
  ↓
マージ → /clear → 次のチケットへ
```

**司令塔(メインセッション)は実装コードを書かない。** PreToolUse hook が
Edit/Write をブロックする。設計は `design.md` に書き切り、実装は委託する。

チケット完了(PR 作成)前に `.harness/decisions.jsonl` へ 1 行追記する。
マージ後に回すと記録そのものが落ちる。
