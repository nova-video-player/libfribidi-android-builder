#!/bin/bash

source ../../AVP/android-setup-light.sh

LOCAL_PATH=$($READLINK -f .)
mkdir -p ../prebuilt/fribidi
PREBUILT_DIR=$($READLINK -f ../prebuilt/fribidi)

# Check if prebuilt libraries already exist
if [ -f "${PREBUILT_DIR}/lib/armeabi-v7a/libfribidi.a" ] && \
   [ -f "${PREBUILT_DIR}/lib/arm64-v8a/libfribidi.a" ] && \
   [ -f "${PREBUILT_DIR}/lib/x86/libfribidi.a" ] && \
   [ -f "${PREBUILT_DIR}/lib/x86_64/libfribidi.a" ]; then
  echo "All fribidi prebuilt libs already exist, skipping"
  exit 0
fi

if [ ! -d "fribidi" ]
then
  git clone https://github.com/fribidi/fribidi.git --depth=1 -b v1.0.16
fi

API_LEVEL=21

for ABI in armeabi-v7a arm64-v8a x86 x86_64
do
  case "${ABI}" in
    'arm64-v8a')
      CPU_FAMILY='aarch64'
      TARGET=aarch64-linux-android
      ;;
    'armeabi-v7a')
      CPU_FAMILY='arm'
      TARGET=armv7a-linux-androideabi
      ;;
    'x86')
      CPU_FAMILY='x86'
      TARGET=i686-linux-android
      ;;
    'x86_64')
      CPU_FAMILY='x86_64'
      TARGET=x86_64-linux-android
      ;;
  esac

  PREFIX="${PREBUILT_DIR}"

  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  TOOLCHAIN="${NDK_PATH}/toolchains/llvm/prebuilt/${OS}-x86_64"

  export AR="${TOOLCHAIN}/bin/llvm-ar"
  export STRIP="${TOOLCHAIN}/bin/llvm-strip"
  export CC="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang"
  export CXX="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang++"

  # Create cross-file for this ABI
  user_config="meson-cross-${ABI}.txt"
  rm -f $user_config
  cat <<EOF > $user_config
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
pkg-config = 'pkg-config'

[host_machine]
system = 'android'
cpu_family = '$CPU_FAMILY'
cpu = '$CPU_FAMILY'
endian = 'little'
EOF

  if [ ! -f "${PREBUILT_DIR}/lib/${ABI}/libfribidi.a" ]
  then
    echo "Building fribidi for ${ABI}..."
    cd fribidi
    rm -rf "build-${ABI}"
    meson setup "build-${ABI}" --cross-file "../meson-cross-${ABI}.txt" --prefix="${PREFIX}" --libdir="lib/${ABI}" --default-library=static -Dtests=false -Ddocs=false -Dbin=false
    ninja -C "build-${ABI}" install
    cd ..
  else
    echo "Fribidi already built for ${ABI}"
  fi
done
