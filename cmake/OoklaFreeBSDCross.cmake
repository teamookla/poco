# Ookla: wrapper toolchain file for the FreeBSD arm64 jail cross builds.
#
# shared/cmake/toolchains/freebsd-arm64.cmake pins CMAKE_FIND_ROOT_PATH to
# /opt/cross/arm64 with CMAKE_FIND_ROOT_PATH_MODE_LIBRARY/INCLUDE set to ONLY.
# That is what we want for keeping the host's x86_64 /usr/include and /usr/lib
# out of the cross build, but it also hides the OpenSSL install that jenkins.sh
# unpacks into the workspace, so find_package(OpenSSL) fails.
#
# Append whatever dependency roots the build passes in via OOKLA_FIND_ROOTS
# (a ;-separated list) after the real toolchain has been selected.
include("${CMAKE_CURRENT_LIST_DIR}/../shared/cmake/select-toolchain.cmake")

if(OOKLA_FIND_ROOTS)
    list(APPEND CMAKE_FIND_ROOT_PATH ${OOKLA_FIND_ROOTS})
    message(STATUS "Ookla: CMAKE_FIND_ROOT_PATH=${CMAKE_FIND_ROOT_PATH}")
endif()
