#!/usr/bin/env bash
# Simple todo CLI backed by todo.md (markdown checkboxes)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODO_FILE="${TODO_FILE:-$SCRIPT_DIR/todo.md}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  add <task text>       Add a new task
  done <n>              Mark task number <n> as done
  edit <n> <new text>   Change the text of task number <n>
  move <n> <pos>        Move task <n> to position <pos> (also: 'up'/'down')
  list                  List open tasks with their numbers
  list --all            List all tasks, including done ones
EOF
}

ensure_file() {
  [[ -f "$TODO_FILE" ]] || touch "$TODO_FILE"
}

cmd_add() {
  local text="$*"
  if [[ -z "$text" ]]; then
    echo "Error: task text required" >&2
    exit 1
  fi
  ensure_file
  echo "- [ ] $text" >> "$TODO_FILE"
  echo "Added: $text"
}

cmd_list() {
  local show_all=0
  if [[ "${1:-}" == "--all" || "${1:-}" == "-a" ]]; then
    show_all=1
  fi
  ensure_file
  if [[ ! -s "$TODO_FILE" ]]; then
    echo "No tasks yet."
    return
  fi
  local nums=() marks=() texts=()
  local n=0
  while IFS= read -r line; do
    n=$((n + 1))
    if [[ "$line" == "- [x] "* ]]; then
      if (( show_all )); then
        nums+=("$n"); marks+=("✓"); texts+=("${line#"- [x] "}")
      fi
    elif [[ "$line" == "- [ ] "* ]]; then
      nums+=("$n"); marks+=(" "); texts+=("${line#"- [ ] "}")
    fi
  done < "$TODO_FILE"

  if (( ${#nums[@]} == 0 )); then
    if (( show_all )); then
      echo "No tasks yet."
    else
      echo "No open tasks."
    fi
    return
  fi

  local last_num="${nums[@]: -1}"
  local num_w=${#last_num}
  (( num_w < 1 )) && num_w=1
  local text_w=4
  local i
  for i in "${!texts[@]}"; do
    (( ${#texts[$i]} > text_w )) && text_w=${#texts[$i]}
  done

  local bold="" green="" reset=""
  if [[ -t 1 ]]; then
    bold=$'\033[1m'; green=$'\033[32m'; reset=$'\033[0m'
  fi

  local num_dashes text_dashes
  num_dashes="$(printf '%*s' "$((num_w + 2))" '' | tr ' ' '─')"
  text_dashes="$(printf '%*s' "$((text_w + 2))" '' | tr ' ' '─')"

  print_rule() {
    local l="$1" m="$2" r="$3"
    printf '%s%s%s%s%s%s%s\n' "$l" "$num_dashes" "$m" "───" "$m" "$text_dashes" "$r"
  }

  print_rule "┌" "┬" "┐"
  printf '│ %s%-*s%s │ %s │ %s%-*s%s │\n' "$bold" "$num_w" "#" "$reset" " " "$bold" "$text_w" "Task" "$reset"
  print_rule "├" "┼" "┤"
  for i in "${!nums[@]}"; do
    local mark="${marks[$i]}"
    [[ "$mark" == "✓" ]] && mark="${green}✓${reset}"
    printf '│ %-*s │ %s │ %-*s │\n' "$num_w" "${nums[$i]}" "$mark" "$text_w" "${texts[$i]}"
  done
  print_rule "└" "┴" "┘"
}

cmd_done() {
  local n="${1:-}"
  if [[ -z "$n" || ! "$n" =~ ^[0-9]+$ ]]; then
    echo "Error: task number required" >&2
    exit 1
  fi
  ensure_file
  local total
  total=$(wc -l < "$TODO_FILE" | tr -d ' ')
  if (( n < 1 || n > total )); then
    echo "Error: no task number $n" >&2
    exit 1
  fi
  local line
  line=$(sed -n "${n}p" "$TODO_FILE")
  if [[ "$line" != "- [ ] "* ]]; then
    echo "Task $n is already done (or invalid)."
    return
  fi
  local tmp
  tmp="$(mktemp "${TODO_FILE}.XXXXXX")"
  awk -v n="$n" 'NR==n { sub(/^- \[ \] /, "- [x] ") } { print }' "$TODO_FILE" > "$tmp"
  mv "$tmp" "$TODO_FILE"
  echo "Done: ${line#"- [ ] "}"
}

cmd_edit() {
  local n="${1:-}"
  if [[ -z "$n" || ! "$n" =~ ^[0-9]+$ ]]; then
    echo "Error: task number required" >&2
    exit 1
  fi
  shift || true
  local text="$*"
  if [[ -z "$text" ]]; then
    echo "Error: new task text required" >&2
    exit 1
  fi
  ensure_file
  local total
  total=$(wc -l < "$TODO_FILE" | tr -d ' ')
  if (( n < 1 || n > total )); then
    echo "Error: no task number $n" >&2
    exit 1
  fi
  local line status
  line=$(sed -n "${n}p" "$TODO_FILE")
  if [[ "$line" == "- [x] "* ]]; then
    status="x"
  elif [[ "$line" == "- [ ] "* ]]; then
    status=" "
  else
    echo "Error: task $n not found" >&2
    exit 1
  fi
  local tmp
  tmp="$(mktemp "${TODO_FILE}.XXXXXX")"
  awk -v n="$n" -v newline="- [$status] $text" 'NR==n { print newline; next } { print }' "$TODO_FILE" > "$tmp"
  mv "$tmp" "$TODO_FILE"
  echo "Edited task $n: $text"
}

cmd_move() {
  local n="${1:-}" dest="${2:-}"
  if [[ -z "$n" || ! "$n" =~ ^[0-9]+$ ]]; then
    echo "Error: task number required" >&2
    exit 1
  fi
  if [[ -z "$dest" ]]; then
    echo "Error: destination position (or 'up'/'down') required" >&2
    exit 1
  fi
  ensure_file
  local total
  total=$(wc -l < "$TODO_FILE" | tr -d ' ')
  if (( n < 1 || n > total )); then
    echo "Error: no task number $n" >&2
    exit 1
  fi

  local pos
  case "$dest" in
    up) pos=$((n - 1)) ;;
    down) pos=$((n + 1)) ;;
    *)
      if [[ ! "$dest" =~ ^[0-9]+$ ]]; then
        echo "Error: destination must be a number, 'up', or 'down'" >&2
        exit 1
      fi
      pos="$dest"
      ;;
  esac
  (( pos < 1 )) && pos=1
  (( pos > total )) && pos=$total

  if (( pos == n )); then
    echo "Task $n is already at position $pos."
    return
  fi

  local lines=()
  while IFS= read -r l; do lines+=("$l"); done < "$TODO_FILE"

  local moved="${lines[$((n - 1))]}"
  local rest=("${lines[@]:0:$((n - 1))}" "${lines[@]:$n}")

  local tmp
  tmp="$(mktemp "${TODO_FILE}.XXXXXX")"
  {
    if (( pos > 1 )); then
      printf '%s\n' "${rest[@]:0:$((pos - 1))}"
    fi
    printf '%s\n' "$moved"
    if (( pos - 1 < ${#rest[@]} )); then
      printf '%s\n' "${rest[@]:$((pos - 1))}"
    fi
  } > "$tmp"
  mv "$tmp" "$TODO_FILE"

  local text="${moved#"- [ ] "}"
  text="${text#"- [x] "}"
  echo "Moved task $n to position $pos: $text"
}

main() {
  local cmd="${1:-}"
  [[ $# -gt 0 ]] && shift || true

  case "$cmd" in
    add) cmd_add "$@" ;;
    done) cmd_done "$@" ;;
    edit) cmd_edit "$@" ;;
    move) cmd_move "$@" ;;
    list|"") cmd_list "$@" ;;
    -h|--help|help) usage ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
