cmake_minimum_required(VERSION 3.22)
project(tahoe-x86 VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(TAHOO_BUILD_SHELL "Build the Tahoe shell" ON)
option(TAHOO_ENABLE_PACKAGING "Enable CPack packaging targets" ON)

if(TAHOO_BUILD_SHELL)
    add_subdirectory(src/shell)
endif()

if(TAHOO_ENABLE_PACKAGING)
    set(CPACK_PACKAGE_NAME "tahoe-x86")
    set(CPACK_PACKAGE_VENDOR "Project Tahoe")
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Project Tahoe X86 desktop shell")
    set(CPACK_GENERATOR "TGZ")
    include(CPack)
endif()

message(STATUS "Tahoe X86 ${PROJECT_VERSION} configured (shell: ${TAHOO_BUILD_SHELL}, packaging: ${TAHOO_ENABLE_PACKAGING})")
