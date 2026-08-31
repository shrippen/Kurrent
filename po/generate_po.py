#!/usr/bin/env python3
"""Generate .po files for plasma_applet_com.github.shrippen.kurrent."""
from __future__ import annotations

import datetime
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extra_translations import EXTRA

DOMAIN = "plasma_applet_com.github.shrippen.kurrent"
VERSION = "1.0.0"
YEAR = datetime.date.today().year
QML_ROOT = Path(__file__).resolve().parent.parent / "plasmoid"

QML_I18N = re.compile(r'i18n(?:c\s*\(\s*"[^"]*"\s*,\s*)?\(\s*"((?:[^"\\]|\\.)*)"')

PLURALS = {
    "%1 open task": {
        "msgid_plural": "%1 open tasks",
        "de": ["%1 offene Aufgabe", "%1 offene Aufgaben"],
        "es": ["%1 tarea abierta", "%1 tareas abiertas"],
        "fr": ["%1 tâche ouverte", "%1 tâches ouvertes"],
        "ja": ["%1 件の未完了タスク"],
        "zh_CN": ["%1 个未完成任务", "%1 个未完成任务"],
    },
    "%1 task": {
        "msgid_plural": "%1 tasks",
        "de": ["%1 Aufgabe", "%1 Aufgaben"],
        "es": ["%1 tarea", "%1 tareas"],
        "fr": ["%1 tâche", "%1 tâches"],
        "ja": ["%1 件のタスク"],
        "zh_CN": ["%1 个任务", "%1 个任务"],
    },
}

LANGS = {
    "de": ("de", "nplurals=2; plural=(n != 1);"),
    "es": ("es", "nplurals=2; plural=(n != 1);"),
    "fr": ("fr", "nplurals=2; plural=(n > 1);"),
    "ja": ("ja", "nplurals=1; plural=0;"),
    "zh_CN": ("zh_CN", "nplurals=1; plural=0;"),
}

LANG_NAMES = {
    "de": "German",
    "es": "Spanish",
    "fr": "French",
    "ja": "Japanese",
    "zh_CN": "Chinese (Simplified)",
}


def extract_qml_strings() -> list[str]:
    found: set[str] = set()
    for qml in sorted(QML_ROOT.rglob("*.qml")):
        for match in QML_I18N.finditer(qml.read_text(encoding="utf-8")):
            found.add(match.group(1))
    return sorted(found)


def po_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def header(lang: str, plural: str) -> str:
    return f'''# Translation of {DOMAIN} to {LANG_NAMES[lang]}.
# Copyright (C) {YEAR} Kurrent Contributors
# This file is distributed under the same license as the kurrent package.
#
msgid ""
msgstr ""
"Project-Id-Version: kurrent {VERSION}\\n"
"Report-Msgid-Bugs-To: \\n"
"POT-Creation-Date: {YEAR}-01-01 00:00+0000\\n"
"PO-Revision-Date: {YEAR}-01-01 00:00+0000\\n"
"Last-Translator: Kurrent Contributors\\n"
"Language-Team: {LANG_NAMES[lang]}\\n"
"Language: {lang}\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Plural-Forms: {plural}\\n"
'''


def nplurals_for(plural: str) -> int:
    if "nplurals=6" in plural:
        return 6
    if "nplurals=3" in plural:
        return 3
    if "nplurals=1" in plural:
        return 1
    return 2


def main() -> int:
    out_dir = Path(__file__).resolve().parent
    msgids = extract_qml_strings()
    missing: dict[str, list[str]] = {lang: [] for lang in LANGS}

    for lang in LANGS:
        extra = EXTRA.get(lang, {})
        for msgid in msgids:
            if msgid not in extra:
                missing[lang].append(msgid)
        for msgid, data in PLURALS.items():
            if lang not in data:
                missing[lang].append(f"{msgid} (plural)")

    exit_code = 0
    for lang, items in missing.items():
        plain = [m for m in items if not m.endswith(" (plural)")]
        if plain:
            exit_code = 1
            print(f"MISSING {lang}: {len(plain)}")
            for item in plain:
                print(f"  {item}")

    if exit_code:
        print("Regenerate catalog: python3 po/_merge_catalog.py", file=sys.stderr)
        return exit_code

    for lang, (_, plural) in LANGS.items():
        nplurals = nplurals_for(plural)
        extra = EXTRA[lang]
        body = [header(lang, plural), ""]
        for msgid in msgids:
            body.append(f'msgid "{po_escape(msgid)}"')
            body.append(f'msgstr "{po_escape(extra[msgid])}"')
            body.append("")
        for msgid, data in PLURALS.items():
            forms = list(data[lang])
            while len(forms) < nplurals:
                forms.append(forms[-1])
            body.append(f'msgid "{po_escape(msgid)}"')
            body.append(f'msgid_plural "{po_escape(data["msgid_plural"])}"')
            for i in range(nplurals):
                body.append(f'msgstr[{i}] "{po_escape(forms[i])}"')
            body.append("")
        (out_dir / f"{lang}.po").write_text("\n".join(body), encoding="utf-8")
        print(f"Wrote {lang}.po ({len(msgids)} strings)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
