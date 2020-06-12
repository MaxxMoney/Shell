#!/bin/bash

[ -z $(command -v gcc) ] || [ -z $(command -v make) ] && yum -y install gcc make

curl -L https://github.com/happyfish100/libfastcommon/archive/V1.0.43.tar.gz -o /tmp/libfastcommon.tar.gz
tar xf /tmp/libfastcommon.tar.gz -C /tmp && cd /tmp/libfastcommon-1.0.43/
./make.sh && ./make.sh install

curl -L https://github.com/happyfish100/fastdfs/archive/V6.06.tar.gz -o /tmp/fastdfs.tar.gz
tar xf /tmp/fastdfs.tar.gz -C /tmp && cd /tmp/fastdfs-6.06/
./make.sh && ./make.sh install

cd /etc/fdfs/
for i in `ls`; do cp -a $i `echo $i | awk -F. '{print $1"."$2}'`; done
mkdir -p /opt/fdfs/{client,storage,tracker}
myip=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d '/' -f1)

sed -i "s#^base_path.*#base_path = /opt/fdfs/client#" client.conf
sed -i "s/^tracker_server/#&/" client.conf
sed -i "/#tracker_server = 192.168.0.197:22122/a\tracker_server = ${myip}:22122" client.conf

sed -i "s#^base_path.*#base_path = /opt/fdfs/storage#" storage.conf
sed -i "s#^store_path0.*#store_path0 = /opt/fdfs/storage#" storage.conf
sed -i "s/^tracker_server/#&/" storage.conf
sed -i "/#tracker_server = 192.168.209.122:22122/a\tracker_server = ${myip}:22122" storage.conf

sed -i "s#^base_path.*#base_path = /opt/fdfs/tracker#" tracker.conf
sed -i "s/^store_group.*/store_group = group1/" tracker.conf

service fdfs_trackerd start && chkconfig fdfs_trackerd on
service fdfs_storaged start && chkconfig fdfs_storaged on

curl -L https://github.com/happyfish100/fastdfs-nginx-module/archive/V1.22.tar.gz -o /tmp/fastdfs-nginx-module.tar.gz
tar xf /tmp/fastdfs-nginx-module.tar.gz -C /tmp/

yum -y install gcc-c++ pcre-devel zlib-devel
groupadd nginx
useradd nginx -g nginx -s /sbin/nologin -M
curl -L http://nginx.org/download/nginx-1.18.0.tar.gz -o /tmp/nginx.tar.gz
tar xf /tmp/nginx.tar.gz -C /tmp
cd /tmp/nginx-1.18.0/
./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --user=nginx --group=nginx --add-module=/tmp/fastdfs-nginx-module-1.22/src
make && make install
mkdir -p /etc/nginx/conf.d
sed -i "2a\user nginx;" /etc/nginx/nginx.conf
sed -i "/^http/a\    include conf.d\/\*\.conf;" /etc/nginx/nginx.conf

cat > /usr/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

cd /tmp/fastdfs-6.06/conf/
cp http.conf mime.types /etc/fdfs/

cd /tmp/fastdfs-nginx-module-1.22/
cp src/mod_fastdfs.conf /etc/fdfs/

cd /etc/fdfs/
sed -i "s/^tracker_server.*/tracker_server=${myip}:22122/" mod_fastdfs.conf
sed -i "s/^url_have_group_name.*/url_have_group_name = true/" mod_fastdfs.conf
sed -i "s#^store_path0.*#store_path0=/opt/fdfs/storage#" mod_fastdfs.conf

cat > /etc/nginx/conf.d/fdfs.conf <<EOF
server {
    listen       80;
    server_name  _;

    location / {
        ngx_fastdfs_module;
    }
}
EOF
chown -R nginx:nginx /etc/nginx
nginx -t &>/dev/null && systemctl start nginx && systemctl enable nginx || echo "Config error"