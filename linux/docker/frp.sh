#! /bin/bash

current_dir=$(cd $(dirname $0);pwd)
workdir=`cat $HOME/.docker_profile | grep "DOCKER_WORKDIR" |  sed 's/\(.*\)=\(.*\)/\2/g'`
local_ip=`hostname -I | awk -F ' ' '{print $1}'`
network_ip=`wget -qO- ip.p3terx.com | sed -n '1p'`

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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

run_script() {
    file=$1
    filepath=`echo "$current_dir/$file" | sed 's/docker\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        wget -O $filepath ${urlroot}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

deploy_server() {
    project_name="frps"
    if [[ $workdir == '' ]]; then
        run_script help.sh workdir
    fi
    echo
    echo -e "${green}----------------"
    echo -e "  部署 FRPS - 内网穿透服务端"
    echo -e "----------------${plain}"
    echo
    confirm "确定要部署 FRPS 吗?" "n"
    if [[ $? != 0 ]]; then
        return 1
    fi
    if [[ -d $workdir/${project_name} ]]; then
        echo -e "${yellow}发现-[${project_name}]-目录${plain}"
        confirm "是否要覆盖安装?" "n"
        if [[ $? == 0 ]]; then
            cd $workdir/${project_name}
            if [[ -f $workdir/${project_name}/docker-compose.yml ]]; then
                docker-compose down -v
            fi
            cd $workdir
            rm -rf $workdir/${project_name}
        else
            return 1
        fi
    fi
    # 创建目录
    mkdir -p $workdir/${project_name}
    cd $workdir/${project_name}
    # 拉取 docker-compose.yml
    wget -O $workdir/${project_name}/docker-compose.yml ${urlroot}/main/linux/docker/frp/frps.yaml
    # 拉取 frps.ini
    wget -O $workdir/${project_name}/frps.ini ${urlroot}/main/linux/docker/frp/frps.ini
    # 设置变量
    while read -p "监听端口[默认: 7000]: " bind_port
    do
        if [[ $bind_port == '' ]]; then
            bind_port=7000
        fi
        if [[ ! $bind_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}监听端口格式错误！${plain}"
            continue
        fi
        break
    done
    while read -p "管理面板端口[默认: 7500]: " dashboard_port
    do
        if [[ $dashboard_port == '' ]]; then
            dashboard_port=7500
        fi
        if [[ ! $dashboard_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}监听端口格式错误！${plain}"
            continue
        fi
        break
    done
    while read -p "管理面板用户名[默认: admin]: " dashboard_user
    do
        if [[ $dashboard_user == '' ]]; then
            dashboard_user="admin"
        fi
        break
    done
    while read -p "管理面板密码: " dashboard_pwd
    do
        if [[ $dashboard_pwd == '' ]]; then
            echo -e "${red}密码不能为空！${plain}"
            continue
        fi
        break
    done
    token=`openssl rand -base64 32`
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^bind_port")/bind_port = $bind_port/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^dashboard_port")/dashboard_port = $dashboard_port/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^dashboard_user")/dashboard_user = $dashboard_user/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^dashboard_pwd")/dashboard_pwd = $dashboard_pwd/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^token")/token = $token/" $workdir/${project_name}/frps.ini
    # 启动容器
    docker-compose up -d
    echo -e "${green}FRPS 部署完毕${plain}"
    read_server_env
}

set_server_env() {
    project_name="frps"
    echo
    echo -e "${green}----------------"
    echo -e "  设置 FRPS 服务端配置"
    echo -e "----------------${plain}"
    echo
    if [[ ! -f $workdir/${project_name}/frps.ini ]]; then
        echo -e "${red}frps.ini 文件不存在；无法继续操作！${plain}"
        return 1
    fi
    cd $workdir/${project_name}
    # 设置变量
    while read -p "监听端口[默认: 7000]: " bind_port
    do
        if [[ $bind_port == '' ]]; then
            bind_port=7000
        fi
        if [[ ! $bind_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}监听端口格式错误！${plain}"
            continue
        fi
        break
    done
    while read -p "管理面板端口[默认: 7500]: " dashboard_port
    do
        if [[ $dashboard_port == '' ]]; then
            dashboard_port=7500
        fi
        if [[ ! $dashboard_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}监听端口格式错误！${plain}"
            continue
        fi
        break
    done
    while read -p "管理面板用户名[默认: admin]: " dashboard_user
    do
        if [[ $dashboard_user == '' ]]; then
            dashboard_user="admin"
        fi
        break
    done
    while read -p "管理面板密码: " dashboard_pwd
    do
        if [[ $dashboard_pwd == '' ]]; then
            echo -e "${red}密码不能为空！${plain}"
            continue
        fi
        break
    done
    token=`openssl rand -base64 32`
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^bind_port")/bind_port = $bind_port/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^dashboard_port")/dashboard_port = $dashboard_port/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^dashboard_user")/dashboard_user = $dashboard_user/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^dashboard_pwd")/dashboard_pwd = $dashboard_pwd/" $workdir/${project_name}/frps.ini
    sed -i "s/$(cat $workdir/${project_name}/frps.ini | grep -E "^token")/token = $token/" $workdir/${project_name}/frps.ini
    # 启动容器
    docker-compose up -d
    echo -e "${green}FRPS 服务端配置完毕${plain}"
    read_server_env
}

read_server_env() {
    project_name="frps"
    if [[ ! -f $workdir/${project_name}/frps.ini ]]; then
        echo -e "${yellow}FRP 服务端未安装！${plain}"
        return 1
    fi
    bind_port=`cat $workdir/${project_name}/frps.ini | grep -E "^bind_port" | sed 's/ //g' | sed 's/\(.*\)=\(.*\)/\2/g'`
    dashboard_port=`cat $workdir/${project_name}/frps.ini | grep -E "^dashboard_port" | sed 's/ //g' | sed 's/\(.*\)=\(.*\)/\2/g'`
    token=`cat $workdir/${project_name}/frps.ini | grep -E "^token" | sed 's/ //g' | sed 's/\(.*\)=\(.*\=\)/\2/g'`
    echo -e "面板访问 -- https://${network_ip}:${dashboard_port}"
    echo -e "===== 客户端连接 ====="
    echo -e "[common]
server_addr = $network_ip
server_port = $bind_port
token = $token
    "
    echo
    echo -e "===== 执行以下代码; 自动配置 ====="
    echo -e "bash <(curl -Ls ${urlroot}/main/linux/docker/frp.sh) get_server --host $network_ip --port $bind_port --token \"$token\""
    echo
}

get_server_env() {
    _host=""
    _port=""
    _token=""

    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --host)
            _host=$2
            shift
        ;;
        --port)
            _port=$2
            shift
        ;;
        --token)
            _token=$2
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
    frpc_dir=$workdir/frpc
    if [[ $workdir == '' ]]; then
        while reap -p "选择配置文件目录[默认: /etc/frp]: " frpc_dir
        do
            if [[ $frpc_dir == '' ]]; then
                frpc_dir=/etc/frp
            fi
            break
        done
    fi
    cd $frpc_dir
    if [[ ! -f frpc.ini ]]; then
        # 拉取 frpc.ini
        wget -O frpc.ini ${urlroot}/main/linux/docker/frp/frpc.ini
    fi
    sed -i "s/$(cat frpc.ini | grep -E "^server_addr")/server_addr = $_host/" frpc.ini
    sed -i "s/$(cat frpc.ini | grep -E "^server_port")/server_port = $_port/" frpc.ini
    sed -i "s/$(cat frpc.ini | grep -E "^token")/token = $_token/" frpc.ini
    if [[ -f $frpc_dir/docker-compose.yml ]]; then
        docker-compose restart
    fi
}

deploy_client() {
    project_name="frps"
    if [[ $workdir == '' ]]; then
        run_script help.sh workdir
    fi
    echo
    echo -e "${green}----------------"
    echo -e "  部署 FRPC - 内网穿透客户端"
    echo -e "----------------${plain}"
    echo
    confirm "确定要部署 FRPC 吗?" "n"
    if [[ $? != 0 ]]; then
        return 1
    fi
    if [[ -d $workdir/${project_name} ]]; then
        echo -e "${yellow}发现-[${project_name}]-目录${plain}"
        confirm "是否要覆盖安装?" "n"
        if [[ $? == 0 ]]; then
            cd $workdir/${project_name}
            if [[ -f $workdir/${project_name}/docker-compose.yml ]]; then
                docker-compose down -v
            fi
            cd $workdir
            rm -rf $workdir/${project_name}
        else
            return 1
        fi
    fi
    # 创建目录
    mkdir -p $workdir/${project_name}
    cd $workdir/${project_name}
    # 拉取 docker-compose.yml
    wget -O $workdir/${project_name}/docker-compose.yml ${urlroot}/main/linux/docker/frp/frpc.yaml
    # 拉取 frpc.ini
    # wget -O $workdir/${project_name}/frps.ini ${urlroot}/main/linux/docker/frp/frpc.ini
    # 启动容器
    docker-compose up -d
    echo -e "${green}FRPC 部署完毕${plain}"
}

# cat /mnt/docker-data/frpc/frpc.ini | awk -F '=' '/\[[a-zA-Z0-9\_]+\]/{print $1}' | sed -E 's/\[|\]//g' 


# cat /mnt/docker-data/frpc/frpc.ini | awk -F '=' '/\[ssh\]/{f=1;next} /\[*\]/{f=0} f'
add_proxy() {
    if [[ ! -f $workdir/frpc/frpc.ini ]]; then
        echo -e "${yellow}frpc.ini 文件不存在！${plain}"
        return 1
    fi
    proxys=(`cat $workdir/frpc/frpc.ini | awk -F '=' '/\[[a-zA-Z0-9\_]+\]/{print $1}' | sed -E 's/\[|\]//g'`)
    while read -p "设置代理名称：" _name
    do
        if [[ $_name == '' ]]; then
            echo -e "${red}代理名称不能为空${plain}"
            continue
        fi
        is_name=0
        for item in ${proxys[@]};
        do
            if [[ $item == $_name ]]; then
                is_name=1
                break
            fi
        done
        if [[ $is_name == 1 ]]; then
            echo -e "${red}代理名称重名，请另起一个${plain}"
            continue
        fi
        break
    done
    list=(tcp udp)
    echo -e "选择转发类型："
    _type="tcp"
    select item in ${list[@]};
    do
        _type=$item
        break
    done
    if [[ $_type == '' ]]; then
        _type="tcp"
    fi
    while read -p "本地IP：" _local_ip
    do
        if [[ $_local_ip == '' ]]; then
            echo -e "${red}本地 IP不能为空"
            continue
        fi
        break
    done
    while read -p "本地端口：" _local_port
    do
        if [[ $_local_port == '' ]]; then
            echo -e "${red}本地端口不能为空"
            continue
        fi
        break
    done
    while read -p "转发远程端口：" _remote_port
    do
        if [[ $_remote_port == '' ]]; then
            echo -e "${red}转发远程端口不能为空"
            continue
        fi
        break
    done

    echo -e "

[$_name]
type = $_type
local_ip = $_local_ip
local_port = $_local_port
remote_port = $_remote_port
    " >> $workdir/frpc/frpc.ini
    if [[ -f $workdir/frpc/docker-compose.yml ]]; then
        docker-compose restart
    fi
}

proxy_list() {
    if [[ ! -f $workdir/frpc/frpc.ini ]]; then
        echo -e "${yellow}frpc.ini 文件不存在！${plain}"
        return 1
    fi
    proxys=(`cat $workdir/frpc/frpc.ini | awk -F '=' '/\[[a-zA-Z0-9\_]+\]/{print $1}' | sed -E 's/\[|\]//g' | sed 's/common//'`)
    if [[ ${#proxys[@]} == 0 ]]; then
        echo -e "${yellow}还没有创建任何代理${plain}"
        return 1
    fi
    _name=""
    select item in ${proxys[@]};
    do
        _name=$item
        break
    done
    if [[ $_name == '' ]]; then
        return 1
    fi

    list=(查看 删除)
    mode=""
    select item in ${list[@]};
    do
        mode=$item
        break
    done
    case $mode in
    删除)
        confirm "确定要删除-[$_name]-吗?" "n"
        if [[ $? != 0 ]]; then
            list=(`cat $workdir/frpc/frpc.ini | awk -F '=' '/\[[a-zA-Z0-9\_]+\]/{print $1}' | sed -E 's/\[|\]//g'`)
            # 备份配置文件
            mv $workdir/frpc/frpc.ini $workdir/frpc/frpc.ini.bak
            for item in ${list[@]};
            do
                if [[ $item != $_name ]]; then
                    cat >> $workdir/frpc/frpc.ini <<EOF
$(cat $workdir/frpc/frpc.ini.bak | awk -F "=" "/\[$item\]/{f=1;next} /\[*\]/{f=0} f" | sed "1i\[$item]")
EOF
                fi
            done
            if [[ -f $workdir/frpc/docker-compose.yml ]]; then
                docker-compose restart
            fi
        fi
    ;;
    *)
        echo
        echo -e "[$_name]"
        cat $workdir/frpc/frpc.ini | awk -F "=" "/\[$_name\]/{f=1;next} /\[*\]/{f=0} f"
    ;;
    esac
}

run_script() {
    file=$1
    filepath=`echo "$current_dir/$file" | sed 's/docker\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        wget -O $filepath ${urlroot}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

show_menu() {
    echo -e "
  ${green}FRP - 内网穿透工具${plain}

  ${green} 0${plain}. 返回
 ------------------------
  ${green} 1${plain}. 部署服务端
  ${green} 2${plain}. 部署客户端
  ${green} 3${plain}. 查看服务端配置
  ${green} 4${plain}. 设置服务端配置
 ------------------------
  ${green} 5${plain}. 添加客户端转发
  ${green} 6${plain}. 客户端转发列表
 ------------------------
  "
    echo && read -p "请输入选择 [0-6]: " num
    echo
    case "${num}" in
    0  )
        run_script help.sh
    ;;
    1  )
        clear
        deploy_server
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    2  )
        clear
        deploy_client
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    3  )
        clear
        read_server_env
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    4  )
        clear
        set_server_env
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    5  )
        clear
        add_proxy
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    6  )
        clear
        proxy_list
        read  -n1  -p "按任意键继续" key
        clear
        run_script help.sh
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-6]${plain}"
    ;;
    esac
}

main() {
    case $1 in
    get_server)
        get_server_env "${@:2}"
    ;;
    * )
        clear
        show_menu
    ;;
    esac
}

check_sys
main "$@"