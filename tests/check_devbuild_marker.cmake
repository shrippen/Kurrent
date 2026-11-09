# ctest kurrent-devbuild-marker: the generated DevBuildMarker.qml must follow KURRENT_DEV_BUILD.
# Usage: cmake -DMARKER=<path> -DEXPECTED=true|false -P check_devbuild_marker.cmake
file(READ "${MARKER}" content)
if(NOT content MATCHES "isDevBuild: ${EXPECTED}\n")
    message(FATAL_ERROR "DevBuildMarker.qml: expected isDevBuild: ${EXPECTED}, got:\n${content}")
endif()
