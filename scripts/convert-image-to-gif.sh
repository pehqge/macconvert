#!/bin/zsh
ACTION_NAME="convert-image-to-gif"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "gif")"
  require_tool "${MAGICK}" "imagemagick" || return 1
  local src; src="$(rasterize_if_svg "${input}")"
  if ! "${MAGICK}" "${src}" "${out}" >>"${LOG_FILE}" 2>&1; then
    [[ "${src}" != "${input}" ]] && rm -f "${src}"
    return 1
  fi
  [[ "${src}" != "${input}" ]] && rm -f "${src}"
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
