# タスクリスト: 紙の質感を画面イメージに合わせる(Issue #57)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること。** 未完了タスク(`[ ]`)を残したまま終了しない。
スキップは技術的理由がある場合のみ `- [x] ~~タスク名~~(理由)` の形で残す。

---

## フェーズ1: 紙の描画(design.md §1 / §2-1)

- [x] `aged_paper.dart` に `paintPaperFibers` と定数を追加する(§1-1 / §1-2 の定数)
- [x] `_PaperParameters` を §1-2 の表に置き換える
- [x] `AgedPaperPainter.paint` を §1-3 の層の順で書き直す(斑・繊維と斑点・不定形のシミと輪染み・ぼかした縁の焼け)
- [x] `AgingPalette` の `stain` を明暗とも不透明度 0x1A にする(§2-1)

## フェーズ2: 背景の紙(design.md §2-2〜§4)

- [x] `AppTheme._build` に `scaffoldBackgroundColor` と `appBarTheme` を足し、doc コメントを更新する(§2-2 / §2-3)
- [x] `lib/ui/widgets/paper_background.dart` を作る(§3)
- [x] `HomeShell` / `ItemAddScreen` / `ItemEditScreen` / `CategoryManageScreen` の根を `PaperBackground` で包む(§4)

## フェーズ3: テスト(design.md §5)

- [x] `aged_paper_contrast_test.dart` を作る(カード全ステージ × 明暗 × 2 サイズ × 16 シード + 背景)(§5-1)
- [x] 落ちたら §7 の手順を適用する(適用した段と最小値を下の振り返りに記録) — **heavilyAged は3段目まで適用しても4.5未満のまま。司令塔判断待ち(振り返り参照)**
- [x] `aged_paper_test.dart` に `paintPaperFibers` の例外なしテストを足す(§5-2)
- [x] `app_theme_test.dart` に Scaffold 背景と AppBar 背景のテストを足す(§5-2)
- [x] `paper_background_test.dart` を作る(§5-2)
- [x] 各ルートの根に `PaperBackground` がある検査を足す(§5-2)
- [x] `aged_paper_preview_test.dart` を作る(§5-3)
- [x] design.md §8 を適用する(§7 の値を戻す・`burnSigma` を 2 に・シミを丸く柔らかく)

## フェーズ4: 検証(design.md §6)

- [x] `dart format --output=none --set-exit-if-changed .` が通る
- [x] `flutter analyze --fatal-infos` が通る
- [x] design.md §9 を適用する(欠けを小さく・焼けは欠ける前の輪郭に・切り口に細い焼け・heavilyAged の burnWidth 6・失敗時に座標を出す)
- [x] design.md §10 を適用する(斑は saveLayer で重ねても濃くしない・斑点 0.06・heavilyAged の斑 0.04)
- [x] `flutter test` が全件通る(`performance_test.dart` を含む)— §10 適用後、全件 green(All tests passed!)
- [x] `PAPER_PREVIEW=1 flutter test test/ui/widgets/aged_paper_preview_test.dart` で PNG が 2 枚できる

## フェーズ4b: 古びを強くする(design.md §11)

- [x] `AgingPaperColors` に `burn` を足し、明暗 5 ステージの値を入れる(§11-1)
- [x] 焼け 2 本の色を `colors.burn` に替え、`burnOpacity` を上げる(§11-2 / §11-3)
- [x] format / analyze / test 全件が通る(落ちたら §11-4)
- [x] `paper_background_test.dart` に RepaintBoundary の検査を足す(§11-7)
- [x] プレビュー PNG を生成し直す

## フェーズ5: 見た目の確認とドキュメント(司令塔)

- [x] プレビュー画像を画面イメージ下段の見本と見比べ、ユーザーに提示する(1 回目「古びをもっと強く」→ §11 → 2 回目で確定)
- [x] `docs/functional-design.md`「色の使い方」の「紙の表現」列と背景の紙を実装に合わせて改める

---

## 実装後の振り返り

### design.md §8 を適用しても heavilyAged のコントラストが4.5を割る(判断済み・§9 で対応)

§8 の手順1〜3を適用した時点での測定値は次のとおりだった(§9 適用前の状態):

| ステージ/テーマ/サイズ | 適用前(§7 3段目時点) | §8 適用後 |
| --- | --- | --- |
| light heavilyAged 336×72 | 3.8412 | 3.4539 |
| light heavilyAged 112×140 | 3.7044 | 3.3991 |
| dark heavilyAged 336×72 | 4.4474 | 4.1497 |
| dark heavilyAged 112×140 | 4.2943 | 4.1325 |

この結果を受け、司令塔が design.md §9 で「律速は角丸ではなく heavilyAged だけの隅の欠け(chips)」と判断し、欠けを小さくする・焼けを欠ける前の輪郭に描く・欠けの切り口に細い焼けを足す・`burnWidth` を6にする、の対応を指示した。

### design.md §9 を適用しても heavilyAged の一部が4.5を割る(司令塔判断待ち)

§9 の手順1〜4(欠けの脚を8〜12pxに・焼けを`burnOutline`基準に・欠けの切り口に幅6/sigma1の焼けを追加・`burnWidth`を6に)を適用済み。座標付きで再検証した結果:

| ステージ/テーマ/サイズ | §8 適用後 | §9 適用後 | 座標(§9 適用後の最小値位置) |
| --- | --- | --- | --- |
| light heavilyAged 336×72 | 3.4539 | 4.4155(onSurfaceVariant) | (86, 35) |
| light heavilyAged 112×140 | 3.3991 | 4.3312(onSurfaceVariant) | (51, 52) |
| dark heavilyAged 336×72 | 4.1497 | **4.5 以上(green)** | — |
| dark heavilyAged 112×140 | 4.1325 | 4.4502(onSurfaceVariant) | (42, 61) |

いずれも `onSurface` とのコントラストは 4.5 以上を満たしており、割っているのは `onSurfaceVariant`(カテゴリなど二次テキスト色)側だけ。4値とも 4.5 まであと 0.05〜0.17 まで詰まっている(§8 時点の 1.0〜1.3 差から大幅に改善)。

**司令塔への判断依頼**: design.md §9 手順6「それでも落ちる場合は、値をいじらずに止めて、ステージ×明暗×サイズごとの最小値と座標を報告する」に該当したため、コードは§9の指示どおり(1〜4適用済み)で止めてある。`heavilyAged` の `edge`(縁色)・`burnOpacity`・座標が示す位置(欠けの切り口付近)の焼けの追加幅(手順3で足した幅6/alpha=burnOpacityの帯)のいずれを調整するかは設計判断が必要。

`flutter test` はこの3本以外すべて green(768件中765 pass・1 skip=`aged_paper_preview_test.dart`(`PAPER_PREVIEW`未設定)。`PAPER_PREVIEW=1`でのプレビュー生成は別途実施し PNG 2枚を再生成済み)。

上記以外のタスク(背景・ルート・既存テスト・プレビュー)は完了している。

### design.md §10 適用後(解決)

司令塔の判断(斑の重なりで濃くなる問題)どおり §10 の3点を適用した結果、`aged_paper_contrast_test.dart` は全22本 green(heavilyAged 含む)。`flutter test` も全件 green(`All tests passed!`)。`PAPER_PREVIEW=1` でのプレビュー PNG 2 枚も再生成済み(`build/paper_preview/paper_light.png` / `paper_dark.png`)。フェーズ4まで全タスク完了。フェーズ5(見た目確認・docs 更新)は司令塔担当のため未着手のまま残す。

### design.md §11 適用後(解決・§11-4 は不要)

`AgingPaperColors` に `burn` を追加(明暗5ステージぶん §11-1 の表どおり)、焼け2本(`burnOutline` と欠けの切り口)の色を `colors.edge` から `colors.burn` に差し替え、`burnOpacity` を §11-3 の表(slightlyAged 0.45 / dueSoon 0.65 / aged 0.80 / heavilyAged 0.90)に上げた。`paper_background_test.dart` に RepaintBoundary 検査(§11-7)を追加。`AgingPaperColors` を直接組み立てるテストは既存になし(§11-5 は該当なしで対応不要)。

`format` / `analyze` / `flutter test`(772件、全 green)は §11-4 の値調整なしで一度で通った(heavilyAged のコントラスト最小値も4.5以上を維持)。プレビュー PNG 2枚も再生成済み。フェーズ4b まで全タスク完了。フェーズ5(見た目確認・docs 更新)は司令塔担当のため未着手のまま残す。

### 司令塔の振り返り(2026-09-27)

- **実装完了日**: 2026-09-27
- **計画と実績の差分**:
  - fork の往復は 5 回(初回 + 判断待ち 3 回 + 見た目の調整 1 回)。判断待ちはすべて heavilyAged のコントラスト(onSurfaceVariant 4.5:1)で、原因の特定が 2 回ずれた(角丸の集中 → 隅の欠け → **層の重なり**が正解)
  - 「装飾は 1 回で塗って濃さを積み上げない」(判断 C)を斑にだけ適用し忘れていた。斑は円ごとにぼかしが違うため個別に塗り、重なりで濃くなっていた → `saveLayer` で 1 回に(§10)
  - ユーザーの見た目判断で、焼けを専用色 `burn` に分け不透明度を上げた(§11)。内側の濃さは制約で上げられないため、テキストが載らない縁の帯で古びを出す
  - 背景の紙は `MaterialApp.builder` ではなくルートごとの `PaperBackground` にした(遷移中に透明な Scaffold が重なるため)
  - 計画時に「Picture をキャッシュ」とユーザーに説明したが、カードごとに描いて各項目の RepaintBoundary に任せる形にした(寿命管理が要らず、性能テストも通る)
- **学んだこと・申し送り**:
  - **コントラストの失敗は、座標を出させてから原因を決める。** 最初から最小値の座標を報告させていれば、往復は 1 回で済んだ。合成式の試算(4.416)は実測(4.4155)と一致したので、層を足すときは先に最悪値を試算する
  - #58 の「記録の詳細」画面の紙のカードは `AgedPaperPainter` をそのまま使えば質感が揃う。新しいルートの根には `PaperBackground` を置くこと(`Scaffold` の背景は透明)
  - 見た目の確認は `PAPER_PREVIEW=1 flutter test test/ui/widgets/aged_paper_preview_test.dart`(`build/paper_preview/`)
