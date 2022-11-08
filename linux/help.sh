#! /bin/bash

current_dir=$(cd $(dirname $0);pwd)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 判断命令是否存在
is_command() { command -v $@ &> /dev/null; }

# 判断是否海外网络
is_oversea() {
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
}

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
    if (is_oversea); then
        urlroot="https://raw.githubusercontent.com/kenote/install"
    else
        urlroot="https://gitee.com/kenote/install/raw"
    fi
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

getsys(){
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
    # echo -e $disk_info
    fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d"
    echo
    echo -e "======= 本机 IP ======="
    echo -e $(hostname -I)
    echo
    echo -e "======= 主机名 ======="
    echo -e $(hostname)
    echo -e $(hostname -f)
    echo

    echo -e "======= 系统信息 ======="
    echo -e "SELINUX: $(getenforce)"
    timedatectl | grep "Time zone" | sed -E 's/^(\s+)//'
    timedatectl | grep "Local time" | sed -E 's/^(\s+)//'
    timedatectl | grep "Universal time" | sed -E 's/^(\s+)//'
}

getip(){
    echo
    curl ip.p3terx.com
    echo
}

initial_sys() {

    if [[ $release == 'centos' ]]; then
        yum update -y
        yum install -y net-tools vim nano jq
    else
        apt update -y
        apt install -y net-tools bc vim nano jq
    fi
    if !(command -v htop); then
        curl -o- ${urlroot}/main/linux/install-htop.sh | bash
    fi
    if !(command -v git); then
        curl -o- ${urlroot}/main/linux/install-git.sh | bash
    fi
}

# 设置主机名
set_hostname() {
    _hostname=$1
    if [[ $_hostname == '' ]]; then
        while read -p "主机名: " _hostname;
        do
            if [[ $_hostname == '' ]]; then
                echo -e "${red}请填写主机名！${plain}"
                continue
            fi
            break
        done
    fi
    _litename=`echo "$_hostname" | awk -F '.' '{print $1}'`
    is_hostname=`cat /etc/hosts | grep "$_hostname"`
    if [[ $is_hostname != '' ]]; then
        sed -i "/$_hostname/d" /etc/hosts
    fi
    # hostnamectl set-hostname $_hostname
    echo -e "
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.0.1   $_hostname $_litename
    " > /etc/hosts
    echo "$_hostname" > /etc/hostname
    hostname -F /etc/hostname
    echo -e "${green}主机名已设置为-[$_hostname]-, 请重启下终端！${plain}"
}

# 设置时区
set_timezone() {
    area=""
    timezone=""
    echo -e "${yellow}选择地区：${plain}"
    list=(Africa America Antarctica Arctic Asia Atlantic Australia Europe Indian Pacific)
    select item in ${list[@]};
    do
        area=$item
        break
    done
    echo -e "${yellow}选择-[${area}]-时区：${plain}"
    timezones=`timedatectl list-timezones | grep -E "^$area"`
    select item in ${timezones[@]};
    do
        timezone=$item
        break
    done
    sudo timedatectl set-timezone $timezone
    echo -e "${green}设置系统时区-[$timezone]-完成${plain}"
    timedatectl
}

# 设置SELINUX
set_selinux() {
    _status=`cat /etc/selinux/config | grep -E "^SELINUX=" | sed -e 's/^SELINUX=//'`
    mode=""
    echo -e "${yellow}设置SELINUX：${plain}"
    list=(强制模式 宽容模式 关闭SELINUX)
    _index=0
    select item in ${list[@]};
    do
        case $item in
        强制模式)
            mode="enforcing"
            _index=1
        ;;
        宽容模式)
            mode="permissive"
            _index=0
        ;;
        关闭SELINUX)
            mode="disabled"
        ;;
        esac
        break
    done
    sed -i "s/$(cat /etc/selinux/config | grep -E "^SELINUX=")/SELINUX=$mode/" /etc/selinux/config
    if [[ $_status == 'disabled' ]]; then
        echo -e "${green}SELINUX 设置完成，需要重启系统才能生效${plain}"
    else
        if [[ $mode == 'disabled' ]]; then
            echo -e "${green}SELINUX 设置完成，需要重启系统才能生效${plain}"
        else
            setenforce $_index
            getenforce
            echo -e "${green}SELINUX 设置完成${plain}"
        fi
        
    fi
}

# 修改ROOT密码
set_passwd() {
    _user=$1
    while read -p "设置-[$_user]-密码：" _passwoed
    do
        if [[ $_passwoed == '' ]]; then
            echo -e "${red}密码不能为空${plain}"
            continue
        fi
        break
    done
    confirm "确定要修改-[$_user]-的密码吗?" "n"
    if [[ $? == 0 ]]; then
        echo "$_passwoed" | passwd root --stdin > /dev/null 2>&1
        echo -e "${yellow}修改-[$_user]-新密码为: ${_passwoed}${plain}"
    fi
}


show_menu() {
    echo -e "
  ${green}服务器运维工具${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 系统信息
  ${green} 2${plain}. 公网 IP
  ${green} 3${plain}. 初始化系统
 ------------------------
  ${green} 4${plain}. 设置主机名
  ${green} 5${plain}. 设置时区
  ${green} 6${plain}. 设置SELINUX
  ${green} 7${plain}. 设置ROOT密码
  ${green} 8${plain}. 进程管理
  ${green} 9${plain}. Firewall 防火墙
 ------------------------
  ${green}10${plain}. SWAP 管理
  ${green}11${plain}. 磁盘分区管理
  ${green}12${plain}. Nginx 管理助手
    "
  
    echo && read -p "请输入选择 [0-14]: " num
    echo
    case "${num}" in
        0)
            exit 0
        ;;
        1)
            clear
            getsys
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        2)
            clear
            getip
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        3)
            clear
            initial_sys
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        4)
            clear
            set_hostname
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        5)
            clear
            set_timezone
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        6)
            clear
            set_selinux
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        7)
            clear
            set_passwd root
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        8)
            clear
            if (is_command htop); then
                htop
            else
                top
            fi
            clear
            show_menu
        ;;
        9)
            clear
            run_script firewall.sh
        ;;
        10)
            clear
            run_script swap.sh
        ;;
        11)
            clear
            run_script disk.sh
        ;;
        12)
            clear
            run_script nginx/help.sh
        ;;
        *  )
            echo -e "${red}请输入正确的数字 [0-14]${plain}"
        ;;
    esac
}

run_script() {
    file=""
    dir=""
    url=""
    files=(`echo $1 | sed 's/\// /'`)
    if [[ ${#files[@]} > 1 ]]; then
        type=${files[0]}
        file=${files[1]}
        dir=$current_dir/$type
        url=$type/$file
        mkdir -p $dir
    else
        file=${files[0]}
        dir=$current_dir
        url=$file
    fi
    if [[ -f $dir/$file ]]; then
        sh $dir/$file "${@:2}"
    else
        # mkdir -p  $dir
        wget -O $dir/$file ${urlroot}/main/linux/$url && chmod +x $dir/$file && clear && $dir/$file "${@:2}"
    fi
}

check_sys
show_menu