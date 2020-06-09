#!/bin/bash

#server
yum -y install chrony ansible

read -p "Type your cidr: " cidr
read -p "Type your netmask: " netmask
cat > /etc/chrony.conf <<EOF
server ntp1.aliyun.com iburst minpoll 4 maxpoll 10
server ntp2.aliyun.com iburst minpoll 4 maxpoll 10
server ntp3.aliyun.com iburst minpoll 4 maxpoll 10
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
allow ${cidr}/${netmask}
local stratum 10
logdir /var/log/chrony
EOF

systemctl start chronyd && systemctl enable chronyd

serverip=`ip addr | grep 'inet ' | egrep -v '127.0.0.1|docker' | awk '{print $2}' | cut -d '/' -f1`
cat > /tmp/chrony_client.conf <<EOF
server ${serverip} iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

#client
echo '
#####################################
## Edit file /tmp/chrony_inventory ##
#####################################'
read -p "Have you writed hosts on /tmp/chrony_inventory?(y/n) " is
if [[ ${is} == 'y' || ${is} == 'Y' ]];then
  ansible all -i /tmp/chrony_inventory -m yum -a "name=chrony state=present" && \
  ansible all -i /tmp/chrony_inventory -m copy -a "src=/tmp/chrony_client.conf dest=/etc/chrony.conf force=yes" && \
  ansible all -i /tmp/chrony_inventory -m service -a "name=chronyd state=started enabled=yes"
  rm -f /tmp/chrony_client.conf
else
  echo "Error."
  exit 1
fi

#chronyc sources -v
#chronyc sourcestats -v
#timedatectl
