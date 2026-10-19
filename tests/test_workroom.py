"""Tests for scripts/workroom.py. Standard library only: python -m unittest discover tests"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "workroom.py"
sys.path.insert(0, str(SCRIPT.parent))
from workroom import remove_tree  # noqa: E402

GIT_IDENTITY = ["-c", "user.name=test", "-c", "user.email=test@example.com"]


def git(repo, *args):
    subprocess.run(["git", *GIT_IDENTITY, "-C", str(repo), *args], check=True, capture_output=True)


class WorkroomTest(unittest.TestCase):
    def setUp(self):
        self.base = Path(tempfile.mkdtemp())

    def tearDown(self):
        remove_tree(self.base)  # handles git's read-only object files on Windows

    def run_script(self, *args):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), *args, "--base-dir", str(self.base)],
            capture_output=True, text=True, encoding="utf-8", cwd=self.base,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def create(self, *words):
        return self.run_script("create", *words)

    def pushed_repo(self, room):
        """A repo in the workroom whose only commit is on its remote."""
        remote = self.base / "remote.git"
        subprocess.run(["git", "init", "-q", "--bare", str(remote)], check=True)
        repo = Path(room["workroom_dir"]) / "repo"
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        git(repo, "commit", "-q", "--allow-empty", "-m", "first")
        git(repo, "remote", "add", "origin", str(remote))
        git(repo, "push", "-q", "-u", "origin", "HEAD")
        return repo

    def checklist(self, room):
        return self.run_script("archive", "--workroom", room["workroom_name"])

    def test_open_prefers_an_exact_name(self):
        first = self.create("fix", "auth")
        self.create("fix", "auth")
        opened = self.run_script("open", first["workroom_name"])
        self.assertEqual(opened.get("workroom_name"), first["workroom_name"])
        self.assertTrue(self.run_script("open", "fix-auth")["workroom_name"].endswith("fix-auth"))
        self.assertTrue(self.run_script("open", "auth").get("ambiguous"))

    def test_archive_is_clean_when_everything_is_on_the_remote(self):
        room = self.create("clean", "room")
        self.pushed_repo(room)
        checklist = self.checklist(room)
        self.assertTrue(checklist["all_clean"], checklist)
        self.assertEqual(checklist["loose_files"], [])

    def test_archive_warns_about_a_branch_with_no_upstream(self):
        room = self.create("local", "branch")
        repo = self.pushed_repo(room)
        git(repo, "checkout", "-q", "-b", "never-pushed")
        git(repo, "commit", "-q", "--allow-empty", "-m", "local only")
        checklist = self.checklist(room)
        self.assertFalse(checklist["all_clean"])
        self.assertIn("1 commits on no remote", checklist["repos"][0]["warnings"])

    def test_archive_warns_about_stashes(self):
        room = self.create("stashed", "work")
        repo = self.pushed_repo(room)
        (repo / "file.txt").write_text("change\n")
        git(repo, "add", "file.txt")
        git(repo, "stash", "-q")
        checklist = self.checklist(room)
        self.assertFalse(checklist["all_clean"])
        self.assertIn("1 stashes", checklist["repos"][0]["warnings"])

    def test_archive_lists_loose_files(self):
        room = self.create("loose", "files")
        self.pushed_repo(room)
        (Path(room["workroom_dir"]) / "analysis.md").write_text("notes\n")
        (Path(room["workroom_dir"]) / "scripts").mkdir()
        checklist = self.checklist(room)
        self.assertFalse(checklist["all_clean"])
        self.assertEqual(checklist["loose_files"], ["analysis.md", "scripts/"])

    def test_close_logs_the_summary_when_nothing_needs_a_decision(self):
        room = self.create("quiet", "close")
        closed = self.run_script("close", "--workroom", room["workroom_name"], "--summary", "Tests green, PR next")
        self.assertTrue(closed["log_updated"])
        self.assertIn("Tests green, PR next", Path(room["worklog"]).read_text(encoding="utf-8"))

    def test_close_leave_logs_the_stop_and_keeps_changes(self):
        room = self.create("leave", "changes")
        repo = self.pushed_repo(room)
        (repo / "file.txt").write_text("change\n")
        first = self.run_script("close", "--workroom", room["workroom_name"], "--summary", "x")
        self.assertTrue(first["needs_decision"])
        self.assertFalse(first["log_updated"])
        left = self.run_script("close", "--workroom", room["workroom_name"], "--leave", "--summary", "Left mid-refactor")
        self.assertFalse(left["needs_decision"])
        self.assertEqual(left["repos"][0]["action_taken"], "left")
        self.assertIn("Left mid-refactor", Path(room["worklog"]).read_text(encoding="utf-8"))
        self.assertTrue((repo / "file.txt").exists())


if __name__ == "__main__":
    unittest.main()
