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

# 负载均衡列表
upstream_list() {
    list=(`ls $workdir/upstream | grep -E "*.conf"`)
    echo -e "${green}--------------------------------"
    echo -e "  负载均衡列表"
    echo -e "--------------------------------${plain}"
    echo
    if [[ ${#list[@]} == 0 ]]; then
        echo -e "还没有负载均衡配置！"
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
        upstream_file_opts "${list[$(expr $num - 1)]}"
    else
        clear
        echo -e "${red}请输入正确的数字 [1-$(expr $_id - 1)]${plain}"
        upstream_list
    fi
}

set_upstream_env() {

    while read -p "名称: " _name
    do
        if [[ $_name == '' ]]; then
            echo -e "${yellow}名称不能为空！${plain}"
            continue
        fi
        break
    done

    echo -e "选择方式: "
    echo -e "-------------------------------------"
    echo -e "  default -- 默认轮询方式"
    echo -e "  ip_hash -- 按照访问IP的hash结果分配"
    echo -e "  url_hash -- 按照响应时间（rt）来分配"
    echo -e "  least_conn -- 请求量最小的服务器优先"
    echo -e "-------------------------------------"
    list=(
        default
        ip_hash
        url_hash
        least_conn
    )
    _type=""
    select item in ${list[@]};
    do
        case $item in
        ip_hash | least_conn)
            _type=$item
        ;;
        url_hash)
            _type="hash \$request_uri"
        ;;
        esac
        break
    done

    echo -e "添加主机: "
    _host=()
    list=(添加服务 完成)
    select item in ${list[@]};
    do
        if [[ $item == '完成' ]]; then
            break
        fi
        add_server
        _host[${#_host[@]}]=$_server_host
        echo -e "1) 继续添加"
        echo -e "2) 完成"
        continue
    done
}

# 添加负载均衡
add_upstream() {
    echo -e "${green}--------------------------------"
    echo -e "  添加负载均衡"
    echo -e "--------------------------------${plain}"
    echo

    set_upstream_env
    _confile=$workdir/upstream/${_name}.conf

    echo -e "# $_confile" > $_confile
    echo -e "upstream $_name {" >> $_confile
    if [[ $_type != '' ]]; then
         echo -e "    $_type;" >> $_confile
    fi
    echo -e "    " >> $_confile
    for item in "${_host[@]:1}";
    do
        echo -e "    $item;" >> $_confile
    done
    echo -e "    " >> $_confile
    echo -e "}" >> $_confile
}

add_server() {
    _server_host=""
    while read -p "主机: " _host
    do
        if [[ $_host == '' ]]; then
            echo -e "${yellow}主机名不能为空！${plain}"
            continue
        fi
        break
    done
    set_server_host
    _server_host="server $_host $_command"
}

set_server_host() {
    _command=""
    while read -p "最大失败次数: " _maxfails;
    do
        if [[ $_maxfails == '' ]]; then
            break
        fi
        if [[ ! $_maxfails =~ [0-9]{1,2} ]]; then
            echo -e "${red}最大失败次数必须是数字！${plain}"
            continue
        fi
        _command="$_command max_fails=$_maxfails"
        break
    done
    while read -p "失败后暂停时间: " _timeout;
    do
        if [[ $_timeout == '' ]]; then
            break
        fi
        if [[ ! $_timeout =~ [0-9]{1,2} ]]; then
            echo -e "${red}失败后暂停时间必须是数字！${plain}"
            continue
        fi
        _command="$_command fail_timeout=$_timeout"
        break
    done
    while read -p "权重: " _weight
    do
        if [[ $_weight == '' ]]; then
            break
        fi
        if [[ ! $_weight =~ [0-9]{1,2} ]]; then
            echo -e "${red}权重必须是数字！${plain}"
            continue
        fi
        _command="$_command weight=$_weight"
        break
    done
    echo -e "选择服务标记: "
    echo -e "-------------------------------------"
    echo -e "  none -- 没有标记"
    echo -e "  backup -- 所有服务请求失败时，对 backup 的服务进行分流"
    echo -e "  down -- 标记为不可用"
    echo -e "-------------------------------------"
    list=(none backup down)
    select item in ${list[@]};
    do
        case $item in
        backup | down)
            _command="$_command $item"
        ;;
        esac
        break
    done
}

# 负载均衡文件
upstream_file_opts() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  负载均衡配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    echo -e "1).\t配置详情"
    echo -e "2).\t手动编辑"
    echo -e "3).\t删除配置"

    echo && read -p "请输入选择 [1-3]: " num

    case "$num" in
    1)
        clear
        view_upstream_file "${_confile}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        upstream_file_opts "${_confile}"
    ;;
    2)
        clear
        edit_upstream_file "${_confile}"
        clear
        upstream_file_opts "${_confile}"
    ;;
    3)
        clear
        del_upstream_file "${_confile}"
        if [[ $? == 1 ]]; then
            clear
            upstream_file_opts "${_confile}"
            return 1
        fi
        echo
        read  -n1  -p "按任意键继续" key
        clear
        upstream_file_opts
    ;;
    x)
        clear
        upstream_list
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [1-3]${plain}"
        upstream_file_opts "${_confile}"
    ;;
    esac

}

# 查看负载均衡配置
view_upstream_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  负载均衡配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo
    if [[ ! -f $workdir/upstream/$_confile ]]; then
        echo
        echo -e "${yellow}配置文件不存在！${plain}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        upstream_file_opts "${_confile}"
        return 1
    fi
    echo -e "========================================================"
    echo -e "${yellow}# configuration file $workdir/upstream/$_confile:${plain}"
    echo
    cat $workdir/upstream/$_confile
    echo
    echo -e "========================================================"
}

# 编辑负载均衡配置
edit_upstream_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  负载均衡配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    vi $workdir/upstream/$_confile
}

# 删除负载均衡配置
del_upstream_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  删除负载均衡配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    confirm "确定要删除负载均衡配置-[${_confile}]-吗?" "n"
    if [[ $? == 1 ]]; then
        return 1
    fi

    rm -rf $workdir/upstream/$_confile

    echo
    echo -e "${green}已成功删除负载均衡配置 -- ${_confile}${plain}"
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}负载均衡${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 负载均衡列表
  ${green} 2${plain}. 添加负载均衡
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
        upstream_list
        if [[ $? == 1 ]]; then
            clear
            show_menu
        fi
    ;;
    2)
        clear
        add_upstream
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


