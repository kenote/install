#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

mem_size_kb=`cat /proc/meminfo | grep "MemTotal" | sed -E 's/[^0-9]//g'`
mem_size_mb=`echo "scale=0; a = $mem_size_kb / 1024; if (length(a)==scale(a)) print 0;print a" | bc`
mem_size_gb=`echo "scale=2; a = $mem_size_kb / 1048576; if (length(a)==scale(a)) print 0;print a" | bc`

get_swap_env() {
    if [[ $mem_size_gb > 64 ]]; then
        swap_tip="根据当前内存，建议设置为 16 G"
        swap_default=`expr 16 \* 1048576`
        swap_mult=0.25
    elif [[ $mem_size_gb > 8 ]]; then
        swap_tip="根据当前内存，建议设置为 8 G"
        swap_default=`expr 8 \* 1048576`
        swap_mult=1
    elif [[ $mem_size_gb > 4 ]]; then
        swap_tip="根据当前内存，建议设置为与当前内存相同大小"
        swap_default=$mem_size_kb
        swap_mult=2
    else
        swap_tip="根据当前内存，建议设置为当前内存的 2 倍"
        swap_default=`expr $mem_size_kb \* 2`
        swap_mult=3
    fi
}

get_swap() {
    swap_str=$1
    # swap_str=`cat /etc/fstab | grep " swap " | awk -F ' ' '{print $1}'`
    # swap_paths=(${swap_str//,/ })
    swap_paths=`cat /etc/fstab | grep " swap " | awk -F ' ' '{print $1}' | awk -v RS='' '{gsub("\n"," "); print}'`
    if [[ ${swap_paths} != '' ]]; then
        swap_table="\n"
        for swap_path in ${swap_paths[@]}
        do
            swap_size=`wc -c ${swap_path} | awk -F ' ' '{print $1}'`
            swap_size_gb=`echo "scale=2; a = ${swap_size} / 1073741824; if (length(a)==scale(a)) print 0;print a" |bc`
            swap_table="${swap_table}\n  $swap_path -- ${swap_size_gb}GB"
        done
        echo -e "${yellow}
 ----------------------------------
  发现 SWAP${swap_str}${swap_table}
 ----------------------------------
  ${plain}"
    else
        echo -e "${yellow}
 ------------------------
  没有发现 SWAP
 ------------------------
  ${plain}"
    fi
}

add_swap() {
    grep -q " swap " /etc/fstab
    if [ $? -ne 0 ]; then
        echo -e "${yellow}
 -------------------------------------------
  开始创建 SWAP
  ${swap_tip}
 -------------------------------------------
  ${plain}"
        echo && read -p "请输入 SWAP 大小（MB）: " swap_mb_size
        
        if [[ $swap_mb_size != '' ]]; then
            if [[ $swap_mb_size =~ ^([1-9]{1})([0-9]+)?$ ]]; then
                echo -e "SWAP 大小 $swap_mb_size MB"
                swap_kb_size=`echo "scale=2; a = ${swap_mb_size} * 1024; if (length(a)==scale(a)) print 0;print a" |bc`
                multiple=`echo "scale=2; a = ${swap_kb_size} / ${mem_size_kb}; if (length(a)==scale(a)) print 0;print a" |bc`
                if [[ $multiple > $swap_mult ]]; then
                    echo -e "\n${red}请谨慎设置SWAP 大小，不要超出当前物理内存的 ${swap_mult} 倍${plain}\n"
                    exit 1
                elif [[ $swap_mb_size < 2048 ]]; then
                    echo -e "\n${red}SWAP 大小至少需要 2 GB${plain}\n"
                    exit 1
                fi
            else
                echo -e "\n${red}SWAP 大小必须是数字${plain}\n"
                exit 1
            fi
        else
            swap_kb_size=$swap_default
        fi
        create_swap ${swap_kb_size}
    else
        get_swap ", 请先删除下列 SWAP"
    fi
}

create_swap() {
    swap_kb_size=$1
    if [[ $swap_kb_size =~ ^([1-9]{1})([0-9]+)?$ ]]; then
        sudo dd if=/dev/zero of=/swapfile bs=1024 count=$swap_kb_size status=progress
        sudo chown root:root /swapfile
        sudo chmod 0600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
        echo -e "\n${green}SWAP 创建完成${plain}\n"
    fi
}

del_swap() {
    echo -e "${yellow}
 -------------------------------------------
  删除 SWAP, 输入 0 退出
 -------------------------------------------
  ${plain}"
    swap_paths=`cat /etc/fstab | grep " swap " | awk -F ' ' '{print $1}' | awk -v RS='' '{gsub("\n"," "); print}'`
    if [[ ${swap_paths} == '' ]]; then
        echo -e "  未找到 SWAP\n"
        show_menu
        return
    fi
    list=0
    for swap_path in ${swap_paths[@]} 
    do 
        list=`expr $list + 1`
        swap_size=`wc -c ${swap_path} | awk -F ' ' '{print $1}'`
        swap_size_gb=`echo "scale=2; a = ${swap_size} / 1073741824; if (length(a)==scale(a)) print 0;print a" |bc`
        echo -e "  ${green}${list}${plain}. $swap_path -- ${swap_size_gb}GB"
    done
    echo
    echo && read -p "请输入选择 [0-${list}]: " num
    echo

    if [ $num == 0 ]; then
        clear
        show_menu
    elif [ $num -gt 0 -a $num -le $list ]; then
        list=0
        for swap_path in ${swap_paths[@]} 
        do
            list=`expr $list + 1`
            if [[ $list == $num ]]; then
                remove_swap $swap_path
            fi
        done
    else
        echo -e "${red}请输入正确的数字 [0-${list}]${plain}"
    fi
}

remove_swap() {
    swap_file=$1
    eval "sudo sed -i '/$(echo $swap_file | sed -e 's/\//\\\//g' | sed -e 's/\-/\\\-/g')/d' /etc/fstab"
    sudo echo "3" > /proc/sys/vm/drop_caches
    sudo swapoff $swap_file
    sudo rm -f $swap_file
    echo -e "\n${green}SWAP -- $swap_path 已成功删除${plain}\n"
}

show_menu() {
    echo -e "
  ${green}SWAP 管理${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看 SWAP
  ${green} 2${plain}. 添加 SWAP
  ${green} 3${plain}. 删除 SWAP
 ------------------------
  " 
    echo && read -p "请输入选择 [0-3]: " num
    echo
    case "${num}" in
        0  )
            clear
            exit 0
        ;;
        1  )
            clear
            get_swap
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        2  )
            clear
            add_swap
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        3  )
            clear
            del_swap
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
        ;;
        *  )
            clear
            echo -e "${red}请输入正确的数字 [0-3]${plain}"

            show_menu
        ;;
    esac
}

get_swap_env
show_menu