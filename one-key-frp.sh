#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# Export
export PATH
export FRP_VERSION=0.43.0

set_text_color() {
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}

print_welcome() {
    local clear_flag=""
    clear_flag=$1
    if [[ ${clear_flag} == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+------------------------------------------------------------+"
    echo "|        frp one-key install script, Author rickgcn          |"
    echo "|           A tool to auto install frps on Linux             |"
    echo "+------------------------------------------------------------+"
    echo ""
}

# Update the script itself

# Check if user is root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_welcome
        echo "Error: This script must be run as root!" 1>&2
        exit 1
    fi
}

# Check OS
checkos() {
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        OS=CentOS
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        OS=Debian
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        OS=Ubuntu
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        OS=Fedora
    else
        echo "Error: Not support OS!"
        exit 1
    fi
}

# Get OS version
get_version() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE "[0-9.]+" /etc/redhat-release
    else
        grep -oE "[0-9.]+" /etc/issue
    fi
}

# Get CentOS version
get_centos_version() {
    local code=$1
    local version="$(get_version)"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ]; then
        return 0
    else
        return 1
    fi
}

check_centos_version() {
    if get_centos_version 5; then
        echo "Error: Not support CentOS 5.x, please change to CentOS 6,7 or Debian or Ubuntu or Fedora and try again."
        exit 1
    fi
}

# Check Architecture
check_architecture() {
    ARCHS=""
    if [[ $(getconf WORD_BIT) = '32' && $(getconf LONG_BIT) = '64' ]]; then
        Is_64bit='y'
        ARCHS="amd64"
    else
        Is_64bit='n'
        ARCHS="386"
    fi
}

install_dependancy() {
    local wget_flag=''
    local killall_flag=''
    local netstat_flag=''
    wget --version >/dev/null 2>&1
    wget_flag=$?
    killall -V >/dev/null 2>&1
    killall_flag=$?
    netstat --version >/dev/null 2>&1
    netstat_flag=$?
    if [[ ${wget_flag} -gt 1 ]] || [[ ${killall_flag} -gt 1 ]] || [[ ${netstat_flag} -gt 6 ]]; then
        echo -e "${COLOR_GREEN} Install support packs...${COLOR_END}"
        if [ "${OS}" == 'CentOS' ]; then
            yum install -y wget psmisc net-tools
        else
            apt-get -y update && apt-get -y install wget psmisc net-tools
        fi
    fi
}

create_systemd_frpc() {
    touch /usr/lib/systemd/system/frpc.service
    cat >/usr/lib/systemd/system/frpc.service <<-EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/bin/frpc -c /etc/frp/frpc.ini
ExecReload=/usr/bin/frpc reload -c /etc/frp/frpc.ini
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

create_systemd_frps() {
    touch /usr/lib/systemd/system/frps.service
    cat >/usr/lib/systemd/system/frps.service <<-EOF
[Unit]
Description=Frp Server Service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/bin/frps -c /etc/frp/frps.ini
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

clear
check_root
set_text_color
checkos
check_centos_version
check_architecture
install_dependancy
clear
action=$1
[ -z $1 ]
case "$action" in
install)
    print_welcome
    FRP_FILENAME="frp_${FRP_VERSION}_linux_${ARCHS}"
    mkdir -p /tmp/frp
    cd /tmp/frp
    wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_FILENAME}.tar.gz
    tar -zxvf ${FRP_FILENAME}.tar.gz
    mkdir -p /etc/frp
    mv ${FRP_FILENAME}/*.ini /etc/frp
    mv ${FRP_FILENAME}/frpc ${FRP_FILENAME}/frps /usr/bin
    create_systemd_frpc
    create_systemd_frps
    systemctl unmask frpc
    systemctl unmask frps
    rm -rf ${FRP_FILENAME}
    rm -rf ${FRP_FILENAME}.tar.gz
    echo -e "${COLOR_GREEN}Install Complete."
    echo -e "${COLOR_BLUE}Run $(basename $0) config to edit the configuration file."
    echo -e "${COLOR_BLUE}You can use the follow command to enable frp Server: "
    echo -e "${COLOR_PINK} systemctl enable frps"
    echo -e "${COLOR_PINK} systemctl restart frps"
    echo -e "${COLOR_BLUE}And you can use the follow command to enable frp Client: "
    echo -e "${COLOR_PINK} systemctl enable frpc"
    echo -e "${COLOR_PINK} systemctl restart frpc${COLOR_END}"
    ;;
config)
    print_welcome
    echo -e "${COLOR_BLUE}Choose Configuration File.\n"
    echo -e "${COLOR_PINK}1. frpc"
    echo -e "${COLOR_PINK}2. frps"
    read -p "" which_config
    if [[ $which_config == 1 ]]; then
        echo -e "${COLOR_BLUE}Using nano to open file...${COLOR_END}"
        nano /etc/frp/frpc.ini
    elif [[ $which_config == 2 ]]; then
        echo -e "${COLOR_BLUE}Using nano to open file...${COLOR_END}"
        nano /etc/frp/frps.ini
    else
        echo -e "${COLOR_RED}Error: Please enter the correct number!${COLOR_END}"
        exit 1
    fi
    ;;
uninstall)
    print_welcome
    echo -e "${COLOR_RED}Warning: Are you sure to uninstall frp? [y/n]${COLOR_END}"
    read -p "" is_uninstall
    if [[ $is_uninstall == 'y' ]] || [[ $is_uninstall == 'Y' ]]; then
        systemctl stop frpc
        systemctl stop frps
        systemctl disable frpc
        systemctl disable frps
        rm -f /usr/lib/systemd/system/frpc.service
        rm -f /usr/lib/systemd/system/frps.service
        rm -rf /etc/frp
        rm -f /usr/bin/frpcss
        rm -f /usr/bin/frps
        echo -e "${COLOR_GREEN}Uninstall Complete.${COLOR_END}"
        exit 0
    else
        echo -e "${COLOR_END}Aborted."
        exit 1
    fi
    ;;
update)
    print_welcome
    echo "update"
    ;;
*)
    print_welcome
    echo -e "${COLOR_RED}Arguments error! [${action} ]"
    echo -e "Usage: $(basename $0) { install | uninstall | update | config }${COLOR_END}"
    RET_VAL=1
    ;;
esac
