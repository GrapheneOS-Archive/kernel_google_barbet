#!/bin/bash

set -o errexit -o pipefail

[[ $# -eq 1 ]] || exit 1

DEVICE=$1

if [[ $DEVICE != redfin && $DEVICE != bramble && $DEVICE != barbet ]]; then
    echo invalid device codename
    exit 1
fi

DEFCONFIG_DEVICE=$DEVICE
if [[ $DEVICE == barbet ]]; then
    DEFCONFIG_DEVICE=bramble
fi

ROOT_DIR=$(realpath ../../..)

PATH="$ROOT_DIR/prebuilts/build-tools/linux-x86/bin:$PATH"
PATH="$ROOT_DIR/prebuilts/build-tools/path/linux-x86:$PATH"
PATH="$ROOT_DIR/kernel/prebuilts/build-tools/linux-x86/bin:$PATH"
PATH="$ROOT_DIR/prebuilts/gas/linux-x86:$PATH"
PATH="$ROOT_DIR/prebuilts/clang/host/linux-x86/clang-r383902/bin:$PATH"
PATH="$ROOT_DIR/prebuilts/misc/linux-x86/libufdt:$PATH"
export LD_LIBRARY_PATH="$ROOT_DIR/prebuilts/clang/host/linux-x86/clang-r383902/lib64:$LD_LIBRARY_PATH"
export DTC_EXT="$ROOT_DIR/kernel/prebuilts/build-tools/linux-x86/bin/dtc"
export DTC_OVERLAY_TEST_EXT="$ROOT_DIR/kernel/prebuilts/build-tools/linux-x86/bin/ufdt_apply_overlay"

export KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_USER=grapheneos
export KBUILD_BUILD_HOST=grapheneos
export KBUILD_BUILD_TIMESTAMP="$(date -ud "@$(git show -s --format=%ct)")"

chrt -bp 0 $$

make \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    ${DEFCONFIG_DEVICE}_defconfig

make -j$(nproc) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

make -j$(nproc) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    INSTALL_MOD_PATH=moduleout \
    INSTALL_MOD_STRIP=1 \
    modules_install

cp out/arch/arm64/boot/dtbo_${DEVICE}.img "$ROOT_DIR/device/google/${DEVICE}-kernel/dtbo.img"
cp out/arch/arm64/boot/Image.lz4 "$ROOT_DIR/device/google/${DEVICE}-kernel"
cp out/arch/arm64/boot/dts/google/qcom-base/lito.dtb "$ROOT_DIR/device/google/${DEVICE}-kernel"

echo "TODO: disable LKM, copying kernel modules. modules in device kernel repo will be deleted"
rm -fv $ROOT_DIR/device/google/${DEVICE}-kernel/*.ko
cd out/moduleout/
for i in $(find -name "*.ko"); do
cp ${i} $ROOT_DIR/device/google/${DEVICE}-kernel/
done
cd ..
cp modules.order "$ROOT_DIR/device/google/${DEVICE}-kernel/modules.load"
