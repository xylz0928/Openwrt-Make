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
# Change Language
sed -i "s/^\(\s*option\s\+lang\s\+\).*/\1'zh_cn'/" feeds/luci/modules/luci-base/root/etc/config/luci

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

# 获取当前 git 版本（保留 r0-xxx 格式）
CURRENT_REV=$(git describe --always --dirty 2>/dev/null || echo "OP")
# 计算编译完成预计时间（+3 小时）
DATE=$(TZ=Asia/Shanghai date -d '+5 hours' +%Y-%m-%d)
# 拼接新版本
NEW_REV="${CURRENT_REV}_R${DATE}_by_Zed-7nian"

# 修改 include/version.mk 中的 REVISION 定义
sed -i "s/^REVISION:=.*/REVISION:=${NEW_REV}/" include/version.mk

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
    echo "  _______                     ________        __      "
    echo " |       |.-----.-----.-----.|  |  |  |.----.|  |_    "
    echo " |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|   "
    echo " |_______||   __|_____|__|__||________||__|  |____|   "
    echo "          |__| W I R E L E S S   F R E E D O M        "
    echo " -----------------------------------------------------"
    echo "  %D %V, %C                         "
    echo " -----------------------------------------------------"

} > /tmp/mark-official

> package/base-files/files/etc/banner
cat /tmp/mark-official >> package/base-files/files/etc/banner
# sed -i "s/timestamp/Built on '$(TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours)' by zed-7nian/g" package/base-files/files/etc/banner

# ----------------------------------------------#
# Plugins from LEDE build (compatible with official)
# ----------------------------------------------#

# Change Argon Theme
# rm -rf ./package/lean/luci-theme-argon 
rm -rf ./feeds/luci/themes/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon.git ./package/luci-theme-argon
# Argon Theme 18.06
#git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git ./package/luci-theme-argon
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
# git pull origin main
git pull origin immortalwrt-24.10
cd ../../

mv package/lucimod/feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons/* feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons/

# Change default theme
sed -i 's/bootstrap/argon/g' feeds/luci/collections/luci/Makefile

# Modify default IP
# sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
# Modify default Hostname
# sed -i 's/OpenWrt/Openwrtx86/g' package/base-files/files/bin/config_generate

# Remove the rependency of luci-app-speedtest
sed -i 's/ +python3-email//' package/netspeedtest/luci-app-speedtest/Makefile
sed -i 's/ +python3-pkg-resources//' package/netspeedtest/luci-app-speedtest/Makefile

# Remove the default apps
sed -i 's/luci-app-arpbind //g' include/target.mk >/dev/null 2>&1
sed -i 's/luci-app-filetransfer //g' include/target.mk >/dev/null 2>&1
sed -i 's/luci-app-vsftpd //g' include/target.mk >/dev/null 2>&1
sed -i 's/luci-app-ssr-plus //g' include/target.mk >/dev/null 2>&1
sed -i 's/luci-app-vlmcsd //g' include/target.mk >/dev/null 2>&1
sed -i 's/luci-app-accesscontrol //g' include/target.mk >/dev/null 2>&1
sed -i 's/luci-app-nlbwmon //g' include/target.mk >/dev/null 2>&1
sed -i 's/luci-app-turboacc //g' include/target.mk >/dev/null 2>&1
# sed -i 's/luci-app-sfe //g' target/linux/x86/Makefile
sed -i 's/luci-app-wol //g' include/target.mk >/dev/null 2>&1
# sed -i 's/-luci-app-flowoffload//g' target/linux/x86/Makefile
# sed -i 's/kmod-drm-amdgpu \\/kmod-drm-amdgpu/g' target/linux/x86/Makefile
sed -e '/luci-app-filetransfer/d' include/target.mk >/dev/null 2>&1
sed -e '/luci-app-vlmcsd/d' include/target.mk >/dev/null 2>&1
sed -e '/luci-app-flowoffload/d' include/target.mk >/dev/null 2>&1
# Re-enable SFE for 5.10
# sed -i 's/@!LINUX_5_10 //g' package/lean/luci-app-sfe/Makefile

# Add ServerChan
# git clone https://github.com/tty228/luci-app-serverchan.git feeds/luci/applications/luci-app-serverchan
# git clone https://github.com/tty228/luci-app-serverchan.git package/luci-app-serverchan
git clone https://github.com/tty228/luci-app-wechatpush.git package/luci-app-wechatpush
# Dependencies
git clone https://github.com/brvphoenix/wrtbwmon package/wrtbwmon
git clone https://github.com/brvphoenix/luci-app-wrtbwmon package/luci-app-wrtbwmon
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

# Add ADGuardHome
git clone https://github.com/xiaoxiao29/luci-app-adguardhome package/luci-app-adguardhome
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

# Add luci-app-netspeedtest
git clone https://github.com/sirpdboy/netspeedtest package/netspeedtest

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



# Add EasyTier
rm -rf feeds/packages/net/easytier
git clone https://github.com/EasyTier/luci-app-easytier package/luci-app-easytier



# Add OpenClash
# git clone -b master https://github.com/vernesong/OpenClash.git package/OpenClash
# svn co https://github.com/vernesong/OpenClash/trunk/luci-app-openclash ./package/luci-app-openclash
# chmod -R 755 ./package/luci-app-openclash/*
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 https://github.com/vernesong/OpenClash.git package/luci-app-openclash
# mkdir package/luci-app-openclash
# cd package/luci-app-openclash
# git clone --depth=1 https://github.com/vernesong/OpenClash.git
# git init
# git remote add -f origin https://github.com/vernesong/OpenClash
# git config core.sparseCheckout true
# echo "luci-app-openclash" >> .git/info/sparse-checkout
# git pull origin master
# cd ../../



#----------------------------------------------#
#----------------------------------------------#
#----------------------------------------------#
### Old Apps
#----------------------------------------------#
## Add GodProxy
# git clone https://github.com/godros/luci-app-godproxy.git package/luci-app-godproxy
#----------------------------------------------#
#----------------------------------------------#
#----------------------------------------------#
### Old Proxy
#----------------------------------------------#
## Add Nikki
# git clone https://github.com/nikkinikki-org/OpenWrt-nikki.git package/OpenWrt-nikki
#----------------------------------------------#
## Add ByPass
## svn co https://github.com/kiddin9/openwrt-packages/trunk/luci-app-bypass ./package/luci-app-bypass
## chmod -R 755 ./package/luci-app-bypass/*
# mkdir package/luci-app-bypass
# cd package/luci-app-bypass
# git init
# git remote add -f origin https://github.com/haiibo/openwrt-packages
## git remote add -f origin https://github.com/kiddin9/openwrt-packages
# git config core.sparseCheckout true
# echo "luci-app-bypass" >> .git/info/sparse-checkout
# git pull origin master
# cd ../../
#----------------------------------------------#
## Add Passwall
## Dependencies
# rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
# git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
## git clone https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall-packages
## Passwall
# rm -rf feeds/luci/applications/luci-app-passwall
# git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
## git clone https://github.com/xiaorouji/openwrt-passwall package/openwrt-passwall
#----------------------------------------------#
## Passwall2
## git clone https://github.com/xiaorouji/openwrt-passwall2 package/luci-app-passwall2
## svn co https://github.com/xiaorouji/openwrt-passwall2/trunk/luci-app-passwall2 ./package/luci-app-passwall2
## chmod -R 755 ./package/luci-app-passwall2/*
## rm -rf ./package/openwrt-passwall/v2ray-*
## rm -rf ./package/openwrt-passwall/xray-*
## https://github.com/xiaorouji/openwrt-passwall/tree/luci/luci-app-passwall
## rm -rf ./package/lean/dns2socks
## rm -rf ./package/lean/ipt2socks
## rm -rf ./package/lean/kcptun
## rm -rf ./package/lean/microsocks
## rm -rf ./package/lean/shadowsocksr-libev
## rm -rf ./package/lean/simple-obfs
## rm -rf ./package/lean/tcping
## rm -rf ./package/lean/trojan
## rm -rf ./package/lean/v2ray
## rm -rf ./package/lean/v2ray-plugin
## rm -rf ./package/openwrt-passwall/naiveproxy
## rm -rf ./package/openwrt-passwall/tcping
## rm -rf ./package/openwrt-passwall/xray-core
## rm -rf ./package/openwrt-passwall/v2ray
## rm -rf ./package/openwrt-passwall/v2ray-plugin
## rm -rf ./feeds/helloworld/naiveproxy
## rm -rf ./feeds/helloworld/tcping
# rm -rf ./feeds/helloworld/xray-plugin
# rm -rf ./package/helloworld/xray-plugin
#----------------------------------------------#
## Add Hello World VSSR
## svn co https://github.com/jerrykuku/luci-app-vssr/trunk/  package/diy/luci-app-vssr
## svn co https://github.com/siropboy/luci-app-vssr-plus/trunk/luci-app-vssr-plus package/new/luci-app-vssr-plus
## svn co https://github.com/ysx88/openwrt-packages/trunk/luci-app-vssr package/luci-app-vssr
## git clone https://github.com/jerrykuku/luci-app-vssr.git package/lean/luci-app-vssr
# git clone https://github.com/OpenWrt-Actions/luci-app-vssr.git package/luci-app-vssr
#----------------------------------------------#
## Add Hello World SSR Plus+
# git clone -b master https://github.com/fw876/helloworld.git package/helloworld
## rm -rf ./package/helloworld/shadowsocksr-libev
## mkdir package/tmp_helloworld
## mkdir package/tmp_helloworld/shadowsocksr-libev
## cd package/tmp_helloworld/shadowsocksr-libev
## git init
## git remote add -f origin https://github.com/sbwml/openwrt_helloworld
## git config core.sparseCheckout true
## echo "shadowsocksr-libev" >> .git/info/sparse-checkout
## git pull origin v5
## cd ../../../
## mv ./package/tmp_helloworld/shadowsocksr-libev/shadowsocksr-libev ./package/helloworld/shadowsocksr-libev
## rm -rf ./package/tmp_helloworld
## git lua-maxminddb 依赖
# git clone https://github.com/jerrykuku/lua-maxminddb.git package/lean/lua-maxminddb


# Fix Multi-use on one physical port 
# 修复 5.4.68-5.4.69内核 于 MIPS 架构 单线复用BUG
# 取自 @AmadeusGhost， 原更新内容为 generic: limit commit "ramips/mediatek: improve GRO performance, fix PPE packet parsing" to mediatek target only
# wget https://github.com/AmadeusGhost/lede/commit/7a49d2cf99bd59506bbd9239e0bde81a61f93c40.patch
# git apply 7a49d2cf99bd59506bbd9239e0bde81a61f93c40.patch

