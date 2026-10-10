"""Plan independent addon releases without changing Git or contacting GitHub."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess

FEATURES = {"nameplates": "Nameplates", "questtracker": "QuestTracker"}
HEADER = re.compile(r"^(\w+)(?:\(([^)]+)\))?(!)?: (.+)$")
VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-(alpha|beta)\.(\d+))?$")
RELEASE_TYPES = {"feat", "fix", "perf", "refactor", "revert", "build"}


def git(*args):
    return subprocess.check_output(["git", *args], text=True, encoding="utf-8").strip()


def version(value):
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError(f"Unsupported version: {value}")
    major, minor, patch, channel, number = match.groups()
    return (int(major), int(minor), int(patch)), channel, int(number or 0)


def version_key(tag):
    base, channel, number = version(tag.split("-v", 1)[1])
    return (*base, {"alpha": 0, "beta": 1, None: 2}[channel], number)


def bump(base, level):
    major, minor, patch = base
    if level == 3:
        return major + 1, 0, 0
    if level == 2:
        return major, minor + 1, 0
    return major, minor, patch + 1


def classify(message, paths, feature):
    """Scopes route notes; paths prevent repository-only changes releasing addons."""
    header = HEADER.match(message.splitlines()[0])
    kind, scope, bang, description = header.groups() if header else (
        "other", None, None, message.splitlines()[0]
    )
    kind = kind.lower()
    scope = scope.lower() if scope else None
    runtime = any(
        (p.startswith("Core/") or p.startswith(FEATURES[feature] + "/"))
        and "/tests/" not in p
        and (p.endswith(".lua") or p.endswith(".toc"))
        for p in paths
    )
    relevant = scope in (feature, "shared") if scope else runtime
    breaking = bool(bang or re.search(r"(?m)^BREAKING[ -]CHANGE: \S", message))
    trigger = relevant and runtime and (kind in RELEASE_TYPES or breaking or not header)
    level = (3 if breaking else 2 if kind == "feat" else 1) if trigger else 0
    return relevant, level, kind, description, breaking


def commits(base, target):
    revision = f"{base}..{target}" if base else target
    result = []
    for sha in git("rev-list", "--reverse", "--no-merges", revision).splitlines():
        result.append({
            "sha": sha,
            "message": git("show", "-s", "--format=%B", sha),
            "paths": git("diff-tree", "--root", "--no-commit-id", "--name-only", "-r", sha).splitlines(),
        })
    return result


def notes_for(entries, feature, base, tag):
    groups = {}
    labels = {"feat": "Features", "fix": "Fixes", "perf": "Performance"}
    for entry in entries:
        relevant, _, kind, description, breaking = classify(entry["message"], entry["paths"], feature)
        if relevant:
            label = "Breaking changes" if breaking else labels.get(kind, "Other changes")
            groups.setdefault(label, []).append(f"- {description} (`{entry['sha'][:7]}`)")
            if breaking:
                for line in entry["message"].splitlines():
                    if re.match(r"^BREAKING[ -]CHANGE: ", line):
                        groups[label].append("  - " + line.split(": ", 1)[1])
    lines = [f"# {FEATURES[feature]} {tag.split('-v', 1)[1]}", "",
             "For Retail and WoW Forever. Shared Extend profiles are embedded.",
             "Requires EllesmereUI and its matching feature module.", ""]
    if base:
        lines.extend([f"Changes since `{base}`.", ""])
    for label in ("Breaking changes", "Features", "Fixes", "Performance", "Other changes"):
        if label in groups:
            lines.extend([f"## {label}", "", *groups[label], ""])
    if not groups:
        lines.extend(["Promotes the previously released prerelease to this channel.", ""])
    return "\n".join(lines)


def plan(feature, channel, target, all_tags):
    tags = [t for t in all_tags if t.startswith(feature + "-v")
            and VERSION.fullmatch(t.split("-v", 1)[1])]
    reachable = [t for t in tags if subprocess.run(
        ["git", "merge-base", "--is-ancestor", t, target], capture_output=True
    ).returncode == 0]
    latest = max(reachable, key=version_key, default=None)
    stable = max((t for t in reachable if version(t.split("-v", 1)[1])[1] is None),
                 key=version_key, default=None)
    recent = commits(latest, target)
    recent_level = max((classify(c["message"], c["paths"], feature)[1] for c in recent), default=0)
    latest_version = version(latest.split("-v", 1)[1]) if latest else None
    promotion = latest_version and latest_version[1] and (
        channel == "stable" or channel == "beta" and latest_version[1] == "alpha"
    )
    if not recent_level and not promotion:
        return None
    if latest_version and latest_version[1] == "beta" and channel == "alpha":
        raise ValueError(f"{feature}: cannot move the current beta back to alpha")
    if stable:
        entries = commits(stable, target)
        level = max((classify(c["message"], c["paths"], feature)[1] for c in entries), default=1)
        base = bump(version(stable.split("-v", 1)[1])[0], level)
        if latest_version:
            base = max(base, latest_version[0])
    elif latest_version:
        # Before the first stable release, continue the existing prerelease base.
        base = bump(latest_version[0], recent_level) if recent_level >= 2 else latest_version[0]
    else:
        toc = Path(FEATURES[feature]) / f"EllesmereUIExtend{FEATURES[feature]}.toc"
        source_version = re.search(r"(?m)^## Version: ([\w.-]+)", toc.read_text(encoding="utf-8"))
        if not source_version:
            raise ValueError(f"Missing source version: {toc}")
        base = bump(version(source_version[1])[0], recent_level)
    value = ".".join(map(str, base))
    if channel != "stable":
        numbers = [version(t.split("-v", 1)[1])[2] for t in tags
                   if version(t.split("-v", 1)[1])[:2] == (base, channel)]
        value += f"-{channel}.{max(numbers, default=0) + 1}"
    tag = f"{feature}-v{value}"
    if tag in all_tags:
        raise ValueError(f"Tag already exists: {tag}; refusing to overwrite it")
    baseline = stable if channel == "stable" else latest
    return {"feature": feature, "source": FEATURES[feature], "tag": tag,
            "project_variable": f"CURSEFORGE_{feature.upper()}_PROJECT_ID",
            "version": value, "prerelease": channel != "stable", "sha": target,
            "notes": notes_for(commits(baseline, target), feature, baseline, tag)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--channel", choices=("alpha", "beta", "stable"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    target = git("rev-parse", "HEAD")
    tags = git("tag", "--list").splitlines()
    plans = [p for f in FEATURES if (p := plan(f, args.channel, target, tags))]
    args.output.mkdir(parents=True, exist_ok=True)
    for p in plans:
        (args.output / f"{p['feature']}.md").write_text(p.pop("notes"), encoding="utf-8")
    matrix = {"include": plans}
    (args.output / "plan.json").write_text(json.dumps(matrix, indent=2), encoding="utf-8")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.write(f"matrix={json.dumps(matrix)}\n")
            output.write(f"has_releases={'true' if plans else 'false'}\n")
    summary = "\n".join(f"- {p['tag']} at {target[:7]}" for p in plans) or "No code-driven releases to create."
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write("## Release plan\n\n" + summary + "\n")


if __name__ == "__main__":
    main()
