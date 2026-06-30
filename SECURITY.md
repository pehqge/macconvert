# Security

## Reporting a vulnerability

Please report vulnerabilities privately via
[GitHub Security Advisories](https://github.com/pehqge/homebrew-macconvert/security/advisories/new).
You should get a response within a few days.

## Security model

MacConvert is a set of local shell scripts; nothing phones home except the
update check (a GitHub API call). Things worth knowing:

- **No elevated privileges.** Everything installs into your user account:
  `~/Library/Services`, `~/Library/Application Support/MacConvert`, and a
  symlink in Homebrew's bin. No `sudo`, no system files.
- **SMTP password lives in the macOS Keychain**, never in a file. It is
  entered through `security`'s own prompt and passed to `curl` via stdin, so
  it does not appear in shell history or `ps` output.
- **The config file is parsed, never sourced** — a tampered config cannot
  execute code.
- **Updates** download release tarballs from this repository over HTTPS.
  If you prefer, disable auto-update (`macconvert autoupdate off`) and update
  manually from a clone you've inspected.
- **The installer is inspectable**: `install.sh` is wrapped in `main()` (a
  partial download can't execute) and we encourage downloading and reading it
  before running.
