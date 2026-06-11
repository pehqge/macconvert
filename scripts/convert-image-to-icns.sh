#!/bin/zsh
ACTION_NAME="convert-image-to-icns"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "icns")"
  require_tool "${MAGICK}" "imagemagick" || return 1
  if [[ ! -x "${ICONUTIL}" ]]; then
    log "iconutil not at ${ICONUTIL}"; return 1
  fi
  local src; src="$(rasterize_if_svg "${input}")"

  local tmp
  tmp="$(mktemp -d -t macconvert-icns)"
  local iconset="${tmp}/${base}.iconset"
  mkdir -p "${iconset}"
  # Standard iconset sizes per Apple HIG.
  for spec in \
    "16 icon_16x16.png" \
    "32 icon_16x16@2x.png" \
    "32 icon_32x32.png" \
    "64 icon_32x32@2x.png" \
    "128 icon_128x128.png" \
    "256 icon_128x128@2x.png" \
    "256 icon_256x256.png" \
    "512 icon_256x256@2x.png" \
    "512 icon_512x512.png" \
    "1024 icon_512x512@2x.png" ; do
    local sz="${spec%% *}"; local fname="${spec#* }"
    # Force exact dimensions (!) — iconutil rejects non-square PNGs.
    if ! "${MAGICK}" "${src}" -resize "${sz}x${sz}!" "${iconset}/${fname}" >>"${LOG_FILE}" 2>&1; then
      log "resize ${sz} failed"; rm -rf "${tmp}"
      [[ "${src}" != "${input}" ]] && rm -f "${src}"
      return 1
    fi
  done
  if ! "${ICONUTIL}" -c icns -o "${out}" "${iconset}" >>"${LOG_FILE}" 2>&1; then
    rm -rf "${tmp}"
    [[ "${src}" != "${input}" ]] && rm -f "${src}"
    return 1
  fi
  rm -rf "${tmp}"
  [[ "${src}" != "${input}" ]] && rm -f "${src}"
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
