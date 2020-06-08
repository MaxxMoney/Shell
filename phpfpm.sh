#!/bin/bash

install_php() {
[ ! -f /etc/yum.repos.d/epel.repo ] && curl -L http://mirrors.aliyun.com/repo/epel-7.repo -o /etc/yum.repos.d/epel.repo
yum -y install https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

echo "a php5.6"
echo "b php7.0"
echo "c php7.2"
read -p "Choose a version[a|b|c]: " ver
case $ver in
  a)
  yum install -y php56w-fpm php56w-pear
  ;;
  b)
  yum install -y php70w-fpm php70w-pear
  ;;
  c)
  yum install -y php72w-fpm php72w-pear
  ;;
  *)
  echo "Error. Please type [a|b|c]"
  ;;
esac
}

config_php() {
read -p "define the user same with nginx: " myuser
sed -i "s/user = apache/user = ${myuser}/" /etc/php-fpm.d/www.conf
sed -i "s/group = apache/group = ${myuser}/" /etc/php-fpm.d/www.conf
read -p "Choose your model[1 is listen9000;2 is socket]: " model
if [ $model -eq 1 ];then
echo 'Your nginx config like:
    location ~ \.php$ {
        root           /path/to/your/web;
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }
'

elif [ $model -eq 2 ];then
  sed -i "s#127.0.0.1:9000#/dev/shm/phpfpm.sock#" /etc/php-fpm.d/www.conf
  sed -i "s/;listen.owner = nobody/listen.owner = ${myuser}/" /etc/php-fpm.d/www.conf
  sed -i "s/;listen.group = nobody/listen.group = ${myuser}/" /etc/php-fpm.d/www.conf
  sed -i "s/^;\(listen.mode\)/\1/" /etc/php-fpm.d/www.conf

echo 'Your nginx config like:
    location ~ \.php$ {
        root           /path/to/your/web;
        fastcgi_pass   unix:/dev/shm/phpfpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }
'
else
  echo "error"
  exit 1
fi
}

install_php
config_php
