# 設計: Flutter プロジェクトの初期化とテーマ設定(#2)

<!-- status: ready -->

## この設計で確定させた判断(実装者は判断しない)

### 判断1: `flutter_riverpod` は `^3.4.3` を使う(`docs/architecture.md` の `^2.x` を改訂する)

`/kickoff` 時点の `docs/architecture.md` は `^2.x` と書いているが、pub.dev の最新は **3.4.3**
(`sdk: ^3.12.0` / `flutter: >=3.0.0`。本環境は Flutter 3.47.4 / Dart 3.13.3 で満たす)。
Riverpod 2 系は後継メジャーが出ている状態で、**Riverpod のコードが 1 行も無い今が乗り換えの最安値**。
2 系で始めると #3 以降で書いた Notifier/Provider をまるごと移行することになる。

→ `pubspec.yaml` は `^3.4.3`。`docs/architecture.md` の 2 箇所(テクノロジースタック表・依存関係管理表)を
タスクリストの指示どおり書き換える。

### 判断2: `sqlite3_flutter_libs` を `sqlite3` に置き換える(同上)

`sqlite3_flutter_libs` の最新は **`0.6.0+eol`**、pub.dev の description が
`Not used anymore, update to version 3.x of package:sqlite3 instead`。**提供終了**している。
後継の `sqlite3` 3.6.0 は `hooks` / `code_assets` / `native_toolchain_c` による Dart のネイティブ
ビルドフックで SQLite 本体を各プラットフォームへ同梱する(android / ios / linux / macos / web / windows)。
`drift` 2.35.0 自身が `sqlite3: ^3.4.0` に依存しており、両者は同じメンテナ(simolus3)。

→ `pubspec.yaml` から `sqlite3_flutter_libs` を落とし、`sqlite3: ^3.6.0` を入れる。
**依存の総数は変わらない**(`docs/architecture.md`「供給網」の「表に挙げたものに限定する」を満たす)。

> **フォールバック(往復を避けるため事前に許可する)**: `flutter build apk --debug` が
> ネイティブビルドフック(code assets / native assets)起因で失敗した場合に限り、
> `sqlite3: ^3.6.0` を `sqlite3_flutter_libs: ^0.5.42`(eol 前の最終版)に戻してよい。
> その場合は **`design.md` のこの節に「フォールバックを適用した」と 1 行追記し、
> `docs/architecture.md` は `sqlite3_flutter_libs ^0.5.x` のまま変更しない**。
> それ以外の理由での依存の差し替え・追加は禁止(停止して報告する)。

### 判断3: テーマのシード色は `Color(0xFF2F6690)`(青系)1 つ

`docs/ui-design-guidelines.md` §7 が「シード色は 1 つだけ定義し、light / dark を同じシードから生成する」と
決めている。色そのものは未定だったのでここで確定する。

**青系を選ぶ理由**: MVP は状態を色で分けない(`docs/functional-design.md`「色の使い方」)が、
P1 の状態表示(F10)で「そろそろ / 経過」を**色 + ラベル/アイコン**で示す予定がある。
赤・橙・緑をシードに置くと、そのときブランド色と状態色の意味が衝突する。青系なら意味色を空けておける。

### 判断4: タイポグラフィは今回作り込まない

`docs/repository-structure.md` は `app_theme.dart` を「`ColorScheme.fromSeed` とタイポグラフィ」と
説明しているが、「経過日数が最大・最も太い」(§7)は**行ウィジェットの実物が無いと値を決められない**。
今回は `ColorScheme` だけを置き、`TextTheme` の実値は #5(一覧画面)で行を組むときに入れる。
推測で `TextTheme` を先に書かない。

### 判断5: 起動時の「空の画面」は `app.dart` 内の私有ウィジェットに置く

`lib/ui/screens/` にプレースホルダのファイルを作らない。#5 が `ItemListScreen` を作って
`home:` を差し替えるとき、**捨てるためだけのファイルが残らない**ようにする。

### 判断6: アプリの表示名は `flutter create` の生成値のまま

ストア掲載名(「最後にいつ」/ LastWhen)は `docs/product-requirements.md`「未決定リスト」#3 で
**未決定**。`android:label` / `CFBundleDisplayName` をここで決めない。
`MaterialApp` の `title` だけは Dart 側の識別子として `'LastWhen'` を置く(リポジトリ名・
パッケージ名と一致し、ストア掲載名の決定に影響しない)。

---

## 変更対象ファイル

| ファイル | 操作 | 備考 |
| --- | --- | --- |
| `pubspec.yaml` | 生成 → 編集 | 依存を下記の内容に置き換える |
| `pubspec.lock` | 生成 | **コミットする** |
| `analysis_options.yaml` | 生成 → 編集 | `exclude` を追加 |
| `lib/main.dart` | 上書き | 下記の内容そのまま |
| `lib/app.dart` | 新規 | 下記の内容そのまま |
| `lib/ui/theme/app_theme.dart` | 新規 | 下記の内容そのまま |
| `lib/domain/.gitkeep` `lib/data/.gitkeep` `lib/state/.gitkeep` | 新規 | 空ディレクトリを git に載せる |
| `test/widget_test.dart` | 上書き | 下記の内容そのまま |
| `android/` `ios/` | 生成 → 一部編集 | 最低 OS バージョン |
| `.github/workflows/ci.yml` | 編集 | 暫定ガードの削除 |
| `docs/architecture.md` | 編集 | 判断1・判断2 の反映 |
| `.metadata` | 生成 | そのまま |

**作らない / 触らない**: `web/` `linux/` `macos/` `windows/`、`lib/data/database/`、
`lib/data/migrations/`、`lib/ui/screens/`、`lib/ui/widgets/`、`test/architecture/`、
`README.md`、`.gitignore`(既存。`flutter create` が上書きしていないか必ず確認する)

---

## 手順

### 1. 雛形の生成

```bash
flutter create --org com.lastwhen --project-name lastwhen --platforms=android,ios .
```

生成後に **`git status` を見て `README.md` / `.gitignore` が変更されていないか確認する**。
変更されていたら `git checkout -- README.md .gitignore` で戻す(既存の内容が正)。

`web/` `linux/` `macos/` `windows/` が生成されていたら削除する(`--platforms` 指定で出ないはずだが確認する)。

### 2. `pubspec.yaml`

`flutter create` が生成したものをベースに、`dependencies` / `dev_dependencies` を以下に置き換える。
`environment:` の `sdk:` は生成された値のまま残す。`flutter:` セクション(`uses-material-design: true`)も残す。

```yaml
dependencies:
  flutter:
    sdk: flutter

  # ローカル DB(#4 で使う)
  drift: ^2.35.0
  # SQLite 本体。sqlite3_flutter_libs は提供終了につき後継の sqlite3 3.x を使う(design.md 判断2)
  sqlite3: ^3.6.0
  path_provider: ^2.1.6

  # 状態管理・依存注入
  flutter_riverpod: ^3.4.3

  # 項目 ID の採番
  uuid: ^4.6.0

  # 日付の日本語整形。Flutter SDK の解決に従うためバージョンを固定しない
  # (docs/architecture.md「依存関係管理」)
  intl: any

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Drift のコード生成(#4 で使う)
  build_runner: ^2.16.1
  drift_dev: ^2.35.0

  flutter_lints: ^6.0.0
```

- **`cupertino_icons` は入れない**(`flutter create` が既定で入れる。Material Symbols のみを使う方針 = `docs/ui-design-guidelines.md` §7 なので削る)
- `drift` と `drift_dev` は**同じバージョン**にする(`docs/architecture.md`)
- ここに無い依存を足さない

### 3. `analysis_options.yaml`

```yaml
# flutter_lints の推奨ルールを継承する。
# Dart は lint と型チェックが分離できないため、analyze が両方を担う
# (docs/architecture.md「開発ツール」)。CI は --fatal-infos で情報レベルも落とす。
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    # コード生成物。git では追跡するが(docs/architecture.md「生成コードの扱い」)、
    # 生成器の出力を lint の対象にはしない
    - "**/*.g.dart"
    - "**/*.drift.dart"
```

`linter:` セクションは置かない(追加ルールを増やす判断は今回していない)。

### 4. `lib/ui/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';

/// アプリ全体のテーマ。
///
/// 色は **1 つのシード色**から light / dark の両方を生成する
/// (`docs/ui-design-guidelines.md` §7)。ウィジェット側に生の色・余白・
/// タイポの値を書かず、必ず `Theme.of(context)` 経由で参照すること。
///
/// `TextTheme` の実値は一覧の行(#5)を組むときに決める。
abstract final class AppTheme {
  /// テーマのシード色。
  ///
  /// 青系を選んでいるのは、P1 の状態表示(F10)で「そろそろ / 経過」を
  /// 色 + ラベルで示す予定があり、赤・橙・緑を意味色として空けておくため。
  /// MVP は状態を色で分けない(`docs/functional-design.md`「色の使い方」)。
  static const Color seedColor = Color(0xFF2F6690);

  /// ライトテーマ。
  static ThemeData light() => _build(Brightness.light);

  /// ダークテーマ。
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
  );
}
```

### 5. `lib/app.dart`

```dart
import 'package:flutter/material.dart';

import 'ui/theme/app_theme.dart';

/// `MaterialApp` の組み立て。
///
/// ルーティングは画面が増える #5 以降で足す。`themeMode` は既定の
/// [ThemeMode.system] に任せ、端末の設定に追従させる。
class App extends StatelessWidget {
  /// アプリのルートウィジェットを作る。
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastWhen',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _PlaceholderHome(),
    );
  }
}

/// 一覧画面(#5)ができるまでの仮の画面。テーマだけが効いた空の画面を出す。
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
```

### 6. `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}
```

`main.dart` は起動だけを担う(`docs/repository-structure.md`「プロジェクト構造」)。
ここに初期化処理・Provider の定義を書かない。

### 7. レイヤーディレクトリ

`lib/domain/` `lib/data/` `lib/state/` に空の `.gitkeep` を置く(git は空ディレクトリを追跡しないため)。
`lib/ui/` は `theme/app_theme.dart` があるので `.gitkeep` は不要。

### 8. `test/widget_test.dart`

`flutter create` が生成したカウンターアプリのテストを、以下で**丸ごと置き換える**。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';

void main() {
  testWidgets('起動すると Material 3 のテーマが適用された空の画面が出る', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme?.useMaterial3, isTrue);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  test('light と dark が同じ 1 つのシード色から生成されている', () {
    expect(
      AppTheme.light().colorScheme,
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    );
    expect(
      AppTheme.dark().colorScheme,
      ColorScheme.fromSeed(
        seedColor: AppTheme.seedColor,
        brightness: Brightness.dark,
      ),
    );
  });
}
```

### 9. 最低 OS バージョン(`docs/architecture.md`「環境要件」: iOS 15 以上 / Android API 26 以上)

- **Android**: `android/app/build.gradle.kts` の `minSdk` を `26` にする
  (`flutter.minSdkVersion` を参照している行を `minSdk = 26` に置き換える)
- **iOS**: `ios/Flutter/AppFrameworkInfo.plist` の `MinimumOSVersion` と、
  `ios/Runner.xcodeproj/project.pbxproj` の **すべての** `IPHONEOS_DEPLOYMENT_TARGET` を `15.0` にする
- **`flutter create` の生成値が既に要件以上なら、下げずにそのまま残す**

### 10. `.github/workflows/ci.yml` の暫定ガード削除

`quality` ジョブから以下をまとめて消す。**それ以外の行は 1 行も変えない。**

- `- name: Check Flutter project presence` の step 全体(`id: probe` とその `run:` ブロック)
- `Setup Flutter` / `Install dependencies` / `Format check` / `Analyze` / `Test` の各 step に付いている
  `if: steps.probe.outputs.present == 'true'` の行(**5 行**)

`Setup Node.js` 以降(secretlint)は元から `if` が無い。触らない。

### 11. `docs/architecture.md` の反映(判断1・判断2)

**「フレームワーク・ライブラリ」表**:

- `sqlite3_flutter_libs` の行を次に置き換える
  - 技術: `sqlite3` / バージョン方針: `^3.x` / 用途: `SQLite 本体のバンドル` /
    選定理由: `Drift が各 OS で同一バージョンの SQLite を使うために要る。旧 sqlite3_flutter_libs は提供終了(0.6.0+eol)で、本体側のネイティブビルドフックに統合された`
- `Riverpod (flutter_riverpod)` の行のバージョン方針を `^2.x` → `^3.x` に変更する

**「依存関係管理」表**:

- `sqlite3_flutter_libs` の行を `sqlite3` に置き換える(用途・方針はそのまま「SQLite 本体」「キャレット」)
- 他の行は変更しない

**`CLAUDE.md` は変更しない**(パッケージ名を個別に列挙していないため)。

---

## 検証

```bash
flutter pub get
dart format .                                    # 整形してから
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter build apk --debug                        # 起動可能性の機械的な確認
```

- `dart format` は Dart 3.7 以降の新スタイル。**上のコード片は整形前の形なので、書き込んだあと必ず `dart format .` を通す**
- `flutter analyze --fatal-infos` は情報レベルの指摘も落とす。`public_member_api_docs` は
  `flutter_lints` に含まれないが、**指摘が出たら修正であって `// ignore:` で黙らせない**
- 上記のいずれかが**同じ原因で 2 回連続して直せなかったら停止して報告する**(`.claude/rules/spec-driven.md`)

## 停止して報告する条件

- `pubspec.yaml` に上記以外の依存を足したくなったとき
- 判断2 のフォールバック**以外**で依存のバージョンを変えたくなったとき
- `lib/data/database/` `lib/data/migrations/` にファイルを作る必要が出たとき(#4 の領域)
- `.github/workflows/ci.yml` で暫定ガード以外を変える必要が出たとき

---

## 検収で判明した追記(2026-09-15)

### `analysis_options.yaml` の `exclude` は Flutter SDK が自動で書き戻す

手順3 では `**/*.g.dart` / `**/*.drift.dart` の 2 つだけを指定したが、実物には
`build/**` / `android/**` / `ios/**` が足されている。これは実装者が独自に足したものではなく、
**`flutter analyze` を実行すると SDK が `Upgrading analysis_options.yaml to exclude build and
platform directories.` と出して自動追記する**(code-reviewer が 3 行を消して再実行し、
書き戻されることを実測で確認した)。

→ **この 3 行は消さない。** 消しても `flutter analyze --fatal-infos` は通るが、次に誰かが
`flutter analyze` を回した時点で同じ内容が戻り、差分だけが増える。手順3 の想定漏れであり、
実装の逸脱ではない。以降のチケットでこの 3 行を「design.md に無い」という理由で消さないこと。

### `pubspec.yaml` の `description`

`flutter create` の生成値 `"A new Flutter project."` が残っていたため、検収フェーズで
司令塔が `docs/product-requirements.md` 冒頭のタグラインに合わせて差し替えた。
**ストア掲載名(判断6)とは別物**で、`publish_to: 'none'` のため配布物にも出ない。
