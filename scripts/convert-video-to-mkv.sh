#!/bin/zsh
ACTION_NAME="convert-video-to-mkv"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "mkv")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  # Try stream copy first (fast, lossless); fall back to re-encode if codecs aren't MKV-compatible.
  if "${FFMPEG}" -y -i "${input}" -c copy "${out}" >>"${LOG_FILE}" 2>&1; then
    LAST_OUTPUT_BASENAME="$(basename "${out}")"
    log "OK (copy) -> ${out}"
    return 0
  fi
  log "stream copy failed, re-encoding"
  rm -f "${out}"
  if ! "${FFMPEG}" -y -i "${input}" \
      -c:v libx264 -crf 20 -preset medium \
      -c:a aac -b:a 192k \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK (reencode) -> ${out}"
}

run_batch "$@"
