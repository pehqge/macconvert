#!/bin/zsh
ACTION_NAME="convert-video-to-mp4-hevc"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}_hevc" "mp4")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  # Hardware HEVC encoder on Apple Silicon; fall back to libx265 if unavailable.
  if "${FFMPEG}" -y -i "${input}" \
      -c:v hevc_videotoolbox -tag:v hvc1 -q:v 60 \
      -c:a aac -b:a 192k -movflags +faststart \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    LAST_OUTPUT_BASENAME="$(basename "${out}")"
    log "OK (hwaccel) -> ${out}"
    return 0
  fi
  log "hevc_videotoolbox failed, trying libx265"
  if ! "${FFMPEG}" -y -i "${input}" \
      -c:v libx265 -crf 24 -preset medium -tag:v hvc1 \
      -c:a aac -b:a 192k -movflags +faststart \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
