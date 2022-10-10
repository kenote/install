#! /bin/bash

#彩色
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}

type=$1

#检查系统
check_sys(){
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
}

# 获取公网ip
function getip(){
    echo
    curl ip.p3terx.com
    echo
}

# 查看系统信息
function getsys(){
    sys_release=`cat /etc/os-release | grep "PRETTY_NAME" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
    if [[ $release == 'centos' ]]; then
        sys_release=`cat /etc/redhat-release`
    fi
    core_version=`uname -sr`
    cpu_name=`cat /proc/cpuinfo | grep "model name" | sed 's/\(.*\)\:\s\(.*\)/\2/g' | uniq`
    cpu_mhz=`cat /proc/cpuinfo | grep "cpu MHz" | sed 's/\(.*\)\:\s\(.*\)/\2/g' | uniq`
    cpu_num=`cat /proc/cpuinfo | grep "physical id" | sort | uniq | wc -l`
    cpu_cores=`cat /proc/cpuinfo | grep "cpu cores" | sed 's/\(.*\)\:\s\(.*\)/\2/g' | uniq`
    mem_size=`cat /proc/meminfo | grep "MemTotal" | sed -E 's/[^0-9]//g'`
    mem_size_gb=`echo "scale=2; a = $mem_size / 1048576; if (length(a)==scale(a)) print 0;print a" |bc`
    mem_size_mb=`echo "scale=0; a = $mem_size / 1024; if (length(a)==scale(a)) print 0;print a" |bc`
    disk_info=`fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d"`
    echo
    echo -e "操作系统: ${sys_release}"
    echo -e "内核版本: ${core_version}"
    echo -e "硬件架构: $(arch)"
    echo
    echo -e "======= CPU 信息 ======="
    echo -e "型号: ${cpu_name}"
    echo -e "频率: ${cpu_mhz} MHz"
    echo -e "数量: ${cpu_num}"
    echo -e "核心数: ${cpu_cores}"
    echo
    echo -e "======= 内存大小 ======="
    echo -e "GB: $mem_size_gb Gb"
    echo -e "MB: $mem_size_mb Mb"
    echo -e "KB: $mem_size Kb"
    echo
    echo -e "======= 磁盘信息 ======="
    echo -e $disk_info
    echo
    echo -e "======= 本机 IP ======="
    echo -e $(hostname -I)
    echo
}

# 主菜单
function start_menu(){
    clear
    red " Kenote 综合工具箱 Linux Supported ONLY" 
    green " FROM: https://github.com/kenote/install "
    green " USE:  wget -O start.sh https://raw.githubusercontent.com/kenote/install/main/start.sh && chmod +x start.sh && clear && ./start.sh "
    yellow " =================================================="
    green " 1. 获取公网IP" 
    green " 2. 查看系统信息" 
    green " =================================================="
    green " 0. 退出脚本"
    echo
    read -p "请输入数字: " menuNumberInput
    case "$menuNumberInput" in
        1 )
            clear
            getip
        ;;
        2 )
            clear
            getsys
        ;;
        0 )
            clear
            exit 1
        ;;
        * )
            clear
            red "请输入正确数字 !"
            sleep 3
            start_menu
        ;;
    esac
}

case $type in
    release )
        check_sys
        echo $release
    ;;
    ip )
        getip
    ;;
    system )
        getsys
    ;;
    * )
        check_sys
        start_menu
    ;;
esac