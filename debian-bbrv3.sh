#!/usr/bin/env bash

# 1. 检查是否为 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "错误：请以 root 权限运行此脚本！"
  exit 1
fi

# 2. 检查 CPU 架构 (XanMod 官方内核仅支持 x86_64)
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
  echo "======================================================"
  echo " 架构不支持: 检测到当前 CPU 为 $ARCH"
  echo " XanMod BBRv3 内核仅支持 x86_64 (AMD/Intel) 架构。"
  echo " 如果这是 ARM 机器 (如 Oracle ARM)，请使用系统自带的 BBRv1。"
  echo "======================================================"
  
  # 针对 ARM 机器退而求其次，直接开启自带的 BBRv1
  echo "正在为您开启 Debian 12 原生 BBRv1..."
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p
  echo "原生 BBRv1 已开启！"
  exit 0
fi

echo "======================================================"
echo " 开始在 Debian 12 (x86_64) 上安装 XanMod 内核 (BBRv3)"
echo "======================================================"

# 3. 安装必备依赖
apt update && apt install -y wget gnupg2

# 4. 导入 XanMod 官方 GPG 密钥和软件源
echo "=> 正在配置 XanMod 软件源..."
wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list

# 5. 更新源并安装内核 (使用 x64v1 以确保 1C1G 老旧 CPU 的最高兼容性)
echo "=> 正在下载并安装 XanMod 内核，请耐心等待..."
apt update
apt install -y linux-xanmod-x64v1

# 6. 配置 BBR 参数 (XanMod 默认将 bbr 映射为 bbrv3)
echo "=> 正在配置系统网络参数..."
# 清理旧配置避免重复
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
# 写入新配置
cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

# 立即应用配置
sysctl -p

echo "======================================================"
echo " BBRv3 / XanMod 内核安装完成！"
echo " 系统需要重启才能加载新内核并使 BBRv3 生效。"
echo "======================================================"
read -p "是否立即重启服务器？(y/n): " REBOOT_CHOICE

if [[ "$REBOOT_CHOICE" == "y" || "$REBOOT_CHOICE" == "Y" ]]; then
    echo "正在重启..."
    reboot
else
    echo "请记得稍后手动执行 reboot 命令重启服务器。"
fi
