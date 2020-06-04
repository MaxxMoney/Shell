#!/bin/bash

install_kernel() {
rpm -i https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/elrepo.repo
yum -y --enablerepo=elrepo-kernel install kernel-ml
}

change_boot() {
uname=$(uname -r)
version=$(grep "^menuentry" /boot/grub2/grub.cfg | cut -d "'" -f2 | awk 'NR==1' | egrep -v "${uname}|rescue")
if [[ -n $version ]];then
  grub2-set-default 0
  echo -e "Boot changed successfully.\n"
else
  echo -e "New kernel is not in the first place.\n"
  exit 1
fi
}

config_bbr() {
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1
}

rebootos() {
echo -e "\nThe system needs to reboot."
read -p "Do you want to reboot now?(y/n)" is_reboot
if [[ ${is_reboot} == 'y' || ${is_reboot} == 'Y' ]];then
  reboot
else
  echo "Reboot is been canceled."
fi
}

install_kernel
change_boot
config_bbr
rebootos
