cmake_minimum_required(VERSION 3.16)

project(kurrent VERSION 0.4.0 LANGUAGES CXX)

set(KURRENT_RELEASE_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}")
add_compile_definitions(KURRENT_RELEASE_VERSION="${KURRENT_RELEASE_VERSION}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(KURRENT_DEV_BUILD "Show developer-only debug info in the plasmoid UI." OFF)

# Dev build counter: increments once per build invocation.
set(_KURRENT_COUNTER_FILE "${CMAKE_BINARY_DIR}/kurrent_build_counter.txt")
if(EXISTS "${_KURRENT_COUNTER_FILE}")
    file(READ "${_KURRENT_COUNTER_FILE}" _kurrent_counter_raw)
    string(STRIP "${_kurrent_counter_raw}" _kurrent_counter_raw)
    if(_kurrent_counter_raw STREQUAL "")
        set(_kurrent_counter 0)
    else()
        math(EXPR _kurrent_counter "${_kurrent_counter_raw} + 1")
    endif()
else()
    set(_kurrent_counter 1)
endif()

file(WRITE "${_KURRENT_COUNTER_FILE}" "${_kurrent_counter}")

add_compile_definitions(KURRENT_BUILD_NUMBER=${_kurrent_counter})
if(KCURRENT_DEV_BUILD)
    add_compile_definitions(KCURRENT_DEV_BUILD=1)
    set(KCURRENT_DEV_BUILD_BOOL "true")
else()
    add_compile_definitions(KURRENT_DEV_BUILD=0)
    set(KCURRENT_DEV_BUILD_BOOL "false")
endif()

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(CTest)

set(CMAKE_AUTOMOC ON)

add_subdirectory(plugin)

option(KURRENT_BUILD_KRUNNER "Build the KRunner plugin" ON)
if(KURRENT_BUILD_KRUNNER)
    find_package(KF6Runner QUIET)
    if(KF6Runner_FOUND)
        add_subdirectory(krunner)
    else()
        message(STATUS "KF6Runner not found; skipping KRunner plugin.")
    endif()
endif()

if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

find_program(GETTEXT_MSGFMT_EXECUTABLE msgfmt)
if(GETTEXT_MSGFMT_EXECUTABLE)
    set(_kurrent_i18n_langs de es fr ja zh_CN)
    set(_kurrent_mo_files)
    foreach(_lang ${_kurrent_i18n_langs})
        set(_po "${CMAKE_CURRENT_SOURCE_DIR}/po/${_lang}.po")
        set(_mo_dir "${CMAKE_CURRENT_BINARY_DIR}/locale/${_lang}/LC_MESSAGES")
        set(_mo "${_mo_dir}/plasma_applet_com.github.shrippen.kurrent.mo")
        add_custom_command(
            OUTPUT "${_mo}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_mo_dir}"
            COMMAND "${GETTEXT_MSGFMT_EXECUTABLE}" -o "${_mo}" "${_po}"
            DEPENDS "${_po}"
            COMMENT "Compiling ${_lang} translation"
        )
        list(APPEND _kurrent_mo_files "${_mo}")
        install(FILES "${_mo}"
            DESTINATION "${CMAKE_INSTALL_PREFIX}/share/locale/${_lang}/LC_MESSAGES")
    endforeach()
    add_custom_target(kurrent-translations ALL DEPENDS ${_kurrent_mo_files})
else()
    message(WARNING "msgfmt not found; translations will not be installed.")
endif()

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/plasmoid/com.github.shrippen.kurrent/contents/config/DevBuildMarker.qml.in"
    "${CMAKE_CURRENT_BINARY_DIR}/DevBuildMarker.qml"
    @ONLY
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/DevBuildMarker.qml"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/plasma/plasmoids/com.github.shrippen.kurrent/contents/config"
)
install(DIRECTORY plasmoid/com.github.shrippen.kurrent/
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/plasma/plasmoids/com.github.shrippen.kurrent"
)
install(FILES icons/kurrent.svg
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/icons/hicolor/scalable/apps"
)
install(FILES kurrent.notifyrc
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/knotifications6"
)
