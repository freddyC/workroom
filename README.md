# Workroom

Claude Code skills for isolated working folders. A workroom is a `workroom-<name>` folder holding the repos for one task and a `WORKLOG.md` that records where you left off, so a later session can pick the work back up.

## Requirements

- Python 3.8 or later (standard library only) and `git`, on macOS, Linux or Windows. On Windows the skills fall back to `python` or `py` when there is no `python3`.

## Install

```
/plugin marketplace add freddyC/workroom
/plugin install workroom@workroom
```

## Skills

| Skill | Say something like | What it does |
| --- | --- | --- |
| `workroom-create` | "start a workroom for ABC-123" | Makes `workroom-<name>` in the current folder, clones the repos you name, writes `WORKLOG.md` and `CLAUDE.md` |
| `workroom-open` | "resume the ABC-123 workroom" | Reads the work log and restores where you stopped |
| `workroom-close` | "pause this workroom" | Records stopping state in the work log, optionally commits or stashes WIP |
| `workroom-list` | "what workrooms do I have?" | Lists workrooms in the current folder and their status |
| `workroom-archive` | "the PR merged, archive it" | Saves the work log to `workroom-archive/`, adds a line to `ACCOMPLISHMENTS.md`, removes the folder |
| `workroom-check` | "check my workrooms", "add a Decisions section to the work log" | Compares workrooms' files with the templates, adds missing sections, helps you change the templates |

Each skill also runs as a slash command, e.g. `/workroom-create`. `scripts/workroom.py` does the file work (`create`, `open`, `close`, `list`, `archive`, `check`) and defaults to the current folder; pass `--base-dir` to use another.

## Customizing the files

Every file a workroom writes comes from a template in [`templates/`](templates):

| Template | Becomes |
| --- | --- |
| `WORKLOG.md` | a new workroom's work log |
| `CLAUDE.md` | a new workroom's instructions for Claude |
| `worklog-entry.md` | each progress entry Claude appends |
| `worklog-paused.md` | the entry `workroom-close` appends |
| `ACCOMPLISHMENTS.md` | the archive index's header |
| `accomplishment.md` | each archived workroom's line in that index |

To change one, ask Claude to "customize the workroom templates", or run `python3 scripts/workroom.py check --init-templates`. Either copies the templates to `~/.claude/workroom/templates/` (or `$WORKROOM_TEMPLATES`), where your edits win over the defaults and survive plugin updates. A `{{placeholder}}` nothing fills, such as one in a section you add, renders as `None`.

Keep the `## Task`, `## Issue`, `## Repositories` and `## Work Log` headings, and each entry's `### YYYY-MM-DD HH:MM — …` heading and `**Status:**` line: open, list and archive read them. `workroom-check` warns when a template drops one, and with `--fix` adds a template's new sections to existing workrooms.

## License

MIT. See [LICENSE](LICENSE).
