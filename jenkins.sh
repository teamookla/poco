#!/usr/bin/env bash

set -Eeuxo pipefail

CONFIGURE_FLAGS=
CMAKE_FLAGS=(
  -DOPENSSL_ROOT_DIR=$(pwd)/openssl-${OPENSSL_VERSION}/usr
)
MAKE=make
JOBS=2

echo "Testing platform $PLATFORM"
case "$PLATFORM" in
  linux*)
    case "$PLATFORM" in
      linux32)
        TOOLCHAIN=/home/jenkins/toolchains/gcc-6.3-i686
        ;;
      linux64)
        TOOLCHAIN=/home/jenkins/toolchains/gcc-6.3-x86_64
        ;;
    esac
    export LD_LIBRARY_PATH=$TOOLCHAIN/lib
    if [[ -d $TOOLCHAIN/lib64 ]]; then
      LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$TOOLCHAIN/lib64
    fi
    CMAKE_FLAGS+=(
      -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN/Toolchain.cmake
    )
    JOBS=$(getconf _NPROCESSORS_ONLN)
    ;;
  macosx)
    JOBS=$(getconf _NPROCESSORS_ONLN)
    ;;
  freebsd*)
    MAKE=gmake
    CMAKE_FLAGS+=(
      -DCMAKE_CXX_FLAGS="-U_XOPEN_SOURCE -UPOCO_HAVE_FD_EPOLL"
      -DCMAKE_C_FLAGS="-U_XOPEN_SOURCE"
    )
    JOBS=$(sysctl -n hw.ncpu)
    ;;
  win*)
    case $VS_VERSION in
      vs90)
        CMAKE_GENERATOR="Visual Studio 9 2008"
        ;;
      vs100)
        CMAKE_GENERATOR="Visual Studio 10 2010"
        ;;
      vs110)
        CMAKE_GENERATOR="Visual Studio 11 2012"
        ;;
      vs120)
        CMAKE_GENERATOR="Visual Studio 12 2013"
        ;;
      vs140)
        CMAKE_GENERATOR="Visual Studio 14 2015"
        ;;
      vs150)
        CMAKE_GENERATOR="Visual Studio 15 2017"
        ;;
      *)
        echo "Error: VS_VERSION not set"
        exit 1
    esac
    if [[ $WIN_PLATFORM = x64 ]]; then
      set CMAKE_GENERATOR="$CMAKE_GENERATOR Win64"
    fi
    CMAKE_FLAGS=(
      -G "$CMAKE_GENERATOR"
      -DOPENSSL_ROOT_DIR=$(pwd)/openssl-${OPENSSL_VERSION}/OpenSSL
      -DPOCO_MT=ON
    )
    ;;
esac

for build_type in Debug Release; do
  (
    build_dir="cmake_build_${build_type}"
    [[ -d ${build_dir} ]] || mkdir ${build_dir}
    cd ${build_dir}
    cmake .. \
      "${CMAKE_FLAGS[@]}" \
      -DCMAKE_BUILD_TYPE=${build_type} \
      $(for m in \
          PDF MONGODB DATA PAGECOMPILER CPPPARSER APACHECONNECTOR SEVENZIP REDIS POCODOC; do \
          echo -DENABLE_$m=OFF; done) \
      -DPOCO_STATIC=1 \
      -DCMAKE_INSTALL_PREFIX="$(cd ..; pwd)/cmake_install_${build_type}"
    MAKEFLAGS=-j${JOBS} cmake --build . --config "${build_type}" --target install
  )
done
