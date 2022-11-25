#! /bin/bash

CURRENT_DIR=$(cd $(dirname $0);pwd)

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
        REPOSITORY_RAW_ROOT="https://raw.githubusercontent.com/kenote/install"
        DOCKER_COMPOSE_REPO="https://github.com"
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
        DOCKER_COMPOSE_REPO="https://get.daocloud.io"
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
    if (docker &> /dev/null); then
        status=`systemctl status docker | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
        docker -v
        if (is_command docker-compose); then
            docker-compose -v
        fi
        if [[ $status != 'running' ]]; then
            systemctl stop docker
        fi
    else
        return 1
    fi
}

read_docker_env() {
    get_docker_status
    if [[ $? == 1 ]]; then
        echo -e "${yellow}Docker 环境未安装${plain}"
        return 1
    fi
    status=`systemctl status docker | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
}

install_base() {
    if !(is_command jq); then
        yum install -y epel-release 2> /dev/null
        yum install -y jq 2> /dev/null || apt install -y jq
    fi
    if !(is_command lsof); then
        yum install -y lsof 2> /dev/null || apt install -y lsof
    fi
}

install_docker() {
    install_base
    if !(is_command docker); then
        echo -e "开始安装 Docker ..."
        if (is_oversea); then
            wget -qO- get.docker.com | bash
        else
            curl -sSL https://get.daocloud.io/docker | sh
        fi
        docker -v
        systemctl enable docker
        set_docker_env
        echo -e "${green}Docker 安装完成${plain}"
    fi
    # 安装 Docker Compose
    if !(is_command docker-compose); then
        echo -e "正在安装 Docker Compose ..."
        curl -L ${DOCKER_COMPOSE_REPO}/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        docker-compose --version
        echo -e "${green}Docker Compose 安装完成${plain}"
        confirm "是否要设置工作目录吗?" "n"
        if [[ $? == 0 ]]; then
            set_workdir
        fi
    fi
}

set_docker_env() {
    install_base
    sleep 3
    echo "{}" | jq > /etc/docker/daemon.json
    str=`cat /etc/docker/daemon.json | jq`
    # 日志
    str=`echo "$str" | jq '.["log-driver"]="json-file"' | jq`
    str=`echo "$str" | jq '.["log-opts"]={}' | jq`; \
    str=`echo "$str" | jq '.["log-opts"]["max-size"]="20m"' | jq`
    str=`echo "$str" | jq '.["log-opts"]["max-file"]="3"' | jq`

    # ipv6
    str=`echo "$str" | jq '.ipv6=true' | jq`; \
    str=`echo "$str" | jq '.["fixed-cidr-v6"]="fd00:dead:beef:c0::/80"' | jq`
    str=`echo "$str" | jq '.experimental=true' | jq`
    str=`echo "$str" | jq '.ip6tables=false' | jq`

    # firewalld
    str=`echo "$str" | jq '.iptables=false' | jq`

    # 国内镜像源
    if !(is_oversea); then
        str=`echo "$str" | jq '.["registry-mirrors"]=[]' | jq`
        str=`echo "$str" | jq '.["registry-mirrors"][0]="https://hub-mirror.c.163.com"' | jq`
        str=`echo "$str" | jq '.["registry-mirrors"][1]="https://registry.aliyuncs.com"' | jq`
        str=`echo "$str" | jq '.["registry-mirrors"][2]="https://registry.docker-cn.com"' | jq`
        str=`echo "$str" | jq '.["registry-mirrors"][3]="https://docker.mirrors.ustc.edu.cn"' | jq`
    fi

    # 写入文件
    echo "$str" > /etc/docker/daemon.json
    sleep 3

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
            sudo yum remove docker-ce docker-ce-cli containerd.io docker-scan-plugin docker-compose-plugin docker-ce-rootless-extras
        else
            sudo apt-get remove docker-ce docker-ce-cli containerd.io docker-scan-plugin docker-compose-plugin docker-ce-rootless-extras
        fi
        rm -rf /var/lib/docker/
        echo -e "${green}docker 删除完成${plain}"
    fi
}

set_workdir() {
    ROOT_DIR=`[ -f $HOME/.docker_profile ] && cat $HOME/.docker_profile | grep "^DOCKER_WORKDIR" | sed -n '1p' |  sed 's/\(.*\)=\(.*\)/\2/g' || echo "/home/docker-data"`
    while read -p "设置工作目录[${ROOT_DIR}]: " _workdir
    do
        if [[ $_workdir == '' ]]; then
            _workdir=${ROOT_DIR}
        fi
        dir_flag==`echo "$_workdir" | gawk '/^\/(\w+\/?)+$/{print $0}'`
        if [[ ! -n "${dir_flag}" ]]; then
            echo -e "${red}工作目录格式错误！${plain}"
            continue
        fi
        break
    done
    echo -e "${yellow}设置工作目录: $_workdir${plain}"
    if [ -f $HOME/.docker_profile ]; then
        sed -i "s/$(cat $HOME/.docker_profile | grep -E "^DOCKER_WORKDIR=")/DOCKER_WORKDIR=$_workdir/" $HOME/.docker_profile
    else
        echo -e "DOCKER_WORKDIR=$_workdir" > $HOME/.docker_profile
    if
    mkdir -p $_workdir
}

show_menu() {
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
  ${green} 8${plain}. 重置Docker环境
 ------------------------
  ${green} 9${plain}. 常用 Docker 项目
  "
    echo && read -p "请输入选择 [0-9]: " num
    echo
    
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/docker' ]]; then
            run_script ../help.sh
        else
            exit 0
        fi
    ;;
    1  )
        clear
        read_docker_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        read_docker_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Docker 正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    echo
                    systemctl restart docker
                else
                    clear
                    show_menu
                    return 0
                fi
            else
                echo
                systemctl start docker
            fi
        ;;
        3)
            echo -e "停止中..."
            if [[ $status == 'running' ]]; then
                echo
                systemctl stop docker
            else
                echo
                echo -e "${yellow}Docker 当前停止状态, 无需存在${plain}"
                echo
                read  -n1  -p "按任意键继续" key
                clear
                show_menu
                return 0
            fi
        ;;
        4)
            echo
            systemctl restart docker
        ;;
        esac
        clear
        read_docker_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5  )
        clear
        read_docker_env
        if [[ $? == 0 ]]; then
            confirm "Docker 环境已经安装, 是否要重新安装?" "n"
            if [[ $? == 0 ]]; then
                remove_docker
            else
                clear
                show_menu
                return 0
            fi
        fi
        install_docker
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    6  )
        clear
        read_docker_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        remove_docker
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    7  )
        clear
        read_docker_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        set_workdir
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    8  )
        clear
        read_docker_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要重置Docker环境吗?" "n"
        if [[ $? == 0 ]]; then
            set_docker_env
            echo -e "${green}Docker环境已经重置！${plain}"
            echo
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    9  )
        run_script project.sh
    ;;
    *  )
        clear
        echo -e "${red}请输入正确的数字 [0-9]${plain}"
        sleep 1
        show_menu
    ;;
    esac
}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/docker\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        mkdir -p $(dirname $filepath)
        wget -O $filepath ${REPOSITORY_RAW_ROOT}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

main() {
    case $1 in
    install)
        install_docker
    ;;
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

