#!/bin/bash

###  This shell only supports CentOS7.  ###

install_kernel() {
rpm -i https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/elrepo.repo
sed -i 's/gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/elrepo.repo
yum -y --enablerepo=elrepo-kernel install kernel-ml
}

change_boot() {
uname=$(uname -r)
version=$(grep "^menuentry" /boot/grub2/grub.cfg | cut -d "'" -f2 | awk 'NR==1' | egrep -v "${uname}|rescue")
if [[ -n $version ]];then
  grub2-set-default 0
  echo -e "\033[32mBoot changed successfully.\033[0m\n"
else
  echo -e "\033[31mNew kernel is not in the first place, please change boot manually.\033[0m\n"
  exit 1
fi
}

config_bbr() {
cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
if [[ ${cc} == 'bbr' ]];then
  echo 'BBR is installed, Skip.'
else
  sed -i '/^net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/^net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
  echo -e 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
  sysctl -p > /dev/null 2>&1
fi
}

reboot_os() {
echo -e "\nThe system needs to reboot."
read -p "Do you want to reboot now? (y/n)" is_reboot
if [[ ${is_reboot} == 'y' || ${is_reboot} == 'Y' ]];then
  reboot
else
  echo "Reboot is been canceled."
  exit
fi
}

install_kernel
change_boot
config_bbr
reboot_os
