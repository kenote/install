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
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
    fi
    REPOSITORY_RAW_URL="${REPOSITORY_RAW_ROOT}/main/linux/docker/serverstatus"
    curl -s ${REPOSITORY_RAW_ROOT}/main/linux/docker/help.sh | bash -s install
    ROOT_DIR=`[ -f $HOME/.docker_profile ] && cat $HOME/.docker_profile | grep "^DOCKER_WORKDIR" | sed -n '1p' |  sed 's/\(.*\)=\(.*\)/\2/g' || echo "/home/docker-data"`
}

read_dashboard_env() {
    CONTAINER_ID=`docker container ls -a -q -f "ancestor=cppla/serverstatus"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${yellow}Server Status 面板未安装${plain}"
        return 1
    fi
    status=`docker inspect ${CONTAINER_ID} | jq -r ".[0].State.Status"`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
}

set_dashboard_env() {
    _path=$1
    HTTP_PORT="8081"
    BIND_PORT="35601"
    if [[ $_path == '' ]]; then
        while read -p "安装路径[serverstatus]: " _name
        do
            if [[ $_path = '' ]]; then
                _name="serverstatus"
            fi
            _path=`[[ $_name =~ ^\/ ]] && echo "${_name}" || echo "${ROOT_DIR}/${_name}"`
            break
        done
    else
        CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
        HTTP_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"${HTTP_PORT}/tcp\"][0].HostPort"`
        BIND_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"${BIND_PORT}/tcp\"][0].HostPort"`
    fi
    while read -p "面板端口[${HTTP_PORT}]:" _http_port
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
    while read -p "TCP端口[默认 ${BIND_PORT}]:" _bind_port
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

set_dashboard() {
    CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}Server Status 面板未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------"
    echo -e "  配置 Server Status 监控面板"
    echo -e "----------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    set_dashboard_env ${WORK_DIR}
    SSS_HTTP_PORT=$_http_port
    SSS_BIND_PORT=$_bind_port

    # 创建环境变量
    echo
    echo -e "正在配置面板参数..."
    echo -e "HTTP_PORT=${SSS_HTTP_PORT}\nBIND_PORT=${SSS_BIND_PORT}" > .env

    # 启动面板
    echo -e "正在启动监控面板..."
    docker-compose up -d
    echo
}

install_dashboard() {
    echo -e "${green}----------------"
    echo -e "  安装 Server Status 监控面板"
    echo -e "----------------${plain}"
    
    # 设置面板参数
    set_dashboard_env
    SSS_BASE_PATH=$_path
    SSS_HTTP_PORT=$_http_port
    SSS_BIND_PORT=$_bind_port

    # 创建工作目录
    mkdir -p ${SSS_BASE_PATH}
    cd ${SSS_BASE_PATH}

    # 拉取 docker-compose.yml
    echo -e "正在配置面板参数..."
    wget --no-check-certificate -qO docker-compose.yml $REPOSITORY_RAW_URL/compose.yml
    # 创建环境变量
    echo -e "HTTP_PORT=${SSS_HTTP_PORT}\nBIND_PORT=${SSS_BIND_PORT}" > .env
    # 创建配置文件
    echo "{\"servers\":[]}" | jq > config.json

    # 启动面板
    echo -e "正在启动监控面板..."
    docker-compose up -d

}

remove_dashboard() {
    echo -e "${green}----------------"
    echo -e "  卸载 Server Status 监控面板"
    echo -e "----------------${plain}"
    if (docker ps -q -f "ancestor=cppla/serverstatus"  &> /dev/null); then
        CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        docker-compose down -v
        rm -rf ${WORK_DIR}
        echo -e "${green}Server Status 监控面板卸载完成${plain}"
    fi
}

add_agent() {
    CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}Server Status 面板未安装${plain}"
        return 1
    fi
    echo -e "${green}--------------------------------"
    echo -e "  添加监控节点"
    echo -e "--------------------------------${plain}"

    while read -p "节点名称: " _name
    do
        if [[ $_name == '' ]]; then
            echo -e "${red}节点名称不能为空${plain}"
            continue
        fi
        break
    done
    while read -p "地区/国家: " _location
    do
        if [[ $_location == '' ]]; then
            echo -e "${red}地区/国家不能为空${plain}"
            continue
        fi
        if [[ ! $_location =~ ^[a-z]{2}$ ]]; then
            echo -e "${red}请填写地区/国家代码[小写]！${plain}参阅: https://www.dute.org/country-code"
            continue
        fi
        break
    done
    while read -p "虚拟化[默认 kvm]: " _type
    do
        if [[ $_type == '' ]]; then
            _type="kvm"
        fi
        break
    done
    confirm "是否采用本机IP?" "n"
    if [[ $? == 0 ]]; then
        if !(systemctl list-unit-files | grep "sss-agent.service"  &> /dev/null); then
            use_localip="true"
        fi
    fi
    

    _user=`uuidgen | tr -dc '[:xdigit:]'`
    _pass=`strings /dev/urandom |tr -dc A-Za-z0-9 | head -c16; echo`

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}
    servers=(`cat config.json | jq '.servers[].name'`)

    server="{\"monthstart\":\"1\",\"location\":\"${_location}\",\"type\":\"${_type}\",\"name\":\"${_name}\",\"host\":\"${_name}\",\"username\":\"${_user}\",\"password\":\"${_pass}\"}"
    # cat config.json | jq ".servers[${#servers[@]}]=${server}" 

    echo
    str=`cat config.json | jq ".servers[${#servers[@]}]=${server}"`; 
    echo "$str" > config.json

    docker-compose restart
    echo
    
    if [[ $use_localip == 'true' ]]; then
        BIND_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"35601/tcp\"][0].HostPort"`
        wget -O $HOME/sss-agent.sh ${REPOSITORY_RAW_URL}/agent.sh
        chmod +x $HOME/sss-agent.sh
        sudo $HOME/sss-agent.sh install --host 127.0.0.1 --port ${BIND_PORT} --user $_user --pass $_pass
    else
        look_agent ${#servers[@]}
    fi
}

list_agent() {
    CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}Server Status 面板未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------------------------------------------------------"
    echo -e "  监控节点列表"
    echo -e "----------------------------------------------------------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}
    servers=(`cat config.json | jq '.servers[].name'`)
    _id=0
    echo -e "ID\t节点\t\t虚拟化\t\t地区/国家"
    for item in ${servers[@]};
    do
        _name=`cat config.json | jq ".servers[${_id}].name" | sed -E 's/\"//g'`
        _type=`cat config.json | jq ".servers[${_id}].type" | sed -E 's/\"//g'`
        _location=`cat config.json | jq ".servers[${_id}].location" | sed -E 's/\"//g'`
        _space="\t"
        if [[ ${#_name} -lt 8 ]]; then
            _space="\t\t"
        fi
        echo -e "${_id}\t${_name}${_space}${_type}\t\t${_location}"
        _id=`expr $_id + 1`
    done
    echo

    _selected=""
    while read -p "请输入ID可操作节点或输入 x 返回: " num
    do
        if [[ $num == 'x' ]]; then
            return 1
        elif [[ $num =~ ^[0-9]+$ && $num -lt $_id && $num -ge 0 ]]; then
            _selected=$num
        else
            echo -e "${red}输入正确的ID或 x 返回${plain}"
            continue
        fi
        break
    done

    clear
    echo -e "${green}--------------------------------"
    echo -e "  选择操作节点 -[$(cat config.json | jq ".servers[${_selected}].name" | sed -E 's/\"//g')]-"
    echo -e "--------------------------------${plain}"
    echo
    list=(编辑 删除 安装脚本 返回)
    _opt=""
    select item in ${list[@]};
    do
        _opt=$item
        case "${item}" in
        编辑)
            edit_agent $_selected
        ;;
        删除)
            confirm "确定要删除节点-[$(cat config.json | jq ".servers[${_selected}].name" | sed -E 's/\"//g')]-?" "n"
            if [[ $? == 0 ]]; then
                remove_agent $_selected
            else
                show_menu 8
            fi
        ;;
        安装脚本)
            look_agent $_selected
        ;;
        返回)
            show_menu 8
        ;;
        *)
            echo -e "${red}请输入正确的选项${plain}"
            continue
        ;;
        esac
        break
    done
}

edit_agent() {
    _id=$1
    CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}

    old_name=`cat config.json | jq ".servers[${_id}].name" | sed -E 's/\"//g'`
    old_type=`cat config.json | jq ".servers[${_id}].type" | sed -E 's/\"//g'`
    old_location=`cat config.json | jq ".servers[${_id}].location" | sed -E 's/\"//g'`

    clear
    echo -e "${green}--------------------------------"
    echo -e "  编辑节点 -[$(cat config.json | jq ".servers[${_id}].name" | sed -E 's/\"//g')]-"
    echo -e "--------------------------------${plain}"

    while read -p "节点名称[${old_name}]: " _name
    do
        if [[ $_name == '' ]]; then
            _name=${old_name}
        fi
        break
    done
    while read -p "地区/国家[${old_location}]: " _location
    do
        if [[ $_location == '' ]]; then
            _location=${old_location}
        fi
        if [[ ! $_location =~ ^[a-z]{2}$ ]]; then
            echo -e "${red}请填写地区/国家代码[小写]！${plain}参阅: https://www.dute.org/country-code"
            continue
        fi
        break
    done
    while read -p "虚拟化[${old_type}]: " _type
    do
        if [[ $_type == '' ]]; then
            _type=${old_type}
        fi
        break
    done

    echo
    cat config.json | jq ".servers[${_id}].name=\"${_name}\"" | jq ".servers[${_id}].host=\"${_name}\"" | jq ".servers[${_id}].type=\"${_type}\"" | jq ".servers[${_id}].location=\"${_location}\"" > config.json
    
    docker-compose restart
    echo
}

remove_agent() {
    _id=$1
    CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}

    echo
    str=`cat config.json | jq "del(.servers[0${_id}])"`; 
    echo "$str" > config.json

    docker-compose restart
    echo
}

look_agent() {
    _id=$1
    CONTAINER_ID=`docker ps -q -f "ancestor=cppla/serverstatus"`
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    BIND_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"35601/tcp\"][0].HostPort"`
    cd ${WORK_DIR}

    clear
    echo -e "${green}--------------------------------"
    echo -e "  节点安装脚本 -[$(cat config.json | jq ".servers[${_id}].name" | sed -E 's/\"//g')]-"
    echo -e "--------------------------------${plain}"

    _host=`wget -qO- ip.p3terx.com | sed -n '1p'`
    _user=`cat config.json | jq ".servers[${_id}].username" | sed -E 's/\"//g'`
    _pass=`cat config.json | jq ".servers[${_id}].password" | sed -E 's/\"//g'`
    _param="--host $_host --port ${BIND_PORT} --user $_user --pass $_pass"

    list=(使用Token 传统方式)
    select item in ${list[@]};
    do
        case "${item}" in
        使用Token)
            _token=`echo "${_param}" | base64 | tr -d "\n"`
            echo
            echo -e "wget -O sss-agent.sh ${REPOSITORY_RAW_URL}/agent.sh && chmod +x sss-agent.sh && sudo ./sss-agent.sh install --token ${_token}"
            echo
        ;;
        传统方式)
            echo
            echo -e "wget -O sss-agent.sh ${REPOSITORY_RAW_URL}/agent.sh && chmod +x sss-agent.sh && sudo ./sss-agent.sh install ${_param}"
            echo
        ;;
        *)
            show_menu 8
        ;;
        esac
        break
    done

}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/serverstatus\/..\///'`
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
  ${green}Server Status监控管理 -- 面板${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动监控面板
  ${green} 3${plain}. 停止监控面板
  ${green} 4${plain}. 重启监控面板
 ------------------------
  ${green} 5${plain}. 安装监控面板
  ${green} 6${plain}. 卸载监控面板
  ${green} 7${plain}. 配置面板参数
 ------------------------
  ${green} 8${plain}. 查看监控列表
  ${green} 9${plain}. 添加监控节点
  "
        echo && read -p "请输入选择 [0-9]: " num
        echo
    fi
    
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/docker/serverstatus' ]]; then
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
                confirm "Server Status 监控面板正在运行, 是否要重启?" "n"
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
                echo -e "${yellow}Server Status 监控面板当前停止状态, 无需操作${plain}"
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
        confirm "确定要安装 Server Status 监控面板吗?" "n"
        if [[ $? == 0 ]]; then
            install_dashboard
            echo -e "${green}Portainer 面板安装完成${plain}"
        fi
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
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
        confirm "确定要卸载 Server Status 监控面板吗?" "n"
        if [[ $? == 0 ]]; then
            remove_dashboard
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
        confirm "确定要重新配置 Server Status 监控面板吗?" "n"
        if [[ $? == 0 ]]; then
            set_dashboard
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    8  )
        clear
        read_dashboard_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        list_agent
        if [[ $? == 0 ]]; then
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    9  )
        clear
        read_dashboard_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        add_agent
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
    install)
        clear
        read_dashboard_env
        if [[ $? == 0 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        install_dashboard "${@:2}"
    ;;
    * )
        clear
        show_menu
    ;;
    esac
}

pre_check
main "$@"
