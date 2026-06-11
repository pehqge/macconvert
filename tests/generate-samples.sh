#!/bin/zsh
# Reproducibly generates the sample/ corpus used by verify.sh.
# Idempotent: only regenerates missing files.

set -u
set -o pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES_DIR="${PROJECT_DIR}/samples"
mkdir -p "${SAMPLES_DIR}"

BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
FFMPEG="${BREW_PREFIX}/bin/ffmpeg"
MAGICK="${BREW_PREFIX}/bin/magick"
PANDOC="${BREW_PREFIX}/bin/pandoc"

cd "${SAMPLES_DIR}" || { echo "ERROR: cannot cd into ${SAMPLES_DIR}" >&2; exit 1; }

need() { [[ ! -f "$1" ]]; }

# --- Images ---
if need sample.png; then
  echo "  sample.png"
  # No -annotate (system font detection is unreliable in some IM builds).
  "${MAGICK}" -size 320x240 gradient:'#ff7f50-#1e90ff' \
    -draw "fill white rectangle 60,90 260,150" sample.png
fi
if need sample.jpg; then
  echo "  sample.jpg"
  "${MAGICK}" sample.png -background white -alpha remove -alpha off -quality 92 sample.jpg
fi
if need sample.tiff; then
  echo "  sample.tiff"
  "${MAGICK}" sample.png sample.tiff
fi
if need sample.gif; then
  echo "  sample.gif"
  "${MAGICK}" -delay 20 -size 200x200 \
    xc:red xc:green xc:blue -loop 0 sample.gif
fi
if need sample.bmp; then
  echo "  sample.bmp"
  "${MAGICK}" sample.png sample.bmp
fi
if need sample.webp; then
  echo "  sample.webp"
  "${MAGICK}" sample.png sample.webp
fi
if need sample.heic; then
  echo "  sample.heic"
  "${MAGICK}" sample.png -quality 90 sample.heic 2>/dev/null || \
    "${MAGICK}" sample.png HEIC:sample.heic 2>/dev/null || \
    cp sample.png sample.heic  # last resort placeholder
fi
if need sample.svg; then
  echo "  sample.svg"
  cat > sample.svg <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240" viewBox="0 0 320 240">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ff7f50"/>
      <stop offset="1" stop-color="#1e90ff"/>
    </linearGradient>
  </defs>
  <rect width="320" height="240" fill="url(#g)"/>
  <text x="160" y="130" text-anchor="middle" font-family="Helvetica" font-size="28" fill="white">SVG Sample</text>
</svg>
EOF
fi

# --- PDF (multi-page) ---
if need sample.pdf; then
  echo "  sample.pdf"
  # Multi-page PDF via pandoc → reliable, no font dependencies.
  cat > /tmp/macconvert-pdf-src.md <<'PDFEOF'
# Page 1

MacConvert sample content for verification.

\newpage

# Page 2

Second page with **more** text for OCR / extraction checks.
This page exists so multi-page PDF conversions can be tested.
PDFEOF
  # Try pandoc with available engines; fallback to magick if all fail.
  pdf_made=0
  for engine in weasyprint wkhtmltopdf xelatex pdflatex; do
    if command -v "${engine}" >/dev/null 2>&1; then
      if "${PANDOC}" /tmp/macconvert-pdf-src.md --pdf-engine="${engine}" -o sample.pdf 2>/dev/null; then
        pdf_made=1; break
      fi
    fi
  done
  if [[ ${pdf_made} -eq 0 ]]; then
    # Last resort: magick with no text.
    "${MAGICK}" \
      \( -size 612x792 xc:white -fill black -draw "rectangle 100,100 500,200" \) \
      \( -size 612x792 xc:white -fill black -draw "rectangle 100,300 500,400" \) \
      sample.pdf
  fi
  rm -f /tmp/macconvert-pdf-src.md
fi

# --- Video / audio ---
if need sample.mp4; then
  echo "  sample.mp4"
  "${FFMPEG}" -y -f lavfi -i "testsrc=duration=3:size=320x240:rate=15" \
    -f lavfi -i "sine=frequency=440:duration=3" \
    -c:v libx264 -preset ultrafast -crf 28 -pix_fmt yuv420p \
    -c:a aac -b:a 96k -shortest sample.mp4 >/dev/null 2>&1
fi
if need sample.mov; then
  echo "  sample.mov"
  "${FFMPEG}" -y -i sample.mp4 -c copy sample.mov >/dev/null 2>&1
fi
if need sample.mkv; then
  echo "  sample.mkv"
  "${FFMPEG}" -y -i sample.mp4 -c copy sample.mkv >/dev/null 2>&1
fi
if need sample.webm; then
  echo "  sample.webm"
  "${FFMPEG}" -y -i sample.mp4 -c:v libvpx -b:v 200k -c:a libopus sample.webm >/dev/null 2>&1
fi

if need sample.wav; then
  echo "  sample.wav"
  "${FFMPEG}" -y -f lavfi -i "sine=frequency=440:duration=3" -ar 44100 sample.wav >/dev/null 2>&1
fi
if need sample.mp3; then
  echo "  sample.mp3"
  "${FFMPEG}" -y -i sample.wav -c:a libmp3lame -b:a 128k sample.mp3 >/dev/null 2>&1
fi
if need sample.flac; then
  echo "  sample.flac"
  "${FFMPEG}" -y -i sample.wav -c:a flac sample.flac >/dev/null 2>&1
fi
if need sample.m4a; then
  echo "  sample.m4a"
  "${FFMPEG}" -y -i sample.wav -c:a aac -b:a 128k sample.m4a >/dev/null 2>&1
fi
if need sample.aac; then
  echo "  sample.aac"
  "${FFMPEG}" -y -i sample.wav -c:a aac -b:a 128k sample.aac >/dev/null 2>&1
fi
if need sample.ogg; then
  echo "  sample.ogg"
  # libvorbis not always available; use built-in experimental vorbis encoder.
  if ! "${FFMPEG}" -y -i sample.wav -c:a libvorbis sample.ogg >/dev/null 2>&1; then
    "${FFMPEG}" -y -i sample.wav -c:a vorbis -strict experimental sample.ogg >/dev/null 2>&1 || \
      "${FFMPEG}" -y -i sample.wav -c:a libopus sample.ogg >/dev/null 2>&1
  fi
fi

# --- Text/markup ---
if need sample.txt; then
  echo "  sample.txt"
  printf 'MacConvert sample text\nLine two\nLine three\n' > sample.txt
fi
if need sample.md; then
  echo "  sample.md"
  cat > sample.md <<'EOF'
# MacConvert Sample

This is **bold**, this is *italic*.

- bullet one
- bullet two
- bullet three

> A blockquote.

```
code block
```
EOF
fi
if need sample.html; then
  echo "  sample.html"
  cat > sample.html <<'EOF'
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Sample</title></head>
<body>
<h1>MacConvert Sample</h1>
<p>This is a <strong>bold</strong> word and an <em>italic</em> one.</p>
<ul><li>one</li><li>two</li><li>three</li></ul>
</body></html>
EOF
fi

if need sample.docx; then
  echo "  sample.docx"
  "${PANDOC}" sample.md -o sample.docx
fi

# --- EPUB ---
if need sample.epub; then
  echo "  sample.epub"
  # Build a minimal EPUB from markdown via pandoc.
  "${PANDOC}" -o sample.epub sample.md --metadata title="MacConvert Sample"
fi

LIBREOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
if need sample.xlsx && [[ -x "${LIBREOFFICE}" ]]; then
  echo "  sample.xlsx"
  printf "Name,Value\nA,1\nB,2\nC,3\n" > /tmp/mc-sample.csv
  "${LIBREOFFICE}" --headless --convert-to xlsx --outdir "${SAMPLES_DIR}" /tmp/mc-sample.csv >/dev/null 2>&1
  mv "${SAMPLES_DIR}/mc-sample.xlsx" "${SAMPLES_DIR}/sample.xlsx" 2>/dev/null || true
  rm -f /tmp/mc-sample.csv
fi
if need sample.pptx; then
  echo "  sample.pptx"
  "${PANDOC}" sample.md -o sample.pptx >/dev/null 2>&1
fi

echo "Samples ready in ${SAMPLES_DIR}"
ls -1 "${SAMPLES_DIR}"
