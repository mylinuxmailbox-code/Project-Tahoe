find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick)

# The notification bridge needs Qt6::DBus. It is optional on purpose: the shell still builds
# and runs without it, and NotificationService then reports that it cannot receive
# notifications from other applications instead of pretending it can.
find_package(Qt6 6.2 QUIET COMPONENTS DBus)

set(TAHOE_SHELL_SOURCES
    main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../services/AppRegistry.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../services/FileService.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../services/NotificationServer.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../services/NotificationService.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../services/SearchService.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../services/SettingsStore.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../services/TrashService.cpp
    tahoe.qrc
)

add_executable(tahoe-shell ${TAHOE_SHELL_SOURCES})

target_include_directories(tahoe-shell PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../services
)

set_target_properties(tahoe-shell PROPERTIES
    OUTPUT_NAME tahoe-shell
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
    # Compiles tahoe.qrc into the binary. Without this the .qrc is inert and the shell would
    # have no QML resources to load at runtime.
    AUTORCC ON
    # Required by the Q_OBJECT classes in src/services.
    AUTOMOC ON
)

# Single source of truth for the version string: project() in the root CMakeLists.
target_compile_definitions(tahoe-shell PRIVATE
    TAHOE_VERSION="${PROJECT_VERSION}"
)

target_link_libraries(tahoe-shell PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

if (Qt6DBus_FOUND)
    target_compile_definitions(tahoe-shell PRIVATE TAHOE_HAS_DBUS)
    target_link_libraries(tahoe-shell PRIVATE Qt6::DBus)
    message(STATUS "Tahoe Shell: Qt6::DBus found - the shell can serve "
                   "org.freedesktop.Notifications")
else()
    message(WARNING "Tahoe Shell: Qt6::DBus not found - notifications from other applications "
                    "will not reach the shell. Install qt6-base-dev to enable them.")
endif()

install(TARGETS tahoe-shell
        RUNTIME DESTINATION bin)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/resources/org.projecttahoe.shell.desktop
        DESTINATION share/applications)
