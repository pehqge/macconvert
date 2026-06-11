#!/bin/zsh
ACTION_NAME="convert-pdf-to-jpg"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  require_tool "${MAGICK}" "imagemagick" || return 1
  local pattern="${dir}/${base}-page-%d.jpg"
  if [[ -e "${dir}/${base}-page-1.jpg" ]]; then
    local n=1
    while [[ -e "${dir}/${base} (${n})-page-1.jpg" ]]; do n=$((n+1)); done
    pattern="${dir}/${base} (${n})-page-%d.jpg"
  fi
  if ! "${MAGICK}" -density 300 "${input}" -background white -alpha remove -alpha off \
      -quality 92 -scene 1 "${pattern}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="${base}-page-*.jpg"
  log "OK -> ${pattern}"
}

run_batch "$@"
