# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- KWin script that turns any keyboard shortcut into an application window
  toggler: focus first instance, cycle through instances, minimize all on the
  last press.
- Runtime configuration stored as JSON in `kwinrc` (`[Script-ktogler]/config`),
  seeded from `ktogler-config.example.json`; no code changes to reconfigure.
- Per-app global shortcuts registered with KWin (`Ktogler<App>`), visible in
  System Settings → Shortcuts.
- Helper CLI (`ktogler.sh`) for editing, validating and syncing the config, and
  pruning stale shortcuts; Makefile targets mirror the workflow.
- Installer (`install.sh`), CI and release workflows, issue/PR templates,
  KDE Store metadata and distribution docs.

### Changed

- Rebranded as **ktogler**: plugin id/name, package name
  (`ktogler-X.Y.Z.kwinscript`), kwinrc group `Script-ktogler`, shortcut prefix
  `Ktogler`, config files and fallback paths.

### Fixed

- Version bookkeeping: `VERSION` and `metadata.json` are kept in sync
  (`make check-version`).
