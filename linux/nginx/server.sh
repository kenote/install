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
    REPOSITORY_RAW_URL="${REPOSITORY_RAW_ROOT}/main/linux/nginx"
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

# 配置文件列表
conf_list() {
    list=(default.conf `ls $confdir | grep -E "*.conf" | grep -v -e "default.conf"`)
    echo -e "${green}--------------------------------"
    echo -e "  选择站点配置"
    echo -e "--------------------------------${plain}"
    echo
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
        conf_file_opts "${list[$(expr $num - 1)]}"
    else
        clear
        echo -e "${red}请输入正确的数字 [1-$(expr $_id - 1)]${plain}"
        conf_list
    fi
}

# 参数设置
set_setting() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  站点配置 -- ${_confile} -> 参数设置"
    echo -e "--------------------------------${plain}"
    echo
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`

    vi $workdir/proxys/$_siteconf/[0]setting::default.conf
}

# 安装证书
install_cert() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  站点配置 -- ${_confile} -> 申请证书"
    echo -e "--------------------------------${plain}"
    echo

    _servername=`echo $(get_item_val $confdir/$_confile server_name)`
    _ports=(`cat "$confdir/$_confile" | sed -E 's/^\s+//g' | grep "^listen" | grep -v -e "[::]" | sed -E 's/(listen|default_server|ssl|http2|;|\s)//g'`)
    
    
    
    _parameter="--port ${_ports[0]} --confile $_confile"

    while read -p "域名[$_servername]: " _domain
    do
        if [[ $_domain == '' ]]; then
            _domain=$_servername
        fi
        break
    done

    domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
    if [[ ! -n "${domain_flag}" ]]; then
        echo -e "${red}域名格式有误, 无法为其申请SSL证书！${plain}"
        return 1
    fi
    
    confirm "是否开启http2?" "n"
    if [[ $? == 0 ]]; then
        _parameter="--http2 $_parameter"
    else
        _parameter="--ssl $_parameter"
    fi

    if [[ ${_ports[0]} == '80' ]]; then
        confirm "是否强制https?" "n"
        if [[ $? == 0 ]]; then
            _parameter="--force-https $_parameter"
        fi
    fi

    confirm "是否开启调试?" "n"
    if [[ $? == 0 ]]; then
        _debug="--debug"
    fi

    _parameter="--domain $_domain $_parameter"

    # 申请证书
    run_script ssl.sh apply_cert --domain $_domain $_debug
    # 创建证书目录
    mkdir -p $workdir/ssl/$_domain
    # 更换配置
    set_conf_file $_parameter
    sleep 5
    # 安装证书
    run_script ssl.sh install_cert --domain $_domain --target $workdir/ssl/$_domain

}

set_conf_file() {
    _domain=""
    _port=""
    _ssl=""
    _http2=""
    _forcehttps=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --domain | -d)
            _domain=$2
            if [[ $_domain == '' ]]; then
                _domain="_"
            fi
            domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
            if [[ ! -n "${domain_flag}" && ! $_domain =~ (\_|localhost) ]]; then
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
            _forcehttps="on"
            _ssl="ssl"
        ;;
        --confile)
            _confile=$2
            if [[ $_confile == '' ]]; then
                echo -e "${red}缺少配置及文件！${plain}"
                return 1
            fi
            shift
        ;;
        *)
            echo -e "${red}Unknown parameter : $1${plain}"
            return 1
            shift
        ;;
        esac
        shift 1
    done

    if [[ $_domain == '_' ]]; then
        _default_listen="$_port default_server"
    else
        _default_listen=$_port
    fi

    if [[ $_ssl = 'ssl' ]]; then
        if [[ $_port == '80' ]]; then
            _listen="443 $_ssl $_http2"
        else
            _listen="$_port $_ssl $_http2"
        fi
    else
        _listen=$_default_listen
    fi
    site_name=`echo $_confile | sed 's/\.conf$//'`
    echo -e "" > "$confdir/${_confile}"
    if [[ $_forcehttps == 'on' ]]; then
        echo -e "server {" >> "$confdir/${_confile}"
        echo -e "    listen ${_default_listen};" >> "$confdir/${_confile}"
        echo -e "    listen [::]:${_default_listen};" >> "$confdir/${_confile}"
        echo -e "    server_name ${_domain};" >> "$confdir/${_confile}"
        echo -e "    " >> "$confdir/${_confile}"
        echo -e "    return  301 https://\$host\$request_uri;" >> "$confdir/${_confile}"
        echo -e "}" >> "$confdir/${_confile}"
        echo -e "" >> "$confdir/${_confile}"
    fi

    echo -e "server {" >> "$confdir/${_confile}"
    echo -e "    listen ${_listen};" >> "$confdir/${_confile}"
    echo -e "    listen [::]:${_listen};" >> "$confdir/${_confile}"
    echo -e "    server_name ${_domain};" >> "$confdir/${_confile}"
    if [[ $_ssl == 'ssl' ]]; then
        echo -e "    " >> "$confdir/${_confile}"
        echo -e "    ssl_certificate $workdir/ssl/$_domain/cert.crt;" >> "$confdir/${_confile}"
        echo -e "    ssl_certificate_key $workdir/ssl/$_domain/private.key;" >> "$confdir/${_confile}"
        echo -e "    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;" >> "$confdir/${_confile}"
        echo -e "    ssl_prefer_server_ciphers on;" >> "$confdir/${_confile}"
        echo -e "    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;" >> "$confdir/${_confile}"
        echo -e "    ssl_session_cache shared:SSL:5m;" >> "$confdir/${_confile}"
        echo -e "    ssl_session_timeout 5m;" >> "$confdir/${_confile}"
    fi
    echo -e "    " >> "$confdir/${_confile}"
    echo -e "    # 反向代理/Fastcgi/目录映射/文件缓存/参数配置" >> "$confdir/${_confile}"
    echo -e "    include ${workdir}/proxys/${site_name}/*.conf;" >> "$confdir/${_confile}"
    echo -e "    " >> "$confdir/${_confile}"
    echo -e "    # 日志" >> "$confdir/${_confile}"
    echo -e "    access_log  ${workdir}/logs/${site_name}/access.log;" >> "$confdir/${_confile}"
    echo -e "    error_log  ${workdir}/logs/${site_name}/error.log;" >> "$confdir/${_confile}"
    echo -e "    " >> "$confdir/${_confile}"
    echo -e "}" >> "$confdir/${_confile}"

    mkdir -p "$workdir/proxys/${site_name}"
    mkdir -p "$workdir/logs/${site_name}"
}

# 配置文件
conf_file_opts() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  站点配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    echo -e "1).\t配置详情"
    echo -e "2).\t查看日志"
    echo -e "3).\t映射管理"
    echo -e "4).\tSSL证书"
    echo -e "5).\t手动编辑"
    echo -e "6).\t删除配置"
    echo -e "7).\t参数设置"

    echo && read -p "请输入选择 [1-7]: " num

    case "$num" in
    1)
        clear
        view_conf_file "${_confile}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        conf_file_opts "${_confile}"
    ;;
    2)
        clear
        view_logs "${_confile}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        conf_file_opts "${_confile}"
    ;;
    3)
        clear
        run_script proxy.sh "${_confile}"
    ;;
    4)
        clear
        install_cert "${_confile}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        conf_file_opts "${_confile}"
    ;;
    5)
        clear
        edit_conf_file "${_confile}"
        clear
        conf_file_opts "${_confile}"
    ;;
    6)
        clear
        del_conf_file "${_confile}"
        if [[ $? == 1 ]]; then
            clear
            conf_file_opts "${_confile}"
            return 1
        fi
        echo
        read  -n1  -p "按任意键继续" key
        clear
        conf_list
    ;;
    7)
        clear
        set_setting  "${_confile}"
        clear
        conf_file_opts "${_confile}"
    ;;
    x)
        clear
        conf_list
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [1-7]${plain}"
        conf_file_opts "${_confile}"
    ;;
    esac

}

# 查看配置内容
view_conf_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  预览配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo
    if [[ ! -f $confdir/$_confile ]]; then
        echo
        echo -e "${yellow}配置文件不存在！${plain}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        conf_file_opts "${_confile}"
        return 1
    fi
    echo -e "========================================================"
    echo -e "${yellow}# configuration file $confdir/$_confile:${plain}"
    echo
    cat $confdir/$_confile
    echo
    site_name=`echo $_confile | sed 's/\.conf$//'`
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

# 手动编辑配置
edit_conf_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  编辑配置 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    vi $confdir/$_confile
}

# 删除配置
del_conf_file() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  删除配置文件 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    confirm "确定要删除配置文件-[${_confile}]-吗?" "n"
    if [[ $? == 1 ]]; then
        return 1
    fi

    rm -rf $confdir/$_confile
    site_name=`echo $_confile | sed 's/\.conf$//'`
    if [[ -d $workdir/proxys/$site_name ]]; then
        rm -rf $workdir/proxys/$site_name
    fi

    echo
    echo -e "${green}已成功删除配置文件 -- ${_confile}${plain}"
}

set_base_conf() {

    while read -p "端口[80]: " _port
    do
        if [[ $_port == '' ]]; then
            _port=80
        fi
        if [[ ! $_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}端口格式错误！${plain}"
            continue
        fi
        break
    done

    while read -p "域名[_]: " _domain
    do
        if [[ $_domain == '' ]]; then
            _domain="_"
        fi
        domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
        if [[ ! -n "${domain_flag}" && $_domain != '_' ]]; then
            echo -e "${red}域名格式有误！${plain}"
            continue
        fi
        _eprot=`[[ ! $_port =~ ^(80|443)$ ]] && echo "::$_port"`
        site_name=`[[ $_domain == '_' ]] && echo "default$_eprot" || echo "$_domain$_eprot"`
        if [ -f "$confdir/${site_name}.conf" ]; then
            echo -e "${red}检测到有相同配置！${plain}"
            continue
        fi
        echo -e "$site_name"
        break
    done
}

# 添加配置文件
add_conf() {
    echo -e "${green}--------------------------------"
    echo -e "  添加配置文件"
    echo -e "--------------------------------${plain}"
    echo

    set_base_conf
    listen_port="$_port"
    if [[ $_domain == '_' ]]; then
        listen_port="$_port default_server"
    fi

    set_conf_file --domain $_domain --port $_port --confile ${site_name}.conf

    confirm "是否创建站点根目录?" "n"
    if [[ $? == 0 ]]; then
        mkdir -p $workdir/wwwroot/${site_name}
        wget --no-check-certificate -qO $workdir/wwwroot/${site_name}/index.html $REPOSITORY_RAW_URL/html/index.html
        _proxy_confile="[1]virtual::default.conf"
        echo -e "# $_proxy_confile" > $workdir/proxys/${site_name}/$_proxy_confile
        echo -e "location / {" >> $workdir/proxys/${site_name}/$_proxy_confile
        echo -e "    root $workdir/wwwroot/${site_name};" >> $workdir/proxys/${site_name}/$_proxy_confile
        echo -e "    index index.html index.htm;" >> $workdir/proxys/${site_name}/$_proxy_confile
        echo -e "}" >> $workdir/proxys/${site_name}/$_proxy_confile
    fi

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi
}

# ssl证书
ssl_cert() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  SSL证书 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    echo -e "1).\t配置详情"
}

# 获取单元值
get_item_val() {
    _file=$1
    _name=$2
    _arr=(`cat "$_file" | sed -E 's/^\s+//g' | grep "^$_name" | sed 's/\;//'`)
    echo "${_arr[@]:1}"
    # echo `cat "$_file" | sed -E 's/^\s+//g' | grep "^$_name" | awk -F "[: ]+" '{ print $2}' | sed 's/\;//'`
}

# 查看日志
view_logs() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  查看日志 -- ${_confile}"
    echo -e "--------------------------------${plain}"
    echo

    _access_log=`cat "$confdir/$_confile" | sed -E 's/^\s+//g' | grep "^access_log" | awk -F "[: ]+" '{ print $2}' | sed 's/\;//'`
    _error_log=`cat "$confdir/$_confile" | sed -E 's/^\s+//g' | grep "^error_log" | awk -F "[: ]+" '{ print $2}' | sed 's/\;//'`

    _id=0
    logs=(~)
    if [[ $_access_log != '' ]]; then
        _id=`expr $_id + 1`
        logs[$_id]="access_log"
        echo -e "$_id).\taccess_log"
    fi
    if [[ $_error_log != '' ]]; then
        _id=`expr $_id + 1`
        logs[$_id]="error_log"
        echo -e "$_id).\terror_log"
    fi
    if [[ $_id == 0 ]]; then
        echo
        echo -e "${yellow}未配置日志文件！${plain}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        conf_file_opts "${_confile}"
        return 1
    fi

    echo && read -p "请输入选择 [1-$_id]: " num

    if [[ $num == 'x' ]]; then
        clear
        conf_file_opts "${_confile}"
    elif [[ $num =~ ^[0-9]+$ && $num -le $_id && $num -ge 1 ]]; then
        _vals=(`echo $(get_item_val $confdir/$_confile ${logs[$num]})`)
        _logfile=${_vals[0]}
        echo -e "${logs[$num]} -- $_logfile"
        if [ ! -f $_logfile ]; then
            echo "" > $_logfile
        fi
        clear
        echo -e "========================================================"
        echo -e "${yellow}# log file $_logfile${plain}"
        echo
        cat $_logfile
        echo
        echo
        echo -e "========================================================"
        echo -e ""
        read  -n1  -p "按任意键继续" key
        clear
        view_logs "${_confile}"
    else
        clear
        echo -e "${red}请输入正确的数字 [1-$_id]${plain}"
        view_logs "${_confile}"
    fi
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}管理站点${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 站点配置
  ${green} 2${plain}. 添加配置
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
        conf_list
        if [[ $? == 1 ]]; then
            clear
            show_menu
        fi
    ;;
    2)
        clear
        add_conf
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
show_menu