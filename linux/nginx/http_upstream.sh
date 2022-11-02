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
    mkdir -p $workdir/upstream
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

#
# --name test
# --least_conn
# --ip_hash
# --host 127.0.0.1:4000
# --host 127.0.0.1:4000\|weight=1
# --host 127.0.0.1:4000\|max_fails=3\|fail_timeout=30s
# --host 127.0.0.1:4000\|backup
# --host 127.0.0.1:4000
set_upstream() {
    _name="" 
    # least_conn -- 最少连接 ｜ ip_hash -- IP地址哈希 ｜ 默认 -- 轮询
    _leastconn=""
    _iphash=""
    _host=()
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --name | -n)
            _name=$2
            if [[ $_name == '' ]]; then
                echo -e "${red}名称不能为空！${plain}"
                return 1
            fi
            if [[ -f $workdir/upstream/$_name.conf ]]; then
                echo -e "${red}该负载均衡名称已存在！${plain}"
                return 1
            fi
            shift
        ;;
        --least_conn)
            _leastconn="least_conn"
        ;;
        --ip_hash)
            _iphash="ip_hash"
            if [[ $_leastconn = 'least_conn' ]]; then
                _iphash=""
            fi
        ;;
        --host | -H)
            _host[${#_host[@]}]=$2
            if [[ $2 == '' ]]; then

                return 1
            fi
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
    if [[ $_name == '' ]]; then
        while read -p "名称: " _name;
        do
            if [[ $_name == '' ]]; then
                echo -e "${red}名称不能为空！${plain}"
                continue
            fi
            if [[ -f $workdir/upstream/$_name.conf ]]; then
                echo -e "${red}该负载均衡名称已存在！${plain}"
                continue
            fi
            echo -e "${yellow}主机: ${_namess}${plain}"
            break
        done
        list=(none least_conn ip_hash)
        echo -e "轮询方式: "
        select item in ${list[@]};
        do
            case $item in
            least_conn)
                _leastconn=$item
            ;;
            ip_hash)
                _iphash=$item
            ;;
            esac
            echo -e "${yellow}轮询方式: ${item}${plain}"
            break
        done
        list=(添加主机 完成)
        echo -e "添加主机: "
        select item in ${list[@]};
        do
            if [[ $item == '完成' ]]; then
                break
            fi
            add_server
            if [[ $? == 0 ]]; then
                _host[${#_host[@]}]=$host
                echo -e "-- $host"
            fi
            echo -e "1) 继续添加"
            echo -e "2) 完成"
            continue
        done
        
    fi
    poll=($_leastconn $_iphash)
    echo -e "$_leastconn"
    echo -e "
upstream $_name {
$(
    if [[ $poll != '' ]]; then
        echo -e "    ${poll[*]};"
    fi
)
$(
    for item in ${_host[@]};
    do
        host=`echo "server $item" | sed 's/|/ /g'`
        echo -e "    $host;"
    done
)
}
    " > $workdir/upstream/$_name.conf
    echo -e "${green}负载均衡配置-[$_name.conf]-已经写入${plain}"
}

add_server() {
    _address=""
    _weight="" # 权重 1-10
    _maxfails="" # 最大失败次数
    _timeout="" # 失败后暂停时间
    _backup="" # 除 backup 字段外机器繁忙时，再请求 backup 机器

    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --address)
            _address=$2
            if [[ $_address == '' ]]; then
                echo -e "${red}请填写主机！${plain}"
                return 1
            fi
            host_flag=`echo "$_address" | gawk '/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\:[1-9][0-9]{1,3}$/{print $0}'`
            if [[ ! -n "${host_flag}" ]]; then
                echo -e "${red}主机格式错误，格式：[host:port]！${plain}"
                return 1
            fi
            shift
        ;;
        --weight)
            _weight=$2
            if [[ ! $_weight =~ [0-9]{1,2} ]]; then
                echo -e "${red}权重必须是数字！${plain}"
                return 1
            fi
            shift
        ;;
        --max_fails)
            _maxfails=$2
            if [[ ! $_maxfails =~ [0-9]{1,2} ]]; then
                echo -e "${red}最大失败次数必须是数字！${plain}"
                return 1
            fi
            shift
        ;;
        --fail_timeout)
            _timeout=$2
            if [[ ! $_timeout =~ [0-9]{1,2} ]]; then
                echo -e "${red}失败后暂停时间必须是数字！${plain}"
                return 1
            fi
            shift
        ;;
        --backup)
            _backup='backup'
        ;;
        *)
            _err "Unknown parameter : $1"
            return 1
            shift
        ;;
        esac
        shift 1
    done
    if [[ $_address == '' ]]; then
        while read -p "主机: " _address;
        do
            if [[ $_address == '' ]]; then
                echo -e "${red}请填写主机！${plain}"
                continue
            fi
            host_flag=`echo "$_address" | gawk '/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\:[1-9][0-9]{1,3}$/{print $0}'`
            if [[ ! -n "${host_flag}" ]]; then
                echo -e "${red}主机格式错误，格式：[host:port]！${plain}"
                continue
            fi
            echo -e "${yellow}主机: ${_address}${plain}"
            break
        done
        while read -p "权重[可不填]: " _weight;
        do
            if [[ $_weight == '' ]]; then
                break
            fi
            if [[ ! $_weight =~ [0-9]{1,2} ]]; then
                echo -e "${red}权重必须是数字！${plain}"
                continue
            fi
            echo -e "${yellow}权重: ${_weight}${plain}"
            break
        done
        while read -p "最大失败次数[可不填]: " _maxfails;
        do
            if [[ $_maxfails == '' ]]; then
                break
            fi
            if [[ ! $_maxfails =~ [0-9]{1,2} ]]; then
                echo -e "${red}最大失败次数必须是数字！${plain}"
                continue
            fi
            echo -e "${yellow}最大失败次数: ${_maxfails}${plain}"
            break
        done
        while read -p "失败后暂停时间[可不填: 秒]: " _timeout;
        do
            if [[ $_timeout == '' ]]; then
                break
            fi
            if [[ ! $_timeout =~ [0-9]{1,2} ]]; then
                echo -e "${red}失败后暂停时间必须是数字！${plain}"
                continue
            fi
            echo -e "${yellow}失败后暂停时间: ${_timeout}${plain}"
            break
        done
        list=($_weight $_maxfails $_timeout)
        if [[ $list == '' ]]; then
            buckup_tag="否"
            read -p "是否作为备份主机?[y/N]": buckup_confirm;
            if [[ x"${buckup_confirm}" == x"y" || x"${buckup_confirm}" == x"Y" ]]; then
                _backup='backup'
                buckup_tag="是"
            fi
            echo -e "${yellow}是否作为备份主机: ${buckup_tag}${plain}"
        fi
    fi
    host=$_address
    if [[ $_weight != '' ]]; then
        host="$host|weight=$_weight"
    fi
    if [[ $_maxfails != '' ]]; then
        host="$host|max_fails=$_maxfails"
    fi
    if [[ $_timeout != '' ]]; then
        host="$host|fail_timeout=${_timeout}s"
    fi
    if [[ $_backup == 'backup' ]]; then
        host="$host|backup"
    fi
}

# get_upstream_env() {

# }

get_upstream() {
    confile=$1
    if [[ $confile == '' ]]; then
        list=`ls $workdir/upstream`
        if [[ $list == '' ]]; then
            echo -e "${yellow}没有负载均衡配置${plain}"
            return 1
        fi
        echo -e "\n${yellow}选择负载均衡配置:${plain}\n"
        select item in `ls $workdir/upstream`;
        do
            confile=$item
            echo -e "${yellow}负载均衡配置: ${item}${plain}"
            break
        done
    fi
    if [[ $confile != '' && -f $workdir/upstream/$confile ]]; then
        echo -e "${yellow}# configuration file $workdir/upstream/$confile:${plain}"
        echo
        cat $workdir/upstream/$confile
        echo
    fi
}

remove_upstream() {
    confile=$1
    if [[ $confile == '' ]]; then
        echo -e "\n${yellow}选择负载均衡配置:${plain}\n"
        select item in `ls $workdir/upstream`;
        do
            confile=$item
            echo -e "${yellow}负载均衡配置: ${item}${plain}"
            break
        done
    fi
    confirm "确定要删除负载均衡配置-[${confile}]-吗?" "n"
    if [[ $? == 0 ]]; then
        rm -rf $workdir/upstream/$confile
        
        echo -e "${green}已成功删除负载均衡配置-[${confile}]-${plain}"
    else
        echo -e "${red}您取消了删除负载均衡配置-[${confile}]-${plain}"
    fi
}

main() {
    case $1 in
    set)
        set_upstream "${@:2}"
    ;;
    get)
        get_upstream "${@:2}"
    ;;
    remove | del)
        remove_upstream "${@:2}"
    ;;
    * )
        exit 0
    ;;
    esac
}

get_nginx_env
main "$@"