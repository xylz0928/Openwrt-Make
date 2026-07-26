#!/bin/bash
# ============================================================
# AllinOne Build Script - Official OpenWRT (x86_64)
# Base repository: openwrt/openwrt (官方主线)
# Maintainer: xylz0928
# ============================================================
set -e

cd ~

# Clone official OpenWRT repository
echo "==> Cloning official OpenWRT..."
git clone --depth 1 https://github.com/openwrt/openwrt.git openwrt-official
cd openwrt-official

# Download DIY scripts from repository
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch1/diy-x86-official-part1.sh && \
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch2/diy-x86-official-part2.sh && \
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/config/MakeMenu.x86-official.config


bash diy-x86-official-part1.sh && \
./scripts/feeds update -a && ./scripts/feeds install -a && \
bash diy-x86-official-part2.sh


cp MakeMenu.x86-official.config .config


make download -j$(nproc) && \
make -j$(($(nproc)+1)) V=s
