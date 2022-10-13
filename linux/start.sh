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

# 判断是否海外网络
function is_oversea(){
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
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
    green " 海外:  wget -O start.sh https://raw.githubusercontent.com/kenote/install/main/linux/start.sh && chmod +x start.sh && clear && ./start.sh "
    green " 国内:  wget -O start.sh https://gitee.com/kenote/install/raw/main/linux/start.sh && chmod +x start.sh && clear && ./start.sh "
    yellow " =================================================="
    green " 1. 获取公网IP" 
    green " 2. 查看系统信息" 
    yellow " --------------------------------------------------"
    green " 11. 安装最新版 Git" 
    green " 12. 安装 Htop" 
    green " 13. 安装 Nginx 新版"
    green " 14. 升级 OpenSSL 1.1.1"
    green " 15. 更新 Nginx, 以支持 TLS1.3"
    yellow " --------------------------------------------------"
    green " 31. 创建 Nginx 站点并申请 Let's Encrypt 证书"
    green " 32. 查看 Nginx 信息"
    green " 33. 更改 Nginx 配置文件路径"
    green " 34. 禁止使用 IP 访问"
    green " 35. 开启使用 IP 访问"
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
        11 )
            clear
            if (is_oversea); then
                curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-git.sh | bash
            else
                curl -o- https://gitee.com/kenote/install/raw/main/linux/install-git.sh | bash
            fi
        ;;
        12 )
            clear
            if (is_oversea); then
                curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-htop.sh | bash
            else
                curl -o- https://gitee.com/kenote/install/raw/main/linux/install-htop.sh | bash
            fi
        ;;
        13 )
            clear
            if (is_oversea); then
                curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh | bash
            else
                curl -o- https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh | bash
            fi
        ;;
        14 )
            clear
            if (is_oversea); then
                bash <(curl -s https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh) openssl
            else
                bash <(curl -s https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh) openssl
            fi
        ;;
        15 )
            clear
            if (is_oversea); then
                bash <(curl -s https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh) update
            else
                bash <(curl -s https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh) update
            fi
        ;;
        31 )
            clear
            if (is_oversea); then
                wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh create
            else
                wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh create
            fi
        ;;
        32 )
            clear
            if (is_oversea); then
                wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh info
            else
                wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh info
            fi
        ;;
        33 )
            clear
            if (is_oversea); then
                wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh workdir
            else
                wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh workdir
            fi
        ;;
        34 )
            clear
            if (is_oversea); then
                wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh not_useip
            else
                wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh not_useip
            fi
        ;;
        35 )
            clear
            if (is_oversea); then
                wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh yes_useip
            else
                wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh yes_useip
            fi
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
    oversea )
        if (is_oversea); then
            echo 1
        else
            echo 0
        fi
    ;;
    * )
        check_sys
        start_menu
    ;;
esac