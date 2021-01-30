export CROSS_COMPILE=/usr/bin/aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnu-
make O=out ARCH=arm64 vendor/apollo_defconfig
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=/usr/bin/clang 