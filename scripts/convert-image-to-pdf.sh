#!/bin/zsh
# Special case: multi-select combines into one PDF; single input produces
# one PDF per image.
ACTION_NAME="convert-image-to-pdf"
source "$(dirname "$0")/_common.sh"

main() {
  require_tool "${MAGICK}" "imagemagick" || { notify_failure "${ACTION_NAME}" "imagemagick missing"; return 1; }

  local count=$#
  if [[ ${count} -eq 0 ]]; then
    notify_failure "${ACTION_NAME}" "No input files"
    return 1
  fi

  if [[ ${count} -eq 1 ]]; then
    local input="$1"
    local dir; dir="$(dirname "${input}")"
    local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
    local out; out="$(unique_output_path "${dir}" "${base}" "pdf")"
    # SVG → PDF: magick has no native SVG-to-PDF path; rsvg-convert does it cleanly.
    if [[ "${input:l}" == *.svg ]] && [[ -x "${RSVG_CONVERT}" ]]; then
      if "${RSVG_CONVERT}" -f pdf "${input}" -o "${out}" >>"${LOG_FILE}" 2>&1; then
        log "OK (rsvg) -> ${out}"
        return 0
      fi
      log "rsvg-convert failed, trying magick"
    fi
    if "${MAGICK}" "${input}" "${out}" >>"${LOG_FILE}" 2>&1; then
      log "OK -> ${out}"
      return 0
    else
      notify_failure "${ACTION_NAME}" "Conversion failed"
      return 1
    fi
  fi

  # Multi-select: combined PDF in the directory of the first input.
  # Rasterize any SVG inputs first so magick can compose them with bitmaps.
  local dir; dir="$(dirname "$1")"
  local out; out="$(unique_output_path "${dir}" "combined" "pdf")"

  local -a sources tmpfiles
  for f in "$@"; do
    local s; s="$(rasterize_if_svg "${f}")"
    sources+=("${s}")
    [[ "${s}" != "${f}" ]] && tmpfiles+=("${s}")
  done

  local rc=0
  if ! "${MAGICK}" "${sources[@]}" "${out}" >>"${LOG_FILE}" 2>&1; then
    rc=1
  fi
  for t in "${tmpfiles[@]}"; do rm -f "${t}"; done

  if [[ ${rc} -eq 0 ]]; then
    log "OK combined -> ${out}"
    return 0
  fi
  notify_failure "${ACTION_NAME}" "Combined PDF failed"
  return 1
}

main "$@"
