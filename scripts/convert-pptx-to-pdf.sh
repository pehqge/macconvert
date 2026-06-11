#!/bin/zsh
ACTION_NAME="convert-pptx-to-pdf"
source "$(dirname "$0")/_common.sh"

LIBREOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "pdf")"

  if [[ ! -x "${LIBREOFFICE}" ]]; then
    log "LibreOffice not installed. Install with: brew install --cask libreoffice"
    notify_failure "${ACTION_NAME}" "LibreOffice required (brew install --cask libreoffice)"
    return 1
  fi

  local tmpd; tmpd="$(mktemp -d -t macconvert-pptx2pdf)"
  if ! "${LIBREOFFICE}" --headless --convert-to pdf --outdir "${tmpd}" "${input}" >>"${LOG_FILE}" 2>&1; then
    rm -rf "${tmpd}"; return 1
  fi
  local generated="${tmpd}/${base}.pdf"
  if [[ ! -f "${generated}" ]]; then
    log "LibreOffice did not produce expected output at ${generated}"
    rm -rf "${tmpd}"; return 1
  fi
  mv "${generated}" "${out}"
  rm -rf "${tmpd}"
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
