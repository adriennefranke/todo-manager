# todo-manager

A tiny, dependency-free todo CLI backed by a plain `todo.md` file.

## Usage

```
todo add "Buy milk"          # add a task
todo list                    # show open (not-done) tasks, numbered
todo list --all              # show all tasks, including done ones
todo done 1                  # mark task 1 as done
todo edit 1 "Buy oat milk"   # change task 1's text
todo move 1 3                # move task 1 to position 3
todo move 3 up               # nudge task 3 up one spot
todo move 3 down             # nudge task 3 down one spot
```

`todo list` renders a table:

```
┌───┬───┬───────────────┐
│ # │   │ Task          │
├───┼───┼───────────────┤
│ 1 │   │ Buy milk      │
│ 2 │ ✓ │ Walk the dog  │
└───┴───┴───────────────┘
```

Tasks are stored in `todo.md` as markdown checkboxes (`- [ ]` / `- [x]`), so the
file is also readable and editable by hand.

## Setup

```sh
git clone https://github.com/<you>/todo-manager.git
ln -sf "$(pwd)/todo-manager/todo.sh" ~/.local/bin/todo
```

Make sure `~/.local/bin` is on your `PATH`. `todo.md` is created automatically
next to `todo.sh` on first use; set `TODO_FILE` to point it elsewhere.

## Requirements

Bash and the standard POSIX utilities (`awk`, `sed`, `mktemp`) — nothing else
to install. Tested on both macOS (bash 3.2+) and Linux.

## License

[MIT](LICENSE)
