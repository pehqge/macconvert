#!/bin/zsh
ACTION_NAME="convert-image-to-png"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "png")"

  if [[ "${input:l}" == *.svg ]]; then
    require_tool "${RSVG_CONVERT}" "rsvg-convert" || return 1
    if ! "${RSVG_CONVERT}" -o "${out}" "${input}" >>"${LOG_FILE}" 2>&1; then
      return 1
    fi
  else
    require_tool "${MAGICK}" "imagemagick" || return 1
    if ! "${MAGICK}" "${input}" "${out}" >>"${LOG_FILE}" 2>&1; then
      return 1
    fi
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
  return 0
}

run_batch "$@"
