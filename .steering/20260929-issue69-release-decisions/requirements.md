# 要求: 公開前の決定事項の確定(Android 先行 / Issue #69)

## 背景

Android を先に公開する。PRD「未決事項」のうち Android の公開に要るものを確定し、公開後は変えられない applicationId を決める。iOS に関わる決定(Bundle ID など)は #75(`on-hold`)の範囲で、ここでは触らない。

## ユーザーの決定(2026-09-29)

| 論点 | 決定 |
| --- | --- |
| 未決事項 #1 収益化 | **まだ決めない。** 初回公開は PRD の MVP 方針どおり無料・広告なしで出す |
| 未決事項 #2 同時リリース | **Android を先に公開し、iOS は後から**(#75 / #76 を `on-hold` にしてある) |
| 未決事項 #3 ストア掲載名 | **「LastWhen — 最後にいつ」**。ホーム画面のアプリ名(`android:label`)とアプリ内の表記は `LastWhen` のまま |
| applicationId | **`com.github.fuji18.lastwhen`**(現在の `com.lastwhen.lastwhen` から変える) |
| Play Console のアカウント | **組織**。個人アカウントに課されるクローズドテストの要件(12 人以上・14 日間)はかからない。D-U-N-S 番号が要る |

## 要求

| # | 要求 | 出典 |
| --- | --- | --- |
| R1 | PRD「未決事項」#1 / #2 / #3 を決定(#1 は「初回公開の扱いだけ決定・方針は未決」)と理由つきで更新する | Issue 受け入れ条件 1 |
| R2 | applicationId を `com.github.fuji18.lastwhen` にし、`namespace` と `MainActivity` のパッケージを合わせる。`flutter test` と Android のデバッグビルドが通る | 受け入れ条件 2 |
| R3 | applicationId と Play Console のアカウント種別を `docs/architecture.md` に記録する | 受け入れ条件 2 / 3 |
| R4 | 連絡先メールアドレスは Issue コメントで共有し、リポジトリに書かない | 受け入れ条件 4(**人手の作業**) |

## スコープ外

- iOS の Bundle ID(`ios/Runner.xcodeproj/project.pbxproj` の `com.lastwhen.lastwhen`)は変えない。#75 で決める
- Play Console の登録そのもの(人手の作業)
- プライバシーポリシー(#70)・掲載情報(#73)
