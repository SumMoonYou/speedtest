# 🚀 sptest - 网络测速 + Telegram 推送

一个轻量的 Linux 网络测速工具，基于 Ookla Speedtest，测速完成后自动把结果和测速图推送到你的 Telegram。

## ✨ 特性

- 🚀 一键测速，自动适配 Ookla 官方版 / Python 版 `speedtest-cli`
- 📤 测速结果 + 官方测速图自动推送到 Telegram
- 🎨 消息格式美观，自动切换 `Mbps` / `Gbps` / `Kbps` 单位
- 🖥️ 兼容主流 Linux 发行版（Debian / Ubuntu / CentOS / RHEL / Fedora / Arch / Alpine / openSUSE）
- ⚙️ 交互式配置，Token 与 Chat ID 保存在本地，不写死在代码里
- 🧩 首次安装后直接输入 `sptest` 即可运行
- 🔄 支持重新配置和卸载

## 📦 安装

### 前置要求

- Linux 系统
- root 权限（需要写入 `/usr/local/bin`）
- `curl`（安装脚本会自动安装缺失依赖）

### 一键安装

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/SumMoonYou/speedtest/refs/heads/main/install.sh)" @ install
```

首次运行会提示你输入：

- **Telegram Bot Token**：找 [@BotFather](https://t.me/BotFather) 创建机器人获取
- **Telegram Chat ID**：找 [@getmyid_bot](https://t.me/getmyid_bot) 获取

配置会保存到 `~/.sptest.conf`（权限 600），主脚本会安装到 `/usr/local/bin/sptest`。

> ⚠️ 提示：创建完机器人后，**一定要先给机器人发送一条消息**（如 `/start`），否则机器人无法主动给你推送。

## 🚀 使用

安装完成后，直接输入：

```bash
sptest
```

测速完成后，你会收到类似这样的 Telegram 消息：

```
🚀 网络测速

📍 节点: Melbicom Los Angeles, CA
🏢 运营商: IT7 Networks Inc
🌐 出口: 23.106.x.x

⏱️ 延迟: 0.6 ms（抖动 0.0 ms）
⬇️ 下载: 12.86 Gbps
⬆️ 上传: 9.14 Gbps

🔗 详细结果 (https://www.speedtest.net/result/c/...)
来源 Ookla Speedtest · 用时 18.6 秒
```

同时附上官方生成的测速图。

## 🔧 管理

再次运行 `install.sh` 会进入管理菜单：

```bash
sudo ./install.sh
```

```
╔══════════════════════════════════════════════╗
║          🚀  sptest 网络测速工具             ║
╚══════════════════════════════════════════════╝

  检测到已有 sptest 安装
──────────────────────────────────────────────
  [1]  修改配置并重装
  [2]  卸载
  [3]  退出
──────────────────────────────────────────────

  请选择 [1/2/3]:
```

- **修改配置**：重新输入 Token 和 Chat ID，覆盖旧配置
- **卸载**：删除 `sptest` 命令，可选是否删除配置文件

## 🖥️ 兼容性

| 系统 | 包管理器 | 支持 |
|---|---|---|
| Debian / Ubuntu | apt | ✅ |
| RHEL / CentOS / Fedora | yum / dnf | ✅ |
| Arch / Manjaro | pacman | ✅ |
| Alpine | apk | ✅ |
| openSUSE | zypper | ✅ |

脚本会自动检测包管理器并安装依赖（`curl`、`jq`、`speedtest-cli`）。

## 📁 文件说明

| 路径 | 说明 |
|---|---|
| `/usr/local/bin/sptest` | 主脚本，安装后可直接调用 |
| `~/.sptest.conf` | 配置文件，保存 Telegram Token 和 Chat ID |

## ❓ 常见问题

### 1. 提示 `Invalid API v1 key`？

这是早期使用 ImgBB 图床时的报错。当前版本已改为直接发送到 Telegram，不再依赖图床 API。

### 2. 提示 `speedtest: error: unrecognized arguments`？

系统中安装的是 Python 版 `speedtest-cli`，而脚本按 Ookla 官方版参数调用。当前版本已自动识别两种版本，不需要手动处理。

### 3. 提示 `trying to overwrite '/usr/bin/speedtest'`？

系统里已经装了 Ookla 官方版 `speedtest`，而安装脚本又试图装 `speedtest-cli`，两者路径冲突。当前版本的依赖检查逻辑是 **`speedtest` 或 `speedtest-cli` 任一存在即可**，不会重复安装。

### 4. 测速数值和官方图不一致？

早期版本误把官方版 `bandwidth` 当成字节/秒乘以 8，导致数值放大 8 倍。当前版本已修正，直接使用 `bandwidth` 原值。

### 5. Telegram 没有收到消息？

检查以下几点：

- 是否已经给机器人发送过 `/start`
- `TG_BOT_TOKEN` 和 `TG_CHAT_ID` 是否正确
- 服务器能否访问 `api.telegram.org`（部分地区需要代理）

### 6. 换用户后 `sptest` 找不到配置？

配置保存在 `$HOME/.sptest.conf`。如果用 `sudo` 安装，配置会存在 `/root/.sptest.conf`，普通用户运行时读不到。建议统一用 root 运行，或手动把配置复制到对应用户的家目录。

## 📄 License

MIT
