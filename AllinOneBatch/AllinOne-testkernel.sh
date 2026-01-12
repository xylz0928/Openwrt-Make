#!/bin/bash
set -e
cd ~
git clone https://github.com/coolsnowwolf/lede
cd lede
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch1/diy-x86-part1.sh && \
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/diy-batch2/diy-x86-part2.sh && \
wget https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/config/MakeMenu.x86_TestKernel.config
bash diy-x86-part1.sh && \
./scripts/feeds update -a && ./scripts/feeds install -a && \
bash diy-x86-part2.sh

cp MakeMenu.x86_TestKernel.config .config

make download && \
make -j16 V=s
