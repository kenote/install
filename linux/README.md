# Linux 服务器安装

## 前期准备

`Redhat / CentOS`
```bash
yum update -y
yum install -y curl wget net-tools
```

`Debian / Ubuntu`
```bash
apt update -y
apt install -y curl wget net-tools bc
```

## 安装工具箱

海外
```bash
wget -O start.sh https://raw.githubusercontent.com/kenote/install/main/linux/start.sh && chmod +x start.sh && clear && ./start.sh
```
国内
```bash
wget -O start.sh https://gitee.com/kenote/install/raw/main/linux/start.sh && chmod +x start.sh && clear && ./start.sh
```

## 单独安装

### 最新版 Git

海外
```bash
curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-git.sh | bash
```

国内
```bash
curl -o- https://gitee.com/kenote/install/raw/main/linux/install-git.sh | bash
```

### Htop

海外
```bash
curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-htop.sh | bash
```

国内
```bash
curl -o- https://gitee.com/kenote/install/raw/main/linux/install-htop.sh | bash
```

### Nginx

海外
```bash
# 安装 nginx
curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh | bash

# 升级 openssl 1.1.1
bash <(curl -s https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh) openssl

# 更新 nginx 替换系统原有的，以支持 TLS1.3
bash <(curl -s https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh) update

# 移除 nginx
bash <(curl -s https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh) remove

# 安装 acme.sh
bash <(curl -s https://raw.githubusercontent.com/kenote/install/main/linux/install-nginx.sh) acmesh

# 创建 Nginx 站点
wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh create

# 查看 Nginx 信息
wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh info

# 更改 Nginx 配置文件路径
wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh workdir

# 禁止使用 IP 访问
wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh not_useip

# 开启使用 IP 访问
wget -O nginx.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh yes_useip
```

国内
```bash
# 安装 nginx
curl -o- https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh | bash

# 升级 openssl 1.1.1
bash <(curl -s https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh) openssl

# 更新 nginx 替换系统原有的，以支持 TLS1.3
bash <(curl -s https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh) update

# 移除 nginx
bash <(curl -s https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh) remove

# 安装 acme.sh
bash <(curl -s https://gitee.com/kenote/install/raw/main/linux/install-nginx.sh) acmesh

# 创建 Nginx 站点
wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh create

# 查看 Nginx 信息
wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh info

# 更改 Nginx 配置文件路径
wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh workdir

# 禁止使用 IP 访问
wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh not_useip

# 开启使用 IP 访问
wget -O nginx.sh https://gitee.com/kenote/install/raw/main/linux/nginx.sh && chmod +x nginx.sh && clear && ./nginx.sh yes_useip
```


