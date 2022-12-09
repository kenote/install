#! /bin/bash

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

# Stream列表
stream_list() {
    list=(`ls $workdir/stream/conf | grep -E "*.conf"`)
    echo -e "${green}--------------------------------"
    echo -e "  Stream列表"
    echo -e "--------------------------------${plain}"
    echo
    if [[ ${#list[@]} == 0 ]]; then
        echo -e "还没有Stream配置！"
        echo
        read  -n1  -p "按任意键继续" key
        return 1
    fi
    _id=1
    for item in ${list[@]};
    do
        echo -e "${_id}).\t${item}"
        _id=`expr $_id + 1`
    done

    echo && read -p "请输入选择 [1-$(expr $_id - 1)]: " num

    if [[ $num == 'x' ]]; then
        return 1
    elif [[ $num =~ ^[0-9]+$ && $num -lt $_id && $num -ge 1 ]]; then
        clear
        stream_file_opts "${list[$(expr $num - 1)]}"
    else
        clear
        echo -e "${red}请输入正确的数字 [1-$(expr $_id - 1)]${plain}"
        stream_list
    fi
}

stream_file_opts() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  Stream配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    echo -e "1).\t配置详情"
    echo -e "2).\t手动编辑"
    echo -e "3).\t删除配置"

    echo && read -p "请输入选择 [1-3]: " num

    case "$num" in
    1)
        clear
        view_stream_file "${_confile}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        stream_file_opts "${_confile}"
    ;;
    2)
        clear
        edit_stream_file "${_confile}"
        clear
        stream_file_opts "${_confile}"
    ;;
    3)
        clear
        del_stream_file "${_confile}"
        if [[ $? == 1 ]]; then
            clear
            stream_file_opts "${_confile}"
            return 1
        fi
        echo
        read  -n1  -p "按任意键继续" key
        clear
        stream_file_opts
    ;;
    x)
        clear
        stream_list
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [1-3]${plain}"
        stream_file_opts "${_confile}"
    ;;
    esac
}

# 查看Stream配置
view_stream_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  Stream配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo
    if [[ ! -f $workdir/stream/conf/$_confile ]]; then
        echo
        echo -e "${yellow}配置文件不存在！${plain}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        upstream_file_opts "${_confile}"
        return 1
    fi
    echo -e "========================================================"
    echo -e "${yellow}# configuration file $workdir/stream/conf/$_confile:${plain}"
    echo
    cat $workdir/stream/conf/$_confile
    echo
    echo -e "========================================================"
}

# 编辑Stream配置
edit_stream_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  Stream配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    vi $workdir/stream/conf/$_confile

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi
}

# 删除负载均衡配置
del_stream_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  删除Stream配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    confirm "确定要删除Stream配置-[${_confile}]-吗?" "n"
    if [[ $? == 1 ]]; then
        return 1
    fi

    rm -rf $workdir/stream/conf/$_confile

    echo
    echo -e "${green}已成功删除Stream配置 -- ${_confile}${plain}"

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi
}

set_stream_env() {
    while read -p "端口: " _port
    do
        if [[ $_port == '' ]]; then
            echo -e "${red}端口不能为空！${plain}"
            continue
        fi
        if [[ ! $_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}端口格式错误！${plain}"
            continue
        fi
        break
    done
    while read -p "转发服务: " _serevr
    do
        if [[ $_serevr == '' ]]; then
            echo -e "${red}转发服务不能为空！${plain}"
            continue
        fi
        break
    done
    while read -p "设置超时: " _timeout
    do
        if [[ $_timeout == '' ]]; then
            break
        fi
        if [[ ! $_timeout =~ ^[0-9]{1,3}$ ]]; then
            echo -e "${red}超时必须是数字！${plain}"
            continue
        fi
        break
    done
    while read -p "连接超时: " _conect_timeout
    do
        if [[ $_conect_timeout == '' ]]; then
            break
        fi
        if [[ ! $_conect_timeout =~ ^[0-9]{1,3}$ ]]; then
            echo -e "${red}连接超时必须是数字！${plain}"
            continue
        fi
        break
    done

}

# 添加Stream
add_stream() {
    echo -e "${green}--------------------------------"
    echo -e "  添加Stream"
    echo -e "--------------------------------${plain}"
    echo

    set_stream_env
    _confile=$workdir/stream/conf/${_port}::default.conf

    echo -e "# $_confile" > $_confile
    echo -e "server {" >> $_confile
    echo -e "    listen $_port;" >> $_confile
    echo -e "    proxy_pass $_serevr;" >> $_confile
    if [[ $_timeout != '' ]]; then
        echo -e "    proxy_timeout ${_timeout}s;" >> $_confile
    fi
    if [[ $_conect_timeout != '' ]]; then
        echo -e "    proxy_connect_timeout ${_conect_timeout}s;" >> $_confile
    fi
    echo -e "}" >> $_confile

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}Stream${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. Stream列表
  ${green} 2${plain}. 添加Stream
  "
        echo && read -p "请输入选择 [0-2]: " num
        echo
    fi
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/nginx' ]]; then
            run_script help.sh
        else
            exit 0
        fi
    ;;
    1)
        clear
        stream_list
        if [[ $? == 1 ]]; then
            clear
            show_menu
        fi
    ;;
    2)
        clear
        add_stream
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [0-2]${plain}"
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
get_nginx_env
show_menu "$@"