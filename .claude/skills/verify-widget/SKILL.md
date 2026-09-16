---
name: verify-widget
description: Install this plugin into the running Omarchy shell and prove the bar is actually rendering it — install, restart, screenshot, inspect. Use after any change to Workspaces.qml or manifest.json, before calling that change done.
---

# Verify the widget for real

Static checks cannot catch this plugin's main failure mode: the shell binds a
bar slot to a plugin id at startup, so a widget can load cleanly and still not
be the file the bar is drawing. Log lines and a clean `journalctl` prove
nothing. Only a screenshot does.

Run every step. Report what you actually observed, not what you expected.

## 1. Static checks

```bash
cd <repo root>
omarchy plugin validate .
qmllint Workspaces.qml
```

`qmllint` exits non-zero on a syntax error but often prints nothing — treat a
non-zero exit as a syntax error and go find it.

Confirm `moduleName` in `Workspaces.qml` equals `id` in `manifest.json`; a
mismatch loads fine and renders nothing.

## 2. Install and restart

```bash
./install.sh
```

This validates, copies (never symlinks), and restarts the shell. Give it ~7s to
come back before looking at anything.

## 3. Look at the bar

Screenshot every connected output, not just one:

```bash
hyprctl monitors -j | jq -r '.[].name'
grim -o <output> /tmp/bar-<output>.png
```

Crop the top strip and read it. Check that:

- the workspace indicators are present at all
- the focused-workspace glyph sits on the workspace `hyprctl monitors -j`
  reports as active for that output
- there is exactly one row of numbers (two means the stock
  `omarchy.workspaces` is still enabled alongside this one)

If you are unsure whether the bar is running your file rather than a stale or
built-in copy, change a label to something unmistakable, screenshot, confirm,
then change it back. Do this before debugging any logic.

## 4. Check for errors

```bash
journalctl --user --no-pager --since "1 min ago" | grep -i <plugin-id>
```

`Local plugin changed, reloading: <id>` is routine. `IpcHandler ... another
handler is registered` warnings from other plugins are pre-existing noise.
Anything else naming this plugin is yours.

## 5. Behaviour, when the change touches click handling

Click behaviour needs two outputs. If only one display is connected, create a
temporary one:

```bash
hyprctl output create headless      # appears as HEADLESS-1
# ... exercise the behaviour ...
hyprctl output remove HEADLESS-1
```

Restore the workspace layout and focus you started from — check with
`hyprctl monitors -j` and `hyprctl workspaces -j` before and after, and say so
in your report if you could not put it back.

To drive the real click handler without a pointer, temporarily add an
`IpcHandler` to the widget whose target is derived from the bar's own output
(`"probe-" + root.clickedMonitorName()`), call it with
`omarchy-shell probe-<output> click <n>`, then re-run `./install.sh` to restore
the clean copy. This exercises everything except the mouse event itself.

## 6. Report

State plainly which steps passed, what the screenshot showed, and anything you
could not verify. Do not commit.
