#! /bin/bash

ssldir=/home/ssl
workdir=/home
current_dir=$(cd $(dirname $0);pwd)

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

# 获取 nginx 变量
get_nginx_env() {
    # 获取 nginx 主路径; 一般为: /etc/nginx
    rootdir=`find /etc /usr/local -name nginx.conf | sed -e 's/\/nginx\.conf//'`
    if [[ $rootdir == '' ]]; then
        return 1
    fi
    # 获取 nginx 配置文件夹路径; 一般为: /etc/nginx/conf.d
    conflink=`cat ${rootdir}/nginx.conf | grep "conf.d/\*.conf;" | sed -e 's/\s//g' | sed -e 's/include//' | sed -e 's/\/\*\.conf\;//'`
    # 获取 nginx 配置文件夹真实路径
    confdir=`readlink -f ${conflink}`
    # 获取工作目录
    if [[ $confdir != $conflink ]]; then
        workdir=`readlink -f ${conflink} | sed -e 's/\/conf$//'`
        ssldir=$workdir/ssl
    fi
}

get_nginx_status() {
    if (is_command nginx); then
        status=`systemctl status nginx | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
        nginx -v
    else
        echo -e "${yellow}Nginx 未安装, 请先安装${plain}"
    fi
}

read_nginx_env() {
    status=`systemctl status nginx | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
    echo
}

show_menu() {
    get_nginx_status
    echo -e "
  ${green}Nginx 管理助手${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动 Nginx
  ${green} 3${plain}. 停止 Nginx
  ${green} 4${plain}. 重启 Nginx
 ------------------------
  ${green} 5${plain}. 站点管理
  ${green} 6${plain}. SSL证书管理
 ------------------------
  ${green} 7${plain}. 安装 Nginx
  ${green} 8${plain}. 卸载 Nginx
  ${green} 9${plain}. 设置工作目录
  ${green}10${plain}. 更新 Nginx
  "
    echo && read -p "请输入选择 [0-10]: " num
    echo
    case "${num}" in
    0  )
        exit 0
    ;;
    1  )
        clear
        if !(is_command nginx); then
            show_menu
            return 1
        fi
        read_nginx_env
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        if !(is_command nginx); then
            show_menu
            return 1
        fi
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Nginx 正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    systemctl restart nginx
                fi
            else
                systemctl start nginx
            fi
        ;;
        3)
            if [[ $status == 'running' ]]; then
                systemctl stop nginx
            else
                echo -e "${yellow}Nginx 当前停止状态, 无需存在${plain}"
            fi
        ;;
        4)
            systemctl restart nginx
        ;;
        esac
        read_nginx_env
        show_menu
    ;;
    5   )
        clear
        run_script http_server.sh
    ;;
    6   )
        clear
        run_script ssl.sh
    ;;
    # 
    7   )
        clear
        run_script install.sh
        read  -n1  -p "按任意键继续" key
        clear
        read_nginx_env
        show_menu
    ;;
    8   )
        clear
        confirm "确定要卸载 Nginx 吗?" "n"
        if [[ $? == 0 ]]; then
            run_script install.sh remove
            echo -e "${green}已成功卸载 Nginx ${plain}"
        else
            echo -e "${red}您取消了卸载 Nginx ${plain}"
        fi
        read  -n1  -p "按任意键继续" key
        clear
        read_nginx_env
        show_menu
    ;;
    9   )
        clear
        if !(is_command nginx); then
            show_menu
            return 1
        fi
        run_script init_conf.sh
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    10  )
        clear
        run_script install.sh update
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-10]${plain}"
    ;;
    esac
}

run_script() {
    file=$1
    if [[ -f $current_dir/$file ]]; then
        sh $current_dir/$file "${@:2}"
    else
        wget -O $current_dir/$file ${urlroot}/main/linux/nginx/$file && chmod +x $current_dir/$file && clear && $current_dir/$file "${@:2}"
    fi
}

clear
check_sys
get_nginx_env
show_menu