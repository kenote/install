#! /bin/bash

# 判断是否海外网络
function is_oversea(){
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
}

# 初始化环境
function init_env(){
    if (is_oversea); then
        urlroot="https://raw.githubusercontent.com/kenote/install"
    else
        urlroot="https://gitee.com/kenote/install/raw"
    fi
    if [ -f './start.sh' ]; then
        system=`./start.sh release`
    else
        system=`wget -O start.sh ${urlroot}/main/linux/start.sh && chmod +x start.sh && clear && ./start.sh release`
    fi
}

# 安装 htop
function install_htop(){
    if (command -v htop); then
        echo -e "htop 已经存在, 无需安装"
    else
        echo -e "开始安装 htop ..."
        cd $HOME
        if [[ $system == 'centos' ]]; then
            version=`cat /etc/os-release | grep "VERSION_ID" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
            yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$version.noarch.rpm -y
            yum install -y htop
        else
            apt install -y htop
        fi
    fi
}

init_env
install_htop