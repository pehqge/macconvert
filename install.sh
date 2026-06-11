#!/bin/zsh
# MacConvert installer.
#
#   From a clone:   ./install.sh
#   One-liner:      zsh -c "$(curl -fsSL https://raw.githubusercontent.com/pehqge/macconvert/main/install.sh)"
#
# What it does, in order:
#   1. copies the runtime to ~/Library/Application Support/MacConvert
#      (the clone becomes disposable — Quick Actions never point into it)
#   2. links the `macconvert` CLI into Homebrew's bin
#   3. hands off to `macconvert setup` — the interactive picker where you
#      choose which Quick Actions to enable
#
# Flags: --update (refresh runtime + re-render enabled actions, no prompts)
#        --all    (enable every action, no prompts)
#
# The whole script runs inside main(), so a partially-downloaded copy can
# never execute half-way.

# zsh-only syntax ahead; re-exec if invoked via bash/sh.
if [[ -z "${ZSH_VERSION:-}" ]]; then
  if [[ -x /bin/zsh ]]; then
    exec /bin/zsh "$0" "$@"
  fi
  echo "ERROR: install.sh requires zsh (preinstalled on macOS)." >&2
  exit 1
fi

set -u
set -o pipefail

readonly REPO="pehqge/macconvert"
readonly APP_NAME="MacConvert"
readonly CLI_NAME="macconvert"
readonly RUNTIME_DIR="${HOME}/Library/Application Support/${APP_NAME}"

say()  { print -- "\e[34m==>\e[0m \e[1m$*\e[0m"; }
ok()   { print -- "    \e[32m✓\e[0m $*"; }
fail() { print -- "\e[31merror:\e[0m $*" >&2; exit 1; }

# Locate the repo files: next to this script when run from a clone, otherwise
# download the latest release tarball (curl-install mode).
resolve_source() {
  local here="${1:A:h}"
  if [[ -f "${here}/lib/core.sh" && -x "${here}/bin/${CLI_NAME}" ]]; then
    print -r -- "${here}"
    return 0
  fi

  say "Downloading the latest ${APP_NAME} release" >&2
  local tmp; tmp="$(mktemp -d -t macconvert-install)" || fail "mktemp failed"
  local tag
  tag="$(/usr/bin/curl -fsSL --max-time 15 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
  local url
  if [[ -n "${tag}" ]]; then
    url="https://github.com/${REPO}/archive/refs/tags/${tag}.tar.gz"
  else
    url="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
  fi
  /usr/bin/curl -fsSL --max-time 120 "${url}" -o "${tmp}/src.tar.gz" \
    || fail "download failed: ${url}"
  tar -xzf "${tmp}/src.tar.gz" -C "${tmp}" || fail "extract failed"
  local -a extracted
  extracted=("${tmp}"/*(N/))
  [[ ${#extracted[@]} -eq 1 ]] || fail "unexpected archive layout"
  print -r -- "${extracted[1]}"
}

install_runtime() {
  local src="$1"
  say "Installing runtime to ${RUNTIME_DIR}"
  mkdir -p "${RUNTIME_DIR}"

  local dir
  for dir in bin lib scripts; do
    rm -rf "${RUNTIME_DIR}/${dir}"
    cp -R "${src}/${dir}" "${RUNTIME_DIR}/${dir}" || fail "copy failed: ${dir}"
  done
  cp -f "${src}/VERSION" "${RUNTIME_DIR}/VERSION"
  mkdir -p "${RUNTIME_DIR}/resources"
  cp -f "${src}/resources/icon.icns" "${src}/resources/icon-menu.png" \
    "${RUNTIME_DIR}/resources/" 2>/dev/null

  chmod +x "${RUNTIME_DIR}/bin/${CLI_NAME}" "${RUNTIME_DIR}"/scripts/*.sh
  ok "runtime $(cat "${RUNTIME_DIR}/VERSION") installed"
}

link_cli() {
  local brew_prefix
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_prefix=/opt/homebrew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_prefix=/usr/local
  else
    fail "Homebrew is required (conversion tools install through it). Get it at https://brew.sh and rerun."
  fi
  ln -sf "${RUNTIME_DIR}/bin/${CLI_NAME}" "${brew_prefix}/bin/${CLI_NAME}"
  ok "CLI linked: ${brew_prefix}/bin/${CLI_NAME}"
}

main() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "${APP_NAME} is macOS-only (it installs Finder Quick Actions)."

  local mode="setup"
  case "${1:-}" in
    --update) mode="update" ;;
    --all)    mode="all" ;;
  esac

  local src; src="$(resolve_source "$0")"
  install_runtime "${src}"
  link_cli

  case "${mode}" in
    update) exec "${RUNTIME_DIR}/bin/${CLI_NAME}" __rerender ;;
    all)    exec "${RUNTIME_DIR}/bin/${CLI_NAME}" enable --all ;;
    *)      exec "${RUNTIME_DIR}/bin/${CLI_NAME}" setup ;;
  esac
}

main "$@"
