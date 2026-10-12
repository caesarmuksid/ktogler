# Roadmap & Distribution Guide

Status and tracking of the ktogler release. Items marked `[x]` are landed in
the repo; `[ ]` are still open.

## 1. Publishing & tagging

- [x] Create a git remote and push `main`:

  ```sh
  git remote add origin git@github.com:<user>/ktogler.git
  git push -u origin main
  ```

- [ ] Make the first release: bump version, commit, tag.

  ```sh
  git add -A
  git commit -m "chore: release ktogler v1.0.2"
  git tag v1.0.2
  git push && git push --tags
  ```

  > `VERSION` and `metadata.json` are already in sync on `1.0.2`
  > (`make check-version` passes). Tag `v1.0.2` after CI is green.

- [x] Add a `CHANGELOG.md` (conventional-commit history; GitHub auto-generated
      release notes are also enabled via the release workflow below).

## 2. CI / CD (GitHub Actions)

- [x] Add `.github/workflows/ci.yml` running on push/PR:

  ```yaml
  name: CI
  on: [push, pull_request]
  jobs:
    ci:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - run: sudo apt-get install -y shellcheck zip
        - run: bash -n ktogler.sh install.sh build.sh scripts/bump-version.sh
        - run: shellcheck ktogler.sh install.sh build.sh scripts/bump-version.sh
        - run: npx --yes eslint contents/code/main.js
        - run: npx --yes prettier --check .
        - run: make check-version
        - run: make build
          # fail if the package layout is broken (metadata.json at zip root)
        - run: unzip -l build/ktogler-*.kwinscript | grep -q './metadata.json' \
            || unzip -Z1 build/ktogler-*.kwinscript | grep -q '^metadata.json$'
  ```

  > `eslint.config.js` was added (flat config for the script); there were no
  > eslint/prettier configs before the CI landed.

- [x] Add `.github/workflows/release.yml` triggered on tag `v*`:

  ```yaml
  name: Release
  on:
    push:
      tags: ["v*"]
  jobs:
    release:
      runs-on: ubuntu-latest
      permissions:
        contents: write
      steps:
        - uses: actions/checkout@v4
        - run: sudo apt-get install -y zip
        - run: make build
        - name: Upload package to GitHub Release
          uses: softprops/action-gh-release@v2
          with:
            files: build/ktogler-*.kwinscript
            generate_release_notes: true
  ```

- [ ] Branch protection on `main` (require CI to pass) once team > 1.

## 3. Distribution channels

| Channel           | How                                                                     |
| ----------------- | ----------------------------------------------------------------------- |
| GitHub Releases   | CI uploads `ktogler-X.Y.Z.kwinscript` (above) — primary asset           |
| KDE Store         | Upload same package to store.kde.org; metadata fields are ready (below) |
| AUR               | `ktogler-kwinscript` PKGBUILD (sketch below)                            |
| Distro packaging  | Only after adoption justifies it (Fedora/Debian/KDE Neon)               |
| One-liner install | `install.sh` (builds from source) or `curl ...                          | kpackagetool6` once a release exists |

### KDE Store metadata

`metadata.json` ships the fields KCoreAddons expects. The KDE Store renders
`Name` / `Description`; since Plasma's `KPluginMetaData` resolves localized
values from keys like `"Name[<lang>]"` and `"Description[<lang>]"` (bare key is
the fallback), add translations there rather than as arrays. Example:

```json
"KPlugin": {
  "License": "GPL-3.0-or-later",
  "SinceVersion": "5.91",
  "Name": "ktogler",
  "Description": "Generic Window Toggler"
}
```

Plus, if you maintain translations:

```json
"Description[de]": "Fenster einer Anwendung per Tastenkürzel umschalten"
```

Add `X-KDE-PluginInfo-*` fields if the store still expects legacy keys.
Upload a preview screenshot (`screenshots/ktogler.png`) and reuse the README
as listing copy (drafted in `docs/kde-store.md`).

### AUR PKGBUILD sketch

```bash
# PKGBUILD for package name: ktogler-kwinscript
pkgname=ktogler-kwinscript
pkgver=1.0.2
pkgrel=1
pkgdesc='KWin script that toggles/cycles application windows via configurable shortcuts'
arch=('any')
url='https://github.com/caesarmuksid/ktogler'
license=('GPL-3.0-or-later')
depends=('kwin')
source=("$url/releases/download/v$pkgver/ktogler-$pkgver.kwinscript")
sha256sums=('...')
package() {
  kpackagetool6 --type KWin/Script --install \
    "$srcdir/ktogler-$pkgver.kwinscript" --global
}
```

(Use `--global` for system-wide install; drop it for a per-user package.)

## 4. Recommend

- [x] `install.sh`: detect `kpackagetool6`/`kwriteconfig6`, install+enable+reload,
      mirroring `make dev` for end users.
- [x] `screenshots/` placeholder + `docs/kde-store.md` listing copy (reuse README).
- [x] GitHub issue/PR templates.
- [x] The roadmap now lives in tracked `docs/roadmap.md`; the remaining
      gitignored `notes/` content (`command.sh`) is a personal scratch pad.
