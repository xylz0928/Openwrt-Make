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

# ubuntu-26.04 新 runner 镜像的 install --version 输出不再含 "GNU"，
# 源树 prereq 的 `install --version | grep GNU` 会误杀整个构建（表现为
# "Please install GNU 'install'" 后每次 make 均在 prereq 阶段失败）。
# 此处放宽为只验证 install 可用，并打印真实输出留档便于追踪。
if [ -f include/prereq-build.mk ] && grep -q "install --version | grep GNU" include/prereq-build.mk; then
	sed -i 's/install --version | grep GNU/install --version/g' include/prereq-build.mk
	sed -i 's/ginstall --version | grep GNU/ginstall --version/g' include/prereq-build.mk
	echo "[prereq] install check relaxed for new runner image"
fi
echo "[prereq-diag] install --version => $(install --version 2>&1 | head -1)"
#

# Uncomment a feed source
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# sed -i -e '/^#/d' feeds.conf.default

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
# sed -i 's/#src-git helloworld/src-git helloworld/g' ./feeds.conf.default
# sed -i 's/coolsnowwolf/sirpdboy/g' ./feeds.conf.default
# git clone https://github.com/sirpdboy/sirpdboy-package package/diy
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
