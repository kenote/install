# Linux 服务器安装

## 初始化

- 新服务器先执行以下命令
  ```bash
  yum install -y curl wget 2> /dev/null || apt install -y curl wget
  ```

## 运维助手

- 安装运维助手
  ```bash
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/help.sh https://${REPO_RAW}/main/linux/help.sh \
  && chmod +x $HOME/.scripts/help.sh \
  && $HOME/.scripts/help.sh
  ```

- 运行运维助手
  ```bash
  $HOME/.scripts/help.sh
  ```

## 单独使用

- ### SWAP 管理
  -- 安装 --
  ```bash
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/swap.sh https://${REPO_RAW}/main/linux/swap.sh \
  && chmod +x $HOME/.scripts/swap.sh \
  && $HOME/.scripts/swap.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/swap.sh
  ```

- ### 磁盘分区管理
  -- 安装 --
  ```bash
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/disk.sh https://${REPO_RAW}/main/linux/disk.sh \
  && chmod +x $HOME/.scripts/disk.sh \
  && $HOME/.scripts/disk.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/disk.sh
  ```

- ### Firewall 防火墙
  -- 安装 --
  ```bash
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/firewall.sh https://${REPO_RAW}/main/linux/firewall.sh \
  && chmod +x $HOME/.scripts/firewall.sh \
  && $HOME/.scripts/firewall.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/firewall.sh
  ```

- ### Nginx 管理助手
  -- 安装 --
  ```bash
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  mkdir -p $HOME/.scripts/nginx \
  && wget -O $HOME/.scripts/nginx/help.sh https://${REPO_RAW}/main/linux/nginx/help.sh \
  && chmod +x $HOME/.scripts/nginx/help.sh \
  && $HOME/.scripts/nginx/help.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/nginx/help.sh
  ```

- ### Docker 管理助手
  -- 安装 --
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  mkdir -p $HOME/.scripts/docker \
  && wget -O $HOME/.scripts/docker/help.sh https://${REPO_RAW}/main/linux/docker/help.sh \
  && chmod +x $HOME/.scripts/docker/help.sh \
  && $HOME/.scripts/docker/help.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/docker/help.sh
  ```

## 单独安装模块

- ### 安装最新版 Git
  ```bash
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  curl -o- https://${REPO_RAW}/main/linux/install-git.sh | bash
  ```

- ### 安装最新版 Htop
  ```bash
  REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
  curl -o- https://${REPO_RAW}/main/linux/install-htop.sh | bash
  ```