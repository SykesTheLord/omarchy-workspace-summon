#!/usr/bin/env bash
#
# Install this plugin into the running Omarchy shell straight from a working
# copy, for development and for anyone who would rather not add a git remote.
#
# Published installs go through `omarchy plugin add <git-url>` instead; that
# path clones, validates, and registers the plugin for you. This script is the
# same idea against a local directory.

set -euo pipefail

PLUGIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGINS_ROOT="${OMARCHY_PLUGINS_DIR:-$HOME/.config/omarchy/plugins}"

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage: ./install.sh [--uninstall] [--force] [--no-restart]

  (no flags)     Validate, copy into $PLUGINS_ROOT, restart the shell
  --uninstall    Remove the installed copy and restart the shell
  --force        Replace a target directory even if it is a git checkout
  --no-restart   Skip the shell restart (you must restart it yourself)

Enabling the widget on the bar is a separate, deliberate step:
  omarchy plugin enable <id> --section left
USAGE
}

UNINSTALL=0
FORCE=0
RESTART=1

while (( $# > 0 )); do
  case "$1" in
    --uninstall) UNINSTALL=1; shift ;;
    --force) FORCE=1; shift ;;
    --no-restart) RESTART=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1 (try --help)" ;;
  esac
done

command -v jq >/dev/null || fail "jq is required"
[[ -f $PLUGIN_DIR/manifest.json ]] || fail "no manifest.json next to this script"

ID=$(jq -r '.id // ""' "$PLUGIN_DIR/manifest.json")
[[ -n $ID ]] || fail "manifest.json has no id"
TARGET="$PLUGINS_ROOT/$ID"

# The shell only rebinds a bar slot to a plugin at startup. Editing an already
# installed plugin's files hot-reloads, but a first install -- or a change of
# id -- is invisible until the shell comes back up.
restart_shell() {
  (( RESTART )) || { echo "Skipped shell restart; run 'omarchy restart shell' yourself."; return; }
  if command -v omarchy >/dev/null; then
    echo "Restarting the Omarchy shell..."
    omarchy restart shell >/dev/null 2>&1 || echo "install.sh: shell restart failed; run 'omarchy restart shell'" >&2
  else
    echo "omarchy not on PATH; restart the shell yourself."
  fi
}

if (( UNINSTALL )); then
  [[ -e $TARGET ]] || fail "not installed: $TARGET"
  if [[ -d $TARGET/.git && $FORCE -eq 0 ]]; then
    fail "$TARGET is a git checkout; remove it with 'omarchy plugin remove $ID', or pass --force"
  fi
  rm -rf -- "$TARGET"
  echo "Removed $TARGET"
  echo "If it was on your bar, take it off with: omarchy plugin disable $ID"
  restart_shell
  exit 0
fi

# Validate before touching the plugins directory: the same check the shell's
# registry applies, so a broken manifest fails here rather than half-installed.
if command -v omarchy-plugin-validate >/dev/null; then
  omarchy-plugin-validate "$PLUGIN_DIR" || fail "validation failed; nothing was installed"
else
  echo "install.sh: omarchy-plugin-validate not found, skipping validation" >&2
fi

if [[ -e $TARGET || -L $TARGET ]]; then
  if [[ -d $TARGET/.git && $FORCE -eq 0 ]]; then
    fail "$TARGET is a git checkout managed by 'omarchy plugin add'.
       Update it with 'omarchy plugin update $ID', or pass --force to overwrite."
  fi
  echo "Replacing existing $TARGET"
  rm -rf -- "$TARGET"
fi

# Stage, then move into place, so an interrupted copy never leaves a partial
# plugin where the shell will try to load it. Symlinks are stripped because the
# registry refuses a plugin folder that contains any.
mkdir -p -- "$PLUGINS_ROOT"
STAGE="$PLUGINS_ROOT/.install.tmp.$$"
rm -rf -- "$STAGE"
trap 'rm -rf -- "$STAGE"' EXIT

mkdir -p -- "$STAGE"
tar -C "$PLUGIN_DIR" --exclude=.git -cf - . | tar -C "$STAGE" -xf -
find "$STAGE" -type l -delete

mv -- "$STAGE" "$TARGET"
trap - EXIT
echo "Installed $ID into $TARGET"

command -v omarchy-shell >/dev/null && omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
restart_shell

cat <<DONE

Next: put it on the bar (it is installed but not placed yet).

  omarchy plugin enable $ID --section left

If the stock workspace widget is still there, take it off so you do not
end up with two rows of numbers:

  omarchy plugin disable omarchy.workspaces
DONE
