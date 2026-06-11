#!/bin/zsh
ACTION_NAME="convert-video-to-webm"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "webm")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  if ! "${FFMPEG}" -y -i "${input}" \
      -c:v libvpx-vp9 -crf 30 -b:v 0 \
      -c:a libopus -b:a 128k \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
