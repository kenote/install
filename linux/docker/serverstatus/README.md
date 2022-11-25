# ServerStatus

ServerStatus 是一个酷炫高逼格的云探针、云监控、服务器云监控、多服务器探针~。

## Install

```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
wget -O sss.sh https://${REPO_RAW}/main/linux/docker/serverstatus/server.sh \
&& chmod +x sss.sh \
&& ./sss.sh
```
