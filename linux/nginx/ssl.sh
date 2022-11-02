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
    mkdir -p $ssldir
}


install_acme() {
    echo -e "开始安装 acme.sh"
    if [[ $release == 'centos' ]]; then
        yum install -y socat
    else
        apt install -y socat
    fi
    cd $HOME
    while read -p "请设置一个邮箱: " email
    do
        if [[ $email == '' ]]; then
            echo -e "${red}请填写一个邮箱地址！${plain}"
            continue
        fi
        mail_flag=`echo "$email" | gawk '/^([a-zA-Z0-9_\-\.\+]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/{print $0}'`
        if [[ ! -n "${mail_flag}" ]]; then
            echo -e "${red}邮箱格式有误！${plain}"
            continue
        fi
        break
    done
    if (is_oversea); then
        curl https://get.acme.sh | sh -s email=$email
    else
        git clone https://gitee.com/neilpang/acme.sh.git
        cd ./acme.sh
        ./acme.sh --install -m $email
                  
    fi
    acmeci=$HOME/.acme.sh/acme.sh
    # $acmeci --register-account -m $email
    echo -e "设置自动更新 ..."
    $acmeci --upgrade --auto-upgrade
    echo -e "acme.sh 安装完成"
}

uninstall_acme() {
    echo -e "开始卸载 acme.sh"
    acmeci=$HOME/.acme.sh/acme.sh
    $acmeci --uninstall
    rm -rf $HOME/.acme.sh
    echo -e "acme.sh 卸载完成"
}

set_default_ca() {
    _ca=$1
    if [[ $1 == '' ]]; then
        list=(letsencrypt buypass zerossl)
        echo -e "设置默认CA"
        select item in ${list[@]};
        do
            _ca=$item
            break
        done
    fi
    acmeci=$HOME/.acme.sh/acme.sh
    $acmeci --set-default-ca --server $_ca
}

# 申请证书
apply_cert() {
    _domain=""
    _server=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --domain | -d)
            _domain=$2
            if [[ $_domain == '' ]]; then
                echo -e "${red}缺少域名！${plain}"
                return 1
            fi
            domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
            if [[ ! -n "${domain_flag}" && ! $_domain =~ (\@|default) ]]; then
                echo -e "${red}域名格式有误！${plain}"
                return 1
            fi
            shift
        ;;
        --server)
            _server=$2
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
        # _domain
        while read -p "申请域名: " _domain;
        do
            if [[ $_domain == '' ]]; then
                echo -e "${red}请填写申请域名！${plain}"
                continue
            fi
            domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
            if [[ ! -n "${domain_flag}" && ! $_domain =~ (\@|default) ]]; then
                echo -e "${red}域名格式有误！${plain}"
                continue
            fi
            echo -e "${yellow}申请域名: ${_domain}${plain}"
            break
        done
        # server
        list=(letsencrypt buypass zerossl)
        echo -e "选择服务商:"
        select item in ${list[@]};
        do
            _server=$item
            echo -e "${yellow}服务商: ${item}${plain}"
            break
        done
    fi
    acmeci=$HOME/.acme.sh/acme.sh
    if [[ $_server == '' ]]; then
        $acmeci --issue -d $_domain --nginx
    else
        $acmeci --issue -d $_domain --nginx --server $_server
    fi
}

# 安装证书
install_cert() {
    _domain=""
    _target=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --domain | -d)
            _domain=$2
            if [[ $_domain == '' ]]; then
                echo -e "${red}缺少域名！${plain}"
                return 1
            fi
            domain_flag=`echo "$_domain" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'`
            if [[ ! -n "${domain_flag}" && ! $_domain =~ (\@|default) ]]; then
                echo -e "${red}域名格式有误！${plain}"
                return 1
            fi
            shift
        ;;
        --target)
            _target=$2
            if [[ $_target == '' ]]; then
                echo -e "${red}目标路径不能为空！${plain}"
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
        list=`ls /root/.acme.sh --ignore="ca" --ignore="deploy" --ignore="dnsapi" --ignore="notify" -F | grep "/$" | sed 's/\///'`
        if [[ $list = '' ]]; then
            echo -e "${red}还没有证书, 请先申请证书！${plain}"
            sleep 5
            apply_cert
            return 1
        fi
        echo -e "选择域名:"
        select item in ${list[@]};
        do
            _domain=$item
            echo -e "${yellow}域名: ${item}${plain}"
            break
        done
        if [[ $_target == '' ]]; then
            while read -p "目标路径: " _target;
            do
                if [[ $_target == '' ]]; then
                    echo -e "${red}请填写目标路径！${plain}"
                    continue
                fi
                echo -e "${yellow}目标路径: ${_target}${plain}"
                break
            done
        fi
    fi
    acmeci=$HOME/.acme.sh/acme.sh
    $acmeci --install-cert -d $_domain --fullchain-file $_target/$_domain/cert.crt  --key-file $_target/$_domain/private.key --reloadcmd "systemctl restart nginx"
}

cer2jks() {
    _target=""
    _pass=""
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        --target)
            _target=$2
            if [[ $_target == '' ]]; then
                echo -e "${red}目标路径不能为空！${plain}"
                return 1
            fi
            shift
        ;;
        --pass)
            _pass=$2
            if [[ $_pass == '' ]]; then
                echo -e "${red}密码不能为空！${plain}"
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
    if [[ $_target == '' ]]; then
        list=`ls $ssldir -F | grep "/$" | sed 's/\///'`
        if [[ $list = '' ]]; then
            echo -e "${red}没有可转换的证书！${plain}"
            return 1
        fi
        echo -e "选择域名证书:"
        select item in ${list[@]};
        do
            _target=$ssldir/$item
            echo -e "${yellow}域名证书: ${item}${plain}"
            break
        done
    fi
    if [[ $_pass == '' ]]; then
        while read -p "设置密码: " _pass;
        do
            if [[ $_target == '' ]]; then
                echo -e "${red}请设置密码！${plain}"
                continue
            fi
            echo -e "${yellow}密码: ${_pass}${plain}"
            break
        done
    fi
    if !(is_command keytool); then
        if [[ $release == 'centos' ]]; then
             yum install -y java-1.8.0-openjdk
        else
            apt install -y java-1.8.0-openjdk
        fi
    fi
    cd $_target
    openssl pkcs12 -export -in cert.crt -inkey private.key -out tomcat.p12 -name tomcat_letsencrypt -password pass:$_pass
    keytool -importkeystore -deststorepass "$_pass" -destkeypass "$_pass" -destkeystore tomcat.jks -srckeystore tomcat.p12 -srcstoretype PKCS12 -srcstorepass "$_pass" -alias tomcat_letsencrypt
    echo "$_pass" > ./jks-password.txt
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}-- SSL证书管理 --${plain}

  ${green} 0${plain}. 返回
 ------------------------
  ${green} 1${plain}. 申请SSL证书
  ${green} 2${plain}. 安装SSL证书
  ${green} 3${plain}. 设置默认CA
  ${green} 4${plain}. CRT转JKS证书
 ------------------------
  ${green} 5${plain}. 安装 ACME
  ${green} 6${plain}. 卸载 ACME
        "
        echo && read -p "请输入选择 [0-6]: " num
        echo
    fi
    case "${num}" in
    0)
        run_script help.sh
    ;;
    1)
        clear
        echo -e "${green}----------------"
        echo -e "  申请SSL证书"
        echo -e "----------------${plain}"
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            apply_cert
        else
            echo -e "${yellow}请先安装 ACME!${plain}"
        fi
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2)
        clear
        echo -e "${green}----------------"
        echo -e "  安装SSL证书"
        echo -e "----------------${plain}"
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            install_cert
        else
            echo -e "${yellow}请先安装 ACME!${plain}"
        fi
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    3)
        clear
        echo -e "${green}----------------"
        echo -e "  设置默认CA"
        echo -e "----------------${plain}"
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            set_default_ca
        else
            echo -e "${yellow}请先安装 ACME!${plain}"
        fi
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    4)
        clear
        echo -e "${green}----------------"
        echo -e "  CRT转JKS证书"
        echo -e "----------------${plain}"
        cer2jks
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5)
        clear
        echo -e "${green}----------------"
        echo -e "  安装 ACME"
        echo -e "----------------${plain}"
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            echo -e "${yellow}ACME 已经安装!${plain}"
        else
            install_acme
        fi
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    6)
        clear
        echo -e "${green}----------------"
        echo -e "  卸载 ACME"
        echo -e "----------------${plain}"
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            uninstall_acme
        else
            echo -e "${yellow}ACME 没有安装!${plain}"
        fi
        sleep 3
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    *)
        clear
        echo -e "${red}请输入正确的数字 [0-6]${plain}"
        show_menu
    ;;
    esac
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
    acme.sh)
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            echo -e "${yellow}ACME 已经安装!${plain}"
        else
            install_acme
        fi
    ;;
    acme_uninstall)
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            uninstall_acme
        else
            echo -e "${yellow}ACME 没有安装!${plain}"
        fi
    ;;
    set_default_ca)
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            echo -e "${yellow}ACME 已经安装!${plain}"
        else
            set_default_ca "${@:2}"
        fi
    ;;
    apply_cert)
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            apply_cert "${@:2}"
        else
            echo -e "${yellow}请先安装 ACME!${plain}"
        fi
    ;;
    install_cert)
        if [[ -f $HOME/.acme.sh/acme.sh ]]; then
            install_cert "${@:2}"
        else
            echo -e "${yellow}请先安装 ACME!${plain}"
        fi
    ;;
    cer2jks)
        cer2jks "${@:2}"
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