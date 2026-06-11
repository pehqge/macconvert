#!/bin/zsh
# Common helpers for all conversion scripts.
# Sourced by every convert-*.sh script. Detects homebrew prefix, exports tool
# paths, provides logging and notification helpers.

set -u
set -o pipefail

# Detect homebrew prefix (Apple Silicon vs Intel).
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_PREFIX="/opt/homebrew"
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_PREFIX="/usr/local"
else
  BREW_PREFIX="/opt/homebrew"
fi
export BREW_PREFIX

# Extend PATH so subprocesses spawned by our binaries (e.g. ImageMagick
# delegating PDF rasterization to Ghostscript, or pandoc finding xelatex)
# can find their helpers. Automator strips PATH; we have to put it back.
export PATH="${BREW_PREFIX}/bin:/Library/TeX/texbin:${PATH}"

# Some ImageMagick builds require MAGICK_GHOSTSCRIPT_PATH to find gs even
# when gs is on PATH (sandboxed delegate lookup).
export MAGICK_GHOSTSCRIPT_PATH="${BREW_PREFIX}/bin"

# Absolute tool paths (Automator strips PATH).
FFMPEG="${BREW_PREFIX}/bin/ffmpeg"
FFPROBE="${BREW_PREFIX}/bin/ffprobe"
MAGICK="${BREW_PREFIX}/bin/magick"
IDENTIFY="${BREW_PREFIX}/bin/identify"
CWEBP="${BREW_PREFIX}/bin/cwebp"
DWEBP="${BREW_PREFIX}/bin/dwebp"
GIF2WEBP="${BREW_PREFIX}/bin/gif2webp"
PANDOC="${BREW_PREFIX}/bin/pandoc"
QPDF="${BREW_PREFIX}/bin/qpdf"
GS="${BREW_PREFIX}/bin/gs"
PDFTOTEXT="${BREW_PREFIX}/bin/pdftotext"
RSVG_CONVERT="${BREW_PREFIX}/bin/rsvg-convert"
EBOOK_CONVERT="${BREW_PREFIX}/bin/ebook-convert"
ICONUTIL="/usr/bin/iconutil"
SIPS="/usr/bin/sips"

LOG_DIR="${HOME}/Library/Logs/macconvert"
mkdir -p "${LOG_DIR}"

# action_name is set by each script; default to script basename.
ACTION_NAME="${ACTION_NAME:-$(basename "${0:-unknown}" .sh)}"
LOG_FILE="${LOG_DIR}/${ACTION_NAME}.log"

log() {
  local msg="$*"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" >> "${LOG_FILE}"
}

# Fire macOS native notification.
notify() {
  local title="$1"
  local subtitle="$2"
  local body="$3"
  # Escape backslashes and double-quotes for AppleScript.
  title="${title//\\/\\\\}"; title="${title//\"/\\\"}"
  subtitle="${subtitle//\\/\\\\}"; subtitle="${subtitle//\"/\\\"}"
  body="${body//\\/\\\\}"; body="${body//\"/\\\"}"
  /usr/bin/osascript -e "display notification \"${body}\" with title \"${title}\" subtitle \"${subtitle}\"" >/dev/null 2>&1 || true
}

notify_success() {
  # Silenced on purpose — only failures notify the user. Successful conversions
  # are visible because the output file lands next to the input.
  :
}

notify_failure() {
  local subtitle="$1"; local reason="$2"
  notify "File Conversion" "${subtitle}" "Failed: ${reason}. See log: ${LOG_FILE}"
}

# Build a non-overwriting output path: if target exists, append " (1)", " (2)", ...
unique_output_path() {
  local dir="$1"; local base="$2"; local ext="$3"
  local candidate="${dir}/${base}.${ext}"
  if [[ ! -e "${candidate}" ]]; then
    printf '%s' "${candidate}"
    return
  fi
  local n=1
  while [[ -e "${dir}/${base} (${n}).${ext}" ]]; do
    n=$((n + 1))
  done
  printf '%s' "${dir}/${base} (${n}).${ext}"
}

# Strip extension from filename (handles dots in name).
strip_ext() {
  local f="$1"
  printf '%s' "${f%.*}"
}

# Make a unique temp file path with a specific extension. mktemp creates
# AND echoes a path, but appending an extension would leak the original
# (extension-less) file. Here we let mktemp pick a unique prefix, remove
# the empty file it left behind, and return prefix+ext.
mktemp_with_ext() {
  local prefix="$1"; local ext="$2"
  local base; base="$(mktemp -t "${prefix}")"
  rm -f "${base}"
  printf '%s' "${base}.${ext}"
}

# Rasterize an SVG input to a temporary PNG so downstream raster-only tools
# (ImageMagick without an SVG delegate, cwebp, gif2webp, etc.) can read it.
# Echoes the input unchanged when it's not an SVG.
#
# Callers should remember the returned path: when it differs from the input
# they must `rm -f` it after they're done (best-effort cleanup).
rasterize_if_svg() {
  local input="$1"
  if [[ "${input:l}" != *.svg ]]; then
    printf '%s' "${input}"
    return 0
  fi
  if [[ ! -x "${RSVG_CONVERT}" ]]; then
    # Fall back to original — magick may or may not handle it. The caller
    # logs/errors if conversion ultimately fails.
    printf '%s' "${input}"
    return 0
  fi
  local tmp; tmp="$(mktemp_with_ext macconvert-svg png)"
  if ! "${RSVG_CONVERT}" -w 2048 -a "${input}" -o "${tmp}" 2>/dev/null; then
    rm -f "${tmp}"
    printf '%s' "${input}"
    return 1
  fi
  printf '%s' "${tmp}"
}

# Find an absolute path to a PDF engine pandoc can drive. Stripped PATH under
# Automator means `command -v` and bare names both fail — so check every known
# install location explicitly. Echoes the absolute path on stdout, or nothing.
find_pdf_engine() {
  local engine="$1"
  local candidates=(
    "${BREW_PREFIX}/bin/${engine}"
    "/usr/local/bin/${engine}"
    "/Library/TeX/texbin/${engine}"
    "/usr/bin/${engine}"
    "/opt/local/bin/${engine}"
  )
  for c in "${candidates[@]}"; do
    [[ -x "${c}" ]] && { printf '%s' "${c}"; return 0; }
  done
  return 1
}

# Require a tool to exist or fail with notification.
require_tool() {
  local tool="$1"; local name="$2"
  if [[ ! -x "${tool}" ]]; then
    log "Required tool missing: ${name} at ${tool}"
    notify_failure "${ACTION_NAME}" "Missing dependency: ${name}"
    return 1
  fi
  return 0
}

# Process arguments: each input file invokes process_file, output success/fail summary.
run_batch() {
  local total=0
  local ok=0
  local failed=0
  local first_input_base=""
  local last_error=""

  for input in "$@"; do
    total=$((total + 1))
    if [[ -z "${first_input_base}" ]]; then
      first_input_base="$(basename "${input}")"
    fi
    if [[ ! -e "${input}" ]]; then
      log "Input not found: ${input}"
      last_error="Input not found: $(basename "${input}")"
      failed=$((failed + 1))
      continue
    fi
    log "Processing: ${input}"
    if process_file "${input}"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
      last_error="${last_error:-Conversion failed for $(basename "${input}")}"
    fi
  done

  if [[ ${total} -eq 0 ]]; then
    notify_failure "${ACTION_NAME}" "No input files"
    return 1
  fi

  if [[ ${total} -eq 1 ]]; then
    if [[ ${ok} -eq 1 ]]; then
      notify_success "${ACTION_NAME}" "${first_input_base} → ${LAST_OUTPUT_BASENAME:-done}"
    else
      notify_failure "${ACTION_NAME}" "${last_error}"
      return 1
    fi
  else
    if [[ ${failed} -eq 0 ]]; then
      notify_success "${ACTION_NAME}" "Converted ${ok}/${total} files"
    else
      notify_failure "${ACTION_NAME}" "${ok}/${total} ok, ${failed} failed. ${last_error}"
      return 1
    fi
  fi
  return 0
}
