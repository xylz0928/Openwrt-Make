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


# 切换ramips内核为 5.10
# sed -i 's/5.4/5.10/g' ./target/linux/ramips/Makefile

# 切换x86内核为 5.10
# sed -i 's/5.4/5.10/g' ./target/linux/x86/Makefile

# 修复核心及添加温度显示
# sed -i 's|pcdata(boardinfo.system or "?")|luci.sys.exec("uname -m") or "?"|g' feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index.htm
# sed -i 's/or "1"%>/or "1"%> ( <%=luci.sys.exec("expr `cat \/sys\/class\/thermal\/thermal_zone0\/temp` \/ 1000") or "?"%> \&#8451; ) /g' feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index.htm

sed -i 's/invalid/# invalid/g' package/network/services/samba36/files/smb.conf.template

# 修改版本号-webui
echo "sed -i '/DISTRIB_REVISION/d' /etc/openwrt_release" >> /tmp/release
echo "echo \"DISTRIB_REVISION='R24.5.5'\" >> /etc/openwrt_release" >> /tmp/release
echo "sed -i '/DISTRIB_DESCRIPTION/d' /etc/openwrt_release" >> /tmp/release
echo "echo \"DISTRIB_DESCRIPTION='ImmortalWRT '\" >> /etc/openwrt_release" >> /tmp/release
echo "exit 0" >> /tmp/release

sed -i '/exit 0/d' ./package/emortal/default-settings/files/99-default-settings
cat /tmp/release >> ./package/emortal/default-settings/files/99-default-settings


modelmark=R`TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours`' by xylz0928'
sed -i "s/DISTRIB_REVISION='R[0-9]*\.[0-9]*\.[0-9]*/DISTRIB_REVISION='$modelmark/g" ./package/emortal/default-settings/files/99-default-settings
sed -i "s/ImmortalWRT /ImmortalWRT $modelmark/g" ./package/emortal/default-settings/files/99-default-settings
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
echo " .___                               __         .__    " >> /tmp/mark
echo " |   | _____   _____   ____________/  |______  |  |   " >> /tmp/mark
echo " |   |/     \ /     \ /  _ \_  __ \   __\__  \ |  |   " >> /tmp/mark
echo " |   |  Y Y  \  Y Y  (  <_> )  | \/|  |  / __ \|  |__ " >> /tmp/mark
echo " |___|__|_|  /__|_|  /\____/|__|   |__| (____  /____/ " >> /tmp/mark
echo "           \/      \/  BE FREE AND UNAFRAID  \/       " >> /tmp/mark
echo " -----------------------------------------------------" >> /tmp/mark
echo "  %D %V, %C                                           " >> /tmp/mark
echo " -----------------------------------------------------" >> /tmp/mark


# sed -i '1,5d' ./package/base-files/files/etc/banner
# sed -i '1r /tmp/mark' ./package/base-files/files/etc/banner

> ./package/base-files/files/etc/banner
cat /tmp/mark >> ./package/base-files/files/etc/banner

# 修改版本号-tty
sed -i "s/timestamp/Built on '$(TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours)' by xylz0928/g" ./package/base-files/files/etc/banner
# echo ' Built on '$(TZ=UTC-8 date +%Y-%m-%d)' by xylz0928' >> ./package/base-files/files/etc/banner
# echo ' -----------------------------------------------------' >> ./package/base-files/files/etc/banner

# Modify index 
#sed -i 's|https://github.com/sirpdboy/openwrt/actions|https://github.com/xylz0928/Openwrt-Make/actions|g' ./package/diy/autocore/files/x86/index.htm
#sed -i 's|https://github.com/sirpdboy/openwrt18.06/issues|https://github.com/xylz0928/Openwrt-Make/issues|g' ./package/diy/autocore/files/x86/index.htm
#sed -i 's|固件TG聊天群|作者网站首页|g' ./package/diy/autocore/files/x86/index.htm
#sed -i 's|https://t.me/joinchat/AAAAAEpRF88NfOK5vBXGBQ|https://7ze.top|g' ./package/diy/autocore/files/x86/index.htm

# Change Argon Theme
# rm -rf ./package/lean/luci-theme-argon 
rm -rf ./feeds/luci/themes/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon.git ./package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git ./package/luci-app-argon-config

# Change default BackGround img
# rm ./package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
wget -O ./package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg https://github.com/xylz0928/luci-mod/raw/main/Background/MontereyDark.jpg
# svn co https://github.com/xylz0928/luci-mod/trunk/feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons ./package/lucimod
mkdir package/lucimod
cd package/lucimod
git init
git remote add -f origin https://github.com/xylz0928/luci-mod
git config core.sparseCheckout true
echo "feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons" >> .git/info/sparse-checkout
git pull origin main
cd ../../

mv package/lucimod/feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons/* feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons/

# Change default theme
sed -i 's/bootstrap/argon/g' feeds/luci/collections/luci/Makefile

# Modify default IP
# sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
# Modify default Hostname
sed -i 's/ImmortalWrt/Z-ImmortalWrt/g' package/base-files/files/bin/config_generate

# Re-enable SFE for 5.10
# sed -i 's/@!LINUX_5_10 //g' package/lean/luci-app-sfe/Makefile

# Add ServerChan
# git clone https://github.com/tty228/luci-app-serverchan.git feeds/luci/applications/luci-app-serverchan
# git clone https://github.com/tty228/luci-app-serverchan.git package/luci-app-serverchan
git clone https://github.com/tty228/luci-app-wechatpush.git package/luci-app-wechatpush
# Dependencies
git clone https://github.com/brvphoenix/wrtbwmon package/wrtbwmon
git clone https://github.com/brvphoenix/luci-app-wrtbwmon package/luci-app-wrtbwmon

# Add DDNS-Aliyun
git clone https://github.com/sensec/ddns-scripts_aliyun package/ddns-scripts_aliyun

# Add Onliner
# git clone https://github.com/rufengsuixing/luci-app-onliner.git feeds/luci/applications/luci-app-onliner
git clone https://github.com/rufengsuixing/luci-app-onliner.git package/luci-app-onliner

# Add OpenAppFilter
# git clone https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter

# Add Dockerman
# git clone https://github.com/lisaac/luci-app-dockerman package/luci-app-dockerman

# remove lede linked luci-app-pushbot
# rm -rf ./package/lean/luci-app-pushbot
rm -rf ./feeds/luci/applications/luci-app-pushbot
# Add PushBot
git clone https://github.com/zzsj0928/luci-app-pushbot package/luci-app-pushbot
git clone https://github.com/brvphoenix/wrtbwmon package/wrtbwmon

# Add Hello World VSSR
# svn co https://github.com/jerrykuku/luci-app-vssr/trunk/  package/diy/luci-app-vssr
# svn co https://github.com/siropboy/luci-app-vssr-plus/trunk/luci-app-vssr-plus package/new/luci-app-vssr-plus
# svn co https://github.com/ysx88/openwrt-packages/trunk/luci-app-vssr package/luci-app-vssr
git clone https://github.com/OpenWrt-Actions/luci-app-vssr.git package/luci-app-vssr

# Add Hello World SSR Plus+
git clone -b main https://github.com/fw876/helloworld.git package/helloworld

# git lua-maxminddb 依赖
git clone https://github.com/jerrykuku/lua-maxminddb.git package/lean/lua-maxminddb

# git clone https://github.com/jerrykuku/luci-app-vssr.git package/lean/luci-app-vssr

# Add Passwall
# Dependencies
git clone https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall-packages
#Passwall
git clone https://github.com/xiaorouji/openwrt-passwall package/openwrt-passwall
#Passwall2
git clone https://github.com/xiaorouji/openwrt-passwall2 package/luci-app-passwall2
# svn co https://github.com/xiaorouji/openwrt-passwall2/trunk/luci-app-passwall2 ./package/luci-app-passwall2
# chmod -R 755 ./package/luci-app-passwall2/*
# rm -rf ./package/openwrt-passwall/v2ray-*
# rm -rf ./package/openwrt-passwall/xray-*
# https://github.com/xiaorouji/openwrt-passwall/tree/luci/luci-app-passwall
# rm -rf ./package/lean/dns2socks
# rm -rf ./package/lean/ipt2socks
# rm -rf ./package/lean/kcptun
# rm -rf ./package/lean/microsocks
# rm -rf ./package/lean/shadowsocksr-libev
# rm -rf ./package/lean/simple-obfs
# rm -rf ./package/lean/tcping
# rm -rf ./package/lean/trojan
# rm -rf ./package/lean/v2ray
# rm -rf ./package/lean/v2ray-plugin
# rm -rf ./package/openwrt-passwall/naiveproxy
# rm -rf ./package/openwrt-passwall/tcping
# rm -rf ./package/openwrt-passwall/xray-core
# rm -rf ./package/openwrt-passwall/v2ray
# rm -rf ./package/openwrt-passwall/v2ray-plugin
# rm -rf ./feeds/helloworld/naiveproxy
# rm -rf ./feeds/helloworld/tcping
# rm -rf ./feeds/helloworld/xray-core


# Add ADGuardHome
# git clone https://github.com/rufengsuixing/luci-app-adguardhome package/luci-app-adguardhome
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-adguardhome ./package/luci-app-adguardhome
# chmod -R 755 ./package/luci-app-adguardhome/*
# mkdir package/luci-app-adguardhome
# cd package/luci-app-adguardhome
# git init
# git remote add -f origin https://github.com/sirpdboy/sirpdboy-package
# git config core.sparseCheckout true
# echo "luci-app-adguardhome" >> .git/info/sparse-checkout
# git pull origin main
# cd ../../
git clone https://github.com/xiaoxiao29/luci-app-adguardhome package/luci-app-adguardhome

#svn co https://github.com/sirpdboy/sirpdboy-package/trunk/adguardhome ./package/adguardhome
# sed -i 's/        /	/g' ./package/adguardhome/Makefile
#chmod -R 755 ./package/adguardhome/*
# mkdir package/adguardhome
# cd package/adguardhome
# git init
# git remote add -f origin https://github.com/sirpdboy/sirpdboy-package
# git config core.sparseCheckout true
# echo "adguardhome" >> .git/info/sparse-checkout
# git pull origin main
# cd ../../

# Add WOL Plus
# svn co https://github.com/sundaqiang/openwrt-packages/trunk/luci-app-wolplus ./package/luci-app-wolplus
# chmod -R 755 ./package/luci-app-wolplus/*
mkdir package/luci-app-wolplus
cd package/luci-app-wolplus
git init
git remote add -f origin https://github.com/sundaqiang/openwrt-packages
git config core.sparseCheckout true
echo "luci-app-wolplus" >> .git/info/sparse-checkout
git pull origin master
cd ../../

# Add KoolProxyR Plus+
# git clone https://github.com/jefferymvp/luci-app-koolproxyR package/luci-app-koolproxyR
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-koolproxyR ./package/luci-app-koolproxyR
# chmod -R 755 ./package/luci-app-koolproxyR/*

# Add GodProxy
git clone https://github.com/godros/luci-app-godproxy.git package/luci-app-godproxy

# Add luci-app-socat
# svn co https://github.com/Lienol/openwrt-package/trunk/luci-app-socat ./package/luci-app-socat
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-socat ./package/luci-app-socat
# chmod -R 755 ./package/luci-app-socat/*
# mkdir package/luci-app-socat
# cd package/luci-app-socat
# git init
# git remote add -f origin https://github.com/sirpdboy/sirpdboy-package
# git config core.sparseCheckout true
# echo "luci-app-socat" >> .git/info/sparse-checkout
# git pull origin main
# cd ../../
git clone https://github.com/chenmozhijin/luci-app-socat package/luci-app-socat

# Add luci-app-advanced
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-advanced ./package/luci-app-advanced
# chmod -R 755 ./package/luci-app-advanced/*
# mkdir package/luci-app-advanced
# cd package/luci-app-advanced
# git init
# git remote add -f origin https://github.com/sirpdboy/sirpdboy-package
# git config core.sparseCheckout true
# echo "luci-app-advanced" >> .git/info/sparse-checkout
# git pull origin main
# cd ../../
git clone https://github.com/sirpdboy/luci-app-advanced package/luci-app-advanced


# Add SmartDNS
# rm -rf ./feeds/packages/net/smartdns
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-smartdns ./package/luci-app-smartdns
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/smartdns ./package/smartdns
# chmod -R 755 ./package/smartdns
# chmod -R 755 ./package/luci-app-smartdns

# Add Poweroff
# git clone https://github.com/xylz0928/luci-app-shutdown package/luci-app-shutdown
git clone https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff
# curl -fsSL  https://raw.githubusercontent.com/siropboy/other/master/patch/poweroff/poweroff.htm > ./feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_system/poweroff.htm 
# curl -fsSL  https://raw.githubusercontent.com/siropboy/other/master/patch/poweroff/system.lua > ./feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua
# chmod -R 755 ./feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua
# chmod -R 755 ./feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_system/poweroff.htm

# Add ByPass
# svn co https://github.com/kiddin9/openwrt-packages/trunk/luci-app-bypass ./package/luci-app-bypass
# chmod -R 755 ./package/luci-app-bypass/*
mkdir package/luci-app-bypass
cd package/luci-app-bypass
git init
git remote add -f origin https://github.com/haiibo/openwrt-packages
# git remote add -f origin https://github.com/kiddin9/openwrt-packages
git config core.sparseCheckout true
echo "luci-app-bypass" >> .git/info/sparse-checkout
git pull origin master
cd ../../

# Add Nikki
git clone https://github.com/nikkinikki-org/OpenWrt-nikki.git package/OpenWrt-nikki

# Add luci-app-netspeedtest
git clone https://github.com/sirpdboy/luci-app-netspeedtest package/luci-app-netspeedtest

# Add OpenClash
# git clone -b master https://github.com/vernesong/OpenClash.git package/OpenClash
# svn co https://github.com/vernesong/OpenClash/trunk/luci-app-openclash ./package/luci-app-openclash
# chmod -R 755 ./package/luci-app-openclash/*

mkdir package/luci-app-openclash
cd package/luci-app-openclash
git init
git remote add -f origin https://github.com/vernesong/OpenClash
git config core.sparseCheckout true
echo "luci-app-openclash" >> .git/info/sparse-checkout
git pull origin master
cd ../../

# Fix Multi-use on one physical port 
# 修复 5.4.68-5.4.69内核 于 MIPS 架构 单线复用BUG
# 取自 @AmadeusGhost， 原更新内容为 generic: limit commit "ramips/mediatek: improve GRO performance, fix PPE packet parsing" to mediatek target only
# wget https://github.com/AmadeusGhost/lede/commit/7a49d2cf99bd59506bbd9239e0bde81a61f93c40.patch
# git apply 7a49d2cf99bd59506bbd9239e0bde81a61f93c40.patch
