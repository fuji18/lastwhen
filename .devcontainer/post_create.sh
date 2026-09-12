#!/bin/bash
set -e

echo "=== Post-create setup ==="

# Install Flutter SDK
# devcontainer feature は使わない(公式 feature が無く、コミュニティ feature は
# 供給元が個人メンテ = サプライチェーン上の依存を増やしたくない)。
# 公式リポジトリの stable ブランチを浅く clone する。PATH は devcontainer.json の
# containerEnv で通してあるので、ここでは配置と初期化だけを行う。
echo "[1/5] Installing Flutter SDK..."
FLUTTER_ROOT="${FLUTTER_ROOT:-/opt/flutter}"
if [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "  Flutter already present at $FLUTTER_ROOT."
else
  sudo mkdir -p "$FLUTTER_ROOT"
  sudo chown -R "$(id -u):$(id -g)" "$FLUTTER_ROOT"
  git clone --branch stable --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$PATH"
# clone 直後は Dart SDK が未展開。任意のコマンドを 1 回叩くと取得される
git config --global --add safe.directory "$FLUTTER_ROOT"
flutter --version || echo "  ⚠️  Flutter の初期化に失敗しました。'flutter doctor' で確認してください。"
flutter config --no-analytics >/dev/null 2>&1 || true

# Install harness dependencies (husky / lint-staged / secretlint)
# これを飛ばすと core.hooksPath が設定されず、.husky/ のガードレール
# (保護ブランチ検査の強制 2・3 層)と pre-commit の機密検出が一切動かない。
echo "[2/5] Installing harness dependencies..."
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund
else
  npm install --no-audit --no-fund
fi
if [ "$(git config core.hooksPath)" = ".husky/_" ]; then
  echo "  git hooks enabled (core.hooksPath=.husky/_)."
else
  echo "  ⚠️  git hook が有効化されていません。'npm run prepare' を手動で実行してください。"
fi

# Install Claude Code
echo "[3/5] Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# Install Codex CLI (Codex 併用ハーネスの前提。docs/template-dev/codex-harness.html §12.4)
# 認証(codex login)はリビルドのたびに人間の手動操作が要る。~/.codex は
# コンテナ内にしか無いため、ここで入れられるのは CLI 本体だけ。
#
# 本体パッケージはランチャー(bin/codex.js)だけを含み、実体はプラットフォーム別の
# optionalDependencies(エイリアス指定)で降ってくる。optional なので取得に失敗しても
# npm install は成功扱いで終わり、実行時に初めて
#   Error: Missing optional dependency @openai/codex-linux-x64
# で落ちる。インストール成否は npm ではなく codex --version で判定する。
echo "[4/5] Installing Codex CLI..."
npm install -g @openai/codex || true
if ! codex --version &>/dev/null; then
  echo "  ⚠️  プラットフォーム別バイナリの取得に失敗。再試行します..."
  npm install -g @openai/codex@latest || true
fi
if codex --version &>/dev/null; then
  if codex login status &>/dev/null; then
    echo "  Already authenticated with Codex."
  else
    echo "  ⚠️  Not authenticated. Run 'codex login'(通らなければ 'codex login --device-auth')."
    echo "      '--with-api-key' は使わないこと(ChatGPT Plus 枠ではなく API 従量課金になる)。"
  fi
else
  echo "  ⚠️  Codex CLI のインストールに失敗しました。手動で 'npm install -g @openai/codex@latest' を実行してください。"
fi

# GitHub authentication
# Codespaces が注入する GITHUB_TOKEN を尊重し、ローカル devcontainer では
# LOCAL_GH_TOKEN(ホストの GH_TOKEN)をフォールバックとして使う
echo "[5/5] Setting up GitHub authentication..."
GITHUB_TOKEN="${GITHUB_TOKEN:-${LOCAL_GH_TOKEN:-}}"
if gh auth status &>/dev/null; then
  echo "  Already authenticated with GitHub."
elif [ -n "$GITHUB_TOKEN" ]; then
  echo "$GITHUB_TOKEN" | gh auth login --with-token
  gh auth setup-git
  echo "  GitHub authentication complete (via GITHUB_TOKEN)."
else
  echo "  ⚠️  Not authenticated. Run 'gh auth login' to authenticate manually."
fi

echo "=== Setup complete ==="
