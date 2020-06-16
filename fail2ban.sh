#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

init_fail2ban() {
[ -z "`grep '^Port' /etc/ssh/sshd_config`" ] && ssh_port=22 || ssh_port=$(grep '^Port' /etc/ssh/sshd_config | awk '{print $2}')

read -p "Type the maxium try time[default 3]:" maxretry
if [ -z "$maxretry" ];then
  maxretry=3
fi
read -p "Type bantime[seconds, default 86400]:" bantime
if [ -z "$bantime" ];then
  bantime=86400
fi

if [[ ! -f /etc/yum.repos.d/epel.repo ]];then
  curl -L http://mirrors.aliyun.com/repo/epel-7.repo -o /etc/yum.repos.d/epel.repo
fi
yum -y install fail2ban
}

config_fail2ban() {
rm -f /etc/fail2ban/jail.local
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1
bantime = 86400
maxretry = 3
findtime = 1800
[ssh-iptables]
enabled = true
filter = sshd
action = iptables[name=SSH, port=ssh, protocol=tcp]
logpath = /var/log/secure
maxretry = $maxretry
findtime = 3600
bantime = $bantime
EOF
}

start_fail2ban() {
systemctl start fail2ban && systemctl enable fail2ban
echo -e "${green}Fail2ban is OK.${plain}"
}

init_fail2ban
config_fail2ban
start_fail2ban