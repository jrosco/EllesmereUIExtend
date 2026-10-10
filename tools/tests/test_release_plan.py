"""Offline release-planning regressions using disposable Git repositories."""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("release_plan", Path(__file__).parents[1] / "release_plan.py")
planner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(planner)


class ReleasePlanTests(unittest.TestCase):
    def setUp(self):
        temp_root = None
        if os.name == "nt":
            temp_root = Path(os.environ["LOCALAPPDATA"]) / "Temp" / "opencode"
            temp_root.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="release-plan-", dir=temp_root)
        self.previous = Path.cwd()
        os.chdir(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release test")
        self.git("config", "user.email", "release-test@example.invalid")
        self.git("config", "core.autocrlf", "false")
        for feature, source in planner.FEATURES.items():
            path = Path(source) / f"EllesmereUIExtend{source}.toc"
            path.parent.mkdir()
            path.write_text("## Version: 1.0.0\n", encoding="utf-8")
        self.commit("chore(shared): initialize fixtures", "Core/Core.lua")
        self.git("tag", "nameplates-v1.0.0")
        self.git("tag", "questtracker-v1.0.0")

    def tearDown(self):
        os.chdir(self.previous)
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], text=True, stderr=subprocess.STDOUT).strip()

    def commit(self, message, path):
        file = Path(path)
        file.parent.mkdir(parents=True, exist_ok=True)
        with file.open("a", encoding="utf-8") as stream:
            stream.write("fixture\n")
        self.git("add", ".")
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def plan(self, feature="nameplates", channel="stable"):
        return planner.plan(feature, channel, self.git("rev-parse", "HEAD"), self.git("tag").splitlines())

    def test_no_changes(self):
        self.assertIsNone(self.plan())

    def test_docs_chore_tests_do_not_trigger(self):
        self.commit("docs(shared): improve guidance", "README.md")
        self.commit("chore(shared): maintain core", "Core/Core.lua")
        self.commit("test(nameplates): add fixture", "Nameplates/tests/runtime.lua")
        self.assertIsNone(self.plan())

    def test_notes_included_in_next_runtime_release(self):
        self.commit("docs(shared): improve guidance", "README.md")
        self.commit("fix(nameplates): fix opacity", "Nameplates/Nameplates.lua")
        result = self.plan()
        self.assertEqual(result["tag"], "nameplates-v1.0.1")
        self.assertIn("improve guidance", result["notes"])
        self.assertIn("fix opacity", result["notes"])
        self.assertIsNone(self.plan("questtracker"))

    def test_core_releases_both(self):
        self.commit("fix(shared): fix profile merge", "Core/Sync.lua")
        self.assertEqual(self.plan()["version"], "1.0.1")
        self.assertEqual(self.plan("questtracker")["version"], "1.0.1")

    def test_feature_notes_isolated(self):
        self.commit("feat(questtracker): new controls", "QuestTracker/Options.lua")
        self.commit("fix(nameplates): restore alpha", "Nameplates/Nameplates.lua")
        self.assertNotIn("new controls", self.plan()["notes"])
        self.assertEqual(self.plan("questtracker")["version"], "1.1.0")

    def test_shared_cross_feature_change(self):
        self.commit("feat(shared): new settings", "Nameplates/Options.lua")
        Path("QuestTracker/Options.lua").write_text("fixture\n", encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "--amend", "--no-edit", "-q")
        self.assertEqual(self.plan()["version"], "1.1.0")
        self.assertEqual(self.plan("questtracker")["version"], "1.1.0")

    def test_breaking_markers(self):
        for message in ("feat(shared)!: new contract", "refactor(shared): new contract\n\nBREAKING CHANGE: new API"):
            relevant, level, _, _, breaking = planner.classify(message, ["Core/Core.lua"], "nameplates")
            self.assertTrue(relevant and breaking)
            self.assertEqual(level, 3)
        self.commit("feat(shared)!: new contract", "Core/Core.lua")
        self.assertEqual(self.plan()["version"], "2.0.0")

    def test_prerelease_iteration_and_promotion(self):
        self.commit("fix(nameplates): fix opacity", "Nameplates/Nameplates.lua")
        first = self.plan(channel="alpha")
        self.assertEqual(first["version"], "1.0.1-alpha.1")
        self.git("tag", first["tag"])
        self.assertIsNone(self.plan(channel="alpha"))
        self.assertEqual(self.plan(channel="beta")["version"], "1.0.1-beta.1")
        self.commit("docs(nameplates): explain opacity", "Nameplates/README.md")
        self.assertIsNone(self.plan(channel="alpha"))
        self.commit("fix(nameplates): second fix", "Nameplates/Nameplates.lua")
        self.assertEqual(self.plan(channel="alpha")["version"], "1.0.1-alpha.2")
        stable = self.plan()
        self.assertEqual(stable["version"], "1.0.1")
        self.assertIn("fix opacity", stable["notes"])
        self.assertIn("second fix", stable["notes"])

    def test_beta_downgrade_refused(self):
        self.commit("fix(nameplates): first fix", "Nameplates/Nameplates.lua")
        self.git("tag", "nameplates-v1.0.1-beta.1")
        self.commit("fix(nameplates): second fix", "Nameplates/Nameplates.lua")
        with self.assertRaisesRegex(ValueError, "back to alpha"):
            self.plan(channel="alpha")

    def test_no_stable_tag_continues_prerelease(self):
        self.git("tag", "-d", "nameplates-v1.0.0")
        self.git("tag", "nameplates-v1.0.0-alpha.0")
        self.commit("fix(nameplates): first fix", "Nameplates/Nameplates.lua")
        self.assertEqual(self.plan(channel="alpha")["version"], "1.0.0-alpha.1")
        self.assertEqual(self.plan()["version"], "1.0.0")

    def test_first_release_uses_source_version(self):
        self.git("tag", "-d", "nameplates-v1.0.0")
        self.commit("feat(nameplates): new feature", "Nameplates/Nameplates.lua")
        self.assertEqual(self.plan()["version"], "1.1.0")

    def test_historical_unscoped_runtime_commit_is_patch(self):
        self.commit("Restore opacity", "Nameplates/Nameplates.lua")
        self.assertEqual(self.plan()["version"], "1.0.1")

    def test_tag_collision_refused(self):
        start = self.git("rev-parse", "HEAD")
        self.commit("fix(nameplates): future fix", "Nameplates/Nameplates.lua")
        self.git("tag", "nameplates-v1.0.1")
        self.git("checkout", "--detach", start)
        self.commit("fix(nameplates): branch fix", "Nameplates/Nameplates.lua")
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.plan()

    def test_version_sort_is_numeric(self):
        self.assertGreater(planner.version_key("nameplates-v1.0.10"), planner.version_key("nameplates-v1.0.9"))
        self.assertGreater(planner.version_key("nameplates-v1.0.1"), planner.version_key("nameplates-v1.0.1-beta.9"))

    def test_major_precedence_and_feature_baselines(self):
        self.commit("feat(nameplates): new controls", "Nameplates/Options.lua")
        self.commit("fix(shared)!: new shared contract", "Core/Core.lua")
        self.assertEqual(self.plan()["version"], "2.0.0")
        self.git("tag", "nameplates-v2.0.0")
        self.assertIsNone(self.plan())
        self.assertEqual(self.plan("questtracker")["version"], "2.0.0")

    def test_unsupported_tags_ignored(self):
        self.git("tag", "nameplates-v9.0.0-rc.1")
        self.commit("fix(nameplates): fix opacity", "Nameplates/Nameplates.lua")
        self.assertEqual(self.plan()["version"], "1.0.1")

    def test_reserved_prerelease_counter_is_skipped(self):
        start = self.git("rev-parse", "HEAD")
        self.commit("fix(nameplates): future fix", "Nameplates/Nameplates.lua")
        self.git("tag", "nameplates-v1.0.1-alpha.1")
        self.git("checkout", "--detach", start)
        self.commit("fix(nameplates): branch fix", "Nameplates/Nameplates.lua")
        self.assertEqual(self.plan(channel="alpha")["version"], "1.0.1-alpha.2")


if __name__ == "__main__":
    unittest.main()
