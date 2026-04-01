#!/usr/bin/env bash

# 1. 检查是否为 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "错误：请以 root 权限运行此脚本！"
  exit 1
fi

# 2. 检查基础命令依赖
for cmd in wget ip awk grep; do
  if ! command -v $cmd &> /dev/null; then
    echo "未找到命令: $cmd，请先使用 apt/yum 等包管理器安装。"
    exit 1
  fi
done

# 3. 动态配置 Root 密码（避免硬编码安全隐患）
read -p "请输入重装后的 root 密码 (直接回车默认设置为: MySecurePass2026!): " CUSTOM_PWD
CUSTOM_PWD=${CUSTOM_PWD:-MySecurePass2026!}

# 4. 设定 GitHub 仓库地址 (⚠️上传前请将此处的 URL 替换为您真实的 GitHub Raw 链接)
GITHUB_RAW_URL="https://raw.githubusercontent.com/noa1188/reinstall/refs/heads/main"

# 安全下载核心执行脚本 (去掉 --no-check-certificate 优先走正常 HTTPS)
wget -qO network-reinstall.sh "$GITHUB_RAW_URL/network-reinstall.sh"
if [ ! -f "network-reinstall.sh" ]; then
    echo "核心脚本下载失败，请检查网络或 GITHUB_RAW_URL 是否正确。"
    exit 1
fi
chmod a+x network-reinstall.sh

# 5. 获取网络信息
MAINIP=$(ip route get 1 | awk '{print $7;exit}')
GATEWAYIP=$(ip route | grep default | awk '{print $3}')
SUBNET=$(ip -o -f inet addr show | awk '/scope global/{sub(/[^.]+\//,"0/",$4);print $4}' | head -1 | awk -F '/' '{print $2}')
value=$(( 0xffffffff ^ ((1 << (32 - $SUBNET)) - 1) ))
NETMASK="$(( (value >> 24) & 0xff )).$(( (value >> 16) & 0xff )).$(( (value >> 8) & 0xff )).$(( value & 0xff ))"

# 关闭 SELinux
if [ -f /etc/selinux/config ]; then
    SELinuxStatus=$(sestatus -v | grep "SELinux status:" | grep enabled)
    [[ "$SELinuxStatus" != "" ]] && setenforce 0
fi

clear
echo "=============================================================="
echo " 网络一键重装系统脚本 (GitHub 定制优化版)"
echo " IP: $MAINIP/$SUBNET"
echo " 网关: $GATEWAYIP"
echo " 重装后的 Root 密码为: $CUSTOM_PWD"
echo "=============================================================="
echo "请选择您需要的镜像包:"
echo " 1) Debian 12 (Bookworm) - 【推荐：极简轻量】"
echo " 2) Debian 13 (Trixie)"
echo " 3) Ubuntu 20.04 LTS (Focal Fossa)"
echo " 4) Ubuntu 22.04 LTS (Jammy Jellyfish)"
echo " 5) Ubuntu 24.04 LTS (Noble Numbat)"
echo " 6) 自定义 DD RAW 镜像 (需提供直连 URL)"
echo " 0) 退出"
echo "=============================================================="
read -p "请输入编号: " N

case $N in
  1) bash network-reinstall.sh -d 12 -p "$CUSTOM_PWD" ;;
  2) bash network-reinstall.sh -d 13 -p "$CUSTOM_PWD" ;;
  3) bash network-reinstall.sh -u 20.04 -p "$CUSTOM_PWD" ;;
  4) bash network-reinstall.sh -u 22.04 -p "$CUSTOM_PWD" ;;
  5) bash network-reinstall.sh -u 24.04 -p "$CUSTOM_PWD" ;;
  6) 
     read -p "请输入 RAW/DD 镜像的 .gz 或 .xz 直连链接: " DD_URL
     bash network-reinstall.sh -dd "$DD_URL"
     ;;
  0) exit 0 ;;
  *) echo "输入错误" ;;
esac
