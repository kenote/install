#! /bin/bash

ssldir=/home/ssl
workdir=/home
openssl_version=`wget -qO- https://www.openssl.org/source | grep "openssl-1.1.1" | sed 's/<[^>]*>//g' | awk -F ' ' '{print $1}' | sed 's/.tar.gz$//'`

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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

# 判断命令是否存在
is_command() { command -v $@ &> /dev/null; }

# 判断是否海外网络
is_oversea() {
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
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

install_nginx() {
    if [[ $release == 'centos' ]]; then
        version=`cat /etc/os-release | grep "VERSION_ID" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'`
        cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx]  
name=nginx repo  
baseurl=https://nginx.org/packages/mainline/centos/$version/\$basearch/  
gpgcheck=0  
enabled=1
EOF
        yum install -y nginx
        systemctl enable nginx
        systemctl start nginx
    else
        apt-get install -y nginx
        systemctl enable nginx
        systemctl start nginx
    fi
}

remove_nginx() {
    if [[ $release == 'centos' ]]; then
        yum remove -y nginx
    else
        apt-get remove -y nginx
    fi
}

update_nginx(){
    echo -e "更新 nginx 替换系统原有的，以支持 TLS1.3"
    if !(command -v git); then
        curl -o- ${urlroot}/main/linux/install-git.sh | bash
    fi
    if [[ $release == 'centos' ]]; then
        yum install -y gcc gcc-c clang automake make autoconf libtool zlib-devel libatomic_ops-devel pcre-devel openssl-devel libxml2-devel libxslt-devel gd-devel GeoIP-devel gperftools-devel  perl-devel perl-ExtUtils-Embed
    fi
    cd $HOME
    rm -rf nginx
    rm -rf nginx-ct
    if (is_oversea); then
        git clone https://github.com/nginx/nginx.git
        git clone https://github.com/grahamedgecombe/nginx-ct.git
    else
        git clone https://gitee.com/kenote/nginx.git
        git clone https://gitee.com/kenote/nginx-ct.git
    fi
    echo -e "./${openssl_version}"
    if [ ! -d "./${openssl_version}" ]; then
        wget --no-check-certificate https://www.openssl.org/source/${openssl_version}.tar.gz
        tar xvf ${openssl_version}.tar.gz
    fi
    cd nginx
    ./auto/configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie' --add-module=../nginx-ct/ --with-openssl=../${openssl_version}/
    make
    ./objs/nginx -v
    mv /usr/sbin/nginx /usr/sbin/nginx.official.mainline
    cp ./objs/nginx /usr/sbin/
    # 显示安装版本
    nginx -V
    systemctl restart nginx
}

install_openssl() {
    echo -e "安装 OpenSSL ${openssl_version}"
    if [[ $release == 'centos' ]]; then
        yum install -y gcc-c++ pcre pcre-devel zlib zlib-devel
    fi
    if !(command -v perl); then
        # 安装 Perl 5
        cd $HOME
        wget https://www.cpan.org/src/5.0/perl-5.36.0.tar.gz
        tar -xzf perl-5.36.0.tar.gz
        cd perl-5.36.0
        ./Configure -des -Dprefix=$HOME/localperl
        make
        make test
        make install
    fi
    # 安装 OpenSSL
    cd $HOME
    wget --no-check-certificate https://www.openssl.org/source/${openssl_version}.tar.gz
    tar xvf ${openssl_version}.tar.gz
    cd ${openssl_version}
    ./config shared --openssldir=/usr/local/openssl --prefix=/usr/local/openssl
    make
    make install
    # 移除老版本
    mv /usr/bin/openssl /tmp/
    ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
    # 配置lib库
    echo "/usr/local/openssl/lib/" >> /etc/ld.so.conf
    ldconfig
    # 显示安装版本
    openssl version
}

main() {
    case $1 in
    remove)
        remove_nginx
    ;;
    update)
        if (is_command nginx); then
            update_nginx
        else
            echo -e "${yellow}请先安装 Nginx! ${plain}"
        fi
    ;;
    openssl)
        install_openssl
    ;;
    * )
        if (is_command nginx); then
            echo -e "${yellow}Nginx 已经安装; 若要重新安装, 请先卸载! ${plain}"
        else
            install_nginx
        fi
    ;;
    esac
}

check_sys
main "$@"