import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

FILE = pathlib.Path(__file__).with_name("check_release_source.py")
spec = importlib.util.spec_from_file_location("read_release_source", FILE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

SHA = "a" * 40

class ReadReleaseSourceTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = pathlib.Path(tmp.name)
        (self.root / "pubspec.yaml").write_text("name: read\nversion: 2.3.1+18\n", encoding="utf-8")
        p = self.root / "lib/src/profile"
        p.mkdir(parents=True)
        (self.root / "lib/src/version.dart").write_text("const String appVersion = '2.3.1';\n", encoding="utf-8")
        (p / "changelog_page.dart").write_text(
            "const readReleaseNotes = [\n  ReadReleaseNote('2.3.1', '2026-11-18', []),\n];\n", encoding="utf-8")

    def check(self, tag="v2.3.1-preview", main=SHA, target=SHA):
        def fake_git(*args):
            if args == ("rev-parse", "HEAD"):
                return SHA
            if args == ("rev-parse", "refs/remotes/origin/main"):
                return main
            if args == ("rev-list", "-n", "1", "refs/tags/" + tag):
                return target
            raise AssertionError(args)
        with patch.object(module, "ROOT", self.root), patch.object(module, "git", side_effect=fake_git):
            with patch("sys.argv", ["check_release_source.py", "--tag", tag]):
                return module.main()

    def test_tag_at_current_main_succeeds(self):
        self.assertEqual(self.check(), 0)

    def test_old_main_source_is_rejected(self):
        self.assertEqual(self.check(main="b" * 40), 1)

    def test_tag_to_different_commit_is_rejected(self):
        self.assertEqual(self.check(target="b" * 40), 1)

    def test_version_mismatch_is_rejected(self):
        self.assertEqual(self.check(tag="v2.4.0-preview"), 1)

    def test_missing_latest_changelog_is_rejected(self):
        p = self.root / "lib/src/profile/changelog_page.dart"
        p.write_text("ReadReleaseNote('2.3.0', '2026-11-17', []);", encoding="utf-8")
        self.assertEqual(self.check(), 1)

if __name__ == "__main__":
    unittest.main()
