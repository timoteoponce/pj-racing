#!/usr/bin/env bash
# PJ-Racing - one script to set up, run, test and export the game.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
GODOT_VERSION="4.7.2"
BUILD_DIR="$ROOT/build"

c_bold=$'\e[1m'; c_y=$'\e[33m'; c_g=$'\e[32m'; c_r=$'\e[31m'; c_0=$'\e[0m'
say()  { echo "${c_bold}${c_y}[pj-racing]${c_0} $*"; }
ok()   { echo "${c_bold}${c_g}[ok]${c_0} $*"; }
die()  { echo "${c_bold}${c_r}[error]${c_0} $*" >&2; exit 1; }

godot() {
  if command -v mise >/dev/null 2>&1; then
    mise exec -- godot "$@"
  elif command -v godot >/dev/null 2>&1; then
    command godot "$@"
  else
    die "Godot not found. Install mise (https://mise.jdx.dev) and run: ./build.sh setup"
  fi
}

cmd_setup() {
  say "Installing tools with mise (Godot $GODOT_VERSION)..."
  command -v mise >/dev/null 2>&1 || die "mise is required: https://mise.jdx.dev"
  mise trust -q "$ROOT/mise.toml" 2>/dev/null || true
  mise install
  cmd_import
  ok "Setup complete. Run: ./build.sh run"
}

cmd_import() {
  say "Importing project..."
  godot --headless --path "$ROOT" --import >/dev/null 2>&1 || godot --headless --path "$ROOT" --editor --quit >/dev/null 2>&1 || true
  ok "Imported"
}

cmd_run() {
  [ -d "$ROOT/.godot" ] || cmd_import
  say "Starting PJ-Racing... (F11 fullscreen, F3 fps)"
  godot --path "$ROOT" "$@"
}

cmd_editor() {
  godot --path "$ROOT" --editor "$@"
}

# Smoke test: loads every menu screen, races every track with CPUs, runs an arcade race and a
# full 2-player tournament on autopilot. Fails on any script/runtime error.
_run_check() {
  local name="$1"; shift
  local expect="$1"; shift
  local out
  out=$(timeout 600 godot --headless --path "$ROOT" --fixed-fps 60 "$@" 2>&1 || true)
  echo "== $name" >> "$CHECK_LOG"; echo "$out" >> "$CHECK_LOG"
  if echo "$out" | grep -q "SCRIPT ERROR\|^ERROR:"; then
    echo "$out" | grep -A4 "SCRIPT ERROR\|^ERROR:" | head -30
    die "$name: errors (full log: $CHECK_LOG)"
  fi
  if [ -n "$expect" ] && ! echo "$out" | grep -q "$expect"; then
    die "$name: did not complete (full log: $CHECK_LOG)"
  fi
  ok "$name"
}

cmd_check() {
  cmd_import
  mkdir -p "$BUILD_DIR"
  CHECK_LOG="$BUILD_DIR/check.log"
  : > "$CHECK_LOG"
  for sc in title arcade versus tracks garage controls settings; do
    _run_check "screen: $sc" "" --quit-after 30 -- --screen "$sc"
  done
  _run_check "gamepad menu navigation" "PAD TEST OK" -- --pad-test
  local tracks="${*:-park dunes frost city lava mud space}"
  for t in $tracks; do
    _run_check "cpu race: $t" "DEMO RACE OK" -- --demo "$t"
  done
  _run_check "arcade race + results" "ARCADE OK" -- --race mud --autoplay --laps 1
  PJ_DEBUG=1 _run_check "easy driving: hands-off kart finishes" "HUMAN RESULT.*finished=true" --quit-after 6000 -- --race city --laps 1
  _run_check "2P tournament (3 races + podium)" "TOURNAMENT OK" -- --tournament stud --players 2 --autoplay --laps 1
  ok "All checks passed"
}

cmd_export() {
  [ -d "$ROOT/.godot" ] || cmd_import
  local tdir="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  if [ ! -f "$tdir/linux_release.x86_64" ]; then
    say "Downloading Godot $GODOT_VERSION export templates (~1 GB, one time)..."
    local tmp; tmp="$(mktemp -d)"
    curl -L --fail -o "$tmp/templates.tpz" \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
    mkdir -p "$tdir"
    unzip -q -o "$tmp/templates.tpz" -d "$tmp"
    cp -r "$tmp/templates/." "$tdir/"
    rm -rf "$tmp"
  fi
  mkdir -p "$BUILD_DIR"
  say "Exporting Linux build..."
  godot --headless --path "$ROOT" --export-release "Linux" "$BUILD_DIR/pj-racing.x86_64"
  ok "Built $BUILD_DIR/pj-racing.x86_64"
}

# Installs the exported game for the current user only (no sudo): binary, launcher on PATH,
# app-menu entry and icon, all under ~/.local.
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/pj-racing"
BIN_LINK="$HOME/.local/bin/pj-racing"
DESKTOP_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/applications/pj-racing.desktop"
ICON_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/pj-racing.svg"

cmd_install() {
  cmd_export
  say "Installing for $USER into ~/.local ..."
  mkdir -p "$APP_DIR" "$(dirname "$BIN_LINK")" "$(dirname "$DESKTOP_FILE")" "$(dirname "$ICON_FILE")"
  install -m 755 "$BUILD_DIR/pj-racing.x86_64" "$APP_DIR/pj-racing.x86_64"
  install -m 644 "$ROOT/icon.svg" "$ICON_FILE"
  ln -sf "$APP_DIR/pj-racing.x86_64" "$BIN_LINK"
  cat > "$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Name=PJ-Racing
GenericName=Lego Kart Racer
Comment=Build your own lego car and race it
Exec=$APP_DIR/pj-racing.x86_64
Icon=pj-racing
Terminal=false
Categories=Game;ArcadeGame;
Keywords=racing;kart;lego;
DESKTOP
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$(dirname "$DESKTOP_FILE")" || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" 2>/dev/null || true
  ok "Installed! Start it from your app menu (PJ-Racing) or run: pj-racing"
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) say "Note: ~/.local/bin is not on your PATH; use the app menu or $APP_DIR/pj-racing.x86_64" ;; esac
}

cmd_uninstall() {
  rm -f "$BIN_LINK" "$DESKTOP_FILE" "$ICON_FILE" "$APP_DIR/pj-racing.x86_64"
  rmdir "$APP_DIR" 2>/dev/null || true
  ok "Uninstalled (your save and garage are kept)"
}

cmd_pads() {
  say "Connected game controllers:"
  godot --headless --path "$ROOT" --script res://tools/list_pads.gd 2>/dev/null | grep -v "^Godot Engine" || true
}

cmd_reset_save() {
  local f="$HOME/.local/share/godot/app_userdata/PJ-Racing/pj_racing_save.json"
  if [ -f "$f" ]; then
    mv "$f" "$f.bak"
    ok "Save moved to $f.bak"
  else
    say "No save file found"
  fi
}

cmd_clean() {
  rm -rf "$ROOT/.godot" "$BUILD_DIR"
  ok "Cleaned"
}

usage() {
  cat <<EOF
${c_bold}PJ-Racing build script${c_0}

  ./build.sh setup        Install Godot via mise and import the project
  ./build.sh run          Play the game (extra args go to Godot, e.g. -- --race park)
  ./build.sh editor       Open the Godot editor
  ./build.sh check [ids]  Smoke test: all screens, CPU races on every track, full tournament
  ./build.sh export       Build a standalone Linux executable into build/
  ./build.sh install      Export and install for this user (~/.local: app menu + 'pj-racing' command)
  ./build.sh uninstall    Remove the user install (keeps your save)
  ./build.sh pads         List detected game controllers
  ./build.sh reset-save   Back up and reset your save (studs, parts, garage)
  ./build.sh clean        Remove caches and build output
EOF
}

case "${1:-run}" in
  setup) cmd_setup ;;
  run) shift || true; cmd_run "$@" ;;
  editor) shift; cmd_editor "$@" ;;
  check) shift; cmd_check "$@" ;;
  export) cmd_export ;;
  install) cmd_install ;;
  uninstall) cmd_uninstall ;;
  pads) cmd_pads ;;
  reset-save) cmd_reset_save ;;
  clean) cmd_clean ;;
  import) cmd_import ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
