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
                exit 1
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