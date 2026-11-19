#!/bin/sh
# Set up Dighouse on this Mac: check what it needs, offer to install what is missing, then build and open the app.
# Run it from the folder you cloned:  ./scripts/setup.sh
set -e
cd "$(dirname "$0")/.."
step() { printf '\n%s\n' "$1"; }
ok() { printf '  ✓ %s\n' "$1"; }
no() { printf '  ✗ %s\n' "$1"; }
ask() { printf '  %s [y/N] ' "$1"; read -r answer; [ "$answer" = y ] || [ "$answer" = Y ]; }
stop() { printf '\n  %s\n  Then run ./scripts/setup.sh again.\n\n' "$1"; exit 1; }

step "1. This Mac"
version=$(sw_vers -productVersion); major=${version%%.*}
if [ "$(uname -m)" != arm64 ]; then no "Dighouse needs a Mac with Apple silicon (M1 or later)."; exit 1; fi
if [ "$major" -lt 14 ]; then no "macOS $version is too old. Dighouse needs macOS 14 or later."; exit 1; fi
ok "Apple silicon, macOS $version"

step "2. Xcode, Apple's free developer app, to build Dighouse"
if [ -d /Applications/Xcode.app ]; then
  ok "Found"
  case "$(xcode-select -p 2>/dev/null)" in *Xcode.app*) ;; *)
    no "Xcode is installed but not selected for building."
    stop "Run:  sudo xcode-select -s /Applications/Xcode.app   (it asks for your Mac password)";;
  esac
elif xcrun --find swift >/dev/null 2>&1; then
  no "Only the Command Line Tools are installed. The build may work; if it fails, install Xcode."
else
  no "Not found."
  stop "Install Xcode from the App Store (free, a large download), open it once to finish installing"
fi

step "3. uv, which runs Dighouse's archaeology tools"
uv=$(command -v uv || true)
[ -z "$uv" ] && [ -x "$HOME/.local/bin/uv" ] && uv="$HOME/.local/bin/uv"
if [ -n "$uv" ]; then ok "Found"; else
  no "Not found."
  if ask "Install uv now, with its official installer from astral.sh?"; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    uv="$HOME/.local/bin/uv"; [ -x "$uv" ] || stop "uv did not install. See https://docs.astral.sh/uv/"
    ok "Installed"
  else stop "Install uv from https://docs.astral.sh/uv/"; fi
fi

step "4. Codex, the agent engine, and your sign-in"
codex=""
for c in "$(command -v codex || true)" "$HOME/.local/bin/codex" /opt/homebrew/bin/codex /usr/local/bin/codex \
         /Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex /Applications/Codex.app/Contents/Resources/codex; do
  if [ -n "$c" ] && [ -x "$c" ]; then codex="$c"; break; fi
done
if [ -z "$codex" ]; then
  no "Not found."
  stop "Install Codex: the Codex app from https://openai.com/codex, or in Terminal  brew install --cask codex  or  npm install -g @openai/codex"
fi
ok "Found ($("$codex" --version 2>/dev/null | head -1))"
if "$codex" login status >/dev/null 2>&1; then ok "Signed in"; else
  no "Not signed in."
  if ask "Sign in now? A browser window opens for your ChatGPT account."; then "$codex" login; else stop "Run:  codex login"; fi
fi

step "5. Building Dighouse (a few minutes the first time)"
./app/scripts/bundle.sh >/tmp/dighouse-build.log 2>&1 || {
  no "The build failed. The last lines of /tmp/dighouse-build.log:"; tail -8 /tmp/dighouse-build.log
  [ -d /Applications/Xcode.app ] || printf '\n  Installing Xcode from the App Store usually fixes this.\n'
  exit 1
}
ok "Built app/build/Dighouse.app"

step "6. Installing"
app="app/build/Dighouse.app"
if ask "Copy Dighouse to your Applications folder?"; then
  if pgrep -x Dighouse >/dev/null; then no "Quit Dighouse first, then run this again to copy it."; exit 1; fi
  if [ -d /Applications/Dighouse.app ]; then mv /Applications/Dighouse.app "$HOME/.Trash/Dighouse-old-$(date +%s).app"; fi
  ditto "$app" /Applications/Dighouse.app && app=/Applications/Dighouse.app && ok "Copied"
fi
if pgrep -x Dighouse >/dev/null; then
  printf '\n  Dighouse is already open. Quit it and open it again to use this build.\n\n'
  exit 0
fi
open "$app"
printf '\n  Dighouse is opening. The first launch prepares the tools, which takes about a minute.\n  docs/SETUP.md says what to do next.\n\n'
