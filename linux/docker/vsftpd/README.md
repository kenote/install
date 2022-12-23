# Vsftpd

vsftpd（very secure FTP daemon，意為非常安全的FTP守护进程）是一个类Unix系统以及Linux上的FTP服务器軟件。

## Install

```bash
REPO_RAW=`curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null && echo "raw.githubusercontent.com/kenote/install" || echo "gitee.com/kenote/install/raw"`; \
wget -O vsftpd.sh https://${REPO_RAW}/main/linux/docker/vsftpd/help.sh \
&& chmod +x vsftpd.sh \
&& ./vsftpd.sh
```
