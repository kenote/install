# Nginx 管理助手

Nginx是异步框架的网页服务器，也可以用作反向代理、负载平衡器和HTTP缓存。

## 安装

```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
mkdir -p $HOME/.scripts/nginx \
&& wget -O $HOME/.scripts/nginx/help.sh https://${REPO_RAW}/main/linux/nginx/help.sh \
&& chmod +x $HOME/.scripts/nginx/help.sh \
&& $HOME/.scripts/nginx/help.sh
```

## 使用
```bash
$HOME/.scripts/nginx/help.sh
```