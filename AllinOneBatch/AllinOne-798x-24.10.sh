#!/bin/bash
set -e
cd ~
git clone -b 2410 --single-branch --filter=blob:none https://github.com/padavanonly/immortalwrt-mt798x-6.6 immortalwrt-mt798x-24.10
cd immortalwrt-mt798x-24.10
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch1/diy-x86-part1.sh && \
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch2/diy-24.10-part2.sh && \
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/config/MakeMenu.mt7981.24.10.config
bash diy-x86-part1.sh && \
./scripts/feeds update -a && ./scripts/feeds install -a && \
bash diy-24.10-part2.sh

cp MakeMenu.mt7981.24.10.config .config

make download && \
make -j16 V=s
