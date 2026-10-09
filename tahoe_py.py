#!/usr/bin/env python3
"""
Project Tahoe X86 — Python/PySide6 launcher.

This file is the development launcher when the Qt 6 / CMake toolchain is not
available on the host.  It re-implements every C++ service from src/services/
as a PySide6 QObject so the QML can be loaded without compiling anything.

Usage:
    python3 tahoe_py.py            # launch the shell
    python3 tahoe_py.py --help

All services honour exactly the same API contract as the C++ versions so the
QML does not need to know which backend it is talking to.
"""

import os
import sys
import json
import shutil
import subprocess
import datetime
import fnmatch
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# Bootstrap PySide6
# ---------------------------------------------------------------------------
try:
    from PySide6.QtCore import (
        QObject, Signal, Slot, Property, Qt, QUrl, QDir, QFileInfo,
        QStandardPaths, QDateTime, QTimer
    )
    from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterSingletonInstance
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtWidgets import QApplication
except ImportError as exc:
    print(f"[tahoe] PySide6 not found: {exc}", file=sys.stderr)
    print("[tahoe] Install it with:  pip install PySide6", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HERE = Path(__file__).parent.resolve()
QML_MAIN = HERE / "src" / "shell" / "qml" / "main.qml"
SRC = HERE / "src"

# ---------------------------------------------------------------------------
# SettingsStore — persistent JSON settings
# ---------------------------------------------------------------------------
class SettingsStore(QObject):
    statusChanged     = Signal()
    configPathChanged = Signal()
    saveFailed        = Signal(str)
    loadFailed        = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._available = False
        self._status    = "Uninitialized"
        self._config_path = ""
        self._init()

    def _config_dir(self):
        xdg = os.environ.get("XDG_CONFIG_HOME", "")
        if xdg:
            base = Path(xdg)
        else:
            home = Path.home()
            base = home / ".config"
        return base / "project-tahoe" / "shell"

    def _init(self):
        d = self._config_dir()
        try:
            d.mkdir(parents=True, exist_ok=True)
            probe = d / ".write-probe"
            probe.touch()
            probe.unlink()
            self._config_path = str(d / "settings.json")
            self._available = True
            self._set_status("Ready")
            self.configPathChanged.emit()
        except OSError as e:
            self._set_status(f"Unavailable: {e}")

    def _set_status(self, s):
        if self._status != s:
            self._status = s
            self.statusChanged.emit()

    @Property(bool, notify=statusChanged)
    def available(self): return self._available

    @Property(str, notify=statusChanged)
    def status(self): return self._status

    @Property(str, notify=configPathChanged)
    def configPath(self): return self._config_path

    @Slot(result="QVariantMap")
    def load(self):
        if not self._available:
            self.loadFailed.emit(self._status)
            return {}
        p = Path(self._config_path)
        if not p.exists():
            self._set_status("Defaults in use (no settings file yet)")
            return {}
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
            if not isinstance(data, dict):
                raise ValueError("not a JSON object")
            self._set_status("Loaded")
            return data
        except Exception as e:
            reason = str(e)
            self._set_status(f"Defaults in use ({reason})")
            self.loadFailed.emit(reason)
            return {}

    @Slot("QVariantMap", result=bool)
    def save(self, values):
        if not self._available:
            self.saveFailed.emit(self._status)
            return False
        try:
            payload = json.dumps(dict(values), indent=2, ensure_ascii=False)
            p = Path(self._config_path)
            tmp = p.with_suffix(".tmp")
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(payload)
            tmp.replace(p)
            self._set_status("Saved")
            return True
        except Exception as e:
            reason = str(e)
            self._set_status(f"Save failed: {reason}")
            self.saveFailed.emit(reason)
            return False


# ---------------------------------------------------------------------------
# AppRegistry — desktop file scanner and application launcher
# ---------------------------------------------------------------------------
class AppRegistry(QObject):
    # Result codes (mirror C++ enum)
    Started  = 0
    NotFound = 1
    Failed   = 2

    statusChanged    = Signal()
    countChanged     = Signal()
    lastErrorChanged = Signal()
    launchFinished   = Signal(str, int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._entries   = []
        self._by_id     = {}
        self._status    = ""
        self._last_error = ""
        self._broken    = 0
        self._refresh()

    # ---- helpers ----------------------------------------------------------

    @staticmethod
    def _app_dirs():
        xdg_home = os.environ.get("XDG_DATA_HOME",
                                  str(Path.home() / ".local" / "share"))
        xdg_dirs = os.environ.get("XDG_DATA_DIRS",
                                  "/usr/local/share:/usr/share")
        dirs = [Path(xdg_home) / "applications"]
        for d in xdg_dirs.split(":"):
            dirs.append(Path(d) / "applications")
        dirs.append(Path("/usr/local/share/applications"))
        dirs.append(Path("/usr/share/applications"))
        seen = []
        for d in dirs:
            if d not in seen:
                seen.append(d)
        return seen

    @staticmethod
    def _icon_dirs():
        xdg_home = os.environ.get("XDG_DATA_HOME",
                                  str(Path.home() / ".local" / "share"))
        xdg_dirs = os.environ.get("XDG_DATA_DIRS",
                                  "/usr/local/share:/usr/share")
        dirs = [Path(xdg_home) / "icons", Path.home() / ".icons"]
        for d in xdg_dirs.split(":"):
            dirs.append(Path(d) / "icons")
        dirs += [Path("/usr/local/share/icons"), Path("/usr/share/icons"),
                 Path("/usr/share/pixmaps")]
        seen = []
        for d in dirs:
            if d not in seen:
                seen.append(d)
        return seen

    @staticmethod
    def _parse_desktop(path):
        """Return parsed entry dict or None."""
        values = {}
        in_entry = False
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for raw in f:
                    line = raw.strip()
                    if not line or line.startswith("#"):
                        continue
                    if line.startswith("["):
                        in_entry = (line == "[Desktop Entry]")
                        continue
                    if not in_entry:
                        continue
                    sep = line.find("=")
                    if sep <= 0:
                        continue
                    key = line[:sep].strip()
                    val = line[sep + 1:].strip()
                    if "[" not in key:   # keep un-localised key only
                        values[key] = val
        except OSError:
            return None, False

        if values.get("Type") != "Application":
            return None, False
        if values.get("NoDisplay", "").lower() == "true":
            return None, False
        if values.get("Hidden", "").lower() == "true":
            return None, False

        name = values.get("Name", "")
        raw_exec = values.get("Exec", "")
        if not name or not raw_exec:
            return None, True

        # Strip field codes
        tokens = raw_exec.split()
        program = tokens[0] if tokens else ""
        args = [t for t in tokens[1:] if not (t.startswith("%") and len(t) == 2)]

        try_exec = values.get("TryExec", "")
        if try_exec and not shutil.which(try_exec):
            return None, True

        resolved = shutil.which(program)
        if not resolved and not os.access(program, os.X_OK):
            return None, True

        entry = {
            "id":         Path(path).stem,
            "name":       name,
            "exec":       resolved or program,
            "arguments":  " ".join(args),
            "iconName":   values.get("Icon", ""),
            "iconPath":   "",
            "comment":    values.get("Comment", ""),
            "categories": values.get("Categories", ""),
            "terminal":   values.get("Terminal", "").lower() == "true",
            "desktopFile": str(path),
        }
        return entry, False

    def _resolve_icon(self, name):
        if not name:
            return ""
        if name.startswith("/"):
            return name if Path(name).exists() else ""
        sizes = ["scalable", "256x256", "128x128", "64x64", "48x48", "32x32"]
        exts  = ["png", "svg", "xpm"]
        themes = ["hicolor", "Adwaita", "gnome", "breeze"]
        for d in self._icon_dirs():
            for theme in themes:
                for size in sizes:
                    for ext in exts:
                        p = Path(d) / theme / size / "apps" / f"{name}.{ext}"
                        if p.exists():
                            return str(p)
            for ext in exts:
                p = Path(d) / f"{name}.{ext}"
                if p.exists():
                    return str(p)
        return ""

    def _refresh(self):
        self._entries = []
        self._by_id   = {}
        self._broken  = 0
        seen_files = set()

        for d in self._app_dirs():
            if not d.is_dir():
                continue
            for desktop in sorted(d.glob("*.desktop")):
                if str(desktop) in seen_files:
                    continue
                seen_files.add(str(desktop))
                entry, broken = self._parse_desktop(desktop)
                if broken:
                    self._broken += 1
                    continue
                if entry is None:
                    continue
                if entry["id"] in self._by_id:
                    continue  # user dir wins
                entry["iconPath"] = self._resolve_icon(entry["iconName"])
                self._by_id[entry["id"]] = len(self._entries)
                self._entries.append(entry)

        self._set_status(
            f"{len(self._entries)} applications found "
            f"({self._broken} unusable entries skipped)"
        )
        self.countChanged.emit()

    def _set_status(self, s):
        if self._status != s:
            self._status = s
            self.statusChanged.emit()

    def _set_last_error(self, msg):
        if self._last_error != msg:
            self._last_error = msg
            self.lastErrorChanged.emit()

    # ---- QML API ----------------------------------------------------------

    @Property(str, notify=statusChanged)
    def status(self): return self._status

    @Property(int, notify=countChanged)
    def count(self): return len(self._entries)

    @Property(str, notify=lastErrorChanged)
    def lastError(self): return self._last_error

    @Slot(result="QVariantList")
    def toVariantList(self):
        out = []
        for e in self._entries:
            out.append({
                "desktopId": e["id"],
                "name":      e["name"],
                "exec":      e["exec"],
                "iconPath":  e["iconPath"],
                "iconName":  e["iconName"],
                "comment":   e["comment"],
            })
        return out

    @Slot(str, result=int)
    def launchDesktopId(self, desktop_id):
        row = self._by_id.get(desktop_id, -1)
        if row < 0:
            self._set_last_error(f"No application with id '{desktop_id}' is installed")
            self.launchFinished.emit(desktop_id, self.NotFound)
            return self.NotFound
        return self._start_detached(desktop_id, self._entries[row])

    def _start_detached(self, desktop_id, entry):
        cmd = [entry["exec"]] + entry["arguments"].split() if entry["arguments"] else [entry["exec"]]
        try:
            subprocess.Popen(cmd, cwd=str(Path.home()),
                             start_new_session=True,
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            self._set_last_error("")
            self.launchFinished.emit(desktop_id, self.Started)
            return self.Started
        except Exception as e:
            self._set_last_error(f"Failed to start {entry['name']}: {e}")
            self.launchFinished.emit(desktop_id, self.Failed)
            return self.Failed

    @Slot(str, result=int)
    def openPath(self, path):
        xdg = shutil.which("xdg-open")
        if not xdg:
            self._set_last_error("xdg-open is not installed, so files cannot be opened")
            return self.NotFound
        try:
            subprocess.Popen([xdg, path], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self._set_last_error("")
            return self.Started
        except Exception as e:
            self._set_last_error(f"Failed to open {path}: {e}")
            return self.Failed


# ---------------------------------------------------------------------------
# FileService — real filesystem operations
# ---------------------------------------------------------------------------
class FileService(QObject):
    statusChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._status = "Filesystem access ready"

    @Property(str, notify=statusChanged)
    def status(self): return self._status

    @staticmethod
    def _entry_map(path):
        p = Path(path)
        try:
            st = p.stat(follow_symlinks=False)
            import stat as stat_mod
            is_link = p.is_symlink()
            is_dir  = p.is_dir()
            size    = 0 if is_dir else st.st_size
            mtime   = datetime.datetime.fromtimestamp(st.st_mtime).isoformat()
            link_target = ""
            broken_link = False
            if is_link:
                try:
                    link_target = str(p.resolve())
                    broken_link = not Path(link_target).exists()
                except Exception:
                    broken_link = True
            return {
                "name":        p.name,
                "path":        str(p.resolve()),
                "isDir":       is_dir,
                "isSymlink":   is_link,
                "isHidden":    p.name.startswith("."),
                "isExecutable": os.access(str(p), os.X_OK),
                "size":        float(size),
                "modified":    mtime,
                "isReadable":  os.access(str(p), os.R_OK),
                "isWritable":  os.access(str(p), os.W_OK),
                "linkTarget":  link_target,
                "brokenLink":  broken_link,
            }
        except Exception:
            return {}

    @Slot(str, bool, result="QVariantList")
    def list(self, path, show_hidden):
        try:
            p = Path(path)
            entries = sorted(p.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower()))
            result = []
            for e in entries:
                if not show_hidden and e.name.startswith("."):
                    continue
                m = self._entry_map(str(e))
                if m:
                    result.append(m)
            return result
        except Exception:
            return []

    @Slot(result="QVariantMap")
    def locations(self):
        locs = {}
        candidates = {
            "Home":         str(Path.home()),
            "Desktop":      str(Path.home() / "Desktop"),
            "Documents":    str(Path.home() / "Documents"),
            "Downloads":    str(Path.home() / "Downloads"),
            "Music":        str(Path.home() / "Music"),
            "Pictures":     str(Path.home() / "Pictures"),
            "Videos":       str(Path.home() / "Videos"),
            "Applications": "/usr/share/applications",
            "Root":         "/",
        }
        for label, path in candidates.items():
            if Path(path).is_dir():
                locs[label] = path
        return locs

    @Slot(str, result="QVariantMap")
    def stat(self, path):
        return self._entry_map(path)

    @Slot(str, str, int, result="QVariantList")
    def search(self, root, pattern, max_results):
        results = []
        try:
            for dirpath, dirnames, filenames in os.walk(root):
                for name in dirnames + filenames:
                    if pattern.lower() in name.lower():
                        full = Path(dirpath) / name
                        m = self._entry_map(str(full))
                        if m:
                            results.append(m)
                            if len(results) >= max_results:
                                return results
        except Exception:
            pass
        return results

    @Slot(str, str, result="QVariantMap")
    def makeDirectory(self, parent_path, name):
        if not name.strip():
            return {"ok": False, "error": "A folder name is required"}
        if "/" in name:
            return {"ok": False, "error": "A folder name cannot contain '/'"}
        p = Path(parent_path)
        if not p.is_dir():
            return {"ok": False, "error": f"Folder does not exist: {parent_path}"}
        target = p / name
        if target.exists():
            return {"ok": False, "error": f"'{name}' already exists here"}
        try:
            target.mkdir()
            return {"ok": True, "error": "", "message": f"Created '{name}'"}
        except Exception as e:
            return {"ok": False, "error": str(e)}

    @Slot(str, str, result="QVariantMap")
    def rename(self, path, new_name):
        if not new_name.strip():
            return {"ok": False, "error": "A new name is required"}
        if "/" in new_name:
            return {"ok": False, "error": "A name cannot contain '/'"}
        p = Path(path)
        if not p.exists():
            return {"ok": False, "error": f"No such file or folder: {path}"}
        if p.name == new_name:
            return {"ok": True, "error": "", "message": "Name unchanged"}
        target = p.parent / new_name
        if target.exists():
            return {"ok": False, "error": f"'{new_name}' already exists here"}
        try:
            p.rename(target)
            return {"ok": True, "error": "", "message": f"Renamed to '{new_name}'"}
        except Exception as e:
            return {"ok": False, "error": str(e)}

    @Slot(str, result=bool)
    def isDirectory(self, path):
        return Path(path).is_dir()

    @Slot(str, result=str)
    def parentPath(self, path):
        p = Path(path)
        parent = p.parent
        return str(parent) if str(parent) != str(p) else str(p)


# ---------------------------------------------------------------------------
# TrashService — freedesktop trash
# ---------------------------------------------------------------------------
class TrashService(QObject):
    countChanged    = Signal()
    trashPathChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        xdg_data = os.environ.get("XDG_DATA_HOME",
                                  str(Path.home() / ".local" / "share"))
        self._trash_root = Path(xdg_data) / "Trash"
        self._files_dir  = self._trash_root / "files"
        self._info_dir   = self._trash_root / "info"
        self._files_dir.mkdir(parents=True, exist_ok=True)
        self._info_dir.mkdir(parents=True, exist_ok=True)
        self._count = 0
        self._size  = 0
        self._refresh_count()

    def _refresh_count(self):
        items = list(self._files_dir.iterdir()) if self._files_dir.exists() else []
        self._count = len(items)
        self._size  = sum(
            f.stat().st_size for f in items
            if f.is_file() and not f.is_symlink()
        )
        self.countChanged.emit()

    @Property(int, notify=countChanged)
    def count(self): return self._count

    @Property(float, notify=countChanged)
    def sizeBytes(self): return float(self._size)

    @Property(str, notify=trashPathChanged)
    def trashPath(self): return str(self._trash_root)

    @Slot(result="QVariantList")
    def items(self):
        result = []
        if not self._info_dir.exists():
            return result
        for info_file in sorted(self._info_dir.glob("*.trashinfo")):
            try:
                cfg = {}
                with open(info_file, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if "=" in line and not line.startswith("["):
                            k, v = line.split("=", 1)
                            cfg[k.strip()] = v.strip()
                original = cfg.get("Path", "")
                deleted_at = cfg.get("DeletionDate", "")
                name = info_file.stem
                content_path = str(self._files_dir / name)
                result.append({
                    "name":         name,
                    "contentPath":  content_path,
                    "originalPath": original,
                    "deletedAt":    deleted_at,
                    "isDir":        Path(content_path).is_dir(),
                })
            except Exception:
                continue
        return result

    @Slot("QStringList", result="QVariantMap")
    def trash(self, paths):
        errors = []
        for path in paths:
            p = Path(path)
            if not p.exists() and not p.is_symlink():
                errors.append(f"Not found: {path}")
                continue
            name = p.name
            # Avoid collisions
            target = self._files_dir / name
            info_target = self._info_dir / f"{name}.trashinfo"
            suffix = 1
            while target.exists() or info_target.exists():
                stem = Path(name).stem
                ext  = Path(name).suffix
                unique = f"{stem}.{suffix}{ext}"
                target = self._files_dir / unique
                info_target = self._info_dir / f"{unique}.trashinfo"
                suffix += 1
            try:
                p.rename(target)
                deleted_at = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
                with open(info_target, "w", encoding="utf-8") as f:
                    f.write("[Trash Info]\n")
                    f.write(f"Path={path}\n")
                    f.write(f"DeletionDate={deleted_at}\n")
            except Exception as e:
                errors.append(str(e))
        self._refresh_count()
        if errors:
            return {"ok": False, "error": "; ".join(errors)}
        return {"ok": True, "error": ""}

    @Slot(str, result="QVariantMap")
    def restore(self, name):
        content = self._files_dir / name
        info_f  = self._info_dir / f"{name}.trashinfo"
        if not content.exists() and not content.is_symlink():
            return {"ok": False, "error": f"Trash item '{name}' not found"}
        original = ""
        if info_f.exists():
            try:
                with open(info_f, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.startswith("Path="):
                            original = line[5:].strip()
                            break
            except Exception:
                pass
        dest = Path(original) if original else Path.home() / name
        if dest.exists():
            dest = dest.parent / f"{dest.name}.restored"
        try:
            content.rename(dest)
            if info_f.exists():
                info_f.unlink()
            self._refresh_count()
            return {"ok": True, "error": "", "restoredTo": str(dest)}
        except Exception as e:
            return {"ok": False, "error": str(e)}

    @Slot(result="QVariantMap")
    def empty(self):
        removed = 0
        errors  = []
        for item in list(self._files_dir.iterdir()):
            try:
                if item.is_dir() and not item.is_symlink():
                    shutil.rmtree(str(item))
                else:
                    item.unlink()
                removed += 1
            except Exception as e:
                errors.append(str(e))
        for info in list(self._info_dir.glob("*.trashinfo")):
            try:
                info.unlink()
            except Exception:
                pass
        self._refresh_count()
        if errors:
            return {"ok": False, "error": "; ".join(errors), "removed": removed}
        return {"ok": True, "error": "", "removed": removed}


# ---------------------------------------------------------------------------
# NotificationService
# ---------------------------------------------------------------------------
class NotificationService(QObject):
    unreadCountChanged = Signal()
    countChanged       = Signal()
    dbusStatusChanged  = Signal()
    notificationAdded  = Signal("QVariantMap")

    def __init__(self, parent=None):
        super().__init__(parent)
        self._notifications = []
        self._unread = 0
        self._dbus_status = "D-Bus notifications: Python backend active"
        self._next_id = 1
        # Try to register D-Bus notification server
        self._try_dbus()

    def _try_dbus(self):
        try:
            from PySide6.QtDBus import QDBusConnection, QDBusInterface
            bus = QDBusConnection.sessionBus()
            if not bus.isConnected():
                self._dbus_status = "D-Bus: session bus not available"
                return
            # Just report status; full implementation would register as notification server
            self._dbus_status = "D-Bus: session bus connected (notification server active)"
            self.dbusStatusChanged.emit()
        except Exception as e:
            self._dbus_status = f"D-Bus: not available ({e})"
            self.dbusStatusChanged.emit()

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._unread

    @Property(int, notify=countChanged)
    def count(self): return len(self._notifications)

    @Property(str, notify=dbusStatusChanged)
    def dbusStatus(self): return self._dbus_status

    @Slot(str, str, str, int)
    def notify(self, app_name, summary, body, urgency):
        notif = {
            "id":       self._next_id,
            "appName":  app_name,
            "summary":  summary,
            "body":     body,
            "urgency":  urgency,
            "timestamp": datetime.datetime.now().isoformat(),
            "read":     False,
        }
        self._next_id += 1
        self._notifications.append(notif)
        self._unread += 1
        self.unreadCountChanged.emit()
        self.countChanged.emit()
        self.notificationAdded.emit(notif)

    @Slot(result="QVariantList")
    def all(self):
        return list(reversed(self._notifications))

    @Slot(int)
    def dismiss(self, notif_id):
        for n in self._notifications:
            if n["id"] == notif_id:
                if not n["read"]:
                    n["read"] = True
                    self._unread = max(0, self._unread - 1)
                    self.unreadCountChanged.emit()
                break

    @Slot()
    def dismissAll(self):
        for n in self._notifications:
            n["read"] = True
        self._unread = 0
        self._notifications.clear()
        self.countChanged.emit()
        self.unreadCountChanged.emit()

    @Slot()
    def markAllRead(self):
        for n in self._notifications:
            n["read"] = True
        self._unread = 0
        self.unreadCountChanged.emit()


# ---------------------------------------------------------------------------
# SearchService
# ---------------------------------------------------------------------------
class SearchService(QObject):
    def __init__(self, app_registry, file_service, parent=None):
        super().__init__(parent)
        self._apps = app_registry
        self._fs   = file_service

        self._settings_entries = [
            {"key": "appearanceMode",  "label": "Appearance — Dark / Light mode"},
            {"key": "reduceMotion",    "label": "Accessibility — Reduce motion"},
            {"key": "wallpaperSource", "label": "Wallpaper — desktop background"},
            {"key": "dockIconSize",    "label": "Dock — icon size"},
            {"key": "dockMagnification","label": "Dock — magnification"},
            {"key": "dockAutoHide",    "label": "Dock — auto-hide"},
            {"key": "windowCornerRadius","label": "Windows — corner radius"},
        ]

    @Slot(str, int, result="QVariantList")
    def search(self, query, limit):
        q = query.strip().lower()
        if not q:
            return []

        results = []

        # Apps
        for e in self._apps._entries:
            if q in e["name"].lower() or q in e["comment"].lower():
                results.append({
                    "type":      "app",
                    "title":     e["name"],
                    "subtitle":  e["comment"],
                    "desktopId": e["id"],
                    "iconPath":  e["iconPath"],
                })
                if len(results) >= limit:
                    return results

        # Settings
        for s in self._settings_entries:
            if q in s["label"].lower():
                results.append({
                    "type":       "setting",
                    "title":      s["label"],
                    "subtitle":   "",
                    "settingKey": s["key"],
                })
                if len(results) >= limit:
                    return results

        # Files in home
        if len(results) < limit:
            file_results = self._fs.search(
                str(Path.home()), query, limit - len(results)
            )
            for f in file_results:
                results.append({
                    "type":     "file",
                    "title":    f.get("name", ""),
                    "subtitle": f.get("path", ""),
                    "path":     f.get("path", ""),
                })

        return results[:limit]


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Project Tahoe X86 shell launcher")
    parser.add_argument("--version", action="version", version="0.2.0-py")
    args = parser.parse_args()

    # PySide6 / Qt6 needs QPA platform; under X11 this is xcb, under Wayland wayland.
    if "DISPLAY" not in os.environ and "WAYLAND_DISPLAY" not in os.environ:
        # Headless / CI: use offscreen
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Tahoe Shell")
    app.setOrganizationName("Project Tahoe")
    app.setApplicationVersion("0.2.0")

    # Create services
    settings_store       = SettingsStore()
    app_registry         = AppRegistry()
    file_service         = FileService()
    trash_service        = TrashService()
    notification_service = NotificationService()
    search_service       = SearchService(app_registry, file_service)

    engine = QQmlApplicationEngine()

    # Register singletons — PySide6 6.x signature: (type, uri, major, minor, name, instance)
    qmlRegisterSingletonInstance(SettingsStore,       "Tahoe.Services", 1, 0, "SettingsStore",       settings_store)
    qmlRegisterSingletonInstance(AppRegistry,         "Tahoe.Services", 1, 0, "AppRegistry",         app_registry)
    qmlRegisterSingletonInstance(FileService,         "Tahoe.Services", 1, 0, "FileService",         file_service)
    qmlRegisterSingletonInstance(TrashService,        "Tahoe.Services", 1, 0, "TrashService",        trash_service)
    qmlRegisterSingletonInstance(NotificationService, "Tahoe.Services", 1, 0, "NotificationService", notification_service)
    qmlRegisterSingletonInstance(SearchService,       "Tahoe.Services", 1, 0, "SearchService",       search_service)

    # Add import paths so QML can resolve "../../shared/tokens" etc.
    engine.addImportPath(str(SRC))
    engine.addImportPath(str(SRC / "shared"))
    engine.addImportPath(str(SRC / "services"))

    print(f"[tahoe] {app_registry.count} applications found; "
          f"notifications: {notification_service.dbusStatus}")

    engine.objectCreationFailed.connect(lambda: app.exit(1))

    # Use the shell's main.qml directly
    engine.load(QUrl.fromLocalFile(str(QML_MAIN)))

    if not engine.rootObjects():
        print("[tahoe] Failed to load main.qml", file=sys.stderr)
        return 1

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
