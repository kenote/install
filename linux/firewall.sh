#! /bin/bash

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

get_firewall_status() {
    if (is_command firewalld); then
        status=`systemctl status firewalld | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
        echo -e "Firewall Version: $(firewall-cmd --version)"
    else
        echo -e "${yellow}Firewall 未安装, 请先安装${plain}"
    fi
}

read_firewall_env() {
    status=`systemctl status firewalld | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
    echo
}

list_ports() {
    _ports=(`firewall-cmd --zone=public --list-ports`)
    echo -e "===== 防火墙已开放端口 ====="
    for item in ${_ports[@]};
    do
        names=(`echo $item | sed -E 's/\// /g'`)
        echo -e "${names[1]}\t${names[0]}"
    done
}

set_port() {
    _type="tcp"
    echo -e "协议类型："
    list=(tcp udp)
    select item in ${list[@]};
    do
        _type=$item
        break
    done
    while read -p "端口号：" _port
    do
        if [[ $_port == '' ]]; then
            echo -e "${red}端口号不能为空！${plain}"
            continue
        fi
        port_flag=`echo "$_port" | gawk '/^[1-9]{1}[0-9]{1,4}(\-[1-9]{1}[0-9]{1,4})?$/{print $0}'`
        if [[ ! -n "${port_flag}" ]]; then
            echo -e "${red}端口号错误！${plain}"
            continue
        fi
        break
    done
    if [[ $_type == '' ]]; then
        _type="tcp"
    fi
    port_name="$_port/$_type"
}

add_port() {
    set_port
    if [[ $? == 0 ]]; then
        echo -e "${green}写入规则 $(firewall-cmd --zone=public --add-port=${port_name} --permanent)${plain}"
        echo -e "${green}重载配置 $(firewall-cmd --reload)${plain}"
    fi
}

remove_port() {
    _ports=(`firewall-cmd --zone=public --list-ports`)
    port_name=""
    select item in ${_ports[@]};
    do
        port_name=$item
        break
    done
    if [[ $port_name != '' ]]; then
        _text=""
        if [[ $port_name == '22/tcp' ]]; then
            _text="关闭-[$port_name]-后，可能无法远程访问"
        fi
        confirm "确定要关闭-[$port_name]-端口吗?$_text" "n"
        if [[ $? == 0 ]]; then
            echo -e "${green}写入规则 $(firewall-cmd --zone=public --remove-port=${port_name} --permanent)${plain}"
            echo -e "${green}重载配置 $(firewall-cmd --reload)${plain}"
        fi
    fi
}

list_rules() {
    list=(`firewall-cmd --list-rich-rules | sed -E 's/\s/_/g'`)
    echo -e "===== 防火墙入站规则 ====="
    echo -e "策略\t来源IP\t\t协议类型\t端口"
    for item in "${list[@]}";
    do
        _strategy=`echo "$item"  | awk -F '_' '{print $8}'`
        _address=`echo "$item" | sed -E 's/\_/\n/g' | grep "address" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
        _protocol=`echo "$item" | sed -E 's/\_/\n/g' | grep "protocol" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
        _port=`echo "$item" | sed -E 's/\_/\n/g' | grep "port=" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
        echo -e "$_strategy\t$_address\t$_protocol\t\t$_port"
    done
}

add_rules() {
    while read -p "来源IP：" _address
    do
        if [[ $_address == '' ]]; then
            _address="0.0.0.0/0"
        fi
        address_flag=`echo "$_address" | gawk '/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(\/[0-9]{1,2})?$/{print $0}'`
        if [[ ! -n "${address_flag}" ]]; then
            echo -e "${red}来源IP格式错误！${plain}"
            continue
        fi
        break
    done
    set_port
    if [[ $? == 0 ]]; then
        list=(accept reject)
       
        select item in ${list[@]};
        do
            _strategy=$item
            break
        done
        if [[ $_strategy == '' ]]; then
             _strategy="accept"
        fi
        port_protocol=(`echo "$port_name" | sed -E 's/\// /g'`)
        
        echo -e "${green}写入规则 $(firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="$_address" port protocol="${port_protocol[1]}" port="${port_protocol[0]}" $_strategy")${plain}"
        echo -e "${green}重载配置 $(firewall-cmd --reload)${plain}"
    fi
}

remove_rules() {
    _rules=()
    _index=0
    list=(`firewall-cmd --list-rich-rules | sed -E 's/\s/_/g'`)
    for item in "${list[@]}";
    do
        _strategy=`echo "$item"  | awk -F '_' '{print $8}'`
        _address=`echo "$item" | sed -E 's/\_/\n/g' | grep "address" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
        _protocol=`echo "$item" | sed -E 's/\_/\n/g' | grep "protocol" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
        _port=`echo "$item" | sed -E 's/\_/\n/g' | grep "port=" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
        # echo -e "$_strategy\t$_address\t$_protocol\t\t$_port"
        _rules[$_index]="${_strategy}_${_address}_${_protocol}_${_port}"
        _index=`expr $_index + 1`
    done
    i=0
    rule=""
    select item in "${_rules[@]}";
    do
        rule=`echo "${list[$i]}" | sed -E 's/\_/ /g'`
        i=`expr $i + 1`
        break
    done
    # echo -e "$rule"
    echo -e "${green}写入规则 $(firewall-cmd --permanent --remove-rich-rule="$rule")"
    echo -e "${green}重载配置 $(firewall-cmd --reload)${plain}"
}

install_firewall() {
    if [[ $release == 'centos' ]]; then
        yum install -y firewalld
    else
        apt install -y firewalld
    fi
    systemctl enable firewalld
}

remove_firewall() {
    if [[ $release == 'centos' ]]; then
        yum remove -y firewalld
    else
        apt-get remove -y firewalld
    fi
}


show_menu() {
    get_firewall_status
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}Firewall 防火墙${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 开启防火墙
  ${green} 3${plain}. 停止防火墙
  ${green} 4${plain}. 重启防火墙
  ${green} 5${plain}. 重载配置
 ------------------------
  ${green} 6${plain}. 已开放端口
  ${green} 7${plain}. 开启端口
  ${green} 8${plain}. 关闭端口
 ------------------------
  ${green} 9${plain}. 查看入站规则
  ${green}10${plain}. 添加入站规则
  ${green}11${plain}. 删除入站规则
 ------------------------
  ${green}12${plain}. 安装 Firewall
  ${green}13${plain}. 卸载 Firewall
        "
        echo && read -p "请输入选择 [0-13]: " num
        echo
    fi
    case "${num}" in
    0  )
        exit 0
    ;;
    1  )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        read_firewall_env
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Firewall 正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    systemctl restart firewalld
                fi
            else
                systemctl start firewalld
            fi
        ;;
        3)
            if [[ $status == 'running' ]]; then
                systemctl stop firewalld
            else
                echo -e "${yellow}Firewall 当前停止状态, 无需存在${plain}"
            fi
        ;;
        4)
            systemctl restart firewalld
        ;;
        esac
        read_firewall_env
        show_menu
    ;;
    5  )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        firewall-cmd --reload
        read_firewall_env
        show_menu
    ;;
    6  )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        list_ports
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    7  )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        echo -e "${green}----------------"
        echo -e "  开启防火墙端口"
        echo -e "----------------${plain}"
        add_port
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    8  )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        echo -e "${green}----------------"
        echo -e "  关闭防火墙端口"
        echo -e "----------------${plain}"
        remove_port
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    9  )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        list_rules
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    10 )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        echo -e "${green}----------------"
        echo -e "  添加入站规则"
        echo -e "----------------${plain}"
        add_rules
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    11 )
        clear
        if !(is_command firewalld); then
            show_menu
            return 1
        fi
        echo -e "${green}----------------"
        echo -e "  删除入站规则"
        echo -e "----------------${plain}"
        remove_rules
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    12  )
        clear
        if (is_command firewalld); then
            echo -e "${yellow}Firewall 已经安装; 若要重新安装, 请先卸载! ${plain}"
        else
            install_firewall
        fi
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    13  )
        clear
        confirm "确定要卸载 Firewall 吗?" "n"
        if [[ $? == 0 ]]; then
            remove_firewall
            echo -e "${green}已成功卸载 Firewall ${plain}"
        else
            echo -e "${red}您取消了卸载 Firewall ${plain}"
        fi
        read  -n1  -p "按任意键继续" key
        clear
        read_firewall_env
        show_menu
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-13]${plain}"
    ;;
    esac
}

main() {
    case $1 in
    * )
        clear
        show_menu
    ;;
    esac
}

clear
check_sys
main "$@"