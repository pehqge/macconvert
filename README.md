<h1 align="center">MacConvert</h1>

<p align="center">
  <em>Convert any file from Finder's right-click menu — 45 native Quick Actions, no app windows, no uploads.</em>
</p>

<p align="center">
  <a href="https://github.com/pehqge/macconvert/actions/workflows/ci.yml"><img src="https://github.com/pehqge/macconvert/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/pehqge/macconvert/releases"><img src="https://img.shields.io/github/v/release/pehqge/macconvert?color=blue" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-12%2B%20·%20Apple%20Silicon%20%26%20Intel-black?logo=apple" alt="macOS">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
  <a href="https://github.com/sponsors/pehqge"><img src="https://img.shields.io/badge/sponsor-%E2%9D%A4-db61a2?logo=githubsponsors&logoColor=white" alt="Sponsor"></a>
</p>

<p align="center">
  <img src="assets/hero.png" alt="Finder right-click menu with MacConvert Quick Actions" width="780">
</p>

Right-click a file → **Quick Actions** → pick a conversion. The output appears
next to the original. Everything runs locally through proven tools (ffmpeg,
ImageMagick, Pandoc, Ghostscript…) — your files never leave your Mac.

## Install

```sh
git clone https://github.com/pehqge/macconvert.git
cd macconvert && ./install.sh
```

or, if you prefer a one-liner (feel free to [read install.sh](install.sh) first):

```sh
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/pehqge/macconvert/main/install.sh)"
```

The installer opens an interactive picker — choose exactly which Quick Actions
you want. **Only the dependencies for what you pick get installed** (via
Homebrew, which is the one requirement).

<p align="center">
  <img src="assets/demo.gif" alt="macconvert menu: interactive picker for enabling and disabling Quick Actions" width="760">
</p>

## What you get

| Right-click a… | And convert to |
|---|---|
| **Image** | PNG · JPG · WebP · HEIC · TIFF · GIF · AVIF · ICO · ICNS · PDF (multi-select combines into one) |
| **Video** | MP4 (H.264) · MP4 (HEVC, hardware-accelerated) · MOV · WebM · MKV · animated GIF · extract MP3/M4A/WAV · compress |
| **Audio** | MP3 · WAV · FLAC · M4A · OGG · OPUS |
| **PDF** | PNG/JPG per page · text · DOCX · compress |
| **Document** | DOCX ⇄ PDF/Markdown/HTML · Markdown ⇄ PDF/DOCX/HTML · HTML ⇄ Markdown/PDF · XLSX → PDF · PPTX → PDF |
| **Ebook** | EPUB → MOBI/PDF · MOBI → EPUB · **Send to Kindle** |

Only conversions valid for the selected file type appear in the menu.
Multi-select works — convert a hundred files in one click. Existing files are
never overwritten (collisions get ` (1)`, ` (2)`… suffixes).

## Manage it anytime

```sh
macconvert            # interactive menu
macconvert menu       # enable/disable any subset of actions
macconvert doctor     # health check
macconvert update     # update to the latest release
macconvert uninstall  # remove everything cleanly
```

Updates can also run themselves: `macconvert autoupdate on` installs a weekly
background check.

## Send to Kindle

An opt-in Quick Action that emails PDFs, EPUBs and documents straight to your
Kindle. Setup (`macconvert kindle setup`) walks you through it:

1. your `@kindle.com` address,
2. the email account that sends (Gmail/iCloud/Outlook app password — stored in
   the **macOS Keychain**, never in a file; existing Calibre settings can be
   imported in one step),
3. authorizing the sender on Amazon: [amazon.com/sendtokindle/email](https://www.amazon.com/sendtokindle/email)
   → **Approved Personal Document E-mail List** → add the sender address.

Then `macconvert kindle test` sends a test document. Delivery uses the
system's `curl` — no extra dependencies.

## How it works

Each action is a real macOS Service: a `.workflow` bundle generated
programmatically into `~/Library/Services`, scoped to Finder by file-type
(UTI). The bundles call zsh scripts installed in
`~/Library/Application Support/MacConvert`, so the cloned repo is disposable
after install. Failures notify with a pointer to
`~/Library/Logs/macconvert/<action>.log`; successes stay silent — the new
file *is* the feedback. Nothing runs with elevated privileges.

Every conversion is covered by an end-to-end test
([`tests/verify.sh`](tests/verify.sh)) that invokes the installed bundles
through the same `automator` path Finder uses.

## Troubleshooting

- **Actions missing from the menu** — `macconvert doctor`, then restart
  Finder (`killall Finder`). Still missing? System Settings → Privacy &
  Security → Extensions → Finder.
- **A conversion fails** — the notification points at the action's log with
  the exact tool error.

## Contributing

Adding a conversion is a script plus one manifest row — see
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
