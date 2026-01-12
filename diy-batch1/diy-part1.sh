#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

sed -i -e '/^#/d' feeds.conf.default

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
sed -i '$a src-git helloworld https://github.com/fw876/helloworld' feeds.conf.default
# sed -i '$a src-git luciappwrtbwmon https://github.com/brvphoenix/luci-app-wrtbwmon' feeds.conf.default
# sed -i '$a src-git wrtbwmon https://github.com/brvphoenix/wrtbwmon' feeds.conf.default
# sed -i '$a src-git smartdns https://github.com/pymumu/smartdns' feeds.conf.default
# sed -i '$a src-git luci-app-smartdns https://github.com/pymumu/luci-app-smartdns' feeds.conf.default
# sed -i '$a src-git onliner https://github.com/rufengsuixing/luci-app-onliner' feeds.conf.default
# sed -i '$a src-git luci-app-serverchan https://github.com/tty228/luci-app-serverchan' feeds.conf.default

# echo 'src-git helloworld https://github.com/fw876/helloworld' >> feeds.conf.default
# echo 'src-git luciappwrtbwmon https://github.com/brvphoenix/luci-app-wrtbwmon' >> feeds.conf.default
# echo 'src-git wrtbwmon https://github.com/brvphoenix/wrtbwmon' >> feeds.conf.default
# echo 'src-git smartdns https://github.com/pymumu/smartdns' >> feeds.conf.default
# echo 'src-git luciappsmartdns https://github.com/pymumu/luci-app-smartdns' >> feeds.conf.default
# echo 'src-git onliner https://github.com/rufengsuixing/luci-app-onliner' >> feeds.conf.default
# echo 'src-git luciappserverchan https://github.com/tty228/luci-app-serverchan' >> feeds.conf.default
