# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

One Omarchy shell bar widget (Quickshell/QML), published as a standalone plugin.
The repo root **is** the plugin: `omarchy plugin add <git-url>` clones this root
and reads `manifest.json` from it, so nothing may move into a `src/`. There is no
build step, no test runner, and no package manager.

## The failure mode that wastes the most time here

The shell binds a bar slot to a plugin id **at startup**. Editing an installed
plugin's files hot-reloads, but a first install — or any change to `id` /
`moduleName` — stays invisible until `omarchy restart shell`.

A plugin that loads is not a widget that renders. `Local plugin changed,
reloading: <id>` in the log, and a clean `journalctl --user`, are **not** evidence
that the bar is running your file. To prove which file the bar is running, change
a label to something unmistakable and screenshot the bar.

## Definition of done

Never call a widget change done on static checks alone:

```bash
./install.sh                  # validate, copy, restart the shell
grim -o eDP-1 /tmp/bar.png    # then actually look at it
```

`/verify-widget` runs this loop.

Multi-monitor behaviour can be exercised without a second display:

```bash
hyprctl output create headless   # appears as HEADLESS-1
hyprctl output remove HEADLESS-1
```

## Constraints that break the plugin silently

- `moduleName` in `Workspaces.qml` must equal `id` in `manifest.json`.
- No symlinks anywhere in the plugin folder — the registry rejects the whole
  folder. `install.sh` copies for this reason; do not make it symlink.
- `omarchy plugin validate .` must pass before publishing.

## Style: stay a minimal diff from upstream

This widget is a modified copy of Omarchy's built-in one:

```
/usr/share/omarchy/shell/plugins/bar/widgets/Workspaces.qml
```

Keep the structure identical so upstream changes can be re-applied by diffing
that file against `Workspaces.qml`. Match its idiom: 2-space indent, no
semicolons, `var` rather than `let`/`const`, comments that explain *why*.

Do **not** run `qmlformat` on `Workspaces.qml` — it reindents to 4 spaces and
destroys that diff.

`/usr/share/omarchy/` is read-only and is overwritten by `omarchy update`, but
reading it is the best reference available. `/usr/share/hypr/stubs/hl.meta.lua`
documents the `hl.dsp.*` Hyprland dispatchers this widget calls.

## Repo conventions

- Bump `version` in `manifest.json` for any user-facing change.
- A change to click behaviour must update the README's behaviour table in the
  same change.
- **Never commit or push.** Leave changes in the working tree for the user to
  review.
