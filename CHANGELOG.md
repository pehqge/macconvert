# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.1] - 2026-06-10

### Changed

- Running `macconvert` with nothing enabled yet (fresh install) goes straight
  into setup instead of the home menu.

## [1.1.0] - 2026-06-10

### Added

- Homebrew tap install: `brew install pehqge/tap/macconvert`. The CLI now
  bootstraps its runtime into Application Support on first run, from wherever
  it's launched (brew libexec or a git checkout), and `macconvert update`
  delegates to `brew upgrade` on brew-managed installs so the two never drift.

## [1.0.0] - 2026-06-10

### Added

- 45 Finder Quick Actions covering images, video, audio, PDF, documents and
  ebooks — all generated programmatically, no Automator clicking.
- `macconvert` CLI with an interactive picker: enable, disable and reconfigure
  any subset of actions at any time (`macconvert menu`).
- Per-selection dependency management: only the Homebrew packages needed by
  the actions you enable get installed.
- Send to Kindle as an opt-in action: emails files to your Kindle through an
  SMTP account you control, with the password stored in the macOS Keychain
  and delivery handled by the system `curl` (no extra dependencies). Existing
  Calibre email settings can be imported in one step.
- `macconvert update` self-update from GitHub releases, plus an optional
  weekly auto-update LaunchAgent (`macconvert autoupdate on`).
- `macconvert doctor` health check.
- End-to-end test suite (`tests/verify.sh`) that exercises every Quick Action
  through the same `automator` path Finder uses, including multi-select,
  filename edge cases and collision suffixing.

[1.1.1]: https://github.com/pehqge/macconvert/releases/tag/v1.1.1
[1.1.0]: https://github.com/pehqge/macconvert/releases/tag/v1.1.0
[1.0.0]: https://github.com/pehqge/macconvert/releases/tag/v1.0.0
