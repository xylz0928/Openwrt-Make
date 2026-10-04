#!/bin/bash

# op_ver.sh —— OpenWrt 固件版本读取（HA command_line 传感器专用）
#
# 用法:
#   pve    PVE_IP SSH_KEY [PVE_PORT] VMID [FALLBACK_IP] [VAR]   # 主路径: qm guest exec
#   direct ROUTER_IP SSH_KEY [PORT] [VAR]                        # 直连 SSH 读取
#
# 2026-10-03 改造（新固件缺 qemu-ga 导致 PVE 路径失败后定位）:
#   1. PVE 模式新增【直连回落】：qm guest exec 失败/无输出（典型: QEMU guest
#      agent is not running）时，自动改为直连 SSH 路由器读取 /etc/openwrt_release
#      - 回落 IP 来源: 参数 $6 优先，未传则查 vmid→IP 内置表
#      - 内置表全部按 hostname 逐一验证（PVE2 六台 + YA 四台）
#   2. 失败结果（Unavailable）只缓存 120 秒（原 24 小时）:
#      避免"故障恢复后 HA 还要盲等一天"；成功结果仍缓存 24 小时
#   3. 其余逻辑（参数解析/重试/解析）完全保留原行为
#
# 缓存键只由 MODE/TARGET/VMID/PORT/VAR 决定 → 回落不改变身份，缓存键不变

MODE=$1
TARGET=$2
SSH_KEY=$3

# 默认值
PVE_SSH_PORT=22
DIRECT_SSH_PORT=22
VMID=""
FALLBACK_IP=""
VAR_NAME="DISTRIB_REVISION" # 保留以兼容缓存键

# --- vmid → 路由器直连 IP（PVE 回落用） ---
# PVE2(10.1.0.200): 110101=ZZ-OP-T1 ... 110114=ZZ-OP-T4（hostname 逐一验证）
# YA(10.101.0.200): 210101=10.101.0.1/T1、210102=10.102.0.1/T2、
#                   210103=10.103.0.1/T3、210104=10.104.0.1/T4
#                   （四台各在独立 /16 网段，PVE MAC 邻居表 + hostname 验证；
#                    注意不是 10.101.0.x！T2-T4 的 10.101.0.2-4 是错误推定，已纠正）
vmid_ip() {
    case "$1" in
        110101) echo "10.1.0.1" ;;
        110102) echo "10.2.0.1" ;;
        110103) echo "10.3.0.1" ;;
        110112) echo "10.12.0.1" ;;
        110113) echo "10.13.0.1" ;;
        110114) echo "10.14.0.1" ;;
        210101) echo "10.101.0.1" ;;
        210102) echo "10.102.0.1" ;;
        210103) echo "10.103.0.1" ;;
        210104) echo "10.104.0.1" ;;
        *) echo "" ;;
    esac
}

# --- 参数解析与映射（完全保留原逻辑） ---
if [ "$MODE" == "pve" ]; then
    # 用法: pve IP KEY [PVE_PORT] VMID [FALLBACK_IP] [VAR]
    PVE_SSH_PORT=${4:-22}
    VMID=$5
    FALLBACK_IP=${6}
    TMP_VAR=${7:-DISTRIB_REVISION}

    # 如果没传 VMID (即 $5 为空)，但 $4 是数字且非22，尝试交换（兼容旧习惯）
    if [ -z "$VMID" ] && [[ "$4" =~ ^[0-9]+$ ]] && [ "$4" != "22" ]; then
        VMID=$4
        PVE_SSH_PORT=22
    fi

    # 映射简写（保留但不再使用）
    case "$TMP_VAR" in
        release) VAR_NAME="DISTRIB_RELEASE" ;;
        revision) VAR_NAME="DISTRIB_REVISION" ;;
        *) VAR_NAME="$TMP_VAR" ;;
    esac

elif [ "$MODE" == "direct" ]; then
    # 用法: direct IP KEY [PORT] [VAR]
    DIRECT_SSH_PORT=${4:-22}

    # 判断 $4 是端口还是变量名
    if [[ "$4" =~ ^[0-9]+$ ]]; then
        TMP_VAR=${5:-DISTRIB_REVISION}
    else
        TMP_VAR=${4:-DISTRIB_REVISION}
        DIRECT_SSH_PORT=22
    fi

    # 映射简写（保留但不再使用）
    case "$TMP_VAR" in
        release) VAR_NAME="DISTRIB_RELEASE" ;;
        revision) VAR_NAME="DISTRIB_REVISION" ;;
        *) VAR_NAME="$TMP_VAR" ;;
    esac
fi

# 生成缓存文件 (保留 VAR_NAME 确保缓存键不变)
CACHE_FILE="/tmp/openwrt_ver_$(echo "$MODE$TARGET$VMID$DIRECT_SSH_PORT$VAR_NAME" | md5sum | cut -d' ' -f1).cache"
MAX_RETRIES=5
TIMEOUT=5

# --- 1. 检查缓存 ---
# 成功结果 24 小时有效；失败结果(Unavailable)只缓存 120 秒，尽快重试
if [ -f "$CACHE_FILE" ]; then
    CACHED=$(cat "$CACHE_FILE")
    TTL=86400
    if [ "$CACHED" == "Unavailable" ]; then
        TTL=120
    fi
    LAST_MOD=$(stat -c %Y "$CACHE_FILE")
    NOW=$(date +%s)
    if [ $((NOW - LAST_MOD)) -lt $TTL ]; then
        printf '%s\n' "$CACHED"
        exit 0
    fi
fi

# --- 2. 获取数据 ---
# 直连 SSH 读取（回落路径 & direct 模式共用）
ssh_direct() {
    ssh -p $DIRECT_SSH_PORT -o ConnectTimeout=$TIMEOUT -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no -i "$SSH_KEY" "root@$1" \
        "cat /etc/openwrt_release" 2>/dev/null
}

get_content() {
    if [ "$MODE" == "pve" ]; then
        # 主路径：PVE 上 qm guest exec 执行 cat
        local out fbp
        out=$(ssh -p $PVE_SSH_PORT -o ConnectTimeout=$TIMEOUT -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no -i "$SSH_KEY" root@$TARGET \
            "qm guest exec $VMID -- cat /etc/openwrt_release" 2>/dev/null \
            | awk -F'"' '/out-data/ {print $4}')

        # 回落：PVE 路径失败（agent 未运行/PVE 不可达/VMID 无输出）→ 直连 SSH 路由器
        if [ -z "$out" ]; then
            fbp=${FALLBACK_IP:-$(vmid_ip "$VMID")}
            # 防注入：只允许数字与点
            case "$fbp" in
                ""|*[!0-9.]*)
                    fbp=""
                    ;;
            esac
            if [ -n "$fbp" ]; then
                [ -n "$OP_VER_DEBUG" ] && echo "op_ver: PVE 路径失败，回落直连 $fbp" >&2
                out=$(ssh_direct "$fbp")
            fi
        fi
        printf '%s' "$out"
    elif [ "$MODE" == "direct" ]; then
        ssh_direct "$TARGET"
    fi
}

# --- 3. 重试机制（解析文件内容提取版本） ---
VERSION=""          # 最终日期版本
REVISION_LAST=""    # 最后一次获取到的 REVISION（用于无日期时回退）
for i in $(seq 1 $MAX_RETRIES); do
    RAW_RESULT=$(get_content)

    # 清洗：处理 JSON 转义字符 & 去除多余换行/回车
    CLEANED=$(echo "$RAW_RESULT" | sed 's/\\n/\n/g' | tr -d '\r' | sed '/^$/d')

    # 提取 DISTRIB_REVISION 和 DISTRIB_RELEASE（兼容单引号和双引号）
    REVISION=$(echo "$CLEANED" | awk -F"'" '/DISTRIB_REVISION=/ {print $2; exit}')
    if [ -z "$REVISION" ]; then
        REVISION=$(echo "$CLEANED" | sed -n 's/^DISTRIB_REVISION="\(.*\)"$/\1/p')
    fi
    RELEASE=$(echo "$CLEANED" | awk -F"'" '/DISTRIB_RELEASE=/ {print $2; exit}')
    if [ -z "$RELEASE" ]; then
        RELEASE=$(echo "$CLEANED" | sed -n 's/^DISTRIB_RELEASE="\(.*\)"$/\1/p')
    fi

    # 保存最后一次的 REVISION
    if [ -n "$REVISION" ]; then
        REVISION_LAST="$REVISION"
    fi

    # 优先从 REVISION 中提取日期，若无则从 RELEASE 中提取
    if [ -n "$REVISION" ]; then
        VERSION=$(echo "$REVISION" | grep -oE 'R[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n1)
    fi
    if [ -z "$VERSION" ] && [ -n "$RELEASE" ]; then
        VERSION=$(echo "$RELEASE" | grep -oE 'R[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n1)
    fi

    # 若成功提取日期，跳出循环；否则若获取到了 REVISION 且长度足够，也跳出（避免无效重试）
    if [ -n "$VERSION" ] || { [ -n "$REVISION" ] && [ ${#REVISION} -gt 5 ]; }; then
        break
    fi
    sleep 2
done

# --- 4. 处理结果 ---
if [ -n "$VERSION" ]; then
    FINAL_RESULT="$VERSION"
else
    # 无日期时使用 REVISION_LAST（若为空则输出 Unavailable）
    if [ -n "$REVISION_LAST" ] && [ "${#REVISION_LAST}" -gt 5 ]; then
        FINAL_RESULT="$REVISION_LAST"
    else
        FINAL_RESULT="Unavailable"
    fi
fi

# 写入缓存并输出（确保无多余换行）
echo "$FINAL_RESULT" | tee "$CACHE_FILE" | tr -d '\n'
