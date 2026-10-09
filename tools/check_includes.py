#!/usr/bin/env python3
"""Checks that Qt classes used in the C++ sources are covered by an include.

This project cannot always be compiled where it is edited (a Qt 6 development environment is
not always present), so this tool catches one specific class of compile error cheaply: a type
that is used in a source file but whose header is not included.

It is deliberately conservative. A type is only reported when:

  * it is a known Qt class in the table below, and
  * the file references it, and
  * none of the headers that provide it are included, and
  * the file does not include a Qt header that is documented to pull it in transitively
    (for example <QVariantMap> provides QVariantMap, and <QAbstractListModel> provides
    QModelIndex).

Exit status: 0 when nothing is missing, 1 when something is.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "src"

# Qt class -> the headers that provide it (any one is enough).
QT_TYPES: dict[str, tuple[str, ...]] = {
    "QAbstractListModel": ("QAbstractListModel",),
    "QChar": ("QChar", "QString"),
    "QDateTime": ("QDateTime",),
    "QDebug": ("QDebug",),
    "QDir": ("QDir",),
    "QDirIterator": ("QDirIterator",),
    "QFile": ("QFile",),
    "QFileInfo": ("QFileInfo",),
    "QFileInfoList": ("QFileInfo",),
    "QHash": ("QHash",),
    "QJsonArray": ("QJsonArray", "QJsonDocument"),
    "QJsonDocument": ("QJsonDocument",),
    "QJsonObject": ("QJsonObject", "QJsonDocument"),
    "QJsonParseError": ("QJsonParseError", "QJsonDocument"),
    "QMultiMap": ("QMultiMap", "QMap"),
    "QModelIndex": ("QAbstractListModel", "QModelIndex"),
    "QObject": ("QObject",),
    "QProcess": ("QProcess",),
    "QProcessEnvironment": ("QProcessEnvironment",),
    "QRegularExpression": ("QRegularExpression",),
    "QSaveFile": ("QSaveFile",),
    "QStandardPaths": ("QStandardPaths",),
    "QString": ("QString",),
    "QStringList": ("QStringList", "QString"),
    "QTextStream": ("QTextStream",),
    "QTimer": ("QTimer",),
    "QUrl": ("QUrl",),
    "QVariant": ("QVariant", "QVariantMap", "QVariantList"),
    "QVariantList": ("QVariantList", "QVariant"),
    "QVariantMap": ("QVariantMap", "QVariant"),
    "QVector": ("QVector", "QList"),
}

# Everything the shell may legitimately reference without including it directly.
IGNORED = {
    "Q_OBJECT", "Q_SIGNALS", "Q_SLOTS", "Q_INVOKABLE", "Q_PROPERTY", "Q_ENUM", "Q_UNUSED",
    "Q_CLASSINFO", "QStringLiteral", "QLatin1Char", "QLatin1String", "QCoreApplication",
    "QGuiApplication", "Qt",
}

INCLUDE_PATTERN = re.compile(r'^\s*#\s*include\s*[<"](Q[A-Za-z]+)[>"]', re.M)
TYPE_PATTERN = re.compile(r"\bQ[A-Z][A-Za-z0-9]*\b")


LOCAL_INCLUDE_PATTERN = re.compile(r'^\s*#\s*include\s*"([^"]+)"', re.M)


def direct_headers(text: str) -> set[str]:
    return {match.group(1) for match in INCLUDE_PATTERN.finditer(text)}


def local_includes(path: Path):
    """Local ("...") includes declared by a file, as paths on disk."""
    for match in LOCAL_INCLUDE_PATTERN.finditer(path.read_text(encoding="utf-8")):
        candidate = path.parent / match.group(1)
        if candidate.exists():
            yield candidate


def resolved_headers(path: Path, seen: set[Path] | None = None) -> set[str]:
    """Every Qt header available to a file, following its own local includes.

    A .cpp that includes its own header really does have everything that header provides,
    so ignoring that would report a screenful of false positives and hide the real gaps.
    """
    seen = seen or set()
    resolved = path.resolve()
    if resolved in seen:
        return set()
    seen.add(resolved)

    text = path.read_text(encoding="utf-8")
    headers = direct_headers(text)
    for included in local_includes(path):
        headers |= resolved_headers(included, seen)
    return headers


def used_types(text: str) -> set[str]:
    # Ignore comments so that prose about a class does not count as a use.
    without_block_comments = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    without_line_comments = re.sub(r"//[^\n]*", " ", without_block_comments)
    without_strings = re.sub(r'"(?:[^"\\]|\\.)*"', '""', without_line_comments)
    return set(TYPE_PATTERN.findall(without_strings))


def main() -> int:
    missing: list[str] = []
    checked = 0

    for path in sorted(SOURCE_DIR.rglob("*")):
        if path.suffix not in {".cpp", ".h", ".hpp"}:
            continue

        checked += 1
        text = path.read_text(encoding="utf-8")
        headers = resolved_headers(path)
        rel = path.relative_to(ROOT)

        # A class used only as a pointer or reference in a header can be forward declared
        # instead of included, which is a deliberate choice, not an error.
        forward_declared = set(re.findall(r"^class\s+(Q[A-Za-z0-9]+)\s*;", text, re.M))

        for type_name in sorted(used_types(text)):
            if type_name in IGNORED or type_name in forward_declared:
                continue
            providers = QT_TYPES.get(type_name)
            if providers is None:
                continue
            if headers.intersection(providers):
                continue
            missing.append(f"{rel}: uses {type_name} but includes none of "
                           f"{', '.join('<' + p + '>' for p in providers)}")

    print(f"files checked: {checked}")
    if missing:
        print(f"missing includes: {len(missing)}")
        for item in missing:
            print(f"  - {item}")
        return 1

    print("every Qt class referenced in the C++ sources is covered by an include")
    return 0


if __name__ == "__main__":
    sys.exit(main())
