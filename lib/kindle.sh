#!/bin/zsh
# kindle.sh — Send to Kindle configuration wizard.
#
# Settings live in the config file (addresses, relay host/port); the SMTP
# password lives in the macOS Keychain and is entered through `security`'s own
# prompt so it never appears in shell history or `ps` output.

readonly MC_KEYCHAIN_ACCOUNT="smtp"
readonly MC_CALIBRE_SMTP_CONFIG="${HOME}/Library/Preferences/calibre/smtp.py.json"

mc_kindle_password_set() {
  # -U updates in place; no -w value means `security` prompts for it silently.
  /usr/bin/security add-generic-password -U \
    -s "${MC_KEYCHAIN_SERVICE}" -a "${MC_KEYCHAIN_ACCOUNT}" \
    -l "${MC_APP_NAME} SMTP" -w
}

mc_kindle_password_exists() {
  /usr/bin/security find-generic-password \
    -s "${MC_KEYCHAIN_SERVICE}" -a "${MC_KEYCHAIN_ACCOUNT}" >/dev/null 2>&1
}

mc_kindle_password_delete() {
  /usr/bin/security delete-generic-password \
    -s "${MC_KEYCHAIN_SERVICE}" -a "${MC_KEYCHAIN_ACCOUNT}" >/dev/null 2>&1 || true
}

mc_kindle_configured() {
  [[ -n "$(mc_config_get kindle_email 2>/dev/null)" ]] \
    && [[ -n "$(mc_config_get smtp_host 2>/dev/null)" ]] \
    && mc_kindle_password_exists
}

# Import relay settings from an existing Calibre installation, if any.
# Calibre stores the relay password as plain hex of the UTF-8 bytes.
mc_kindle_import_calibre() {
  [[ -f "${MC_CALIBRE_SMTP_CONFIG}" ]] || return 1
  local py=/usr/bin/python3
  [[ -x "${py}" ]] || return 1

  local host port user from pw_hex
  host="$("${py}" -c "import json;print(json.load(open('${MC_CALIBRE_SMTP_CONFIG}')).get('relay_host') or '')" 2>/dev/null)"
  port="$("${py}" -c "import json;print(json.load(open('${MC_CALIBRE_SMTP_CONFIG}')).get('relay_port') or '')" 2>/dev/null)"
  user="$("${py}" -c "import json;print(json.load(open('${MC_CALIBRE_SMTP_CONFIG}')).get('relay_username') or '')" 2>/dev/null)"
  from="$("${py}" -c "import json;print(json.load(open('${MC_CALIBRE_SMTP_CONFIG}')).get('from_') or '')" 2>/dev/null)"
  pw_hex="$("${py}" -c "import json;print(json.load(open('${MC_CALIBRE_SMTP_CONFIG}')).get('relay_password') or '')" 2>/dev/null)"
  [[ -n "${host}" && -n "${from}" && -n "${pw_hex}" ]] || return 1

  mc_config_set smtp_host "${host}"
  mc_config_set smtp_port "${port:-587}"
  mc_config_set smtp_user "${user:-${from}}"
  mc_config_set smtp_from "${from}"
  # Move the password into the Keychain rather than keeping Calibre's
  # hex-on-disk scheme.
  local pw; pw="$(print -- "${pw_hex}" | /usr/bin/xxd -r -p 2>/dev/null)"
  [[ -n "${pw}" ]] || return 1
  /usr/bin/security add-generic-password -U \
    -s "${MC_KEYCHAIN_SERVICE}" -a "${MC_KEYCHAIN_ACCOUNT}" \
    -l "${MC_APP_NAME} SMTP" -w "${pw}"
}

mc_kindle_show_amazon_steps() {
  local sender="$1"
  print
  print -- "  ${MC_BOLD}One step left — authorize your sender address on Amazon:${MC_RESET}"
  print
  print -- "  1. Open ${MC_CYAN}https://www.amazon.com/sendtokindle/email${MC_RESET}"
  print -- "     (or: amazon.com → Account → Manage Your Content & Devices →"
  print -- "      Preferences → Personal Document Settings)"
  print -- "  2. Under ${MC_BOLD}Approved Personal Document E-mail List${MC_RESET},"
  print -- "     click ${MC_BOLD}Add a new approved e-mail address${MC_RESET} and add:"
  print
  print -- "         ${MC_GREEN}${sender}${MC_RESET}"
  print
  print -- "  ${MC_DIM}Amazon requires the complete address — domain-only entries no longer work.${MC_RESET}"
  print -- "  ${MC_DIM}Your Kindle address is listed on the same page under Send-to-Kindle E-Mail Settings.${MC_RESET}"
  print
}

# Interactive setup. Returns 1 if the user aborts.
mc_kindle_setup() {
  print
  mc_info "Send to Kindle setup"
  print -- "    Files are emailed to your Kindle address through an SMTP account"
  print -- "    you control. The password is stored in the macOS Keychain."
  print

  # 1. Kindle destination address ------------------------------------------
  local kindle_email
  while true; do
    read -r "kindle_email?    Your Kindle address (name@kindle.com): "
    [[ "${kindle_email}" == *@kindle.com ]] && break
    mc_warn "that doesn't look like an @kindle.com address"
  done
  mc_config_set kindle_email "${kindle_email}"

  # 2. Sender / SMTP relay ----------------------------------------------------
  if [[ -f "${MC_CALIBRE_SMTP_CONFIG}" ]] \
     && mc_confirm "    Found an existing Calibre email setup. Import it?" y; then
    if mc_kindle_import_calibre; then
      mc_ok "imported relay settings from Calibre (password moved to Keychain)"
    else
      mc_warn "Calibre import failed — configuring manually instead"
      mc_kindle_setup_smtp || return 1
    fi
  else
    mc_kindle_setup_smtp || return 1
  fi

  mc_kindle_show_amazon_steps "$(mc_config_get smtp_from)"

  # 3. Optional test ----------------------------------------------------------
  if mc_confirm "    Send a test document to ${kindle_email} now?" n; then
    mc_kindle_test
  fi
  return 0
}

mc_kindle_setup_smtp() {
  print
  print -- "    Which email provider will send the files?"
  print
  print -- "      1) Gmail      ${MC_DIM}smtp.gmail.com — needs an App Password (2FA required)${MC_RESET}"
  print -- "      2) iCloud     ${MC_DIM}smtp.mail.me.com — needs an app-specific password${MC_RESET}"
  print -- "      3) Outlook    ${MC_DIM}smtp-mail.outlook.com${MC_RESET}"
  print -- "      4) Other      ${MC_DIM}any SMTP relay${MC_RESET}"
  print
  local choice host port
  while true; do
    read -r "choice?    Choice [1-4]: "
    case "${choice}" in
      1) host="smtp.gmail.com"; port=587
         print -- "    ${MC_DIM}Create an App Password: https://myaccount.google.com/apppasswords${MC_RESET}"
         break ;;
      2) host="smtp.mail.me.com"; port=587
         print -- "    ${MC_DIM}Create an app-specific password: https://account.apple.com → Sign-In and Security${MC_RESET}"
         break ;;
      3) host="smtp-mail.outlook.com"; port=587; break ;;
      4) read -r "host?    SMTP host: "
         read -r "port?    SMTP port [587]: "
         port="${port:-587}"
         break ;;
    esac
  done

  local from user
  read -r "from?    Sender email address: "
  [[ -n "${from}" ]] || return 1
  read -r "user?    SMTP username [${from}]: "
  user="${user:-${from}}"

  mc_config_set smtp_host "${host}"
  mc_config_set smtp_port "${port}"
  mc_config_set smtp_from "${from}"
  mc_config_set smtp_user "${user}"

  print -- "    SMTP password (stored in your Keychain, prompted by macOS):"
  mc_kindle_password_set || { mc_error "could not store password in Keychain"; return 1; }
  mc_ok "password stored in Keychain"
  return 0
}

# Sends a small test document through the real pipeline.
mc_kindle_test() {
  local tmp; tmp="$(mktemp -t macconvert-kindle-test).txt"
  print -- "This is a test document sent by ${MC_APP_NAME}. Your Send to Kindle setup works." > "${tmp}"
  mc_info "Sending test document…"
  if /bin/zsh "${MC_SCRIPTS_DIR}/send-to-kindle.sh" "${tmp}"; then
    mc_ok "sent — it should appear in your Kindle library in a few minutes"
  else
    mc_error "test send failed — see ${MC_LOG_DIR}/send-to-kindle.log"
    mc_warn "most common cause: the sender address is not on Amazon's approved list yet"
  fi
  rm -f "${tmp}"
}

# Settings summary + edit menu for `macconvert kindle`.
mc_kindle_status() {
  print
  if mc_kindle_configured; then
    print -- "    Kindle address : $(mc_config_get kindle_email)"
    print -- "    Sender         : $(mc_config_get smtp_from)"
    print -- "    SMTP relay     : $(mc_config_get smtp_host):$(mc_config_get smtp_port)"
    print -- "    Password       : ${MC_GREEN}in Keychain${MC_RESET}"
  else
    print -- "    Send to Kindle is ${MC_YELLOW}not configured${MC_RESET}. Run: ${MC_BOLD}${MC_CLI_NAME} kindle setup${MC_RESET}"
  fi
  print
}
