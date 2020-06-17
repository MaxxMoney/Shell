[ -z `command -v java` ] && yum -y install java-1.8.0-openjdk

ver=3.24.0-02
curl -L http://download.sonatype.com/nexus/3/nexus-${ver}-unix.tar.gz -o /tmp/nexus.tar.gz
tar xf /tmp/nexus.tar.gz -C /opt/
mv /opt/nexus-${ver} /opt/nexus

useradd nexus
chown -R nexus:nexus /opt/nexus /opt/sonatype-work

cat > /usr/lib/systemd/system/nexus.service <<EOF
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start nexus && systemctl enable nexus
echo -e "\033[32mNexus installed successfully.\033[0m"
echo -e "\033[32mNexus admin password is $(cat /opt/sonatype-work/nexus3/admin.password)\033[0m"