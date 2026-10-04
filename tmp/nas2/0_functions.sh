#!/bin/bash

# 全局配置
export LOG_DIR="/volume7/Tools/Synology/confs/OP-Upgrade/logs"
export STATIC_HTTP="https://static.z.7ze.top:20443/files"
export PRIMARY_GW_HYTJ="10.1.0.1"
export PRIMARY_GW_YA="10.101.0.1"
export TODAY=$(date +"%Y.%m.%d")
export SNAPSHOT_NAME="WeeklyUpdate$(date +'%m%d')"

# 默认固件类型: lede | openwrt
export DEFAULT_FIRMWARE="openwrt"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 日志函数
log() {
    local log_file="$LOG_DIR/$(date +'%Y%m%d').log"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_file"
}

# 从 /etc/openwrt_release 内容中提取编译日期 (兼容 DISTRIB_REVISION 与 DISTRIB_RELEASE)
extract_build_date() {
    echo "$1" | grep -E 'DISTRIB_(REVISION|RELEASE)=' | sed -n "s/.*R\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p" | head -1
}

# 带超时的SSH连接 (修复版)
timeout_ssh() {
    local timeout=$1
    local ip=$2
    local port=${3:-22}  # 默认22端口
    shift 3
    
    # 简化SSH命令，移除BatchMode参数
    ssh -p $port -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@$ip" "$@" &
    
    local pid=$!
    local count=0
    while kill -0 $pid 2>/dev/null; do
        sleep 1
        count=$((count+1))
        if [ $count -ge $timeout ]; then
            kill -9 $pid 2>/dev/null
            log "SSH命令超时: $@ (端口:$port)"
            return 124
        fi
    done
    wait $pid
    return $?
}

# 固件校验函数
validate_firmware() {
    local firmware_dir=$1
    local firmware_file=$2
    local checksum_file="$firmware_dir/sha256sums"
    
    # 添加详细的路径检查
    if [ ! -d "$firmware_dir" ]; then
        log "错误: 固件目录不存在: $firmware_dir"
        return 1
    fi
    
    if [ ! -f "$checksum_file" ]; then
        log "校验文件缺失: $checksum_file"
        return 1
    fi
    
    log "使用校验文件: $checksum_file"
    log "验证固件: $firmware_dir/$firmware_file"
    
    pushd "$firmware_dir" > /dev/null || return 1
    
    # 增加详细的校验输出
    if sha256sum -c sha256sums --ignore-missing 2>&1 | tee -a "$LOG_DIR/$(date +'%Y%m%d')_checksum.log" | grep -q "$firmware_file: OK"; then
        log "固件校验成功: $firmware_file"
        popd > /dev/null || true
        return 0
    else
        log "固件校验失败: $firmware_file"
        log "详细校验输出:"
        sha256sum -c sha256sums --ignore-missing 2>&1 | tee -a "$LOG_DIR/$(date +'%Y%m%d')_checksum.log" | grep -v OK
        popd > /dev/null || true
        return 1
    fi
}

# 同步 sum 到 static 目录（2026-10-03 加：固件 OTA 备源 static.z.7ze.top 的 sha256 校验依赖）
# - 从源版本目录的 sha256sums 取该固件哈希（兼容 "hash  name" 与 "hash *name"）
# - 写入 static 目录共享的 sha256sums，文件名改写为 static 目标名（下载方按 static 文件名匹配）
# - 按目标文件名覆盖：每次传输刷新本文件对应行，不同固件的行共存互不影响
sync_sum_to_static() {
    local src_dir="$1"
    local src_file="$2"
    local target_file="$3"
    local src_sums="$src_dir/sha256sums"
    local dest_sums dest_name static_dir hash tmp

    static_dir=$(dirname "$target_file")
    dest_sums="$static_dir/sha256sums"
    dest_name=$(basename "$target_file")

    if [ ! -f "$src_sums" ]; then
        log "警告: 源版本目录无 sha256sums，跳过 sum 同步: $src_sums"
        return 0
    fi

    hash=$(awk -v f="$src_file" '{ n=$2; sub(/^\*/, "", n); if (n == f) { print $1; exit } }' "$src_sums")
    if [ -z "$hash" ]; then
        log "警告: sha256sums 中未找到 $src_file 的哈希，跳过 sum 同步"
        return 0
    fi

    tmp="$dest_sums.tmp.$$"
    if [ -f "$dest_sums" ]; then
        awk -v b="$dest_name" '{ n=$2; sub(/^\*/, "", n); if (n != b) print }' "$dest_sums" > "$tmp"
    else
        : > "$tmp"
    fi
    printf '%s  %s\n' "$hash" "$dest_name" >> "$tmp"
    mv "$tmp" "$dest_sums"
    log "sum 已同步到 static: $dest_name -> $dest_sums"
}

# 为 static 中的单个产物生成专属校验文件 <dest>.sha256sums（2026-10-03 用户指令）
# - 文件名：追加在 static 目标名之后，避免与已存在的共享 sha256sums 撞名
# - 内容：按 static 目标文件名改写（手动下载 360-t7-108M.bin 后可直接 sha256sum -c）
write_product_sha() {
    local dest="$1" src_sha="$2" src_name="$3"
    if [ ! -f "$src_sha" ]; then
        log "警告: 源 sha256sums 缺失，跳过专属校验文件: $src_sha"
        return 0
    fi
    local hash out
    hash=$(awk -v f="$src_name" '{ n=$2; sub(/^\*/, "", n); if (n == f) { print $1; exit } }' "$src_sha")
    if [ -z "$hash" ]; then
        log "警告: sha256sums 中未找到 $src_name，跳过专属校验文件"
        return 0
    fi
    out="${dest}.sha256sums"
    printf '%s  %s\n' "$hash" "$(basename "$dest")" > "$out"
    log "专属校验文件已生成: $out"
}

# 处理固件函数
process_firmware() {
    local src_dir="$1"
    local src_file="$2"
    local target_file="$3"
    local date_file="$4"
    
    # 存储最新有效版本信息
    local latest_timestamp=""
    local latest_date=""
    local latest_dir=""
    
    if [ ! -d "$src_dir" ]; then
        log "错误: 固件目录不存在: $src_dir"
        return 1
    fi
    
    log "扫描固件版本目录: $src_dir"
    
    # 创建临时数组存储结果
    local results=()
    while IFS=$'\t' read -r timestamp path; do
        results+=("$timestamp" "$path")
    done < <(find "$src_dir" -maxdepth 1 -type d -name "20*" -printf '%T@\t%p\n' | sort -nr 2>/dev/null)
    
    # 处理每个版本
    for ((i=0; i<${#results[@]}; i+=2)); do
        local timestamp="${results[i]}"
        local version_dir="${results[i+1]}"
        local version_name=$(basename "$version_dir")
        
        # 检查目录是否存在
        if [ ! -d "$version_dir" ]; then
            log "警告: 目录不存在: $version_dir"
            continue
        fi
        
        log "处理版本: $version_name"
        
        # 验证固件
        if validate_firmware "$version_dir" "$src_file"; then
            log "$version_name 固件校验成功"
            
            # 提取编译日期
            local current_date=$(echo "$version_name" | sed -E 's/([0-9]{4})[.-]([0-9]{2})[.-]([0-9]{2}).*/\1-\2-\3/')
            
            # 检查是否是最新有效版本
            if [[ -z "$latest_timestamp" || "$timestamp" > "$latest_timestamp" ]]; then
                latest_timestamp="$timestamp"
                latest_date="$current_date"
                latest_dir="$version_dir"
                log "标记为当前最新有效版本"
            fi
        else
            log "$version_name 固件校验失败，删除目录"
            rm -rf "$version_dir"
        fi
    done
    
    # 处理最新有效版本
    if [ -n "$latest_dir" ] && [ -d "$latest_dir" ]; then
        log "使用最新有效版本: $(basename "$latest_dir")"
        
        # 复制固件
        cp "$latest_dir/$src_file" "$target_file"
        
        # 记录编译日期
        if [ -n "$date_file" ]; then
            echo "$latest_date" > "$date_file"
            log "记录编译日期: $latest_date"
        fi
        # 同步 sum 到 static（每次传输覆盖本文件对应行）
        sync_sum_to_static "$latest_dir" "$src_file" "$target_file"
        # 同步专属校验文件（按 static 文件名改写，与共享 sha256sums 不撞名）
        write_product_sha "$target_file" "$latest_dir/sha256sums" "$src_file"
        return 0
    else
        log "错误: 未找到任何有效固件版本"
        return 1
    fi
}

# 多路径传输函数（增加连接类型参数）
transfer_firmware() {
    local target_ip=$1
    local target_port=$2
    local target_domain=$3
    local target_wan_port=$4
    local conn_type=$5  # 连接类型
    local firmware_path=$6
    local firmware_name=$(basename "$firmware_path")

    # 方案1: 内网SCP
    log "尝试内网SCP传输到 $target_ip:$target_port"
    local scp_output
    scp_output=$(timeout 600 scp -v -P $target_port -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "$firmware_path" "root@$target_ip:/tmp/" 2>&1)
    local scp_status=$?

    if [ $scp_status -eq 0 ]; then
        log "内网SCP传输成功"
        return 0
    else
        log "内网SCP传输失败 (状态码: $scp_status)"
        log "SCP错误详情: $scp_output"
    fi

    # 如果是直连设备，不尝试备用线路
    if [ "$conn_type" == "direct" ]; then
        log "直连设备，跳过备用线路尝试"
        return 1
    fi

    # 方案2: HTTP下载
    log "尝试HTTP下载 ($target_ip)"
    if timeout 600 ssh -p $target_port -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@$target_ip" \
        "wget --no-check-certificate -O '/tmp/$firmware_name' '$STATIC_HTTP/$firmware_name'"; then
        log "HTTP下载成功"
        return 0
    fi

    # 方案3: 外网SCP
    log "尝试外网SCP传输 ($target_domain:$target_wan_port)"
    if timeout 600 scp -P $target_wan_port -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "$firmware_path" "root@$target_domain:/tmp/"; then
        log "外网SCP传输成功"
        return 0
    fi

    log "所有传输方式均失败"
    return 1
}

# 设备状态检查（增加连接类型参数和日期验证）
check_device_status() {
    local target_ip=$1
    local target_port=$2
    local target_domain=$3
    local target_wan_port=$4
    local conn_type=$5  # 连接类型
    local pve_host=$6
    local vm_id=$7
    local expected_date="$8"   # 期望的编译日期 (YYYY-MM-DD格式)

    # 尝试通过多种方式获取版本信息
    local version_found=false
    local actual_date=""
    local status_code=5  # 默认状态码为完全不可达

    # 方式1: 尝试内网SSH访问（带重试机制）
    log "尝试内网SSH访问获取版本: $target_ip:$target_port"
    local ssh_retries=3
    for ((i=1; i<=ssh_retries; i++)); do
        if release_info=$(timeout_ssh 10 "$target_ip" "$target_port" "cat /etc/openwrt_release 2>/dev/null"); then
            # 提取编译日期
            actual_date=$(extract_build_date "$release_info")
            
            if [ -n "$actual_date" ]; then
                log "通过内网SSH获取编译日期: $actual_date"
                version_found=true
                status_code=0  # 成功获取版本
                break
            else
                log "警告: 无法从内网SSH信息中提取编译日期"
            fi
        else
            log "内网SSH尝试失败 (${i}/${ssh_retries})，等待5秒后重试..."
            sleep 5
        fi
    done

    # 方式2: 如果内网访问失败且不是直连设备，尝试外网访问
    if ! $version_found && [ "$conn_type" != "direct" ]; then
        log "尝试外网SSH访问获取版本: $target_domain:$target_wan_port"
        if release_info=$(timeout_ssh 60 "$target_domain" "$target_wan_port" "cat /etc/openwrt_release 2>/dev/null"); then
            # 提取编译日期
            actual_date=$(extract_build_date "$release_info")
            
            if [ -n "$actual_date" ]; then
                log "通过外网SSH获取编译日期: $actual_date"
                version_found=true
                status_code=4  # 外网访问成功
            else
                log "警告: 无法从外网SSH信息中提取编译日期"
            fi
        else
            log "外网SSH访问失败"
        fi
    fi

    # 方式3: 如果前两种方式都失败，尝试通过PVE获取版本
    if ! $version_found && [ -n "$pve_host" ] && [ -n "$vm_id" ]; then
        log "尝试通过PVE Guest Agent获取版本: $vm_id@$pve_host"
        if check_version_via_pve "$pve_host" "$vm_id" "$expected_date"; then
            # 在check_version_via_pve函数中已经设置了actual_date
            version_found=true
            status_code=0  # 成功获取版本
        else
            log "PVE Guest Agent获取版本失败"
        fi
    fi

    # 如果有期望日期且成功获取实际日期，检查日期是否匹配
    if $version_found && [ -n "$expected_date" ] && [ -n "$actual_date" ]; then
        log "编译日期检查: 实际[$actual_date] vs 期望[$expected_date]"
        if [ "$actual_date" != "$expected_date" ]; then
            log "编译日期不匹配"
            return 6  # 状态码6表示日期不匹配
        fi
    fi

    # 如果成功获取版本信息，返回成功状态码
    if $version_found; then
        log "设备在线，版本信息已获取"
        return 0
    fi

    # 所有方式都失败，返回不可达状态
    log "所有方式都无法获取版本信息，设备不可达"
    return $status_code
}

# 获取固件文件路径
get_firmware_path() {
    case "${1:-$DEFAULT_FIRMWARE}" in
        lede)    echo "/volume7/Documents/docker-files/static/files/LEDE-x64.img.gz" ;;
        openwrt) echo "/volume7/Documents/docker-files/static/files/OpenWrt-x64.img.gz" ;;
        mt798x)  echo "/volume7/Documents/docker-files/static/files/360-t7-108M.bin" ;;
        *)       log "错误: 未知固件类型: $1"; return 1 ;;
    esac
}

# 获取固件编译日期文件路径
get_date_file() {
    case "${1:-$DEFAULT_FIRMWARE}" in
        lede)    echo "/volume7/Documents/docker-files/static/files/build_date_lede.txt" ;;
        openwrt) echo "/volume7/Documents/docker-files/static/files/build_date_openwrt.txt" ;;
        mt798x)  echo "/volume7/Documents/docker-files/static/files/build_date_mt798x.txt" ;;
        *)       log "错误: 未知固件类型: $1"; return 1 ;;
    esac
}

sysupgrade_device() {
    local target_ip=$1
    local target_port=$2
    local target_domain=$3
    local target_wan_port=$4
    local conn_type=$5
    local pve_host=$6
    local vm_id=$7
    local firmware_type=${8:-$DEFAULT_FIRMWARE}

    local firmware_path=$(get_firmware_path "$firmware_type")
    if [ -z "$firmware_path" ]; then
        log "错误: 固件类型无效: $firmware_type"
        return 1
    fi
    log "本次使用固件类型: $firmware_type ($(basename "$firmware_path"))"

    # 从文件读取期望的编译日期
    local date_file=$(get_date_file "$firmware_type")
    local expected_date=""
    if [ -f "$date_file" ]; then
        expected_date=$(cat "$date_file")
        log "期望编译日期: $expected_date"
    else
        log "警告: 未找到编译日期文件: $date_file"
    fi

    # 传输固件
    if ! transfer_firmware "$target_ip" "$target_port" "$target_domain" "$target_wan_port" "$conn_type" \
        "$firmware_path"; then
        log "固件传输失败"
        return 1
    fi

    # 获取当前编译日期（用于回滚验证）
    log "获取当前固件编译日期..."
    local current_date=$(timeout_ssh 30 "$target_ip" "$target_port" \
        "cat /etc/openwrt_release 2>/dev/null | grep -E 'DISTRIB_(REVISION|RELEASE)=' | sed -n \"s/.*R\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p\" | head -1")
    log "当前编译日期: ${current_date:-未知}"

    # 触发更新
    log "触发固件更新 (保留配置)..."
    execute_sysupgrade "$target_ip" "$target_port" "$firmware_type"

    # 等待设备开始重启
    log "等待设备开始重启..."
    if ! wait_for_shutdown "$target_ip" "$target_port" 120; then
        log "设备未重启，尝试安全重启..."
        timeout_ssh 10 "$target_ip" "$target_port" "reboot -f"
    fi

    # 等待设备重启完成
    log "等待设备重启完成..."
    if ! wait_for_reboot "$target_ip" "$target_port" 300; then
        log "设备重启后无法通过内网访问，尝试其他方式检查状态..."
    fi
    
    # 无论wait_for_reboot是否成功，都进行状态检查（通过多种途径）
    check_device_status "$target_ip" "$target_port" "$target_domain" "$target_wan_port" \
        "$conn_type" "$pve_host" "$vm_id" "$expected_date"
    status_result=$?
    
    # 统一处理状态码
    case $status_result in
        0)
            log "更新成功验证完成"
            return 0
            ;;
        6)  # 日期不匹配的特殊处理
            log "警告: 设备已启动但编译日期不匹配"
            return 5
            ;;
        2|4|5)  # 仅在这些状态码下执行回滚
            log "设备启动失败且无法获取版本信息，执行回滚..."
            # 确保PVE主机信息存在
            if [ -z "$pve_host" ] || [ -z "$vm_id" ]; then
                log "错误: 缺少PVE主机信息，无法回滚"
                return 4
            fi

            # 执行回滚
            log "执行快照回滚: $vm_id@$pve_host"
            ssh -o ConnectTimeout=10 "root@$pve_host" "qm rollback $vm_id $SNAPSHOT_NAME"
            ssh -o ConnectTimeout=10 "root@$pve_host" "qm start $vm_id"

            log "等待回滚后设备启动..."
            if wait_for_reboot "$target_ip" "$target_port" 240; then
                log "回滚后设备已启动，验证版本..."
                # 回滚后验证版本（传递回滚前日期）
                if check_device_status "$target_ip" "$target_port" "$target_domain" "$target_wan_port" \
                    "$conn_type" "$pve_host" "$vm_id" "$current_date"; then
                    log "回滚成功 (编译日期恢复)"
                    return 3
                else
                    log "回滚后设备状态检查失败"
                    return 4
                fi
            else
                log "回滚后设备仍无法启动"
                return 4
            fi
            ;;
        *)
            log "设备状态异常，返回码: $status_result"
            return $status_result
            ;;
    esac
}

# 简化版 sysupgrade 执行
execute_sysupgrade() {
    local target_ip=$1
    local target_port=$2
    local firmware_type=${3:-$DEFAULT_FIRMWARE}
    local firmware_file="/tmp/$(basename "$(get_firmware_path "$firmware_type")")"

    log "验证固件文件..."
    # 检查固件文件是否存在
    timeout_ssh 10 "$target_ip" "$target_port" "test -f $firmware_file"
    if [ $? -ne 0 ]; then
        log "错误: 固件文件不存在"
        return 2
    fi
    
    # 升级前清理 openclash 可再生成的缓存/数据库文件（*.csv/*.mmdb/*.dat/smart_*），
    # 防止备份包过大导致升级恢复时 /etc/shadow 未恢复（root 密码被清空）
    log "升级前清理 openclash 缓存文件 (*.csv/*.mmdb/*.dat/smart_*)..."
    timeout_ssh 20 "$target_ip" "$target_port" \
        "rm -f /etc/openclash/*.csv /etc/openclash/*.mmdb /etc/openclash/*.dat /etc/openclash/smart_* /etc/openclash/history/Smart-Locales.db* 2>/dev/null; echo openclash-cache-cleaned"

    log "固件文件存在，执行 sysupgrade..."
    
    # 在后台执行 sysupgrade
    timeout_ssh 10 "$target_ip" "$target_port" "nohup /sbin/sysupgrade $firmware_file > /tmp/sysupgrade.log 2>&1 &"
    
    # 总是返回成功 - 因为我们无法可靠捕获退出状态
    log "sysupgrade 命令已发送到设备"
    return 0
}

# 等待设备开始重启
wait_for_shutdown() {
    local target_ip=$1
    local target_port=$2
    local max_wait=${3:-120}
    local interval=2
    local start_time=$(date +%s)
    
    log "等待设备开始重启 (最多${max_wait}秒)..."
    
    while true; do
        # 检测设备是否离线
        if ! ping -c 1 -W 1 "$target_ip" &> /dev/null; then
            log "设备已开始重启"
            return 0
        fi
        
        # 检查超时
        local current_time=$(date +%s)
        if (( current_time - start_time > max_wait )); then
            log "设备未在预期时间内重启"
            return 1
        fi
        
        sleep $interval
    done
}

# 等待设备重启完成
wait_for_reboot() {
    local target_ip=$1
    local target_port=$2
    local max_wait=${3:-300}
    local interval=5
    local start_time=$(date +%s)
    local last_log_time=$start_time
    
    log "等待设备启动完成 (最多${max_wait}秒)..."
    
    while true; do
        # 尝试SSH连接
        if timeout_ssh 5 "$target_ip" "$target_port" "echo 'SSH测试成功'" &> /dev/null; then
            log "SSH连接已恢复"
            return 0
        fi
        
        # 检查超时
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if (( elapsed > max_wait )); then
            log "等待设备启动超时 (已等待 ${elapsed} 秒)"
            return 1
        fi
        
        # 每15秒记录一次等待状态
        if (( current_time - last_log_time > 15 )); then
            log "等待中... 已等待 ${elapsed} 秒"
            last_log_time=$current_time
        fi
        
        sleep $interval
    done
}

# 等待 QEMU Guest Agent 启动并获取版本信息
wait_for_guest_agent() {
    local pve_host=$1
    local vm_id=$2
    local expected_date=$3
    local max_wait=${4:-600}  # 默认等待600秒
    local interval=10
    local start_time=$(date +%s)
    local last_log_time=$start_time
    
    log "等待 QEMU Guest Agent 启动 (最多${max_wait}秒)..."
    
    while true; do
        # 尝试通过 PVE 获取版本信息
        if check_version_via_pve "$pve_host" "$vm_id" "$expected_date"; then
            return 0
        fi
        
        # 检查超时
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [ $elapsed -ge $max_wait ]; then
            log "等待 QEMU Guest Agent 超时"
            return 1
        fi
        
        # 每30秒记录一次状态
        if (( current_time - last_log_time > 30 )); then
            log "等待中... 已等待 ${elapsed} 秒"
            last_log_time=$current_time
        fi
        
        sleep $interval
    done
}

# 通过 PVE 检查版本（优化版）
check_version_via_pve() {
    local pve_host=$1
    local vm_id=$2
    local expected_date=$3

    if [ -z "$pve_host" ] || [ -z "$vm_id" ]; then
        log "错误: 缺少PVE信息，无法检查版本"
        return 1
    fi

    log "尝试通过PVE获取版本信息: $vm_id@$pve_host"

    # 执行命令并解析JSON输出
    local json_output
    json_output=$(ssh -o ConnectTimeout=10 "root@$pve_host" "qm guest exec $vm_id cat /etc/openwrt_release 2>/dev/null")

    if [ -z "$json_output" ]; then
        log "PVE命令无输出"
        return 1
    fi

    # 提取退出码
    local exitcode=$(echo "$json_output" | grep '"exitcode"' | awk '{print $3}' | tr -d ',')

    if [ "$exitcode" != "0" ]; then
        log "PVE命令执行失败 (退出码: $exitcode)"
        return 1
    fi

    # 提取输出数据
    local out_data=$(echo "$json_output" | grep '"out-data"' | sed -e 's/.*"out-data" : "\(.*\)".*/\1/' -e 's/\\n/\n/g')

    if [ -z "$out_data" ]; then
        log "无法解析输出数据"
        return 1
    fi

    # 提取实际编译日期
    local actual_date=$(extract_build_date "$out_data")

    if [ -z "$actual_date" ]; then
        log "无法从输出中提取编译日期"
        return 1
    fi

    log "通过PVE获取的编译日期: $actual_date"
    log "期望编译日期: ${expected_date:-未设置}"

    # 设置全局变量供调用者使用
    export actual_date

    if [ -n "$expected_date" ] && [ "$actual_date" = "$expected_date" ]; then
        log "版本验证成功 (日期匹配)"
        return 0
    elif [ -n "$expected_date" ]; then
        log "版本验证失败 (日期不匹配)"
        return 0  # 仍然返回成功，因为获取到了版本信息
    else
        log "未提供期望日期，跳过日期验证"
        return 0  # 没有期望日期时视为成功
    fi
}