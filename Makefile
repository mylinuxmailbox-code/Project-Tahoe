.PHONY: configure build clean check lint-qml verify-deps help

QML_FILES = src/shell/qml/main.qml \
            src/apps/finder/FinderWindow.qml \
            src/apps/settings/SettingsWindow.qml \
            src/services/Settings.qml \
            src/shared/tokens/DesignTokens.qml \
            src/shared/components/TahoeDock.qml \
            src/shared/components/TahoeMenuBar.qml \
            src/shared/components/TahoeDesktop.qml \
            src/shared/components/TahoeWindow.qml \
            src/shared/components/TahoeWindowLayer.qml \
            src/shared/components/TahoeSpotlight.qml \
            src/shared/components/TahoeControlCenter.qml \
            src/shared/components/TahoeNotificationCenter.qml \
            src/shared/components/TahoeToggle.qml \
            src/shared/components/TahoeSlider.qml

configure:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug

build: configure
	cmake --build build --target tahoe-shell

clean:
	rm -rf build

# Verification that does not require Qt:
#   1. structural checks over the source tree (tools/verify_structure.py)
#   2. a check that every Qt class used has its header included (tools/check_includes.py)
# Make stops at the first failing line, so a failure here is a real failure.
check:
	python3 tools/verify_structure.py
	python3 tools/check_includes.py

# Static QML checking. Requires qt6-declarative-dev-tools (qmllint).
# Exit codes: 0 = qmllint ran and passed, 2 = skipped (tool absent), non-zero = qmllint failed.
# A skip is never reported as a pass.
lint-qml:
	@if command -v qmllint6 >/dev/null 2>&1; then \
		qmllint6 $(QML_FILES); \
	elif command -v qmllint >/dev/null 2>&1; then \
		qmllint $(QML_FILES); \
	elif [ -x /usr/lib/qt6/bin/qmllint ]; then \
		/usr/lib/qt6/bin/qmllint $(QML_FILES); \
	else \
		echo "qmllint not available (install qt6-declarative-dev-tools)."; \
		echo "QML was NOT statically checked - this is a skipped check, not a pass."; \
		exit 2; \
	fi

verify-deps:
	@echo "Checking build dependencies..."
	@command -v cmake >/dev/null || { echo "missing: cmake"; exit 1; }
	@command -v g++ >/dev/null || { echo "missing: g++"; exit 1; }
	@qt6_found=no; \
	if [ -n "$(Qt6_DIR)" ] && [ -d "$(Qt6_DIR)" ]; then qt6_found=yes; fi; \
	if [ "$qt6_found" = no ] && [ -f build/CMakeCache.txt ]; then \
		qt6_cached=`sed -n 's/^Qt6_DIR:PATH=//p' build/CMakeCache.txt | head -1`; \
		case "$$qt6_cached" in \
			""|*NOTFOUND*|"Qt6_DIR-NOTFOUND") qt6_found=no ;; \
			*) if [ -d "$$qt6_cached" ]; then qt6_found=yes; else qt6_found=no; fi ;; \
		esac; \
	fi; \
	if [ "$$qt6_found" = yes ]; then \
		echo "Qt 6 CMake config found."; \
	else \
		echo "Qt 6 CMake config NOT found."; \
		echo "A build/CMakeCache.txt may exist from a failed configure; Qt6_DIR-NOTFOUND is not a found config."; \
		echo "Install a Qt 6 development package (qt6-base-dev + qt6-declarative-dev on"; \
		echo "Debian/Ubuntu-class systems) or set CMAKE_PREFIX_PATH / Qt6_DIR. See build_env.md."; \
	fi
	@echo "Dependency check complete."

help:
	@echo "Project Tahoe X86 make targets:"
	@echo "  configure  - run cmake configuration"
	@echo "  build      - configure and build tahoe-shell"
	@echo "  clean      - remove build tree"
	@echo "  check      - structural + include verification (no Qt required)"
	@echo "  lint-qml   - static QML check via qmllint (skips honestly if absent)"
	@echo "  verify-deps - check key build dependencies"
	@echo "  help       - show this message"
