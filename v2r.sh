#!/bin/bash

check_os() {
if [[ ! -f /etc/redhat-release ]];then
  echo "System is not CentOS7."
  exit
elif [[ $(cat /etc/redhat-release | sed -r 's/.*([0-9]+)\..*/\1/') -ne '7' ]];then
  echo "System is not CentOS7."
  exit
fi
}

init_config() {
systemctl disable firewalld && systemctl stop firewalld
systemctl disable NetworkManager && systemctl stop NetworkManager
systemctl disable postfix && systemctl stop postfix && yum remove -y postfix
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
timedatectl set-timezone Asia/Shanghai
yum -y install unzip
}

install_nginx() {
read -p "Your domain is:" domain
cat > /etc/yum.repos.d/nginx.repo <<'EOF'
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/$basearch/
gpgcheck=0
enabled=1
EOF

yum -y install nginx
mkdir -p /etc/nginx/ssl

cat > /etc/nginx/conf.d/default.conf <<EOF
server {
  listen 80;
  server_name ${domain};
  location / {
    root html;
  }
}
EOF

systemctl start nginx && systemctl enable nginx
}

acme() {
curl https://get.acme.sh | sh
cd ~/.acme.sh/
./acme.sh --issue -d ${domain} --nginx
./acme.sh --install-cert -d ${domain} --key-file /etc/nginx/ssl/key.pem --fullchain-file /etc/nginx/ssl/cert.pem --reloadcmd "service nginx force-reload"
}

update_nginx() {
cat > /etc/nginx/conf.d/default.conf <<EOF
server {
  listen 80;
  server_name ${domain};
  location / {
    return 301 https://\$server_name\$request_uri;
  }
}
server {
  listen 443 ssl;
  server_name ${domain};
  ssl_certificate /etc/nginx/ssl/cert.pem;
  ssl_certificate_key /etc/nginx/ssl/key.pem;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers HIGH:!aNULL:!MD5;
  location / {
    root html;
  }
  location /ray {
    proxy_redirect off;
    proxy_pass http://127.0.0.1:120;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$http_host;
  }
}
EOF

nginx -s reload
}

install_v2ray() {
curl -L https://install.direct/go.sh -o /tmp/go.sh
if [[ -f /tmp/go.sh ]];then
  source /tmp/go.sh
fi
myuuid=$(uuidgen)
cat > /etc/v2ray/config.json <<EOF
{
  "log": {
    "access": "",
    "error": "",
    "loglevel": ""
    },
  "inbound": {
    "port": 120,
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [{
      "id": "${myuuid}",
      "alterId": 64
      }]
    },
  "streamSettings": {
    "network": "ws",
    "wsSettings": {
      "path": "/ray"
      }
    }
  },
  "outbound": {
    "protocol": "freedom",
    "settings": {}
  }
}
EOF

rm -f /tmp/go.sh
systemctl start v2ray && systemctl enable v2ray
}

client_config() {
cat > /tmp/client.json <<EOF
{
  "log": {
    "access": "",
    "error": "",
    "loglevel": ""
  },
  "inbound": {
    "port": 1080,
    "listen": "127.0.0.1",
    "protocol": "socks",
    "settings": {
      "auth": "noauth",
      "udp": true,
      "clients": null
    },
    "streamSettings": null
  },
  "outbound": {
    "tag": "agentout",
    "protocol": "vmess",
    "settings": {
      "vnext": [
        {
          "address": "${domain}",
          "port": 443,
          "users": [
            {
              "id": "${myuuid}",
              "alterId": 64
            }
          ]
        }
      ]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tcpSettings": null,
      "kcpSettings": null,
      "wsSettings": {
        "connectionReuse": true,
        "path": "\/ray",
        "headers": null
      }
    },
    "mux": {
      "enabled": true
    }
  },
  "inboundDetour": null,
  "outboundDetour": [
    {
      "protocol": "freedom",
      "settings": {
        "response": null
      },
      "tag": "direct"
    }
  ],
  "dns": {
    "servers": [
      "8.8.8.8",
      "8.8.4.4",
      "localhost"
    ]
  },
  "routing": {
    "strategy": "rules",
    "settings": {
      "domainStrategy": "IPOnDemand",
      "rules": [
 {
          "type": "field",
          "domain": [
            "googleapis.cn",
            "google.cn"
          ],
          "outboundTag": "proxy"
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "domain": [
            "geosite:cn"
          ]
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "ip": [
            "geoip:cn",
            "geoip:private"
          ]
        }
      ]
    }
  }
}
}
EOF

echo
echo -e "The client config is in /tmp/client.json"
}

check_os
init_config
install_nginx
acme
update_nginx
install_v2ray
client_config
