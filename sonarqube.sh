#devel才是JDK
yum -y install java-11-openjdk-devel unzip
#这里安装pg10版本
rpm -ivh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sed -i 's/gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/pgdg-redhat-all.repo
sed -i 's#https://download.postgresql.org/pub#http://mirrors.zju.edu.cn/postgresql#' /etc/yum.repos.d/pgdg-redhat-all.repo
yum -y install postgresql10-server postgresql10
/usr/pgsql-10/bin/postgresql-10-setup initdb
systemctl start postgresql-10 && systemctl enable postgresql-10
#创建用户授权并配置密码登录
passwd1=`strings /dev/urandom | tr -dc A-Za-z0-9 | head -c20` && echo "postgres:${passwd1}" >> /tmp/postgres_passwd
passwd2=`strings /dev/urandom | tr -dc A-Za-z0-9 | head -c20` && echo "sonarqube:${passwd2}" >> /tmp/postgres_passwd
sudo -u postgres psql -c "alter user postgres password '${passwd1}';"
sudo -u postgres psql -c "create user sonarqube with password '${passwd2}';"
sudo -u postgres psql -c "create database sonarqube with owner=sonarqube encoding='UTF8' lc_collate='en_US.UTF-8' lc_ctype='en_US.UTF-8';"
sed -ri "s/peer$|ident$/md5/" /var/lib/pgsql/10/data/pg_hba.conf
systemctl restart postgresql-10
#export PGPASSWORD=${passwd1}

curl -L https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.3.1.34397.zip -o /tmp/sonarqube.zip
unzip -q /tmp/sonarqube.zip -d /opt/
mv /opt/sonarqube-8.3.1.34397 /opt/sonarqube

#建立普通用户启动sonarqube
groupadd sonar
useradd sonar -g sonar
#配置文件描述符限制
cat >> /etc/security/limits.conf <<EOF
sonar hard nofile 65536
sonar soft nofile 65536
EOF
#es的配置要求
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

mkdir -p /opt/sonar/{logs,data,temp}
chown -R sonar:sonar /opt/sonar /opt/sonarqube

serverip=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d '/' -f1)
sed -i "s/#sonar.jdbc.username.*/sonar.jdbc.username=sonarqube/" /opt/sonarqube/conf/sonar.properties
sed -i "s/#sonar.jdbc.password.*/sonar.jdbc.password=${passwd2}/" /opt/sonarqube/conf/sonar.properties
sed -i "s@#sonar.jdbc.url=jdbc:postgresql.*@sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube@" /opt/sonarqube/conf/sonar.properties
sed -i "s/#sonar.web.host.*/sonar.web.host=${serverip}/" /opt/sonarqube/conf/sonar.properties
sed -i "s@#sonar.path.logs.*@sonar.path.logs=/opt/sonar/logs@" /opt/sonarqube/conf/sonar.properties
sed -i "s@#sonar.path.data.*@sonar.path.data=/opt/sonar/data@" /opt/sonarqube/conf/sonar.properties
sed -i "s@#sonar.path.temp.*@sonar.path.temp=/opt/sonar/temp@" /opt/sonarqube/conf/sonar.properties

#su - sonar -c "/opt/sonarqube/bin/linux-x86-64/sonar.sh start"
#su - sonar -c "/opt/sonarqube/bin/linux-x86-64/sonar.sh status"

cat > /usr/lib/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=simple
User=sonar
Group=sonar
PermissionsStartOnly=true
ExecStart=/bin/nohup /opt/java/bin/java -Xms512m -Xmx512m -Djava.net.preferIPv4Stack=true -jar /opt/sonarqube/lib/sonar-application-8.3.1.34397.jar
StandardOutput=syslog
LimitNOFILE=65536
LimitNPROC=8192
TimeoutStartSec=5
Restart=always
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start sonarqube && systemctl enable sonarqube
echo -e "\033[32mYour Postgresql password is writed in /tmp/postgres_passwd\033[0m"
echo -e "\033[32mNow you can visit http://${serverip}:9000 [admin:admin]\033[0m"