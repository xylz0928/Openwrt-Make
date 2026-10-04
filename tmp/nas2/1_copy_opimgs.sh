#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/0_functions.sh"

log "===== 开始固件传输流程 ====="

# 初始化变量
# DATE_FILE="/volume1/docker/nginx-ui/data/static/files/build_date_lede.txt"
DATE_FILE="/volume7/Documents/docker-files/static/files/build_date_lede.txt"
rm -f "$DATE_FILE"

# 1. 处理x86固件
process_firmware "/volume3/OpenwrtImgs/x86_64/x64" \
    "openwrt-x86-64-generic-squashfs-combined-efi.img.gz" \
    "/volume7/Documents/docker-files/static/files/LEDE-x64.img.gz" \
    "$DATE_FILE"

# 1.1 处理x86官方固件
process_firmware "/volume3/OpenwrtImgs/x86_64/x64-official" \
    "openwrt-x86-64-generic-squashfs-combined-efi.img.gz" \
    "/volume7/Documents/docker-files/static/files/OpenWrt-x64.img.gz" \
    "/volume7/Documents/docker-files/static/files/build_date_openwrt.txt"

# 2. 处理360T7-6.6固件
process_firmware "/volume3/OpenwrtImgs/mt7981/360T7_108M_24.10_6.6" \
    "immortalwrt-mediatek-filogic-qihoo_360t7_108M-squashfs-sysupgrade.bin" \
    "/volume7/Documents/docker-files/static/files/360-t7-108M.bin" \
    "/volume7/Documents/docker-files/static/files/build_date_mt798x.txt"

# 2. 处理360T7固件
# process_firmware "/volume3/OpenwrtImgs/mt7981/360T7_108M_24.10" \
#    "immortalwrt-mediatek-mt7981-mt7981-360-t7-108M-squashfs-sysupgrade.bin" \
#    "/volume1/docker/nginx-ui/data/static/files/360-t7-108M.bin" \
#    ""

# 3. 同步所有架构的固件到生产仓库
log "复制所有架构的OpenWrt镜像到生产仓库"
rsync -avrzP --exclude='*.tmp' --exclude='*.part' "/volume3/OpenwrtImgs/" "/volume7/Tools/Router/OpenwrtOSs/"

# 4. 安全延迟
log "等待10秒..."
sleep 10

# 5. 清理所有平台的版本目录（保留架构文件夹）
log "清理所有版本目录"
find "/volume3/OpenwrtImgs/" -type d -name "20*" -exec rm -rf {} + 2>/dev/null

log "===== 固件传输流程完成 ====="