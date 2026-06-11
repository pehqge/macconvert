#!/bin/zsh
# Emails the selected file(s) to the user's Kindle address.
#
# Configuration comes from ~/.config/macconvert/config (kindle_email, smtp_*);
# the SMTP password comes from the macOS Keychain. Delivery uses the system
# curl's SMTP support — no extra dependencies. Credentials are passed to curl
# via stdin (--config -) so they never appear in `ps` output.

ACTION_NAME="send-to-kindle"
source "$(dirname "$0")/_common.sh"

CONFIG_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/macconvert/config"
KEYCHAIN_SERVICE="macconvert"
KEYCHAIN_ACCOUNT="smtp"
CURL="/usr/bin/curl"
BASE64="/usr/bin/base64"
# Amazon's Send to Kindle limit per document.
MAX_SIZE_MB=200

config_get() {
  local key="$1" line
  [[ -f "${CONFIG_FILE}" ]] || return 1
  while IFS= read -r line; do
    [[ "${line}" == "${key}="* ]] && { print -r -- "${line#*=}"; return 0; }
  done < "${CONFIG_FILE}"
  return 1
}

smtp_password() {
  /usr/bin/security find-generic-password \
    -s "${KEYCHAIN_SERVICE}" -a "${KEYCHAIN_ACCOUNT}" -w 2>/dev/null
}

# Build an RFC 2822 message with the file as a base64 attachment.
# build_message <input-file> <from> <to> <output-message-file>
build_message() {
  local input="$1" from="$2" to="$3" msg="$4"
  local filename; filename="$(basename "${input}")"
  # Header-safe filename: strip CR/LF and double quotes.
  local safe_name="${filename//[$'\r\n\"']/}"
  local boundary="macconvert-$(date +%s)-$$"

  {
    print -r -- "From: ${from}"
    print -r -- "To: ${to}"
    print -r -- "Subject: ${safe_name}"
    print -r -- "MIME-Version: 1.0"
    print -r -- "Content-Type: multipart/mixed; boundary=\"${boundary}\""
    print -r -- ""
    print -r -- "--${boundary}"
    print -r -- "Content-Type: text/plain; charset=utf-8"
    print -r -- ""
    print -r -- "Sent by MacConvert."
    print -r -- ""
    print -r -- "--${boundary}"
    print -r -- "Content-Type: application/octet-stream; name=\"${safe_name}\""
    print -r -- "Content-Transfer-Encoding: base64"
    print -r -- "Content-Disposition: attachment; filename=\"${safe_name}\""
    print -r -- ""
    # -b 76 wraps lines; SMTP forbids lines longer than 998 bytes.
    "${BASE64}" -b 76 -i "${input}"
    print -r -- ""
    print -r -- "--${boundary}--"
  } > "${msg}"
}

process_file() {
  local input="$1"
  local base; base="$(basename "${input}")"

  local kindle_addr from host port user
  kindle_addr="$(config_get kindle_email)" || { log "kindle_email not configured — run: macconvert kindle setup"; return 1; }
  from="$(config_get smtp_from)"           || { log "smtp_from not configured"; return 1; }
  host="$(config_get smtp_host)"           || { log "smtp_host not configured"; return 1; }
  port="$(config_get smtp_port)"; port="${port:-587}"
  user="$(config_get smtp_user)"; user="${user:-${from}}"

  local password; password="$(smtp_password)"
  if [[ -z "${password}" ]]; then
    log "SMTP password not found in Keychain — run: macconvert kindle setup"
    return 1
  fi

  local size_mb=$(( $(stat -f%z "${input}") / 1024 / 1024 ))
  if (( size_mb > MAX_SIZE_MB )); then
    log "${base} is ${size_mb} MB — Amazon rejects documents over ${MAX_SIZE_MB} MB"
    return 1
  fi

  local msg; msg="$(mktemp -t macconvert-kindle)"
  build_message "${input}" "${from}" "${kindle_addr}" "${msg}"

  # Port 465 is implicit TLS (smtps); everything else negotiates STARTTLS.
  local url
  if [[ "${port}" == "465" ]]; then
    url="smtps://${host}:${port}"
  else
    url="smtp://${host}:${port}"
  fi

  log "Sending ${base} (${size_mb} MB) from ${from} to ${kindle_addr} via ${host}:${port}"

  # Dry run for the test suite — validates config and message build, skips SMTP.
  if [[ "${MACCONVERT_DRY_RUN:-0}" == "1" ]]; then
    log "DRY RUN: message built at ${msg}, skipping SMTP send"
    rm -f "${msg}"
    LAST_OUTPUT_BASENAME="→ ${kindle_addr} (dry run)"
    return 0
  fi

  local rc=0
  # Credentials go through --config on stdin, never argv.
  if ! print -r -- "user = \"${user//\"/\\\"}:${password//\"/\\\"}\"" | "${CURL}" \
      --silent --show-error \
      --config - \
      --ssl-reqd \
      --url "${url}" \
      --mail-from "${from}" \
      --mail-rcpt "${kindle_addr}" \
      --upload-file "${msg}" \
      --max-time 300 \
      >>"${LOG_FILE}" 2>&1; then
    log "curl SMTP send failed"
    rc=1
  fi
  rm -f "${msg}"

  if [[ ${rc} -eq 0 ]]; then
    LAST_OUTPUT_BASENAME="→ ${kindle_addr}"
    log "OK: delivered to ${kindle_addr}"
  fi
  return ${rc}
}

run_batch "$@"
