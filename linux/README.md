# Linux 服务器安装

## 初始化

- 新服务器先执行以下命令
  ```bash
  yum install -y curl wget 2> /dev/null || apt install -y curl wget
  ```

## 运维助手

- 安装运维助手
  ```bash
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/help.sh https://raw.githubusercontent.com/kenote/install/main/linux/help.sh \
  && chmod +x $HOME/.scripts/help.sh \
  && clear && $HOME/.scripts/help.sh

  # 中国大陆
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/help.sh https://gitee.com/kenote/install/raw/main/linux/help.sh \
  && chmod +x $HOME/.scripts/help.sh \
  && clear && $HOME/.scripts/help.sh
  ```

- 运行运维助手
  ```bash
  $HOME/.scripts/help.sh
  ```

## 单独使用模块

- ### SWAP 管理
  -- 安装 --
  ```bash
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/swap.sh https://raw.githubusercontent.com/kenote/install/main/linux/swap.sh \
  && chmod +x $HOME/.scripts/swap.sh \
  && clear && $HOME/.scripts/swap.sh

  # 中国大陆
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/swap.sh https://gitee.com/kenote/install/raw/main/linux/swap.sh \
  && chmod +x $HOME/.scripts/swap.sh \
  && clear && $HOME/.scripts/swap.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/swap.sh
  ```

- ### 磁盘分区管理
  -- 安装 --
  ```bash
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/disk.sh https://raw.githubusercontent.com/kenote/install/main/linux/disk.sh \
  && chmod +x $HOME/.scripts/disk.sh \
  && clear && $HOME/.scripts/disk.sh

  # 中国大陆
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/disk.sh https://gitee.com/kenote/install/raw/main/linux/disk.sh \
  && chmod +x $HOME/.scripts/disk.sh \
  && clear && $HOME/.scripts/disk.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/disk.sh
  ```

- ### Firewall 防火墙
  -- 安装 --
  ```bash
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/firewall.sh https://raw.githubusercontent.com/kenote/install/main/linux/firewall.sh \
  && chmod +x $HOME/.scripts/firewall.sh \
  && clear && $HOME/.scripts/firewall.sh

  # 中国大陆
  mkdir -p $HOME/.scripts \
  && wget -O $HOME/.scripts/firewall.sh https://gitee.com/kenote/install/raw/main/linux/firewall.sh \
  && chmod +x $HOME/.scripts/firewall.sh \
  && clear && $HOME/.scripts/firewall.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/firewall.sh
  ```

- ### Nginx 管理助手
  -- 安装 --
  ```bash
  mkdir -p $HOME/.scripts/nginx \
  && wget -O $HOME/.scripts/nginx/help.sh https://raw.githubusercontent.com/kenote/install/main/linux/nginx/help.sh \
  && chmod +x $HOME/.scripts/nginx/help.sh \
  && clear && $HOME/.scripts/nginx/help.sh

  # 中国大陆
  mkdir -p $HOME/.scripts/nginx \
  && wget -O $HOME/.scripts/nginx/help.sh https://gitee.com/kenote/install/raw/main/linux/nginx/help.sh \
  && chmod +x $HOME/.scripts/nginx/help.sh \
  && clear && $HOME/.scripts/nginx/help.sh
  ```
  -- 运行 --
  ```bash
  $HOME/.scripts/nginx/help.sh
  ```

## 单独安装模块

- ### 安装最新版 Git
  ```bash
  curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-git.sh | bash

  # 中国大陆
  curl -o- https://gitee.com/kenote/install/raw/main/linux/install-git.sh | bash
  ```

- ### 安装最新版 Htop
  ```bash
  curl -o- https://raw.githubusercontent.com/kenote/install/main/linux/install-htop.sh | bash

  # 中国大陆
  curl -o- https://gitee.com/kenote/install/raw/main/linux/install-htop.sh | bash
  ```