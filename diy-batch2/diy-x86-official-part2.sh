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


# 定义版本变量
CURRENT_REV=$(git describe --always 2>/dev/null || echo "Official")
DATE=$(TZ=Asia/Shanghai date -d '+5 hours' +%Y-%m-%d)
CUSTOM_VERSION="R${DATE}_by_Zed-7nian"
CUSTOM_REV="r${CURRENT_REV}_R${DATE}_by_Zed-7nian"

# 复制模板并替换占位符
mkdir -p files/etc/uci-defaults
wget -O files/etc/uci-defaults/99-custom-version https://github.com/xylz0928/Openwrt-Make/raw/refs/heads/main/files/etc/uci-defaults/99-custom-version
sed -i "s/@CUSTOM_VERSION@/${CUSTOM_VERSION}/g" files/etc/uci-defaults/99-custom-version
sed -i "s/@CUSTOM_REV@/${CUSTOM_REV}/g" files/etc/uci-defaults/99-custom-version
chmod +x files/etc/uci-defaults/99-custom-version

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
    echo "  %D %V, %C                          "
    echo "  timestamp                         "
    echo " -----------------------------------------------------"

} > /tmp/mark-official

> package/base-files/files/etc/banner
cat /tmp/mark-official >> package/base-files/files/etc/banner
sed -i "s/timestamp/Built on '$(TZ=Asia/Shanghai date +%Y-%m-%d -d +"5"hours)' by zed-7nian/g" package/base-files/files/etc/banner

# ----------------------------------------------#
# UI and Theme
# ----------------------------------------------#

# Change Language
sed -i "s/^\(\s*option\s\+lang\s\+\).*/\1'zh_cn'/" feeds/luci/modules/luci-base/root/etc/config/luci



# Change Argon Theme
# rm -rf ./package/lean/luci-theme-argon 
rm -rf ./feeds/luci/themes/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git feeds/luci/themes/luci-theme-argon
# Argon Theme 18.06
#git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git ./package/luci-theme-argon

git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git feeds/luci/applications/luci-app-argon-config

# Change default background image
mkdir -p feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img
wget -O feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg https://github.com/xylz0928/luci-mod/raw/main/Background/MontereyDark.jpg
# svn co https://github.com/xylz0928/luci-mod/trunk/feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons ./package/lucimod

# Change the default icons
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

# svn co --depth files https://github.com/xylz0928/luci-mod/trunk/feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons feeds/luci/modules/luci-base/htdocs/luci-static/resources/icons

# Change default theme
sed -i 's/bootstrap/argon/g' feeds/luci/collections/luci/Makefile

# Modify default IP
# sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
# Modify default Hostname
# sed -i 's/OpenWrt/Openwrtx86/g' package/base-files/files/bin/config_generate

# Re-enable SFE for 5.10
# sed -i 's/@!LINUX_5_10 //g' package/lean/luci-app-sfe/Makefile

# Add ServerChan
git clone https://github.com/tty228/luci-app-wechatpush.git package/luci-app-wechatpush
# Dependencies
git clone https://github.com/brvphoenix/wrtbwmon package/wrtbwmon
git clone https://github.com/brvphoenix/luci-app-wrtbwmon package/luci-app-wrtbwmon
# Add Onliner
git clone https://github.com/rufengsuixing/luci-app-onliner.git package/luci-app-onliner



# remove lede linked luci-app-pushbot
# rm -rf ./package/lean/luci-app-pushbot
rm -rf ./feeds/luci/applications/luci-app-pushbot
# Add PushBot
git clone https://github.com/zzsj0928/luci-app-pushbot package/luci-app-pushbot

# Add ADGuardHome
git clone https://github.com/xiaoxiao29/luci-app-adguardhome package/luci-app-adguardhome

# Add WOL Plus
mkdir package/luci-app-wolplus
cd package/luci-app-wolplus
git init
git remote add -f origin https://github.com/sundaqiang/openwrt-packages
git config core.sparseCheckout true
echo "luci-app-wolplus" >> .git/info/sparse-checkout
git pull origin master
cd ../../

# Add luci-app-socat
git clone https://github.com/chenmozhijin/luci-app-socat package/luci-app-socat

# Add luci-app-advanced
git clone https://github.com/sirpdboy/luci-app-advanced package/luci-app-advanced

# Add luci-app-netspeedtest
git clone https://github.com/sirpdboy/netspeedtest package/netspeedtest

# Remove the rependency of luci-app-speedtest
sed -i 's/ +python3-email//g' package/netspeedtest/luci-app-netspeedtest/Makefile
sed -i 's/ +python3-pkg-resources//g' package/netspeedtest/luci-app-netspeedtest/Makefile

# Add Poweroff
git clone https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff

# Add EasyTier
rm -rf feeds/packages/net/easytier
git clone https://github.com/EasyTier/luci-app-easytier package/luci-app-easytier


# Add OpenClash
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 https://github.com/vernesong/OpenClash.git package/luci-app-openclash

#----------------------------------------------#
### Old Apps
#----------------------------------------------#
# Add SmartDNS
# rm -rf ./feeds/packages/net/smartdns
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/luci-app-smartdns ./package/luci-app-smartdns
# svn co https://github.com/sirpdboy/sirpdboy-package/trunk/smartdns ./package/smartdns
# chmod -R 755 ./package/smartdns
# chmod -R 755 ./package/luci-app-smartdns

# Add OpenAppFilter
# git clone https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter

# Add Dockerman
# git clone https://github.com/lisaac/luci-app-dockerman package/luci-app-dockerman

#----------------------------------------------#
### Old Proxy
#----------------------------------------------#
## Add Nikki
# git clone https://github.com/nikkinikki-org/OpenWrt-nikki.git package/OpenWrt-nikki
#----------------------------------------------#


