#!/bin/zsh
ACTION_NAME="convert-video-to-mov"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "mov")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  # ProRes 422 LT — editor-friendly, plays on Apple silicon natively.
  if ! "${FFMPEG}" -y -i "${input}" \
      -c:v prores_ks -profile:v 1 -pix_fmt yuv422p10le \
      -c:a pcm_s16le \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
