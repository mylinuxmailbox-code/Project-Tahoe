# Behavioural tests for the C++ services.
#
# They link the real service sources, not copies, so a service that stops compiling or changes
# its contract fails here. Qt Test is required; when it is missing the tests are skipped with a
# warning rather than silently reported as passing.

# Imported targets from find_package() are visible in the directory that found them and
# below, so this directory has to ask for the components it links against itself.
find_package(Qt6 6.2 QUIET COMPONENTS Core Gui Qml Test)

if(NOT Qt6Test_FOUND)
    message(WARNING "Tahoe X86: Qt6::Test not found - the service tests are NOT built. "
                    "Install the Qt Test component to run them.")
    return()
endif()

find_package(Qt6 6.2 QUIET COMPONENTS DBus)

set(TAHOE_SERVICE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../src/services)

set(TAHOE_TEST_SOURCES
    tst_services.cpp
    ${TAHOE_SERVICE_DIR}/AppRegistry.cpp
    ${TAHOE_SERVICE_DIR}/FileService.cpp
    ${TAHOE_SERVICE_DIR}/NotificationServer.cpp
    ${TAHOE_SERVICE_DIR}/NotificationService.cpp
    ${TAHOE_SERVICE_DIR}/SearchService.cpp
    ${TAHOE_SERVICE_DIR}/SettingsStore.cpp
    ${TAHOE_SERVICE_DIR}/TrashService.cpp
)

add_executable(tahoe-tests ${TAHOE_TEST_SOURCES})

target_include_directories(tahoe-tests PRIVATE
    ${TAHOE_SERVICE_DIR}
)

# Q_OBJECT in the test class and in the services.
set_target_properties(tahoe-tests PROPERTIES
    AUTOMOC ON
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

target_link_libraries(tahoe-tests PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Test
)

if(Qt6DBus_FOUND)
    target_compile_definitions(tahoe-tests PRIVATE TAHOE_HAS_DBUS)
    target_link_libraries(tahoe-tests PRIVATE Qt6::DBus)
endif()

add_test(NAME services COMMAND tahoe-tests)
