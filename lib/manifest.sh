#!/bin/zsh
# manifest.sh — the single source of truth for every Quick Action.
#
# Record format (pipe-delimited):
#   id | category | menu label | input UTIs (csv) | script | deps (csv)
#
# deps are Homebrew formula names; "cask:" prefix marks casks. The installer
# only installs the dependencies of the actions the user actually enables.
#
# MOBI / AZW / AZW3 have no stable system UTIs on macOS; files get
# extension-derived dynamic UTIs. The dyn.* strings are the actual UTIs macOS
# assigns to .mobi / .azw / .azw3 — captured via `mdls` and pinned here.

readonly MC_UTI_MOBI="com.amazon.mobi-pocket-ebook,dyn.ah62d4rv4ge80455cre,dyn.ah62d4rv4ge80c8x1gq,dyn.ah62d4rv4ge80c8x1"
readonly MC_UTI_DOCX="org.openxmlformats.wordprocessingml.document"
readonly MC_UTI_MD="net.daringfireball.markdown,public.plain-text"

readonly -a MC_ACTIONS=(
  # --- Images -------------------------------------------------------------
  "png|Images|Convert to PNG|public.image|convert-image-to-png.sh|imagemagick,librsvg"
  "jpg|Images|Convert to JPG|public.image|convert-image-to-jpg.sh|imagemagick,librsvg"
  "webp|Images|Convert to WebP|public.image|convert-image-to-webp.sh|imagemagick,webp,librsvg"
  "heic|Images|Convert to HEIC|public.image|convert-image-to-heic.sh|imagemagick,librsvg"
  "tiff|Images|Convert to TIFF|public.image|convert-image-to-tiff.sh|imagemagick,librsvg"
  "gif|Images|Convert to GIF|public.image|convert-image-to-gif.sh|imagemagick,librsvg"
  "avif|Images|Convert to AVIF|public.image|convert-image-to-avif.sh|imagemagick,ffmpeg,librsvg"
  "ico|Images|Convert to ICO|public.image|convert-image-to-ico.sh|imagemagick,librsvg"
  "icns|Images|Convert to ICNS|public.image|convert-image-to-icns.sh|imagemagick,librsvg"
  "image-pdf|Images|Convert to PDF|public.image|convert-image-to-pdf.sh|imagemagick,librsvg"

  # --- Video ----------------------------------------------------------------
  "mp4|Video|Convert to MP4 (H.264)|public.movie|convert-video-to-mp4.sh|ffmpeg"
  "hevc|Video|Convert to MP4 (HEVC)|public.movie|convert-video-to-mp4-hevc.sh|ffmpeg"
  "mov|Video|Convert to MOV|public.movie|convert-video-to-mov.sh|ffmpeg"
  "webm|Video|Convert to WebM|public.movie|convert-video-to-webm.sh|ffmpeg"
  "mkv|Video|Convert to MKV|public.movie|convert-video-to-mkv.sh|ffmpeg"
  "video-gif|Video|Convert to Animated GIF|public.movie|convert-video-to-gif.sh|ffmpeg"
  "extract-mp3|Video|Extract Audio (MP3)|public.movie|extract-audio-mp3.sh|ffmpeg"
  "extract-m4a|Video|Extract Audio (M4A)|public.movie|extract-audio-m4a.sh|ffmpeg"
  "extract-wav|Video|Extract Audio (WAV)|public.movie|extract-audio-wav.sh|ffmpeg"
  "compress-video|Video|Compress Video|public.movie|compress-video.sh|ffmpeg"

  # --- Audio ----------------------------------------------------------------
  "mp3|Audio|Convert to MP3|public.audio|convert-audio-to-mp3.sh|ffmpeg"
  "wav|Audio|Convert to WAV|public.audio|convert-audio-to-wav.sh|ffmpeg"
  "flac|Audio|Convert to FLAC|public.audio|convert-audio-to-flac.sh|ffmpeg"
  "m4a|Audio|Convert to M4A|public.audio|convert-audio-to-m4a.sh|ffmpeg"
  "ogg|Audio|Convert to OGG|public.audio|convert-audio-to-ogg.sh|ffmpeg,vorbis-tools"
  "opus|Audio|Convert to OPUS|public.audio|convert-audio-to-opus.sh|ffmpeg"

  # --- PDF ------------------------------------------------------------------
  "pdf-png|PDF|PDF to PNG (per page)|com.adobe.pdf|convert-pdf-to-png.sh|imagemagick,ghostscript"
  "pdf-jpg|PDF|PDF to JPG (per page)|com.adobe.pdf|convert-pdf-to-jpg.sh|imagemagick,ghostscript"
  "pdf-text|PDF|PDF to Text|com.adobe.pdf|convert-pdf-to-text.sh|poppler"
  "compress-pdf|PDF|Compress PDF|com.adobe.pdf|compress-pdf.sh|ghostscript"
  "pdf-docx|PDF|PDF to DOCX|com.adobe.pdf|convert-pdf-to-docx.sh|pandoc,poppler"

  # --- Documents --------------------------------------------------------------
  "docx-pdf|Documents|DOCX to PDF|${MC_UTI_DOCX}|convert-docx-to-pdf.sh|pandoc,cask:libreoffice"
  "docx-md|Documents|DOCX to Markdown|${MC_UTI_DOCX}|convert-docx-to-md.sh|pandoc"
  "docx-html|Documents|DOCX to HTML|${MC_UTI_DOCX}|convert-docx-to-html.sh|pandoc"
  "md-pdf|Documents|Markdown to PDF|${MC_UTI_MD}|convert-md-to-pdf.sh|pandoc,cask:libreoffice"
  "md-docx|Documents|Markdown to DOCX|${MC_UTI_MD}|convert-md-to-docx.sh|pandoc"
  "md-html|Documents|Markdown to HTML|${MC_UTI_MD}|convert-md-to-html.sh|pandoc"
  "html-md|Documents|HTML to Markdown|public.html|convert-html-to-md.sh|pandoc"
  "html-pdf|Documents|HTML to PDF|public.html|convert-html-to-pdf.sh|pandoc,cask:libreoffice"
  "xlsx-pdf|Documents|XLSX to PDF|org.openxmlformats.spreadsheetml.sheet|convert-xlsx-to-pdf.sh|cask:libreoffice"
  "pptx-pdf|Documents|PPTX to PDF|org.openxmlformats.presentationml.presentation|convert-pptx-to-pdf.sh|cask:libreoffice"

  # --- Ebooks -----------------------------------------------------------------
  "epub-mobi|Ebooks|EPUB to MOBI|org.idpf.epub-container|convert-epub-to-mobi.sh|cask:calibre"
  "epub-pdf|Ebooks|EPUB to PDF|org.idpf.epub-container|convert-epub-to-pdf.sh|cask:calibre"
  "mobi-epub|Ebooks|MOBI to EPUB|${MC_UTI_MOBI}|convert-mobi-to-epub.sh|cask:calibre"

  # --- Kindle -----------------------------------------------------------------
  # UTIs limited to formats Amazon's Send to Kindle accepts (2025+): PDF, EPUB,
  # DOC/DOCX, TXT, RTF, HTML. MOBI was dropped by Amazon in March 2025.
  "kindle|Kindle|Send to Kindle|com.adobe.pdf,org.idpf.epub-container,${MC_UTI_DOCX},com.microsoft.word.doc,public.html,public.plain-text,public.rtf|send-to-kindle.sh|"
)

# Ordered category list (drives menu section order).
readonly -a MC_CATEGORIES=(Images Video Audio PDF Documents Ebooks Kindle)

# ---------------------------------------------------------------------------
# Accessors — every consumer goes through these, never parses records itself.
# ---------------------------------------------------------------------------

# All action ids, in manifest order.
mc_action_ids() {
  local row
  for row in "${MC_ACTIONS[@]}"; do print -- "${row%%|*}"; done
}

# Look up one record by id; prints the full row or returns 1.
mc_action_row() {
  local id="$1" row
  for row in "${MC_ACTIONS[@]}"; do
    [[ "${row%%|*}" == "${id}" ]] && { print -r -- "${row}"; return 0; }
  done
  return 1
}

# Field accessors. Usage: mc_action_field <id> <category|label|utis|script|deps>
mc_action_field() {
  local id="$1" field="$2" row
  row="$(mc_action_row "${id}")" || return 1
  local -a parts
  parts=("${(@s:|:)row}")
  case "${field}" in
    id)       print -r -- "${parts[1]}" ;;
    category) print -r -- "${parts[2]}" ;;
    label)    print -r -- "${parts[3]}" ;;
    utis)     print -r -- "${parts[4]}" ;;
    script)   print -r -- "${parts[5]}" ;;
    deps)     print -r -- "${parts[6]:-}" ;;
    *)        return 1 ;;
  esac
}

# Ids belonging to one category, in manifest order.
mc_actions_in_category() {
  local category="$1" row
  for row in "${MC_ACTIONS[@]}"; do
    local -a parts
    parts=("${(@s:|:)row}")
    [[ "${parts[2]}" == "${category}" ]] && print -- "${parts[1]}"
  done
}

# Union of deps for a list of ids (one per line, deduped, casks included).
mc_deps_for() {
  local -A seen
  local id dep deps
  for id in "$@"; do
    deps="$(mc_action_field "${id}" deps)" || continue
    for dep in "${(@s:,:)deps}"; do
      [[ -n "${dep}" && -z "${seen[${dep}]:-}" ]] && { seen[${dep}]=1; print -- "${dep}"; }
    done
  done
}
