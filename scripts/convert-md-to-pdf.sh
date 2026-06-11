#!/bin/zsh
ACTION_NAME="convert-md-to-pdf"
source "$(dirname "$0")/_common.sh"

LIBREOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "pdf")"
  require_tool "${PANDOC}" "pandoc" || return 1

  # Try direct HTML→PDF engines first (no LaTeX needed).
  for engine in weasyprint wkhtmltopdf prince; do
    local engpath; engpath="$(find_pdf_engine "${engine}")" || continue
    if "${PANDOC}" "${input}" --pdf-engine="${engpath}" -o "${out}" >>"${LOG_FILE}" 2>&1; then
      LAST_OUTPUT_BASENAME="$(basename "${out}")"
      log "OK (${engine}) -> ${out}"
      return 0
    fi
  done

  # LaTeX engines.
  for engine in xelatex pdflatex tectonic; do
    local engpath; engpath="$(find_pdf_engine "${engine}")" || continue
    if "${PANDOC}" "${input}" --pdf-engine="${engpath}" -o "${out}" >>"${LOG_FILE}" 2>&1; then
      LAST_OUTPUT_BASENAME="$(basename "${out}")"
      log "OK (${engine}) -> ${out}"
      return 0
    fi
  done

  # LibreOffice fallback: pandoc → DOCX → libreoffice → PDF.
  if [[ -x "${LIBREOFFICE}" ]]; then
    local tmpd; tmpd="$(mktemp -d -t macconvert-md2pdf)"
    local tmpdocx="${tmpd}/${base}.docx"
    if "${PANDOC}" "${input}" -o "${tmpdocx}" >>"${LOG_FILE}" 2>&1; then
      if "${LIBREOFFICE}" --headless --convert-to pdf --outdir "${tmpd}" "${tmpdocx}" >>"${LOG_FILE}" 2>&1; then
        local generated="${tmpd}/${base}.pdf"
        if [[ -f "${generated}" ]]; then
          mv "${generated}" "${out}"
          rm -rf "${tmpd}"
          LAST_OUTPUT_BASENAME="$(basename "${out}")"
          log "OK (libreoffice) -> ${out}"
          return 0
        fi
      fi
    fi
    rm -rf "${tmpd}"
  fi

  log "No PDF engine available. Install one of: weasyprint, wkhtmltopdf, MacTeX, or LibreOffice."
  return 1
}

run_batch "$@"
