#!/bin/bash
# PostToolUse(Edit|Write) async hook: Dart ファイルの編集後にフォーマット検査と解析を走らせる。
#
# 元の設計(TypeScript 版)の要点はそのまま引き継ぐ:
#   1. 検査は編集した 1 ファイルを起点にする。全体の結果をそのまま流すと、編集と無関係な
#      既存エラーが毎編集ごとにコンテキストへ載り、ファイル数に比例して太る
#   2. dart analyze はパッケージ全体を見る(Dart は型を 1 ファイルで決められない)が、
#      出力は編集ファイルの行だけ通し、それ以外は件数 1 行に畳む
#   3. 多重起動は flock で待ち合わせる。自前の mkdir ロックには (a) 実行中に入った編集を
#      無検査で捨てる (b) 強制終了でロックが孤立する の 2 つの穴がある。
#      flock はプロセスが死ねばカーネルが解放するので、この問題自体が消える。
#
# Dart 固有の差分:
#   - lint と型チェックは分離できない。dart analyze が両方を担う
#   - Flutter SDK が入っていない環境(devcontainer リビルド前)では黙って exit 0 する。
#     ハーネスはフェイルオープン設計で、層が消えたことより毎編集のエラー出力の方が害が大きい
set -uo pipefail

f="$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)"
[ -n "$f" ] || exit 0
case "$f" in
  *.dart) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Flutter SDK 未導入なら何もしない(フェイルオープン)
command -v dart >/dev/null 2>&1 || exit 0

LOCK=".claude/.lint-on-edit.lock"
LOCK_WAIT=100   # settings.json の hook timeout(120s)の内側に収める

root="$(realpath . 2>/dev/null || printf '%s' "$PWD")"

# 編集ファイル 1 本を検査する。プロジェクト外・削除済みのパスは黙って捨てる。
run_checks() {
  local target="$1" abs="" rel="" out="" mine="" mine_count=0 total=0

  # シンボリックリンク経由で $PWD と字面が食い違うと無検査になるため正規化する
  abs="$(realpath "$target" 2>/dev/null || printf '%s' "$target")"
  case "$abs" in
    "$root"/*) rel="${abs#"$root"/}" ;;
    /*) return 0 ;;
    *) rel="$abs" ;;
  esac
  [ -f "$rel" ] || return 0

  # フォーマット差分は編集ファイル 1 本だけを見る。
  # --output=none で書き換えず、差分があれば非ゼロで知らせる
  if ! dart format --output=none --set-exit-if-changed "$rel" >/dev/null 2>&1; then
    echo "format: $rel に未整形の差分があります(dart format \"$rel\" で整形)"
  fi

  # 解析はパッケージ単位。pubspec.yaml が無い = まだ Flutter プロジェクトになっていない
  [ -f pubspec.yaml ] || return 0

  out="$(dart analyze --no-fatal-warnings 2>&1)" || true
  [ -n "$out" ] || return 0

  # dart analyze の行は "  error - path/to/file.dart:12:3 - message - rule" の形。
  # 編集ファイルのパスを含む行だけ通す
  mine="$(printf '%s\n' "$out" | grep -F " $rel:" || true)"
  [ -z "$mine" ] || printf '%s\n' "$mine" | head -20

  total="$(printf '%s\n' "$out" | grep -cE '^[[:space:]]+(error|warning|info) - ' || true)"
  mine_count="$(printf '%s\n' "$mine" | grep -cE '^[[:space:]]+(error|warning|info) - ' || true)"
  if [ "$((total - mine_count))" -gt 0 ]; then
    echo "(このファイル以外に $((total - mine_count)) 件の指摘。全体は flutter analyze で確認する)"
  fi
}

# 先行プロセスの完了を待ってから検査する(スキップしない = 連続編集でも取りこぼさない)。
# 待ちきれなければこの回は諦める。hook の timeout に食い込ませて SIGKILL されるより行儀がよく、
# 検査は常にその時点の内容を読むので、後続の編集で検査される。
if command -v flock >/dev/null 2>&1; then
  if { exec 9>"$LOCK"; } 2>/dev/null; then
    flock -w "$LOCK_WAIT" 9 || exit 0
  fi
fi

run_checks "$f"
exit 0
