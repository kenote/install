#! /bin/bash

ssldir=/home/ssl

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 获取 nginx 变量
get_nginx_env() {
    # 获取 nginx 主路径; 一般为: /etc/nginx
    rootdir=`find /etc /usr/local -name nginx.conf | sed -e 's/\/nginx\.conf//'`
    # 获取 nginx 配置文件夹路径; 一般为: /etc/nginx/conf.d
    conflink=`cat ${rootdir}/nginx.conf | grep "conf.d/\*.conf;" | sed -e 's/\s//g' | sed -e 's/include//' | sed -e 's/\/\*\.conf\;//'`
    # 获取 nginx 配置文件夹真实路径
    confdir=`readlink -f ${conflink}`
    # 获取 ssl 存放目录
    if [[ $confdir != $conflink ]]; then
        ssldir=`readlink -f ${conflink} | sed -e 's/\/conf$/\/ssl/'`
    fi
    echo -e "
NGINX_CONF=$confdir
SSL_DIR=$ssldir
    " > /root/.nginx_profile
}

# 初始化配置目录
init_nginx_conf() {
    workdir=$1
    if [[ $1 == '' ]]; then
        read -p "设置工作目录: " workdir
    fi
    if [[ $workdir == '' ]]; then
        echo -e "${red}工作目录不能为空${plain}"
        return 1
    fi
    echo -e "${yellow}工作目录: $workdir${plain}"
    echo -e "NGINX_WORKDIR=$workdir" >> /root/.nginx_profile
    # 创建工作目录
    mkdir -p $workdir
    mkdir -p $workdir/proxys
    mkdir -p $workdir/upstream
    mkdir -p $workdir/stream/server
    mkdir -p $workdir/stream/upstream
    # 备份原配置文件
    cp -r $confdir/.  $conflink.bak
    # 移动配置目录
    if [[ ! -d $workdir/conf ]]; then
        mv $confdir $workdir/conf
    fi
    rm -rf ${conflink}
    echo -e "ln -s $workdir/conf $conflink"
    ln -s $workdir/conf $conflink
    if [[ -d $confdir/conf.d ]]; then
        rm -rf $confdir/conf.d
    fi
    mv $confdir/*.conf.rpmsave $(echo $confdir/default.conf.rpmsave | sed 's/.rpmsave$//')
    # 添加负载均衡配置目录
    upstream=`cat /etc/nginx/nginx.conf | grep "/upstream/\*.conf;"`;
    if [[ $upstream == '' ]]; then
        sed -i "/include \/etc\/nginx\/conf.d\/\*.conf;/a\    include $workdir/upstream/\*.conf;" /etc/nginx/nginx.conf
    fi
    # 添加TCP转发配置目录
    stream=`cat /etc/nginx/nginx.conf | grep "/stream/index.conf;"`;
    if [[ $stream == '' ]]; then
        sed -i "/http {/i\include $workdir/stream/index.conf;\n" /etc/nginx/nginx.conf
    fi
    echo -e "
stream {
    include $workdir/stream/server/*.conf;
    include $workdir/stream/upstream/*.conf;
}
    " > $workdir/stream/index.conf
    # 重启 nginx
    systemctl restart nginx
    echo -e "${green}Nginx 工作目录已迁移至 ${workdir}${plain}"
}

get_nginx_env
init_nginx_conf "$@"