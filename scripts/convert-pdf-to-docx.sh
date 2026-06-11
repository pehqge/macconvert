#!/bin/zsh
ACTION_NAME="convert-pdf-to-docx"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "docx")"
  require_tool "${PDFTOTEXT}" "poppler" || return 1
  require_tool "${PANDOC}" "pandoc" || return 1
  # pandoc cannot read PDF natively in most builds. Extract text → DOCX.
  local tmp; tmp="$(mktemp_with_ext macconvert-pdf-text txt)"
  if ! "${PDFTOTEXT}" -layout "${input}" "${tmp}" >>"${LOG_FILE}" 2>&1; then
    rm -f "${tmp}"; return 1
  fi
  if ! "${PANDOC}" -f markdown -o "${out}" "${tmp}" >>"${LOG_FILE}" 2>&1; then
    rm -f "${tmp}"; return 1
  fi
  rm -f "${tmp}"
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
