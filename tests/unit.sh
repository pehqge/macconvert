#!/bin/zsh
# Fast checks — no installation, no Homebrew, no conversions. Runs in CI on a
# bare macOS runner and locally in under a second.
#
#   tests/unit.sh
#
# Covers: syntax of every shell file, manifest integrity, workflow bundle
# generation (validated with plutil), config round-trip, output-path
# collision handling, and the updater's version comparison.

set -u
set -o pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0

check() {  # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass + 1))
    print -- "  ✅ ${desc}"
  else
    fail=$((fail + 1))
    print -- "  ❌ ${desc}"
  fi
}

note_fail() { fail=$((fail + 1)); print -- "  ❌ $1"; }
note_pass() { pass=$((pass + 1)); print -- "  ✅ $1"; }

# --- 1. syntax ---------------------------------------------------------------
print -- "--- Syntax (zsh -n) ---"
for f in "${PROJECT_DIR}"/install.sh "${PROJECT_DIR}"/bin/macconvert \
         "${PROJECT_DIR}"/lib/*.sh "${PROJECT_DIR}"/scripts/*.sh \
         "${PROJECT_DIR}"/tests/*.sh; do
  check "$(basename "${f}")" zsh -n "${f}"
done

# --- 2. manifest integrity ---------------------------------------------------
print -- "--- Manifest ---"
(
  MC_ROOT="${PROJECT_DIR}"
  source "${PROJECT_DIR}/lib/core.sh"
  source "${PROJECT_DIR}/lib/manifest.sh"

  ids=($(mc_action_ids))
  [[ ${#ids[@]} -eq ${#MC_ACTIONS[@]} ]] || exit 1
  # unique ids
  [[ ${#ids[@]} -eq $(print -l -- "${ids[@]}" | sort -u | wc -l | tr -d ' ') ]] || exit 1
  for id in "${ids[@]}"; do
    cat="$(mc_action_field "${id}" category)"
    (( ${MC_CATEGORIES[(I)${cat}]} )) || { print -- "bad category for ${id}: ${cat}" >&2; exit 1; }
    script="${PROJECT_DIR}/scripts/$(mc_action_field "${id}" script)"
    [[ -x "${script}" ]] || { print -- "missing script for ${id}: ${script}" >&2; exit 1; }
    [[ -n "$(mc_action_field "${id}" label)" ]] || exit 1
    [[ -n "$(mc_action_field "${id}" utis)" ]] || exit 1
  done
) && note_pass "all actions: unique ids, valid categories, executable scripts" \
  || note_fail "manifest integrity"

# --- 3. dependency declarations map to known probes --------------------------
(
  MC_ROOT="${PROJECT_DIR}"
  source "${PROJECT_DIR}/lib/core.sh"
  source "${PROJECT_DIR}/lib/manifest.sh"
  source "${PROJECT_DIR}/lib/deps.sh"
  for dep in $(mc_deps_for $(mc_action_ids)); do
    if [[ "${dep}" == cask:* ]]; then
      [[ -n "${MC_CASK_PROBE[${dep#cask:}]:-}" ]] || { print -- "unknown cask: ${dep}" >&2; exit 1; }
    else
      [[ -n "${MC_DEP_PROBE[${dep}]:-}" ]] || { print -- "unknown formula: ${dep}" >&2; exit 1; }
    fi
  done
) && note_pass "every declared dependency has an install probe" \
  || note_fail "dependency declarations"

# --- 4. bundle generation ----------------------------------------------------
print -- "--- Workflow bundle generation ---"
(
  tmp="$(mktemp -d -t macconvert-unit)"
  trap "rm -rf '${tmp}'" EXIT
  MC_ROOT="${PROJECT_DIR}"
  source "${PROJECT_DIR}/lib/core.sh"
  source "${PROJECT_DIR}/lib/manifest.sh"
  source "${PROJECT_DIR}/lib/bundle.sh"
  for id in $(mc_action_ids); do
    label="$(mc_action_field "${id}" label)"
    mc_bundle_write "${MC_WORKFLOW_PREFIX}${label}" \
      "$(mc_action_field "${id}" utis)" \
      "/tmp/fake-script.sh" "${tmp}" "${label}" || exit 1
    /usr/bin/plutil -lint "${tmp}/${MC_WORKFLOW_PREFIX}${label}.workflow/Contents/Info.plist" >/dev/null || exit 1
    /usr/bin/plutil -lint "${tmp}/${MC_WORKFLOW_PREFIX}${label}.workflow/Contents/document.wflow" >/dev/null || exit 1
  done
) && note_pass "all 45 bundles render and pass plutil lint" \
  || note_fail "bundle generation"

# --- 5. config round-trip ----------------------------------------------------
print -- "--- Config ---"
(
  sandbox="$(mktemp -d -t macconvert-cfg)"
  trap "rm -rf '${sandbox}'" EXIT
  MC_ROOT="${PROJECT_DIR}"
  XDG_CONFIG_HOME="${sandbox}"
  source "${PROJECT_DIR}/lib/core.sh"
  source "${PROJECT_DIR}/lib/config.sh"
  mc_config_set alpha "one two" || exit 1
  mc_config_set beta "x=y=z" || exit 1
  [[ "$(mc_config_get alpha)" == "one two" ]] || exit 1
  [[ "$(mc_config_get beta)" == "x=y=z" ]] || exit 1
  mc_config_set alpha "updated" || exit 1
  [[ "$(mc_config_get alpha)" == "updated" ]] || exit 1
  [[ "$(wc -l < "${MC_CONFIG_FILE}" | tr -d ' ')" == "2" ]] || exit 1
  mc_config_unset alpha
  mc_config_get alpha && exit 1
  # secrets never in config: file mode is 600
  [[ "$(stat -f '%Lp' "${MC_CONFIG_FILE}")" == "600" ]] || exit 1
) && note_pass "set/get/update/unset round-trip, 600 perms, values with = and spaces" \
  || note_fail "config round-trip"

# --- 6. unique_output_path ---------------------------------------------------
print -- "--- Output collision handling ---"
(
  tmp="$(mktemp -d -t macconvert-out)"
  trap "rm -rf '${tmp}'" EXIT
  ACTION_NAME="unit-test"
  source "${PROJECT_DIR}/scripts/_common.sh"
  first="$(unique_output_path "${tmp}" "doc" "pdf")"
  [[ "${first}" == "${tmp}/doc.pdf" ]] || exit 1
  touch "${tmp}/doc.pdf"
  second="$(unique_output_path "${tmp}" "doc" "pdf")"
  [[ "${second}" == "${tmp}/doc (1).pdf" ]] || exit 1
  touch "${tmp}/doc (1).pdf"
  third="$(unique_output_path "${tmp}" "doc" "pdf")"
  [[ "${third}" == "${tmp}/doc (2).pdf" ]] || exit 1
) && note_pass "never overwrites: doc.pdf → doc (1).pdf → doc (2).pdf" \
  || note_fail "unique_output_path"

# --- 7. version comparison ---------------------------------------------------
print -- "--- Updater ---"
(
  MC_ROOT="${PROJECT_DIR}"
  source "${PROJECT_DIR}/lib/core.sh"
  source "${PROJECT_DIR}/lib/updater.sh"
  [[ "$(mc_update_compare 1.0.0 v1.0.1)" == "newer" ]] || exit 1
  [[ "$(mc_update_compare 1.0.0 v1.0.0)" == "current" ]] || exit 1
  [[ "$(mc_update_compare 1.2.0 v1.10.0)" == "newer" ]] || exit 1
  [[ "$(mc_update_compare 2.0.0 v1.9.9)" == "current" ]] || exit 1
) && note_pass "semver compare (incl. 1.2 < 1.10)" \
  || note_fail "version comparison"

print
print -- "==> ${pass} pass / ${fail} fail"
[[ ${fail} -eq 0 ]] || exit 1
