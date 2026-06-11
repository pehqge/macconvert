#!/bin/zsh
# updater.sh — self-update from GitHub releases, plus the optional weekly
# auto-update LaunchAgent.

readonly MC_RELEASES_API="https://api.github.com/repos/${MC_REPO}/releases/latest"

# Latest released tag (e.g. "v1.2.0"), or empty on network failure.
mc_update_latest_tag() {
  /usr/bin/curl -fsSL --max-time 15 "${MC_RELEASES_API}" 2>/dev/null \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
}

# Compare two semver strings. Prints "newer" if $2 > $1, else "current".
mc_update_compare() {
  local current="${1#v}" latest="${2#v}"
  local -a c=("${(@s:.:)current}") l=("${(@s:.:)latest}")
  local i
  for i in 1 2 3; do
    (( ${l[${i}]:-0} > ${c[${i}]:-0} )) && { print -- "newer"; return; }
    (( ${l[${i}]:-0} < ${c[${i}]:-0} )) && { print -- "current"; return; }
  done
  print -- "current"
}

# `macconvert update [--check] [--quiet]`
mc_update() {
  local check_only=0 quiet=0 arg
  for arg in "$@"; do
    case "${arg}" in
      --check) check_only=1 ;;
      --quiet) quiet=1 ;;
    esac
  done

  local current; current="$(mc_version)"
  local latest;  latest="$(mc_update_latest_tag)"
  if [[ -z "${latest}" ]]; then
    (( quiet )) || mc_warn "could not reach GitHub to check for updates"
    return 1
  fi

  if [[ "$(mc_update_compare "${current}" "${latest}")" != "newer" ]]; then
    (( quiet )) || mc_ok "already up to date (${current})"
    return 0
  fi

  if (( check_only )); then
    print -- "update available: ${current} → ${latest}"
    print -- "run: ${MC_CLI_NAME} update"
    return 0
  fi

  (( quiet )) || mc_info "Updating ${current} → ${latest}"
  local tmp; tmp="$(mktemp -d -t macconvert-update)"
  {
    /usr/bin/curl -fsSL --max-time 120 \
      "https://github.com/${MC_REPO}/archive/refs/tags/${latest}.tar.gz" \
      -o "${tmp}/release.tar.gz" \
      && tar -xzf "${tmp}/release.tar.gz" -C "${tmp}"
  } || { rm -rf "${tmp}"; mc_error "download failed"; return 1; }

  local src
  src=("${tmp}"/*(N/))   # the single extracted directory
  if [[ ${#src[@]} -ne 1 || ! -f "${src[1]}/install.sh" ]]; then
    rm -rf "${tmp}"
    mc_error "unexpected release layout"
    return 1
  fi

  # The new version's installer copies the runtime and re-renders the
  # currently enabled Quick Actions; it never touches your selection.
  /bin/zsh "${src[1]}/install.sh" --update
  local rc=$?
  rm -rf "${tmp}"
  return ${rc}
}

# --- auto-update LaunchAgent -------------------------------------------------

mc_autoupdate_enabled() {
  [[ -f "${MC_LAUNCH_AGENT}" ]]
}

mc_autoupdate_on() {
  mkdir -p "${HOME}/Library/LaunchAgents"
  cat > "${MC_LAUNCH_AGENT}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${MC_BUNDLE_PREFIX}.autoupdate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>${MC_HOME}/bin/${MC_CLI_NAME}</string>
        <string>update</string>
        <string>--quiet</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>12</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${MC_LOG_DIR}/autoupdate.log</string>
    <key>StandardErrorPath</key>
    <string>${MC_LOG_DIR}/autoupdate.log</string>
</dict>
</plist>
EOF
  launchctl unload "${MC_LAUNCH_AGENT}" 2>/dev/null
  launchctl load "${MC_LAUNCH_AGENT}" 2>/dev/null
  mc_config_set auto_update on
  mc_ok "auto-update enabled (checks every Monday at noon)"
}

mc_autoupdate_off() {
  launchctl unload "${MC_LAUNCH_AGENT}" 2>/dev/null
  rm -f "${MC_LAUNCH_AGENT}"
  mc_config_set auto_update off
  mc_ok "auto-update disabled"
}
