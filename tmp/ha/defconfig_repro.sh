#!/bin/bash
# 根因复现：当前 openwrt master + feeds + 本仓库 config → defconfig → 看 qemu-ga 是否存活
set -x
cd "$(dirname "$0")"
rm -rf owrt
git clone --depth 1 https://github.com/openwrt/openwrt owrt || exit 1
cd owrt
./scripts/feeds update -a || exit 2
./scripts/feeds install -a || exit 3
cp /home/zed/coding/openwrt/Openwrt-Make/config/MakeMenu.x86-official.config .config
make defconfig || exit 4
echo "===== 结果 ====="
grep -E "qemu-ga|libudev|virtio-console" .config
echo "---- defconfig 后 qemu-ga 行数:"
grep -c "CONFIG_PACKAGE_qemu-ga=y" .config
