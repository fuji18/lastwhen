# 要件: プロジェクトキックオフ(Flutter 化)

## 背景

`claude-code-template` から作成した `lastwhen` リポジトリを、`docs/ideas/initial-requirements.md`
に書かれたアイデア(生活行動の最終実施日を記録するモバイルアプリ「最後にいつ」)の
開発リポジトリとして立ち上げる。

テンプレート既定のスタックは Node.js 24 / TypeScript 6 / vitest / eslint / prettier だが、
本プロダクトは iOS / Android 両対応のモバイルアプリであり、Flutter を採用する。

## 確定した決定(/kickoff フェーズ0〜1 でユーザー承認済み)

| 項目 | 決定 |
| --- | --- |
| プロダクト名 | 「最後にいつ」(英語表記 LastWhen) |
| フロントエンド | Flutter / Dart |
| ローカル DB | Drift(SQLite 上の型安全 ORM) |
| バックエンド | MVP では使用しない(端末内完結) |
| 認証 | MVP では実装しない |
| リポジトリ可視性 | public(ルールセットを無料で使うため) |
| ブランチ保護 | ルールセット `protect-main` を作成済み |
| ハーネスの Node | 削除せず最小構成で残す(husky / lint-staged / secretlint) |

## スコープ

### やること

1. 技術スタックの置換(TypeScript ツールチェーン → Flutter / Dart)
2. CI・ハーネス・devcontainer の npm 前提部分を Flutter に合わせる
3. ガードレール(保護ブランチ検査 3 層・secretlint)を維持したまま置換する
4. リポジトリのプロダクト化(README / package.json / devcontainer 名 / ライセンス / CLAUDE.md)

### やらないこと

- アプリ本体の実装(P0 チケットとして別途起票する)
- P1 / P2 機能の先行実装
- クラウド同期・認証まわりの準備

## 非機能上の制約

- **ガードレールの層を減らさない。** 保護ブランチ検査は強制 3 層 + 情報提供 1 層、
  機密検出は pre-commit と CI の 2 層を維持する
- CI の 3 ジョブ名(`branch-policy` / `harness-integrity` / `quality`)は変えない
  —— ルールセットの required status checks が context 名で紐づいているため
