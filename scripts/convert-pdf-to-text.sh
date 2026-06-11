#!/bin/zsh
ACTION_NAME="convert-pdf-to-text"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "txt")"
  require_tool "${PDFTOTEXT}" "poppler" || return 1
  if ! "${PDFTOTEXT}" -layout "${input}" "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
