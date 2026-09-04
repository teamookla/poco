#!/usr/bin/env bash

set -Eeuxo pipefail
env

: "${TOOLCHAINS:=}"
: "${MUSL_GCC_VERSION:=}"
: "${FREEBSD_JAIL:=}"
: "${IN_FREEBSD_JAIL:=}"
: "${JENKINS_PLATFORM:=${PLATFORM}}"
PLATFORM="${JENKINS_PLATFORM}"

if [[ -z $IN_FREEBSD_JAIL ]]; then
    rm -rf shared
    git clone --depth 1 git@github.com:teamookla/speedtest-sharedsuite.git shared
fi

if [[ -n $FREEBSD_JAIL ]]; then
    exec ./jenkins-freebsd-jail.sh
fi

. ./shared/build/ccache.sh

OPENSSL_ROOT_DIR=$(pwd)/openssl-${OPENSSL_VERSION}/usr

# Flags that must be identical on every platform. The win* arm below rebuilds
# CMAKE_FLAGS from scratch (the Windows OpenSSL tarball has a different prefix),
# so anything that has to hold everywhere belongs here rather than inline.
#
# ENABLE_FASTLOGGER / ENABLE_TRACE are new in 1.15.x and default ON / OFF. They
# pull in the bundled Quill and cpptrace respectively; Ookla ships neither, and
# Quill is the only thing in the tree that needs a macOS deployment target
# newer than 10.15. Pin both so the artifact does not change under us.
COMMON_FLAGS=(
  -DBUILD_SHARED_LIBS=off
  -DENABLE_FASTLOGGER=OFF
  -DENABLE_TRACE=OFF
)
CMAKE_FLAGS=(
  "${COMMON_FLAGS[@]}"
  -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}
)
TOOLCHAIN_FILE=../shared/cmake/select-toolchain.cmake

echo "Testing platform $PLATFORM"
case "$PLATFORM" in
    freebsd*)
        if [[ $PLATFORM == *-arm64 ]]; then
            TOOLCHAIN_FILE=../cmake/OoklaFreeBSDCross.cmake
            CMAKE_FLAGS+=(
                -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}
                -DTOOLCHAINS=${TOOLCHAINS:-/home/jenkins/toolchains}
                -DJENKINS_PLATFORM=${JENKINS_PLATFORM}
                -DOOKLA_FIND_ROOTS=${OPENSSL_ROOT_DIR}
            )
        fi
        ;;
    win*)
        unset CMAKE_GENERATOR CMAKE_GENERATOR_PLATFORM CMAKE_GENERATOR_TOOLSET
        CMAKE_FLAGS=(
            "${COMMON_FLAGS[@]}"
            -DOPENSSL_ROOT_DIR=$(pwd)/openssl-${OPENSSL_VERSION}/OpenSSL
            -DPOCO_MT=ON
        )
        ;;
    mac*)
        # Poco 1.15.4 defaults CMAKE_OSX_DEPLOYMENT_TARGET to 15.0; we override it
        # back to 10.11. That only builds with ENABLE_FASTLOGGER=OFF (see
        # COMMON_FLAGS) -- Quill needs >= 10.15 for aligned new/delete and
        # std::filesystem::path.
        CMAKE_FLAGS+=(
            '-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64'
            '-DCMAKE_OSX_DEPLOYMENT_TARGET=10.11'
        )
        ;;
esac

source ./shared/build/detect-platform.sh

if [ -z "${TOOLCHAINS}" ]; then
    TOOLCHAINS=/home/jenkins/toolchains
fi


PACKAGES=(
  CRYPTO
  ENCODINGS
  FOUNDATION
  JSON
  JWT
  NET
  NETSSL
  UTIL
  XML
  ZIP
)

PACKAGES_RE=$(echo "^(${PACKAGES[@]})\$" | perl -pe 's/ /|/g')

# Check for cross-compiler toolchain.
if [[ ${TOOLCHAIN_NAME} != none ]]; then
        JENKINS_PLATFORM="${TOOLCHAIN_NAME}"
        CMAKE_FLAGS+=(
            -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}
            -DTOOLCHAINS=${TOOLCHAINS}
            -DJENKINS_PLATFORM=${JENKINS_PLATFORM}
            # Generic static-musl-* toolchain files resolve
            # ${TOOLCHAINS}/cross/<target>-gcc-${MUSL_GCC_VERSION}; without this the path
            # ends in a bare "gcc-" and compiler detection fails.
            -DMUSL_GCC_VERSION=${MUSL_GCC_VERSION}
        )
fi

for build_type in Debug Release; do
  CMAKE_PACKAGES_FLAGS=()
  (
    build_dir="cmake_build_${build_type}"
    [[ -d ${build_dir} ]] || mkdir ${build_dir}
    cd ${build_dir}
    CMAKE_PACKAGES=$(cmake .. "${CMAKE_FLAGS[@]}" ${CMAKE_EXTRA} -Wno-dev -LA | grep '^ENABLE' | cut -c8- | sed -e 's,:BOOL=, ,'; true)
    while IFS='\n' read line; do
        read package enabled <<< "$line"
        echo "$package => $enabled"
        if [[ $enabled = ON ]] && [[ ! $package =~ $PACKAGES_RE ]]; then
          CMAKE_PACKAGES_FLAGS+=("-DENABLE_$package=OFF")
          echo "Disabling package $package"
        elif [[ $enabled = OFF ]] && [[ $package =~ $PACKAGES_RE ]]; then
          CMAKE_PACKAGES_FLAGS+=("-DENABLE_$package=ON")
          echo "Enabling package $package"
        else
          CMAKE_PACKAGES_FLAGS+=("-DENABLE_$package=$enabled")
        fi
    done <<< "${CMAKE_PACKAGES[@]}"

    cmake .. \
      "${CMAKE_FLAGS[@]}" \
       ${CMAKE_EXTRA} \
       -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE} \
       -DTOOLCHAINS=${TOOLCHAINS}  -DJENKINS_PLATFORM=${JENKINS_PLATFORM} \
      -DCMAKE_BUILD_TYPE=${build_type} \
      "${CMAKE_PACKAGES_FLAGS[@]}" \
      -DCMAKE_INSTALL_PREFIX="$(cd ..; pwd)/cmake_install_${build_type}"
   cmake --build . --config "${build_type}" --target install
  )
done

. ./shared/build/ccache.sh archive
