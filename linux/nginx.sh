#! /bin/bash

type=$1
acmeci=$HOME/.acme.sh/acme.sh
ssldir=/mnt/ssl
wwwroot=/mnt/wwwroot

# 获取 nginx 变量
function get_nginx_env(){
    # 获取 nginx 主路径; 一般为: /etc/nginx
    rootdir=`find /etc /usr/local -name nginx.conf | sed -e 's/\/nginx\.conf//'`
    # 获取 nginx 配置文件夹路径; 一般为: /etc/nginx/conf.d
    conflink=`cat ${rootdir}/nginx.conf | grep "conf.d/\*.conf;" | sed -e 's/\s//g' | sed -e 's/include//' | sed -e 's/\/\*\.conf\;//'`
    # 获取 nginx 配置文件夹真实路径
    confdir=`readlink -f ${conflink}`
    # 获取 ssl 存放目录
    if [[ $confdir != $conflink ]]; then
        ssldir=`readlink -f ${conflink} | sed -e 's/\/conf$/\/ssl/'`
    fi
}

# 创建基础服务
function create_server(){
    force=""
    if [[ $1 == '--force' ]]; then
        force=$1
    fi
    read -p "绑定域名: " domain
    mkdir -p ${wwwroot}/${domain}/htdocs
    cat > ${wwwroot}/${domain}/htdocs/index.html <<EOF
<html>
    <head>
        <title>${domain}</title>
    </head>
    <body>
        网站建设中 ...
    </body>
</html>
EOF
    # 创建一个基础服务
    cat > ${confdir}/${domain}.conf <<EOF
server {
    listen 80;
    server_name ${domain};
    index index.html index.htm;
    root ${wwwroot}/${domain}/htdocs;
}
EOF
    systemctl restart nginx
    # 申请 Let's Encrypt 域名证书
    ${acmeci} --issue -d ${domain} --nginx $force
    # 更新配置加入 ssl
    cat > ${confdir}/${domain}.conf <<EOF
server {
    listen 80;
    server_name ${domain};
    index index.html index.htm;
    root ${wwwroot}/${domain}/htdocs;

    return  301 https://\$host\$request_uri;
}
server {
    isten 443 ssl;
    server_name ${domain};
    index index.html index.htm;
    root ${wwwroot}/${domain}/htdocs;
  
    ssl_certificate ${ssldir}/${domain}/cert.crt;
    ssl_certificate_key ${ssldir}/${domain}/private.key;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
    ssl_prefer_server_ciphers on;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:5m;
    ssl_session_timeout 5m;
}
EOF
    # 创建证书存放目录
    mkdir -p ${ssldir}/${domain}
    # 安装证书到目录
    ${acmeci} --installcert -d ${domain} --key-file ${ssldir}/${domain}/private.key --fullchain-file ${ssldir}/${domain}/cert.crt --reloadcmd "systemctl restart nginx"
}

# 更改配置文件工作目录
function set_workdir(){
    echo -e "设置 Nginx 工作目录"
    read -p "设置工作目录: " workdir
    if [[ $workdir == '' ]]; then
        exit 1
    else
        mkdir -p ${workdir}
        times=`date +%Y%m%d%H%M`
        if [[ $confdir == $conflink ]]; then
            # 软链接不存在; 
            cp $confdir/*  $conflink.bak.$times
            mv $confdir ${workdir}/conf
        else
            # 软链接存在; 先清除软链接
            rm -rf ${conflink}
            cp $confdir/*  $conflink.bak.$times
            mv $confdir ${workdir}/conf
        fi
        ln -s ${workdir}/conf ${conflink}   
        echo -e "Nginx 工作目录已迁移至 ${workdir}/ 下"
    fi
}

# 禁止使用 IP 访问
function disable_useip(){
    # 创建一张默认证书
    mkdir -p ${ssldir}
    openssl req -newkey rsa:2048 -nodes -keyout ${ssldir}/private.key -x509 -days 365 -out ${ssldir}/cert.crt -subj "/C=CN"
    # 写入配置
    cat > ${confdir}/default.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 400;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
  
    ssl_certificate ${ssldir}/cert.crt;
    ssl_certificate_key ${ssldir}/private.key;
    
    server_name _;
    return 400;
}
EOF
    # 重启 nginx
    systemctl restart nginx
}

# 开启使用 IP 访问
function enable_useip(){
    # 写入配置
    cat > ${confdir}/default.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
EOF
    # 重启 nginx
    systemctl restart nginx
}

case $type in
    info )
        clear
        get_nginx_env
        echo -e "======= Nginx 信息 ======="
        echo -e $(nginx -v)
        echo -e "nginx主目录: ${rootdir}"
        echo -e "配置文件目录: ${confdir}"
        echo -e "SSL证书目录: ${ssldir}"
        echo -e "静态文件目录: ${wwwroot}"
    ;;
    create )
        clear
        echo -e "如果证书申请失败; 请添加 '--force' 参数, 再次尝试"
        get_nginx_env
        create_server $2
    ;;
    workdir )
        clear
        get_nginx_env
        set_workdir
    ;;
    not_useip )
        clear
        get_nginx_env
        disable_useip
    ;;
    yes_useip )
        clear
        get_nginx_env
        enable_useip
    ;;
    * )
        exit 1
    ;;
esac