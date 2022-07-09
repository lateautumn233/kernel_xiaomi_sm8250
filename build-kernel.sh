#!/usr/bin/env bash
# shellcheck disable=SC2199
# shellcheck disable=SC2086
# shellcheck source=/dev/null
#
# Copyright (C) 2020-22 UtsavBalar1231 <utsavbalar1231@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ ! -d "anykernel" ]; then
    git clone https://github.com/lateautumn233/AnyKernel3 -b kona --depth=1 anykernel
fi

# Set device
case "$1" in
alioth)
    DEVICE=$1
    ;;
apollo)
    DEVICE=$1
    ;;
cas)
    DEVICE=$1
    ;;
cmi)
    DEVICE=$1
    ;;
elish)
    DEVICE=$1
    ;;
enuma)
    DEVICE=$1
    ;;
lmi)
    DEVICE=$1
    ;;
umi)
    DEVICE=$1
    ;;
thyme)
    DEVICE=$1
    ;;
psyche)
    DEVICE=$1
    ;;
esac

KBUILD_COMPILER_STRING=$(${HOME}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
KBUILD_LINKER_STRING=$(${HOME}/clang/bin/ld.lld --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' | sed 's/(compatible with [^)]*)//')

export KBUILD_COMPILER_STRING
export KBUILD_LINKER_STRING

#
# Enviromental Variables
#

# Set compiler path
PATH=${HOME}/gas:${HOME}/clang/bin/:$PATH
export LD_LIBRARY_PATH=${HOME}/clang/lib64:${LD_LIBRARY_PATH}


# Set the current branch name
BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

# Set the last commit sha
COMMIT=$(git rev-parse --short HEAD)

# Set current date
DATE=$(date +"%d.%m.%y")

# Set Kernel Version
KERNELVER=$(make kernelversion)

# Set our directory
OUT_DIR=out/

#Set csum
CSUM=$(cksum <<<${COMMIT} | cut -f 1 -d ' ')

if [ ! -f "${OUT_DIR}Version" ] || [ ! -d "${OUT_DIR}" ]; then
    echo "init Version"
    mkdir -p $OUT_DIR
    echo 1 >${OUT_DIR}Version
fi

#Set build count
BUILD=$(cat out/Version)

# Select LTO or non LTO builds
if [[ "$@" =~ "lto"* ]]; then
    VERSION="Autumn-${DEVICE^^}-build${BUILD}-LTO-${CSUM}-${DATE}"

else
    VERSION="Autumn-${DEVICE^^}-build${BUILD}-${CSUM}-${DATE}"
fi

# Export Zip name
export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
    COUNT="$(grep -c '^processor' /proc/cpuinfo)"
    export KEBABS="$((COUNT * 2))"
fi

ARGS="ARCH=arm64 \
O=${OUT_DIR} \
LLVM=1 \
CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
-j${KEBABS} "

dts_source=arch/arm64/boot/dts/vendor/qcom
# Correct panel dimensions on MIUI builds
function miui_fix_dimens() {
    sed -i 's/<70>/<695>/g' $dts_source/dsi-panel-j3s-37-02-0a-dsc-video.dtsi
    sed -i 's/<70>/<695>/g' $dts_source/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
    sed -i 's/<70>/<695>/g' $dts_source/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi
    sed -i 's/<71>/<710>/g' $dts_source/dsi-panel-j1s*
    sed -i 's/<71>/<710>/g' $dts_source/dsi-panel-j2*
    sed -i 's/<155>/<1544>/g' $dts_source/dsi-panel-j3s-37-02-0a-dsc-video.dtsi
    sed -i 's/<155>/<1545>/g' $dts_source/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
    sed -i 's/<155>/<1546>/g' $dts_source/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi
    sed -i 's/<154>/<1537>/g' $dts_source/dsi-panel-j1s*
    sed -i 's/<154>/<1537>/g' $dts_source/dsi-panel-j2*
}

# Enable back mi smartfps while disabling qsync min refresh-rate
function miui_fix_fps() {
    sed -i 's/qcom,mdss-dsi-qsync-min-refresh-rate/\/\/qcom,mdss-dsi-qsync-min-refresh-rate/g' $dts_source/dsi-panel*
    sed -i 's/\/\/ mi,mdss-dsi-smart-fps-max_framerate/mi,mdss-dsi-smart-fps-max_framerate/g' $dts_source/dsi-panel*
    sed -i 's/\/\/ mi,mdss-dsi-pan-enable-smart-fps/mi,mdss-dsi-pan-enable-smart-fps/g' $dts_source/dsi-panel*
    sed -i 's/\/\/ qcom,mdss-dsi-pan-enable-smart-fps/qcom,mdss-dsi-pan-enable-smart-fps/g' $dts_source/dsi-panel*
}

# Enable back refresh rates supported on MIUI
function miui_fix_dfps() {
    sed -i 's/120 90 60/120 90 60 50 30/g' $dts_source/dsi-panel-g7a-37-02-0a-dsc-video.dtsi
    sed -i 's/120 90 60/120 90 60 50 30/g' $dts_source/dsi-panel-g7a-37-02-0b-dsc-video.dtsi
    sed -i 's/120 90 60/120 90 60 50 30/g' $dts_source/dsi-panel-g7a-36-02-0c-dsc-video.dtsi
    sed -i 's/144 120 90 60/144 120 90 60 50 48 30/g' $dts_source/dsi-panel-j3s-37-02-0a-dsc-video.dtsi
}

# Enable back brightness control from dtsi
function miui_fix_fod() {
    sed -i 's/\/\/39 01 00 00 01 00 03 51 03 FF/39 01 00 00 01 00 03 51 03 FF/g' $dts_source/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 03 FF/39 01 00 00 00 00 03 51 03 FF/g' $dts_source/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
    sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' $dts_source/dsi-panel-j1s-42-02-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' $dts_source/dsi-panel-j1s-42-02-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' $dts_source/dsi-panel-j1s-42-02-0a-mp-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' $dts_source/dsi-panel-j1s-42-02-0a-mp-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' $dts_source/dsi-panel-j1u-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' $dts_source/dsi-panel-j1u-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 00 00/39 01 00 00 00 00 03 51 00 00/g' $dts_source/dsi-panel-j2-38-0c-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 00 00/39 01 00 00 00 00 03 51 00 00/g' $dts_source/dsi-panel-j2-38-0c-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' $dts_source/dsi-panel-j2-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' $dts_source/dsi-panel-j2-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' $dts_source/dsi-panel-j2-mp-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' $dts_source/dsi-panel-j2-mp-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' $dts_source/dsi-panel-j2-p1-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' $dts_source/dsi-panel-j2-p1-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 00 00 00 00 00 03 51 0D FF/39 00 00 00 00 00 03 51 0D FF/g' $dts_source/dsi-panel-j2-p2-1-38-0c-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 11 00 03 51 03 FF/39 01 00 00 11 00 03 51 03 FF/g' $dts_source/dsi-panel-j2-p2-1-38-0c-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' $dts_source/dsi-panel-j2-p2-1-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' $dts_source/dsi-panel-j2-p2-1-42-02-0b-dsc-cmd.dtsi
    sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' $dts_source/dsi-panel-j2s-mp-42-02-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' $dts_source/dsi-panel-j2s-mp-42-02-0a-dsc-cmd.dtsi
    sed -i 's/\/\/39 00 00 00 00 00 03 51 03 FF/39 00 00 00 00 00 03 51 03 FF/g' $dts_source/dsi-panel-j9-38-0a-0a-fhd-video.dtsi
    sed -i 's/\/\/39 01 00 00 00 00 03 51 03 FF/39 01 00 00 00 00 03 51 03 FF/g' $dts_source/dsi-panel-j9-38-0a-0a-fhd-video.dtsi
}

function enable_lto() {
    scripts/config --file ${OUT_DIR}/.config \
        -e LTO_CLANG

    # Make olddefconfig
    cd ${OUT_DIR} || exit
    make -j${KEBABS} ${ARGS} olddefconfig
    cd ../ || exit
}

if [[ "$@" =~ "lto"* ]]; then
    # Enable LTO
    lto=1
fi

function build() {

os=$@

# Start Build
echo "------ Stating echo ${os^^} Build ------"

# Make defconfig
make -j${KEBABS} ${ARGS} "${DEVICE}"_defconfig

if [ "$os" == "miui" ]; then
    scripts/config --file ${OUT_DIR}/.config \
        -d LOCALVERSION_AUTO \
        -d TOUCHSCREEN_COMMON \
        --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
        -e BOOT_INFO \
        -e BINDER_OPT \
        -e DEBUG_KERNEL \
        -e IPC_LOGGING \
        -e KPERFEVENTS \
        -e LAST_TOUCH_EVENTS \
        -e MIGT \
        -e MIHW \
        -e MILLET \
        -e MIUI_DRM_WAKE_OPT \
        -e MIUI_ZRAM_MEMORY_TRACKING \
        -e MI_RECLAIM \
        -d OSSFOD \
        -e PERF_HUMANTASK \
        -e TASK_DELAY_ACCT

    miui_fix_dimens
    miui_fix_fps
    miui_fix_dfps
    miui_fix_fod
fi

if [ "$os" == "aospa" ]; then
scripts/config --file ${OUT_DIR}/.config \
    -d SDCARD_FS \
    -e UNICODE
fi

# Make olddefconfig
cd ${OUT_DIR} || exit
make -j${KEBABS} ${ARGS} olddefconfig
cd ../ || exit

if [[ $lto -eq 1 ]]; then
    # Enable LTO
    enable_lto
    make -j${KEBABS} ${ARGS} CC="ccache clang" 2>&1 | tee build.log
else
    make -j${KEBABS} ${ARGS} CC="ccache clang" 2>&1 | tee build.log
fi

#return_codes=(${PIPESTATUS[*]})

# 如果编译错误就恢复对dts的更改并退出
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
    echo "Error in ${os} build!!"
    git checkout arch/arm64/boot/dts/vendor &>/dev/null
    exit 1
fi

find ${OUT_DIR}/$dts_source -name '*.dtb' -exec cat {} + >${OUT_DIR}/arch/arm64/boot/dtb

mkdir -p anykernel/kernels/$os
# Import Anykernel3 folder
if [[ -f ${OUT_DIR}/arch/arm64/boot/Image.gz ]]; then
    cp ${OUT_DIR}/arch/arm64/boot/Image.gz anykernel/kernels/$os
else
    if [[ -f ${OUT_DIR}/arch/arm64/boot/Image ]]; then
        cp ${OUT_DIR}/arch/arm64/boot/Image anykernel/kernels/$os
    fi
fi
cp ${OUT_DIR}/arch/arm64/boot/dtb anykernel/kernels/$os
cp ${OUT_DIR}/arch/arm64/boot/dtbo.img anykernel/kernels/$os

git checkout arch/arm64/boot/dts/vendor &>/dev/null

echo "------ Finishing ${os^^} Build ------" # ^^转小写为大写

}

START=$(date +"%s")

build aosp
build miui
build aospa

END=$(date +"%s")
DIFF=$((END - START))

echo "✅ Kernel compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds for ${DEVICE}"

echo $(($BUILD + 1)) >${OUT_DIR}Version

cd anykernel || exit
zip -r9 "${ZIPNAME}" ./* -x .git .gitignore ./*.zip

cd "$(pwd)" || exit

# Cleanup
#rm -fr anykernel/
