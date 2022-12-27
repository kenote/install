# SpeedTest

这是一个非常轻量级的 Speedtest，使用 Javascript 实现，使用 XMLHttpRequest 和 Web Workers。

## Install

```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
wget -O speedtest.sh https://${REPO_RAW}/main/linux/docker/speedtest/help.sh \
&& chmod +x speedtest.sh \
&& ./speedtest.sh
```
