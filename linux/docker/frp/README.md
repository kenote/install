# FRP

- frp 主要由 **客户端(frpc)** 和 **服务端(frps)** 组成，服务端通常部署在具有公网 IP 的机器上，客户端通常部署在需要穿透的内网服务所在的机器上。

- 内网服务由于没有公网 IP，不能被非局域网内的其他用户访问。

- 用户通过访问服务端的 frps，由 frp 负责根据请求的端口或其他信息将请求路由到对应的内网机器，从而实现通信。

## Install

服务端
```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
wget -O frps.sh https://${REPO_RAW}/main/linux/docker/frp/server.sh \
&& chmod +x frps.sh \
&& ./frps.sh
```

客户端
```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
wget -O frpc.sh https://${REPO_RAW}/main/linux/docker/frp/agent.sh \
&& chmod +x frps.sh \
&& ./frpc.sh
```