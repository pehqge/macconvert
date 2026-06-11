#!/bin/zsh
ACTION_NAME="convert-video-to-mp4"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "mp4")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  if ! "${FFMPEG}" -y -i "${input}" \
      -c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p \
      -c:a aac -b:a 192k -movflags +faststart \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
