#!/bin/zsh
# services.sh — installs/removes Quick Actions and keeps macOS's Services
# registry (pbs) in sync.
#
# The set of *enabled* actions is exactly the set of installed .workflow
# bundles in ~/Library/Services — no shadow state to drift out of sync.

# Path of the bundle for an action id.
mc_service_path() {
  local id="$1"
  local label; label="$(mc_action_field "${id}" label)" || return 1
  print -r -- "${MC_SERVICES_DIR}/${MC_WORKFLOW_PREFIX}${label}.workflow"
}

mc_service_installed() {
  [[ -d "$(mc_service_path "$1")" ]]
}

# Ids of all currently installed actions, in manifest order.
mc_services_installed_ids() {
  local id
  for id in $(mc_action_ids); do
    mc_service_installed "${id}" && print -- "${id}"
  done
}

# Install (or refresh) the Quick Action for one id.
mc_service_install() {
  local id="$1"
  local label utis script
  label="$(mc_action_field "${id}" label)" || { mc_error "unknown action: ${id}"; return 1; }
  utis="$(mc_action_field "${id}" utis)"
  script="${MC_SCRIPTS_DIR}/$(mc_action_field "${id}" script)"
  [[ -x "${script}" ]] || { mc_error "runtime script missing: ${script}"; return 1; }
  mkdir -p "${MC_SERVICES_DIR}"
  mc_bundle_write "${MC_WORKFLOW_PREFIX}${label}" "${utis}" "${script}" "${MC_SERVICES_DIR}" "${label}" \
    && mc_service_enable "${id}"
}

mc_service_remove() {
  local id="$1"
  # NB: not named "path" — zsh ties that to $PATH.
  local bundle; bundle="$(mc_service_path "${id}")" || return 1
  rm -rf "${bundle}"
}

# Flip the pbs (Services pasteboard) switches so the action shows up in the
# right-click menu immediately, without a trip to System Settings. Workflow
# bundles have no CFBundleIdentifier (on purpose — see bundle.sh), so pbs
# keys them as "(null) - <menu-label> - runWorkflowAsService".
mc_service_enable() {
  local id="$1"
  local label; label="$(mc_action_field "${id}" label)"
  local key="(null) - ${label} - runWorkflowAsService"
  local plist="${HOME}/Library/Preferences/pbs.plist"
  local pb=/usr/libexec/PlistBuddy

  "${pb}" -c "Add :NSServicesStatus dict" "${plist}" 2>/dev/null
  "${pb}" -c "Delete :NSServicesStatus:'${key}'" "${plist}" 2>/dev/null
  "${pb}" -c "Add :NSServicesStatus:'${key}' dict" "${plist}" 2>/dev/null || return 0
  "${pb}" -c "Add :NSServicesStatus:'${key}':presentation_modes dict" "${plist}" 2>/dev/null
  "${pb}" -c "Add :NSServicesStatus:'${key}':presentation_modes:ContextMenu bool true" "${plist}" 2>/dev/null
  "${pb}" -c "Add :NSServicesStatus:'${key}':presentation_modes:FinderPreview bool true" "${plist}" 2>/dev/null
  "${pb}" -c "Add :NSServicesStatus:'${key}':presentation_modes:ServicesMenu bool true" "${plist}" 2>/dev/null
  "${pb}" -c "Add :NSServicesStatus:'${key}':enabled_context_menu bool true" "${plist}" 2>/dev/null
  "${pb}" -c "Add :NSServicesStatus:'${key}':enabled_services_menu bool true" "${plist}" 2>/dev/null
  return 0
}

# Drop pbs entries from pre-1.2 versions, which keyed services by a
# com.macconvert.* bundle id (that keying also pushed them into the legacy
# "Services" submenu).
mc_services_clean_legacy_pbs() {
  /usr/bin/python3 - <<'PY' 2>/dev/null || true
import os, plistlib
p = os.path.expanduser("~/Library/Preferences/pbs.plist")
try:
    with open(p, "rb") as f:
        d = plistlib.load(f)
except Exception:
    raise SystemExit
s = d.get("NSServicesStatus", {})
stale = [k for k in s
         if k.startswith("com.macconvert.")
         or k.startswith("(null) - MacConvert - ")]
for k in stale:
    del s[k]
if stale:
    with open(p, "wb") as f:
        plistlib.dump(d, f)
PY
}

# Make macOS notice what changed: reload prefs, re-scan Services, poke Finder.
mc_services_refresh() {
  mc_services_clean_legacy_pbs
  killall cfprefsd 2>/dev/null || true
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
  sleep 1
  killall Finder 2>/dev/null || true
}

# Apply a target set of ids: render what's wanted, remove what isn't.
# Wanted bundles are always re-rendered (cheap) so they pick up manifest or
# script changes; the Services registry is refreshed only when the enabled
# set actually changed. Usage: mc_services_apply id1 id2 ...
mc_services_apply() {
  local -A want
  local id changed=0 was
  for id in "$@"; do want[${id}]=1; done

  for id in $(mc_action_ids); do
    if [[ -n "${want[${id}]:-}" ]]; then
      was=0; mc_service_installed "${id}" && was=1
      if mc_service_install "${id}"; then
        if (( was )); then
          mc_ok "$(mc_action_field "${id}" label)"
        else
          mc_ok "enabled  $(mc_action_field "${id}" label)"
          changed=1
        fi
      fi
    else
      if mc_service_installed "${id}"; then
        mc_service_remove "${id}" && { print -- "    ${MC_DIM}✗ disabled $(mc_action_field "${id}" label)${MC_RESET}"; changed=1; }
      fi
    fi
  done

  mc_services_prune
  mc_services_refresh
  return 0
}

# Remove bundles carrying our prefix whose label no longer exists in the
# manifest (leftovers from older versions after a rename).
mc_services_prune() {
  local wf label id known
  for wf in "${MC_SERVICES_DIR}/${MC_WORKFLOW_PREFIX}"*.workflow(N); do
    label="$(basename "${wf}" .workflow)"
    label="${label#${MC_WORKFLOW_PREFIX}}"
    known=0
    for id in $(mc_action_ids); do
      [[ "$(mc_action_field "${id}" label)" == "${label}" ]] && { known=1; break; }
    done
    (( known )) || { rm -rf "${wf}"; print -- "    ${MC_DIM}✗ removed stale ${label}${MC_RESET}"; }
  done
}

# Re-render every installed bundle (used after an update so bundles pick up
# new scripts/UTIs). Keeps the enabled set unchanged.
mc_services_rerender() {
  local id
  for id in $(mc_services_installed_ids); do
    mc_service_install "${id}" >/dev/null && mc_ok "refreshed $(mc_action_field "${id}" label)"
  done
  mc_services_refresh
}
