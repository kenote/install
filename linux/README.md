# Linux 服务器安装

## 前期准备

`Redhat / CentOS`
```bash
yum update
yum install -y curl wget net-tools
```

`Debian / Ubuntu`
```bash
apt update
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