# Docker

Docker 是一个开源的应用容器引擎，基于 Go 语言 并遵从 Apache2.0 协议开源。\
Docker 可以让开发者打包他们的应用以及依赖包到一个轻量级、可移植的容器中，然后发布到任何流行的 Linux 机器上，也可以实现虚拟化。\
容器是完全使用沙箱机制，相互之间不会有任何接口（类似 iPhone 的 app）,更重要的是容器性能开销极低。

## Install

```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
mkdir -p $HOME/.scripts/docker \
&& wget -O $HOME/.scripts/docker/help.sh https://${REPO_RAW}/main/linux/docker/help.sh \
&& chmod +x $HOME/.scripts/docker/help.sh \
&& $HOME/.scripts/docker/help.sh
```

快速安装
```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
curl -s https://${REPO_RAW}/main/linux/docker/help.sh | bash -s install
```

## Usage

```bash
$HOME/.scripts/docker/help.sh
```