# KDE Store Listing

Suggested submission content for the [KDE Store](https://store.kde.org),
reusing the README. Upload the same `ktogler-X.Y.Z.kwinscript` that the
release workflow publishes to GitHub Releases.

## Checklist

- [ ] Package: the `.kwinscript` from `make build` (with `metadata.json` in
      the zip root).
- [ ] Screenshot: `screenshots/ktogler.png` added under **Screenshots**.
- [ ] `metadata.json` contains the fields the store renders: `Name`,
      `Description`, `License`, `SinceVersion` (see `docs/roadmap.md` for the
      `Name[<lang>]` / `Description[<lang>]` translation pattern).
- [ ] Version matches the latest GitHub release tag (`vX.Y.Z`).

## Name

ktogler

## Short description

KWin script that toggles/cycles application windows via configurable shortcuts.

## Long description

A KWin script that turns any keyboard shortcut into an **application window
toggler**. Press a key once to bring an app forward, again to cycle through
its windows, and once more to minimize them all.

Fully configurable at runtime — apps and shortcuts live in a user-editable
JSON config stored in `kwinrc`, no code changes required.

### Features

- Toggle / focus / minimize any application by its window `resourceClass`
- Cycle through **multiple instances** of the same app with repeated presses
- Per-app shortcuts registered with KWin (visible in System Settings →
  Shortcuts)
- Config stored as JSON in `kwinrc` (`[Script-ktogler]`) via `readConfig` —
  edit it, reload KWin, done
- Helper CLI (`ktogler.sh`) for editing/validating config and reloading KWin

### Requirements

- KDE Plasma 6 / KWin (Scripting enabled)
- `kpackagetool6` (install/upgrade), `kwriteconfig6` + `qdbus6`
  (enable/reload)
- `jq` (optional — used by reload to prune shortcuts of removed apps)

### Setup

Install the package, then enable it and reload KWin:

```sh
kpackagetool6 --type KWin/Script --install ktogler-<version>.kwinscript
kwriteconfig6 --file kwinrc --group Plugins --key ktoglerEnabled true
qdbus6 org.kde.KWin /KWin reconfigure
```

There are **no built-in defaults** — a fresh install registers no shortcuts
until a config is set. Seed one from the shipped template:

```sh
./ktogler.sh edit       # creates the config from ktogler-config.example.json,
                        # opens it, then pushes it into kwinrc
make reload             # apply changes
```

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

### How toggling works

For each app registered in the config, both `apps.<name>` (resource class) and
`shortcuts.<name>` (key combination) must be present. Pressing the shortcut:

1. App has no focused window → focus its **first** open instance
2. An instance is focused → cycle to the **next** instance
3. The **last** instance is active → minimize **all** of its windows

With a single window open this is exactly a show/hide toggle.

### License

GPL-3.0-or-later
