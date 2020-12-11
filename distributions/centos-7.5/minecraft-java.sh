#!/bin/bash

HOST=`curl inet-ip.info`
SERVICE_USER=minecraft
SERVICE_NAME=minecraft
SERVECE_PORT=25565
APP_DIR=/home/${SERVICE_USER}/${SERVICE_NAME}
LAUNCH_ARGS="-Xms4G -Xmx4G"
TARGET_JAR="https://launcher.mojang.com/v1/objects/bb2b6b1aefcd70dfd1892149ac3a215f6c636b07/server.jar"


yum -y install java-1.8.0-openjdk
firewall-cmd --add-port=${SERVECE_PORT}/tcp --zone=public --permanent
firewall-cmd --reload

useradd ${SERVICE_USER}
mkdir -p ${APP_DIR}
chown ${SERVICE_USER}:${SERVICE_USER} ${APP_DIR}
chmod 755 ${APP_DIR}

curl -o ${APP_DIR}/minecraft_server.jar ${TARGET_JAR}
chown ${SERVICE_USER}:${SERVICE_USER} ${APP_DIR}/minecraft_server.jar


cat << EOT > ${APP_DIR}/boot.sh
#!/bin/bash
java ${LAUNCH_ARGS} -jar  ${APP_DIR}/minecraft_server.jar nogui
EOT

chown ${SERVICE_USER}:${SERVICE_USER} ${APP_DIR}/boot.sh
chmod a+x ${APP_DIR}/boot.sh

echo "eula=true" > ${APP_DIR}/eula.txt
chown ${SERVICE_USER}:${SERVICE_USER} ${APP_DIR}/eula.txt


cat << EOT > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=Minecraft Server
After=network-online.target
[Service]
ExecStart=/bin/bash ${APP_DIR}/boot.sh
WorkingDirectory=${APP_DIR}
Restart=always
User=${SERVICE_USER}
Group=${SERVICE_USER}
[Install]
WantedBy=multi-user.target
EOT
