# Workroom

Claude Code skills for isolated working folders. A workroom is a `workroom-<name>` folder holding the repos for one task and a `WORKLOG.md` that records where you left off, so a later session can pick the work back up.

## Install

```
/plugin marketplace add freddyC/workroom
/plugin install workroom@workroom
```

## Skills

| Skill | Say something like | What it does |
| --- | --- | --- |
| `workroom-create` | "start a workroom for ABC-123" | Makes `workroom-<name>` in the current folder, clones the repos you name, starts `WORKLOG.md` |
| `workroom-open` | "resume the ABC-123 workroom" | Reads the work log and restores where you stopped |
| `workroom-close` | "pause this workroom" | Records stopping state in the work log, optionally commits WIP |
| `workroom-list` | "what workrooms do I have?" | Lists workrooms in the current folder and their status |
| `workroom-archive` | "the PR merged, archive it" | Saves the work log to the archive and removes the folder |

Each skill also runs as a slash command, e.g. `/workroom-create`. The scripts in `scripts/` do the file work and default to the current folder; pass `--base-dir` to use another.

## License

MIT. See [LICENSE](LICENSE).
