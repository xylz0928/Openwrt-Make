include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-zed-opota
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Zed-7nian <https://github.com/xylz0928>

# 与 pushbot 同款：强制 VERSION 为 PKG_VERSION-rPKG_RELEASE，
# 避免部分 luci.mk 版本规则忽略 PKG_RELEASE。
override VERSION:=$(if $(PKG_RELEASE),$(PKG_VERSION)-r$(PKG_RELEASE),$(PKG_VERSION))

LUCI_TITLE:=LuCI OTA online upgrade (official x86 firmware via GitHub Release)
LUCI_PKGARCH:=all
# curl：GitHub API/固件下载；jsonfilter：解析 API 响应；其余为 busybox/base 自带
LUCI_DEPENDS:=+luci-base +curl +jsonfilter

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
