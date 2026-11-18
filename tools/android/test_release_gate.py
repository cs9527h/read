import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

SRC = pathlib.Path(__file__).with_name("release_gate.py")
spec = importlib.util.spec_from_file_location("read_release_gate", SRC)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
SHA = "a" * 40
TAG = "v2.4.0-preview"
ENV = {"GITHUB_EVENT_NAME": "workflow_dispatch",
       "GITHUB_REF": "refs/heads/main", "RELEASE_TAG": TAG}


class ReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "pubspec.yaml").write_text("name: read\nversion: 2.4.0+18\n")
        (self.root / "tools/android").mkdir(parents=True)
        (self.root / "tools/android/read_release_baseline.json").write_text(
            '{"released_version":"2.3.0","released_build_number":17}'
        )
        d = self.root / "lib/src/profile"
        d.mkdir(parents=True)
        (d / "changelog_page.dart").write_text("ReadReleaseNote('2.4.0', '2026-11-18', []),")

    def run_gate(self, env=None, tag_commit=SHA, main_commit=SHA):
        def mock_git(*args):
            if args[0] == "merge-base":
                if main_commit != SHA:
                    raise __import__("subprocess").CalledProcessError(1, args)
                return ""
            if args == ("rev-parse", "HEAD"):
                return SHA
            if args == ("rev-parse", f"refs/tags/{TAG}^{{commit}}"):
                return tag_commit
            if args == ("rev-parse", "refs/remotes/origin/main"):
                return main_commit
            raise AssertionError(args)
        with patch.object(module, "ROOT", self.root), patch.object(module, "git", side_effect=mock_git), patch.dict(__import__("os").environ, ENV if env is None else env, clear=True):
            return module.guard()

    def test_current_main_tag_passes(self):
        self.assertEqual(self.run_gate(), SHA)

    def test_stale_main_tag_fails(self):
        with self.assertRaises(SystemExit):
            self.run_gate(main_commit="b" * 40)

    def test_other_commit_tag_fails(self):
        with self.assertRaises(SystemExit):
            self.run_gate(tag_commit="b" * 40)

    def test_missing_current_changelog_fails(self):
        (self.root / "lib/src/profile/changelog_page.dart").write_text("no current version")
        with self.assertRaises(SystemExit):
            self.run_gate()

    def test_equal_build_number_fails(self):
        (self.root / "pubspec.yaml").write_text("name: read\nversion: 2.4.0+17\n")
        with self.assertRaises(SystemExit):
            self.run_gate()

    def test_tag_version_mismatch_fails(self):
        (self.root / "pubspec.yaml").write_text("name: read\nversion: 2.3.0+17\n")
        with self.assertRaises(SystemExit):
            self.run_gate()


if __name__ == "__main__":
    unittest.main()
