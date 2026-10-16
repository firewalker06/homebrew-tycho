"""Regression checks for test-bot's ignored-build and absent-test reports."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("verify_bottles", Path(__file__).parents[1] / "scripts/verify-bottles.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReportsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "steps_output.txt").write_text("All steps passed!")
        (self.root / "skipped_or_failed_formulae-x86_64_linux.txt").write_text("")
        self.report("passed")

    def report(self, status, name="test firewalker06/tycho/tycho"):
        (self.root / "brew-test-bot.xml").write_text(
            f'<testsuites><testsuite><testcase name="{name}" status="{status}"/></testsuite></testsuites>')

    def test_passed_installed_test(self):
        module.verify_reports(self.root)

    def test_actual_ignored_build_summary_is_rejected(self):
        (self.root / "steps_output.txt").write_text("Warning: 1 failed step ignored!")
        with self.assertRaisesRegex(ValueError, "ignored"):
            module.verify_reports(self.root)

    def test_skipped_formula_is_rejected(self):
        (self.root / "skipped_or_failed_formulae-x86_64_linux.txt").write_text("firewalker06/tycho/tycho")
        with self.assertRaisesRegex(ValueError, "skipped"):
            module.verify_reports(self.root)

    def test_absent_installed_test_is_rejected(self):
        self.report("passed", "audit firewalker06/tycho/tycho")
        with self.assertRaisesRegex(ValueError, "did not pass"):
            module.verify_reports(self.root)

    def test_ignored_installed_test_is_rejected(self):
        self.report("ignored")
        with self.assertRaisesRegex(ValueError, "did not pass"):
            module.verify_reports(self.root)

    def test_missing_bottle_is_rejected_even_with_passed_reports(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            module.verify(self.root, "0.14.0", "x86_64_linux")


if __name__ == "__main__":
    unittest.main()
