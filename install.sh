#!/bin/bash
# ============================================================
# sptest 安装脚本
# 功能：交互式配置 Telegram Bot，安装 sptest 命令
# 支持：Debian/Ubuntu、RHEL/CentOS/Fedora、Arch、Alpine、openSUSE
# ============================================================

set -e

# ---------- 全局变量 ----------
CONF_FILE="$HOME/.sptest.conf"
BIN_PATH="/usr/local/bin/sptest"

# 颜色定义（如果终端不支持会自动降级）
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ---------- 打印带颜色的提示 ----------
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- 菜单美化 ----------
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║          🚀  sptest 网络测速工具             ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

print_menu_item() {
    local num=$1
    local text=$2
    echo -e "  ${GREEN}${BOLD}[$num]${NC}  $text"
}

print_divider() {
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
}

# ---------- 卸载 ----------
uninstall() {
    info "正在卸载 sptest..."
    rm -f "$BIN_PATH"
    if [ -f "$CONF_FILE" ]; then
        read -p "$(echo -e "${YELLOW}是否同时删除配置文件 $CONF_FILE ? [y/N] ${NC}")" ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            rm -f "$CONF_FILE"
            success "配置文件已删除"
        fi
    fi
    success "卸载完成"
    exit 0
}

# ---------- 交互式配置 ----------
interactive_config() {
    echo ""
    print_divider
    echo -e "  ${BOLD}📝 请填写 Telegram 配置${NC}"
    print_divider
    echo ""
    echo -e "  ${CYAN}提示：${NC}"
    echo -e "    • Bot Token 找 @BotFather 创建机器人获取"
    echo -e "    • Chat ID 找 @getmyid_bot 获取"
    echo ""

    while true; do
        read -p "  🔑 Bot Token: " TG_BOT_TOKEN
        [ -n "$TG_BOT_TOKEN" ] && break
        warn "Token 不能为空，请重新输入"
    done

    while true; do
        read -p "  💬 Chat ID: " TG_CHAT_ID
        [ -n "$TG_CHAT_ID" ] && break
        warn "Chat ID 不能为空，请重新输入"
    done

    cat > "$CONF_FILE" <<EOF
# sptest 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
TG_BOT_TOKEN="$TG_BOT_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
EOF
    chmod 600 "$CONF_FILE"
    echo ""
    success "配置已保存到 $CONF_FILE"
}

# ---------- 写入主脚本 ----------
write_main_script() {
    info "正在安装主脚本到 $BIN_PATH ..."

    cat > "$BIN_PATH" <<'MAIN_EOF'
#!/bin/bash
# ============================================================
# sptest - 网络测速 + 发送结果到 Telegram
# ============================================================

CONF_FILE="$HOME/.sptest.conf"

# ---------- 检查配置 ----------
if [ ! -f "$CONF_FILE" ]; then
    echo "❌ 未找到配置文件，请先运行 install.sh 完成初始化"
    exit 1
fi

source "$CONF_FILE"

if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    echo "❌ 配置不完整，请重新运行 install.sh"
    exit 1
fi

# ---------- 颜色 ----------
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ---------- 包管理器检测 ----------
detect_pkg_manager() {
    command -v apt-get &>/dev/null && echo "apt" && return
    command -v dnf &>/dev/null && echo "dnf" && return
    command -v yum &>/dev/null && echo "yum" && return
    command -v pacman &>/dev/null && echo "pacman" && return
    command -v apk &>/dev/null && echo "apk" && return
    command -v zypper &>/dev/null && echo "zypper" && return
    echo "unknown"
}

PKG_MGR=$(detect_pkg_manager)

# ---------- 安装单个包 ----------
install_pkg() {
    local pkg=$1
    echo -e "${YELLOW}正在安装 $pkg ...${NC}"
    case $PKG_MGR in
        apt)    apt-get update -qq && apt-get install -y "$pkg" ;;
        dnf)    dnf install -y "$pkg" ;;
        yum)    yum install -y "$pkg" ;;
        pacman) pacman -S --noconfirm "$pkg" ;;
        apk)    apk add "$pkg" ;;
        zypper) zypper install -y "$pkg" ;;
        *)      echo "❌ 无法识别的包管理器，请手动安装 $pkg"; return 1 ;;
    esac
}

# ---------- 依赖检查 ----------
check_deps() {
    local need_install=()
    command -v curl &>/dev/null || need_install+=("curl")
    command -v jq &>/dev/null || need_install+=("jq")
    if ! command -v speedtest &>/dev/null && ! command -v speedtest-cli &>/dev/null; then
        need_install+=("speedtest-cli")
    fi
    if [ ${#need_install[@]} -eq 0 ]; then
        return 0
    fi
    echo "检测到缺少依赖: ${need_install[*]}"
    for pkg in "${need_install[@]}"; do
        install_pkg "$pkg" || exit 1
    done
}

check_deps

# ---------- IP 脱敏 ----------
mask_ip() {
    local ip="$1"

    [ -z "$ip" ] && echo "Unknown" && return

    # IPv4
    if [[ "$ip" =~ ^([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+$ ]]; then
        echo "${BASH_REMATCH[1]}.x.x"
        return
    fi

    # IPv4-mapped IPv6，如 ::ffff:23.106.1.100
    if [[ "$ip" =~ ^::ffff:([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+$ ]]; then
        echo "::ffff:${BASH_REMATCH[1]}.x.x"
        return
    fi

    # IPv6
    if [[ "$ip" == *:* ]]; then
        local part1=$(echo "$ip" | cut -d: -f1)
        local part2=$(echo "$ip" | cut -d: -f2)
        echo "${part1}:${part2}:x:x"
        return
    fi

    echo "$ip"
}

# ---------- 开始测速 ----------
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║          🚀  开始测速，请稍候...             ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ---------- 获取测速数据（自动适配两个版本） ----------
if command -v speedtest &>/dev/null; then
    JSON=$(speedtest --format=json --accept-license --accept-gdpr 2>/dev/null)
    RESULT_URL=$(echo "$JSON" | jq -r '.result.url // empty')
    DOWNLOAD_BPS=$(echo "$JSON" | jq -r '.download.bandwidth // 0')
    UPLOAD_BPS=$(echo "$JSON" | jq -r '.upload.bandwidth // 0')
    PING=$(echo "$JSON" | jq -r '.ping.latency // 0')
    JITTER=$(echo "$JSON" | jq -r '.ping.jitter // 0')
    ISP=$(echo "$JSON" | jq -r '.isp // "Unknown"')
    SERVER=$(echo "$JSON" | jq -r '(.server.name // "Unknown") + ", " + (.server.location // "")')
    EXTERNAL_IP=$(echo "$JSON" | jq -r '.interface.externalIp // "Unknown"')
    ELAPSED_MS=$(echo "$JSON" | jq -r '(.download.elapsed // 0) + (.upload.elapsed // 0)')
else
    JSON=$(speedtest-cli --json 2>/dev/null)
    RESULT_URL=$(echo "$JSON" | jq -r '.share // empty')
    DOWNLOAD_BPS=$(echo "$JSON" | jq -r '.download // 0')
    UPLOAD_BPS=$(echo "$JSON" | jq -r '.upload // 0')
    PING=$(echo "$JSON" | jq -r '.ping // 0')
    JITTER="0.0"
    ISP=$(echo "$JSON" | jq -r '.client.isp // "Unknown"')
    SERVER=$(echo "$JSON" | jq -r '(.server.name // "Unknown") + ", " + (.server.location // "")')
    EXTERNAL_IP=$(echo "$JSON" | jq -r '.client.ip // "Unknown"')
    ELAPSED_MS=0
fi

if [ -z "$RESULT_URL" ]; then
    echo "❌ 测速失败"
    exit 1
fi

# ---------- IP 脱敏处理 ----------
EXTERNAL_IP_MASKED=$(mask_ip "$EXTERNAL_IP")

# ---------- 单位自动转换 ----------
format_speed() {
    local bps=$1
    awk -v bps="$bps" 'BEGIN {
        mbps = bps / 1e6
        if (mbps >= 1000) {
            printf "%.2f Gbps", bps / 1e9
        } else if (mbps >= 1) {
            printf "%.2f Mbps", mbps
        } else {
            printf "%.2f Kbps", bps / 1e3
        }
    }'
}

DOWNLOAD_STR=$(format_speed "$DOWNLOAD_BPS")
UPLOAD_STR=$(format_speed "$UPLOAD_BPS")
ELAPSED_SEC=$(awk -v ms="$ELAPSED_MS" 'BEGIN { printf "%.1f", ms / 1000 }')

echo -e "${GREEN}✅ 测速完成${NC}  下载 ${BOLD}${DOWNLOAD_STR}${NC}  /  上传 ${BOLD}${UPLOAD_STR}${NC}"
echo ""

# ---------- 拼接消息文本 ----------
MESSAGE="🚀 网络测速

📍 节点: ${SERVER}
🏢 运营商: ${ISP}
🌐 出口: ${EXTERNAL_IP_MASKED}

⏱️ 延迟: ${PING} ms（抖动 ${JITTER} ms）
⬇️ 下载: ${DOWNLOAD_STR}
⬆️ 上传: ${UPLOAD_STR}

🔗 详细结果 (${RESULT_URL})
来源 Ookla Speedtest · 用时 ${ELAPSED_SEC} 秒"

# ---------- 发送到 Telegram ----------
echo -e "${BLUE}📤 正在发送到 Telegram...${NC}"
SHARE_URL="${RESULT_URL}.png"

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendPhoto" \
    -F "chat_id=${TG_CHAT_ID}" \
    -F "photo=${SHARE_URL}" \
    -F "caption=${MESSAGE}")

if echo "$RESPONSE" | jq -e '.ok == true' &>/dev/null; then
    echo ""
    echo -e "${GREEN}${BOLD}🎉 完成！已发送到 Telegram。${NC}"
else
    echo ""
    echo -e "${RED}❌ 发送失败${NC}"
    echo "响应: $RESPONSE"
fi
MAIN_EOF

    chmod +x "$BIN_PATH"
    success "主脚本已安装"
}

# ============================================================
# 主流程
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "请使用 sudo 或 root 权限运行 install.sh"
    exit 1
fi

print_header

# 已安装 → 管理菜单
if [ -f "$BIN_PATH" ] || [ -f "$CONF_FILE" ]; then
    echo -e "  ${YELLOW}检测到已有 sptest 安装${NC}"
    print_divider
    print_menu_item "1" "修改配置并重装"
    print_menu_item "2" "卸载"
    print_menu_item "3" "退出"
    print_divider
    echo ""
    read -p "$(echo -e "  ${GREEN}请选择 [1/2/3]: ${NC}")" choice

    case "$choice" in
        1)
            interactive_config
            write_main_script
            echo ""
            success "配置已更新，脚本已重装"
            ;;
        2)
            uninstall
            ;;
        3|*)
            echo ""
            info "已退出。"
            exit 0
            ;;
    esac
    exit 0
fi

# 首次安装
interactive_config
write_main_script

echo ""
print_divider
echo -e "${GREEN}${BOLD}  🎉 安装完成！${NC}"
print_divider
echo -e "  ${CYAN}配置文件:${NC}  $CONF_FILE"
echo -e "  ${CYAN}命令路径:${NC}  $BIN_PATH"
echo ""
echo -e "  以后直接输入 ${GREEN}${BOLD}sptest${NC} 即可测速并发送到 Telegram"
echo -e "  重新运行 ${CYAN}install.sh${NC} 可修改配置或卸载"
echo ""
print_divider
