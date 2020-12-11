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

#---------------
# Policy:
#
# 1. Manage SELinux
# 2. Manage firewalld
# 3. Manage sshd
# 4. Create admin ssh/{SSH_PORT} with key
#---------------


# 0.
yum -y update

# 1. Manage SELinux
yum -y install policycoreutils-python
semanage port --add --type ssh_port_t --proto tcp ${SSH_PORT}


# 2. Manage firewalld

systemctl -q is-active firewalld
status=$?
if [ "$status" == 0 ]; then
  echo "firewalld running"
else
  echo "firewalld start"
  systemctl start firewalld
fi
systemctl enable firewalld


cat << EOT > /etc/firewalld/services/ssh.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>SSH</short>
  <description>ssh</description>
  <port protocol="tcp" port="${SSH_PORT}"/>
</service>
EOT

firewall-cmd --reload


# 3. Manage sshd

sed -i "s/^#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config
sed -i 's/PermitRootLogin\ yes/PermitRootLogin\ no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication\ yes/PasswordAuthentication\ no/' /etc/ssh/sshd_config
systemctl restart sshd



# 4. create admin user

cat << EOT > /etc/sudoers.d/base
${SSH_USER} ALL=(ALL) ALL
%${SSH_USER} ALL=(ALL) NOPASSWD: ALL
Defaults:${SSH_USER} !requiretty
EOT
chmod 440 /etc/sudoers.d/base

useradd ${SSH_USER}
mkdir /home/${SSH_USER}/.ssh
cat << EOT > /home/${SSH_USER}/.ssh/authorized_keys
${SSH_KEYS}
EOT

chown ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/.ssh
chmod 755 /home/${SSH_USER}/.ssh
chown ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/.ssh/authorized_keys
chmod 644 /home/${SSH_USER}/.ssh/authorized_keys

# Ending

echo "Try follow command :"
echo "ssh ${SSH_USER}@${HOST} -p ${SSH_PORT} -i ${SSH_KEY_NAME}"

reboot
