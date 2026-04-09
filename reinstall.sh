#!/usr/bin/env bash

# 1. 检查是否为 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误：请以 root 权限运行此脚本！"
    exit 1
fi

# 2. 检查基础命令依赖 (增加 curl 依赖，底层脚本常用)
for cmd in wget ip awk grep curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "未找到命令: $cmd，请先使用 apt/yum 等包管理器安装。"
        exit 1
    fi
done

# 3. 动态配置 Root 密码
read -p "请输入重装后的 root 密码 (直接回车默认设置为: MySecurePass2026!): " CUSTOM_PWD
CUSTOM_PWD=${CUSTOM_PWD:-MySecurePass2026!}

# 动态配置 SSH 端口
read -p "请输入自定义 SSH 端口 (直接回车默认保留为: 22): " CUSTOM_PORT
CUSTOM_PORT=${CUSTOM_PORT:-22}

# 4. 下载核心执行脚本 (修复了真实的底层脚本直连地址)
CORE_SCRIPT="InstallNET.sh"
wget --no-check-certificate -qO $CORE_SCRIPT "https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"

if [ ! -s "$CORE_SCRIPT" ]; then
    echo "核心脚本下载失败，请检查网络。"
    exit 1
fi
chmod a+x $CORE_SCRIPT

# 5. 关闭 SELinux (针对可能运行在 CentOS/AlmaLinux 上的情况)
if [ -f /etc/selinux/config ]; then
    SELinuxStatus=$(sestatus -v | grep "SELinux status:" | grep enabled)
    [[ "$SELinuxStatus" != "" ]] && setenforce 0
fi

clear
echo "=============================================================="
echo " 网络一键重装系统脚本 (兼容 Oracle Cloud & CloudCone)"
echo " 重装后的 Root 密码为: $CUSTOM_PWD"
echo " 注意: 底层脚本将自动扫描并完美保留您的 IPv4 和 IPv6 配置"
echo "=============================================================="
echo "请选择您需要的镜像包:"
echo "  1) Debian 12 (Bookworm) - 【推荐：极简轻量】"
echo "  2) Debian 13 (Trixie)"
echo "  3) Ubuntu 20.04 LTS"
echo "  4) Ubuntu 22.04 LTS"
echo "  5) Ubuntu 24.04 LTS"
echo "  0) 退出"
echo "=============================================================="
read -p "请输入编号: " N

# 适配了新底层脚本的参数格式 (-debian 12 -pwd 密码)
case $N in
    1) bash $CORE_SCRIPT -debian 12 -pwd "$CUSTOM_PWD" -port "$CUSTOM_PORT" -firmware --nomemcheck ;;
    2) bash $CORE_SCRIPT -debian 13 -pwd "$CUSTOM_PWD" -port "$CUSTOM_PORT" -firmware --nomemcheck ;;
    3) bash $CORE_SCRIPT -ubuntu 20.04 -pwd "$CUSTOM_PWD" -port "$CUSTOM_PORT" -firmware --nomemcheck ;;
    4) bash $CORE_SCRIPT -ubuntu 22.04 -pwd "$CUSTOM_PWD" -port "$CUSTOM_PORT" -firmware --nomemcheck ;;
    5) bash $CORE_SCRIPT -ubuntu 24.04 -pwd "$CUSTOM_PWD" -port "$CUSTOM_PORT" -firmware --nomemcheck ;;
    0) exit 0 ;;
    *) echo "输入错误" ;;
esac
