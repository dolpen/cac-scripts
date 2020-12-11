#!/bin/bash

MYSQL_PORT=13776

yum remove mariadb-libs
rm -rf /var/lib/mysql/
rpm -Uvh http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
yum -y install mysql-community-server
mysql --version

cat << EOT > /etc/my.cnf
[mysqld]
port=${MYSQL_PORT}
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
symbolic-links=0
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
character_set_client_handshake=false
character_set_server=utf8mb4
collation_server=utf8mb4_unicode_ci
default-time-zone='+09:00'
[client]
default_character_set=utf8mb4
EOT

firewall-cmd --zone=public --add-port=${MYSQL_PORT}/tcp --permanent
firewall-cmd --reload
semanage port --add --type mysqld_port_t --proto tcp ${MYSQL_PORT}
systemctl start mysqld

cat /var/log/mysqld.log | grep password
