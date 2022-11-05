#! /bin/bash

git_release="git-2.37.1"

get_release_version() {
    list=(`wget -qO- https://mirrors.edge.kernel.org/pub/software/scm/git/ | grep -E "git-[1-9]" | sed 's/<[^>]*>//g' | awk -F ' ' '{print $1}' | grep ".tar.gz"`)
    release_version="1.0.0"
    value=0
    for item in ${list[@]};
    do
        tmpval=`echo $item | sed -E 's/(git-|\.tar\.gz)//g'`
        if ( test "$(echo "$release_version $tmpval" | tr " " "\n" | sort -V | head -n 1)" != "$tmpval" ); then
            release_version=$tmpval
        fi
    done
    git_release="git-$release_version"
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
}

# 安装 git
install_git() {
    echo -e "开始安装 ${git_release} ..."
    cd $HOME
    if [[ $release == 'debian' ]]; then
        sudo apt install -y  build-essential
        sudo apt install  -y libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev
    elif [[ $release == 'centos' ]]; then
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

get_release_version
check_sys
install_git