#! /bin/bash

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

# 安装 htop
install_htop() {
    if (command -v htop); then
        echo -e "htop 已经存在, 无需安装"
    else
        echo -e "开始安装 htop ..."
        cd $HOME
        if [[ $release == 'centos' ]]; then
            version=`cat /etc/os-release | grep "VERSION_ID" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
            yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$version.noarch.rpm -y
            yum install -y htop
        else
            apt install -y htop
        fi
    fi
}

check_sys
install_htop