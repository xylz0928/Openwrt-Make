include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-zed-opota
PKG_VERSION:=1.0
PKG_RELEASE:=2

PKG_MAINTAINER:=Zed-7nian <https://github.com/xylz0928>

# 与 pushbot 同款：强制 VERSION 为 PKG_VERSION-rPKG_RELEASE，
# 避免部分 luci.mk 版本规则忽略 PKG_RELEASE。
override VERSION:=$(if $(PKG_RELEASE),$(PKG_VERSION)-r$(PKG_RELEASE),$(PKG_VERSION))

LUCI_TITLE:=LuCI OTA online upgrade (official x86 firmware via GitHub Release)
LUCI_PKGARCH:=all
# curl：GitHub API/固件下载；jsonfilter：解析 API 响应；其余为 busybox/base 自带
LUCI_DEPENDS:=+luci-base +curl +jsonfilter

# 装/升级后必须让 uWSGI 各 worker 重建内存菜单树：
# dispatcher 里 `tree ??= build_pagetree()` —— 菜单树只在每个 worker 的首次请求
# 时构建、永不失效；若在 apk del→add 间隙或旧树存续期收到请求，新端点会命中
# 陈旧树返回 404（实机踩坑：space/log 均 404）。重启 uwsgi + 清索引缓存根治。
# 镜像构建期（IPKG_INSTROOT）跳过。
define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
rm -f /tmp/luci-indexcache* 2>/dev/null
if [ -x /etc/init.d/uwsgi ]; then
	/etc/init.d/uwsgi restart >/dev/null 2>&1 || true
fi
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
