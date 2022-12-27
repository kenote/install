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
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
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

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}常用 Docker 项目${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. Portainer -- Docker图形面板
  ${green} 2${plain}. ServerStatus -- 多服务器监控
  ${green} 3${plain}. FRP -- 内网穿透服务
  ${green} 4${plain}. Vsftpd -- FTP服务端
  ${green} 5${plain}. SpeedTest -- 网络测速
  "
        echo && read -p "请输入选择 [0-5]: " num
        echo
    fi
    
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/docker' ]]; then
            run_script help.sh
        else
            exit 0
        fi
    ;;
    1  )
        run_script portainer/help.sh
    ;;
    2  )
        run_script serverstatus/server.sh
    ;;
    3  )
        list=(服务端 客户端)
        select item in ${list[@]};
        do
            case $item in
            服务端)
                run_script frp/server.sh
            ;;
            客户端)
                run_script frp/agent.sh
            ;;
            *)
                clear
                show_menu
            ;;
            esac
            break
        done
    ;;
    4  )
        run_script vsftpd/help.sh
    ;;
    5  )
        run_script speedtest/help.sh
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-5]${plain}"
    ;;
    esac
}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/docker\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [ -f $filepath ]; then
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

check_sys
main "$@"