# Openwrt-Make - 自定义固件构建与 OTA 在线升级

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE)

基于 GitHub Actions 的多线固件构建仓库，配套自研 **OTA 在线升级插件**（`luci-app-zed-opota`，
双源：GitHub Release + NAS 静态站），支持按固件家族（Official / LEDE）自动识别与切换升级通道。

## 目录结构

```
├── .github/workflows/       # GitHub Actions 构建工作流（活跃5 / 休眠11，见下）
├── config/                  # 各构建线的 .config（含插件选择、分区、OTA 插件选中）
├── diy-batch1/              # feeds update 之前执行的 DIY 脚本
├── diy-batch2/              # feeds install 之后执行的 DIY 脚本（主题/插件挂载、盖章）
├── package/luci-app-zed-opota/  # OTA 插件源（shell 助手 + ucode 控制器 + JS 前端 + menu.d）
├── last_build.txt           # OTA 固定版本文件（由 Actions 写回，浏览器与后端直读，零 api）
└── AllinOneBatch/           # 本地一键编译脚本
```

## 构建工作流（活跃 5 个）

| 工作流 | 源树 | 配置 | 触发 | 说明 |
|---|---|---|---|---|
| `build-openwrt-x86-opofficial.yml` | openwrt/openwrt @ master | `MakeMenu.x86-official.config` | 手动/事件/周五 11:10 UTC | x86 官方线，OTA 源之一 |
| `build-openwrt-x86.yml` | coolsnowwolf/lede @ master | `MakeMenu.x86.config` | 手动/事件/周五 14:10 UTC | x86 LEDE 线，OTA 源之一 |
| `build-openwrt-mt7981-24.10-6.6.yaml` | padavanonly immortalwrt-mt798x | `MakeMenu.mt7981.24.10.6.6.config` | 手动/事件/周五 14:00 UTC | 360T7(108M)+RAX3000M 双机，OTA 源之一 |
| `build-openwrt-mt7981-24.10-6.6-withClash.yaml` | 同上 | `…withClash.config` | 手动/事件 | 内置 OpenClash 版（定时已注释，按需手动触发） |
| `test-rsync-proxy.yml` | — | — | 手动/事件 | rsync/NAS 上传/OTA 写回验证 |

休眠 11 个：改名出 Actions 列表（`.disabled` / `.bak` / `.offline`），文件保留在仓库可随时恢复。

### 构建约定

- **Release tag 形态统一**：`OP_x86_Official_Ryyyy-mm-dd` / `OP_MT7981_Ryyyy-mm-dd` /
  `OP_MT7981_Clash_Ryyyy-mm-dd` / `OP_x86_LEDE_Ryyyy-mm-dd`；日期与固件盖章同源。
- **同日覆盖**：同日重复构建先删除当天旧 release 与其 tag 再重建。
- **OTA 关键文件门**（`otafiles`）：`squashfs-combined-efi.img.gz` + `sha256sums` 缺失即判失败，
  失败轮不发版、不写回（杜绝空 release）。
- **上限 30 ×3**：workflow runs、release、tag 一律保留最近 30（tag 由 release 关联清理 +
  孤儿 tag 修剪步骤维护）。

## OTA 体系

### 插件 `luci-app-zed-opota`

- 依赖仅 `libc / luci-base / curl / jsonfilter`（无 Lua）；当前版本 `PKG_VERSION=1.0`、`PKG_RELEASE=16`。
- 功能：版本检查（双源）、固件下载与 sha 校验、空间预检、`sysupgrade` 刷入、进度轮询、
  刷机倒计时与自动恢复、双侧可达性诊断、按型号/家族识别升级通道。
- **固件家族识别**：读 `/etc/openwrt_release` 的 `DISTRIB_DESCRIPTION` 与 `/etc/os-release`
  （`OPENWRT_RELEASE` / `PRETTY_NAME` / `VERSION`），含 `LEDE` 即判 LEDE 线，否则 Official 线；
  x86 型号行旁提供手动切换芯片，默认选中识别值。
- **产物线接线**：LEDE 线自动切换 tag 前缀（`OP_x86_LEDE_`）、固定文件行键（`x86_LEDE`）与
  NAS 静态两件套；Official 线对应 `OP_x86_Official_` / `x86_Official`。

### 固定版本文件 `last_build.txt`

```
格式：KEY=YYYY-MM-DD <资产体积字节> <构建UTC时间>
键：  x86_Official / MT7981 / Test / x86_LEDE
```

- 由对应工作流在「关键文件门通过 + 发版成功」后写回（`continue-on-error`，写回失败不阻断发版）。
- 浏览器（raw.githubusercontent.com，免配额）与路由器后端**都直接读它**，不经过任何 GitHub API。
- 体积由 `stat -c%s` 取真实值。

### 双源

| 源 | 形态 |
|---|---|
| GitHub Release | `https://github.com/xylz0928/Openwrt-Make/releases/download/<tag>/<资产>` + `sha256sums` |
| NAS 静态站 | `https://static.z.7ze.top:20443/files/<产物>` + 同名 `.sha256sums` |

### NAS 静态产物清单

```
OpenWrt-x64.img.gz            + build_date_openwrt.txt    # x86 官方线
LEDE-x64.img.gz                + build_date_lede.txt       # x86 LEDE 线
360-t7-108M.bin               + build_date_mt798x.txt     # MT7981 线
```


## 使用方式（本地编译）

```bash
bash AllinOneBatch/AllinOne.sh              # LEDE x86_64
bash AllinOneBatch/AllinOne-official-x86.sh # Official OpenWrt x86_64
```

| 项目 | LEDE 分支 | Official 主线 |
|------|-----------|---------------|
| 基础仓库 | coolsnowwolf/lede | openwrt/openwrt |
| 目标平台 | x86_64 | x86_64 |
| 插件 | 完整（Passwall, Xray, SmartDNS 等） | 完整（兼容官方 feeds） |
| Theme | Argon（v3 主题自带 compat 配置应用） | Argon |
| Banner | Zed-7nian 定制 | Zed-7nian 定制 |

## 许可证

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © P3TERX
