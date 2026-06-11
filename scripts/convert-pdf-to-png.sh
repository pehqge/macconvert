#!/bin/zsh
ACTION_NAME="convert-pdf-to-png"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  require_tool "${MAGICK}" "imagemagick" || return 1
  # %d expands to 0-based page index; use -scene 1 to start at 1.
  # Use absolute filename pattern to avoid overwrite if first page already exists.
  local pattern="${dir}/${base}-page-%d.png"
  # If first-page output exists, derive a non-collision basename.
  if [[ -e "${dir}/${base}-page-1.png" ]]; then
    local n=1
    while [[ -e "${dir}/${base} (${n})-page-1.png" ]]; do n=$((n+1)); done
    pattern="${dir}/${base} (${n})-page-%d.png"
  fi
  if ! "${MAGICK}" -density 300 "${input}" -quality 100 -scene 1 "${pattern}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="${base}-page-*.png"
  log "OK -> ${pattern}"
}

run_batch "$@"
