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
    _domain=""
    _port=80
    _ssl=""
    _http2=""
    _certfile=""
    _keyfile=""
    _forcehttps=""
    _yes=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --domain | -d)
            _domain=$2
            if [[ $_domain == '' ]]; then
                echo -e "${red}缺少域名！${plain}"
                return 1
            fi
            if [[ $_domain =~ (\@|default) ]]; then
                _domain=default
            fi
            domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
            if [[ ! -n "${domain_flag}" && ! $_domain =~ (\@|default) ]]; then
                echo -e "${red}域名格式有误！${plain}"
                return 1
            fi
            shift
        ;;
        --port | -p)
            _port=$2
            if [[ $_port == '' ]]; then
                _port=80
            fi
            if [[ ! $_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
                echo -e "${red}端口号格式错误！${plain}"
                return 1
            fi
            if [[ $_port == 443 ]]; then
                _ssl="ssl"
            fi
            shift
        ;;
        --ssl)
            _ssl="ssl"
        ;;
        --http2)
            _http2="http2"
            _ssl="ssl"
        ;;
        --force-https | -f)
            _forcehttps="forcehttps"
            _ssl="ssl"
        ;;
        --yes | -y)
            _yes="yes"
        ;;
        --cert-file)
            _certfile=$2
            if [[ ! -f $2 && $2 != '' ]]; then
                echo -e "${red}所选证书文件不存在！${plain}"
                return 1
            fi
            shift
        ;;
        --key-file)
            _keyfile=$2
            if [[ ! -f $2 && $2 != '' ]]; then
                echo -e "${red}所选私钥文件不存在！${plain}"
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
    if [[ $_domain == '' ]]; then
        ssl_tag="否"
        http2_tag="否"
        forcehttps_tag="否"
        # _domain
        while read -p "绑定域名: " _domain;
        do
            if [[ $_domain == '' ]]; then
                echo -e "${red}请填写绑定域名！${plain}"
                continue
            fi
            if [[ $_domain =~ (\@|default) ]]; then
                _domain=default
            fi
            domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
            if [[ ! -n "${domain_flag}" && ! $_domain =~ (\@|default) ]]; then
                echo -e "${red}域名格式有误！${plain}"
                continue
            fi
            echo -e "${yellow}绑定域名: ${_domain}${plain}"
            break
        done
        # _port
        while read -p "绑定端口[80]: " _port;
        do
            if [[ $_port == '' ]]; then
                _port=80
            fi
            if [[ ! $_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
                echo -e "${red}端口号格式错误！${plain}"
                continue
            fi
            if [[ $_port == 443 ]]; then
                _ssl="ssl"
                ssl_tag="是"
            fi
            echo -e "${yellow}绑定端口: ${_port}${plain}"
            break
        done
        # _ssl
        if [[ $_ssl == '' && $_port != 80 ]]; then
            read -p "是否启用SSL?[y/N]": ssl_confirm;
            if [[ x"${ssl_confirm}" == x"y" || x"${ssl_confirm}" == x"Y" ]]; then
                _ssl='ssl'
                ssl_tag="是"
            fi
        fi
        echo -e "${yellow}是否启用SSL: ${ssl_tag}${plain}"
        # _http2
        if [[ $_http2 == '' && $_ssl == 'ssl' ]]; then
            read -p "是否启用HTTP2?[y/N]": http2_confirm;
            if [[ x"${http2_confirm}" == x"y" || x"${http2_confirm}" == x"Y" ]]; then
                _http2='http2'
                http2_tag="是"
            fi
        fi
        echo -e "${yellow}是否启用HTTP2: ${http2_tag}${plain}"
        # _forcehttps
        if [[ $_forcehttps == '' && $_ssl == 'ssl' ]]; then
            read -p "是否强行跳转HTTPS?[y/N]": forcehttps_confirm;
            if [[ x"${forcehttps_confirm}" == x"y" || x"${forcehttps_confirm}" == x"Y" ]]; then
                _forcehttps='forcehttps'
                forcehttps_tag="是"
            fi
        fi
        echo -e "${yellow}是否强行跳转HTTPS: ${http2_tag}${plain}"
    else
        if [[ $_port == 80 ]]; then
            if [[ $_ssl == 'ssl' ]]; then
                _port=443
            else
                _port=80
            fi
        fi
    fi
}

set_server() {
    set_server_env "$@"
    if [[ $? == 0 ]]; then
        
        _listen=($_port $_ssl $_http2)
        if [[ $_domain == 'default' ]]; then
            _domain_name="_"
        else
            _domain_name=$_domain
        fi
        if [[ "$_port" =~ ^(80|443)$ ]]; then 
            _site_name="${_domain}"
        else
            _site_name="${_port}::${_domain}"
        fi
        if [[ $_certfile ]]; then
            _ssl_certfile=$_certfile
        else
            _ssl_certfile="$ssldir/${_site_name}/cert.crt"
        fi
        if [[ $_keyfile ]]; then
            _ssl_keyfile=$_keyfile
        else
            _ssl_keyfile="$ssldir/${_site_name}/private.key"
        fi
        if [[ $_yes == 'yes' ]]; then
            echo -e "${yellow}写入站点配置-[${_site_name}]-开始...${plain}"
        elif [[ -f $confdir/${_site_name}.conf ]]; then
            read -p "站点配置已存在，是否替换?[y/N]": save_confirm;
            if [[ x"${save_confirm}" == x"y" || x"${save_confirm}" == x"Y" ]]; then
                echo -e "${yellow}替换站点配置-[${_site_name}]-开始...${plain}"
            else
                return 1
            fi
        fi
        echo -e "
$(
    if [[ $_port = 443 ]]; then

        echo -e "server {
    listen 80;
    listen [::]:80;
    server_name ${_domain_name};
$(
    if [[ $_forcehttps = 'forcehttps' ]]; then
        echo -e "
    return  301 https://\$host\$request_uri;
        "
    else
        echo -e "
    # 引入反向代理配置
    include /mnt/nginx-data/proxys/${_site_name}/*.conf;

    # 日志
    access_log  /mnt/nginx-data/logs/${_site_name}/access.log;
    error_log   /mnt/nginx-data/logs/${_site_name}/error.log;
        "
    fi
)
}

        "
    fi
)
server {
    listen ${_listen[*]};
    listen [::]:${_listen[*]};
    server_name ${_domain_name};
$(
    if [[ $_ssl == 'ssl' ]]; then
        echo -e "
    ssl_certificate ${_ssl_certfile};
    ssl_certificate_key ${_ssl_keyfile};
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
    ssl_prefer_server_ciphers on;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:5m;
    ssl_session_timeout 5m;
        "
    fi
)
    # 引入反向代理配置
    include $workdir/proxys/${_site_name}/*.conf;

    # 日志
    access_log  $workdir/logs/${_site_name}/access.log;
    error_log   $workdir/logs/${_site_name}/error.log;
}
        " > $confdir/${_site_name}.conf
        mkdir -p "$workdir/proxys/${_site_name}"
        mkdir -p "$workdir/logs/${_site_name}"
        echo -e "${green}写入站点配置-[${_site_name}]-完成${plain}"
    else
        exit 0
    fi
}

get_server() {
    confile=$1
    if [[ $confile == '' ]]; then
        echo -e "\n${yellow}选择站点配置:${plain}\n"
        select item in `ls $confdir`;
        do
            # confile=`echo $item | sed 's/\.conf$//'`
            confile=$item
            echo -e "${yellow}站点配置: ${item}${plain}"
            break
        done
    fi
    clear
    echo -e "========================================================"
    echo -e "${yellow}# configuration file $confdir/$confile:${plain}"
    echo
    cat $confdir/$confile
    echo
    site_name=`echo $confile | sed 's/\.conf$//'`
    if [[ -d $workdir/proxys/$site_name ]]; then
        for file in `ls $workdir/proxys/$site_name`;
        do
            echo -e "${yellow}# configuration file $workdir/proxys/$site_name/$file:${plain}"
            cat $workdir/proxys/$site_name/$file
            echo
        done
    fi
    echo -e "========================================================"
}

remove_server() {
    confile=$1
    if [[ $confile == '' ]]; then
        echo -e "\n${yellow}选择站点配置:${plain}\n"
        select item in `ls $confdir`;
        do
            # confile=`echo $item | sed 's/\.conf$//'`
            confile=$item
            echo -e "${yellow}站点配置: ${item}${plain}"
            break
        done
    fi
    confirm "确定要删除站点配置-[${confile}]-吗?" "n"
    if [[ $? == 0 ]]; then
        rm -rf $confdir/$confile
        site_name=`echo $confile | sed 's/\.conf$//'`
        echo -e "$workdir/proxys/$site_name"
        if [[ -d $workdir/proxys/$site_name ]]; then
            rm -rf $workdir/proxys/$site_name
        fi
        echo -e "${green}已成功删除站点配置-[${confile}]-${plain}"
    else
        echo -e "${red}您取消了删除站点配置-[${confile}]-${plain}"
        return 1
    fi
}

get_proxy_list() {
    _domain=$1
    list=(代理列表 添加代理 返回上级)
    type=$2
    if [[ $type == '' ]]; then
        echo -e "${yellow}--站点[$_domain]-反向代理${plain}"
        select item in ${list[@]};
        do
            type=$item
            break
        done
    fi
    case $type in
    代理列表)
        if [[ -d $workdir/proxys/$_domain ]]; then
            list=`ls $workdir/proxys/$_domain`
            if [[ $list == '' ]]; then
                echo -e "${yellow}没有代理配置${plain}"
                sleep 1
                clear
                get_proxy_list $_domain
                return 1
            fi
            proxy_file=$3
            if [[ $proxy_file == '' ]]; then
                clear
                echo -e "\n${yellow}选择代理配置: ${plain}\n"
                select item in `ls $workdir/proxys/$_domain` 返回上级;
                do
                    if [[ $item == '返回上级' ]]; then
                        clear
                        get_proxy_list $_domain
                        return 1
                    fi
                    proxy_file=$item
                    break
                done
            fi
            clear
            echo -e "${yellow}--站点[$_domain]-代理[$proxy_file]--${plain}"
            list=(查看代理配置 删除代理配置 返回上级)
            opt=""
            select item in ${list[@]};
            do
                opt=$item
                break
            done
            case $opt in
            查看代理配置)
                clear
                run_script http_proxy.sh get --domain $_domain --confile $workdir/proxys/$_domain/$proxy_file
                sleep 3
                read  -n1  -p "按任意键继续" key
                clear
                get_proxy_list $domain "代理列表" $workdir/proxys/$_domain/$proxy_file
            ;;
            删除代理配置)
                clear
                run_script http_proxy.sh del --domain $_domain --confile $workdir/proxys/$_domain/$proxy_file
                if [[ $? == 0 ]]; then
                    restart "是否现在重启"
                    sleep 3
                fi
                clear
                get_proxy_list $domain "代理列表"
            ;;
            返回上级)
                clear
                get_proxy_list $domain
            ;;
            esac

        else
            echo -e "${yellow}没有代理配置${plain}"
            sleep 1
            clear
            get_proxy_list $domain
        fi
    ;;
    添加代理)
        echo -e "${yellow}-[$_domain]-反向代理${plain}"
        run_script http_proxy.sh set --confile ${domain}.conf --inquir
        if [[ $? == 0 ]]; then
            restart "是否现在重启"
            sleep 3
        fi
        clear
        get_proxy_list $domain
    ;;
    返回上级)
        clear
        server_opts ${domain}.conf
    ;;
    esac
    
}

server_opts() {
    confile=$1
    type=""
    list=(查看配置 删除配置 反向代理 SSL证书 返回上级)
    clear
    echo
    echo -e "${yellow}--站点[${confile}]--${plain}"
    echo
    select item in ${list[@]};
    do
        type=$item
        break
    done
    case $type in
    查看配置)
        clear
        get_server $confile
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        server_opts $confile
    ;;
    删除配置)
        clear
        remove_server $confile
        if [[ $? == 0 ]]; then
            restart "是否现在重启"
            sleep 3
        fi
        clear
        show_menu 1
    ;;
    反向代理)
        domain=`echo $confile | sed 's/\.conf$//'`
        clear
        get_proxy_list $domain
    ;;
    SSL证书)
        domain=`echo $confile | sed 's/\.conf$//'`
        confirm "确定要为-[$domain]-申请SSL证书吗?" "n"
        if [[ $? == 0 ]]; then
            # 申请证书
            echo -e "${yellow}申请SSL证书...${plain}"
            run_script ssl.sh apply_cert --domain $domain
            # 安装证书
            echo -e "${yellow}安装SSL证书...${plain}"
            mkdir -p $ssldir/$domain
            run_script ssl.sh install_cert --domain $domain --target $ssldir
            # 更换配置
            echo -e "${yellow}更新-[nginx]-配置...${plain}"
            set_server --domain $domain --ssl --force-https --cert-file $ssldir/$domain/cert.crt --key-file $ssldir/$domain/private.key --yes
            # 重启 nginx
            restart "是否现在重启"
        fi
    ;;
    返回上级)
        clear
        show_menu 1
    
    ;;
    esac
}

get_upstream_list() {
    upstream_file=$1
    echo -e "${yellow}--负载均衡[$upstream_file]--${plain}"
    list=(查看负载均衡 删除负载均衡 返回上级)
    opt=""
    select item in ${list[@]};
    do
        opt=$item
        break
    done
    case $opt in
    查看负载均衡)
        clear
        run_script http_upstream.sh get $upstream_file
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        get_upstream_list $upstream_file
    ;;
    删除负载均衡)
        clear
        run_script http_upstream.sh del $upstream_file
        sleep 1
        clear
        show_menu 3
    ;;
    返回上级)
        clear
        show_menu 3
    ;;
    esac
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
    ${green}-- 站点管理 --${plain}

    ${green} 0${plain}. 返回
    ------------------------
    ${green} 1${plain}. 站点列表
    ${green} 2${plain}. 添加站点
    ------------------------
    ${green} 3${plain}. 负载均衡列表
    ${green} 4${plain}. 添加负载均衡
        "
        echo && read -p "请输入选择 [0-4]: " num
        echo
    fi
    case "${num}" in
    0)
        run_script help.sh
    ;;
    1)
        clear
        echo -e "${green}----------------"
        echo -e "  站点列表"
        echo -e "----------------${plain}"
        echo -e "\n${yellow}选择站点:${plain}\n"
        confile=""
        select item in `ls $confdir` 返回上级;
        do
            if [[ $item == '返回上级' ]]; then
                clear
                show_menu
                return 1
            fi
            confile=$item
            break
        done

        if [[ $confile != '' ]]; then
            server_opts $confile
        fi
       
    ;;
    2)
        clear
        echo -e "${green}----------------"
        echo -e "  添加站点"
        echo -e "----------------${plain}"
        set_server
        if [[ $? == 0 ]]; then
            restart "是否现在重启"
            sleep 3
        fi
        clear
        show_menu
    ;;
    3)
        clear
        echo -e "${green}----------------"
        echo -e "  负载均衡列表"
        echo -e "----------------${plain}"
        if [[ -d $workdir/upstream ]]; then
            list=`ls $workdir/upstream`
            if [[ $list == '' ]]; then
                echo -e "${yellow}没有负载均衡${plain}"
                sleep 1
                clear
                show_menu
                return 1
            fi
            # echo -e "\n${yellow}选择负载均衡:${plain}\n"
            upstream_file=""
            select item in `ls $workdir/upstream` 返回上级;
            do
                if [[ $item == '返回上级' ]]; then
                    clear
                    show_menu
                    return 1
                fi
                upstream_file=$item
                break
            done
            clear
            get_upstream_list $upstream_file
        else
            echo -e "${yellow}没有负载均衡${plain}"
            sleep 1
            clear
            show_menu
        fi
    ;;
    4)
        clear
        echo -e "${green}----------------"
        echo -e "  添加负载均衡"
        echo -e "----------------${plain}"
        run_script http_upstream.sh set
        clear
        show_menu
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [0-4]${plain}"
        show_menu
    ;;
    esac
}

restart() {
    confirm "$1-[nginx]-?" "n"
    if [[ $? == 0 ]]; then
        echo -e "-[nginx]-重启中..."
        systemctl restart nginx
        read_nginx_env
    else
        echo -e "-[nginx]-未重启, 记得稍后重启"
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

run_script() {
    file=$1
    if [[ -f $current_dir/$file ]]; then
        sh $current_dir/$file "${@:2}"
    else
        wget -O $current_dir/$file ${urlroot}/main/linux/nginx/$file && chmod +x $current_dir/$file && clear && $current_dir/$file "${@:2}"
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
        clear
        show_menu
    ;;
    esac
}

check_sys
get_nginx_env
main "$@"