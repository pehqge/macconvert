#!/bin/zsh
# core.sh — shared constants and helpers for the macconvert CLI.
#
# Every identity-related string lives here so renaming the project is a
# one-file change. Sourced by bin/macconvert and every lib/ module.

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------
readonly MC_APP_NAME="MacConvert"            # human-facing name
readonly MC_CLI_NAME="macconvert"            # binary / config-dir name
readonly MC_BUNDLE_PREFIX="com.macconvert"   # CFBundleIdentifier prefix
readonly MC_REPO="pehqge/macconvert"         # GitHub owner/repo, used by updater
readonly MC_TAP_FORMULA="pehqge/tap/macconvert"  # Homebrew tap formula
readonly MC_WORKFLOW_PREFIX="${MC_APP_NAME} - "  # on-disk Services filename prefix

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
readonly MC_HOME="${HOME}/Library/Application Support/${MC_APP_NAME}"
readonly MC_SCRIPTS_DIR="${MC_HOME}/scripts"
readonly MC_RESOURCES_DIR="${MC_HOME}/resources"
readonly MC_SERVICES_DIR="${HOME}/Library/Services"
readonly MC_LOG_DIR="${HOME}/Library/Logs/${MC_CLI_NAME}"
readonly MC_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/${MC_CLI_NAME}"
readonly MC_CONFIG_FILE="${MC_CONFIG_DIR}/config"
readonly MC_LAUNCH_AGENT="${HOME}/Library/LaunchAgents/${MC_BUNDLE_PREFIX}.autoupdate.plist"
readonly MC_KEYCHAIN_SERVICE="${MC_CLI_NAME}"

# MC_ROOT — where the CLI's own lib/scripts live. bin/macconvert sets this
# before sourcing; default to the installed location for direct sourcing.
: "${MC_ROOT:=${MC_HOME}}"

# ---------------------------------------------------------------------------
# Homebrew prefix (Apple Silicon and Intel)
# ---------------------------------------------------------------------------
if [[ -x /opt/homebrew/bin/brew ]]; then
  readonly MC_BREW_PREFIX="/opt/homebrew"
elif [[ -x /usr/local/bin/brew ]]; then
  readonly MC_BREW_PREFIX="/usr/local"
else
  readonly MC_BREW_PREFIX=""
fi

# ---------------------------------------------------------------------------
# Terminal output
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  readonly MC_BOLD=$'\e[1m' MC_DIM=$'\e[2m' MC_RESET=$'\e[0m'
  readonly MC_GREEN=$'\e[32m' MC_RED=$'\e[31m' MC_YELLOW=$'\e[33m'
  readonly MC_BLUE=$'\e[34m' MC_CYAN=$'\e[36m'
else
  readonly MC_BOLD="" MC_DIM="" MC_RESET=""
  readonly MC_GREEN="" MC_RED="" MC_YELLOW="" MC_BLUE="" MC_CYAN=""
fi

mc_info()  { print -- "${MC_BLUE}==>${MC_RESET} ${MC_BOLD}$*${MC_RESET}"; }
mc_ok()    { print -- "    ${MC_GREEN}✓${MC_RESET} $*"; }
mc_warn()  { print -- "    ${MC_YELLOW}!${MC_RESET} $*" >&2; }
mc_error() { print -- "${MC_RED}error:${MC_RESET} $*" >&2; }
mc_die()   { mc_error "$*"; exit 1; }

# Ask a yes/no question. Usage: mc_confirm "Question?" [default:y|n]
mc_confirm() {
  local question="$1" default="${2:-y}" hint reply
  [[ "${default}" == "y" ]] && hint="Y/n" || hint="y/N"
  while true; do
    read -r "reply?${question} ${MC_DIM}[${hint}]${MC_RESET} "
    reply="${reply:l}"
    [[ -z "${reply}" ]] && reply="${default}"
    case "${reply}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
    esac
  done
}

# Installed version, read from the VERSION file shipped with the runtime.
mc_version() {
  if [[ -f "${MC_ROOT}/VERSION" ]]; then
    cat "${MC_ROOT}/VERSION"
  else
    print -- "unknown"
  fi
}
