# 設計: 委託禁止領域の抽出規約の違反を検出する(Issue #28)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **`.claude/scripts/` は委託禁止領域そのものなので Codex に委託しない**(`implement-ticket` の fork が書く)
> - `lib-forbidden.sh` はテンプレート所有。**このリポジトリで直す**(ユーザー決定)。上流への起票は司令塔が行うので実装者は触れない
> - 変更してよいファイルは判断7 の一覧だけ。Dart コード(`lib/` `test/`)は触らない

## 0. 全体像

```
AGENTS.md §4 マーカー内
  - `path` / `path2` — 説明(説明にバックティックを使わない)
    ^^^^^^^^^^^^^^^^^ ← ここ(箇条書きの、最初の " — " より前)のコードスパンだけを抽出する
                         それ以外の場所のコードスパンは抽出せず、警告を出す
```

抽出規則(判断1)と警告(判断2)を `lib-forbidden.sh` に入れ、`AGENTS.md` の地の文を規則に合わせて直す(判断3)。
直した後の `--print-forbidden` は警告 0 件・パスだけになる。

## 判断1: 抽出規則

マーカー(`<!-- kickoff:delegation-forbidden-paths -->` 〜 `<!-- /kickoff:delegation-forbidden-paths -->`)の内側の各行について:

| 行の種類 | 抽出の対象 | 警告 |
| --- | --- | --- |
| `- ` で始まる行(行頭。インデントなし)で ` — `(半角スペース + U+2014 + 半角スペース)を含む | **最初の ` — ` より前(= 見出し部)のコードスパン** | 見出し部のスパンが 0 個 → 過少 / パスに見えないスパン → 過剰寄り / ` — ` より後のスパン → 地の文 |
| `- ` で始まるが ` — ` を含まない | **行全体のコードスパン**(フェイルクローズ = 従来どおり抽出する) | 「説明ダッシュが無い」+ 上と同じ 2 種 |
| それ以外の行(見出し・空行・地の文) | 抽出しない | スパンがあれば地の文 |

- 「パスに見えない」の判定: `^[A-Za-z0-9._][A-Za-z0-9._/*-]*$` に一致し、**かつ** `/` か `.` を含む、を満たさないもの。
  **パスに見えなくても見出し部にあれば抽出はする**(黙って落とさない。保護を外す側に倒さない)
- 空のスパン(``)は無視する
- 重複は畳む(同じパスは 1 回だけ出力)。出力順は出現順(従来の `sort -u` による整列はやめてよい。
  `forbidden_snapshot()` が自分で `sort -u` しており、`--print-forbidden` の順序に依存する利用者はいない)
- マーカーが片方しか無いときの挙動(警告して抽出スキップ)と、両方無いときの挙動(何もしない)は**変えない**
- 限界(コメントに書く): 箇条書きでない地の文にバックティックなしでパスを書いても検出できない

## 判断2: 実装(`lib-forbidden.sh`)

現在の抽出ブロック(`if [ "$_fp_start" = 1 ] && [ "$_fp_end" = 1 ]; then` の中の `while ... done < <(sed ... | grep -o ... | sort -u)`)を
次に置き換える。**awk は mawk で動くこと**(devcontainer は mawk。gawk 拡張を使わない)。司令塔が mawk で動作確認済みのプログラム:

```bash
  while IFS=$'\t' read -r _fp_kind _fp_a _fp_b; do
    case "$_fp_kind" in
      P) [ -n "$_fp_a" ] && PROJECT_FORBIDDEN_PATHS+=("$_fp_a") ;;
      W) echo "delegate-codex: 警告 — AGENTS.md:${_fp_a} (委託禁止領域のマーカー内): ${_fp_b}" >&2 ;;
    esac
  done < <(awk '
    function pathlike(s) { return s ~ /^[A-Za-z0-9._][A-Za-z0-9._\/*-]*$/ && s ~ /[\/.]/ }
    /<!-- kickoff:delegation-forbidden-paths -->/ { inside = 1; next }
    /<!-- \/kickoff:delegation-forbidden-paths -->/ { inside = 0; next }
    !inside { next }
    {
      rest = $0
      if ($0 ~ /^- /) {
        d = index($0, " — ")
        if (d > 0) { head = substr($0, 1, d - 1); rest = substr($0, d) }
        else { head = $0; rest = ""; print "W\t" NR "\t説明ダッシュ( — )の無い箇条書き。行全体からパスを抽出した" }
        n = 0
        while (match(head, /`[^`]*`/)) {
          span = substr(head, RSTART + 1, RLENGTH - 2)
          head = substr(head, RSTART + RLENGTH)
          if (span == "") continue
          n++
          if (!(span in seen)) { seen[span] = 1; print "P\t" span }
          if (!pathlike(span)) print "W\t" NR "\tパスに見えない語がバックティックで囲まれている(抽出はする): " span
        }
        if (n == 0) print "W\t" NR "\t箇条書きにバックティックで囲んだパスが無い(この項目は保護されない)"
      }
      while (match(rest, /`[^`]*`/)) {
        span = substr(rest, RSTART + 1, RLENGTH - 2)
        rest = substr(rest, RSTART + RLENGTH)
        if (span != "") print "W\t" NR "\t地の文のバックティック(抽出しない): " span
      }
    }
  ' "$AGENTS" 2>/dev/null)
  unset _fp_kind _fp_a _fp_b
```

- 既存の `unset _fp_line` は不要になるので `unset _fp_kind _fp_a _fp_b` に置き換える
- 警告の出力先は stderr(既存の「マーカーが片方しか無い」警告と同じ)。stdout に出すと `--print-forbidden` の出力を汚す
- 抽出ブロック直前のコメント(「抽出はバックティック囲みの文字列すべて。実在しないもの(…)は forbidden_files() の実在検査で落ちるため…無害。」の段落)を、
  判断1 の規則・警告 3 種の意味・限界に書き換える。**過剰方向と過少方向の両方が以前は無通知だった(Issue #28)**ことを 1〜2 行で残す。
  既存コメントの文体(「〜する(Issue #N)」、理由を添える)に合わせる
- ファイル冒頭の説明や `forbidden_files()` のコメントは変えない

## 判断3: `AGENTS.md` §4 の地の文を直す

マーカー内の次の箇所から**バックティックを外す**。意味は変えない。

| 行(現状) | 変更 |
| --- | --- |
| `.claude/scripts/` の項目 | 説明中の `` `delegate-codex.sh` ``(2 箇所)→ delegate-codex.sh |
| `AGENTS.md` の項目 | `` `<!-- verify-probe: ... -->` `` → 「verify-probe コメント」(**HTML コメントを地の文にそのまま書かない**。Markdown 上で消えるため)。`` `exists` `` → exists、`` `npx` `` / `` `python3` `` → npx / python3 |
| `**このプロジェクト固有の禁止領域**` の見出し行 | `` (`/kickoff` フェーズ4 で追加) `` → (/kickoff フェーズ4 で追加) |
| `.husky/` の項目末尾の括弧書き | 「(この節のバックティックは禁止領域そのもののパスにだけ使い、説明のための例示は地の文で書きます)」を削除し、**マーカー開始行の直後(最初の箇条書きの前)に独立した段落として**次を置く(バックティックを使わない): |

```
この節は委託の出口検査が機械的に読みます。各項目は「- パス — 説明」の 1 行で書き、抽出されるのは説明ダッシュ( — )より前のバックティックだけです。説明文ではバックティックを使いません(使うと委託のたびに警告が出ます)。
```

- 段落の前後に空行を入れる(Markdown として箇条書きと分かれるように)
- これ以外の行は変えない

## 判断4: `/kickoff` の記入指示

`.claude/commands/kickoff.md` と `.agents/skills/source-command-kickoff/SKILL.md` の**同じ文**(「**この節のパスは出口検査が委託開始時に抽出して機械的に検査する**ため、実在するパスをバックティックで囲んで書く(ディレクトリは `src/auth/` または `src/auth/**`)」)の直後に、同じ箇条の中で次を足す。2 ファイルで同一の文言にする:

```
。書式は `- \`パス\` — 説明` の 1 行 1 項目で、**抽出されるのは説明ダッシュ( — )より前のバックティックだけ**。説明文ではバックティックを使わない(使うと委託のたびに警告が出る)
```

- 元の文末に句点が無い場合はそのままつなげる。行を分割しない(箇条の 1 行に収める)

## 判断5: CHANGELOG

`docs/template-dev/CHANGELOG.md` の先頭(`## 2026-09-23` の前)に `## 2026-09-25` 節を作り、1 項目を足す。既存項目の書き方(太字の要約 + 経緯 + 下位箇条)に合わせる。含める内容:

- `lib-forbidden.sh` の抽出を「箇条書きの説明ダッシュより前のコードスパン」に狭め、規約違反を警告するようにした(#28)
- 以前は過剰(地の文の語が実在パスと衝突して誤爆)・過少(バックティックなしのパスが静かに保護から外れる)の両方が無通知だった
- `AGENTS.md` §4 の地の文のバックティックを外した(`--print-forbidden` に `npx` などが混ざっていた)
- **`lib-forbidden.sh` はテンプレート所有**。上流(`fuji18/claude-codex-template`)に同じ修正が入るまで、`/sync-template` で旧版に戻りうる

## 判断6: 検証

作業は一時ファイルで行い、**リポジトリ内に検証用ファイルを残さない**(一時ファイルは `mktemp` で作り、使い終えたら消す)。

1. `bash .claude/scripts/delegate-codex.sh --print-forbidden` の **stdout** が 32 行(汎用 15 行 + 固有抽出 17 行)、重複を畳むと 17 行で、
   **stderr が空**であること。固有抽出分(`PROJECT_FORBIDDEN_PATHS`)が次の 17 個ちょうどであること(パスでない語が 1 つも無い):
   `.claude/scripts/` `.claude/hooks/` `.claude/settings.json` `.claude/settings.local.json` `.claude/branch-policy.json` `.claude/rules/` `.husky/` `.claude/codex-denylist.txt` `AGENTS.md` `CLAUDE.md` `.mcp.json` `.github/workflows/` `.codex/` `.harness/mode` `.harness/codex-runs/` `lib/data/database/` `lib/data/migrations/`(= 17 個)
   - 確認コマンド例: `bash .claude/scripts/delegate-codex.sh --print-forbidden 2>err.txt | sort -u` と `wc -c err.txt`
2. `bash .claude/scripts/check-forbidden-paths-doc.sh; echo $?` が `0`
3. 警告の確認: `AGENTS.md` のコピーを一時ディレクトリに作り、マーカー内に次の 4 行を足したものを対象に抽出だけを走らせる
   (`AGENTS=<コピー> ; source .claude/scripts/lib-forbidden.sh` をサブシェルで実行し、`printf '%s\n' "${PROJECT_FORBIDDEN_PATHS[@]}"` と stderr を見る)
   - `` - lib/foo/ — バックティックなし `` → 「保護されない」警告、`lib/foo/` は抽出されない
   - `` - `exists` — パスに見えない `` → 「パスに見えない」警告、`exists` は抽出される
   - `` - `x/` — 説明に `y.txt` がある `` → `x/` は抽出、`y.txt` は「地の文」警告で抽出されない
   - `` - `z/` `` → 「説明ダッシュの無い箇条書き」警告、`z/` は抽出される
4. マーカー片方: コピーから終了マーカー行を消したものを対象に source し、従来の「マーカーが片方しかありません」警告が出て `PROJECT_FORBIDDEN_PATHS` が空であること
5. `bash -n .claude/scripts/lib-forbidden.sh`、`shellcheck` があれば `shellcheck .claude/scripts/lib-forbidden.sh` で**新規の**指摘が無いこと(既存の指摘は対象外)
6. `bash .claude/scripts/check-guard-integrity.sh degraded` など他の利用者は `--print-forbidden` 経由なので追加確認は不要

## 判断7: 変更してよいファイル

- `.claude/scripts/lib-forbidden.sh`
- `.claude/scripts/delegate-codex.sh`(判断8)
- `AGENTS.md`
- `.claude/commands/kickoff.md`
- `.agents/skills/source-command-kickoff/SKILL.md`
- `docs/template-dev/CHANGELOG.md`
- `.steering/20260925-issue28-forbidden-extract/tasklist.md`(進捗更新)

`git status --short` がこの範囲に収まっていることを最後に確認する。

## 判断8: 入口検査0 に awk を加える(検収で追加)

抽出が awk に依存するようになったが、`delegate-codex.sh` の入口検査0 は awk の存在を確認していない。awk が無いと
`awk ... 2>/dev/null` が黙って空を返し、**プロジェクト固有パスの保護だけが静かに外れる**(フェイルオープン)。

- `.claude/scripts/delegate-codex.sh` 入口検査0 の `for _cmd in find grep sed head tail tr sort uniq; do` に `awk` を加える(`sed` の直後)
- 同ファイルの source 位置コメント「入口検査0(find / grep / sed の存在確認)より後 … 抽出が grep と sed を使う」を「入口検査0(find / grep / sed / awk の存在確認)より後 … 抽出が grep と awk を使う」に直す
- `lib-forbidden.sh` 冒頭コメントの「1) 入口検査0(find / grep / sed の存在確認)を通し」を「1) 入口検査0(find / grep / sed / awk の存在確認)を通し」に直す
- 判断7 の変更可能ファイルに `.claude/scripts/delegate-codex.sh` を加える
