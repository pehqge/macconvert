#!/bin/zsh
ACTION_NAME="convert-image-to-webp"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "webp")"

  if [[ "${input:l}" == *.gif ]]; then
    require_tool "${GIF2WEBP}" "gif2webp" || return 1
    if ! "${GIF2WEBP}" -q 90 "${input}" -o "${out}" >>"${LOG_FILE}" 2>&1; then
      return 1
    fi
  else
    require_tool "${CWEBP}" "cwebp" || return 1
    # cwebp does not read all formats; pipe through magick for safety.
    local src; src="$(rasterize_if_svg "${input}")"
    if ! "${MAGICK}" "${src}" -quality 90 "${out}" >>"${LOG_FILE}" 2>&1; then
      [[ "${src}" != "${input}" ]] && rm -f "${src}"
      return 1
    fi
    [[ "${src}" != "${input}" ]] && rm -f "${src}"
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
