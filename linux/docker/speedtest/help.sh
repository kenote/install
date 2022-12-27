#!/bin/bash

CURRENT_DIR=$(cd $(dirname $0);pwd)
LOCAL_IP=`hostname -I | awk -F ' ' '{print $1}'`
NETWORK_IP=`wget -qO- ip.p3terx.com | sed -n '1p'`

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
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
    fi
    REPOSITORY_RAW_URL="${REPOSITORY_RAW_ROOT}/main/linux/docker/speedtest"
    curl -s ${REPOSITORY_RAW_ROOT}/main/linux/docker/help.sh | bash -s install
    ROOT_DIR=`[ -f $HOME/.docker_profile ] && cat $HOME/.docker_profile | grep "^DOCKER_WORKDIR" | sed -n '1p' |  sed 's/\(.*\)=\(.*\)/\2/g' || echo "/home/docker-data"`
}

read_speedtest_env() {
    CONTAINER_ID=`docker container ls -a -q -f "ancestor=adolfintel/speedtest"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${yellow}SpeedTest 未安装${plain}"
        return 1
    fi
    status=`docker inspect ${CONTAINER_ID} | jq -r ".[0].State.Status"`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi

    # TITLE=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Env[]" | grep "TITLE" | sed 's/\(.*\)=\(.*\)/\2/g'`
    # HTTP_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"80/tcp\"][0].HostPort"`
}

set_speedtest_env() {
    _path=$1
    TITLE="SpeedTest"
    PORT="8086"
    if [[ $_path == '' ]]; then
        while read -p "安装路径[speedtest]: " _name
        do
            if [[ $_path = '' ]]; then
                _name="speedtest"
            fi
            _path=`[[ $_name =~ ^\/ ]] && echo "${_name}" || echo "${ROOT_DIR}/${_name}"`
            break
        done
    else
        CONTAINER_ID=`docker ps -q -f "ancestor=adolfintel/speedtest"`
        TITLE=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Env[]" | grep "TITLE" | sed 's/\(.*\)=\(.*\)/\2/g'`
        PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"80/tcp\"][0].HostPort"`
    fi
    while read -p "设置标题[$TITLE]: " _title
    do
        if [[ $_title == '' ]]; then
            _title=$TITLE
        fi
        break
    done
    while read -p "设置端口[$PORT]: " _port
    do
        if [[ $_port == '' ]]; then
            _port=$PORT
        fi
        if [[ ! $_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}端口格式错误！${plain}"
            continue
        fi
        if [[ $_port == ${PORT} ]]; then
            break
        fi
        if (lsof -i:$_port  &> /dev/null); then
            echo -e "${red}端口-[${_port}]-被占用，请更换${plain}"
            continue
        fi
        break
    done

}

install_speedtest() {
    echo -e "${green}----------------"
    echo -e "  安装 SpeedTest"
    echo -e "----------------${plain}"
    
    # 设置面板参数
    set_speedtest_env
    WORK_DIR=$_path
    TITLE=$_title
    PORT=$_port

    # 创建工作目录
    mkdir -p ${WORK_DIR}
    cd ${WORK_DIR}

    # 拉取 docker-compose.yml
    echo -e "正在配置 SpeedTest 参数..."
    wget --no-check-certificate -qO docker-compose.yml $REPOSITORY_RAW_URL/compose.yml
    # 创建环境变量
    echo -e "TITLE=${TITLE}" > .env
    echo -e "PORT=${PORT}" >> .env

    # 启动 SpeedTest
    echo -e "正在启动 SpeedTest..."
    docker-compose up -d
}

set_speedtest() {
    CONTAINER_ID=`docker ps -q -f "ancestor=adolfintel/speedtest"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}SpeedTest 未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------"
    echo -e "  配置 SpeedTest"
    echo -e "----------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    set_speedtest_env ${WORK_DIR}
    TITLE=$_title
    PORT=$_port

    # 创建环境变量
    echo
    echo -e "正在配置 SpeedTest 参数..."
    echo -e "TITLE=${TITLE}" > .env
    echo -e "PORT=${PORT}" >> .env

    # 重启 SpeedTest
    clear
    echo -e "正在重置 SpeedTest..."
    docker-compose down
    docker-compose up -d
}

remove_speedtest() {
    echo -e "${green}----------------"
    echo -e "  卸载 SpeedTest"
    echo -e "----------------${plain}"
    if (docker ps -q -f "ancestor=adolfintel/speedtest"  &> /dev/null); then
        CONTAINER_ID=`docker ps -q -f "ancestor=adolfintel/speedtest"`
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        docker-compose down -v
        rm -rf ${WORK_DIR}
        echo -e "${green}SpeedTest 卸载完成${plain}"
    fi
}


show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}SpeedTest 服务器测速${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动 SpeedTest
  ${green} 3${plain}. 停止 SpeedTest
  ${green} 4${plain}. 重启 SpeedTest
 ------------------------
  ${green} 5${plain}. 安装 SpeedTest
  ${green} 6${plain}. 卸载 SpeedTest
  ${green} 7${plain}. 配置参数
  "
        echo && read -p "请输入选择 [0-7]: " num
        echo
    fi
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/docker/speedtest' ]]; then
            run_script ../project.sh
        else
            exit 0
        fi
    ;;
    1  )
        clear
        read_speedtest_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        read_speedtest_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        clear
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "SpeedTest 服务正在运行, 是否要重启?" "n"
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
                echo -e "${yellow}SpeedTest 服务当前停止状态, 无需操作${plain}"
            fi
        ;;
        4)
            echo
            docker-compose restart
        ;;
        esac
        read_speedtest_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5  )
        clear
        read_speedtest_env
        if [[ $? == 0 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要安装 SpeedTest 吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            install_speedtest
            echo -e "${green}SpeedTest 安装完成${plain}"
            echo
            read_speedtest_env
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    6  )
        clear
        read_speedtest_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要卸载 SpeedTest 吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            remove_speedtest
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    7  )
        clear
        read_speedtest_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要重新配置 SpeedTest 吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            set_speedtest
            read_speedtest_env
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

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/speedtest\/..\///'`
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
    * )
        clear
        show_menu
    ;;
    esac
}

pre_check
main "$@"