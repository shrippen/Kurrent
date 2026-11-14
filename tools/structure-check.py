#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["lizard==1.26.0"]
# ///
"""Checks the structure limits of a repository: function size and file size.

Synced from the rules repository (`shrippen/regeln`, `tools/`) with `tools/sync-rules.sh`.
Do not edit this copy; change the source and sync.

    pipx run tools/structure-check.py            check, exit 1 on a violation
    pipx run tools/structure-check.py --update   rewrite structure.baseline from the code

What is over a limit today is listed in `structure.baseline` with its value. Such an
entry may stay as it is or shrink, never grow; code outside the list has to keep the
limits. Example line (tab separated): `src/app.rs	refresh	length=90`.
"""

import argparse
import collections
import enum
import fnmatch
import subprocess
import sys
from pathlib import Path

import lizard

# Limits of one function. Example: a function of 95 lines breaks "length".
FUNCTION_LIMITS = {"ccn": 15, "length": 80, "nesting": 4}

# Limit of one file, in lines.
FILE_LIMITS = {"lines": 800}

LIMITS = {**FUNCTION_LIMITS, **FILE_LIMITS}

BASELINE_NAME = "structure.baseline"
FILE_ENTRY = "-"
EXCLUDE_KEY = "exclude"

# Files whose length counts. Functions are measured where lizard knows the language.
CODE_SUFFIXES = {
    ".c", ".cc", ".cpp", ".dart", ".go", ".h", ".hpp", ".java", ".js", ".jsx", ".kt",
    ".lua", ".php", ".py", ".qml", ".rs", ".sh", ".ts", ".tsx", ".twig",
}

# QML carries its logic as JavaScript; lizard reads it under that name.
READ_AS = {".qml": ".js"}

FOREIGN_DIRS = {"vendor", "node_modules", "third_party", "3rdparty"}

BASELINE_HEAD = """\
# What is over a structure limit today (tools/structure-check.py). An entry may shrink,
# never grow; a raised or new entry needs its reason in the PR. Rewrite with --update.
# Lines: exclude<TAB>glob | path<TAB>function or - for the file<TAB>metric=value ...
"""


class Mode(enum.Enum):
    CHECK = "check"
    UPDATE = "update"


def repo_root():
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
    )

    return Path(out.stdout.strip())


def tracked_files(root):
    out = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, capture_output=True, text=True, check=True
    )

    return [p for p in out.stdout.split("\0") if p]


def is_measured(path, excludes):
    parts = Path(path)

    if parts.suffix not in CODE_SUFFIXES:
        return False

    if FOREIGN_DIRS.intersection(parts.parts):
        return False

    return not any(fnmatch.fnmatch(path, glob) for glob in excludes)


def function_values(path, code, analyzer):
    """Yields (function name, line, {metric: value}) for each function lizard finds."""
    suffix = Path(path).suffix
    name = path + READ_AS.get(suffix, "")

    if lizard.get_reader_for(name) is None:
        return

    for func in analyzer.analyze_source_code(name, code).function_list:
        yield func.name, func.start_line, {
            "ccn": func.cyclomatic_complexity,
            "length": func.length,
            "nesting": func.max_nested_structures,
        }


def measure(root, paths):
    """Returns {(path, name): (line, {metric: value})}, only values over their limit.

    Functions of one name in a file are numbered in file order, so each needs its own
    baseline entry. Example: "(anonymous)", "(anonymous)#2".
    """
    analyzer = lizard.FileAnalyzer(lizard.get_extensions(["ns"]))
    over = {}

    for path in paths:
        code = (root / path).read_text(encoding="utf-8", errors="replace")
        found = [(FILE_ENTRY, 1, {"lines": code.count("\n")})]
        found.extend(function_values(path, code, analyzer))

        seen = collections.Counter()

        for name, line, values in found:
            excess = {m: v for m, v in values.items() if v > LIMITS[m]}

            if not excess:
                continue

            seen[name] += 1
            key = name if seen[name] == 1 else f"{name}#{seen[name]}"
            over[(path, key)] = (line, excess)

    return over


def read_baseline(file):
    """Returns (exclude globs, {(path, name): {metric: value}})."""
    excludes, allowed = [], {}

    if not file.exists():
        return excludes, allowed

    for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
        if not line or line.startswith("#"):
            continue

        fields = line.split("\t")

        if fields[0] == EXCLUDE_KEY and len(fields) == 2:
            excludes.append(fields[1])
            continue

        if len(fields) != 3:
            sys.exit(f"{file.name}:{number}: expected 3 tab separated fields")

        pairs = (pair.split("=") for pair in fields[2].split())
        allowed[(fields[0], fields[1])] = {metric: int(value) for metric, value in pairs}

    return excludes, allowed


def write_baseline(file, excludes, over):
    lines = [f"{EXCLUDE_KEY}\t{glob}" for glob in excludes]

    for (path, name), (_, values) in sorted(over.items()):
        pairs = " ".join(f"{metric}={value}" for metric, value in sorted(values.items()))
        lines.append(f"{path}\t{name}\t{pairs}")

    file.write_text(BASELINE_HEAD + "\n".join(lines) + "\n", encoding="utf-8")


def violations(over, allowed):
    """Yields a message for each value above its limit and above its baseline entry."""
    for (path, name), (line, values) in sorted(over.items()):
        known = allowed.get((path, name), {})
        what = "file" if name == FILE_ENTRY else name

        for metric, value in sorted(values.items()):
            if metric in known and value <= known[metric]:
                continue

            bound = f"baseline {known[metric]}" if metric in known else f"limit {LIMITS[metric]}"
            yield f"{path}:{line}: {what}: {metric} {value} > {bound}"


def shrinkable(over, allowed):
    """Counts baseline values the code no longer needs (fixed, smaller or gone)."""
    count = 0

    for key, known in allowed.items():
        current = over.get(key, (0, {}))[1]
        count += sum(1 for metric, value in known.items() if current.get(metric, 0) < value)

    return count


def run(mode):
    root = repo_root()
    file = root / BASELINE_NAME
    excludes, allowed = read_baseline(file)

    paths = [p for p in tracked_files(root) if is_measured(p, excludes) and (root / p).is_file()]
    over = measure(root, paths)

    if mode is Mode.UPDATE:
        write_baseline(file, excludes, over)
        print(f"structure-check: {BASELINE_NAME} written, {len(over)} entries")
        return 0

    failed = list(violations(over, allowed))

    for message in failed:
        print(message)

    stale = shrinkable(over, allowed)

    if stale:
        print(f"structure-check: {stale} baseline values can shrink (--update)")

    print(f"structure-check: {len(paths)} files, {len(failed)} violations, {len(allowed)} in baseline")

    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--update", action="store_const", const=Mode.UPDATE, default=Mode.CHECK, dest="mode")

    sys.exit(run(parser.parse_args().mode))


if __name__ == "__main__":
    main()
