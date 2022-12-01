#! /bin/bash

CURRENT_DIR=$(cd $(dirname $0);pwd)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 系统盘
sys_disk=""

tmp_disks=()

# 判断命令是否存在
is_command() { command -v $@ &> /dev/null; }

# 判断是否海外网络
is_oversea() {
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
}

check_sys(){
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
    if (is_oversea); then
        REPOSITORY_RAW_ROOT="https://raw.githubusercontent.com/kenote/install"
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
    fi
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

need_mounts=""

# 获取可操作磁盘
get_opt_disks() {
    _type=$1
    get_sys_disk
    _disks=""
    alldisks=(`fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d" | sed -E 's/\:|：/ /g' | awk -F ' ' '{print $2}'`)
    if [[ $_type == 'expand' ]]; then
        tmp_disks=(`fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d" | sed -E 's/\:|：/ /g' | awk -F ' ' '{print $2}'`)
        return 1
    fi
    for item in ${alldisks[@]};
    do
        if [[ $item != $sys_disk ]]; then
            # is_true=`fdisk -l | grep -E "${item}"`
            is_true=`df -h | grep -E "^${item}"`
            case $_type in
            mount )
                # 挂载
                if [[ $is_true == '' ]]; then
                    _disks="$_disks $item"
                fi
            ;;
            unmount )
                # 卸载
                if [[ $is_true != '' ]]; then
                    _disks="$_disks $item"
                fi
            ;;
            esac
        fi
    done
    tmp_disks=(`echo $_disks | sed 's/^(\s)//'`)
}

# 获取系统盘
get_sys_disk() {
    sys_disk=`df -h /boot | grep -E "^/dev" | awk -F ' ' '{print $1}' | sed 's/[1-9]$//'`
}

# 选择磁盘分区
select_disk() {
    _type=$1
    _name=$2
    get_opt_disks $_type
    _disk=""
    if [[ ${#tmp_disks[@]} == 0 ]]; then
        echo -e "${yellow}没有可${_name}的磁盘分区${plain}"
        return 1
    fi
    select item in ${tmp_disks[@]};
    do
        _disk=$item
        break
    done
    if [[ $_disk == '' ]]; then
        echo -e "${yellow}没有选择如何磁盘分区${plain}"
        return 1
    fi
}

# 挂载磁盘
mount_disk() {
    _disk=$1
    # _point=$2
    _volumes=(`fdisk -lu ${_disk} | grep -E "^${_disk}" | awk -F ' ' '{print $1}'`)
    _volume=${_volumes[0]}
    is_format="false"
    if [[ ${#_volumes[@]} == 0 ]]; then
        # 需要分区/格式化
        is_format="true"
    else
        confirm "检测到磁盘中有数据，是否要格式化磁盘-[$_disk]-吗?" "n"
        if [[ $? == 0 ]]; then
            is_format="true"
        fi
    fi

    
    if [[ $is_format == 'true' ]]; then
        echo -e "${yellow}创建分区-[${_disk}]-${plain}"
        fdisk -u $_disk <<EOF
n
p
1


wq
EOF
        sleep 1
        _volumes=(`fdisk -lu ${_disk} | grep -E "^${_disk}" | awk -F ' ' '{print $1}'`)
        _volume=${_volumes[0]}
        echo -e "${yellow}格式化分区-[${_volume}]-${plain}"
        mkfs -t ext4 $_volume
        sleep 1
    fi

    while read -p "输入挂载点: " _path
    do
        if [[ $_path == '' ]]; then
            echo -e "${red}挂载点不能为空${plain}"
            continue
        fi
        if [[ ! $_path =~ ^(\/[0-9a-zA-Z]+)+$ ]]; then
            echo -e "${red}挂载点不是路径格式${plain}"
            continue
        fi
        echo -e "${yellow}挂载点: ${_path}${plain}"
        break
    done

    echo -e "${yellow}挂载磁盘分区-[${_volume}]-到-[$_path]-${plain}"
    cp /etc/fstab /etc/fstab.bak
    echo `blkid $_volume | awk '{print $2}' | sed 's/\"//g'` $_path ext4 defaults 0 0 >> /etc/fstab
    mkdir -p $_path
    mount -a
    echo -e "${green}挂载磁盘分区-[完成]-${plain}"
    df -Th
}

# 卸载磁盘分区
unmount_disk() {
    _disk=$1
    _volume=`df -h | grep "$_disk" | awk -F ' ' '{print $1}'`
    confirm "确定要卸载磁盘分区-[$_volume]-吗?" "n"
    if [[ $? == 0 ]]; then
        _path=`df -h | grep "$_disk" | awk -F ' ' '{print $6}'`
        sed -i "/$(echo $_path | sed -E 's/\//\\\//') /d" /etc/fstab
        umount $_path
        echo -e "${green}卸载磁盘分区-[完成]-${plain}"
        df -Th
    else
        return 1
    fi
}

# 扩容磁盘分区
expand_disk() {
    _disk=$1
    if !(is_command growpart); then
        if [[ $release == 'centos' ]]; then
            yum install -y cloud-utils-growpart
        else
            apt-get install -y cloud-guest-utils
        fi
    fi
    echo -e "${yellow}扩容磁盘分区-[${_disk}]-${plain}"
    growpart $_disk 1
    sleep 1
    _partition=`fdisk -lu $_disk | grep -E "^$_disk" | awk -F ' ' '{print $1}'`
    echo -e "${yellow}重置分区-[${_partition}]-大小${plain}"
    resize2fs $_partition
    echo -e "${green}扩容磁盘分区-[完成]-${plain}"
    df -Th
}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file"`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        mkdir -p $(dirname $filepath)
        wget -O $filepath ${REPOSITORY_RAW_ROOT}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}磁盘分区管理${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看磁盘分区
  ${green} 2${plain}. 挂载磁盘分区
  ${green} 3${plain}. 卸载磁盘分区
  ${green} 4${plain}. 扩容磁盘分区
        "
        echo && read -p "请输入选择 [0-4]: " num
        echo
    fi
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts' ]]; then
            run_script help.sh
        else
            exit 0
        fi
    ;;
    1  )
        clear
        echo -e "${green}----------------"
        echo -e "  查看磁盘分区"
        echo -e "----------------${plain}"
        df -Th
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2  )
        clear
        echo -e "${green}----------------"
        echo -e "  挂载磁盘分区"
        echo -e "----------------${plain}"
        select_disk mount "挂载"
        if [[ $? == 0 ]]; then
            confirm "确定要挂载磁盘-[$_disk]-吗?" "n"
            if [[ $? == 0 ]]; then
                mount_disk $_disk
                read  -n1  -p "按任意键继续" key
            fi
        else
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    3  )
        clear
        echo -e "${green}----------------"
        echo -e "  卸载磁盘分区"
        echo -e "----------------${plain}"
        select_disk unmount "卸载"
        if [[ $? == 0 ]]; then
            unmount_disk $_disk
            if [[ $? == 0 ]]; then
                read  -n1  -p "按任意键继续" key
            fi
        else
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    4  )
        clear
        echo -e "${green}----------------"
        echo -e "  扩容磁盘分区"
        echo -e "----------------${plain}"
        select_disk expand "扩容"
        if [[ $? == 0 ]]; then
            confirm "确定要扩容磁盘分区-[$_disk]-吗?" "n"
            if [[ $? == 0 ]]; then
                expand_disk $_disk 
                read  -n1  -p "按任意键继续" key
            fi
        fi
        clear
        show_menu
    ;;
    *  )
        echo -e "${red}请输入正确的数字 [0-4]${plain}"
    ;;
    esac
}

main() {
    case $1 in
    * )
        clear
        show_menu
    ;;
    esac
}

clear
check_sys
main "$@"