#!/usr/bin/env bash
# 2026.3.21：Claude Sonnet 4.6 修改

Green="\033[32m"
Font="\033[0m"
Red="\033[31m"

root_need() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Red}Error: This script must be run as root!${Font}"
        exit 1
    fi
}

ovz_no() {
    if [[ -d "/proc/vz" ]]; then
        echo -e "${Red}Your VPS is based on OpenVZ, not supported!${Font}"
        exit 1
    fi
}

add_swap() {
    # 获取总内存 (MB) 并给出推荐值
    local mem_mb
    mem_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
    local recommend=$(( mem_mb / 2 ))
    [[ $recommend -lt 512 ]] && recommend=512

    echo -e "${Green}当前内存: ${mem_mb}MB，推荐 swap 大小: ${recommend}MB（1c1g 建议 512M~1G）${Font}"
    read -p "请输入 swap 大小 (MB，直接回车使用推荐值 ${recommend}MB): " swapsize
    swapsize=${swapsize:-$recommend}

    # 输入验证
    if ! [[ "$swapsize" =~ ^[0-9]+$ ]] || [[ "$swapsize" -lt 128 ]] || [[ "$swapsize" -gt 8192 ]]; then
        echo -e "${Red}输入无效，请输入 128~8192 之间的整数！${Font}"
        return 1
    fi

    # 检查磁盘空间
    local free_mb
    free_mb=$(df / --output=avail -BM | tail -1 | tr -d 'M')
    if [[ "$free_mb" -lt "$swapsize" ]]; then
        echo -e "${Red}磁盘空间不足！可用: ${free_mb}MB，需要: ${swapsize}MB${Font}"
        return 1
    fi

    # 检查是否已存在 swapfile
    if grep -q "swapfile" /etc/fstab || swapon --show | grep -q "/swapfile"; then
        echo -e "${Red}swapfile 已存在，请先删除后重试！${Font}"
        return 1
    fi

    echo -e "${Green}正在创建 ${swapsize}MB 的 swapfile...${Font}"

    # fallocate 失败则回退 dd（兼容 btrfs 等文件系统）
    if ! fallocate -l "${swapsize}M" /swapfile 2>/dev/null; then
        echo -e "${Green}fallocate 不支持，改用 dd 创建...${Font}"
        dd if=/dev/zero of=/swapfile bs=1M count="$swapsize" status=progress
    fi

    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap defaults 0 0' >> /etc/fstab

    # 针对 1c1g 优化内核参数
    echo -e "${Green}优化内核 swap 参数（vm.swappiness=10, vfs_cache_pressure=50）...${Font}"
    sysctl -w vm.swappiness=10
    sysctl -w vm.vfs_cache_pressure=50

    grep -q "vm.swappiness" /etc/sysctl.conf && \
        sed -i 's/vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf || \
        echo "vm.swappiness=10" >> /etc/sysctl.conf

    grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf && \
        sed -i 's/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf || \
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

    echo -e "${Green}swap 创建成功！当前状态：${Font}"
    swapon --show
    free -h
}

del_swap() {
    if grep -q "swapfile" /etc/fstab || swapon --show | grep -q "/swapfile"; then
        echo -e "${Green}正在移除 swapfile...${Font}"
        swapoff /swapfile 2>/dev/null || swapoff -a
        sed -i '/swapfile/d' /etc/fstab
        rm -f /swapfile
        echo -e "${Green}swap 已删除！${Font}"
    else
        echo -e "${Red}未发现 swapfile，删除失败！${Font}"
    fi
}

main() {
    root_need
    ovz_no
    while true; do
        clear
        echo -e "———————————————————————————————————————"
        echo -e "${Green}Linux VPS 一键添加/删除 swap 脚本${Font}"
        echo -e "${Green}1、添加 swap${Font}"
        echo -e "${Green}2、删除 swap${Font}"
        echo -e "———————————————————————————————————————"
        read -p "请输入数字 [1-2]: " num
        case "$num" in
            1) add_swap; break ;;
            2) del_swap; break ;;
            *)
                echo -e "${Green}请输入正确数字 [1-2]${Font}"
                sleep 2s
                ;;
        esac
    done
}

main
