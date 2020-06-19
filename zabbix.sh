#!/bin/bash

[ -z "`rpm -qa | grep httpd`" ] && yum -y install httpd || echo 'httpd is installed.'
[ -n "`command -v mysqld_safe`" -o -n "`command -v mysqld`" ] && echo "Please uninstall MySQL by yourself." && exit 1 || yum -y install mariadb-server

systemctl start mariadb && systemctl enable mariadb
passwd1=`strings /dev/urandom | tr -dc A-Za-z0-9 | head -c20` && echo "root:${passwd1}" >> /tmp/mysql_passwd
passwd2=`strings /dev/urandom | tr -dc A-Za-z0-9 | head -c20` && echo "zabbix:${passwd2}" >> /tmp/mysql_passwd
mysqladmin -u root password "${passwd1}"

mysql -uroot -p${passwd1} -e "CREATE DATABASE zabbix character set utf8 collate utf8_bin;"
mysql -uroot -p${passwd1} -e "Grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '${passwd2}';"
mysql -uroot -p${passwd1} -e "flush privileges;"

[ -n "`rpm -qa | grep php`" ] && rpm -qa | grep php | xargs yum -y remove
yum -y install https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
rm -f /etc/yum.repos.d/epel.repo && curl -L http://mirrors.aliyun.com/repo/epel-7.repo -o /etc/yum.repos.d/epel.repo
yum -y install php72w php72w-cli php72w-common php72w-bcmath php72w-gd \
               php72w-ldap php72w-mbstring php72w-mysql php72w-pdo php72w-xml

sed -i 's#^;date.timezone.*#date.timezone = Asia/Shanghai#' /etc/php.ini
sed -i 's/^post_max_size.*/post_max_size = 16M/' /etc/php.ini
sed -i 's/^max_execution_time.*/max_execution_time = 300/' /etc/php.ini
sed -i 's/^max_input_time.*/max_input_time = 300/' /etc/php.ini

cat > /etc/yum.repos.d/zabbix.repo<< 'EOF'
[zabbix]
name=Zabbix Official Repository - $basearch
baseurl=http://mirrors.aliyun.com/zabbix/zabbix/4.4/rhel/7/$basearch/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX-A14FE591

[zabbix-debuginfo]
name=Zabbix Official Repository debuginfo - $basearch
baseurl=http://mirrors.aliyun.com/zabbix/zabbix/4.4/rhel/7/$basearch/debuginfo/
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX-A14FE591
gpgcheck=0
EOF

yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent
yum -y install wqy-microhei-fonts
mv /usr/share/fonts/dejavu/DejaVuSans.ttf /usr/share/fonts/dejavu/DejaVuSans.ttf.bak
cp /usr/share/fonts/wqy-microhei/wqy-microhei.ttc /usr/share/fonts/dejavu/DejaVuSans.ttf
zcat `ls /usr/share/doc/zabbix-server-mysql* -d`/create.sql.gz | mysql -uzabbix -p${passwd2} zabbix
sed -i "s/^# DBPassword=/DBPassword=${passwd2}/" /etc/zabbix/zabbix_server.conf
sed -i 's@# php_value date.timezone.*@php_value date.timezone = Asia/Shanghai@' /etc/httpd/conf.d/zabbix.conf

systemctl enable zabbix-server zabbix-agent httpd
systemctl start zabbix-server zabbix-agent httpd

echo -e "\033[32mZabbix installed successfully. MySQL password is writed in /tmp/mysql_passwd.\033[0m"
echo -e "\033[32mPlease visit http://ip/zabbix\033[0m"