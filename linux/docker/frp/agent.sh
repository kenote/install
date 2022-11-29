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

read_frpc_env() {
    CONTAINER_ID=`docker container ls -a -q -f "ancestor=snowdreamtech/frpc"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${yellow}FRP 客户端未安装${plain}"
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
    json=`echo $(inf2json frpc.ini)`
    BIND_HOST=`echo $json | jq '.[] | select(.key == "common")' | jq '.["server_addr"]' | sed -E 's/\"//g'`
    BIND_PORT=`echo $json | jq '.[] | select(.key == "common")' | jq '.["server_port"]' | sed -E 's/\"//g'`
    BIND_TOKEN=`echo $json | jq '.[] | select(.key == "common")' | jq '.["token"]' | sed -E 's/\"//g'`

    echo
    echo -e "----------------------------------------------------------------------"
    echo -e " 连接主机 -- ${BIND_HOST}"
    echo -e " 连接端口 -- ${BIND_PORT}"
    echo -e " 连接密钥 -- ${BIND_TOKEN}"
    echo -e "----------------------------------------------------------------------"
    echo
}

set_frpc_env() {
    _path=$1
    BIND_HOST="127.0.0.1"
    BIND_PORT="7000"
    BIND_TOKEN=""
    if [[ $_path == '' ]]; then
        while read -p "安装路径[frpc]: " _name
        do
            if [[ $_path = '' ]]; then
                _name="frpc"
            fi
            _path=`[[ $_name =~ ^\/ ]] && echo "${_name}" || echo "${ROOT_DIR}/${_name}"`
            break
        done
    else
        CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frpc"`
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        if [ -f frpc.ini ]; then
            json=`echo $(inf2json frpc.ini)`
            BIND_HOST=`echo "$json" | jq '.[] | select(.key == "common")' | jq '.["server_addr"]' | sed -E 's/\"//g'`
            BIND_PORT=`echo "$json" | jq '.[] | select(.key == "common")' | jq '.["server_port"]' | sed -E 's/\"//g'`
            BIND_TOKEN=`echo "$json" | jq '.[] | select(.key == "common")' | jq '.["token"]' | sed -E 's/\"//g'`
        fi
    fi
    while read -p "服务器主机[${BIND_HOST}]: " _bind_host
    do
        if [[ $_bind_host == '' ]]; then
            _bind_host=${BIND_HOST}
        fi
        break
    done
    while read -p "服务器端口[${BIND_PORT}]: " _bind_port
    do
        if [[ $_bind_port = '' ]]; then
            _bind_port=${BIND_PORT}
        fi
        if [[ ! $_bind_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}服务器格式错误！${plain}"
            continue
        fi
        break
    done
    while read -p "连接用的私钥: " _bind_token
    do
        if [[ $_bind_token == '' ]]; then
            if [[ $BIND_TOKEN != '' ]]; then
                _bind_token=${BIND_TOKEN}
            else
                echo -e "${red}连接用的私钥不能为空！${plain}"
                continue
            fi
        fi
        break
    done
    _bind_token=`echo "${_bind_token}" | sed -E 's/\///g'`
}

set_frpc() {
    CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frpc"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}FRP 客户端未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------"
    echo -e "  配置 FRP 客户端"
    echo -e "----------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}
    
    # 设置客户端参数
    set_frpc_env ${WORK_DIR}
    FRPC_BIND_HOST=$_bind_host
    FRPC_BIND_PORT=$_bind_port
    FRPC_BIND_TOKEN=$_bind_token

    # 创建环境变量
    echo
    echo -e "正在配置客户端参数..."

    # 写入参数

    json=`echo $(inf2json frpc.ini)`
    _id=`echo $json | jq '[ .[] | .key == "common" ] | index(true)'`
    json=`echo $json | jq ".[${_id}][\"server_addr\"]=\"$FRPC_BIND_HOST\""`
    json=`echo $json | jq ".[${_id}][\"server_port\"]=\"$FRPC_BIND_PORT\""`
    json=`echo $json | jq ".[${_id}][\"token\"]=\"$FRPC_BIND_TOKEN\""`

    echo -e $(json2inf "$json") > frpc.ini

    # 重启客户端
    clear
    echo -e "正在启动客户端..."
    docker-compose restart
}

install_frpc() {
    echo -e "${green}----------------"
    echo -e "  安装 FRP 客户端"
    echo -e "----------------${plain}"
    
    # 设置客户端参数
    set_frpc_env
    FRPC_BASE_PATH=$_path
    FRPC_BIND_HOST=$_bind_host
    FRPC_BIND_PORT=$_bind_port
    FRPC_BIND_TOKEN=$_bind_token

    # 创建工作目录
    mkdir -p ${FRPC_BASE_PATH}
    cd ${FRPC_BASE_PATH}

    # 拉取 docker-compose.yml
    echo -e "正在配置客户端参数..."
    wget --no-check-certificate -qO docker-compose.yml $REPOSITORY_RAW_URL/frpc.yml

    # 写入参数
    json=`echo "[]"`
    json=`echo $json | jq ".[0]={\"key\":\"common\"}"`
    json=`echo $json | jq ".[0][\"server_addr\"]=\"$FRPC_BIND_HOST\""`
    json=`echo $json | jq ".[0][\"server_port\"]=\"$FRPC_BIND_PORT\""`
    json=`echo $json | jq ".[0][\"token\"]=\"$FRPC_BIND_TOKEN\""`

    echo -e $(json2inf "$json") > frpc.ini

    # 启动服务端
    echo -e "正在启动客户端..."
    docker-compose up -d
}

remove_frpc() {
    echo -e "${green}----------------"
    echo -e "  卸载 FRP 客户端"
    echo -e "----------------${plain}"
    if (docker ps -q -f "ancestor=snowdreamtech/frpc"  &> /dev/null); then
        CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frpc"`
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        docker-compose down -v
        rm -rf ${WORK_DIR}
        echo -e "${green}FRP 客户端卸载完成${plain}"
    fi
}

add_proxy() {
    CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frpc"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}FRP 客户端未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------"
    echo -e "  添加转发服务"
    echo -e "----------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    while read -p "节点名称: " _name
    do
        if [[ $_name = '' ]]; then
            echo -e "${red}节点名称不能为空！${plain}"
            continue
        fi
        is_name=`echo $(inf2json ${WORK_DIR}/frpc.ini) | jq ".[] | select(.key == \"$_name\")"`
        if [[ $is_name != '' ]]; then
            echo -e "${red}节点名称已存在，请另起一个${plain}"
            continue
        fi
        break
    done

    list=(tcp udp)
    echo -e "协议类型: "
    select item in ${list[@]};
    do
        _type=$item
        if [[ $_type == '' ]]; then
            _type="tcp"
        fi
        break
    done

    while read -p "代理本地IP: " _local_ip
    do
        if [[ $_local_ip = '' ]]; then
            echo -e "${red}代理本地端口不能为空！${plain}"
            continue
        fi
        break
    done

    while read -p "代理本地端口: " _local_port
    do
        if [[ $_local_port = '' ]]; then
            echo -e "${red}代理本地端口不能为空！${plain}"
            continue
        fi
        if [[ ! $_local_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}代理本地端口格式错误！${plain}"
            continue
        fi
        break
    done

    while read -p "映射远程端口: " _remote_port
    do
        if [[ $_remote_port = '' ]]; then
            echo -e "${red}映射远程端口不能为空！${plain}"
        fi
        if [[ ! $_remote_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}映射远程端口格式错误！${plain}"
            continue
        fi
        break
    done
    confirm "是否加密传输?" "n"
    if [[ $? == 0 ]]; then
        _use_encryption="true"
    fi
    confirm "数据是否压缩?" "n"
    if [[ $? == 0 ]]; then
        _use_compression="true"
    fi

    json=`echo $(inf2json frpc.ini)`
    _id=`echo $json | jq '. | length'`
    json=`echo $json | jq ".[$_id]={\"key\":\"${_name}\"}"`
    json=`echo $json | jq ".[$_id][\"__index\"]=[\"type\", \"local_ip\", \"local_port\", \"remote_port\"]"`
    json=`echo $json | jq ".[$_id][\"type\"]=\"$_type\""`
    json=`echo $json | jq ".[$_id][\"local_ip\"]=\"$_local_ip\""`
    json=`echo $json | jq ".[$_id][\"local_port\"]=\"$_local_port\""`
    json=`echo $json | jq ".[$_id][\"remote_port\"]=\"$_remote_port\""`
    if [[ $_use_encryption == 'true' ]]; then
        json=`echo $json | jq ".[${_id}][\"use_encryption\"]=\"$_use_encryption\""`
        len=`echo $json | jq ".[$_id][\"__index\"] | length"`
        json=`echo $json | jq ".[$_id][\"__index\"][$len]=\"use_encryption\""`
    fi
    if [[ $_use_compression == 'true' ]]; then
        json=`echo $json | jq ".[${_id}][\"use_compression\"]=\"$_use_compression\""`
        len=`echo $json | jq ".[$_id][\"__index\"] | length"`
        json=`echo $json | jq ".[$_id][\"__index\"][$len]=\"use_compression\""`
    fi

    echo -e $(json2inf "$json") > frpc.ini

    docker-compose restart
    echo
}

list_proxy() {
    CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frpc"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}FRP 客户端未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------------------------------------"
    echo -e "  转发服务列表"
    echo -e "----------------------------------------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    json=`echo $(inf2json frpc.ini)`

    list=(`echo $json | jq '.[].key' | sed -E 's/\"//g' | sed 's/common//'`)
    if [[ ${#list[@]} == 0 ]]; then
        echo -e "${yellow}还没有创建任何代理${plain}"
        return 1
    fi

    echo -e "ID\t名称\t\t协议\t本地IP\t\t本地端口\t映射端口\t加密传输\t数据压缩"
    _id=1
    for item in ${list[@]};
    do
        _type=`echo $json | jq ".[$_id][\"type\"]" | sed -E 's/\"//g'`
        _local_ip=`echo $json | jq ".[$_id][\"local_ip\"]" | sed -E 's/\"//g'`
        _local_port=`echo $json | jq ".[$_id][\"local_port\"]" | sed -E 's/\"//g'`
        _remote_port=`echo $json | jq ".[$_id][\"remote_port\"]" | sed -E 's/\"//g'`
        _use_encryption=`echo $json | jq ".[$_id][\"use_encryption\"]" | sed -E 's/\"//g' | sed 's/null/false/'`
        _use_compression=`echo $json | jq ".[$_id][\"use_compression\"]" | sed -E 's/\"//g' | sed 's/null/false/'`
        _space="\t"
        if [[ ${#item} -lt 8 ]]; then
            _space="\t\t"
        fi
        echo -e "${_id}\t${item}${_space}${_type}\t${_local_ip}\t${_local_port}\t\t${_remote_port}\t\t${_use_encryption}\t\t${_use_compression}"
        _id=`expr $_id + 1`
    done

    proxy_name=""
    echo
    while read -p "请输入ID可操作节点或输入 x 返回: " num
    do
        if [[ $num == 'x' ]]; then
            return 1
        elif [[ $num =~ ^[0-9]+$ && $num -lt $_id && $num -ge 1 ]]; then
            proxy_name=`echo $(inf2json frpc.ini) | jq ".[$num][\"key\"]" | sed -E 's/\"//g'`
        else
            echo -e "${red}输入正确的ID或 x 返回${plain}"
            continue
        fi
        break
    done

    clear
    echo -e "${green}--------------------------------"
    echo -e "  选择操作节点 -[${proxy_name}]-"
    echo -e "--------------------------------${plain}"
    echo
    list=(编辑 删除 返回)
    _opt=""
    select item in ${list[@]};
    do
        _opt=$item
        echo -e "$item"
        case "${item}" in
        编辑)
            edit_proxy ${proxy_name}
        ;;
        删除)
            confirm "确定要删除节点-[${proxy_name}]-?" "n"
            if [[ $? == 0 ]]; then
                remove_proxy ${proxy_name}
            else
                show_menu 8
            fi
        ;;
        返回)
            show_menu 8
        ;;
        esac
        break
    done
}

edit_proxy() {
    _name=$1
    CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frpc"`
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}
    json=`echo $(inf2json frpc.ini) | jq ".[] | select(.key == \"$_name\")"`

    clear
    echo -e "${green}--------------------------------"
    echo -e "  编辑节点 -[$(echo "$json" | jq '.key' | sed -E 's/\"//g')]-"
    echo -e "--------------------------------${plain}"

    # json=`echo -e $(inf2json frpc.ini) | jq ".[] | select(.key == \"$_name\")"`
    old_type=`echo "$json" | jq '.type' | sed -E 's/\"//g'`
    old_local_ip=`echo "$json" | jq '.["local_ip"]' | sed -E 's/\"//g'`
    old_local_port=`echo "$json" | jq '.["local_port"]' | sed -E 's/\"//g'`
    old_remote_port=`echo "$json" | jq '.["remote_port"]' | sed -E 's/\"//g'`

    list=(tcp udp)
    echo -e "协议类型[${old_type}]: "
    select item in ${list[@]};
    do
        _type=$item
        if [[ $_type == '' ]]; then
            _type=${old_type}
        fi
        break
    done

    while read -p "代理本地IP[${old_local_ip}]: " _local_ip
    do
        if [[ $_local_ip = '' ]]; then
            _local_ip=${old_local_ip}
        fi
        break
    done

    while read -p "代理本地端口[${old_local_port}]: " _local_port
    do
        if [[ $_local_port = '' ]]; then
            _local_port=${old_local_port}
        fi
        if [[ ! $_local_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}代理本地端口格式错误！${plain}"
            continue
        fi
        break
    done

    while read -p "映射远程端口[${old_remote_port}]: " _remote_port
    do
        if [[ $_remote_port = '' ]]; then
            _remote_port=${old_remote_port}
        fi
        if [[ ! $_remote_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}映射远程端口格式错误！${plain}"
            continue
        fi
        break
    done
    confirm "是否加密传输?" "n"
    if [[ $? == 0 ]]; then
        _use_encryption="true"
    fi
    confirm "数据是否压缩?" "n"
    if [[ $? == 0 ]]; then
        _use_compression="true"
    fi
    json=`echo $(inf2json frpc.ini)`
    _id=`echo $json | jq "[ .[] | .key == \"$_name\" ] | index(true)"`
    json=`echo $json | jq ".[$_id][\"__index\"]=[\"type\", \"local_ip\", \"local_port\", \"remote_port\"]"`
    json=`echo $json | jq ".[$_id][\"type\"]=\"$_type\""`
    json=`echo $json | jq ".[$_id][\"local_ip\"]=\"$_local_ip\""`
    json=`echo $json | jq ".[$_id][\"local_port\"]=\"$_local_port\""`
    json=`echo $json | jq ".[$_id][\"remote_port\"]=\"$_remote_port\""`
    if [[ $_use_encryption == 'true' ]]; then
        json=`echo $json | jq ".[${_id}][\"use_encryption\"]=\"$_use_encryption\""`
        len=`echo $json | jq ".[$_id][\"__index\"] | length"`
        json=`echo $json | jq ".[$_id][\"__index\"][$len]=\"use_encryption\""`
    fi
    if [[ $_use_compression == 'true' ]]; then
        json=`echo $json | jq ".[${_id}][\"use_compression\"]=\"$_use_compression\""`
        len=`echo $json | jq ".[$_id][\"__index\"] | length"`
        json=`echo $json | jq ".[$_id][\"__index\"][$len]=\"use_compression\""`
    fi

    echo -e $(json2inf "$json") > frpc.ini

    docker-compose restart
    echo
}

remove_proxy() {
    _name=$1
    CONTAINER_ID=`docker ps -q -f "ancestor=snowdreamtech/frpc"`
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}
    json=`echo $(inf2json frpc.ini)`
    _id=`echo $json | jq "[ .[] | .key == \"$_name\" ] | index(true)"`
    json=`echo $json | jq "del(.[${_id}])"`

    echo -e $(json2inf "$json") > frpc.ini

    docker-compose restart
    echo
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
  ${green}FRP内网穿透 -- 客户端${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动客户端
  ${green} 3${plain}. 停止客户端
  ${green} 4${plain}. 重启客户端
 ------------------------
  ${green} 5${plain}. 安装客户端
  ${green} 6${plain}. 卸载客户端
  ${green} 7${plain}. 配置参数
 ------------------------
  ${green} 8${plain}. 转发服务列表
  ${green} 9${plain}. 添加转发服务
  "
        echo && read -p "请输入选择 [0-9]: " num
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
        read_frpc_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        read_frpc_env
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
                confirm "FRP 客户端正在运行, 是否要重启?" "n"
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
                echo -e "${yellow}FRP 客户端当前停止状态, 无需操作${plain}"
            fi
        ;;
        4)
            echo
            docker-compose restart
        ;;
        esac
        read_frpc_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5  )
        clear
        read_frpc_env
        if [[ $? == 0 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要安装 FRP 客户端吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            install_frpc
            echo -e "${green}FRP 客户端安装完成${plain}"
            echo
            read_frpc_env
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    6  )
        clear
        read_frpc_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要卸载 FRP 客户端吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            remove_frpc
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    7  )
        clear
        read_frpc_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要重新配置 FRP 客户端吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            set_frpc
            read_frpc_env
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    8  )
        clear
        read_frpc_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        
        clear
        list_proxy
        if [[ $? == 0 ]]; then
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    9  )
        clear
        read_frpc_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        
        clear
        add_proxy
        read_frpc_env
        read  -n1  -p "按任意键继续" key
        
        clear
        show_menu
    ;;
    *  )
        clear
        echo -e "${red}请输入正确的数字 [0-9]${plain}"
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