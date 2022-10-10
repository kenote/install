#! /bin/bash

git_release="git-2.37.1"

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

# 安装 git
function install_git(){
    echo -e "开始安装 ${git_release} ..."
    cd $HOME
    if [[ $system == 'debian' ]]; then
        sudo apt install -y  build-essential
        sudo apt install  -y libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev
    elif [[ $system == 'centos' ]]; then
        sudo yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel gcc-c++ perl-ExtUtils-MakeMaker
        sudo yum -y remove git
    else
        sudo apt update
        sudo apt install dh-autoreconf libcurl4-gnutls-dev libexpat1-dev make gettext libz-dev libssl-dev libghc-zlib-dev
    fi
    wget https://www.kernel.org/pub/software/scm/git/${git_release}.tar.gz
    tar -zxvf ${git_release}.tar.gz
    cd ${git_release}
    make prefix=/usr/local/git all
    make prefix=/usr/local/git install
    ln -s /usr/local/git/bin/git /usr/bin/git
    git --version
}

init_env
install_git