# Workspace Summon

A drop-in replacement for the Omarchy shell's built-in workspace indicators.

The stock widget treats a workspace number as a destination: click `3` and you
are taken to whichever display workspace 3 happens to live on. On a multi-head
setup that is usually backwards — you clicked the number on *this* monitor
because you want the workspace *here*.

This widget reads the click the other way round. The number you press names the
workspace; the bar you press it on names where that workspace should end up.

## Behaviour

A bar surface exists per monitor, so the widget can tell which display the
click physically landed on.

| Workspace state | Left click does |
| --- | --- |
| Already on the display you clicked | Focus it — same as stock |
| Lives on another display | Move it to this display, then focus it |
| Does not exist yet | Create it on this display, rather than on whatever was focused |

Right click keeps the stock behaviour: go to the workspace where it already is.

On a single-monitor machine every click falls into the first row, so the widget
behaves exactly like the built-in one.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy-shell`)
- Hyprland with the Lua dispatch API (`hl.dsp.*`)

## Install

### From git

```bash
omarchy plugin add https://github.com/SykesTheLord/omarchy-workspace-summon.git
```

### From a local checkout

```bash
git clone https://github.com/SykesTheLord/omarchy-workspace-summon.git
cd omarchy-workspace-summon
./install.sh
```

`install.sh` validates the manifest, copies the plugin into
`~/.config/omarchy/plugins/`, and restarts the shell. It never symlinks — the
plugin registry refuses a plugin folder containing symlinks.

### Put it on the bar

Installing does not place the widget. Enable it, then take the stock one off so
you are not left with two rows of numbers:

```bash
omarchy plugin enable io.github.sykesthelord.workspaces --section left
omarchy plugin disable omarchy.workspaces
```

To place it precisely, `omarchy bar move` takes `--section` and `--index`:

```bash
omarchy bar move io.github.sykesthelord.workspaces --section left --index 1
```

## Uninstall

```bash
./install.sh --uninstall          # local install
omarchy plugin remove io.github.sykesthelord.workspaces   # git install
```

## Development

The shell hot-reloads plugin *file* changes, so editing `Workspaces.qml` in the
installed copy takes effect on save. It does **not** rebind a bar slot to a
newly installed plugin id — a first install, or a change of `id`, stays
invisible until the shell restarts. `install.sh` restarts it for you; pass
`--no-restart` if you would rather do it yourself.

If a change seems to have no effect, confirm the bar is running *your* file
before debugging the logic — temporarily change the label text to something
unmistakable and look at the bar. Plugin load messages and a clean
`journalctl --user` are not evidence that the bar slot is bound to your widget.

Validate before publishing:

```bash
omarchy plugin validate .
```

## How it works

`hl.dsp.workspace.move` relocates an existing workspace; focusing a monitor
before focusing a not-yet-created workspace makes Hyprland create it there.
The widget resolves its own output from `QsWindow.window.screen.name`, which
matches Hyprland's monitor names, and picks between those two paths.

## Licence

MIT — see [LICENSE](LICENSE).
