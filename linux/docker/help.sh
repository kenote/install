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

get_docker_status() {
    if (is_command docker); then
        status=`systemctl status docker | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
        docker -v
        if (is_command docker-compose); then
            docker-compose -v
        fi
    else
        echo -e "${yellow}Docker 未安装, 请先安装${plain}"
    fi
}

read_docker_env() {
    status=`systemctl status docker | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
    echo
}

install_docker() {
    if (is_command docker); then
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
        systemctl restart docker
        echo -e "${green}docker 安装完成${plain}"
    fi
}

install_compose() {
    if (is_command docker-compose); then
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
        echo -e "${green}docker-compose 安装完成${plain}"
    fi
}

set_daemon() {
    echo -e "优化配置; 开启容器的 IPv6 功能，以及限制日志文件大小，防止 Docker 日志塞满硬盘"
    mkdir -p /etc/docker
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

remove_docker() {
    if (is_command docker-compose); then
        echo -e "删除 docker-compose ..."
        rm -fr /usr/local/bin/docker-compose
        echo -e "${green}docker-compose 删除完成${plain}"
    fi
    if (is_command docker); then
        echo -e "删除 docker ..."
        if [[ $release == 'centos' ]]; then
            sudo yum remove docker docker-common container-selinux docker-selinux docker-engine
        else
            sudo apt-get remove docker docker-engine
        fi
        rm -fr /var/lib/docker/
        echo -e "${green}docker 删除完成${plain}"
    fi
}

set_workdir() {
    while read -p "设置工作目录: " _workdir
    do
        if [[ $_workdir == '' ]]; then
            echo -e "${red}工作目录不能为空！${plain}"
            continue
        fi
        dir_flag==`echo "$_workdir" | gawk '/^\/(\w+\/?)+$/{print $0}'`
        if [[ ! -n "${dir_flag}" ]]; then
            echo -e "${red}工作目录格式错误！${plain}"
            continue
        fi
        break
    done
    echo -e "${yellow}设置工作目录: $_workdir${plain}"
    echo -e "DOCKER_WORKDIR=$_workdir" >> $HOME/.docker_profile
    mkdir -p $_workdir
}

show_menu() {
    get_docker_status
    echo -e "
  ${green}Docker 管理助手${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动 Docker
  ${green} 3${plain}. 停止 Docker
  ${green} 4${plain}. 重启 Docker
 ------------------------
  ${green} 5${plain}. 安装 Docker
  ${green} 6${plain}. 卸载 Docker
  ${green} 7${plain}. 设置工作目录
 ------------------------
  ${green} 8${plain}. 部署 Portainer
  ${green} 9${plain}. 部署 FRP 内网穿透
  "
    echo && read -p "请输入选择 [0-9]: " num
    echo
    
    case "${num}" in
    0  )
        exit 0
    ;;
    1  )
        clear
        if !(is_command docker); then
            show_menu
            return 1
        fi
        read_docker_env
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        if !(is_command docker); then
            show_menu
            return 1
        fi
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Docker 正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    systemctl restart docker
                fi
            else
                systemctl start docker
            fi
        ;;
        3)
            if [[ $status == 'running' ]]; then
                systemctl stop docker
            else
                echo -e "${yellow}Docker 当前停止状态, 无需存在${plain}"
            fi
        ;;
        4)
            systemctl restart docker
        ;;
        esac
        read_docker_env
        show_menu
    ;;
    5  )
        clear
        install_docker
        install_compose
        sleep 5
        set_daemon
        read  -n1  -p "按任意键继续" key
        clear
        read_docker_env
        show_menu
    ;;
    6  )
        clear
        remove_docker
        read  -n1  -p "按任意键继续" key
        clear
        read_docker_env
        show_menu
    ;;
    7  )
        clear
        set_workdir
        read  -n1  -p "按任意键继续" key
        clear
        read_docker_env
        show_menu
    ;;
    8  )
        clear
        run_script portainer.sh
        read  -n1  -p "按任意键继续" key
        clear
        read_docker_env
        show_menu
    ;;
    9  )
        clear
        run_script frp.sh
        read  -n1  -p "按任意键继续" key
        clear
        read_docker_env
        show_menu
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-9]${plain}"
    ;;
    esac
}

run_script() {
    file=$1
    filepath=`echo "$current_dir/$file" | sed 's/docker\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        wget -O $filepath ${urlroot}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

main() {
    case $1 in
    workdir)
        set_workdir
    ;;
    * )
        clear
        show_menu
    ;;
    esac
}

clear
check_sys
main "$@"

