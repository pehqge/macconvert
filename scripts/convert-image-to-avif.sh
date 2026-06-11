#!/bin/zsh
ACTION_NAME="convert-image-to-avif"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "avif")"
  require_tool "${MAGICK}" "imagemagick" || return 1
  local src; src="$(rasterize_if_svg "${input}")"
  # Prefer ffmpeg if available for better AVIF support; fallback to magick.
  if [[ -x "${FFMPEG}" ]]; then
    if "${FFMPEG}" -y -i "${src}" -c:v libaom-av1 -still-picture 1 -crf 30 -b:v 0 -pix_fmt yuv420p "${out}" >>"${LOG_FILE}" 2>&1; then
      [[ "${src}" != "${input}" ]] && rm -f "${src}"
      LAST_OUTPUT_BASENAME="$(basename "${out}")"
      log "OK -> ${out}"
      return 0
    fi
    log "ffmpeg avif failed, trying magick"
  fi
  if ! "${MAGICK}" "${src}" -quality 70 "AVIF:${out}" >>"${LOG_FILE}" 2>&1; then
    [[ "${src}" != "${input}" ]] && rm -f "${src}"
    return 1
  fi
  [[ "${src}" != "${input}" ]] && rm -f "${src}"
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
