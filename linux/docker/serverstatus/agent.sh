#!/bin/bash

SSS_BASE_PATH="/opt/sss"
SSS_AGENT_PATH="${SSS_BASE_PATH}/agent"
SERVICE_NAME="sss-agent.service"
SSS_AGENT_SERVICE="/etc/systemd/system/${SERVICE_NAME}"
REPOSITORY_RAW_URL="https://raw.githubusercontent.com/lidalao/ServerStatus/master"

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

pre_check(){
    if (is_oversea); then
        REPOSITORY_RAW_URL="https://raw.githubusercontent.com/kenote/install/main/linux/docker/serverstatus"
    else
        REPOSITORY_RAW_URL="https://gitee.com/kenote/install/raw/main/linux/docker/serverstatus"
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

read_agent_env() {
    status=`systemctl status ${SERVICE_NAME} | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
    echo
}

get_param_val() {
    eval _$2=`echo "$1" | sed -E 's/--([0-9a-zA-Z\-]+)\s/\1\=/g' | sed 's/\s/\n/g' | grep -E "^${2}=" | sed -E 's/([0-9a-zA-Z\-]+)\=([^\s+])/\2/'`
}

modify_agent_config() {

    _host=""
    _user=""
    _pass=""
    _token=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --host_flag)

        ;;
        --user)

        ;;
        --pass)

        ;;
        --token)
            _token=$2
            shift
        ;;
        *)
            _err "Unknown parameter : $1"
            return 1
            shift
        ;;
        esac
        shift 1
    done

    if [[ $_token != '' ]]; then
        keycode=`echo "${_token}" | base64 --decode`
        get_param_val "$keycode" host
        get_param_val "$keycode" user
        get_param_val "$keycode" pass
    fi

    if [[ $_host == '' || $_user == '' || $_pass = '' ]]; then
        list=(使用Token 传统方式)
        _type=""
        select item in ${list[@]};
        do
            _type=$item
            break
        done
        case "$_type" in
        使用Token)
            while read -p "您的Token: " _token
            do
                if [[ $_token = '' ]]; then
                    echo -e "${red}Token 不能为空！${plain}"
                    continue
                fi
                break
            done
            keycode=`echo "${_token}" | base64 --decode`
            get_param_val "$keycode" host
            get_param_val "$keycode" user
            get_param_val "$keycode" pass
        ;;
        传统方式)
            while read -p "伺服器IP: " _host
            do
                if [[ $_host = '' ]]; then
                    echo -e "${red}伺服器IP不能为空！${plain}"
                    continue
                fi
                break
                break
            done
            while read -p "用户名: " _user
            do
                if [[ $_user = '' ]]; then
                    echo -e "${red}用户名不能为空！${plain}"
                    continue
                fi
                break
                break
            done
            while read -p "密码: " _pass
            do
                if [[ $_pass = '' ]]; then
                    echo -e "${red}密码不能为空！${plain}"
                    continue
                fi
                break
                break
            done
        ;;
        * )
            return 1
        ;;
        esac
        
    fi

    # 下载 service 文件
    wget -O $SSS_AGENT_SERVICE ${REPOSITORY_RAW_URL}/agent.service >/dev/null 2>&1
    
    SSS_AGENT_EXEC=`echo "$(command -v python3 2> /dev/null || command -v python) ${SSS_AGENT_PATH}/client-linux.py SERVER=${_host} USER=${_user} PASSWORD=${_pass}"`

    sed -i "s/$(cat ${SSS_AGENT_SERVICE} | grep -E "^WorkingDirectory=")/WorkingDirectory=${SSS_AGENT_PATH}/" ${SSS_AGENT_SERVICE}
    sed -i "s/$(cat ${SSS_AGENT_SERVICE} | grep -E "^ExecStart=")/ExecStart=${SSS_AGENT_EXEC}/" ${SSS_AGENT_SERVICE}

    echo -e "${green}客户端配置成功，请等待重启生效${plain}"

    # 重启进程
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    systemctl restart ${SERVICE_NAME}
}

install_agent() {
    echo -e "${green}----------------"
    echo -e "  安装 Server Status 客户端"
    echo -e "----------------${plain}"

    if !(is_command python3); then
        echo -e "正在安装基础组件 python3..."
        yum install -y python3 2> /dev/null || apt install -y python3
    fi

    # 创建目录
    mkdir -p $SSS_AGENT_PATH
    chmod 777 -R $SSS_AGENT_PATH

    # 下载监控端
    echo -e "正在下载监控端..."
    wget --no-check-certificate -qO $SSS_AGENT_PATH/client-linux.py $REPOSITORY_RAW_URL/client-linux.py

    echo -e "开始配置客户端参数..."
    modify_agent_config "$@"

}

remove_agent() {
    if (systemctl list-unit-files | grep "${SERVICE_NAME}"  &> /dev/null); then
        systemctl stop ${SERVICE_NAME}
        systemctl disable ${SERVICE_NAME}
        rm -rf ${SSS_AGENT_SERVICE}
        systemctl daemon-reload
    fi
    if [ -d $SSS_AGENT_PATH ]; then
        rm -rf ${SSS_AGENT_PATH}
    fi
}

show_menu() {

    echo -e "
  ${green}Server Status监控管理 -- 客户端${plain}

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
  "
    echo && read -p "请输入选择 [0-7]: " num
    echo
    
    case "${num}" in
    0  )
        exit 0
    ;;
    1  )
        clear
        if !(systemctl list-unit-files | grep "${SERVICE_NAME}"  &> /dev/null); then
            echo -e "${yellow}检测到 Server Status 客户端未安装，请先安装客户端${plain}"
            show_menu
            return 1
        fi
        read_agent_env
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        if !(systemctl list-unit-files | grep "${SERVICE_NAME}"  &> /dev/null); then
            echo -e "${yellow}检测到 Server Status 客户端未安装，请先安装客户端${plain}"
            show_menu
            return 1
        fi
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Server Status 客户端正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    systemctl restart ${SERVICE_NAME}
                fi
            else
                systemctl start ${SERVICE_NAME}
            fi
        ;;
        3)
            if [[ $status == 'running' ]]; then
                systemctl stop ${SERVICE_NAME}
            else
                echo -e "${yellow}Server Status 客户端当前停止状态, 无需操作${plain}"
            fi
        ;;
        4)
            systemctl restart ${SERVICE_NAME}
        ;;
        esac
        read_agent_env
        show_menu
    ;;
    5  )
        clear
        if (systemctl list-unit-files | grep "${SERVICE_NAME}"  &> /dev/null); then
            echo -e "${yellow}检测到 Server Status 客户端已安装${plain}"
            show_menu
            return 1
        fi
        confirm "确定要安装 Server Status 客户端吗?" "n"
        if [[ $? == 0 ]]; then
            install_agent
        fi
        read  -n1  -p "按任意键继续" key
        clear
        read_agent_env
        show_menu
    ;;
    6  )
        clear
        if !(systemctl list-unit-files | grep "${SERVICE_NAME}"  &> /dev/null); then
            echo -e "${yellow}检测到 Server Status 客户端未安装，请先安装客户端${plain}"
            show_menu
            return 1
        fi
        confirm "确定要卸载 Server Status 客户端吗?" "n"
        if [[ $? == 0 ]]; then
            remove_agent
        fi
        read  -n1  -p "按任意键继续" key
        clear
        read_agent_env
        show_menu
    ;;
    7  )
        clear
        if !(systemctl list-unit-files | grep "${SERVICE_NAME}"  &> /dev/null); then
            echo -e "${yellow}检测到 Server Status 客户端未安装，请先安装客户端${plain}"
            show_menu
            return 1
        fi
        echo -e "${green}----------------"
        echo -e "  配置参数"
        echo -e "----------------${plain}"
        modify_agent_config "$@"
        read  -n1  -p "按任意键继续" key
        clear
        read_agent_env
        show_menu
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-7]${plain}"
    ;;
    esac
}

main() {
    case $1 in
    install)
        if (systemctl list-unit-files | grep "${SERVICE_NAME}"  &> /dev/null); then
            echo -e "${yellow}检测到 Server Status 客户端已安装${plain}"
            show_menu
            return 1
        fi
        install_agent "${@:2}"
    ;;
    * )
        clear
        show_menu
    ;;
    esac
}

pre_check
main "$@"