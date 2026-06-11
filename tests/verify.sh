#!/bin/zsh
# End-to-end smoke test for every Quick Action.
#
# For each row, invokes the installed .workflow bundle via the `automator` CLI
# (same execution path Finder right-click uses) and asserts the output is real:
#  - file exists, non-zero size, correct type per `file`
#  - media: ffprobe reports valid duration and codec
#  - images: magick identify reports non-zero dimensions
#  - text: extracted output is non-empty
#
# Exits 0 only if every row passes.

set -u

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES_DIR="${PROJECT_DIR}/samples"

# The sample corpus is generated, not committed.
if [[ ! -f "${SAMPLES_DIR}/sample.png" ]]; then
  echo "==> Generating sample corpus"
  "${PROJECT_DIR}/tests/generate-samples.sh" || { echo "ERROR: sample generation failed" >&2; exit 1; }
fi
SERVICES_DIR="${HOME}/Library/Services"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
FFPROBE="${BREW_PREFIX}/bin/ffprobe"
MAGICK="${BREW_PREFIX}/bin/magick"
IDENTIFY="${BREW_PREFIX}/bin/identify"

# Working area separate from samples so we can clean up between rows.
WORK_DIR="$(mktemp -d -t macconvert-verify)"
trap "rm -rf '${WORK_DIR}'" EXIT

pass=0
fail=0
results=()

# Format one summary row.
record() {
  local num="$1"; local name="$2"; local st="$3"; local detail="$4"
  results+=("${num}|${name}|${st}|${detail}")
  if [[ "${st}" == "PASS" ]]; then
    pass=$((pass + 1))
    echo "  ✅ ${num} ${name}"
  else
    fail=$((fail + 1))
    echo "  ❌ ${num} ${name} — ${detail}"
  fi
}

# Run a workflow against an input. Returns 0 on automator success.
#
# We invoke automator with a stripped PATH that matches the environment Finder
# gives to Quick Actions. Without this, the workflow's shell script would
# inherit the user's full PATH (with /opt/homebrew/bin, /Library/TeX/texbin,
# etc.) and `command -v <tool>` would succeed in the test even though it
# would fail when the user triggers the same Quick Action from Finder.
# This is exactly how Markdown→PDF passed verification but failed in real
# usage before the find_pdf_engine() fix.
run_workflow() {
  local action="$1"; shift
  local wf="${SERVICES_DIR}/MacConvert - ${action}.workflow"
  if [[ ! -d "${wf}" ]]; then
    echo "MISSING_WORKFLOW"
    return 2
  fi
  env -i HOME="${HOME}" USER="${USER}" \
      PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
      /usr/bin/automator -i "$@" "${wf}" >/dev/null 2>&1
  return $?
}

# Copy sample into WORK_DIR with a fresh stem so subsequent expected outputs
# don't collide. Echo the new absolute path.
fresh_input() {
  local src="$1"; local stem="$2"
  local ext="${src##*.}"
  local target="${WORK_DIR}/${stem}.${ext}"
  cp "${src}" "${target}"
  echo "${target}"
}

# Verify a generic file: exists, non-empty, and (optionally) `file` mentions a keyword.
assert_file() {
  local f="$1"; local keyword="${2:-}"
  [[ -f "${f}" ]] || { echo "missing: $(basename "${f}")"; return 1; }
  [[ -s "${f}" ]] || { echo "empty: $(basename "${f}")"; return 1; }
  if [[ -n "${keyword}" ]]; then
    file "${f}" | grep -qi "${keyword}" || { echo "file-type mismatch ($(file -b "${f}")) expected ${keyword}"; return 1; }
  fi
  return 0
}

assert_image() {
  local f="$1"
  assert_file "${f}" || return 1
  local dims; dims="$("${IDENTIFY}" -format '%wx%h' "${f}[0]" 2>/dev/null)"
  [[ -n "${dims}" && "${dims}" != "0x0" ]] || { echo "bad image dims: ${dims}"; return 1; }
  return 0
}

assert_media() {
  local f="$1"; local stream="${2:-v}"
  assert_file "${f}" || return 1
  local dur; dur="$("${FFPROBE}" -v error -show_entries stream=duration -of default=nokey=1:noprint_wrappers=1 -select_streams "${stream}:0" "${f}" 2>/dev/null | head -1)"
  if [[ -z "${dur}" || "${dur}" == "N/A" ]]; then
    dur="$("${FFPROBE}" -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 "${f}" 2>/dev/null)"
  fi
  # duration > 0.1
  awk -v d="${dur:-0}" 'BEGIN{exit !(d+0 > 0.1)}' || { echo "no/short duration: ${dur}"; return 1; }
  return 0
}

# Single-input test wrapper.
test_row() {
  local num="$1"; local action="$2"; local sample_basename="$3"; local out_path_template="$4"; local assert_kind="$5"
  local stem="row${num}"
  local src="${SAMPLES_DIR}/${sample_basename}"
  if [[ ! -f "${src}" ]]; then
    record "${num}" "${action}" "FAIL" "sample missing: ${sample_basename}"
    return
  fi
  local input; input="$(fresh_input "${src}" "${stem}")"
  local input_dir; input_dir="$(dirname "${input}")"
  local input_base; input_base="$(basename "${input}")"; input_base="${input_base%.*}"
  local expected="${out_path_template//@DIR@/${input_dir}}"
  expected="${expected//@BASE@/${input_base}}"
  if ! run_workflow "${action}" "${input}"; then
    record "${num}" "${action}" "FAIL" "automator returned non-zero"
    return
  fi
  # Allow glob expansion for multi-page outputs.
  local matched; matched=(${~expected}(N))
  if [[ ${#matched[@]} -eq 0 ]]; then
    record "${num}" "${action}" "FAIL" "no output at ${expected}"
    return
  fi
  local first="${matched[1]}"
  local err
  case "${assert_kind}" in
    image)
      err="$(assert_image "${first}" 2>&1)" || { record "${num}" "${action}" "FAIL" "${err}"; return; }
      ;;
    video)
      err="$(assert_media "${first}" v 2>&1)" || { record "${num}" "${action}" "FAIL" "${err}"; return; }
      ;;
    audio)
      err="$(assert_media "${first}" a 2>&1)" || { record "${num}" "${action}" "FAIL" "${err}"; return; }
      ;;
    pdf)
      err="$(assert_file "${first}" "PDF" 2>&1)" || { record "${num}" "${action}" "FAIL" "${err}"; return; }
      ;;
    text)
      err="$(assert_file "${first}" 2>&1)" || { record "${num}" "${action}" "FAIL" "${err}"; return; }
      local wc_words; wc_words="$(wc -w < "${first}" | tr -d ' ')"
      [[ "${wc_words}" -gt 0 ]] || { record "${num}" "${action}" "FAIL" "zero words in extracted text"; return; }
      ;;
    docx|html|md|epub|mobi|icns|ico|file)
      err="$(assert_file "${first}" 2>&1)" || { record "${num}" "${action}" "FAIL" "${err}"; return; }
      ;;
  esac
  record "${num}" "${action}" "PASS" "$(basename "${first}")"
}

echo "==> Verifying installed Quick Actions"
echo "    Services dir: ${SERVICES_DIR}"
echo "    Work dir:     ${WORK_DIR}"
echo

# Pre-flight: list installed workflows. (N) is zsh's null_glob qualifier so we
# don't crash on "no matches found" before printing a helpful error.
installed_wfs=("${SERVICES_DIR}"/MacConvert\ -\ *.workflow(N))
if [[ ${#installed_wfs[@]} -eq 0 ]]; then
  echo "ERROR: no MacConvert workflows installed. Run ./install.sh first." >&2
  exit 1
fi

echo "--- Images ---"
test_row  1 "Convert to PNG"          sample.jpg  "@DIR@/@BASE@.png"               image
test_row  2 "Convert to JPG"          sample.png  "@DIR@/@BASE@.jpg"               image
test_row  3 "Convert to WebP"         sample.png  "@DIR@/@BASE@.webp"              image
test_row  4 "Convert to HEIC"         sample.png  "@DIR@/@BASE@.heic"              image
test_row  5 "Convert to TIFF"         sample.png  "@DIR@/@BASE@.tiff"              image
test_row  6 "Convert to GIF"          sample.png  "@DIR@/@BASE@.gif"               image
test_row  7 "Convert to PDF"          sample.png  "@DIR@/@BASE@.pdf"               pdf
test_row  8 "Convert to AVIF"         sample.png  "@DIR@/@BASE@.avif"              image
test_row  9 "Convert to ICO"          sample.png  "@DIR@/@BASE@.ico"               ico
test_row 10 "Convert to ICNS"         sample.png  "@DIR@/@BASE@.icns"              icns

echo "--- SVG inputs (covers image conversions that previously broke for SVG) ---"
test_row 1.1 "Convert to PNG"          sample.svg  "@DIR@/@BASE@.png"               image
test_row 1.2 "Convert to JPG"          sample.svg  "@DIR@/@BASE@.jpg"               image
test_row 1.3 "Convert to WebP"         sample.svg  "@DIR@/@BASE@.webp"              image
test_row 1.4 "Convert to HEIC"         sample.svg  "@DIR@/@BASE@.heic"              image
test_row 1.5 "Convert to TIFF"         sample.svg  "@DIR@/@BASE@.tiff"              image
test_row 1.6 "Convert to PDF"          sample.svg  "@DIR@/@BASE@.pdf"               pdf

echo "--- Video ---"
test_row 11 "Convert to MP4 (H.264)"  sample.mov  "@DIR@/@BASE@.mp4"               video
test_row 12 "Convert to MP4 (HEVC)"   sample.mov  "@DIR@/@BASE@_hevc.mp4"          video
test_row 13 "Convert to MOV"          sample.mp4  "@DIR@/@BASE@.mov"               video
test_row 14 "Convert to WebM"         sample.mp4  "@DIR@/@BASE@.webm"              video
test_row 15 "Convert to MKV"          sample.mp4  "@DIR@/@BASE@.mkv"               video
test_row 16 "Convert to Animated GIF" sample.mp4  "@DIR@/@BASE@.gif"               image
test_row 17 "Extract Audio (MP3)"     sample.mp4  "@DIR@/@BASE@.mp3"               audio
test_row 18 "Extract Audio (M4A)"     sample.mp4  "@DIR@/@BASE@.m4a"               audio
test_row 19 "Extract Audio (WAV)"     sample.mp4  "@DIR@/@BASE@.wav"               audio
test_row 20 "Compress Video"          sample.mp4  "@DIR@/@BASE@_compressed.mp4"    video

echo "--- Audio ---"
test_row 21 "Convert to MP3"          sample.wav  "@DIR@/@BASE@.mp3"               audio
test_row 22 "Convert to WAV"          sample.mp3  "@DIR@/@BASE@.wav"               audio
test_row 23 "Convert to FLAC"         sample.wav  "@DIR@/@BASE@.flac"              audio
test_row 24 "Convert to M4A"          sample.wav  "@DIR@/@BASE@.m4a"               audio
test_row 25 "Convert to OGG"          sample.wav  "@DIR@/@BASE@.ogg"               audio
test_row 26 "Convert to OPUS"         sample.wav  "@DIR@/@BASE@.opus"              audio

echo "--- PDF ---"
test_row 27 "PDF to PNG (per page)"   sample.pdf  "@DIR@/@BASE@-page-*.png"        image
test_row 28 "PDF to JPG (per page)"   sample.pdf  "@DIR@/@BASE@-page-*.jpg"        image
test_row 29 "PDF to Text"             sample.pdf  "@DIR@/@BASE@.txt"               text
test_row 30 "Compress PDF"            sample.pdf  "@DIR@/@BASE@_compressed.pdf"    pdf
test_row 31 "PDF to DOCX"             sample.pdf  "@DIR@/@BASE@.docx"              docx

echo "--- Documents ---"
test_row 32 "DOCX to PDF"             sample.docx "@DIR@/@BASE@.pdf"               pdf
test_row 33 "DOCX to Markdown"        sample.docx "@DIR@/@BASE@.md"                md
test_row 34 "DOCX to HTML"            sample.docx "@DIR@/@BASE@.html"              html
test_row 35 "Markdown to PDF"         sample.md   "@DIR@/@BASE@.pdf"               pdf
test_row 36 "Markdown to DOCX"        sample.md   "@DIR@/@BASE@.docx"              docx
test_row 37 "Markdown to HTML"        sample.md   "@DIR@/@BASE@.html"              html
test_row 38 "HTML to Markdown"        sample.html "@DIR@/@BASE@.md"                md
test_row 39 "HTML to PDF"             sample.html "@DIR@/@BASE@.pdf"               pdf
test_row 39.1 "XLSX to PDF"           sample.xlsx "@DIR@/@BASE@.pdf"               pdf
test_row 39.2 "PPTX to PDF"           sample.pptx "@DIR@/@BASE@.pdf"               pdf

echo "--- Ebooks ---"
test_row 40 "EPUB to MOBI"            sample.epub "@DIR@/@BASE@.mobi"              mobi
test_row 41 "EPUB to PDF"             sample.epub "@DIR@/@BASE@.pdf"               pdf
# MOBI to EPUB: generate a mobi from epub first.
if [[ -f "${SAMPLES_DIR}/sample.mobi" ]] || \
   ${BREW_PREFIX}/bin/ebook-convert "${SAMPLES_DIR}/sample.epub" "${SAMPLES_DIR}/sample.mobi" >/dev/null 2>&1 || \
   /Applications/calibre.app/Contents/MacOS/ebook-convert "${SAMPLES_DIR}/sample.epub" "${SAMPLES_DIR}/sample.mobi" >/dev/null 2>&1; then
  test_row 42 "MOBI to EPUB"          sample.mobi "@DIR@/@BASE@.epub"              epub
else
  record 42 "MOBI to EPUB" "FAIL" "could not derive sample.mobi (calibre missing?)"
fi

echo
echo "==> Multi-select test: 3 images → 1 combined PDF (direct script call,"
echo "    since 'automator -i' CLI accepts only one input — Finder right-click"
echo "    passes the full selection as \$@ to the script, which is what we test here)."
m1="$(fresh_input "${SAMPLES_DIR}/sample.png" multi1)"
m2="$(fresh_input "${SAMPLES_DIR}/sample.jpg" multi2)"
m3="$(fresh_input "${SAMPLES_DIR}/sample.tiff" multi3)"
mdir="$(dirname "${m1}")"
rm -f "${mdir}/combined.pdf"
# Invoke the underlying script the same way Automator's Run Shell Script does
# when Finder hands it a multi-file selection: stripped PATH, args = files.
# Use the installed Application Support copy — that's what workflows actually
# point at, so testing the project copy could mask a stale install.
INSTALLED_SCRIPTS="${HOME}/Library/Application Support/MacConvert/scripts"
multi_script="${INSTALLED_SCRIPTS}/convert-image-to-pdf.sh"
[[ -x "${multi_script}" ]] || multi_script="${PROJECT_DIR}/scripts/convert-image-to-pdf.sh"
if env -i HOME="${HOME}" USER="${USER}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    /bin/zsh "${multi_script}" "${m1}" "${m2}" "${m3}" \
    >/dev/null 2>&1; then
  if [[ -f "${mdir}/combined.pdf" ]] && file "${mdir}/combined.pdf" | grep -qi PDF; then
    echo "  ✅ multi-select combined.pdf produced"
    multi_ok=1
  else
    echo "  ❌ no combined.pdf at ${mdir}/combined.pdf"
    multi_ok=0
  fi
else
  echo "  ❌ multi-select script returned non-zero"
  multi_ok=0
fi

echo
echo "==> Send to Kindle (dry run — parses Calibre config, builds SMTP args, skips actual send)"
sk_input="${WORK_DIR}/kindle-test.pdf"
cp "${SAMPLES_DIR}/sample.pdf" "${sk_input}"
sk_script="${INSTALLED_SCRIPTS}/send-to-kindle.sh"
[[ -x "${sk_script}" ]] || sk_script="${PROJECT_DIR}/scripts/send-to-kindle.sh"
if env -i HOME="${HOME}" USER="${USER}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    MACCONVERT_DRY_RUN=1 \
    /bin/zsh "${sk_script}" "${sk_input}" \
    >/dev/null 2>&1; then
  echo "  ✅ Send to Kindle (config parsed, args built)"
  kindle_ok=1
else
  echo "  ❌ Send to Kindle (dry run failed — calibre config or deps missing)"
  kindle_ok=0
fi

echo
echo "==> Filename edge-cases: spaces, accents, parentheses, ampersands"
edge_dir="${WORK_DIR}/edge"
mkdir -p "${edge_dir}"
edge_src="${edge_dir}/arquivo com espaços (1) ç & @.png"
cp "${SAMPLES_DIR}/sample.png" "${edge_src}"
if run_workflow "Convert to JPG" "${edge_src}"; then
  edge_out="${edge_dir}/arquivo com espaços (1) ç & @.jpg"
  if [[ -f "${edge_out}" ]] && file "${edge_out}" | grep -qi JPEG; then
    echo "  ✅ ${edge_out:t}"
    edge_ok=1
  else
    echo "  ❌ edge-case output missing"
    edge_ok=0
  fi
else
  echo "  ❌ edge-case automator failed"
  edge_ok=0
fi

echo
echo "==> Collision suffixing: run same conversion three times, expect (1)/(2)"
col_dir="${WORK_DIR}/col"
mkdir -p "${col_dir}"
cp "${SAMPLES_DIR}/sample.jpg" "${col_dir}/c.jpg"
run_workflow "Convert to PNG" "${col_dir}/c.jpg" >/dev/null
run_workflow "Convert to PNG" "${col_dir}/c.jpg" >/dev/null
run_workflow "Convert to PNG" "${col_dir}/c.jpg" >/dev/null
if [[ -f "${col_dir}/c.png" && -f "${col_dir}/c (1).png" && -f "${col_dir}/c (2).png" ]]; then
  echo "  ✅ c.png, c (1).png, c (2).png all present"
  col_ok=1
else
  echo "  ❌ collision suffixing broken: $(ls "${col_dir}" | tr '\n' ' ')"
  col_ok=0
fi

echo
echo "==> Summary: ${pass} pass / ${fail} fail (multi-select: ${multi_ok:-?}, edge-names: ${edge_ok:-?}, collision: ${col_ok:-?}, kindle: ${kindle_ok:-?})"
if [[ ${fail} -eq 0 && "${multi_ok:-0}" -eq 1 && "${edge_ok:-0}" -eq 1 && "${col_ok:-0}" -eq 1 && "${kindle_ok:-0}" -eq 1 ]]; then
  echo "ALL CLEAR"
  exit 0
fi
echo "FAILURES PRESENT"
exit 1
