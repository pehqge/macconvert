#!/bin/zsh
ACTION_NAME="convert-video-to-gif"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "gif")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1

  local palette
  palette="$(mktemp_with_ext macconvert-palette png)"
  # Two-pass: generate optimized palette, then encode using it. Keeps GIFs small and clean.
  if ! "${FFMPEG}" -y -i "${input}" \
      -vf "fps=15,scale=720:-1:flags=lanczos,palettegen=stats_mode=diff" \
      "${palette}" >>"${LOG_FILE}" 2>&1; then
    rm -f "${palette}"; return 1
  fi
  if ! "${FFMPEG}" -y -i "${input}" -i "${palette}" \
      -lavfi "fps=15,scale=720:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5" \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    rm -f "${palette}"; return 1
  fi
  rm -f "${palette}"
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
