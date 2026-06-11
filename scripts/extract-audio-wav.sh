#!/bin/zsh
ACTION_NAME="extract-audio-wav"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "wav")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  if ! "${FFMPEG}" -y -i "${input}" -vn -c:a pcm_s16le "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
