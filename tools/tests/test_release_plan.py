"""Offline release-planning regressions using disposable Git repositories."""

import importlib.util
from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

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
        for feature in planner.FEATURES:
            self.git("tag", f"{feature}-v1.0.0")

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
        for feature in planner.FEATURES:
            self.assertIsNone(self.plan(feature))

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

    def test_core_releases_all_features(self):
        self.commit("fix(shared): fix profile merge", "Core/Sync.lua")
        for feature in planner.FEATURES:
            self.assertEqual(self.plan(feature)["version"], "1.0.1")

    def test_bags_release_identity_and_isolation(self):
        self.commit("feat(bags): add bank search", "Bags/Viewer.lua")
        self.commit("docs(bags): explain snapshots", "Bags/README.md")
        result = self.plan("bags", "alpha")
        self.assertEqual(result["tag"], "bags-v1.1.0-alpha.1")
        self.assertEqual(result["source"], "Bags")
        self.assertEqual(result["project_variable"], "CURSEFORGE_BAGS_PROJECT_ID")
        self.assertTrue(result["prerelease"])
        self.assertIn("add bank search", result["notes"])
        self.assertIn("explain snapshots", result["notes"])
        self.assertIsNone(self.plan("nameplates"))
        self.assertIsNone(self.plan("questtracker"))

    def test_bags_non_runtime_changes_do_not_trigger(self):
        for message, path in (
            ("docs(bags): explain bank", "Bags/README.md"),
            ("test(bags): cover snapshots", "Bags/tests/runtime.lua"),
            ("build(bags): package bank", ".pkgmeta-bags"),
            ("ci(shared): maintain workflow", ".github/workflows/create-releases.yaml"),
        ):
            self.commit(message, path)
        for feature in planner.FEATURES:
            self.assertIsNone(self.plan(feature))

    def test_notes_describe_alternative_hosts_without_relaxing_questtracker(self):
        self.commit("fix(shared): update embedded core", "Core/Core.lua")
        for feature in ("nameplates", "bags"):
            with self.subTest(feature=feature):
                self.assertIn(f"or EUI Standalone {planner.FEATURES[feature]}", self.plan(feature)["notes"])
        quest_notes = self.plan("questtracker")["notes"]
        self.assertIn("Requires EllesmereUI and its matching feature module.", quest_notes)
        self.assertNotIn("Standalone", quest_notes)

    def test_bags_first_release_channel_from_plain_source_version(self):
        self.git("tag", "-d", "bags-v1.0.0")
        toc = Path("Bags/EllesmereUIExtendBags.toc")
        toc.write_text("## Version: 0.1.0\n", encoding="utf-8")
        self.commit("feat(bags): add bank snapshots", "Bags/Bags.lua")
        for channel, expected in (("alpha", "0.2.0-alpha.1"), ("beta", "0.2.0-beta.1"), ("stable", "0.2.0")):
            with self.subTest(channel=channel):
                result = self.plan("bags", channel)
                self.assertEqual(result["tag"], "bags-v" + expected)
                self.assertEqual(result["version"], expected)
                self.assertEqual(result["prerelease"], channel != "stable")
                self.assertEqual(toc.read_text(encoding="utf-8"), "## Version: 0.1.0\n")

    def test_bags_historical_alpha_source_version_remains_supported(self):
        self.git("tag", "-d", "bags-v1.0.0")
        Path("Bags/EllesmereUIExtendBags.toc").write_text("## Version: 0.1.0-alpha.1\n", encoding="utf-8")
        self.commit("feat(bags): add bank snapshots", "Bags/Bags.lua")
        self.assertEqual(self.plan("bags", "alpha")["tag"], "bags-v0.2.0-alpha.1")

    def test_bags_prerelease_promotion_and_independent_boundary(self):
        self.commit("fix(bags): fix capture", "Bags/Snapshot.lua")
        alpha = self.plan("bags", "alpha")
        self.git("tag", alpha["tag"])
        self.assertIsNone(self.plan("bags", "alpha"))
        beta = self.plan("bags", "beta")
        self.assertEqual(beta["tag"], "bags-v1.0.1-beta.1")
        self.git("tag", beta["tag"])
        self.assertEqual(self.plan("bags")["tag"], "bags-v1.0.1")
        self.commit("fix(shared): fix embedded core", "Core/Core.lua")
        self.assertEqual(self.plan("bags", "beta")["tag"], "bags-v1.0.1-beta.2")
        for feature in ("nameplates", "questtracker"):
            result = self.plan(feature)
            self.assertEqual(result["version"], "1.0.1")
            self.assertNotIn("fix capture", result["notes"])
            self.assertIn("fix embedded core", result["notes"])

    def test_three_feature_matrix_and_notes_artifacts(self):
        self.commit("fix(shared): fix embedded core", "Core/Core.lua")
        self.commit("fix(bags): fix bank viewer", "Bags/Viewer.lua")
        output = Path("release-plan")
        env = {"GITHUB_OUTPUT": str(Path("github-output")), "GITHUB_STEP_SUMMARY": str(Path("summary"))}
        with patch.dict(os.environ, env), patch("sys.argv", ["release_plan.py", "--channel", "alpha", "--output", str(output)]):
            planner.main()
        matrix = json.loads((output / "plan.json").read_text(encoding="utf-8"))
        self.assertEqual({p["feature"] for p in matrix["include"]}, set(planner.FEATURES))
        for result in matrix["include"]:
            feature = result["feature"]
            self.assertEqual(result["source"], planner.FEATURES[feature])
            self.assertEqual(result["project_variable"], f"CURSEFORGE_{feature.upper()}_PROJECT_ID")
            self.assertEqual(result["tag"], f"{feature}-v1.0.1-alpha.1")
            self.assertNotIn("notes", result)
            notes = (output / f"{feature}.md").read_text(encoding="utf-8")
            self.assertIn("fix embedded core", notes)
            self.assertEqual("fix bank viewer" in notes, feature == "bags")
        github_output = Path(env["GITHUB_OUTPUT"]).read_text(encoding="utf-8")
        self.assertIn("has_releases=true", github_output)
        self.assertEqual(json.loads(github_output.splitlines()[0].removeprefix("matrix=")), matrix)
        self.assertIn("bags-v1.0.1-alpha.1", Path(env["GITHUB_STEP_SUMMARY"]).read_text(encoding="utf-8"))

    def test_feature_notes_isolated(self):
        self.commit("feat(questtracker): new controls", "QuestTracker/Options.lua")
        self.commit("fix(nameplates): restore alpha", "Nameplates/Nameplates.lua")
        self.assertNotIn("new controls", self.plan()["notes"])
        self.assertEqual(self.plan("questtracker")["version"], "1.1.0")
        self.assertIsNone(self.plan("bags"))

    def test_all_nonempty_addon_selections_filter_matrix_and_artifacts(self):
        self.commit("fix(shared): update embedded core", "Core/Core.lua")
        features = tuple(planner.FEATURES)
        for mask in range(1, 1 << len(features)):
            selected = [feature for i, feature in enumerate(features) if mask & (1 << i)]
            with self.subTest(selected=selected):
                output = Path(f"selected-{mask}")
                env = {"GITHUB_OUTPUT": f"github-output-{mask}", "GITHUB_STEP_SUMMARY": f"summary-{mask}"}
                argv = ["release_plan.py", "--channel", "alpha", "--features", *selected, "--output", str(output)]
                with patch.dict(os.environ, env), patch("sys.argv", argv), redirect_stdout(io.StringIO()):
                    planner.main()
                matrix = json.loads((output / "plan.json").read_text(encoding="utf-8"))
                self.assertEqual([result["feature"] for result in matrix["include"]], selected)
                self.assertEqual({path.stem for path in output.glob("*.md")}, set(selected))
                emitted = Path(env["GITHUB_OUTPUT"]).read_text(encoding="utf-8")
                self.assertIn("has_releases=true", emitted)
                self.assertEqual(json.loads(emitted.splitlines()[0].removeprefix("matrix=")), matrix)
                summary = Path(env["GITHUB_STEP_SUMMARY"]).read_text(encoding="utf-8")
                self.assertIn("Selected addons: " + ", ".join(planner.FEATURES[f] for f in selected), summary)
                for feature in set(features) - set(selected):
                    self.assertNotIn(feature + "-v", summary)

    def test_unselected_addon_planner_errors_do_not_block_selection(self):
        self.commit("fix(nameplates): beta fix", "Nameplates/Nameplates.lua")
        self.git("tag", "nameplates-v1.0.1-beta.1")
        self.commit("fix(nameplates): next fix", "Nameplates/Nameplates.lua")
        self.commit("feat(bags): new bank display", "Bags/Viewer.lua")
        argv = ["release_plan.py", "--channel", "alpha", "--features", "bags", "--output", "selected"]
        with patch("sys.argv", argv), patch.object(planner, "plan", wraps=planner.plan) as called, redirect_stdout(io.StringIO()):
            planner.main()
        self.assertEqual([call.args[0] for call in called.call_args_list], ["bags"])
        matrix = json.loads(Path("selected/plan.json").read_text(encoding="utf-8"))
        self.assertEqual([result["feature"] for result in matrix["include"]], ["bags"])
        self.assertEqual(matrix["include"][0]["version"], "1.1.0-alpha.1")

    def test_selection_does_not_force_ineligible_release(self):
        self.commit("feat(nameplates): new display", "Nameplates/Nameplates.lua")
        env = {"GITHUB_OUTPUT": "github-output", "GITHUB_STEP_SUMMARY": "summary"}
        argv = ["release_plan.py", "--channel", "stable", "--features", "bags", "--output", "selected"]
        with patch.dict(os.environ, env), patch("sys.argv", argv), redirect_stdout(io.StringIO()):
            planner.main()
        self.assertEqual(json.loads(Path("selected/plan.json").read_text(encoding="utf-8")), {"include": []})
        self.assertFalse(list(Path("selected").glob("*.md")))
        self.assertIn("has_releases=false", Path("github-output").read_text(encoding="utf-8"))
        summary = Path("summary").read_text(encoding="utf-8")
        self.assertIn("Selected addons: Bags", summary)
        self.assertIn("No code-driven releases", summary)

    def test_selection_deduplicates_in_canonical_order(self):
        self.commit("fix(shared): update core", "Core/Core.lua")
        argv = ["release_plan.py", "--channel", "stable", "--features", "bags", "nameplates", "bags", "--output", "selected"]
        with patch("sys.argv", argv), redirect_stdout(io.StringIO()):
            planner.main()
        matrix = json.loads(Path("selected/plan.json").read_text(encoding="utf-8"))
        self.assertEqual([result["feature"] for result in matrix["include"]], ["nameplates", "bags"])

    def test_empty_or_invalid_explicit_selection_is_rejected_before_planning(self):
        for selection in ([], ["invalid"], ["all"], ["bags", "invalid"]):
            with self.subTest(selection=selection):
                argv = ["release_plan.py", "--channel", "alpha", "--features", *selection, "--output", "selected"]
                with patch("sys.argv", argv), patch.object(planner, "plan") as called, redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as error:
                        planner.main()
                    self.assertEqual(error.exception.code, 2)
                    called.assert_not_called()
                self.assertFalse(Path("selected").exists())

    def test_shared_cross_feature_change(self):
        self.commit("feat(shared): new settings", "Nameplates/Options.lua")
        Path("QuestTracker/Options.lua").write_text("fixture\n", encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "--amend", "--no-edit", "-q")
        self.assertEqual(self.plan()["version"], "1.1.0")
        self.assertEqual(self.plan("questtracker")["version"], "1.1.0")
        self.assertIsNone(self.plan("bags"), "shared scope without Bags/Core runtime must not release Bags")

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


class WorkflowSelectionTests(unittest.TestCase):
    def test_dispatch_checkboxes_are_passed_to_planner_safely(self):
        workflow = (Path(__file__).parents[2] / ".github/workflows/create-releases.yaml").read_text(encoding="utf-8")
        for feature in planner.FEATURES:
            self.assertRegex(workflow, rf"(?m)^      {feature}:\n        description: [^\n]+\n        type: boolean\n        default: true$")
            self.assertIn(f"SELECT_{feature.upper()}: ${{{{ inputs.{feature} }}}}", workflow)
            self.assertIn(f'if [[ "$SELECT_{feature.upper()}" == \'true\' ]]; then features+=({feature}); fi', workflow)
        self.assertIn('if (( ${#features[@]} == 0 )); then', workflow)
        self.assertIn("::error::Select at least one addon to release.", workflow)
        self.assertIn('--features "${features[@]}"', workflow)
        self.assertIn("matrix: ${{ fromJSON(needs.plan.outputs.matrix) }}", workflow)
        self.assertIn("needs.plan.outputs.has_releases == 'true' && !inputs.preview", workflow)


if __name__ == "__main__":
    unittest.main()
