#!/bin/zsh
ACTION_NAME="compress-video"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}_compressed" "mp4")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  # CRF 28 = aggressive size reduction; scale down to max 1080p if larger.
  if ! "${FFMPEG}" -y -i "${input}" \
      -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease" \
      -c:v libx264 -crf 28 -preset medium -pix_fmt yuv420p \
      -c:a aac -b:a 128k -movflags +faststart \
      "${out}" >>"${LOG_FILE}" 2>&1; then
    return 1
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
