#!/bin/zsh
ACTION_NAME="convert-audio-to-ogg"
source "$(dirname "$0")/_common.sh"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "ogg")"
  require_tool "${FFMPEG}" "ffmpeg" || return 1
  # ffmpeg from Homebrew lacks libvorbis; use vorbis-tools' oggenc instead.
  local OGGENC="${BREW_PREFIX}/bin/oggenc"
  if [[ -x "${OGGENC}" ]]; then
    local tmpwav; tmpwav="$(mktemp_with_ext macconvert-ogg wav)"
    if ! "${FFMPEG}" -y -i "${input}" -vn -c:a pcm_s16le -ar 44100 "${tmpwav}" >>"${LOG_FILE}" 2>&1; then
      rm -f "${tmpwav}"; return 1
    fi
    if ! "${OGGENC}" -q 5 -o "${out}" "${tmpwav}" >>"${LOG_FILE}" 2>&1; then
      rm -f "${tmpwav}"; return 1
    fi
    rm -f "${tmpwav}"
  else
    # Try libvorbis-built ffmpeg, then experimental vorbis encoder.
    if ! "${FFMPEG}" -y -i "${input}" -vn -c:a libvorbis -q:a 5 "${out}" >>"${LOG_FILE}" 2>&1; then
      if ! "${FFMPEG}" -y -i "${input}" -vn -c:a vorbis -strict experimental -q:a 5 "${out}" >>"${LOG_FILE}" 2>&1; then
        return 1
      fi
    fi
  fi
  LAST_OUTPUT_BASENAME="$(basename "${out}")"
  log "OK -> ${out}"
}

run_batch "$@"
