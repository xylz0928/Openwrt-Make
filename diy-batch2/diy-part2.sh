#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
sed -i 's/bootstrap/argon/g' feeds/luci/collections/luci/Makefile


# 修改版本号-webui
modelmark=R`TZ=UTC-8 date +%Y-%m-%d -d +"0"days`' by xylz0928'
sed -i "s/DISTRIB_REVISION='R[0-9]*\.[0-9]*\.[0-9]*/DISTRIB_REVISION='$modelmark/g" ./package/lean/default-settings/files/zzz-default-settings
# sed -i 's/$(VERSION_DIST_SANITIZED)/$(VERSION_DIST_SANITIZED)-${modelmark}/g' include/image.mk
# sed -i 's/$(VERSION_DIST_SANITIZED)/$(VERSION_DIST_SANITIZED)-$(shell TZ=UTC-8 date +%Y.%m.%d)_By_xylz0928/g' include/image.mk
# echo "DISTRIB_REVISION='${modelmark}'" > ./package/base-files/files/etc/openwrt_release
# sed -i "s/DISTRIB_REVISION='/DISTRIB_REVISION='$(TZ=UTC-8 date +%Y-%m-%d) by xylz0928 /g" ./package/base-files/files/etc/openwrt_release


# 修改tty banner
echo " -----------------------------------------------------" >> /tmp/mark
echo "      █      █  ▚           ▟               █         " >> /tmp/mark
echo "     █████   █      █████████     █        █████████  " >> /tmp/mark
echo "    █ ▃ ██ ██████   ██            █        █   ██     " >> /tmp/mark
echo "  ██ ▃ ██   █ █     █████████     ██████ ██ ████████  " >> /tmp/mark
echo "     ██    █   █    █ ██████  ███▟          █  ██     " >> /tmp/mark
echo "   ██     █     ██  █ █    █      █         █  ██     " >> /tmp/mark
echo "    ▞  ▚   ▚   ▚    █ █    █      █   █  ████████████ " >> /tmp/mark
echo "  ▞▞▞  ▚▚▚ ▚▚▚ ▚▚▚ ▟  ██████      █████        ██     " >> /tmp/mark
echo "                                               ██     " >> /tmp/mark
echo " -----------------------------------------------------" >> /tmp/mark
echo "     _________       _    ___ ___  ___                " >> /tmp/mark
echo "    /        /\     | |  | __|   \| __|               " >> /tmp/mark
echo "   /  LE    /  \    | |__| _|| |) | _|                " >> /tmp/mark
echo "  /    DE  /    \   |____|___|___/|___|               " >> /tmp/mark
echo " /________/  LE  \                                    " >> /tmp/mark
echo " \        \   DE / -----------------------------------" >> /tmp/mark
echo "  \    LE  \    /  %D %V, %C                          " >> /tmp/mark
echo "   \  DE    \  /   timestamp                          " >> /tmp/mark
echo "    \________\/    -----------------------------------" >> /tmp/mark

# echo "      █      █  ▚           ▟               █         " >> /tmp/mark
# echo "     █████   █      █████████     █        █████████  " >> /tmp/mark
# echo "    █ ▃ ██ ██████   ██            █        █   ██     " >> /tmp/mark
# echo "  ██ ▃ ██   █ █     █████████     ██████ ██ ████████  " >> /tmp/mark
# echo "     ██    █   █    █ ██████  ███▟          █  ██     " >> /tmp/mark
# echo "   ██     █     ██  █ █    █      █         █  ██     " >> /tmp/mark
# echo "    ▞  ▚   ▚   ▚    █ █    █      █   █  ████████████ " >> /tmp/mark
# echo "  ▞▞▞  ▚▚▚ ▚▚▚ ▚▚▚ ▟  ██████      █████        ██     " >> /tmp/mark
# echo "                                               ██     " >> /tmp/mark
# echo " -----------------------------------------------------" >> /tmp/mark

# echo "    @:     @L                                 @          " >> /tmp/mark
# echo "    @@,,L. @0@@.     @@@@@@@@t     @L        @@;;;;;;f1  " >> /tmp/mark
# echo "  ;@@8 @@  @t :.     @;            @f        @@   @@     " >> /tmp/mark
# echo ",@@G G@@  @@@        @@00000@@,    @L8@@C  @0 CCC@@CC01  " >> /tmp/mark
# echo "    @@@  @@ @@       @ L1;;fi   @@@f          8@  @@     " >> /tmp/mark
# echo "  @@@  G@@   0@@@   @@ @@   @,     @f         8@  @@     " >> /tmp/mark
# echo "   @@ L@ @@  @@    ,@8 @@   @.     @f   @t :Liiiii@@iiiG " >> /tmp/mark
# echo "  @@, 0@, @@  @@G @@@  @@@@@@;     @@@@@1         @@     " >> /tmp/mark
# echo " ;                                                tt     " >> /tmp/mark
# echo " -----------------------------------------------------" >> /tmp/mark

# sed -i '1,5d' ./package/base-files/files/etc/banner
# sed -i '1r /tmp/mark' ./package/base-files/files/etc/banner

> ./package/base-files/files/etc/banner
cat /tmp/mark >> ./package/base-files/files/etc/banner

# 修改版本号-tty
sed -i "s/timestamp/Built on '$(TZ=UTC-8 date +%Y-%m-%d)' by xylz0928/g" ./package/base-files/files/etc/banner
# echo ' Built on '$(TZ=UTC-8 date +%Y-%m-%d)' by xylz0928' >> ./package/base-files/files/etc/banner
# echo ' -----------------------------------------------------' >> ./package/base-files/files/etc/banner

# Add ServerChan
# git clone https://github.com/tty228/luci-app-serverchan.git feeds/luci/applications/luci-app-serverchan
git clone https://github.com/tty228/luci-app-serverchan.git package/luci-app-serverchan

# Add Onliner
# git clone https://github.com/rufengsuixing/luci-app-onliner.git feeds/luci/applications/luci-app-onliner
git clone https://github.com/rufengsuixing/luci-app-onliner.git package/luci-app-onliner


# Add OpenAppFilter
git clone https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter


# Add PushBot
git clone https://github.com/zzsj0928/luci-app-pushbot package/luci-app-pushbot


# Fix Multi-use on one physical port 
# 修复 5.4.68-5.4.69内核 于 MIPS 架构 单线复用BUG
# 取自 @AmadeusGhost， 原更新内容为 generic: limit commit "ramips/mediatek: improve GRO performance, fix PPE packet parsing" to mediatek target only
# wget https://github.com/AmadeusGhost/lede/commit/7a49d2cf99bd59506bbd9239e0bde81a61f93c40.patch
# git apply 7a49d2cf99bd59506bbd9239e0bde81a61f93c40.patch
