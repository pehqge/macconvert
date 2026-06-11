#!/bin/zsh
ACTION_NAME="convert-docx-to-pdf"
source "$(dirname "$0")/_common.sh"

LIBREOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"

process_file() {
  local input="$1"
  local dir; dir="$(dirname "${input}")"
  local base; base="$(basename "${input}")"; base="$(strip_ext "${base}")"
  local out; out="$(unique_output_path "${dir}" "${base}" "pdf")"
  require_tool "${PANDOC}" "pandoc" || return 1

  # Prefer LibreOffice if installed (best fidelity, no LaTeX needed).
  if [[ -x "${LIBREOFFICE}" ]]; then
    local tmp; tmp="$(mktemp -d -t macconvert-docx2pdf)"
    if "${LIBREOFFICE}" --headless --convert-to pdf --outdir "${tmp}" "${input}" >>"${LOG_FILE}" 2>&1; then
      local generated="${tmp}/${base}.pdf"
      if [[ -f "${generated}" ]]; then
        mv "${generated}" "${out}"
        rm -rf "${tmp}"
        LAST_OUTPUT_BASENAME="$(basename "${out}")"
        log "OK (libreoffice) -> ${out}"
        return 0
      fi
    fi
    rm -rf "${tmp}"
    log "LibreOffice path failed, trying pandoc"
  fi

  # Pandoc fallback: try with available HTML engines (no LaTeX).
  for engine in weasyprint wkhtmltopdf prince; do
    local engpath; engpath="$(find_pdf_engine "${engine}")" || continue
    if "${PANDOC}" "${input}" --pdf-engine="${engpath}" -o "${out}" >>"${LOG_FILE}" 2>&1; then
      LAST_OUTPUT_BASENAME="$(basename "${out}")"
      log "OK (${engine}) -> ${out}"
      return 0
    fi
  done

  # Last resort: try xelatex/pdflatex if MacTeX is installed.
  for engine in xelatex pdflatex; do
    local engpath; engpath="$(find_pdf_engine "${engine}")" || continue
    if "${PANDOC}" "${input}" --pdf-engine="${engpath}" -o "${out}" >>"${LOG_FILE}" 2>&1; then
      LAST_OUTPUT_BASENAME="$(basename "${out}")"
      log "OK (${engine}) -> ${out}"
      return 0
    fi
  done

  log "No PDF engine available. Install LibreOffice ('brew install --cask libreoffice') or MacTeX."
  return 1
}

run_batch "$@"
