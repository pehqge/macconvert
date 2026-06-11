#!/bin/zsh
# tui.sh — small interactive terminal UI, pure zsh, no dependencies.
#
# Two widgets:
#   mc_tui_select  — checkbox multi-select grouped by category (the action picker)
#   mc_tui_choose  — single-choice vertical menu (the home screen)
#
# Both draw on the alternate screen buffer and restore the terminal on exit,
# including on Ctrl-C. Every flow has a non-interactive escape hatch
# (--all/--none flags and `macconvert enable/disable`) so scripts and CI never
# need a TTY.

# --- terminal plumbing ------------------------------------------------------

mc_tui_enter() {
  tput smcup 2>/dev/null   # alternate screen
  tput civis 2>/dev/null   # hide cursor
  trap 'mc_tui_leave; return 130' INT TERM
}

mc_tui_leave() {
  tput cnorm 2>/dev/null
  tput rmcup 2>/dev/null
  trap - INT TERM
}

# Read one keypress, decoding arrow-key escape sequences.
# Prints: up | down | space | enter | esc | <char>
mc_tui_key() {
  local k rest
  read -srk1 k || { print -- "esc"; return; }
  if [[ "${k}" == $'\e' ]]; then
    # Arrow keys arrive as ESC [ A/B; a lone ESC has nothing buffered.
    read -srk1 -t 0.01 rest || { print -- "esc"; return; }
    [[ "${rest}" == "[" ]] && read -srk1 -t 0.01 rest
    case "${rest}" in
      A) print -- "up" ;;
      B) print -- "down" ;;
      *) print -- "esc" ;;
    esac
  elif [[ "${k}" == " " ]]; then
    print -- "space"
  elif [[ "${k}" == $'\n' || "${k}" == $'\r' ]]; then
    print -- "enter"
  else
    print -- "${k}"
  fi
}

# --- multi-select -----------------------------------------------------------

# mc_tui_select <title> <preselected-ids-csv>
#
# Rows come from the manifest, grouped under category headers. Space on an
# item toggles it; space on a header toggles the whole category. Result is
# returned in the global array MC_TUI_RESULT; returns 1 when cancelled.
mc_tui_select() {
  local title="$1" preselected="$2"

  # rows: "header:<category>" or "item:<id>"
  local -a rows
  local cat id
  for cat in "${MC_CATEGORIES[@]}"; do
    rows+=("header:${cat}")
    for id in $(mc_actions_in_category "${cat}"); do
      rows+=("item:${id}")
    done
  done

  local -A sel
  for id in "${(@s:,:)preselected}"; do
    [[ -n "${id}" ]] && sel[${id}]=1
  done

  local cursor=1 total=${#rows[@]}

  _selected_count() {
    local n=0 r
    for r in "${rows[@]}"; do
      [[ "${r}" == item:* && -n "${sel[${r#item:}]:-}" ]] && n=$((n + 1))
    done
    print -- "${n}"
  }

  _cat_counts() {  # prints "<selected> <total>" for a category
    local c="$1" n=0 t=0 i
    for i in $(mc_actions_in_category "${c}"); do
      t=$((t + 1))
      [[ -n "${sel[${i}]:-}" ]] && n=$((n + 1))
    done
    print -- "${n} ${t}"
  }

  _toggle_row() {
    local row="${rows[${cursor}]}"
    if [[ "${row}" == item:* ]]; then
      local i="${row#item:}"
      if [[ -n "${sel[${i}]:-}" ]]; then unset "sel[${i}]"; else sel[${i}]=1; fi
    else
      # Header: select all in category unless all already selected, then clear.
      local c="${row#header:}" i all=1
      for i in $(mc_actions_in_category "${c}"); do
        [[ -z "${sel[${i}]:-}" ]] && all=0
      done
      for i in $(mc_actions_in_category "${c}"); do
        if [[ ${all} -eq 1 ]]; then unset "sel[${i}]"; else sel[${i}]=1; fi
      done
    fi
  }

  _draw() {
    local lines=${LINES:-$(tput lines)} cols=${COLUMNS:-$(tput cols)}
    local height=$((lines - 5))                  # rows visible in the viewport
    (( height < 5 )) && height=5
    local top=$((cursor - height / 2))
    (( top < 1 )) && top=1
    (( top > total - height + 1 )) && top=$((total - height + 1))
    (( top < 1 )) && top=1

    tput cup 0 0 2>/dev/null
    tput ed 2>/dev/null                           # clear to end of screen
    print -- "  ${MC_BOLD}${title}${MC_RESET}"
    print

    local idx row marker label pointer c
    local -a counts
    for (( idx = top; idx < top + height && idx <= total; idx++ )); do
      row="${rows[${idx}]}"
      pointer="  "
      (( idx == cursor )) && pointer="${MC_CYAN}❯ ${MC_RESET}"
      if [[ "${row}" == header:* ]]; then
        c="${row#header:}"
        counts=( $(_cat_counts "${c}") )
        print -- "${pointer}${MC_BOLD}${MC_BLUE}${c}${MC_RESET} ${MC_DIM}(${counts[1]}/${counts[2]})${MC_RESET}"
      else
        id="${row#item:}"
        label="$(mc_action_field "${id}" label)"
        if [[ -n "${sel[${id}]:-}" ]]; then
          marker="${MC_GREEN}●${MC_RESET}"
        else
          marker="${MC_DIM}○${MC_RESET}"
        fi
        print -- "${pointer}  ${marker} ${label}"
      fi
    done

    print
    # Keep the footer narrower than the terminal — a wrapped line would
    # scroll the whole alternate screen and shift the layout.
    print -n -- "  ${MC_DIM}↑↓ move · space toggle · a all · n none · ⏎ apply · q quit${MC_RESET} ${MC_BOLD}$(_selected_count)/${#MC_ACTIONS[@]}${MC_RESET}"
  }

  mc_tui_enter
  while true; do
    _draw
    case "$(mc_tui_key)" in
      up|k)   (( cursor > 1 )) && cursor=$((cursor - 1)) ;;
      down|j) (( cursor < total )) && cursor=$((cursor + 1)) ;;
      space)  _toggle_row ;;
      a)      for id in $(mc_action_ids); do sel[${id}]=1; done ;;
      n)      sel=() ;;
      enter)
        mc_tui_leave
        MC_TUI_RESULT=()
        for id in $(mc_action_ids); do
          [[ -n "${sel[${id}]:-}" ]] && MC_TUI_RESULT+=("${id}")
        done
        return 0
        ;;
      q|esc)
        mc_tui_leave
        return 1
        ;;
    esac
  done
}

# --- single choice ----------------------------------------------------------

# mc_tui_choose <title> <option>...
# Prints the 1-based index of the chosen option; returns 1 when cancelled.
mc_tui_choose() {
  local title="$1"; shift
  local -a options=("$@")
  local cursor=1 total=${#options[@]}

  _draw_choose() {
    tput cup 0 0 2>/dev/null
    tput ed 2>/dev/null
    print -- "  ${MC_BOLD}${title}${MC_RESET}"
    print
    local i
    for (( i = 1; i <= total; i++ )); do
      if (( i == cursor )); then
        print -- "  ${MC_CYAN}❯ ${options[${i}]}${MC_RESET}"
      else
        print -- "    ${options[${i}]}"
      fi
    done
    print
    print -- "  ${MC_DIM}↑/↓ move · enter select · q quit${MC_RESET}"
  }

  mc_tui_enter
  while true; do
    _draw_choose
    case "$(mc_tui_key)" in
      up|k)   (( cursor > 1 )) && cursor=$((cursor - 1)) ;;
      down|j) (( cursor < total )) && cursor=$((cursor + 1)) ;;
      enter)  mc_tui_leave; print -- "${cursor}"; return 0 ;;
      q|esc)  mc_tui_leave; return 1 ;;
    esac
  done
}
