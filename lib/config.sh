#!/bin/zsh
# config.sh — read/write the user config file.
#
# Format: one `key=value` per line, written only by us. The file is parsed,
# never sourced, so a tampered config can't execute code. Secrets never land
# here — the SMTP password lives in the macOS Keychain (see kindle.sh).
#
# Keys in use:
#   kindle_email     destination @kindle.com address
#   smtp_from        sender address (must be on Amazon's approved list)
#   smtp_host        SMTP relay host
#   smtp_port        SMTP relay port
#   smtp_user        SMTP username (usually same as smtp_from)
#   auto_update      "on" when the weekly LaunchAgent is installed

mc_config_get() {
  local key="$1" line
  [[ -f "${MC_CONFIG_FILE}" ]] || return 1
  while IFS= read -r line; do
    [[ "${line}" == "${key}="* ]] && { print -r -- "${line#*=}"; return 0; }
  done < "${MC_CONFIG_FILE}"
  return 1
}

mc_config_set() {
  local key="$1" value="$2"
  mkdir -p "${MC_CONFIG_DIR}"
  local tmp="${MC_CONFIG_FILE}.tmp.$$"
  : > "${tmp}"
  chmod 600 "${tmp}"
  local line
  if [[ -f "${MC_CONFIG_FILE}" ]]; then
    while IFS= read -r line; do
      [[ "${line}" == "${key}="* ]] || print -r -- "${line}" >> "${tmp}"
    done < "${MC_CONFIG_FILE}"
  fi
  print -r -- "${key}=${value}" >> "${tmp}"
  mv -f "${tmp}" "${MC_CONFIG_FILE}"
}

mc_config_unset() {
  local key="$1" line
  [[ -f "${MC_CONFIG_FILE}" ]] || return 0
  local tmp="${MC_CONFIG_FILE}.tmp.$$"
  : > "${tmp}"
  chmod 600 "${tmp}"
  while IFS= read -r line; do
    [[ "${line}" == "${key}="* ]] || print -r -- "${line}" >> "${tmp}"
  done < "${MC_CONFIG_FILE}"
  mv -f "${tmp}" "${MC_CONFIG_FILE}"
}
