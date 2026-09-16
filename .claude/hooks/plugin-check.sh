#!/usr/bin/env bash
#
# PostToolUse hook for Write|Edit.
#
# Catches the two breakages that are invisible until install time: a manifest
# the plugin registry would reject, and QML that will not parse. Both otherwise
# surface as a widget that simply is not on the bar, with nothing in the log
# that names the cause.
#
# Reads the tool payload on stdin; prints nothing and exits 0 when clean.

set -uo pipefail

payload=$(cat)
file=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' <<<"$payload" 2>/dev/null)
[[ -n $file && -e $file ]] || exit 0

file=$(readlink -f -- "$file" 2>/dev/null) || exit 0

# The nearest ancestor holding a manifest.json is the plugin root. Deriving it
# from the edited file keeps this hook working from any checkout path.
root=""
dir=$(dirname -- "$file")
while [[ -n $dir && $dir != "/" ]]; do
  if [[ -f "$dir/manifest.json" ]]; then
    root=$dir
    break
  fi
  dir=$(dirname -- "$dir")
done

problems=""

if [[ -n $root ]] && command -v omarchy-plugin-validate >/dev/null 2>&1; then
  if ! out=$(omarchy-plugin-validate "$root" 2>&1); then
    problems+="omarchy plugin validate failed:"$'\n'"$out"$'\n'
  fi
fi

# qmllint exits non-zero on a parse error but frequently prints nothing, so the
# exit code is the signal and the message has to be supplied here.
if [[ $file == *.qml ]] && command -v qmllint >/dev/null 2>&1; then
  if ! out=$(qmllint "$file" 2>&1); then
    problems+="qmllint rejected $(basename -- "$file") — likely a syntax error."$'\n'
    [[ -n $out ]] && problems+="$out"$'\n'
  fi
fi

[[ -z $problems ]] && exit 0

jq -n --arg p "$problems" '{
  systemMessage: ("Plugin check failed:\n" + $p),
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("These checks failed after the edit. Fix them before continuing:\n" + $p)
  }
}'
