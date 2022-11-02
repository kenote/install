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
    mkdir -p $workdir/proxys
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

add_inbounds() {
    confile=$1
    if [[ $confile == '' ]]; then
        echo -e "\n${yellow}选择站点配置:${plain}\n"
        select item in `ls $confdir`;
        do
            confile=$item
            break
        done
    fi
    site_name=`echo $confile | sed 's/\.conf$//'`
    inbounds=`cat $confdir/$confile | grep "/inbounds/\*.inbound;"`;
    mkdir -p $workdir/inbounds
    sleep 5
    if [[ $inbounds == '' ]]; then
        remove_inbounds
        sleep 1
        sed -i "/proxys\/${site_name}\/\*.conf;/a\    include $workdir/inbounds/\*.inbound;" $confdir/$confile
        echo -e "${green}已成功加入 [inbounds] 到站点配置-[${confile}]-${plain}"
    else
        echo -e "${yellow}[inbounds] 已经存在站点配置-[${confile}]-中, 无需添加${plain}"
        return 1
    fi
}

remove_inbounds() {
    for item in `ls $confdir`;
    do
        sed -i "/inbounds\/\*.inbound;/d" $confdir/$item
    done
}

set_proxy_env() {
    _prefix=""
    _location="/"
    _type="lite"
    _root=""
    _index="index.html|index.htm"
    _autoindex=""
    _proxy_pass=""
    _yes=""
    _inquir=""
    _confile=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --location)
            _location=$2
            if [[ $_location == '' ]]; then
                _location='/'
            fi
            shift
        ;;
        --prefix)
            _prefix=$2
            if [[ ! $_prefix =~ ^(=|~|~\*|\^~)$ ]]; then
                echo -e "${red}路径前缀设置错误，请在 [=|~|~*|^~] 中选择${plain}"
                return 1
            fi
            shift
        ;;
        --type)
            _type=$2
            if [[ $_type == '' ]]; then
                _type='list'
            fi
            if [[ ! $_type =~ ^(virtual|lite|full)$ ]]; then
                echo -e "${red}类型设置错误，请在 [virtual|lite|full] 中选择${plain}"
                return 1
            fi
            shift
        ;;
        --root)
            _root=$2
            if [[ $_type == 'virtual' && $_root == '' ]]; then
                echo -e "${red}主目录物理路径不能为空！${plain}"
                return 1
            fi
            shift
        ;;
        --index)
            _index=$2
            if [[ $_index == '' ]]; then
                _index='index.html|index.htm'
            fi
            shift
        ;;
        --autoindex)
            _autoindex="autoindex"
        ;;
        --proxy_pass)
            _proxy_pass=$2
            if [[ $_type =~ ^(lite|full)$ ]]; then
                if [[ $_proxy_pass == '' ]]; then
                    echo -e "${red}代理主机不能为空！${plain}"
                    return 1
                fi
                host_flag=`echo "$_proxy_pass" | gawk '/^(http|https):\/\/[^/s]*/{print $0}'`
                if [[ ! -n "${host_flag}" ]]; then
                    echo -e "${red}代理主机格式错误，格式：[(http?s)://host:port]！${plain}"
                    return 1
                fi
            fi
            shift
        ;;
        --confile)
            _confile=$2
            if [[ $_confile == '' ]]; then
                echo -e "${red}关联配置文件不能为空！${plain}"
                return 1
            fi
            if [[ ! -f $confdir/$_confile ]]; then
                echo -e "${red}关联配置文件不存在！${plain}"
                return 1
            fi
            shift
        ;;
        --yes | -y)
            _yes="yes"
        ;;
        --inquir | -i)
            _inquir="inquir"
        ;;
        *)
            _err "Unknown parameter : $1"
            return 1
            shift
        ;;
        esac
        shift 1
    done
    if [[ $_inquir == 'inquir' ]]; then
        read -p "绑定路径[默认 /]: " _location;
        if [[ $_location == '' ]]; then
            _location="/"
        fi
        echo -e "${yellow}绑定路径: ${_location}${plain}"
        while read -p "设置路径前缀[可不填]: " _prefix
        do
            if [[ $_prefix != '' ]]; then
                if [[ ! $_prefix =~ ^(=|~|~\*|\^~)$ ]]; then
                    echo -e "${red}路径前缀设置错误，请在 [=|~|~*|^~] 中选择${plain}"
                    continue
                fi
            fi
            echo -e "${yellow}路径前缀: ${_prefix}${plain}"
            break
        done
        list=(virtual lite full)
        echo -e "选择代理类型:"
        select item in ${list[@]};
        do
            _type=$item
            echo -e "${yellow}代理类型: ${item}${plain}"
            break
        done
        if [[ $_type == 'virtual' ]]; then
            while read -p "主目录: " _root;
            do
                if [[ $_root == '' ]]; then
                    echo -e "${red}请填写主目录物理路径！${plain}"
                    continue
                fi
                echo -e "${yellow}主目录: ${_domain}${plain}"
                break
            done
            read -p "索引页面[默认 index.html|index.htm]: " _index;
            if [[ $_index == '' ]]; then
                _index="index.html|index.htm"
            fi
            echo -e "${yellow}索引页面: ${_index}${plain}"
            autoindex_tag="否"
            read -p "是否开启目录索引?[y/N]": autoindex_confirm;
            if [[ x"${autoindex_confirm}" == x"y" || x"${autoindex_confirm}" == x"Y" ]]; then
                _autoindex='autoindex'
                autoindex_tag="是"
            fi
            echo -e "${yellow}是否开启目录索引: ${autoindex_tag}${plain}"
        else
            while read -p "代理主机: " _proxy_pass;
            do
                if [[ $_proxy_pass == '' ]]; then
                    echo -e "${red}请填写代理主机！${plain}"
                    continue
                fi
                host_flag=`echo "$_proxy_pass" | gawk '/^(http|https):\/\/[^/s]*/{print $0}'`
                if [[ ! -n "${host_flag}" ]]; then
                    echo -e "${red}代理主机格式错误，格式：[(http?s)://host:port]！${plain}"
                    continue
                fi
                echo -e "${yellow}代理主机: ${_proxy_pass}${plain}"
                break
            done
        fi
        # 选择关联配置
        if [[ $_confile == '' ]]; then
            echo -e "选择关联配置: $confdir"
            select item in `ls $confdir`;
            do
                _confile=$item
                echo -e "${yellow}关联配置文件: ${item}${plain}"
                break
            done
        fi
    fi
    if [[ $_type == 'virtual' ]]; then
        if [[ $_root == '' ]]; then
            echo -e "${red}缺少参数 --root！${plain}"
            return 1
        fi
    else
        if [[ $_proxy_pass == '' ]]; then
            echo -e "${red}缺少参数 --proxy_pass！${plain}"
            return 1
        fi
    fi
}

set_proxy() {
    set_proxy_env "$@"
    if [[ $? == 0 ]]; then
        _path=($_prefix $_location)
        _index_page=`echo $_index | sed 's/|/ /'`
        site_name=`echo $_confile | sed 's/\.conf$//'`

        if [[ $_location == '/' ]]; then
            proxy_name="@default"
        else
            proxy_name=`echo $_location | sed 's/^\///g' | sed 's/\//::/g'`
        fi
        if [[ $_type != 'virtual' ]]; then
            proxy_pass=`echo $_proxy_pass | sed 's/^\(http\|https\):\/\//::/' | sed 's/\//::/g'`
            proxy_name="$proxy_name$proxy_pass"
        fi
        echo -e "confile: $workdir/proxys/$site_name/$proxy_name.conf"
        echo -e "
location ${_path[*]} {
$(
    if [[ $_type == 'virtual' ]]; then
        echo -e "
    root ${_root};
    index ${_index_page};
    $(
        if [[ $_autoindex == 'autoindex' ]]; then
            echo -e "autoindex on;"
        fi
    )
        "
    elif [[ $_type == 'full' ]]; then
        echo -e "
    proxy_pass ${_proxy_pass};
    proxy_redirect off;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_set_header X-NginX-Proxy ture;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"upgrade\";
        "
    else
        echo -e "
    proxy_pass ${_proxy_pass};
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        "
    fi
)
}
        " > $workdir/proxys/$site_name/$proxy_name.conf
        echo -e "${green}写入代理配置-[$proxy_name.conf]-到-[$site_name]-完成${plain}"
    else
        return 1
    fi
}

get_proxy_env() {
    _confile=""
    _domain=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --domain | -d)
            _domain=$2
            shift
        ;;
        --confile)
            _confile=$2
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
    if [[ $_confile == '' ]]; then
        if [[ $_domain == '' ]]; then
            echo -e "\n${yellow}选择站点配置:${plain}\n"
            select item in `ls $confdir`;
            do
                _domain=`echo $item | sed 's/\.conf$//'`
                echo -e "${yellow}站点配置: ${item}${plain}"
                break
            done
        fi
        if [[ -d $workdir/proxys/$_domain ]]; then
            list=`ls $workdir/proxys/$_domain`
            if [[ $list == '' ]]; then
                echo -e "${yellow}没有代理配置${plain}"
                return 1
            fi
            echo -e "\n${yellow}选择代理配置: ${plain}\n"
            select item in `ls $workdir/proxys/$_domain`;
            do
                echo -e "${yellow}代理配置: ${item}${plain}"
                _confile=$workdir/proxys/$_domain/$item
                break
            done
        else
            echo -e "${yellow}没有代理配置${plain}"
            return 1
        fi
    fi
    if [[ ! -f $_confile ]]; then
        echo -e "${red}配置文件不存在${plain}"
        return 1
    fi
    
}

get_proxy() {
    get_proxy_env "$@"
    if [[ $? == 0 ]]; then
        echo -e "${yellow}# configuration file $_confile:${plain}"
        cat $_confile
    else
        exit 0
    fi
}

remove_proxy() {
    get_proxy_env "$@"
    if [[ $? == 0 ]]; then
        confirm "确定要删除代理配置-[${_confile}]-吗?" "n"
        if [[ $? == 0 ]]; then
            rm -rf $_confile
            echo -e "${green}已成功删除代理配置-[${_confile}]-${plain}"
        else
            echo -e "${red}您取消了删除代理配置-[${_confile}]-${plain}"
        fi
    else
        exit 0
    fi
}

main() {
    case $1 in
    inbounds)
        add_inbounds "${@:2}"
    ;;
    set)
        set_proxy "${@:2}"
    ;;
    get)
        get_proxy "${@:2}"
    ;;
    remove | del)
        remove_proxy "${@:2}"
    ;;
    * )
        exit 0
    ;;
    esac
}

get_nginx_env
main "$@"