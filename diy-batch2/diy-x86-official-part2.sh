#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt Official DIY script part 2 (After Update feeds)
# Base repository: openwrt/openwrt (official)
#

# ----------------------------------------------#
# Theme & Banner - same as LEDE build
# ----------------------------------------------#

# Change default theme to argon
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git feeds/luci/themes/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git feeds/luci/applications/luci-app-argon-config
sed -i 's/bootstrap/argon/g' feeds/luci/collections/luci/Makefile

# Change default background image
mkdir -p feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img
wget -O feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg https://github.com/xylz0928/Openwrt-Make-x86_7621/raw/main/BigSurLight.jpg

# Change icons
svn co --depth files https://github.com/xylz0928/luci-mod/trunk/feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons

# Modify version info - web UI
modelmark_os=R$(TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours)_by_Zed-7nian
modelmark_os_lower=r$(TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours)_by_zed-7nian
modelmark=R`TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours`' by Zed-7nian'

# Create os-release patch script
{
    echo "sed -i \"s/VERSION=\\\".*\\\"/VERSION=\\\"$modelmark_os\\\"/g\" /etc/os-release"
    echo "sed -i \"s/PRETTY_NAME=\\\".*\\\"/PRETTY_NAME=\\\"OpenWrt $modelmark_os\\\"/g\" /etc/os-release"
    echo "sed -i \"s/VERSION_ID=\\\".*\\\"/VERSION_ID=\\\"$modelmark_os_lower\\\"/g\" /etc/os-release"
    echo "sed -i 's|https://openwrt.org/|https://7nian.top/|g' /etc/os-release"
    echo "sed -i 's|https://forum.openwrt.org|https://github.com/xylz0928/Openwrt-Make/actions|g' /etc/os-release"
    echo "sed -i 's|https://bugs.openwrt.org|https://github.com/xylz0928/Openwrt-Make/issues|g' /etc/os-release"
    echo "exit 0"
} > /tmp/release-official

# Patch luci-base Makefile to run our os-release changes
sed -i '/^exit 0/d' feeds/luci/luci-base/Makefile
cat /tmp/release-official >> feeds/luci/luci-base/Makefile

# Modify tty banner
{
    echo " -----------------------------------------------------"
    echo "      █      █  ▚           ▟               █         "
    echo "     █████   █      █████████     █        █████████  "
    echo "    █ ▃ ██ ██████   ██            █        █   ██     "
    echo "  ██ ▃ ██   █ █     █████████     ██████ ██ ████████  "
    echo "     ██    █   █    █ ██████  ███▟          █  ██     "
    echo "   ██     █     ██  █ █    █      █         █  ██     "
    echo "    ▞  ▚   ▚   ▚    █ █    █      █   █  ████████████ "
    echo "  ▞▞▞  ▚▚▚ ▚▚▚ ▚▚▚ ▟  ██████      █████        ██     "
    echo "                                               ██     "
    echo " -----------------------------------------------------"
    echo "     _________       _    ___ ___  ___                "
    echo "    /        /\     | |  | __|   \| __|               "
    echo "   /  OFI   /  \    | |__| _|| |) | _|                "
    echo "  /    FI  /    \   |____|___|___/|___|               "
    echo " /________/  OFI  \                                    "
    echo " \        \   FI / -----------------------------------"
    echo "  \    OFI \   /  %D %V, %C                          "
    echo "   \  FI    \  /   timestamp                          "
    echo "    \________\/    -----------------------------------"
} > /tmp/mark-official

> feeds/luci/luci-base/root/etc/banner
cat /tmp/mark-official >> feeds/luci/luci-base/root/etc/banner
sed -i "s/timestamp/Built on '$(TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours)' by zed-7nian/g" feeds/luci/luci-base/root/etc/banner

# ----------------------------------------------#
# Plugins from LEDE build (compatible with official)
# ----------------------------------------------#

## Add Hello World (SSR Plus+)
echo "src-git helloworld https://github.com/fw876/helloworld" >> ./feeds.conf.default

## Add Passwall packages
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

## Add Passwall (Luci)
rm -rf feeds/luci/applications/luci-app-passwall
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci

## Add cloudflared
rm -rf feeds/packages/net/cloudflared
git clone --depth 1 https://github.com/rqydhy/cloudflared-for-openwrt package/cloudflared

## Add SmartDNS
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/applications/luci-app-smartdns
git clone --depth 1 https://github.com/pymumu/smartdns feeds/packages/net/smartdns
git clone --depth 1 https://github.com/pymumu/luci-app-smartdns feeds/luci/applications/luci-app-smartdns

## Add luci-app-onliner
git clone --depth 1 https://github.com/rufengsuixing/luci-app-onliner.git feeds/luci/applications/luci-app-onliner

## Add ServerChan
git clone --depth 1 https://github.com/tty228/luci-app-serverchan.git feeds/luci/applications/luci-app-serverchan

## Add PushBot
git clone --depth 1 https://github.com/zzsj0928/luci-app-pushbot.git package/luci-app-pushbot

## Add Adbyby
git clone --depth 1 https://github.com/tindy2013/openwrt-packages.git package/adbyby-repo
cp -r package/adbyby-repo/subscribes-reply package/
cp -r package/adbyby-repo/luci-app-adbyby-plus package/
rm -rf package/adbyby-repo

## Add easytier
rm -rf feeds/packages/utils/easytier
git clone --depth 1 https://github.com/EasyTier/easytier package/easytier-core
cp -r package/easytier/package/openwrt easytier-openwrt
rm -rf package/easytier
mv easytier-openwrt package/easytier

## Add UWSGI (same as LEDE build)
mkdir -p package/uwsgi
cd package/uwsgi
git init
git remote add origin https://github.com/immortalwrt/packages.git
git config core.sparsecheckout true
echo "net/uwsgi/*" >> .git/info/sparse-checkout
git pull origin master
rm -rf net/uwsgi/files-luci-support
cd ../..
cp -r feeds/packages/net/uwsgi/files-luci-support package/uwsgi/net/uwsgi/
rm -rf feeds/packages/net/uwsgi/*
mv package/uwsgi/net/uwsgi/* feeds/packages/net/uwsgi/
rm -rf package/uwsgi

# ----------------------------------------------#
# Old proxy apps (commented, enable as needed)
# ----------------------------------------------#

## Add VSSR
# git clone --depth 1 https://github.com/OpenWrt-Actions/luci-app-vssr.git feeds/luci/applications/luci-app-vssr

## Add lua-maxminddb (VSSR dependency)
# git clone --depth 1 https://github.com/jerrykuku/lua-maxminddb.git package/lean/lua-maxminddb
