#!/usr/bin/env bash

set -Eeuxo pipefail
env

CONFIGURE_FLAGS=
CMAKE_FLAGS=(
  -DOPENSSL_ROOT_DIR=$(pwd)/openssl-${OPENSSL_VERSION}/usr
)
NINJA="$(type -p ninja || true)"
if [ "${USE_NINJA:-true}" != "true" -o  -z "$NINJA" ]; then 
    JOBS=4
    case $(uname) in
        Linux |  Darwin)
	    JOBS=$(getconf _NPROCESSORS_ONLN)
	    ;;
        FreeBSD)
	    JOBS=$(sysctl -n hw.ncpu)
	    ;;
    esac
    MAKE="make -j${JOBS}"
else
    MAKE=ninja
    CMAKE_FLAGS+=(
        "-GNinja"
    )
fi

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
      *)
        TOOLCHAIN=""
        ;;
    esac
    if [[  $TOOLCHAIN != "" ]]; then 
        export LD_LIBRARY_PATH=$TOOLCHAIN/lib
        if [[ -d $TOOLCHAIN/lib64 ]]; then
            LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$TOOLCHAIN/lib64
        fi
        CMAKE_FLAGS+=(
            -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN/Toolchain.cmake
        )
    fi
    ;;
  freebsd*)
    CMAKE_FLAGS+=(
      -DCMAKE_CXX_FLAGS="-U_XOPEN_SOURCE -UPOCO_HAVE_FD_EPOLL"
      -DCMAKE_C_FLAGS="-U_XOPEN_SOURCE"
    )
    ;;
  win*)
    CMAKE_FLAGS+=(
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
    if [ "$(cat generator 2>/dev/null || true)" != "${MAKE}" ]; then
        rm -rf *
    fi
    echo "${MAKE}" >  generator
    cmake .. \
      "${CMAKE_FLAGS[@]}" \
      -DCMAKE_BUILD_TYPE=${build_type} \
      $(for m in \
          PDF MONGODB DATA PAGECOMPILER CPPPARSER APACHECONNECTOR SEVENZIP REDIS POCODOC; do \
          echo -DENABLE_$m=OFF; done) \
      -DPOCO_STATIC=1 \
      -DCMAKE_INSTALL_PREFIX="$(cd ..; pwd)/cmake_install_${build_type}"
   ${MAKE} install
  )
done
