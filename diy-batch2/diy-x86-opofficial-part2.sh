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

# 添加Lean
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean ./package/lean/
chmod -R 755 ./package/lean/*

rm -rf package/lean/luci-app-docker
rm -rf package/lean/qt5
rm -rf package/lean/qBittorrent
rm -rf package/lean/luci-app-qbittorrent

# Passwall 编译依赖
svn co https://github.com/coolsnowwolf/lede/trunk/tools/ucl ./tools/ucl
chmod -R 755 ./tools/ucl
svn co https://github.com/coolsnowwolf/lede/trunk/tools/upx ./tools/upx
chmod -R 755 ./tools/upx
echo '$(curdir)/upx/compile := $(curdir)/ucl/compile' >> ./tools/Makefile
echo "tools-y += ucl upx" >> ./tools/Makefile


# autosamba 依赖 samba
svn co https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-samba ./package/collected/luci-app-samba
chmod -R 755 ./package/collected/luci-app-samba
sed -i "s|../../luci.mk|../../../feeds/luci/luci.mk|g" ./package/collected/luci-app-samba/Makefile

svn co https://github.com/coolsnowwolf/lede/trunk/package/network/services/samba36 ./package/collected/samba36
chmod -R 755 ./package/collected/samba36


# 修改版本号-webui
modelmark=R`TZ=UTC-8 date +%Y-%m-%d -d +"0"days`' by xylz0928'
sed -i "s/DISTRIB_REVISION='R[0-9]*\.[0-9]*\.[0-9]*/DISTRIB_REVISION='$modelmark/g" ./package/lean/default-settings/files/zzz-default-settings


# 修改tty banner


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

sed -i '1,5d' ./package/base-files/files/etc/banner
sed -i '1r /tmp/mark' ./package/base-files/files/etc/banner

# 修改版本号-tty
echo ' Built on '$(TZ=UTC-8 date +%Y-%m-%d)' by xylz0928' >> ./package/base-files/files/etc/banner
echo ' -----------------------------------------------------' >> ./package/base-files/files/etc/banner

# Change Argon Theme
rm -rf ./package/lean/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon.git ./package/collected/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git ./package/collected/luci-app-argon-config

# Change default BackGround img
wget -O ./package/collected/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg https://github.com/xylz0928/Openwrt-Make-x86_7621/raw/main/BigSurLight.jpg
svn co https://github.com/xylz0928/luci-mod/trunk/feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons ./package/collected/lucimod
mv package/collected/lucimod/* feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons/


# Change default theme
sed -i 's/bootstrap/argon/g' feeds/luci/collections/luci/Makefile


# Add ServerChan
git clone https://github.com/tty228/luci-app-serverchan.git package/collected/luci-app-serverchan

# Add Onliner
git clone https://github.com/rufengsuixing/luci-app-onliner.git package/collected/luci-app-onliner

# Add OpenAppFilter
git clone https://github.com/destan19/OpenAppFilter.git package/collected/OpenAppFilter


# Add PushBot
git clone https://github.com/zzsj0928/luci-app-pushbot package/collected/luci-app-pushbot

# Add Hello World
git clone https://github.com/jerrykuku/luci-app-vssr.git package/lean/luci-app-vssr
#git lua-maxminddb 依赖
git clone https://github.com/jerrykuku/lua-maxminddb.git package/lean/lua-maxminddb


# Add Passwall
git clone https://github.com/xiaorouji/openwrt-passwall package/collected/openwrt-passwall
rm -rf ./package/lean/dns2socks
rm -rf ./package/lean/ipt2socks
rm -rf ./package/lean/kcptun
rm -rf ./package/lean/microsocks
rm -rf ./package/lean/shadowsocksr-libev
rm -rf ./package/lean/simple-obfs
rm -rf ./package/lean/tcping
rm -rf ./package/lean/trojan
# rm -rf ./package/lean/v2ray
rm -rf ./package/lean/v2ray-plugin
rm -rf ./package/collected/openwrt-passwall/naiveproxy
rm -rf ./package/collected/openwrt-passwall/tcping
rm -rf ./package/collected/openwrt-passwall/xray-core
rm -rf ./package/collected/openwrt-passwall/v2ray
# rm -rf ./package/openwrt-passwall/v2ray-plugin
# rm -rf ./feeds/helloworld/naiveproxy
# rm -rf ./feeds/helloworld/tcping
# rm -rf ./feeds/helloworld/xray-core


# Add OpenClash
git clone -b master https://github.com/vernesong/OpenClash.git package/collected/OpenClash

# Add ADGuardHome
# git clone https://github.com/rufengsuixing/luci-app-adguardhome package/luci-app-adguardhome
svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-adguardhome ./package/collected/luci-app-adguardhome
chmod -R 755 ./package/collected/luci-app-adguardhome/*
svn co https://github.com/sirpdboy/sirpdboy-package/trunk/adguardhome ./package/collected/adguardhome
chmod -R 755 ./package/collected/adguardhome/*

# Add WOL Plus
svn co https://github.com/sundaqiang/openwrt-packages/trunk/luci-app-services-wolplus ./package/collected/luci-app-wolplus
chmod -R 755 ./package/collected/luci-app-wolplus/*

# Add KoolProxyR Plus+
# git clone https://github.com/jefferymvp/luci-app-koolproxyR package/luci-app-koolproxyR
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-koolproxyR ./package/collected/luci-app-koolproxyR
# chmod -R 755 ./package/collected/luci-app-koolproxyR/*

# Add GodProxy
git clone https://github.com/godros/luci-app-godproxy.git package/collected/luci-app-godproxy

# Add luci-app-socat
# svn co https://github.com/Lienol/openwrt-package/trunk/luci-app-socat ./package/collected/luci-app-socat
svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-socat ./package/collected/luci-app-socat
chmod -R 755 ./package/collected/luci-app-socat/*

# Add luci-app-advanced
svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-advanced ./package/collected/luci-app-advanced
chmod -R 755 ./package/collected/luci-app-advanced/*


# Add SmartDNS
# rm -rf ./feeds/packages/net/smartdns
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-smartdns ./package/luci-app-smartdns
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/smartdns ./package/smartdns
# chmod -R 755 ./package/smartdns
# chmod -R 755 ./package/luci-app-smartdns

# Add Poweroff
# git clone https://github.com/xylz0928/luci-app-shutdown package/luci-app-shutdown
git clone https://github.com/esirplayground/luci-app-poweroff package/collected/luci-app-poweroff
# curl -fsSL  https://raw.githubusercontent.com/siropboy/other/master/patch/poweroff/poweroff.htm > ./feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_system/poweroff.htm 
# curl -fsSL  https://raw.githubusercontent.com/siropboy/other/master/patch/poweroff/system.lua > ./feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua
# chmod -R 755 ./feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua
# chmod -R 755 ./feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_system/poweroff.htm
