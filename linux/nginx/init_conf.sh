#! /bin/bash

default_workdir=/home/nginx-data

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 判断是否海外网络
is_oversea() {
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
}

check_sys(){
    if (is_oversea); then
        REPOSITORY_RAW_ROOT="https://raw.githubusercontent.com/kenote/install"
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
    fi
    REPOSITORY_RAW_URL="${REPOSITORY_RAW_ROOT}/main/linux/nginx"
}

# 获取 nginx 变量
get_nginx_env() {
    # 获取 nginx 主路径; 一般为: /etc/nginx
    rootdir=`find /etc /usr/local -name nginx.conf | sed -e 's/\/nginx\.conf//'`
    # 获取 nginx 配置文件夹路径; 一般为: /etc/nginx/conf.d
    conflink=`cat ${rootdir}/nginx.conf | grep "conf.d/\*.conf;" | sed -e 's/\s//g' | sed -e 's/include//' | sed -e 's/\/\*\.conf\;//'`
    # 获取 nginx 配置文件夹真实路径
    confdir=`readlink -f ${conflink}`
}

# 初始化配置目录
init_nginx_conf() {
    workdir=$1

    if [[ $workdir == '' ]]; then
        while read -p "设置工作目录[$default_workdir]: " workdir
        do
            if [[ $workdir == '' ]]; then
                workdir=$default_workdir
            fi
            dir_flag==`echo "$workdir" | gawk '/^\/(\w+\/?)+$/{print $0}'`
            if [[ ! -n "${dir_flag}" ]]; then
                echo -e "${red}工作目录格式错误！${plain}"
                continue
            fi
            break
        done
    fi

    # 创建工作目录
    mkdir -p $workdir
    mkdir -p $workdir/proxys            # 反向代理
    mkdir -p $workdir/upstream          # 负载均衡
    mkdir -p $workdir/stream/conf       # Stream
    mkdir -p $workdir/ssl               # SSL证书
    mkdir -p $workdir/logs              # 日志文件
    mkdir -p $workdir/wwwroot           # 虚拟主机
    
    if [[ $confdir == $conflink ]]; then
        # 备份原配置文件
        cp -r $confdir/.  $conflink.bak
        # 拷贝配置文件
        cp -r $conflink.bak/. $workdir/conf
        # 添加 setting.conf
        sed -i 's/sendfile/#sendfile/' $rootdir/nginx.conf
        sed -i 's/keepalive/#keepalive/' $rootdir/nginx.conf
        wget --no-check-certificate -qO $workdir/setting.conf $REPOSITORY_RAW_URL/conf/setting.conf
        if [ ! -f $workdir/setting.conf ]; then
            echo -e "" > $workdir/setting.conf
            echo -e "#隐藏版本号" >> $workdir/setting.conf
            echo -e "server_tokens on;" >> $workdir/setting.conf
            echo -e "" >> $workdir/setting.conf
            echo -e "#优化服务器域名的散列表大小" >> $workdir/setting.conf
            echo -e "server_names_hash_bucket_size 64;" >> $workdir/setting.conf
            echo -e "server_names_hash_max_size 2048;" >> $workdir/setting.conf
            echo -e "" >> $workdir/setting.conf
            echo -e "#开启高效文件传输模式" >> $workdir/setting.conf
            echo -e "sendfile on;" >> $workdir/setting.conf
            echo -e "#减少网络报文段数量" >> $workdir/setting.conf
            echo -e "#tcp_nopush on;" >> $workdir/setting.conf
            echo -e "#提高I/O性能" >> $workdir/setting.conf
            echo -e "tcp_nodelay on;" >> $workdir/setting.conf
            echo -e "" >> $workdir/setting.conf
            echo -e "#长连接超时，默认75s" >> $workdir/setting.conf
            echo -e "keepalive_timeout 120s 120s;" >> $workdir/setting.conf
            echo -e "#长连接最大请求数，默认100" >> $workdir/setting.conf
            echo -e "keepalive_requests 10000;" >> $workdir/setting.conf
        fi
        sed -i "/include \/etc\/nginx\/conf.d\/\*.conf;/i\    include $workdir/setting.conf;" $rootdir/nginx.conf
        # 向 nginx.conf 添加负载均衡配置
        _upstream=`cat $rootdir/nginx.conf | grep "/upstream/\*.conf;"`;
        if [[ $_upstream == '' ]]; then
            sed -i "/include \/etc\/nginx\/conf.d\/\*.conf;/a\    include $workdir/upstream/\*.conf;" $rootdir/nginx.conf
        fi
        # 向 nginx.conf 添加 Stream 配置
        _stream=`cat $rootdir/nginx.conf | grep "/stream/index.conf;"`;
        if [[ $_stream == '' ]]; then
            sed -i "/http {/i\include $workdir/stream/index.conf;\n" $rootdir/nginx.conf
        fi
        echo -e "stream {" > $workdir/stream/index.conf
        echo -e "    include $workdir/stream/conf/*.conf;" >> $workdir/stream/index.conf
        echo -e "    include $workdir/upstream/*.conf;" >> $workdir/stream/index.conf
        echo -e "}" >> $workdir/stream/index.conf
    else
        # 拷贝配置文件
        old_workdir=`readlink -f ${conflink} | sed -e 's/\/conf$//'`
        cp -r $old_workdir/. $workdir
        rm -rf $old_workdir
        # 替换引用
        sed -i "s/$(echo $old_workdir | sed 's/\//\\\//g')/$(echo $workdir | sed 's/\//\\\//g')/g" $rootdir/nginx.conf
        sed -i "s/$(echo $old_workdir | sed 's/\//\\\//g')/$(echo $workdir | sed 's/\//\\\//g')/g" $workdir/conf/*.conf
        sed -i "s/$(echo $old_workdir | sed 's/\//\\\//g')/$(echo $workdir | sed 's/\//\\\//g')/g" $workdir/stream/index.conf
    fi

    # 删除软链
    rm -rf $conflink
    # 创建软链
    ln -s $workdir/conf $conflink

    # 重启 nginx
    systemctl restart nginx
}

check_sys
get_nginx_env
init_nginx_conf "$@"