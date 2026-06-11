#!/bin/zsh
# deps.sh — Homebrew dependency management.
#
# Dependencies are declared per action in the manifest; only the deps of the
# actions the user enables are installed. Formula names map to a probe binary
# so "already installed" detection works even when brew's db is slow.

# formula -> binary that proves it's installed
typeset -gA MC_DEP_PROBE=(
  ffmpeg        "ffmpeg"
  imagemagick   "magick"
  ghostscript   "gs"
  pandoc        "pandoc"
  poppler       "pdftotext"
  librsvg       "rsvg-convert"
  webp          "cwebp"
  vorbis-tools  "oggenc"
)

# cask -> app binary that proves it's installed
typeset -gA MC_CASK_PROBE=(
  libreoffice  "/Applications/LibreOffice.app/Contents/MacOS/soffice"
  calibre      "/Applications/calibre.app/Contents/MacOS/ebook-convert"
)

mc_brew() {
  [[ -n "${MC_BREW_PREFIX}" ]] || mc_die "Homebrew not found. Install it from https://brew.sh and rerun."
  "${MC_BREW_PREFIX}/bin/brew" "$@"
}

# Is a single dep (formula or "cask:name") present?
mc_dep_installed() {
  local dep="$1"
  if [[ "${dep}" == cask:* ]]; then
    local cask="${dep#cask:}"
    [[ -x "${MC_CASK_PROBE[${cask}]:-/nonexistent}" ]]
  else
    [[ -x "${MC_BREW_PREFIX}/bin/${MC_DEP_PROBE[${dep}]:-${dep}}" ]]
  fi
}

# Install every missing dep from a newline-separated list on stdin.
# Prints progress; returns non-zero if any install failed.
mc_deps_install() {
  local dep failed=0
  while IFS= read -r dep; do
    [[ -n "${dep}" ]] || continue
    if mc_dep_installed "${dep}"; then
      mc_ok "${dep#cask:}"
      continue
    fi
    if [[ "${dep}" == cask:* ]]; then
      print -- "    ${MC_CYAN}↓${MC_RESET} installing ${dep#cask:} (cask)…"
      mc_brew install --cask --no-quarantine "${dep#cask:}" >/dev/null 2>&1 \
        || { mc_warn "failed to install ${dep#cask:} — related actions won't work until you install it"; failed=1; }
    else
      print -- "    ${MC_CYAN}↓${MC_RESET} installing ${dep}…"
      mc_brew install "${dep}" >/dev/null 2>&1 \
        || { mc_warn "failed to install ${dep}"; failed=1; }
    fi
  done
  return ${failed}
}

# Human-readable dependency report for `macconvert doctor`.
mc_deps_report() {
  local dep
  for dep in "$@"; do
    if mc_dep_installed "${dep}"; then
      mc_ok "${dep#cask:}"
    else
      mc_warn "${dep#cask:} missing — run: brew install ${dep/cask:/--cask }"
    fi
  done
}
