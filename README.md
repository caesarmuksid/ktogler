# ktogler

A [KWin script](https://develop.kde.org/docs/plasma/kwin/) that turns any keyboard shortcut into an **application window toggler**. Press a key once to bring an app forward, again to cycle through its windows, and once more to minimize them all.

Fully configurable at runtime — apps and shortcuts live in a user-editable JSON config stored in `kwinrc`, no code changes required.

## Features

- Toggle / focus / minimize any application by its window `resourceClass`
- Cycle through **multiple instances** of the same app with repeated presses
- Per-app shortcuts registered with KWin (visible in _System Settings → Shortcuts_)
- Config stored as JSON in `kwinrc` (`[Script-ktogler]`) via `readConfig` — edit it, reload KWin, done
- Helper CLI (`ktogler.sh`) for editing/validating config and reloading KWin

## Requirements

- KDE Plasma 6 / KWin (Scripting enabled)
- `kpackagetool6` (install/upgrade), `kwriteconfig6` + `qdbus6` (enable/reload)
- `jq` (optional — used by `ktogler.sh` for status/validation, and by reload to prune shortcuts of removed apps)

## Installation

### From source

```sh
make install       # build + install the .kwinscript package
make enable        # enable the KWin script
make reload        # apply changes (unloads + reloads the script, prunes stale shortcuts)
```

Or in one go: `make dev`.

Uninstall (disables the script and removes all its registered shortcuts):

```sh
make uninstall
# or also delete your config:
make purge
```

### From the release package

Download `ktogler-<version>.kwinscript` and run:

```sh
kpackagetool6 --type KWin/Script --install ktogler-<version>.kwinscript
kwriteconfig6 --file kwinrc --group Plugins --key ktoglerEnabled true
qdbus6 org.kde.KWin /KWin reconfigure
```

Verify it's loaded: `make check` or `./ktogler.sh status`.

## Configuration

Configuration is a JSON document read at script load time, in this order:

1. **KConfig** (primary): read from `kwinrc`, group `[Script-ktogler]`, key
   `config` via `readConfig`. This works on all KWin versions with scripting.
2. **JSON file** (fallback for builds that support `readFile`): the user config
   paths and `ktogler-config.json` next to the script.

There are **no built-in defaults** — a fresh install registers no shortcuts
until a config is set. Seed one from the shipped template:

```sh
./ktogler.sh edit       # creates the config from ktogler-config.example.json,
                       # opens it, then pushes it into kwinrc
make reload            # apply changes
```

`./ktogler.sh sync` seeds the config only if none is set yet; `./ktogler.sh push`
overwrites the kwinrc config from the JSON file (same as `make config-sync` /
`make config-push`).

The JSON maps app names to window `resourceClass` values and shortcuts:

```json
{
  "apps": {
    "kitty": "kitty",
    "dolphin": "org.kde.dolphin",
    "firefox": "firefox-esr"
  },
  "shortcuts": {
    "kitty": "Meta+K",
    "dolphin": "Meta+F",
    "firefox": "Meta+Shift+F"
  }
}
```

Find the `resourceClass` of a running window with `./ktogler.sh list`.

## How toggling works

For each app registered in the config, both `apps.<name>` (resource class) and `shortcuts.<name>` (key combination) must be present. Pressing the shortcut:

1. App has no focused window → focus its **first** open instance
2. An instance is focused → cycle to the **next** instance
3. The **last** instance is active → minimize **all** of its windows

With a single window open this is exactly a show/hide toggle.

## Helper CLI

```sh
./ktogler.sh reload     # reload KWin to apply config changes
./ktogler.sh edit       # edit the config (opens $EDITOR, then pushes to kwinrc)
./ktogler.sh status     # show config + plugin status
./ktogler.sh sync       # seed config from example (only if kwinrc config unset)
./ktogler.sh push       # push config file into kwinrc (overwrite)
./ktogler.sh validate   # JSON syntax + required sections
./ktogler.sh check-key Meta+S   # check whether a shortcut combination is already taken
./ktogler.sh list       # list open windows and their resourceClass values
```

A Makefile provides the same workflow plus `make dev` (reinstall + enable + sync + reload).

## Development

```sh
make dev              # full cycle: reinstall + enable + config-sync + reload
make bump-patch       # bump version (also bump-minor / bump-major)
journalctl --user -f | grep -i ktogler   # watch script errors (quiet when healthy)
```

## Troubleshooting

- **Shortcut does nothing** — KWin Scripting may be disabled. Enable _System Settings → Window Management → KWin Scripts → ktogler_.
- **Shortcut conflicts** — check _System Settings → Shortcuts_ for other bindings using the same keys.
- **No shortcuts registered** — config may be unset in kwinrc; run `./ktogler.sh status`, then `./ktogler.sh sync` / `make config-sync`.
- **Uses stale config** — the script reads config only at load; after editing run `./ktogler.sh push` (or `./ktogler.sh edit`), then `make reload`.
- **Shortcut from a removed app still visible** — `reload` deregisters shortcuts not in the current config automatically (`jq` required; install it if you see the "skipping" message).
- **App not toggling** — the `resourceClass` must match exactly; run `./ktogler.sh list` to confirm.

## License

[GPL-3.0-or-later](LICENSE)
