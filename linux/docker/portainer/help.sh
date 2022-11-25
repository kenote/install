#!/bin/bash

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

pre_check(){
    if (is_oversea); then
        REPOSITORY_RAW_ROOT="https://raw.githubusercontent.com/kenote/install"
        DOCKER_COMPOSE_REPO="https://github.com"
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
        DOCKER_COMPOSE_REPO="https://get.daocloud.io"
    fi
    REPOSITORY_RAW_URL="${REPOSITORY_RAW_ROOT}/main/linux/docker/portainer"
    curl -s ${REPOSITORY_RAW_ROOT}/main/linux/docker/help.sh | bash -s install
    ROOT_DIR=`[ -f $HOME/.docker_profile ] && cat $HOME/.docker_profile | grep "DOCKER_WORKDIR" |  sed 's/\(.*\)=\(.*\)/\2/g' || echo "/home/docker-data"`
}

read_dashboard_env() {
    CONTAINER_ID=`docker container ls -a -q -f "ancestor=portainer/portainer-ce"`
    CONTAINER_NAME="面板"
    if [[ $CONTAINER_ID == '' ]]; then
        read_agent_env
        if [[ $? == 1 ]]; then
            echo -e "${yellow}Portainer ${CONTAINER_NAME}未安装${plain}"
        fi
        return 1
    fi
    status=`docker inspect ${CONTAINER_ID} | jq -r ".[0].State.Status"`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "Portainer ${CONTAINER_NAME} -- ${green}运行中${plain}"
    else
        echo -e "Portainer ${CONTAINER_NAME} -- ${red}停止${plain}"
    fi
}

read_agent_env() {
    CONTAINER_ID=`docker container ls -a -q -f "ancestor=portainer/agent"`
    if [[ $CONTAINER_ID == '' ]]; then
        return 1
    fi
    CONTAINER_NAME="客户机"
    status=`docker inspect ${CONTAINER_ID} | jq -r ".[0].State.Status"`
    if [[ $status == 'running' ]]; then
        echo -e "Portainer ${CONTAINER_NAME} -- ${green}运行中${plain}"
    else
        echo -e "Portainer ${CONTAINER_NAME} -- ${red}停止${plain}"
    fi
}

set_dashboard_env() {
    HTTP_PORT="8000"
    HTTPS_PORT="9443"
    CONTAINER_ID=`docker ps -q -f "ancestor=portainer/portainer-ce"`
    if [[ $CONTAINER_ID != '' ]]; then
        HTTP_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"${HTTP_PORT}/tcp\"][0].HostPort"`
        HTTPS_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"${HTTPS_PORT}/tcp\"][0].HostPort"`
    fi
    while read -p "安装目录[portainer]: " _name
    do
        if [[ $_name == '' ]]; then
            _name="portainer"
        fi
        _path=`[[ $_name =~ ^\/ ]] && echo "${_name}" || echo "${ROOT_DIR}/${_name}"`
        break
    done
    while read -p "HTTP端口[${HTTP_PORT}]: " _http_port
    do
        if [[ $_http_port == '' ]]; then
            _http_port=${HTTP_PORT}
        fi
        if [[ ! $_http_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}HTTP端口格式错误！${plain}"
            continue
        fi
        if [[ $CONTAINER_ID != '' && $_http_port == ${HTTP_PORT} ]]; then
            break
        fi
        if (lsof -i:$_http_port  &> /dev/null); then
            echo -e "${red}HTTP端口-[${_http_port}]-被占用，请更换${plain}"
            continue
        fi
        break
    done
    while read -p "HTTPS端口[${HTTPS_PORT}]: " _https_port
    do
        if [[ $_https_port == '' ]]; then
            _https_port=${HTTPS_PORT}
        fi
        if [[ ! $_https_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}HTTPS端口格式错误！${plain}"
            continue
        fi
        if [[ $CONTAINER_ID != '' && $_https_port == ${HTTPS_PORT} ]]; then
            break
        fi
        if (lsof -i:$_https_port  &> /dev/null); then
            echo -e "${red}HTTPS端口-[${_https_port}]-被占用，请更换${plain}"
            continue
        fi
        break
    done

}

install_dashboard() {

    # 设置面板参数
    set_dashboard_env
    CP_BASE_PATH=$_path
    CP_HTTP_PORT=$_http_port
    CP_HTTPS_PORT=$_https_port

    # 创建工作目录
    mkdir -p ${CP_BASE_PATH}
    cd ${CP_BASE_PATH}

    # 拉取 docker-compose.yml
    echo -e "正在配置面板..."
    wget --no-check-certificate -qO docker-compose.yml $REPOSITORY_RAW_URL/compose.yml
    # 创建环境变量
    echo -e "HTTP_PORT=${CP_HTTP_PORT}\nHTTPS_PORT=${CP_HTTPS_PORT}" > .env

    # 启动面板
    echo -e "正在启动面板..."
    docker-compose up -d
}

set_agent_env() {
    TCP_PORT="9001"
    CONTAINER_ID=`docker ps -q -f "ancestor=portainer/agent"`
    if [[ $CONTAINER_ID != '' ]]; then
        TCP_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"${TCP_PORT}/tcp\"][0].HostPort"`
    fi
    while read -p "安装目录[portainer_agent]: " _name
    do
        if [[ $_name == '' ]]; then
            _name="portainer_agent"
        fi
        _path=`[[ $_name =~ ^\/ ]] && echo "${_name}" || echo "${ROOT_DIR}/${_name}"`
        break
    done
    while read -p "TCP端口[${TCP_PORT}]: " _tcp_port
    do
        if [[ $_tcp_port == '' ]]; then
            _tcp_port=${TCP_PORT}
        fi
        if [[ ! $_tcp_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}TCP端口格式错误！${plain}"
            continue
        fi
        if [[ $CONTAINER_ID != '' && $_tcp_port == ${TCP_PORT} ]]; then
            break
        fi
        if (lsof -i:$_tcp_port  &> /dev/null); then
            echo -e "${red}TCP端口-[${_tcp_port}]-被占用，请更换${plain}"
            continue
        fi
        break
    done

}

install_agent() {

    # 设置客户机参数
    set_agent_env
    AGT_BASE_PATH=$_path
    AGT_TCP_PORT=$_tcp_port

    # 创建工作目录
    mkdir -p ${AGT_BASE_PATH}
    cd ${AGT_BASE_PATH}

    # 拉取 docker-compose.yml
    echo -e "正在配置客户机..."
    wget --no-check-certificate -qO docker-compose.yml $REPOSITORY_RAW_URL/compose_agent.yml
    # 创建环境变量
    echo -e "TCP_PORT=${AGT_TCP_PORT}" > .env

    # 启动面板
    echo -e "正在启动客户机..."
    docker-compose up -d
}

update_compose() {
    echo -e "${green}----------------"
    echo -e "  升级 Portainer ${CONTAINER_NAME}"
    echo -e "----------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    CONTAINER_IMAGE=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Image"`
    if [[ ${WORK_DIR} != null ]]; then
        cd ${WORK_DIR}
        docker-compose down
        docker rmi ${CONTAINER_IMAGE}
        sleep 3
        docker-compose up -d
        echo
        echo -e "${green}Portainer ${CONTAINER_NAME}升级完成${plain}"
    else
        docker stop ${CONTAINER_ID}
        docker rm ${CONTAINER_ID}
        docker rmi ${CONTAINER_IMAGE}
        sleep 3
        # 安装新版
        if (echo "${CONTAINER_IMAGE}" | grep "portainer/agent" &> /dev/null); then 
            install_agent
            echo
            echo -e "${green}Portainer 客户机升级完成${plain}"
        else
            install_dashboard
            echo -e "${green}Portainer 面板升级完成${plain}"
        fi
    fi
}

remove_compose() {
    echo -e "${green}----------------"
    echo -e "  卸载 Portainer ${CONTAINER_NAME}"
    echo -e "----------------${plain}"
    
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}
    docker-compose down -v
    rm -rf ${WORK_DIR}

    echo -e "${green}Portainer ${CONTAINER_NAME}卸载完成${plain}"
}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/portainer\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        mkdir -p $(dirname $filepath)
        wget -O $filepath ${urlroot}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}Portainer -- Docker图形面板${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动 Portainer
  ${green} 3${plain}. 停止 Portainer
  ${green} 4${plain}. 重启 Portainer
 ------------------------
  ${green} 5${plain}. 安装 Portainer
  ${green} 6${plain}. 升级 Portainer
  ${green} 7${plain}. 卸载 Portainer
  "
        echo && read -p "请输入选择 [0-7]: " num
        echo
    fi
    
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/docker/portainer' ]]; then
            run_script ../project.sh
        else
            exit 0
        fi
    ;;
    1  )
        clear
        read_dashboard_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        read_dashboard_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Portainer ${CONTAINER_NAME}正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    echo
                    docker-compose restart
                else
                    clear
                    show_menu
                    return 0
                fi
            else
                echo
                docker-compose start
            fi
        ;;
        3)
            if [[ $status == 'running' ]]; then
                echo
                docker-compose stop
            else
                echo
                echo -e "${yellow}Portainer ${CONTAINER_NAME}当前停止状态, 无需操作${plain}"
            fi
        ;;
        4)
            echo
            docker-compose restart
        ;;
        esac
        read_dashboard_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5  )
        clear
        read_dashboard_env
        if [[ $? == 0 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        list=(服务端面板 客户机)
        select item in "${list[@]}";
        do
            case "${item}" in
            服务端面板)
                echo -e "${green}----------------"
                echo -e "  安装 Portainer 面板"
                echo -e "----------------${plain}"
                install_dashboard
                echo -e "${green}Portainer 面板安装完成${plain}"
            ;;
            客户机)
                echo -e "${green}----------------"
                echo -e "  安装 Portainer 客户机"
                echo -e "----------------${plain}"
                install_agent
                echo -e "${green}Portainer 客户机安装完成${plain}"
            ;;
            * )
                clear
                show_menu
                return 1
            ;;
            esac
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            break
        done
    ;;
    6  )
        clear
        read_dashboard_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要升级 Portainer ${CONTAINER_NAME}吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            update_compose
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    7  )
        clear
        read_dashboard_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要卸载 Portainer ${CONTAINER_NAME}吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            remove_compose
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    *  )
        clear
        echo -e "${red}请输入正确的数字 [0-7]${plain}"
        sleep 1
        show_menu
    ;;
    esac
}

main() {
    case $1 in
    * )
        clear
        show_menu
    ;;
    esac
}

pre_check
main "$@"