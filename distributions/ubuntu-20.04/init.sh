#!/bin/bash

HOST=`curl inet-ip.info`
SSH_PORT=11422
SSH_USER=dolpen
SSH_KEY_NAME='~/.ssh/home.pem'
SSH_KEYS=`cat <<EOT
ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBM00pdbmU5T0w1FNKhXvRxFOY0Uj/dyvE2s63PlJAXaGwZo/WApia1DCnXB6zpNQB5xreb5jNdRR3fpnJmkrQ3Y= dolpen@dolpen.net
ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAje5AzaJgX02bMD/tuRhyqYwDXsyMg0c1NrxlQWRXGb41hViGsbQltQRGJo8rbVTNZJfMEUBmj0PtrwSp18q+avoSuNDNlDn8MmoLuYIMKIVCZuNvJWz5OQ5bVWA5hUoWq58Gp1/3ZQ3Oj9/owRelCwLXf9aohdhsYthXuEGfhsqAGnA7BSV9I29XF1YWI/xmY/hVVqlIFUBkziu9YWLhU8E35f+UBM8vX2YtjqaeXiQPaGz5RIF7SXsCi3fSj3F/jFKaCHbMtPcK1voqpiRveOm36HayCGmMlniVpvPQ8czREKrrjE7cRoxB87b5S4B+7DcLE9gKnrijoC9k/UKPKw==
EOT
`

# 0.

apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install language-pack-ja-base language-pack-ja
update-locale LANG=ja_JP.UTF-8
update-locale LC_ALL=ja_JP.utf8
timedatectl set-timezone Asia/Tokyo

# 1. create admin user

cat << EOT > /etc/sudoers.d/base
${SSH_USER} ALL=(ALL) ALL
%${SSH_USER} ALL=(ALL) NOPASSWD: ALL
Defaults:${SSH_USER} !requiretty
EOT
chmod 440 /etc/sudoers.d/base

adduser ${SSH_USER}
mkdir /home/${SSH_USER}/.ssh
cat << EOT > /home/${SSH_USER}/.ssh/authorized_keys
${SSH_KEYS}
EOT

chown ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/.ssh
chmod 755 /home/${SSH_USER}/.ssh
chown ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/.ssh/authorized_keys
chmod 644 /home/${SSH_USER}/.ssh/authorized_keys

# change vim scheme
echo colorscheme ron > /home/${SSH_USER}/.vimrc
chown ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/.vimrc

# change login shell
chsh -s $(which bash) dolpen
chsh -s $(which bash) root

# 2. Manage ufw

apt-get install -y ufw
sed -i 's/IPV6\=yes/IPV6\=no/' /etc/default/ufw
ufw allow ${SSH_PORT}
ufw default deny
ufw enable
ufw status

# 3. Manage sshd

sed -i "s/^#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config
sed -i 's/PermitRootLogin\ yes/PermitRootLogin\ no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication\ yes/PasswordAuthentication\ no/' /etc/ssh/sshd_config
service ssh restart


# OK

reboot
