#!/bin/bash

CURRENT_DIR=$(cd $(dirname $0);pwd)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 判断命令是否存在
is_command() { command -v $@ &> /dev/null; }

# 判断是否海外网络
is_oversea() {
    curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/1.[01] [23].." &> /dev/null;
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

pre_check(){
    if (is_oversea); then
        REPOSITORY_RAW_ROOT="https://raw.githubusercontent.com/kenote/install"
        DOCKER_COMPOSE_REPO="https://github.com"
    else
        REPOSITORY_RAW_ROOT="https://gitee.com/kenote/install/raw"
        DOCKER_COMPOSE_REPO="https://get.daocloud.io"
    fi
    REPOSITORY_RAW_URL="${REPOSITORY_RAW_ROOT}/main/linux/docker/vsftpd"
    curl -s ${REPOSITORY_RAW_ROOT}/main/linux/docker/help.sh | bash -s install
    ROOT_DIR=`[ -f $HOME/.docker_profile ] && cat $HOME/.docker_profile | grep "^DOCKER_WORKDIR" | sed -n '1p' |  sed 's/\(.*\)=\(.*\)/\2/g' || echo "/home/docker-data"`
}

read_vsftpd_env() {
    CONTAINER_ID=`docker container ls -a -q -f "ancestor=fauria/vsftpd"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${yellow}Vsftpd Server 未安装${plain}"
        return 1
    fi
    status=`docker inspect ${CONTAINER_ID} | jq -r ".[0].State.Status"`
    echo
    if [[ $status == 'running' ]]; then
        echo -e "状态 -- ${green}运行中${plain}"
    else
        echo -e "状态 -- ${red}停止${plain}"
    fi
}

set_vsftpd_env() {
    _path=$1
    FTP_USER="admin"
    DATA_DIR="./data"
    FTP_PORT="21"
    if [[ $_path == '' ]]; then
        while read -p "安装路径[vsftpd]: " _name
        do
            if [[ $_path = '' ]]; then
                _name="vsftpd"
            fi
            _path=`[[ $_name =~ ^\/ ]] && echo "${_name}" || echo "${ROOT_DIR}/${_name}"`
            break
        done
    else
        CONTAINER_ID=`docker ps -q -f "ancestor=fauria/vsftpd"`
        FTP_USER=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Env[]" | grep "FTP_USER" | sed 's/\(.*\)=\(.*\)/\2/g'`
        FTP_PASS=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Env[]" | grep "FTP_PASS" | sed 's/\(.*\)=\(.*\)/\2/g'`
        FTP_PORT=`docker inspect ${CONTAINER_ID} | jq -r ".[0].NetworkSettings.Ports[\"21/tcp\"][0].HostPort"`
        DATA_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Mounts[] | select(.Destination == \"/home/vsftpd\") | .Source"`
    fi

    while read -p "数据存放路径[$DATA_DIR]: " _data_dir
    do
        if [[ $_data_dir == '' ]]; then
            _data_dir=$DATA_DIR
        fi
        break
    done

    while read -p "默认FTP用户[$FTP_USER]: " _ftp_user
    do
        if [[ $_ftp_user == '' ]]; then
            _ftp_user=$FTP_USER
        fi
        break
    done

    while read -p "默认FTP密码: " _ftp_pass
    do
        if [[ $_ftp_pass == '' ]]; then
            _ftp_pass=`[[ $FTP_PASS == '' ]] && echo $(strings /dev/urandom |tr -dc A-Za-z0-9 | head -c16; echo) || echo $FTP_PASS`;
        fi
        break
    done

    while read -p "FTP端口[${FTP_PORT}]:" _ftp_port
    do
        if [[ $_ftp_port = '' ]]; then
            _ftp_port=$FTP_PORT
        fi
        if [[ ! $_ftp_port =~ ^[1-9]{1}[0-9]{1,4}$ ]]; then
            echo -e "${red}FTP端口格式错误！${plain}"
            continue
        fi
        if [[ $_ftp_port == ${FTP_PORT} ]]; then
            break
        fi
        if (lsof -i:$_ftp_port  &> /dev/null); then
            echo -e "${red}FTP端口-[${_ftp_port}]-被占用，请更换${plain}"
            continue
        fi
        break
    done
}

install_vsftpd() {
    echo -e "${green}----------------"
    echo -e "  安装 Vsftpd Server"
    echo -e "----------------${plain}"
    
    # 设置面板参数
    set_vsftpd_env
    VSFTPD_PATH=$_path
    FTP_USER=$_ftp_user
    FTP_PASS=$_ftp_pass
    DATA_DIR=$_data_dir
    FTP_PORT=$_ftp_port

    # 创建工作目录
    mkdir -p ${VSFTPD_PATH}
    cd ${VSFTPD_PATH}

    # 拉取 docker-compose.yml
    echo -e "正在配置 Vsftpd 参数..."
    wget --no-check-certificate -qO docker-compose.yml $REPOSITORY_RAW_URL/compose.yml
    # 创建环境变量
    echo -e "DATA_DIR=${DATA_DIR}" > .env
    echo -e "FTP_USER=${FTP_USER}" >> .env
    echo -e "FTP_PASS=${FTP_PASS}" >> .env
    echo -e "FTP_PORT=${FTP_PORT}" >> .env
    # 创建vsftpd配置
    mkdir -p conf
    wget --no-check-certificate -qO conf/vsftpd.conf $REPOSITORY_RAW_URL/conf/vsftpd.conf
    wget --no-check-certificate -qO run-vsftpd.sh $REPOSITORY_RAW_URL/run-vsftpd.sh
    chmod +x run-vsftpd.sh

    # 启动 Vsftpd
    echo -e "正在启动 Vsftpd..."
    docker-compose up -d

    txt2json conf/virtual_users.txt | jq > conf/virtual_users.json
}

set_vsftpd() {
    CONTAINER_ID=`docker ps -q -f "ancestor=fauria/vsftpd"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}Vsftpd Server 未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------"
    echo -e "  配置 Vsftpd Server"
    echo -e "----------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    set_vsftpd_env ${WORK_DIR}
    FTP_USER=$_ftp_user
    FTP_PASS=$_ftp_pass
    DATA_DIR=$_data_dir
    FTP_PORT=$_ftp_port

    # 创建环境变量
    echo
    echo -e "正在配置 Vsftpd 参数..."
    echo -e "DATA_DIR=${DATA_DIR}" > .env
    echo -e "FTP_USER=${FTP_USER}" >> .env
    echo -e "FTP_PASS=${FTP_PASS}" >> .env
    echo -e "FTP_PORT=${FTP_PORT}" >> .env

    # 刷新虚拟用户
    if [ -f conf/virtual_users.json ]; then
        json=`echo $(cat conf/virtual_users.json)`
        json=`echo $json | jq ".[0][\"useraname\"]=\"${FTP_USER}\""`
        json=`echo $json | jq ".[0][\"password\"]=\"${FTP_PASS}\""`
        echo $json | jq > conf/virtual_users.json
    else
        txt2json conf/virtual_users.txt | jq > conf/virtual_users.json
    fi
    json2txt "$(cat conf/virtual_users.json)" > conf/virtual_users.txt
    /usr/bin/db_load -T -t hash -f ${WORK_DIR}/conf/virtual_users.txt ${WORK_DIR}/conf/virtual_users.db

    # 重启 Vsftpd
    clear
    echo -e "正在启动 Vsftpd..."
    docker-compose restart
}

remove_vsftpd() {
    echo -e "${green}----------------"
    echo -e "  卸载 Vsftpd Server"
    echo -e "----------------${plain}"
    if (docker ps -q -f "ancestor=fauria/vsftpd"  &> /dev/null); then
        CONTAINER_ID=`docker ps -q -f "ancestor=fauria/vsftpd"`
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        docker-compose down -v
        rm -rf ${WORK_DIR}
        echo -e "${green}Vsftpd Server 卸载完成${plain}"
    fi
}

# 虚拟用户列表
virtual_user_list() {
    CONTAINER_ID=`docker ps -q -f "ancestor=fauria/vsftpd"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}Vsftpd Server未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------------------------------------"
    echo -e "  虚拟用户列表"
    echo -e "----------------------------------------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    json=`cat conf/virtual_users.json`
    list=(`echo $json | jq '.[].username' | sed -E 's/\"//g'`)
    echo -e "ID\t用户名"
    _id=0
    for item in ${list[@]};
    do
        # json=`echo $json | jq ".[] | select(.username == \"$item\") | .password"`
        if [[ $_id -gt 0 ]]; then
            echo -e "${_id}\t${item}"
        fi
        _id=`expr $_id + 1`
    done

    username=""
    echo
    while read -p "请输入ID可操作节点或输入 x 返回: " num
    do
        if [[ $num == 'x' ]]; then
            return 1
        elif [[ $num =~ ^[0-9]+$ && $num -lt $_id && $num -ge 0 ]]; then
            username=`echo $json | jq ".[$num][\"username\"]" | sed -E 's/\"//g'`
        else
            echo -e "${red}输入正确的ID或 x 返回${plain}"
            continue
        fi
        break
    done

    # echo -e "username -- $username"

    clear
    echo -e "${green}--------------------------------"
    echo -e "  选择虚拟用户 -[${username}]-"
    echo -e "--------------------------------${plain}"
    echo
    list=(编辑 删除 返回)
    _opt=""
    select item in ${list[@]};
    do
        _opt=$item
        # echo -e "$item"
        case "${item}" in
        编辑)
            edit_virtual_user ${username}
        ;;
        删除)
            confirm "确定要删除虚拟用户-[${username}]-?" "n"
            if [[ $? == 0 ]]; then
                del_virtual_user ${username}
            else
                show_menu 5
            fi
        ;;
        返回)
            show_menu 5
        ;;
        esac
        break
    done

}

# 添加虚拟用户
add_virtual_user() {
    CONTAINER_ID=`docker ps -q -f "ancestor=fauria/vsftpd"`
    if [[ $CONTAINER_ID == '' ]]; then
        echo -e "${red}Vsftpd Server未安装${plain}"
        return 1
    fi
    echo -e "${green}----------------------------------------------"
    echo -e "  添加虚拟用户"
    echo -e "----------------------------------------------${plain}"

    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`

    cd ${WORK_DIR}

    while read -p "用户名: " _username
    do
        if [[ $_username == '' ]]; then
            echo -e "${yellow}用户名不能为空！${plain}"
            continue
        fi
        is_name=`cat conf/virtual_users.json | jq ".[] | select(.username == \"$_username\")"`
        if [[ $is_name != '' ]]; then
            echo -e "${red}用户名已存在，请另起一个${plain}"
            continue
        fi
        break
    done
    while read -p "密码[留空表示随机]: " _password
    do
        if [[ $_password == '' ]]; then
            _password=`strings /dev/urandom |tr -dc A-Za-z0-9 | head -c16; echo`
        fi
        break
    done

    json=`cat conf/virtual_users.json`
    _id=`echo $json | jq ". | length"`
    json=`echo $json | jq ".[$_id]={\"username\":\"$_username\",\"password\":\"$_password\"}"`
    echo $json | jq > conf/virtual_users.json
    json2txt "$json" > conf/virtual_users.txt

    /usr/bin/db_load -T -t hash -f ${WORK_DIR}/conf/virtual_users.txt ${WORK_DIR}/conf/virtual_users.db

    
    docker-compose restart
    echo
    echo -e " 用户名: $_username"
    echo -e " 密码: $_password"
    echo
}

# 修改虚拟用户
edit_virtual_user() {
    _username=$1
    clear
    echo -e "${green}--------------------------------"
    echo -e "  编辑虚拟用户 -[${_username}]-"
    echo -e "--------------------------------${plain}"

    while read -p "密码: " _password
    do
        if [[ $_password == '' ]]; then
            echo -e "不修改密码"
            return 1
        fi
        break
    done

    CONTAINER_ID=`docker ps -q -f "ancestor=fauria/vsftpd"`
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}

    json=`cat conf/virtual_users.json`
    _id=`echo $json | jq "[ .[] | .username == \"$_username\" ] | index(true)"`
    json=`echo $json | jq ".[$_id][\"password\"]=\"$_password\""`
    echo $json | jq > conf/virtual_users.json
    json2txt "$json" > conf/virtual_users.txt

    /usr/bin/db_load -T -t hash -f ${WORK_DIR}/conf/virtual_users.txt ${WORK_DIR}/conf/virtual_users.db

    # if [[ $_id == 0 ]]; then
    #     sed -i "s/$(cat .env | grep -E "^FTP_PASS=")/FTP_PASS=$_password/" .env
    #     docker-compose down
    #     docker-compose up -d
    # else
    #     docker-compose restart
    # fi
    docker-compose restart
}

# 删除虚拟用户
del_virtual_user() {
    _username=$1
    CONTAINER_ID=`docker ps -q -f "ancestor=fauria/vsftpd"`
    WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
    cd ${WORK_DIR}
    json=`cat conf/virtual_users.json | jq "del(.[] | select(.username == \"$_username\"))"`
    json2txt "$json" > conf/virtual_users.txt
    /usr/bin/db_load -T -t hash -f ${WORK_DIR}/conf/virtual_users.txt ${WORK_DIR}/conf/virtual_users.db

    docker-compose restart
}

# text转json
txt2json() {
    file=$1
    list=(`cat $file`)
    i=0
    json="[]"
    for item in "${list[@]}";
    do
        if [[ $_user == '' ]]; then
            _user=$item
        else
            json=`echo $json | jq ".[$i][\"useraname\"]=\"$_user\""`
            json=`echo $json | jq ".[$i][\"password\"]=\"$item\""`
            _user=""
            i=`expr $i + 1`
        fi
    done
    echo $json
}

# json转txt
json2txt() {
    json=$1
    info=""
    list=(`echo $json | jq '.[].username' | sed -E 's/\"//g'`)
    info=""
    password=""
    for username in ${list[@]}
    do
        if [[ $password != '' ]]; then
            info="$info\n"
        fi
        password=`echo $json | jq ".[] | select(.username == \"$username\") | .password" | sed -E 's/\"//g'`
        info="$info$username\n$password"
    done
    echo -e $info
}

show_menu() {
    num=$1
    if [[ $1 == '' ]]; then
        echo -e "
  ${green}Vsftpd 管理${plain}

  ${green} 0${plain}. 退出脚本
 ------------------------
  ${green} 1${plain}. 查看状态
  ${green} 2${plain}. 启动 Vsftpd
  ${green} 3${plain}. 停止 Vsftpd
  ${green} 4${plain}. 重启 Vsftpd
 ------------------------
  ${green} 5${plain}. 虚拟用户管理
  ${green} 6${plain}. 添加虚拟用户
 ------------------------
  ${green} 7${plain}. 安装 Vsftpd
  ${green} 8${plain}. 卸载 Vsftpd
  ${green} 9${plain}. 配置参数
  "
        echo && read -p "请输入选择 [0-9]: " num
        echo
    fi
    case "${num}" in
    0  )
        if [[ $CURRENT_DIR == '/root/.scripts/docker/vsftpd' ]]; then
            run_script ../project.sh
        else
            exit 0
        fi
    ;;
    1  )
        clear
        read_vsftpd_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    2 | 3 | 4 )
        clear
        read_vsftpd_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        WORK_DIR=`docker inspect ${CONTAINER_ID} | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]"`
        cd ${WORK_DIR}
        clear
        case "${num}" in
        2)
            if [[ $status == 'running' ]]; then
                confirm "Vsftpd 服务正在运行, 是否要重启?" "n"
                if [[ $? == 0 ]]; then
                    echo
                    docker-compose restart
                else
                    clear
                    show_menu
                    return 0
                fi
            else
                echo
                docker-compose start
            fi
        ;;
        3)
            if [[ $status == 'running' ]]; then
                echo
                docker-compose stop
            else
                echo
                echo -e "${yellow}Vsftpd 服务当前停止状态, 无需操作${plain}"
            fi
        ;;
        4)
            echo
            docker-compose restart
        ;;
        esac
        read_vsftpd_env
        echo
        read  -n1  -p "按任意键继续" key
        clear
        show_menu
    ;;
    5  )
        # 虚拟用户管理
        
        clear
        read_vsftpd_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        
        clear
        virtual_user_list
        if [[ $? == 0 ]]; then
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    6  )
        # 添加虚拟用户
        clear
        read_vsftpd_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        
        clear
        add_virtual_user
        # read_vsftpd_env
        read  -n1  -p "按任意键继续" key
        
        clear
        show_menu
    ;;
    7  )
        clear
        read_vsftpd_env
        if [[ $? == 0 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要安装 Vsftpd 服务吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            install_vsftpd
            echo -e "${green}Vsftpd 服务安装完成${plain}"
            echo
            read_vsftpd_env
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    8  )
        clear
        read_vsftpd_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要卸载 Vsftpd 服务吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            remove_vsftpd
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    9  )
        clear
        read_vsftpd_env
        if [[ $? == 1 ]]; then
            echo
            read  -n1  -p "按任意键继续" key
            clear
            show_menu
            return 1
        fi
        confirm "确定要重新配置 Vsftpd 服务吗?" "n"
        if [[ $? == 0 ]]; then
            clear
            set_vsftpd
            read_vsftpd_env
            read  -n1  -p "按任意键继续" key
        fi
        clear
        show_menu
    ;;
    *  )
        clear
        echo -e "${red}请输入正确的数字 [0-9]${plain}"
        sleep 1
        show_menu
    ;;
    esac
}

run_script() {
    file=$1
    filepath=`echo "$CURRENT_DIR/$file" | sed 's/nginx\/..\///'`
    urlpath=`echo "$filepath" | sed 's/\/root\/.scripts\///'`
    if [[ -f $filepath ]]; then
        sh $filepath "${@:2}"
    else
        mkdir -p $(dirname $filepath)
        wget -O $filepath ${REPOSITORY_RAW_ROOT}/main/linux/$urlpath && chmod +x $filepath && clear && $filepath "${@:2}"
    fi
}

main() {
    case $1 in
    * )
        clear
        show_menu
    ;;
    esac
}

pre_check
main "$@"