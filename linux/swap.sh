#!/bin/bash

type=$1

case $type in
  create)
    #检查是否存在swapfile
    grep -q "swapfile" /etc/fstab
    if [ $? -ne 0 ]; then
      echo -e "创建swap, 默认为当前内存的2倍"
      # 获取内存大小
      mem=`cat /proc/meminfo | grep "MemTotal" | sed -E 's/[^0-9]//g'`
      # 设置2倍内存大小
      swap=`expr $mem \* 2`
      sudo dd if=/dev/zero of=/swapfile bs=1024 count=$swap status=progress
      sudo mkswap /swapfile
      sudo swapon /swapfile
      sudo chown root:root /swapfile
      sudo chmod 0600 /swapfile
      echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
      echo -e "swap创建完成"
    else
      echo -e "swap已存在, 无需创建"
    fi
  ;;
  remove)
    #检查是否存在swapfile
    grep -q "swapfile" /etc/fstab
    if [ $? -eq 0 ]; then
      sudo sed -i '/swapfile/d' /etc/fstab
      sudo echo "3" > /proc/sys/vm/drop_caches
      sudo swapoff /swapfile
      sudo rm -f /swapfile
      echo -e "swap已删除"
    else
      echo -e "未发现swap"
    fi
  ;;
  *)
  exit;;
esac