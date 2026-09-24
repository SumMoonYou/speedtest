#!/bin/bash
# ============================================================
# sptest 安装脚本（优化版）
# ------------------------------------------------------------
# 功能：
#   1. 交互式配置 Telegram Bot Token 和 Chat ID
#   2. 把配置保存到 ~/.sptest.conf（权限 600）
#   3. 把主脚本安装到 /usr/local/bin/sptest
#   4. 再次运行时可修改配置或卸载
#
# 支持系统：
#   Debian/Ubuntu、RHEL/CentOS/Fedora、Arch、Alpine、openSUSE
# ============================================================

set -euo pipefail

# ---------- 全局变量 ----------
CONF_FILE="$HOME/.sptest.conf"        # 配置文件路径
BIN_PATH="/usr/local/bin/sptest"      # 主脚本安装路径

# ---------- 颜色定义 ----------
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

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║          🚀  sptest 网络测速工具             ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

print_menu_item() {
    echo -e "  ${GREEN}${BOLD}[$1]${NC}  $2"
}

print_divider() {
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
}

# ---------- 安全读取（兼容 set -e） ----------
# read 在 EOF 时返回非 0，会触发 set -e 退出，这里统一兜底
safe_read() {
    local __var=$1
    local __prompt=$2
    local __val=""
    read -r -p "$__prompt" __val || true
    printf -v "$__var" '%s' "$__val"
}

# ---------- 卸载 ----------
uninstall() {
    info "正在卸载 sptest..."
    rm -f "$BIN_PATH"
    if [ -f "$CONF_FILE" ]; then
        safe_read ans "$(echo -e "${YELLOW}是否同时删除配置文件 $CONF_FILE ? [y/N] ${NC}")"
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

    local TG_BOT_TOKEN="" TG_CHAT_ID=""

    while true; do
        safe_read TG_BOT_TOKEN "  🔑 Bot Token: "
        [ -n "$TG_BOT_TOKEN" ] && break
        warn "Token 不能为空，请重新输入"
    done

    while true; do
        safe_read TG_CHAT_ID "  💬 Chat ID: "
        [ -n "$TG_CHAT_ID" ] && break
        warn "Chat ID 不能为空，请重新输入"
    done

    # 用单引号包裹值，避免特殊字符被 shell 解释；同时转义内部单引号
    cat > "$CONF_FILE" <<EOF
# sptest 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
TG_BOT_TOKEN='${TG_BOT_TOKEN//\'/\'\\\'\'}'
TG_CHAT_ID='${TG_CHAT_ID//\'/\'\\\'\'}'
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
# ------------------------------------------------------------
# 依赖：curl、jq、speedtest（Ookla 官方版）
# 配置：~/.sptest.conf
# ============================================================

set -uo pipefail

CONF_FILE="$HOME/.sptest.conf"

# ---------- 检查配置文件 ----------
if [ ! -f "$CONF_FILE" ]; then
    echo "❌ 未找到配置文件，请先运行 install.sh 完成初始化"
    exit 1
fi

# shellcheck disable=SC1090
source "$CONF_FILE"

if [ -z "${TG_BOT_TOKEN:-}" ] || [ -z "${TG_CHAT_ID:-}" ]; then
    echo "❌ 配置不完整，请重新运行 install.sh"
    exit 1
fi

# ---------- 颜色 ----------
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

# ---------- 安装 Ookla 官方 speedtest ----------
# 各平台官方安装方式不同，这里只处理主流 Linux
install_ookla() {
    echo -e "${YELLOW}正在安装 Ookla 官方 speedtest ...${NC}"
    case $PKG_MGR in
        apt)
            # Debian/Ubuntu：官方 packagecloud 源
            if ! curl -fsSL https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash; then
                echo "❌ 添加 Ookla 源失败，请检查网络后手动安装："
                echo "   curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash"
                echo "   apt install -y speedtest"
                return 1
            fi
            apt-get install -y speedtest
            ;;
        dnf|yum)
            curl -fsSL https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash && \
            $PKG_MGR install -y speedtest
            ;;
        apk)
            # Alpine 官方源里通常没有，需手动下载二进制
            install_ookla_binary
            ;;
        *)
            install_ookla_binary
            ;;
    esac
}

# ---------- 通用二进制安装（兜底） ----------
install_ookla_binary() {
    local arch url tmp
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz" ;;
        aarch64|arm64) url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz" ;;
        *) echo "❌ 不支持的架构：$arch，请手动安装 speedtest"; return 1 ;;
    esac
    tmp=$(mktemp -d)
    if ! curl -fsSL "$url" | tar -xz -C "$tmp"; then
        rm -rf "$tmp"
        echo "❌ 下载 speedtest 二进制失败"
        return 1
    fi
    install -m 0755 "$tmp/speedtest" /usr/local/bin/speedtest
    rm -rf "$tmp"
}

# ---------- 依赖检查 ----------
check_deps() {
    local need_apt=()

    command -v curl &>/dev/null || need_apt+=("curl")
    command -v jq   &>/dev/null || need_apt+=("jq")

    # 只认 Ookla 官方版；Python 版 speedtest-cli 已失效，不再使用
    if ! command -v speedtest &>/dev/null; then
        if [ ${#need_apt[@]} -gt 0 ]; then
            echo "检测到缺少依赖: ${need_apt[*]}"
            for pkg in "${need_apt[@]}"; do
                install_pkg "$pkg" || exit 1
            done
        fi
        install_ookla || exit 1
        return 0
    fi

    if [ ${#need_apt[@]} -gt 0 ]; then
        echo "检测到缺少依赖: ${need_apt[*]}"
        for pkg in "${need_apt[@]}"; do
            install_pkg "$pkg" || exit 1
        done
    fi
}

check_deps

# ---------- IP 脱敏 ----------
mask_ip() {
    local ip="$1"
    [ -z "$ip" ] && echo "Unknown" && return

    if [[ "$ip" =~ ^([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+$ ]]; then
        echo "${BASH_REMATCH[1]}.x.x"; return
    fi
    if [[ "$ip" =~ ^::ffff:([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+$ ]]; then
        echo "::ffff:${BASH_REMATCH[1]}.x.x"; return
    fi
    if [[ "$ip" == *:* ]]; then
        local part1 part2
        part1=$(echo "$ip" | cut -d: -f1)
        part2=$(echo "$ip" | cut -d: -f2)
        echo "${part1}:${part2}:x:x"; return
    fi
    echo "$ip"
}

# ---------- 单位转换 ----------
format_speed() {
    local bps=$1
    awk -v bps="$bps" 'BEGIN {
        mbps = bps / 1e6
        if (mbps >= 1000)      printf "%.2f Gbps", bps / 1e9
        else if (mbps >= 1)    printf "%.2f Mbps", mbps
        else                   printf "%.2f Kbps", bps / 1e3
    }'
}

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║          🚀  开始测速，请稍候...             ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ---------- 测速（分步诊断） ----------
TMP_JSON=$(mktemp)
trap 'rm -f "$TMP_JSON"' EXIT

if ! speedtest --format=json --accept-license --accept-gdpr >"$TMP_JSON" 2>/tmp/sptest_err.$$; then
    echo -e "${RED}❌ speedtest 执行失败${NC}"
    if [ -s /tmp/sptest_err.$$ ]; then
        echo "错误信息："
        sed 's/^/  /' /tmp/sptest_err.$$
    fi
    rm -f /tmp/sptest_err.$$
    echo ""
    echo "常见原因："
    echo "  • 服务器无法访问 speedtest.net（网络/防火墙问题）"
    echo "  • 首次运行未接受许可（本脚本已自动接受）"
    echo "  • 二进制与系统架构不匹配"
    exit 1
fi
rm -f /tmp/sptest_err.$$

JSON=$(cat "$TMP_JSON")

if [ -z "$JSON" ] || ! echo "$JSON" | jq -e . &>/dev/null; then
    echo -e "${RED}❌ speedtest 未返回有效 JSON${NC}"
    echo "原始输出（前 500 字符）："
    echo "$JSON" | head -c 500
    echo ""
    exit 1
fi

RESULT_URL=$(echo "$JSON" | jq -r '.result.url // empty')
DOWNLOAD_BPS=$(echo "$JSON" | jq -r '(.download.bandwidth // 0) * 8')
UPLOAD_BPS=$(echo "$JSON"   | jq -r '(.upload.bandwidth   // 0) * 8')
PING=$(echo "$JSON"         | jq -r '.ping.latency // 0')
JITTER=$(echo "$JSON"       | jq -r '.ping.jitter  // 0')
ISP=$(echo "$JSON"          | jq -r '.isp // "Unknown"')
SERVER=$(echo "$JSON"       | jq -r '(.server.name // "Unknown") + ", " + (.server.location // "")')
EXTERNAL_IP=$(echo "$JSON"  | jq -r '.interface.externalIp // "Unknown"')
ELAPSED_MS=$(echo "$JSON"   | jq -r '(.download.elapsed // 0) + (.upload.elapsed // 0)')

if [ -z "$RESULT_URL" ]; then
    echo -e "${RED}❌ 测速完成但未拿到结果 URL${NC}"
    echo "可能原因：服务端返回异常，或网络中断导致部分数据缺失"
    exit 1
fi

# ---------- 处理数据 ----------
EXTERNAL_IP_MASKED=$(mask_ip "$EXTERNAL_IP")
DOWNLOAD_STR=$(format_speed "$DOWNLOAD_BPS")
UPLOAD_STR=$(format_speed "$UPLOAD_BPS")
ELAPSED_SEC=$(awk -v ms="$ELAPSED_MS" 'BEGIN { printf "%.1f", ms / 1000 }')

echo -e "${GREEN}✅ 测速完成${NC}  下载 ${BOLD}${DOWNLOAD_STR}${NC}  /  上传 ${BOLD}${UPLOAD_STR}${NC}"
echo ""

# ---------- 拼接消息 ----------
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
    # 若 sendPhoto 失败，回退用 sendMessage（图片可能是异步生成，偶发 404）
    echo -e "${YELLOW}尝试改用 sendMessage 发送文本...${NC}"
    RESPONSE2=$(curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -F "chat_id=${TG_CHAT_ID}" \
        -F "text=${MESSAGE}")
    if echo "$RESPONSE2" | jq -e '.ok == true' &>/dev/null; then
        echo -e "${GREEN}${BOLD}🎉 已改用文本消息发送成功。${NC}"
    else
        echo -e "${RED}文本发送也失败：${NC}"
        echo "$RESPONSE2"
    fi
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

# ---------- 已安装 → 管理菜单 ----------
if [ -f "$BIN_PATH" ] || [ -f "$CONF_FILE" ]; then
    echo -e "  ${YELLOW}检测到已有 sptest 安装${NC}"
    print_divider
    print_menu_item "1" "修改配置并重装"
    print_menu_item "2" "卸载"
    print_menu_item "3" "退出"
    print_divider
    echo ""
    safe_read choice "$(echo -e "  ${GREEN}请选择 [1/2/3]: ${NC}")"

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

# ---------- 首次安装 ----------
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
