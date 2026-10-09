#!/usr/bin/env python3
"""Structural verification for Project Tahoe X86.

This script checks repository consistency that can be verified WITHOUT a Qt build:

  * required files exist and are non-empty
  * every file referenced by src/shell/tahoe.qrc exists on disk
  * every relative QML import resolves to a directory that has a qmldir, and every
    file named in that qmldir exists
  * main.qml imports the shared modules and binds the Dock to real settings
  * known broken patterns are absent (they were fixed and must not come back)
  * CMake wiring required for a working build is present (AUTORCC, version define,
    install rules, CPack)
  * version strings are consistent
  * no credential-style assignments in packaging artifacts

It does NOT compile QML, link Qt, or prove the shell runs. That requires a Qt 6
development environment; see build_env.md. Exit code 0 means every check below passed.
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

failures: list[str] = []
passes = 0


def check(condition: bool, message: str) -> None:
    global passes
    if condition:
        passes += 1
    else:
        failures.append(message)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


REQUIRED_FILES = [
    "README.md",
    "CONTRIBUTING.md",
    "Makefile",
    ".gitignore",
    "build_env.md",
    "CMakeLists.txt",
    "docs/PRODUCT_SPEC.md",
    "docs/ARCHITECTURE.md",
    "docs/DESIGN_SYSTEM.md",
    "docs/FEATURE_MATRIX.md",
    "docs/SECURITY_MODEL.md",
    "docs/IMPLEMENTATION_ROADMAP.md",
    "docs/RESEARCH_SOURCES.md",
    "src/shell/CMakeLists.txt",
    "src/shell/main.cpp",
    "src/shell/tahoe.qrc",
    "src/shell/qml/main.qml",
    "src/shell/resources/org.projecttahoe.shell.desktop",
    "src/shared/tokens/DesignTokens.qml",
    "src/shared/tokens/qmldir",
    "src/shared/components/TahoeDock.qml",
    "src/shared/components/qmldir",
    "src/services/Settings.qml",
    "src/services/qmldir",
    "src/services/SettingsStore.h",
    "src/services/SettingsStore.cpp",
    "src/services/AppRegistry.h",
    "src/services/AppRegistry.cpp",
    "src/services/FileService.h",
    "src/services/FileService.cpp",
    "src/services/TrashService.h",
    "src/services/TrashService.cpp",
    "src/services/NotificationService.h",
    "src/services/NotificationService.cpp",
    "src/services/NotificationServer.h",
    "src/services/NotificationServer.cpp",
    "src/services/SearchService.h",
    "src/services/SearchService.cpp",
    "src/apps/finder/FinderWindow.qml",
    "src/apps/settings/SettingsWindow.qml",
    "src/shared/components/TahoeMenuBar.qml",
    "src/shared/components/TahoeDesktop.qml",
    "src/services/tahoe_shell.json",
    "packaging/README.md",
    "packaging/tahoe-shell.cpack",
    "packaging/release_checklist.md",
]


def check_required_files() -> None:
    for rel in REQUIRED_FILES:
        path = ROOT / rel
        check(path.exists(), f"missing file: {rel}")
        if path.exists():
            check(path.stat().st_size > 0, f"empty file: {rel}")


def check_qrc() -> None:
    qrc_path = ROOT / "src/shell/tahoe.qrc"
    try:
        tree = ET.parse(qrc_path)
    except ET.ParseError as exc:
        failures.append(f"tahoe.qrc is not valid XML: {exc}")
        return

    entries = []
    for file_node in tree.iter("file"):
        if file_node.text:
            entries.append((file_node.text.strip(), file_node.get("alias")))

    check(len(entries) >= 7, f"tahoe.qrc has too few resource entries: {len(entries)}")

    for text, alias in entries:
        source = (qrc_path.parent / text).resolve()
        check(source.exists(), f"tahoe.qrc references a missing file: {text}")

    aliases = {alias for _, alias in entries if alias}
    for required_alias in [
        "shell/qml/main.qml",
        "shared/tokens/DesignTokens.qml",
        "shared/tokens/qmldir",
        "shared/components/TahoeDock.qml",
        "shared/components/TahoeMenuBar.qml",
        "shared/components/TahoeDesktop.qml",
        "shared/components/qmldir",
        "shared/components/TahoeWindow.qml",
        "shared/components/TahoeWindowLayer.qml",
        "shared/components/TahoeSpotlight.qml",
        "shared/components/TahoeControlCenter.qml",
        "shared/components/TahoeNotificationCenter.qml",
        "shared/components/TahoeToggle.qml",
        "shared/components/TahoeSlider.qml",
        "services/Settings.qml",
        "services/qmldir",
        "apps/finder/FinderWindow.qml",
        "apps/settings/SettingsWindow.qml",
    ]:
        check(required_alias in aliases, f"tahoe.qrc missing alias: {required_alias}")


def check_qml_imports() -> None:
    """Every relative QML import must resolve to a directory with a valid qmldir."""
    for qml in (ROOT / "src").rglob("*.qml"):
        text = qml.read_text(encoding="utf-8")
        for match in re.finditer(r'^\s*import\s+"([^"]+)"', text, re.M):
            target = (qml.parent / match.group(1)).resolve()
            rel_qml = qml.relative_to(ROOT)
            check(target.is_dir(), f"{rel_qml}: import target is not a directory: {match.group(1)}")

            qmldir = target / "qmldir"
            check(qmldir.exists(), f"{rel_qml}: imported directory has no qmldir: {match.group(1)}")
            if not qmldir.exists():
                continue

            for line in qmldir.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                entry_file = line.split()[-1]
                check(
                    (target / entry_file).exists(),
                    f"{rel_qml}: {target.relative_to(ROOT)}/qmldir references missing {entry_file}",
                )


def check_tokens_modes() -> None:
    text = read("src/shared/tokens/DesignTokens.qml")
    check("property string mode" in text, "DesignTokens has no light/dark mode property")
    check("isDark" in text, "DesignTokens does not derive an isDark flag")
    check(text.count("isDark ?") >= 6, "DesignTokens does not switch palette colors by mode")



def check_services_cpp() -> None:
    store_h = read("src/services/SettingsStore.h")
    store_cpp = read("src/services/SettingsStore.cpp")
    check("QSaveFile" in store_cpp, "SettingsStore does not write atomically (QSaveFile)")
    check("XDG_CONFIG_HOME" in store_cpp, "SettingsStore does not honour XDG_CONFIG_HOME")
    check("project-tahoe/shell" in store_cpp, "SettingsStore does not use the documented config path")
    check("QJsonDocument" in store_cpp, "SettingsStore does not use JSON as documented")
    check("Q_OBJECT" in store_h, "SettingsStore is not a QObject (cannot be registered in QML)")
    check("Q_INVOKABLE QVariantMap load" in store_h, "SettingsStore::load is not QML-callable")
    check("Q_INVOKABLE bool save" in store_h, "SettingsStore::save is not QML-callable")

    # AppRegistry: launching must work from real .desktop entries, not a hardcoded list.
    registry_h = read("src/services/AppRegistry.h")
    registry_cpp = read("src/services/AppRegistry.cpp")
    check("QAbstractListModel" in registry_h, "AppRegistry is not a model")
    check("QStandardPaths" in registry_cpp,
          "AppRegistry does not resolve executables via QStandardPaths")
    check("startDetached" in registry_cpp, "AppRegistry does not start processes detached")
    for state in ["Started", "NotFound", "Failed"]:
        check(state in registry_h, f"AppRegistry is missing the {state} result state")
    check("NoDisplay" in registry_cpp, "AppRegistry does not honour NoDisplay entries")
    check("TryExec" in registry_cpp, "AppRegistry does not honour TryExec entries")
    check("XDG_DATA_DIRS" in registry_cpp, "AppRegistry ignores XDG_DATA_DIRS")
    check("lastError" in registry_h, "AppRegistry does not report why a launch failed")

    # FileService: real filesystem work with real error strings.
    files_h = read("src/services/FileService.h")
    files_cpp = read("src/services/FileService.cpp")
    for method in ["list", "locations", "makeDirectory", "rename", "copy", "move",
                   "removePermanently", "search"]:
        check(method in files_h, f"FileService is missing {method}()")
    check('QStringLiteral("error")' in files_cpp, "FileService does not return error strings")
    check("setFollowSymlinks(false)" in files_cpp, "FileService search may follow symlink loops")

    # TrashService: the freedesktop trash specification, not a private folder.
    trash_h = read("src/services/TrashService.h")
    trash_cpp = read("src/services/TrashService.cpp")
    check("freedesktop" in trash_h, "TrashService does not document the freedesktop trash spec")
    check("trashinfo" in trash_cpp, "TrashService does not write .trashinfo records")
    check("[Trash Info]" in trash_cpp, "TrashService does not write the Trash Info group")
    check("toPercentEncoding" in trash_cpp,
          "TrashService does not percent-encode the original path")
    check("DeletionDate" in trash_cpp, "TrashService does not record the deletion date")

    # NotificationService: a real model plus an honest statement of bus ownership.
    notif_h = read("src/services/NotificationService.h")
    notif_cpp = read("src/services/NotificationService.cpp")
    check("dbusStatus" in notif_h, "NotificationService does not report its bus status")
    check("registerService" in notif_cpp,
          "NotificationService does not try to own org.freedesktop.Notifications")
    check("Another notification service owns" in notif_cpp,
          "NotificationService does not report when another daemon owns the bus name")
    check("TAHOE_HAS_DBUS" in notif_cpp, "NotificationService is not guarded by TAHOE_HAS_DBUS")
    server_h = read("src/services/NotificationServer.h")
    server_cpp = read("src/services/NotificationServer.cpp")
    # The interface name is declared with Q_CLASSINFO in the header, which is what moc
    # turns into the exported D-Bus interface.
    check('Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")' in server_h,
          "NotificationServer does not declare the freedesktop notification interface")
    check("QDBusAbstractAdaptor" in server_h,
          "NotificationServer is not a D-Bus adaptor (its methods would not be exported)")
    for method in ["GetCapabilities", "Notify", "CloseNotification", "GetServerInformation"]:
        check(method in server_cpp, f"NotificationServer does not implement {method}")
    check("setAutoRelaySignals(false)" in server_cpp,
          "NotificationServer auto-relays signals it does not own")

    # The advertised capabilities must match what the shell can actually do: notification
    # bodies are rendered, notifications persist, and action buttons are not offered.
    returned = [line.strip() for line in server_cpp.splitlines()
                if "return {" in line and "QStringLiteral(\"body\")" in line]
    check(len(returned) == 1, "NotificationServer GetCapabilities does not return a list")
    if returned:
        advertised = returned[0]
        check("persistence" in advertised,
              "NotificationServer does not advertise the persistence capability it implements")
        check("actions" not in advertised and "body-markup" not in advertised,
              "NotificationServer advertises a capability the shell does not implement")

    # SearchService: results must be actionable and come from real services.
    search_h = read("src/services/SearchService.h")
    search_cpp = read("src/services/SearchService.cpp")
    check("AppRegistry" in search_h and "FileService" in search_h,
          "SearchService is not backed by the application registry and the filesystem service")
    check("settingKey" in search_cpp, "SearchService results carry no setting identifier")
    check("desktopId" in search_cpp, "SearchService results carry no application identifier")



def check_qml_does_not_touch_filesystem() -> None:
    for qml in (ROOT / "src").rglob("*.qml"):
        text = qml.read_text(encoding="utf-8")
        rel = qml.relative_to(ROOT)
        check("XMLHttpRequest" not in text, f"{rel} performs file/network I/O in QML")
        check("FileIO" not in text, f"{rel} uses a QML file-I/O injection")


# QML types that require a specific import. Catching this structurally is worthwhile:
# a missing import compiles fine but makes the shell fail to load at runtime.
REQUIRED_IMPORTS = {
    "ApplicationWindow": "import QtQuick.Controls",
    "Popups": "import QtQuick.Controls",
    "Label": "import QtQuick.Controls",
    "Image": "import QtQuick",
    "MouseArea": "import QtQuick",
    "Repeater": "import QtQuick",
    "Timer": "import QtQuick",
}


def check_type_imports() -> None:
    from collections import Counter

    for qml in (ROOT / "src").rglob("*.qml"):
        text = qml.read_text(encoding="utf-8")
        rel = qml.relative_to(ROOT)
        imports = [line.strip() for line in text.splitlines() if line.strip().startswith("import ")]

        for type_name, needed in REQUIRED_IMPORTS.items():
            pattern = r"(?<![.\w])" + re.escape(type_name) + r"\s*\{"
            if re.search(pattern, text):
                check(
                    needed in imports,
                    f"{rel}: uses {type_name} but is missing '{needed}'",
                )


def check_singleton_declared() -> None:
    qmldir = read("src/shared/tokens/qmldir")
    check(
        re.search(r"^singleton\s+DesignTokens\s+1\.0\s+DesignTokens\.qml$", qmldir, re.M) is not None,
        "tokens qmldir does not declare the DesignTokens singleton",
    )
    check(
        "pragma Singleton" in read("src/shared/tokens/DesignTokens.qml"),
        "DesignTokens.qml is missing 'pragma Singleton'",
    )



def check_main_qml() -> None:
    text = read("src/shell/qml/main.qml")
    for module in ['"../../shared/tokens"', '"../../shared/components"', '"../../services"']:
        check(module in text, f"main.qml missing import {module}")

    check("DesignTokens." in text, "main.qml never uses the shared design tokens")
    check("TahoeDock {" in text, "main.qml does not instantiate TahoeDock")
    check("TahoeWindowLayer {" in text, "main.qml does not instantiate the window layer")
    check("TahoeSpotlight {" in text, "main.qml does not instantiate Spotlight")
    check("TahoeControlCenter {" in text, "main.qml does not instantiate the Control Center")
    check("TahoeNotificationCenter {" in text,
          "main.qml does not instantiate the Notification Center")

    # Settings is a QML singleton shared with the hosted applications.
    check("Settings {" not in text,
          "main.qml instantiates Settings again instead of using the shared singleton")

    for binding in [
        "Settings.dockMagnification",
        "Settings.dockMagnificationStrength",
        "Settings.dockAutoHide",
        "Settings.reduceMotion",
        "Settings.windowCornerRadius",
        "Settings.showWindowTitleBars",
    ]:
        check(binding in text, f"main.qml missing binding: {binding}")

    check("TahoeMenuBar {" in text, "main.qml does not use TahoeMenuBar")
    check("TahoeDesktop {" in text, "main.qml does not use TahoeDesktop")
    check("import Tahoe.Services 1.0" in text, "main.qml does not import the C++ service module")
    check("SettingsStore.load()" in text, "main.qml never loads persisted settings")
    check("SettingsStore.save(" in text, "main.qml never saves settings")
    check("Settings.applyConfig(" in text, "main.qml never applies loaded settings")
    check("Settings.collectConfig()" in text, "main.qml never collects settings to persist")
    # QML handles the persistedValueChanged signal through the onPersistedValueChanged slot.
    check("onPersistedValueChanged" in text,
          "main.qml does not react to the shared settings model changing")
    check("AppRegistry.launchDesktopId(" in text,
          "main.qml does not launch applications through the registry")
    check("AppRegistry.Started" in text, "main.qml does not handle the Started result")
    check("AppRegistry.lastError" in text, "main.qml does not surface launch failures")
    check("AppRegistry.openPath(" in text, "main.qml never opens files with the default handler")
    check("windowLayer.isHosted(" in text,
          "main.qml does not distinguish hosted applications from installed ones")
    check("Shortcut {" in text, "main.qml has no keyboard shortcuts")
    check("Ctrl+Space" in text, "Spotlight is not reachable by keyboard")
    check("DesignTokens.mode = Settings.appearanceMode" in text,
          "main.qml does not drive the theme from settings")
    check("console.log" not in text, "main.qml logs to the console instead of reporting to the UI")
    check("Timeline" not in text, "main.qml uses a placeholder animation stub again")

    # Regressions that were fixed and must not return.
    check("appearaceMode" not in text, "main.qml contains the 'appearaceMode' typo again")
    check("reduceMotion: root.reduceMotion" not in text,
          "main.qml contains the self-referential reduceMotion binding again")
    check(re.search(r"anchors\.top:\s*header\.bottom", text) is None,
          "main.qml anchors content across items again (header.bottom)")



def check_qml_service_members() -> None:
    """Every member QML reads from a C++ service must actually be exposed.

    A C++ getter with no Q_PROPERTY and no Q_INVOKABLE is invisible to QML: the code compiles,
    the shell loads, and the binding silently fails at runtime. This checks each service
    header for its exposed properties, invokable methods, and enumerated values, then checks
    every `Service.member` reference in the QML against that list.
    """
    services = {
        "SettingsStore": "src/services/SettingsStore.h",
        "AppRegistry": "src/services/AppRegistry.h",
        "FileService": "src/services/FileService.h",
        "TrashService": "src/services/TrashService.h",
        "NotificationService": "src/services/NotificationService.h",
        "SearchService": "src/services/SearchService.h",
    }

    exposed: dict[str, dict[str, set[str]]] = {}

    for name, header in services.items():
        text = read(header)

        properties = set(re.findall(r"Q_PROPERTY\(\s*[\w:<>,\s*&]+?\s+(\w+)\s+READ", text))
        invokables = set(re.findall(r"Q_INVOKABLE\s+[\w:<>,\s*&]+?\b(\w+)\s*\(", text))

        # Q_ENUM values are visible from QML, e.g. AppRegistry.Started.
        enumerated: set[str] = set()
        for body in re.findall(r"enum\s+\w+\s*\{([^}]*)\}", text):
            for entry in body.split(","):
                entry = entry.strip()
                if entry:
                    enumerated.add(entry.split("=")[0].strip())

        exposed[name] = {"property": properties, "invokable": invokables,
                         "enum": enumerated}

    for qml in sorted((ROOT / "src").rglob("*.qml")):
        raw = qml.read_text(encoding="utf-8")
        rel = qml.relative_to(ROOT)

        # Strip comments first: the file paths in doc comments (SettingsStore.h) would
        # otherwise look like member accesses.
        text = re.sub(r"/\*.*?\*/", " ", raw, flags=re.S)
        text = re.sub(r"//[^\n]*", " ", text)

        for match in re.finditer(r"\b(" + "|".join(services) + r")\.([A-Za-z_]\w*)", text):
            service, member = match.group(1), match.group(2)
            available = exposed[service]
            is_call = match.end() < len(text) and text[match.end()] == "("

            if is_call:
                check(
                    member in available["invokable"],
                    f"{rel}: calls {service}.{member}() which is not Q_INVOKABLE in C++",
                )
            else:
                check(
                    member in available["property"] or member in available["enum"],
                    f"{rel}: reads {service}.{member} which is neither a Q_PROPERTY nor a "
                    f"Q_ENUM value in C++",
                )


def check_phase2_components() -> None:
    """The Phase 2 surface: window management, panels, and the hosted applications."""

    # --- Window frame: real chrome behaviour, not decoration ---
    window = read("src/shared/components/TahoeWindow.qml")
    for fn in ["beginDrag", "continueDrag", "beginResize", "continueResize", "applyGeometry",
               "zoomToFill", "restoreFromZoom"]:
        check(f"function {fn}" in window, f"TahoeWindow is missing {fn}()")
    check(window.count("beginResize(") >= 9,
          "TahoeWindow does not wire up all eight resize handles")
    for signal in ["closeRequested", "minimizeRequested", "zoomRequested", "focusRequested"]:
        check(f"signal {signal}" in window, f"TahoeWindow is missing the {signal} signal")
    check("clampX" in window and "clampY" in window,
          "TahoeWindow does not clamp a dragged window inside its container")

    # --- Window layer: real stacking and focus ---
    layer = read("src/shared/components/TahoeWindowLayer.qml")
    for fn in ["openWindow", "closeWindow", "minimizeWindow", "restoreWindow", "raiseWindow",
               "toggleWindow", "topVisibleAppId", "rowFor"]:
        check(f"function {fn}" in layer, f"TahoeWindowLayer is missing {fn}()")
    check("appSources" in layer, "TahoeWindowLayer has no application source map")
    check("compositor" in layer,
          "TahoeWindowLayer does not state the boundary with the compositor")
    check("TahoeWindow {" in layer, "TahoeWindowLayer does not instantiate window frames")

    # Every hosted application source must exist on disk and inside the qrc bundle, or the
    # shell would show a broken window at runtime.
    qrc = read("src/shell/tahoe.qrc")
    for match in re.finditer(r'"(qrc:/[^"]+\.qml)"', layer):
        alias = match.group(1).replace("qrc:/", "")
        check((ROOT / "src" / alias).exists(),
              f"TahoeWindowLayer points at a missing application: {match.group(1)}")
        check(f'alias="{alias}"' in qrc,
              f"TahoeWindowLayer application is not bundled in tahoe.qrc: {alias}")

    # --- Spotlight: real search, keyboard driven ---
    spotlight = read("src/shared/components/TahoeSpotlight.qml")
    check("SearchService.search(" in spotlight, "Spotlight does not search through SearchService")
    for signal in ["applicationChosen", "fileChosen", "settingChosen"]:
        check(f"signal {signal}" in spotlight, f"Spotlight does not report {signal}")
    check("Keys.onEscapePressed" in spotlight, "Spotlight cannot be dismissed with Escape")
    check("Keys.onReturnPressed" in spotlight, "Spotlight cannot be activated with Return")

    # --- Control Center: writes the shared settings model ---
    control = read("src/shared/components/TahoeControlCenter.qml")
    for key in ["appearanceMode", "dockIconSize", "dockMagnification", "dockAutoHide",
                "reduceMotion"]:
        check(f"Settings.{key}" in control, f"Control Center does not expose {key}")
    check("not implemented yet" in control,
          "Control Center does not state which system controls are missing")

    # --- Notification Center: real model, honest empty state ---
    center = read("src/shared/components/TahoeNotificationCenter.qml")
    check("NotificationService.dismissAll()" in center, "Notification Center cannot clear all")
    check("NotificationService.dismiss(" in center, "Notification Center cannot dismiss one item")
    check("dbusStatus" in center,
          "Notification Center does not explain when other applications cannot reach it")

    # --- Finder: real filesystem and trash operations ---
    finder = read("src/apps/finder/FinderWindow.qml")
    for api in ["FileService.list(", "FileService.makeDirectory(", "FileService.rename(",
                "FileService.parentPath(", "FileService.isDirectory(",
                "TrashService.trash(", "TrashService.restore(", "TrashService.empty(",
                "FileService.locations()", "AppRegistry.openPath("]:
        check(api in finder, f"Finder does not use {api}")
    check("messageIsError" in finder, "Finder does not distinguish errors from normal messages")

    # --- Settings app: real persistence, no controls for unimplemented features ---
    settings_app = read("src/apps/settings/SettingsWindow.qml")
    check("SettingsStore.configPath" in settings_app, "Settings app does not show the config path")
    check("Settings.applyConfig(" in settings_app, "Settings app cannot reload preferences")
    check("NotificationService.dbusStatus" in settings_app,
          "Settings app does not report the notification service status")
    check("not offered" in settings_app and "bottom edge only" in settings_app,
          "Settings app does not state that Dock position is unimplemented")
    check("dockPosition =" not in settings_app,
          "Settings app exposes a Dock position control it cannot honour")

    # --- Menu bar: real notification count, honest dimming ---
    menubar = read("src/shared/components/TahoeMenuBar.qml")
    check("unreadNotifications" in menubar, "Menu bar does not show the unread notification count")
    check("notificationServiceReady" in menubar,
          "Menu bar does not indicate when it is not the notification server")
    check("signal notificationsRequested" in menubar,
          "Menu bar cannot open the Notification Center")
    check("signal controlCenterRequested" in menubar, "Menu bar cannot open the Control Center")


def check_dock() -> None:
    text = read("src/shared/components/TahoeDock.qml")

    for fn in ["addPinnedItem", "removePinnedItem", "setRunningItems", "currentItems", "isRunning"]:
        check(f"function {fn}" in text, f"TahoeDock missing function: {fn}")

    check("signal itemActivated" in text, "TahoeDock missing itemActivated signal")
    check("MouseArea" in text, "TahoeDock has no mouse handling; tiles would be dead")
    check("onClicked: root.itemActivated(modelData)" in text, "TahoeDock tile click is not wired")
    check("handleHeight" in text and "revealArea" in text, "TahoeDock auto-hide reveal logic missing")
    check("import \"../tokens\"" in text, "TahoeDock does not consume the shared tokens")
    check("DesignTokens." in text, "TahoeDock never references DesignTokens")

    # Regressions that were fixed and must not return.
    check("pinnedItems.push(" not in text, "TahoeDock mutates pinnedItems in place again (no notify)")
    check("property bool visible" not in text, "TahoeDock shadows the built-in 'visible' property again")
    check("delegate: TahoeDockItem" not in text, "TahoeDock uses an invalid Component-id delegate again")



def check_settings() -> None:
    text = read("src/services/Settings.qml")
    check("XDG_CONFIG_HOME" in text, "Settings.qml no longer documents the XDG config location")
    check("settings.json" in text, "Settings.qml no longer documents the settings file name")
    check("Qt.binding(" not in text, "Settings.qml contains the broken Qt.binding() stub again")
    check("function collectConfig" in text, "Settings.qml missing collectConfig()")
    check("function applyConfig" in text, "Settings.qml missing applyConfig()")
    check("function defaultConfig" not in text,
          "Settings.qml still exposes the superseded defaultConfig()")
    check("pragma Singleton" in text, "Settings.qml is not a singleton")
    check("signal persistedValueChanged" in text,
          "Settings.qml does not announce changes to persisted values")
    check("suppressChangeNotifications" in text,
          "Settings.qml does not suppress notifications while applying a loaded config")

    # requestedSection is navigation state and must never reach the config file.
    config_body = text.split("function collectConfig")[1].split("function applyConfig")[0]
    check("requestedSection" not in config_body,
          "Settings.qml persists requestedSection, which is transient navigation state")

    # The services qmldir must declare the singleton, or the shell and the applications it
    # hosts would each get their own copy of the settings model.
    services_qmldir = read("src/services/qmldir")
    check(
        re.search(r"^singleton\s+Settings\s+1\.0\s+Settings\.qml$", services_qmldir, re.M)
        is not None,
        "services qmldir does not declare the Settings singleton",
    )




def check_main_cpp() -> None:
    text = read("src/shell/main.cpp")
    check("qrc:/shell/qml/main.qml" in text, "main.cpp does not load the bundled main.qml")
    check("#ifndef TAHOE_VERSION" in text, "main.cpp lost the TAHOE_VERSION fallback")
    check("loadFromModule" not in text,
          "main.cpp calls loadFromModule for a module that is not registered")
    check("../../qml" not in text, "main.cpp contains the broken relative import path again")
    check("qmlRegisterSingletonInstance" in text, "main.cpp does not register the C++ services")
    check('"Tahoe.Services"' in text, "main.cpp does not register the Tahoe.Services module")

    registrations = {
        "SettingsStore": "settingsStore",
        "AppRegistry": "appRegistry",
        "FileService": "fileService",
        "TrashService": "trashService",
        "NotificationService": "notificationService",
        "SearchService": "searchService",
    }
    # Whitespace-normalised, because a call may be wrapped across lines.
    flat = " ".join(text.split())
    for service, instance in registrations.items():
        check(f'#include "{service}.h"' in text, f"main.cpp does not include {service}.h")
        check(f'"{service}", &{instance}' in flat,
              f"main.cpp does not register the {service} singleton as &{instance}")
        # Either default-constructed or constructed with arguments (SearchService needs the
        # registry and the filesystem service).
        check(f"{service} {instance};" in flat or f"{service} {instance}(" in flat,
              f"main.cpp does not construct a single {service} instance named {instance}")

    # SearchService holds pointers to the registry and the filesystem service, so those must
    # be constructed before it and destroyed after it.
    check("SearchService searchService(&appRegistry, &fileService)" in text,
          "main.cpp does not wire SearchService to the registry and the filesystem service")
    check(text.index("AppRegistry appRegistry") < text.index("SearchService searchService"),
          "the registry is created after SearchService, which holds a pointer to it")
    check("AppLauncher" not in text, "main.cpp still refers to the retired AppLauncher service")




def check_cmake() -> None:
    root = read("CMakeLists.txt")
    shell = read("src/shell/CMakeLists.txt")

    check("project(tahoe-x86 VERSION 0.1.0" in root, "root CMakeLists version/name mismatch")
    check("include(CPack)" in root, "root CMakeLists missing CPack packaging block")
    check("AUTORCC ON" in shell, "shell CMakeLists missing AUTORCC (resources would not compile)")
    check("AUTOMOC ON" in shell,
          "shell CMakeLists missing AUTOMOC (Q_OBJECT classes would not compile)")
    check('TAHOE_VERSION="${PROJECT_VERSION}"' in shell,
          "shell CMakeLists missing the version define")
    check("install(TARGETS tahoe-shell" in shell, "shell CMakeLists missing install rules")
    check("tahoe.qrc" in shell, "shell CMakeLists does not compile the resource file")

    for source in ["AppRegistry.cpp", "FileService.cpp", "TrashService.cpp",
                   "NotificationService.cpp", "NotificationServer.cpp", "SearchService.cpp"]:
        check(source in shell, f"shell CMakeLists does not build {source}")

    check("AppLauncher.cpp" not in shell, "shell CMakeLists still builds the retired AppLauncher")

    # DBus must stay optional, with an explicit warning when it is absent.
    check("QUIET COMPONENTS DBus" in shell, "shell CMakeLists does not probe for Qt6::DBus")
    check("TAHOE_HAS_DBUS" in shell, "shell CMakeLists does not define TAHOE_HAS_DBUS")
    check("message(WARNING" in shell, "shell CMakeLists does not warn when DBus is missing")



def check_version_consistency() -> None:
    root = read("CMakeLists.txt")
    cpack_note = read("packaging/tahoe-shell.cpack")
    check("VERSION 0.1.0" in root, "project version is not 0.1.0 in CMake")
    check("0.1.0" in cpack_note, "packaging note does not state the current version")


def check_service_contract() -> None:
    try:
        data = json.loads(read("src/services/tahoe_shell.json"))
    except json.JSONDecodeError as exc:
        failures.append(f"tahoe_shell.json is not valid JSON: {exc}")
        return
    check(isinstance(data.get("components"), list), "tahoe_shell.json has no components list")

    states = json.dumps(data.get("contract", {}).get("states", []))
    for state in ["Available", "Unavailable", "Failed", "RequiresPermission", "RequiresConfiguration"]:
        check(state in states, f"service contract is missing state: {state}")


def check_no_credentials() -> None:
    pattern = re.compile(r"(password|secret|token|client_secret)\s*=\s*\S", re.I)
    for rel in ["packaging/README.md", "packaging/tahoe-shell.cpack", "packaging/release_checklist.md"]:
        check(
            pattern.search(read(rel)) is None,
            f"{rel} contains a credential-style assignment",
        )


def main() -> int:
    check_required_files()
    check_qrc()
    check_qml_imports()
    check_singleton_declared()
    check_type_imports()
    check_tokens_modes()
    check_services_cpp()
    check_qml_does_not_touch_filesystem()
    check_main_qml()
    check_dock()
    check_phase2_components()
    check_qml_service_members()
    check_settings()
    check_main_cpp()
    check_cmake()
    check_version_consistency()
    check_service_contract()
    check_no_credentials()

    print(f"checks passed: {passes}")
    if failures:
        print(f"checks FAILED: {len(failures)}")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("all structural checks passed")
    print("note: this does not compile QML or prove the shell runs; see build_env.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
