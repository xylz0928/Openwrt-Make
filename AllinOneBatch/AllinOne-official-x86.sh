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
wget -q https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch1/diy-x86-official-part1.sh
wget -q https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch2/diy-x86-official-part2.sh
wget -q https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/config/MakeMenu.x86-official.config

# Run DIY part 1 (Before feeds update)
echo "==> Running diy-part1..."
bash diy-x86-official-part1.sh

# Update and install feeds
echo "==> Updating feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# Run DIY part 2 (After feeds update)
echo "==> Running diy-part2..."
bash diy-x86-official-part2.sh

# Copy configuration
echo "==> Applying configuration..."
cp MakeMenu.x86-official.config .config

# Download sources and start build
echo "==> Downloading source packages..."
make download -j$(nproc)

echo "==> Starting compilation (parallel threads=$(nproc))..."
make -j$(($(nproc)+1)) V=s
