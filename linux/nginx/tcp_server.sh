#! /bin/bash

ssldir=/home/ssl
workdir=/home

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 获取 nginx 变量
get_nginx_env() {
    # 获取 nginx 主路径; 一般为: /etc/nginx
    rootdir=`find /etc /usr/local -name nginx.conf | sed -e 's/\/nginx\.conf//'`
    # 获取 nginx 配置文件夹路径; 一般为: /etc/nginx/conf.d
    conflink=`cat ${rootdir}/nginx.conf | grep "conf.d/\*.conf;" | sed -e 's/\s//g' | sed -e 's/include//' | sed -e 's/\/\*\.conf\;//'`
    # 获取 nginx 配置文件夹真实路径
    confdir=`readlink -f ${conflink}`
    # 获取工作目录
    if [[ $confdir != $conflink ]]; then
        workdir=`readlink -f ${conflink} | sed -e 's/\/conf$//'`
        ssldir=$workdir/ssl
    fi
    mkdir -p $workdir/stream/server
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

set_server_env() {
    _port=""
    _proxy_pass=""
    _timeout=""
    _connect_timeout=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --port)
            _port=$2
            if [[ $_port == '' ]]; then
                echo -e "${red}转发端口不能为空！${plain}"
                return 1
            fi
            if [[ ! $_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
                echo -e "${red}转发端口格式错误！${plain}"
                return 1
            fi
            shift
        ;;
        --proxy_pass)
            _proxy_pass=$2
            if [[ $_proxy_pass == '' ]]; then
                echo -e "${red}代理主机不能为空！${plain}"
                return 1
            fi
            shift
        ;;
        --timeout)
            _timeout=$2
            if [[ ! $_timeout =~ [0-9]{1,2} ]]; then
                echo -e "${red}代理超时必须是数字！${plain}"
                return 1
            fi
        ;;
        --connect_timeout)
             _connect_timeout=$2
            if [[ ! $_connect_timeout =~ [0-9]{1,2} ]]; then
                echo -e "${red}连接超时必须是数字！${plain}"
                return 1
            fi
        ;;
        *)
            _err "Unknown parameter : $1"
            return 1
            shift
        ;;
        esac
        shift 1
    done
    if [[ $_port == '' ]]; then
        while read -p "转发端口: " _port;
        do
            if [[ $_port == '' ]]; then
                echo -e "${red}转发端口不能为空！${plain}"
                continue
            fi
            if [[ ! $_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
                echo -e "${red}转发端口格式错误！${plain}"
                continue
            fi
            echo -e "${yellow}转发端口: ${_port}${plain}"
            break
        done
        while read -p "代理主机: " _proxy_pass;
        do
            if [[ $_proxy_pass == '' ]]; then
                echo -e "${red}代理主机不能为空！${plain}"
                continue
            fi
            echo -e "${yellow}代理主机: ${_proxy_pass}${plain}"
            break
        done
        while read -p "代理超时[可不填: 秒]: " _timeout;
        do
            if [[ $_timeout == '' ]]; then
                break
            fi
            if [[ ! $_timeout =~ [0-9]{1,2} ]]; then
                echo -e "${red}代理超时必须是数字！${plain}"
                continue
            fi
            echo -e "${yellow}代理超时: ${_timeout}${plain}"
            break
        done
        while read -p "连接超时[可不填: 秒]: " _connect_timeout;
        do
            if [[ $_connect_timeout == '' ]]; then
                break
            fi
            if [[ ! $_connect_timeout =~ [0-9]{1,2} ]]; then
                echo -e "${red}连接超时必须是数字！${plain}"
                continue
            fi
            echo -e "${yellow}连接超时: ${_connect_timeout}${plain}"
            break
        done
    fi
}

set_server() {
    set_server_env "$@"
    if [[ $? == 0 ]]; then
        mkdir -p $workdir/stream/server
        echo -e "confile: $workdir/stream/server/${_port}::default.conf"
        echo -e "
server {
    listen $_port;
    proxy_pass $_proxy_pass;
    $(if [[ $_timeout != '' ]]; then
        echo -e "proxy_timeout: ${_timeout}s;"
    fi)
    $(if [[ $_connect_timeout != '' ]]; then
        echo -e "proxy_connect_timeout: ${_connect_timeout}s;"
    fi)
}
        " > $workdir/stream/server/${_port}::default.conf
        echo -e "${green}写入TCP代理配置-[${_port}::default.conf]-完成${plain}"
    else
        return 1
    fi
}

get_server() {
    confile=$1
    if [[ $confile == '' ]]; then
        echo -e "\n${yellow}选择TCP代理配置:${plain}\n"
        select item in `ls $workdir/stream/server`;
        do
            confile=$item
            echo -e "${yellow}TCP代理配置: ${item}${plain}"
            break
        done
    fi
    clear
    echo -e "========================================================"
    echo -e "${yellow}# configuration file $workdir/stream/server/$confile:${plain}"
    echo
    cat $workdir/stream/server/$confile
    echo
    echo -e "========================================================"
}

remove_server() {
    confile=$1
    if [[ $confile == '' ]]; then
        echo -e "\n${yellow}选择TCP代理配置:${plain}\n"
        select item in `ls $workdir/stream/server`;
        do
            # confile=`echo $item | sed 's/\.conf$//'`
            confile=$item
            echo -e "${yellow}TCP代理配置: ${item}${plain}"
            break
        done
    fi
    confirm "确定要删除TCP代理配置-[${confile}]-吗?" "n"
    if [[ $? == 0 ]]; then
        rm -rf $workdir/stream/server/$confile
        echo -e "${green}已成功删除TCP代理配置-[${confile}]-${plain}"
    else
        echo -e "${red}您取消了删除TCP代理配置-[${confile}]-${plain}"
        return 1
    fi
}

main() {
    case $1 in
    set)
        set_server "${@:2}"
    ;;
    get)
        get_server "${@:2}"
    ;;
    remove | del)
        remove_server "${@:2}"
    ;;
    * )
        exit 0
    ;;
    esac
}

get_nginx_env
main "$@"