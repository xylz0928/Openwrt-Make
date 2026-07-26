# Openwrt-Make - 自定义固件构建配置

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE)

## 项目结构

```
├── AllinOneBatch/          # 一键编译脚本
│   ├── AllinOne.sh            # LEDE x86_64 编译（主仓库）
│   ├── AllinOne-official-x86.sh # Official OpenWRT x86_64 编译
│   ├── AllinOne-798x.sh       # ImmortalWRT MT798x 编译
│   └── ...
├── config/                 # .config 配置文件
│   ├── MakeMenu.x86.config        # LEDE x86_64 配置
│   ├── MakeMenu.x86-official.config # Official x86_64 配置
│   └── ...
├── diy-batch1/             # 编译前 DIY 脚本 (feeds update 之前)
│   ├── diy-x86-part1.sh           # LEDE x86_64
│   ├── diy-x86-official-part1.sh  # Official x86_64
│   └── ...
├── diy-batch2/             # 编译后 DIY 脚本 (feeds update 之后)
│   ├── diy-x86-part2.sh           # LEDE x86_64
│   ├── diy-x86-official-part2.sh  # Official x86_64
│   └── ...
└── target/                 # 内核及其他资源
```

## 使用方式

### 本地编译

1. **LEDE 分支**（现有，功能最全）：
   ```bash
   bash AllinOneBatch/AllinOne.sh
   ```

2. **Official OpenWRT 主线**（新增，基于官方源码）：
   ```bash
   bash AllinOneBatch/AllinOne-official-x86.sh
   ```

### 区别说明

| 项目 | LEDE 分支 | Official 主线 |
|------|-----------|---------------|
| 基础仓库 | coolsnowwolf/lede | openwrt/openwrt |
| 分区配置 | 保留（TARGET_ROOTFS_PARTSIZE=1024） | 保留 |
| 目标平台 | x86_64 | x86_64 |
| 插件 | 完整（Passwall, Xray, SmartDNS等） | 完整（兼容官方feeds） |
| Theme | Argon | Argon |
| Banner | Zed-7nian 定制 | Zed-7nian 定制 |

## 配置文件说明

- `MakeMenu.x86*.config` — `.config` 文件，包含所有插件选择、目标平台、分区大小等设置
- `diy-*-part1.sh` — 在 `./scripts/feeds update -a` 之前执行的脚本
- `diy-*-part2.sh` — 在 `./scripts/feeds install -a` 之后执行的脚本

## 许可证

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © P3TERX
