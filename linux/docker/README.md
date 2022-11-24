# Docker

Docker 是一个开源的应用容器引擎，基于 Go 语言 并遵从 Apache2.0 协议开源。\
Docker 可以让开发者打包他们的应用以及依赖包到一个轻量级、可移植的容器中，然后发布到任何流行的 Linux 机器上，也可以实现虚拟化。\
容器是完全使用沙箱机制，相互之间不会有任何接口（类似 iPhone 的 app）,更重要的是容器性能开销极低。

## 安装

创建目录
```bash
mkdir -p $HOME/.scripts/docker
```

下载脚本 - Github
```bash
wget -O $HOME/.scripts/docker/help.sh https://raw.githubusercontent.com/kenote/install/main/linux/docker/help.sh
```

下载脚本 - Gitee
```bash
wget -O $HOME/.scripts/docker/help.sh https://gitee.com/kenote/install/raw/main/linux/docker/help.sh
```

设置权限
```bash
chmod +x $HOME/.scripts/docker/help.sh
```

运行脚本
```bash
$HOME/.scripts/docker/help.sh
```