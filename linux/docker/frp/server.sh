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
    REPOSITORY_RAW_URL="${REPOSITORY_RAW_ROOT}/main/linux/docker/frp"
    curl -s ${REPOSITORY_RAW_ROOT}/main/linux/docker/help.sh | bash -s install
    ROOT_DIR=`[ -f $HOME/.docker_profile ] && cat $HOME/.docker_profile | grep "^DOCKER_WORKDIR" | sed -n '1p' |  sed 's/\(.*\)=\(.*\)/\2/g' || echo "/home/docker-data"`
}

read_frps_env() {
    CONTAINER_ID=`docker container ls -a -q -f "ancestor=snowdreamtech/frps"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${yellow}FRP 服务端未安装${plain}"
        return 1
    fi
    status=`docker inspect ${CONTAINER_ID} | jq -r ".[0].State.Status"`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}
    json=`echo $(inf2json frps.ini)`
    BIND_PORT=`echo $json | jq '.[] | select(.key == "common")' | jq '.["bind_port"]' | sed -E 's/\"//g'`
    BIND_TOKEN=`echo $json | jq '.[] | select(.key == "common")' | jq '.["token"]' | sed -E 's/\"//g'`
    HTTP_PORT=`echo $json | jq '.[] | select(.key == "common")' | jq '.["dashboard_port"]' | sed -E 's/\"//g'`
    HTTP_USER=`echo $json | jq '.[] | select(.key == "common")' | jq '.["dashboard_user"]' | sed -E 's/\"//g'`
    HTTP_PASS=`echo $json | jq '.[] | select(.key == "common")' | jq '.["dashboard_pwd"]' | sed -E 's/\"//g'`

    echo
    echo -e "----------------------------------------------------------------------"
    echo -e " 面板URL -- http://${LOCAL_IP}:${HTTP_PORT}"
    echo -e " 面板用户 -- ${HTTP_USER}"
    echo -e " 面板密码 -- ${HTTP_PASS}"
    echo
    echo -e " 连接主机 -- ${NETWORK_IP}"
    echo -e " 连接端口 -- ${BIND_PORT}"
    echo -e " 连接密钥 -- ${BIND_TOKEN}"
    echo -e "----------------------------------------------------------------------"
    echo
}

set_frps_env() {
    _path=$1
    HTTP_PORT="7500"
    BIND_PORT="7000"
    HTTP_USER="admin"
    HTTP_PASS="admin"
    BIND_TOKEN=""
    if [[ $_path == '' ]]; then
        while read -p "安装路径[frps]: " _name
        do
            if [[ $_path = '' ]]; then
                _name="frps"
            fi
            _path=`[[ $_name =~ ^\/ ]] && echo "${_name}" || echo "${ROOT_DIR}/${_name}"`
            break
        done
    else
        CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frps"`
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        if [ -f frps.ini ]; then
            json=`echo $(inf2json frps.ini)`
            BIND_PORT=`echo $json | jq '.[] | select(.key == "common")' | jq '.["bind_port"]' | sed -E 's/\"//g'`
            BIND_TOKEN=`echo $json | jq '.[] | select(.key == "common")' | jq '.["token"]' | sed -E 's/\"//g'`
            HTTP_PORT=`echo $json | jq '.[] | select(.key == "common")' | jq '.["dashboard_port"]' | sed -E 's/\"//g'`
            HTTP_USER=`echo $json | jq '.[] | select(.key == "common")' | jq '.["dashboard_user"]' | sed -E 's/\"//g'`
            HTTP_PASS=`echo $json | jq '.[] | select(.key == "common")' | jq '.["dashboard_pwd"]' | sed -E 's/\"//g'`
        fi
    fi
    while read -p "面板端口[${HTTP_PORT}]: " _http_port
    do
        if [[ $_http_port = '' ]]; then
            _http_port=${HTTP_PORT}
        fi
        if [[ ! $_http_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}面板端口格式错误！${plain}"
            continue
        fi
        if [[ $_http_port == ${HTTP_PORT} ]]; then
            break
        fi
        if (lsof -i:$_http_port  &> /dev/null); then
            echo -e "${red}面板端口-[${_http_port}]-被占用，请更换${plain}"
            continue
        fi
        break
    done
    while read -p "面板用户名[${HTTP_USER}]: " _http_user
    do
        if [[ $_http_user == '' ]]; then
            _http_user=${HTTP_USER}
        fi
        break
    done
    while read -p "面板密码[${HTTP_PASS}]: " _http_pass
    do
        if [[ $_http_pass == '' ]]; then
            _http_pass=${HTTP_PASS}
        fi
        break
    done
    while read -p "TCP端口[${BIND_PORT}]: " _bind_port
    do
        if [[ $_bind_port = '' ]]; then
            _bind_port=${BIND_PORT}
        fi
        if [[ ! $_bind_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}TCP端口格式错误！${plain}"
            continue
        fi
        if [[ $_bind_port == ${BIND_PORT} ]]; then
            break
        fi
        if (lsof -i:$_bind_port  &> /dev/null); then
            echo -e "${red}TCP端口-[${_bind_port}]-被占用，请更换${plain}"
            continue
        fi
        break
    done
}

set_frps() {
    CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frps"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}FRP 服务端未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------"
    echo -e "  配置 FRP 服务端"
    echo -e "----------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    set_frps_env ${WORK_DIR}
    FRPS_HTTP_PORT=$_http_port
    FRPS_HTTP_USER=$_http_user
    FRPS_HTTP_PASS=$_http_pass
    FRPS_BIND_PORT=$_bind_port

    # 创建环境变量
    echo
    echo -e "正在配置服务端参数..."

    # 写入参数
    json=`echo $(inf2json frps.ini)`
    _id=`echo $json | jq '[ .[] | .key == "common" ] | index(true)'`
    json=`echo $json | jq ".[${_id}][\"bind_port\"]=\"$FRPS_BIND_PORT\""`
    json=`echo $json | jq ".[${_id}][\"dashboard_port\"]=\"$FRPS_HTTP_PORT\""`
    json=`echo $json | jq ".[${_id}][\"dashboard_user\"]=\"$FRPS_HTTP_USER\""`
    json=`echo $json | jq ".[${_id}][\"dashboard_pwd\"]=\"$FRPS_HTTP_PASS\""`

    confirm "是否更新密钥?" "n"
    if [[ $? == 0 ]]; then
        FRPS_BIND_TOKEN=`openssl rand -base64 32 | sed -E 's/\///g'`
        json=`echo $json | jq ".[${_id}][\"token\"]=\"$FRPS_BIND_TOKEN\""`
    fi

    echo -e $(json2inf "$json") > frps.ini

    # 重启服务端
    clear
    echo -e "正在启动服务端..."
    docker-compose restart
}

install_frps() {
    echo -e "${green}----------------"
    echo -e "  安装 FRP 服务端"
    echo -e "----------------${plain}"
    
    # 设置服务端参数
    set_frps_env
    FRPS_BASE_PATH=$_path
    FRPS_HTTP_PORT=$_http_port
    FRPS_HTTP_USER=$_http_user
    FRPS_HTTP_PASS=$_http_pass
    FRPS_BIND_PORT=$_bind_port

    # 创建工作目录
    mkdir -p ${FRPS_BASE_PATH}
    cd ${FRPS_BASE_PATH}

    # 拉取 docker-compose.yml
    echo -e "正在配置服务端参数..."
    wget --no-check-certificate -qO docker-compose.yml $REPOSITORY_RAW_URL/frps.yml
    wget --no-check-certificate -qO frps.ini $REPOSITORY_RAW_URL/frps.ini

    # 写入参数
    FRPS_BIND_TOKEN=`openssl rand -base64 32 | sed -E 's/\///g'`
    json=`echo $(inf2json frps.ini)`
    _id=`echo $json | jq '[ .[] | .key == "common" ] | index(true)'`
    json=`echo $json | jq ".[${_id}][\"bind_port\"]=\"$FRPS_BIND_PORT\""`
    json=`echo $json | jq ".[${_id}][\"dashboard_port\"]=\"$FRPS_HTTP_PORT\""`
    json=`echo $json | jq ".[${_id}][\"dashboard_user\"]=\"$FRPS_HTTP_USER\""`
    json=`echo $json | jq ".[${_id}][\"dashboard_pwd\"]=\"$FRPS_HTTP_PASS\""`
    json=`echo $json | jq ".[${_id}][\"token\"]=\"$FRPS_BIND_TOKEN\""`

    # 启动服务端
    echo -e "正在启动服务端..."
    docker-compose up -d
}

remove_frps() {
    echo -e "${green}----------------"
    echo -e "  卸载 FRP 服务端"
    echo -e "----------------${plain}"
    if (docker ps -q -f "ancestor=snowdreamtech/frps"  &> /dev/null); then
        CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frps"`
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        docker-compose down -v
        rm -rf ${WORK_DIR}
        echo -e "${green}FRP 服务端卸载完成${plain}"
    fi
}

# INF 转 JSON
inf2json() {
    file=$1
    list=(`cat $file | awk -F '=' '/\[[a-zA-Z0-9\_]+\]/{print $1}' | sed -E 's/\[|\]//g'`)
    i=0
    json="[]"
    for item in "${list[@]}";
    do
        json=`echo "$json" | jq ".[$i]={\"key\":\"${item}\"}"`
        info=(`cat $file | awk -F "=" "/\[$item\]/{f=1;next} /\[*\]/{f=0} f"| sed -E 's/\s+//g'`); 
        _index=""
        json=`echo "$json" | jq ".[$i][\"__index\"]=[]"`
        j=0
        for node in "${info[@]}";
        do
            if [[ ! $node =~ ^(\#) ]]; then
                _key=`echo "$node" | sed -E 's/\s+//g' | sed 's/\(.*\)=\(.*\)/\1/g'`
                _val=`echo "$node" | sed -E 's/\s+//g' | sed 's/\(.*\)=\(.*\)/\2/g'`
                if [[ $_val == '' ]]; then
                    _key=`echo "$node" | sed -E 's/\s+//g' | sed 's/\(.*\)=\(.*=\)/\1/g'`
                    _val=`echo "$node" | sed -E 's/\s+//g' | sed 's/\(.*\)=\(.*=\)/\2/g'`
                fi
                json=`echo "$json" | jq ".[$i][\"$_key\"]=\"$_val\""`
                json=`echo "$json" | jq ".[$i][\"__index\"][$j]=\"$_key\""`
            else
                json=`echo "$json" | jq ".[$i][\"__index\"][$j]=\"$node\""`
            fi
            j=`expr $j + 1`
        done
        i=`expr $i + 1`
    done
    echo $json
}

# JSON 转 INF
json2inf() {
    json=$1
    info=""
    list=(`echo $json | jq '.[].key' | sed -E 's/\"//g'`)
    i=0
    for item in ${list[@]}
    do
        info=`echo "$info[$item]\n"`
        fields=(`echo $json | jq ".[$i][\"__index\"][]" | sed -E 's/\"//g'`)
        for field in "${fields[@]}";
        do
            if [[ $field =~ ^(\#) ]]; then
                info=`echo "$info\n$field\n"`
            else
                _val=`echo $json | jq ".[$i][\"$field\"]" | sed -E 's/\"//g'`
                info=`echo "$info$field = $_val\n"`
            fi
        done
        info=`echo "$info\n"`
        i=`expr $i + 1`
    done
    echo $info
}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/frp\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        mkdir -p $(dirname $filepath)
        wget -O $filepath ${REPOSITORY_RAW_ROOT}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}FRP内网穿透 -- 服务端${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动服务端
  ${green} 3${plain}. 停止服务端
  ${green} 4${plain}. 重启服务端
 ------------------------
  ${green} 5${plain}. 安装服务端
  ${green} 6${plain}. 卸载服务端
  ${green} 7${plain}. 配置参数
  "
        echo && read -p "请输入选择 [0-7]: " num
        echo
    fi
    
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/docker/frp' ]]; then
            run_script ../project.sh
        else
            exit 0
        fi
    ;;
    1  )
        clear
        read_frps_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        read_frps_env
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
                confirm "FRP 服务端正在运行, 是否要重启?" "n"
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
                echo -e "${yellow}FRP 服务端当前停止状态, 无需操作${plain}"
            fi
        ;;
        4)
            echo
            docker-compose restart
        ;;
        esac
        read_frps_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5  )
        clear
        read_frps_env
        if [[ $? == 0 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要安装 FRP 服务端吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            install_frps
            echo -e "${green}FRP 服务端安装完成${plain}"
            echo
            read_frps_env
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    6  )
        clear
        read_frps_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要卸载 FRP 服务端吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            remove_frps
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    7  )
        clear
        read_frps_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要重新配置 FRP 服务端吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            set_frps
            read_frps_env
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