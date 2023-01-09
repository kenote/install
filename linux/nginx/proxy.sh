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

# 映射列表
proxy_list() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  ${_confile} -- 映射列表"
    echo -e "--------------------------------${plain}"
    echo
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`
    echo -e "ID\t类型\t\t名称"
    if [[ ! -d $workdir/proxys/$_siteconf ]]; then
        return 2
    fi
    list=(`ls $workdir/proxys/$_siteconf | grep -E "*.conf"`)
    if [[ ${#list[@]} == 0 ]]; then
        return 2
    fi
    _id=0
    for item in ${list[@]};
    do
        _name=`echo $(get_proxy_info $item name)`
        _type=`echo $(get_proxy_info $item type)`
        _id=`expr $_id + 1`
        echo -e "${_id})\t${_type}\t${_name}"
    done

    echo && read -p "请输入选择 [1-$_id]: " num

    if [[ $num == 'x' ]]; then
        return 1
    elif [[ $num =~ ^[0-9]+$ && $num -le $_id && $num -ge 1 ]]; then
        clear
        proxy_file_opts $_confile "${list[$(expr $num - 1)]}"
    else
        clear
        echo -e "${red}请输入正确的数字 [1-$_id]${plain}"
        proxy_list $_confile
    fi
}

get_proxy_info() {
    _confile=$1
    _tag=$2
    _name=`echo $_confile | awk -F "[:::]+" '{ print $2}' | sed -E 's/.conf$//'`
    _type=`echo $_confile | awk -F "[:::]+" '{ print $1}'`
    case $_tag in
    name)
        echo $_name
    ;;
    type)
        echo $_type
    ;;
    *)
        echo $_confile
    ;;
    esac
}

proxy_file_opts() {
    _confile=$1
    _proxyfile=$2
    echo -e "${green}----------------------------------------------------------------"
    echo -e "  ${_confile} -- 映射配置 -> ${_proxyfile}"
    echo -e "----------------------------------------------------------------${plain}"
    echo

    echo -e "1).\t配置详情"
    echo -e "2).\t手动编辑"
    echo -e "3).\t删除配置"

    echo && read -p "请输入选择 [1-3]: " num

    case "$num" in
    1)
        clear
        view_proxy_file "${_confile}" "${_proxyfile}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        proxy_file_opts "${_confile}" "${_proxyfile}"
    ;;
    2)
        clear
        edit_proxy_file "${_confile}" "${_proxyfile}"
        clear
        proxy_file_opts "${_confile}" "${_proxyfile}"
    ;;
    3)
        clear
        del_proxy_file "${_confile}" "${_proxyfile}"
        if [[ $? == 1 ]]; then
            clear
            proxy_file_opts "${_confile}" "${_proxyfile}"
            return 1
        fi
        echo
        read  -n1  -p "按任意键继续" key
        clear
        proxy_list $_confile
    ;;
    x)
        clear
        proxy_list $_confile
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [1-3]${plain}"
        proxy_file_opts "${_confile}" "${_proxyfile}"
    ;;
    esac

}

# 查看配置内容
view_proxy_file() {
    _confile=$1
    _proxyfile=$2
    echo -e "${green}----------------------------------------------------------------"
    echo -e "  ${_confile} -- 预览配置 -- ${_proxyfile}"
    echo -e "----------------------------------------------------------------${plain}"
    echo
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`
    if [[ ! -f $workdir/proxys/$_siteconf/$_proxyfile ]]; then
        echo
        echo -e "${yellow}配置文件不存在！${plain}"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        conf_file_opts "${_confile}"
        return 1
    fi
    echo -e "========================================================"
    echo -e "${yellow}# configuration file $workdir/proxys/$_siteconf/$_proxyfile:${plain}"
    echo
    cat $workdir/proxys/$_siteconf/$_proxyfile
    echo
    echo -e "========================================================"
}

# 编辑配置
edit_proxy_file() {
    _confile=$1
    _proxyfile=$2
    echo -e "${green}----------------------------------------------------------------"
    echo -e "  ${_confile} -- 编辑配置 -- ${_proxyfile}"
    echo -e "----------------------------------------------------------------${plain}"
    echo
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`

    vi $workdir/proxys/$_siteconf/$_proxyfile
}

# 删除配置
del_proxy_file() {
    _confile=$1
    _proxyfile=$2
    echo -e "${green}----------------------------------------------------------------"
    echo -e "  ${_confile} -- 删除配置 -- ${_proxyfile}"
    echo -e "----------------------------------------------------------------${plain}"
    echo
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`

    confirm "确定要删除配置文件-[${_proxyfile}]-吗?" "n"
    if [[ $? == 1 ]]; then
        return 1
    fi

    rm -rf $workdir/proxys/$_siteconf/$_proxyfile

    echo
    echo -e "${green}已成功删除配置文件 -- ${_proxyfile}${plain}"
}

set_virtual_env() {
    while read -p "location[/]: " _location
    do
        if [[ $_location == '' ]]; then
            _location="/"
        fi
        break
    done
    while read -p "文件根路径: " _root
    do
        if [[ $_root == '' ]]; then
            echo -e "${yellow}请填写文件根路径！${plain}"
            continue
        fi
        break
    done
    while read -p "默认页面[index.html index.htm]: " _index_page
    do
        if [[ $_index_page == '' ]]; then
            _index_page="index.html index.htm"
        fi
        break
    done
    confirm "是否开启目录索引?" "n"
    if [[ $? == 0 ]]; then
        _autoindex="on"
    fi

    while read -p "下载限速: " _limit_rate
    do
        if [[ $_limit_rate == '' ]]; then
            break
        fi
        if [[ ! $_limit_rate =~ ^[0-9]{1,4}(k|m)$ ]]; then
            echo -e "${yellow}请填写正确的限速大小！${plain}"
            continue
        fi
        break
    done

    if [[ $_limit_rate != '' ]]; then
        while read -p "针对多少大小文件限速: " _limit_rate_after
        do
            if [[ $_limit_rate_after == '' ]]; then
                break
            fi
            if [[ ! $_limit_rate_after =~ ^[0-9]{1,4}(k|m|g)$ ]]; then
                echo -e "${yellow}请填写正确的文件大小！${plain}"
                continue
            fi
            break
        done
    fi
}

# 添加静态目录
add_virtual() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  ${_confile} -- 添加静态目录"
    echo -e "--------------------------------${plain}"
    echo

    while read -p "名称: " _name
    do
        if [[ $_name == '' ]]; then
            echo -e "${yellow}名称不能为空！${plain}"
            continue
        fi
        break
    done
    _proxy_confile="[1]virtual::${_name}.conf"
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`
    set_virtual_env

    echo -e "# $_proxy_confile" > "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "location $_location {" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    root $_root;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    index $_index_page;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    if [[ $_autoindex == 'on' ]]; then
        echo -e "    autoindex on;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    fi
    if [[ $_limit_rate != '' ]]; then
        echo -e "    " >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "    limit_rate $_limit_rate;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        if [[ $_limit_rate_after != '' ]]; then
            echo -e "    limit_rate_after $_limit_rate_after;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        fi
    fi
    echo -e "}" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi
}

set_cache_env() {
    list=(目录 文件)
    select item in ${list[@]};
    do
        if [[ $item == '' ]]; then
            return 1
        fi
        _type=$item
        break
    done

    while read -p "$_type: " _files
    do
        if [[ $_files == '' ]]; then
            echo -e "${yellow}请填写需要缓存的$_type${plain}"
            continue
        fi
        break
    done
    while read -p "文件根路径: " _root
    do
        break
    done
    while read -p "缓存时间: " _expires
    do
        break
    done
    if [[ $_type == '目录' ]]; then
        _location="~ ^/($_files)/"
    else
        _location="~ .*\.($_files)?$"
    fi
    # 防盗链
    while read -p "防盗链设置: " _valid_domain
    do
        break
    done
}

# 添加文件缓存
add_cache() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  ${_confile} -- 添加文件缓存"
    echo -e "--------------------------------${plain}"
    echo

    while read -p "名称: " _name
    do
        if [[ $_name == '' ]]; then
            echo -e "${yellow}名称不能为空！${plain}"
            continue
        fi
        break
    done
    _proxy_confile="[2]cache::${_name}.conf"
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`
    set_cache_env
    if [[ $? == 1 ]]; then
        clear
        show_menu ${_confile}
        return 1
    fi

    echo -e "# $_proxy_confile" > "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "location $_location {" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    if [[ $_root != '' ]]; then
        echo -e "    root $_root;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    fi
    if [[ $_expires != '' ]]; then
        echo -e "    expires $_expires;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    fi
    if [[ $_valid_domain != '' ]]; then
        echo -e "    " >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "    valid_referers none blocked $_valid_domain;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "    if ($invalid_referer) {" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "        #rewrite ^/ http://www.youdomain.com/404.jpg;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "        return 403;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "        break;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "    }" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
        echo -e "    access_log off;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    fi
    echo -e "}" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi
}

add_reverse_env() {
    while read -p "location[/]: " _location
    do
        if [[ $_location == '' ]]; then
            _location="/"
        fi
        break
    done
    while read -p "代理URL: " _url 
    do
        if [[ $_url == '' ]]; then
            echo -e "${yellow}代理URL不能为空！${plain}"
            continue
        fi
        host_flag=`echo "$_url" | gawk '/^(http|https):\/\/[^/s]*/{print $0}'`
        if [[ ! -n "${host_flag}" ]]; then
            echo -e "${red}代理URL格式错误，格式：[(http?s)://host:port]！${plain}"
            continue
        fi
        break
    done
}

# 添加反向代理
add_reverse() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  ${_confile} -- 添加反向代理"
    echo -e "--------------------------------${plain}"
    echo

    while read -p "名称: " _name
    do
        if [[ $_name == '' ]]; then
            echo -e "${yellow}名称不能为空！${plain}"
            continue
        fi
        break
    done
    _proxy_confile="[3]reverse::${_name}.conf"
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`
    add_reverse_env

    echo -e "# $_proxy_confile" > "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "location $_location {" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_pass $_url;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_redirect off;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_set_header X-Real-IP \$remote_addr;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_set_header Host \$http_host;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_set_header X-NginX-Proxy ture;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_http_version 1.1;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_set_header Upgrade \$http_upgrade;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    proxy_set_header Connection \"upgrade\";" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "}" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi
}

add_fastcgi_env() {
    while read -p "Fastcgi[127.0.0.1:9000]: " _fastcgi
    do
        if [[ $_fastcgi == '' ]]; then
            _fastcgi="127.0.0.1:9000"
        fi
        break
    done
    while read -p "文件后缀[php]: " _suffix
    do
        if [[ $_suffix == '' ]]; then
            _suffix="php"
        fi
        break
    done
    while read -p "文件根路径: " _root
    do
        break
    done
    while read -p "索引文件: " _index_page
    do
        break
    done
}

# 添加Fastcgi
add_fastcgi() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  ${_confile} -- 添加Fastcgi"
    echo -e "--------------------------------${plain}"
    echo

    while read -p "名称: " _name
    do
        if [[ $_name == '' ]]; then
            echo -e "${yellow}名称不能为空！${plain}"
            continue
        fi
        break
    done
    _proxy_confile="[4]fastcgi::${_name}.conf"
    _siteconf=`echo $_confile | sed -E 's/.conf$//'`
    add_fastcgi_env

    echo -e "# $_proxy_confile" > "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "location ~ \.${_suffix}$ {" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    if [[ $_root != '' ]]; then
        echo -e "    root $_root;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    fi
    echo -e "    fastcgi_pass $_fastcgi;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    if [[ $_index_page != '' ]]; then
        echo -e "    fastcgi_index $_index_page;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    fi
    echo -e "    fastcgi_param SCRIPT_FILENAME /scripts\$fastcgi_script_name;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "    include fastcgi_params;" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"
    echo -e "}" >>  "$workdir/proxys/$_siteconf/$_proxy_confile"

    confirm "是否要重启 Nginx?" "n"
    if [[ $? == 0 ]]; then
        systemctl restart nginx
    else
        echo -e "要生效配置，请重启 Nginx！"
    fi

}

show_menu() {
    _confile=$1
    echo -e "${green}--------------------------------"
    echo -e "  ${_confile} -- 映射管理"
    echo -e "--------------------------------${plain}"
    echo

    echo -e "1).\t映射列表"
    echo -e "2).\t添加静态目录"
    echo -e "3).\t添加文件缓存"
    echo -e "4).\t添加反向代理"
    echo -e "5).\t添加Fastcgi"

    echo && read -p "请输入选择 [1-5]: " num

    case "$num" in
    1)
        clear
        proxy_list "$_confile"
        if [[ $? == 1 ]]; then
            clear
            show_menu ${_confile}
            return 1
        fi
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu ${_confile}
    ;;
    2)
        clear
        add_virtual "$_confile"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu ${_confile}
    ;;
    3)
        clear
        add_cache "$_confile"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu ${_confile}
    ;;
    4)
        clear
        add_reverse "$_confile"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu ${_confile}
    ;;
    5)
        clear
        add_fastcgi "$_confile"
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu ${_confile}
    ;;
    x)
        if [[ $CURRENT_DIR == '/root/.scripts/nginx' ]]; then
            run_script server.sh
        else
            exit 0
        fi
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [1-5]${plain}"
        show_menu ${_confile}
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