#! /bin/bash

current_dir=$(cd $(dirname $0);pwd)
workdir=`cat $HOME/.docker_profile | grep "DOCKER_WORKDIR" |  sed 's/\(.*\)=\(.*\)/\2/g'`
local_ip=`hostname -I | awk -F ' ' '{print $1}'`
network_ip=`wget -qO- ip.p3terx.com | sed -n '1p'`

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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

deploy() {
    project_name="portainer"
    if [[ $workdir == '' ]]; then
        run_script help.sh workdir
    fi
    echo
    echo -e "${green}----------------"
    echo -e "  部署 Portainer - Docker 图形管理"
    echo -e "----------------${plain}"
    echo
    confirm "确定要部署 Portainer 吗?" "n"
    if [[ $? != 0 ]]; then
        return 1
    fi
    if [[ -d $workdir/${project_name} ]]; then
        echo -e "${yellow}发现-[${project_name}]-目录${plain}"
        confirm "是否要覆盖安装?" "n"
        if [[ $? == 0 ]]; then
            cd $workdir/${project_name}
            if [[ -f $workdir/${project_name}/docker-compose.yml ]]; then
                docker-compose down -v
            fi
            cd $workdir
            rm -rf $workdir/${project_name}
        else
            return 1
        fi
    fi
    # 创建目录
    mkdir -p $workdir/${project_name}
    cd $workdir/${project_name}
    # 拉取 docker-compose.yml
    wget -O $workdir/${project_name}/docker-compose.yml ${urlroot}/main/linux/docker/portainer/portainer.yaml
    # 设置变量
    while read -p "HTTP端口[默认: 8000]: " http_port
    do
        if [[ $http_port == '' ]]; then
            http_port=8000
        fi
        if [[ ! $http_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}HTTP端口格式错误！${plain}"
            continue
        fi
        break
    done
    while read -p "HTTPS端口[默认: 9443]: " https_port
    do
        if [[ $https_port == '' ]]; then
            https_port=9443
        fi
        if [[ ! $https_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}HTTPS端口格式错误！${plain}"
            continue
        fi
        break
    done
    echo -e "
HTTP_PORT=$http_port
HTTPS_PORT=$https_port
    " > $workdir/${project_name}/.env
    # 启动容器
    docker-compose up -d
    echo -e "${green}Portainer 部署完毕${plain}"
    echo -e "内部 -- https://${local_ip}:${https_port}"
    echo -e "外部 -- https://${network_ip}:${https_port}"
}

deploy_agent() {
    project_name="portainer_agent"
    if [[ $workdir == '' ]]; then
        run_script help.sh workdir
    fi
    echo
    echo -e "${green}----------------"
    echo -e "  部署 Portainer Agent"
    echo -e "----------------${plain}"
    echo
    confirm "确定要部署 Portainer Agent 吗?" "n"
    if [[ $? != 0 ]]; then
        return 1
    fi
    if [[ -d $workdir/${project_name} ]]; then
        echo -e "${yellow}发现-[${project_name}]-目录${plain}"
        confirm "是否要覆盖安装?" "n"
        if [[ $? == 0 ]]; then
            cd $workdir/${project_name}
            if [[ -f $workdir/${project_name}/docker-compose.yml ]]; then
                docker-compose down -v
            fi
            cd $workdir
            rm -rf $workdir/${project_name}
        else
            return 1
        fi
    fi
    # 创建目录
    mkdir -p $workdir/${project_name}
    cd $workdir/${project_name}
    # 拉取 docker-compose.yml
    wget -O $workdir/${project_name}/docker-compose.yml ${urlroot}/main/linux/docker/portainer/portainer_agent.yaml
    # 设置变量
    while read -p "HTTP端口[默认: 8000]: " http_port
    do
        if [[ $http_port == '' ]]; then
            http_port=9001
        fi
        if [[ ! $http_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}HTTP端口格式错误！${plain}"
            continue
        fi
        break
    done
    echo -e "
HTTP_PORT=$http_port
    " > $workdir/${project_name}/.env
    # 启动容器
    docker-compose up -d
    echo -e "${green}Portainer Anget 部署完毕${plain}"
    echo -e "内部 -- ${local_ip}:${https_port}"
    echo -e "外部 -- ${network_ip}:${https_port}"
}

update() {
    project_name="portainer"
    if [[ $workdir == '' ]]; then
        run_script help.sh workdir
    fi
    echo
    echo -e "${green}----------------"
    echo -e "  升级 Portainer 版本"
    echo -e "----------------${plain}"
    echo
    confirm "确定要升级 Portainer 吗?" "n"
    if [[ $? != 0 ]]; then
        return 1
    fi
    if [[ -f $workdir/${project_name}/docker-compose.yml ]]; then
        cd $workdir/${project_name}
        docker-compose down -v
        docker rmi portainer/portainer-ce
        sleep 3
        docker-compose up -d
        echo -e "${green}Portainer 更新完毕${plain}"
    else
        docker stop portainer
        docker rm portainer
        docker rmi portainer/portainer-ce
        sleep 3
        deploy
    fi
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

show_menu() {
    echo -e "
  ${green}Portainer - Docker 图形管理${plain}

  ${green} 0${plain}. 返回
 ------------------------
  ${green} 1${plain}. 部署 Portainer
  ${green} 2${plain}. 部署 Portainer Agent
  ${green} 3${plain}. 升级 Portainer
  "
    echo && read -p "请输入选择 [0-2]: " num
    echo
    case "${num}" in
    0  )
        run_script help.sh
    ;;
    1  )
        clear
        deploy
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    2  )
        clear
        deploy_agent
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    3  )
        clear
        update
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-2]${plain}"
    ;;
    esac
}

check_sys
show_menu