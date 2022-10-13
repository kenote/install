#! /bin/bash

type=$1

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

# 安装 docker
function install_docker(){
    if (command -v docker); then
        echo -e "docker 已经存在, 无需安装"
    else
        echo -e "开始安装 docker ..."
        if (is_oversea); then
            wget -qO- get.docker.com | bash
        else
            curl -sSL https://get.daocloud.io/docker | sh
        fi
        docker -v
        systemctl enable docker
        echo -e "docker 安装完成"
    fi
}

# 安装 docker-compose
function install_compose(){
    if (command -v docker-compose); then
        echo -e "docker-compose 已经存在, 无需安装"
    else
        echo -e "开始安装 docker-compose ..."
        if (is_oversea); then
            compose_url="https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)"
        else
            compose_url="https://get.daocloud.io/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)"
        fi
        curl -L ${compose_url} -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        docker-compose --version
        echo -e "docker-compose 安装完成"
    fi
}

# 优化配置
function set_daemon(){
    echo -e "优化配置; 开启容器的 IPv6 功能，以及限制日志文件大小，防止 Docker 日志塞满硬盘"
    if (is_oversea); then
        cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "ipv6": true,
    "fixed-cidr-v6": "fd00:dead:beef:c0::/80",
    "experimental":true,
    "ip6tables":true
}
EOF
    else
        cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "ipv6": true,
    "fixed-cidr-v6": "fd00:dead:beef:c0::/80",
    "experimental":true,
    "ip6tables":true,
    "registry-mirrors": [
        "https://hub-mirror.c.163.com",
        "https://registry.aliyuncs.com",
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn"
    ]
}
EOF
    fi
    echo -e "重启 docker ..."
    systemctl restart docker
}

# 删除 docker
function remove_docker(){
    if (command -v docker); then
        echo -e "删除 docker ..."
        if [[ $system == 'centos' ]]; then
            sudo yum remove docker docker-common container-selinux docker-selinux docker-engine
        else
            sudo apt-get remove docker docker-engine
        fi
        rm -fr /var/lib/docker/
    fi
    if (command -v docker-compose); then
        echo -e "删除 docker-compose ..."
        rm -fr /usr/local/bin/docker-compose
    fi
}

init_env
case $type in
    daemon )
        if (command -v docker); then
            set_daemon
        fi
    ;;
    remove )
        remove_docker
    ;;
    * )
        install_docker
        set_daemon
        install_compose
    ;;
esac