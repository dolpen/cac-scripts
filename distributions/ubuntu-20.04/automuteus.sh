#!/bin/bash
# run as root

set -e

echo ${USER:?'run this script with `USER` env variable'} >/dev/null
echo ${DISCORD_TOKEN:?'run this script with `DISCORD_TOKEN` env variable'} >/dev/null
echo ${AUTOMUTEUS_VER:?'run this script with `AUTOMUTEUS_VER` env variable, see https://github.com/denverquane/automuteus/releases'} >/dev/null
echo ${GALACTUS_VER:?'run this script with `GALACTUS_VER` env variable, see https://github.com/automuteus/galactus/releases'} >/dev/null

if [ "`whoami`" != "root" ]; then
  echo "this script requires superuser authority to setup AutoMuteUs"
  exit 1
fi

apt-get -y git docker.io curl
curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose
chmod a+x /usr/local/bin/docker-compose

HOME=/home/$USER
HOST=`curl inet-ip.info`

mkdir -p $HOME
cd $HOME
git clone https://github.com/denverquane/automuteus.git
cd automuteus/

cat << EOT > ./.env
AUTOMUTEUS_TAG=${AUTOMUTEUS_VER}
GALACTUS_TAG=${GALACTUS_VER}
DISCORD_BOT_TOKEN=${DISCORD_TOKEN}
GALACTUS_HOST=http://${HOST}:8123
GALACTUS_EXTERNAL_PORT=8123
POSTGRES_USER=postgres
POSTGRES_PASS=putsomesecretpasswordhere
EMOJI_GUILD_ID=
WORKER_BOT_TOKENS=
CAPTURE_TIMEOUT=
AUTOMUTEUS_LISTENING=
BROKER_PORT=8123
GALACTUS_PORT=5858
GALACTUS_REDIS_ADDR=redis:6379
AUTOMUTEUS_REDIS_ADDR=redis:6379
GALACTUS_ADDR=http://galactus:5858
POSTGRES_ADDR=postgres:5432
EOT

chown -R $USER:$USER $HOME

# to prepare, $ docker-compose pull
# to launch, $ docker-compose up -d
# to stop, $ docker-compose down

