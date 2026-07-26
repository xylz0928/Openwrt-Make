#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt Official DIY script part 1 (Before Update feeds)
# Base repository: openwrt/openwrt (官方主线)
#

# Uncomment a feed source
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# sed -i -e '/^#/d' feeds.conf.default

# Add third-party feed sources
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default
