#!/usr/bin/env python3
"""Workroom: isolated working folders for Claude Code tasks.

Usage: workroom.py <create|open|close|list|archive|check> [options]

Every command prints JSON for the model to read. Standard library only, so it
runs anywhere Python 3.8+ does (macOS, Linux, Windows). Templates come from
templates/ beside this folder; a file of the same name in $WORKROOM_TEMPLATES
(default ~/.claude/workroom/templates) overrides it.
"""

import argparse
import datetime
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from pathlib import Path

PLUGIN_TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "templates"
USER_TEMPLATES_DIR = Path(os.environ.get("WORKROOM_TEMPLATES") or Path.home() / ".claude" / "workroom" / "templates")
TEMPLATE_NAMES = ["WORKLOG.md", "CLAUDE.md", "worklog-entry.md", "worklog-paused.md", "ACCOMPLISHMENTS.md", "accomplishment.md"]
WORKLOG_REQUIRED_HEADINGS = ["## Task", "## Issue", "## Repositories", "## Work Log"]
ARCHIVE_DIR_NAME = "workroom-archive"


class WorkroomError(Exception):
    pass


def now(fmt="%Y-%m-%d %H:%M"):
    return datetime.datetime.now().strftime(fmt)


def emit(data):
    print(json.dumps(data, indent=2, ensure_ascii=False))


def read_text(path):
    return Path(path).read_text(encoding="utf-8")


def write_text(path, text, append=False):
    with open(path, "a" if append else "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def template_path(name):
    override = USER_TEMPLATES_DIR / name
    return override if override.is_file() else PLUGIN_TEMPLATES_DIR / name


def render(name, **values):
    text = read_text(template_path(name))
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", str(value))
    text = re.sub(r"\{\{[A-Za-z0-9_]+\}\}", "None", text)
    return text if text.endswith("\n") else text + "\n"


def headings(path):
    return [line for line in read_text(path).splitlines() if line.startswith("## ")]


def section(log_text, name):
    lines, found = [], False
    for line in log_text.splitlines():
        if found and line.startswith("## "):
            break
        if found:
            lines.append(line)
        elif line.startswith("## " + name):
            found = True
    return lines


def nonblank(lines):
    return [line for line in lines if line.strip()]


def last_status(log_text):
    statuses = [line[len("**Status:**"):].strip() for line in log_text.splitlines() if line.startswith("**Status:**")]
    return statuses[-1] if statuses else ""


def last_entry_date(log_text):
    dates = [line[4:] for line in log_text.splitlines() if re.match(r"^### \d{4}-\d{2}-\d{2}", line)]
    return " ".join(dates[-1].split()[:2]) if dates else ""


def workroom_dirs(base_dir):
    if not base_dir.is_dir():
        return []
    return sorted(
        path for path in base_dir.iterdir()
        if path.is_dir() and path.name.startswith("workroom-") and path.name != ARCHIVE_DIR_NAME
    )


def current_workroom():
    """The workroom holding the current folder (it or any parent), or None."""
    cwd = Path.cwd().resolve()
    for path in (cwd, *cwd.parents):
        if path.name.startswith("workroom-") and path.name != ARCHIVE_DIR_NAME:
            return path
    return None


def default_base_dir():
    current = current_workroom()
    return str(current.parent if current else Path.cwd())


def resolve_workroom(base_dir, name):
    if not name:
        current = current_workroom()
        if current and current.parent == base_dir.resolve():
            name = current.name
        else:
            raise WorkroomError("No workroom specified and cwd is not inside a workroom. Pass --workroom NAME.")
    workroom_dir = base_dir / name
    if not workroom_dir.is_dir():
        raise WorkroomError(f"Workroom not found: {workroom_dir}")
    return name, workroom_dir


def git(repo_dir, *args):
    result = subprocess.run(
        ["git", "-C", str(repo_dir), *args],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    return result.returncode, result.stdout.strip()


def repos_in(workroom_dir):
    return sorted(path for path in workroom_dir.iterdir() if (path / ".git").is_dir())


def count_lines(text):
    return len([line for line in text.splitlines() if line.strip()])


def slugify(text, words=4):
    parts = [part for part in re.split(r"[^a-z0-9]+", text.lower()) if part]
    return "-".join(parts[:words])


def remove_tree(path):
    """Deletes a folder, including git's read-only object files on Windows."""

    def make_writable(func, target, _error):
        os.chmod(target, stat.S_IWRITE)
        func(target)

    if sys.version_info >= (3, 12):
        shutil.rmtree(path, onexc=make_writable)
    else:
        shutil.rmtree(path, onerror=make_writable)


def cmd_create(args):
    description = " ".join(args.description).strip()
    if not description:
        raise WorkroomError("No description provided. Pass description words as positional arguments.")
    slug = slugify(description)
    base_slug = f"{args.ticket}-{slug}" if args.ticket else slug

    base_dir = Path(args.base_dir)
    base_dir.mkdir(parents=True, exist_ok=True)
    name = f"workroom-{base_slug}"
    suffix = 2
    while (base_dir / name).exists():
        name = f"workroom-{base_slug}-{suffix}"
        suffix += 1
    workroom_dir = base_dir / name
    workroom_dir.mkdir(parents=True)

    cloned, branches = [], []
    for url in args.repo:
        repo_name = re.sub(r"\.git$", "", url.rstrip("/").split("/")[-1])
        repo_dir = workroom_dir / repo_name
        if subprocess.run(["git", "clone", url, str(repo_dir)], capture_output=True).returncode != 0:
            cloned.append({"repo": url, "status": "clone_failed", "path": None, "branch": None})
            continue
        code, head = git(repo_dir, "symbolic-ref", "refs/remotes/origin/HEAD")
        default_branch = head.replace("refs/remotes/origin/", "") if code == 0 and head else "main"
        branch = f"{args.ticket}-{slug}" if args.ticket else slug
        if git(repo_dir, "checkout", "-b", branch, f"origin/{default_branch}")[0] != 0:
            git(repo_dir, "checkout", "-b", branch)
        cloned.append({"repo": url, "status": "ok", "path": str(repo_dir), "branch": branch, "default_branch": default_branch})
        branches.append(f"{repo_name}={branch}")

    timestamp = now()
    write_text(workroom_dir / "WORKLOG.md", render(
        "WORKLOG.md",
        created_at=timestamp, workroom_name=name, task=description,
        repositories="\n".join(args.repo) or "None", issue=args.ticket or "None",
        branch=", ".join(branches) or "N/A",
    ))
    write_text(workroom_dir / "CLAUDE.md", render("CLAUDE.md", workroom_name=name, workroom_dir=workroom_dir))

    emit({
        "workroom_name": name,
        "workroom_dir": str(workroom_dir),
        "base_dir": str(base_dir),
        "slug": slug,
        "ticket": args.ticket or None,
        "description": description,
        "created_at": timestamp,
        "worklog": str(workroom_dir / "WORKLOG.md"),
        "claude_md": str(workroom_dir / "CLAUDE.md"),
        "entry_template": str(template_path("worklog-entry.md")),
        "repos": cloned,
    })


def infer_phase(status):
    status = status.lower()
    for words, phase in [
        (("plan", "design", "ready"), "Planning"),
        (("implement", "progress"), "Implementation"),
        (("test",), "Testing"),
        (("review", "pr", "done"), "Review"),
        (("block",), "Blocked"),
        (("pause",), "Paused"),
    ]:
        if any(word in status for word in words):
            return phase
    return "Unknown"


def cmd_open(args):
    search = " ".join(args.search).strip()
    if not search:
        raise WorkroomError("No search term provided.")
    base_dir = Path(args.base_dir)
    if not base_dir.is_dir():
        raise WorkroomError(f"Base directory not found: {base_dir}")

    needle = search.lower()
    candidates = workroom_dirs(base_dir)
    matches = [path for path in candidates if needle in path.name.lower()]
    if not matches:
        matches = [
            path for path in candidates
            if (path / "WORKLOG.md").is_file() and needle in read_text(path / "WORKLOG.md").lower()
        ]
    if not matches:
        return emit({"error": f"No workroom found matching: {search}", "search": search, "base_dir": str(base_dir)})
    if len(matches) > 1:
        return emit({"ambiguous": True, "search": search, "matches": [str(path) for path in matches]})

    workroom_dir = matches[0]
    log = workroom_dir / "WORKLOG.md"
    if not log.is_file():
        return emit({"error": "Workroom found but WORKLOG.md is missing", "workroom_dir": str(workroom_dir)})
    text = read_text(log)

    blocks, current = [], []
    for line in section(text, "Work Log"):
        if line.startswith("### "):
            if current:
                blocks.append(current)
            current = []
        current.append(line)
    if current:
        blocks.append(current)
    status = last_status(text)

    emit({
        "workroom_name": workroom_dir.name,
        "workroom_dir": str(workroom_dir),
        "resumed_at": now(),
        "context": {
            "task": "\n".join(section(text, "Task")).strip(),
            "repositories": "\n".join(section(text, "Repositories")).strip(),
            "issue": "\n".join(section(text, "Issue")).strip(),
            "design": "\n".join(section(text, "Design")).strip(),
        },
        "last_entry": {
            "date": last_entry_date(text),
            "status": status,
            "content": "\n".join(nonblank(blocks[-1])) if blocks else "",
        },
        "inferred_phase": infer_phase(status),
    })


def cmd_close(args):
    base_dir = Path(args.base_dir)
    name, workroom_dir = resolve_workroom(base_dir, args.workroom)
    timestamp = now()
    statuses = []

    for repo_dir in repos_in(workroom_dir):
        dirty = git(repo_dir, "status", "--short")[1]
        unpushed = count_lines(git(repo_dir, "log", "@{u}..", "--oneline")[1])
        stashes = count_lines(git(repo_dir, "stash", "list")[1])
        code, branch = git(repo_dir, "rev-parse", "--abbrev-ref", "HEAD")
        has_changes = bool(dirty)
        action = "none"
        if has_changes and args.commit:
            git(repo_dir, "add", "-A")
            git(repo_dir, "commit", "-m", f"WIP: {args.summary or f'pausing workroom {name}'}")
            action, dirty = "committed", ""
        elif has_changes and args.stash:
            git(repo_dir, "stash", "push", "-m", f"workroom-close: {timestamp}")
            action, dirty = "stashed", ""
            stashes = count_lines(git(repo_dir, "stash", "list")[1])
        statuses.append({
            "repo": repo_dir.name,
            "branch": branch if code == 0 else "unknown",
            "has_changes": has_changes,
            "uncommitted": dirty,
            "unpushed_commits": unpushed,
            "stash_count": stashes,
            "action_taken": action,
        })

    needs_decision = any(status["has_changes"] and status["action_taken"] == "none" for status in statuses)
    log = workroom_dir / "WORKLOG.md"
    log_updated = False
    if not needs_decision and log.is_file():
        write_text(log, render(
            "worklog-paused.md", timestamp=timestamp,
            summary=args.summary or "<fill in what you were working on>",
        ), append=True)
        log_updated = True

    emit({
        "workroom_name": name,
        "workroom_dir": str(workroom_dir),
        "closed_at": timestamp,
        "log_updated": log_updated,
        "needs_decision": needs_decision,
        "repos": statuses,
    })


def cmd_list(args):
    base_dir = Path(args.base_dir)
    active = []
    for workroom_dir in workroom_dirs(base_dir):
        log = workroom_dir / "WORKLOG.md"
        if not log.is_file():
            active.append({"name": workroom_dir.name, "kind": "active", "task": None, "status": "no log", "last_updated": None, "path": str(workroom_dir)})
            continue
        text = read_text(log)
        active.append({
            "name": workroom_dir.name,
            "kind": "active",
            "task": " ".join(" ".join(nonblank(section(text, "Task"))[:5]).split()),
            "status": last_status(text) or "unknown",
            "last_updated": last_entry_date(text),
            "path": str(workroom_dir),
        })

    archived = []
    accomplishments = base_dir / ARCHIVE_DIR_NAME / "ACCOMPLISHMENTS.md"
    if args.show_archived and accomplishments.is_file():
        for line in read_text(accomplishments).splitlines():
            match = re.match(r"^## ([0-9-]+) — (.+)$", line)
            if match:
                archived.append({"name": "archived", "kind": "archived", "task": match.group(2), "status": "Archived", "last_updated": match.group(1), "path": None})

    current = current_workroom()
    emit({
        "base_dir": str(base_dir),
        "current": next((room for room in active if current and Path(room["path"]).resolve() == current), None),
        "count": len(active),
        "archive_count": len(archived),
        "workrooms": active + archived,
    })


def cmd_archive(args):
    base_dir = Path(args.base_dir)
    name, workroom_dir = resolve_workroom(base_dir, args.workroom)
    log = workroom_dir / "WORKLOG.md"
    archive_dir = base_dir / ARCHIVE_DIR_NAME
    today, timestamp = now("%Y-%m-%d"), now()

    text = read_text(log) if log.is_file() else ""
    task = " ".join(" ".join(nonblank(section(text, "Task"))[:3]).split())
    ticket_match = re.search(r"[A-Z]+-[0-9]+|#[0-9]+", " ".join(nonblank(section(text, "Issue"))[:3]))
    ticket = ticket_match.group(0) if ticket_match else "N/A"
    topic = re.sub(r"^workroom-", "", name)
    topic = re.sub("^" + re.escape(ticket) + "-", "", topic, flags=re.IGNORECASE).replace("-", "_")
    archive_log_name = f"WORKLOG-{today}-{topic}.md"

    checks, all_clean = [], True
    for repo_dir in repos_in(workroom_dir):
        code, branch = git(repo_dir, "rev-parse", "--abbrev-ref", "HEAD")
        dirty = git(repo_dir, "status", "--short")[1]
        unpushed = count_lines(git(repo_dir, "log", "@{u}..", "--oneline")[1])
        warnings = []
        if dirty:
            warnings.append("uncommitted changes")
        if unpushed:
            warnings.append(f"{unpushed} unpushed commits")
        all_clean = all_clean and not warnings
        checks.append({
            "repo": repo_dir.name,
            "branch": branch if code == 0 else "unknown",
            "remote": git(repo_dir, "remote", "get-url", "origin")[1],
            "clean": not warnings,
            "warnings": warnings,
        })

    if not args.confirm_delete:
        return emit({
            "phase": "checklist",
            "workroom_name": name,
            "workroom_dir": str(workroom_dir),
            "task": task,
            "ticket": ticket,
            "all_clean": all_clean,
            "archive_log_name": archive_log_name,
            "repos": checks,
        })

    archive_dir.mkdir(parents=True, exist_ok=True)
    log_moved = log.is_file()
    if log_moved:
        shutil.move(str(log), str(archive_dir / archive_log_name))

    accomplishments = archive_dir / "ACCOMPLISHMENTS.md"
    if not accomplishments.is_file():
        write_text(accomplishments, render("ACCOMPLISHMENTS.md"))
    outcome = args.outcome or task
    write_text(accomplishments, render(
        "accomplishment.md", date=today, outcome=outcome, ticket=ticket,
        pr=args.pr_url or "N/A", worklog=archive_log_name,
    ), append=True)

    remove_tree(workroom_dir)
    emit({
        "phase": "complete",
        "workroom_name": name,
        "archived_at": timestamp,
        "log_moved": log_moved,
        "archive_log": str(archive_dir / archive_log_name),
        "accomplishments_updated": True,
        "deleted": True,
    })


def insert_sections(path, missing):
    block = "".join(f"{heading}\n\nNone\n\n" for heading in missing)
    lines = read_text(path).splitlines(keepends=True)
    for index, line in enumerate(lines):
        if line.startswith("## Work Log"):
            lines.insert(index, block)
            return write_text(path, "".join(lines))
    write_text(path, "\n" + block, append=True)


def cmd_check(args):
    if args.init_templates:
        USER_TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
        copied, kept = [], []
        for name in TEMPLATE_NAMES:
            target = USER_TEMPLATES_DIR / name
            if target.is_file():
                kept.append(name)
            else:
                shutil.copyfile(PLUGIN_TEMPLATES_DIR / name, target)
                copied.append(name)
        return emit({"templates_dir": str(USER_TEMPLATES_DIR), "copied": copied, "kept": kept})

    base_dir = Path(args.base_dir)
    worklog_template = template_path("WORKLOG.md")
    template_problems = [
        f"WORKLOG.md template is missing {heading}"
        for heading in WORKLOG_REQUIRED_HEADINGS if heading not in headings(worklog_template)
    ]

    results = []
    for workroom_dir in workroom_dirs(base_dir):
        if args.workroom and args.workroom not in (workroom_dir.name, f"workroom-{args.workroom}"):
            continue
        files = []
        for file_name in ("WORKLOG.md", "CLAUDE.md"):
            path = workroom_dir / file_name
            status, missing, fixed = "ok", [], False
            if not path.is_file():
                status = "missing"
                if args.fix:
                    if file_name == "WORKLOG.md":
                        text = render("WORKLOG.md", created_at=now(), workroom_name=workroom_dir.name, branch="N/A")
                    else:
                        text = render("CLAUDE.md", workroom_name=workroom_dir.name, workroom_dir=workroom_dir)
                    write_text(path, text)
                    fixed = True
            else:
                expected = headings(template_path(file_name))
                if file_name == "WORKLOG.md":
                    expected += WORKLOG_REQUIRED_HEADINGS
                present = set(headings(path))
                missing = [heading for heading in dict.fromkeys(expected) if heading not in present]
                if missing:
                    status = "sections_missing"
                    if args.fix:
                        insert_sections(path, missing)
                        fixed = True
            files.append({"file": file_name, "status": status, "missing": missing, "fixed": fixed})
        results.append({"workroom": workroom_dir.name, "files": files})

    emit({
        "base_dir": str(base_dir),
        "override_dir": str(USER_TEMPLATES_DIR),
        "templates": [
            {"name": name, "source": "override" if (USER_TEMPLATES_DIR / name).is_file() else "default", "path": str(template_path(name))}
            for name in TEMPLATE_NAMES
        ],
        "template_problems": template_problems,
        "fix": args.fix,
        "workrooms": results,
    })


def parser():
    root = argparse.ArgumentParser(prog="workroom.py", description="Manage workroom folders.")
    commands = root.add_subparsers(dest="command", required=True)

    def command(name, handler):
        sub = commands.add_parser(name)
        sub.add_argument("--base-dir", default=default_base_dir())
        sub.set_defaults(handler=handler)
        return sub

    create = command("create", cmd_create)
    create.add_argument("--ticket", default="")
    create.add_argument("--repo", action="append", default=[])
    create.add_argument("description", nargs="*")

    command("open", cmd_open).add_argument("search", nargs="*")

    close = command("close", cmd_close)
    close.add_argument("--workroom", default="")
    close.add_argument("--commit", action="store_true")
    close.add_argument("--stash", action="store_true")
    close.add_argument("--summary", default="")

    command("list", cmd_list).add_argument("--show-archived", action="store_true")

    archive = command("archive", cmd_archive)
    archive.add_argument("--workroom", default="")
    archive.add_argument("--outcome", default="")
    archive.add_argument("--pr-url", default="")
    archive.add_argument("--confirm-delete", action="store_true")

    check = command("check", cmd_check)
    check.add_argument("--workroom", default="")
    check.add_argument("--fix", action="store_true")
    check.add_argument("--init-templates", action="store_true")
    return root


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parser().parse_args()
    try:
        args.handler(args)
    except WorkroomError as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
