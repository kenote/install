#! /bin/bash

type=$1
openssl_version="openssl-1.1.1q"

# 判断是否海外网络
function is_oversea(){
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
}

# 初始化环境
function init_env(){
    if (is_oversea); then
        urlroot="https://raw.githubusercontent.com/kenote/install"
    else
        urlroot="https://gitee.com/kenote/install/raw"
    fi
    if [ -f './start.sh' ]; then
        system=`./start.sh release`
    else
        system=`wget -O start.sh ${urlroot}/main/linux/start.sh && chmod +x start.sh && clear && ./start.sh release`
    fi
}

# 安装 nginx
function install_nginx(){
    if [[ $system == 'centos' ]]; then
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

function remove_nginx(){
    if [[ $system == 'centos' ]]; then
        yum remove -y nginx
    else
        apt-get remove -y nginx
    fi
}

# 升级 openssl
function install_openssl(){
    echo -e "升级 OpenSSL 到 ${openssl_version}"
    if [[ $system == 'centos' ]]; then
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

# 更新 nginx 替换系统原有的，以支持 TLS1.3
function update_nginx(){
    echo -e "更新 nginx 替换系统原有的，以支持 TLS1.3"
    if !(command -v git); then
        curl -o- ${urlroot}/main/linux/install-git.sh | bash
    fi
    if [[ $system == 'centos' ]]; then
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

init_env
case $type in
    openssl )
        install_openssl
    ;;
    update )
        update_nginx
    ;;
    remove )
        remove_nginx
    ;;
    * )
        install_nginx
    ;;
esac
