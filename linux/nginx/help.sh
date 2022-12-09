#! /bin/bash

default_workdir=/home/nginx-data
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
    if (nginx -v &> /dev/null); then
        nginx -v
        get_nginx_env
        echo
        echo -e "工作目录: \t$workdir"
        echo -e "站点配置: \t$confdir"
        echo -e "反向代理: \t$workdir/proxys"
        echo -e "负载均衡: \t$workdir/upstream"
        echo -e "Stream: \t$workdir/stream"
        echo -e "日志文件: \t$workdir/logs"
        echo -e "虚拟主机: \t$workdir/wwwroot"
    else
        return 1
    fi
}

read_nginx_env() {
    get_nginx_status
    if [[ $? == 1 ]]; then
        echo -e "${yellow}Nginx 未安装, 请先安装${plain}"
        return 1
    fi
    status=`systemctl status nginx | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
}

# 参数设置
set_setting() {
    echo -e "${green}--------------------------------"
    echo -e "  参数设置"
    echo -e "--------------------------------${plain}"
    echo

    vi $workdir/setting.conf
}

show_menu() {
    echo -e "
  ${green}Nginx 管理助手${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动 Nginx
  ${green} 3${plain}. 停止 Nginx
  ${green} 4${plain}. 重启 Nginx
 ------------------------
  ${green} 5${plain}. 管理站点
  ${green} 6${plain}. 负载均衡
  ${green} 7${plain}. Stream
  ${green} 8${plain}. SSL证书
  ${green} 9${plain}. 参数设置
 ------------------------
  ${green}10${plain}. 安装 Nginx
  ${green}11${plain}. 卸载 Nginx
  ${green}12${plain}. 设置工作目录
  ${green}13${plain}. 更新 Nginx
  "
    echo && read -p "请输入选择 [0-13]: " num
    echo
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/nginx' ]]; then
            run_script ../help.sh
        else
            exit 0
        fi
    ;;
    1  )
        clear
        read_nginx_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        read_nginx_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Nginx 正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    echo
                    systemctl restart nginx
                else
                    clear
                    show_menu
                    return 0
                fi
            else
                echo
                systemctl start nginx
            fi
        ;;
        3)
            if [[ $status == 'running' ]]; then
                echo
                systemctl stop nginx
            else
                echo
                echo -e "${yellow}Nginx 当前停止状态, 无需存在${plain}"
                echo
                read  -n1  -p "按任意键继续" key
                clear
                show_menu
                return 0
            fi
        ;;
        4)
            echo
            systemctl restart nginx
        ;;
        esac
        clear
        read_nginx_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5   )
        clear
        run_script server.sh
    ;;
    6   )
        clear
        run_script upstream.sh
    ;;
    7   )
        clear
        run_script stream.sh
    ;;
    8   )
        clear
        run_script ssl.sh
    ;;
    9   )
        clear
        set_setting
        clear
        show_menu
    ;;
    # 
    10  )
        clear
        read_nginx_env
        if [[ $? == 0 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        run_script install.sh
        sleep 3
        echo -e "${yellow}设置工作目录...${plain}"
        run_script init_conf.sh $default_workdir
        read_nginx_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    11  )
        clear
        read_nginx_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要卸载 Nginx 吗?" "n"
        if [[ $? == 0 ]]; then
            run_script install.sh remove
            echo
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    12  )
        clear
        read_nginx_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        clear
        echo -e "${yellow}设置工作目录...${plain}"
        run_script init_conf.sh
        read_nginx_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    13  )
        clear
        run_script install.sh update
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    *  )
        clear
        echo -e "${red}请输入正确的数字 [0-13]${plain}"
        sleep 1
        show_menu
    ;;
    esac
}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/nginx\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        mkdir -p $(dirname $filepath)
        wget -O $filepath ${REPOSITORY_RAW_ROOT}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

clear
check_sys
# get_nginx_env
show_menu