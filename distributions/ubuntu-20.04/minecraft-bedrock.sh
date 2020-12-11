#!/bin/bash
# run as root

# https://www.minecraft.net/en-us/download/server/bedrock
BDS=https://minecraft.azureedge.net/bin-linux/bedrock-server-1.16.40.02.zip

USER=dolpen
HOME=/opt/bedrock
SERVER=$HOME/server
BACKUP=$HOME/backup
PORT=19132/udp

apt-get -y install unzip
# apt-get -y install screen はすでにある

mkdir -p $SERVER
mkdir -p $BACKUP
wget $BDS -O bedrock.zip
unzip bedrock.zip -d $SERVER
chown -R $USER:$USER $HOME

cat << 'EOS'  > /etc/init.d/bedrock
#!/bin/bash
# /etc/init.d/bedrock
### BEGIN INIT INFO
# Provides:   minecraft
# Required-Start: $local_fs $remote_fs
# Required-Stop:  $local_fs $remote_fs
# Should-Start:   $network
# Should-Stop:    $network
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:    Bedrock server
# Description:    Starts the bedrock server
### END INIT INFO
#Settings
USERNAME=dolpen
SERVICE=bedrock_server
MCHOME=/opt/bedrock
SERVERHOME=${MCHOME}/server
BACKUP=${MCHOME}/backup
INVOCATION="./${SERVICE}"
ME=`whoami`
as_user() {
  if [ $ME == $USERNAME ] ; then
    bash -c "$1"
  else
    su - $USERNAME -c "$1"
  fi
}
mc_start() {
  if  pgrep -u $USERNAME -f $SERVICE > /dev/null
  then
    echo "$SERVICE is already running!"
  else
    echo "Starting $SERVICE..."
    cd $SERVERHOME
    as_user "cd $SERVERHOME && LD_LIBRARY_PATH=. screen -dmS minecraft $INVOCATION"
    sleep 7
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
      echo "$SERVICE is now running."
    else
      echo "Error! Could not start $SERVICE!"
    fi
  fi
}
mc_stop() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null
  then
    echo "Stopping $SERVICE"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map...\"\015'"
    sleep 10
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'"
    sleep 7
  else
    echo "$SERVICE was not running."
  fi
  if pgrep -u $USERNAME -f $SERVICE > /dev/null
  then
    echo "Error! $SERVICE could not be stopped."
  else
    echo "$SERVICE is stopped."
  fi
}
#Start-Stop here
case "$1" in
  start)
    mc_start
    ;;
  stop)
    mc_stop
    ;;
  restart)
    mc_stop
    mc_start
    ;;
  status)
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
      echo "$SERVICE is running."
    else
      echo "$SERVICE is not running."
    fi
    ;;
  *)
  echo "Usage: /etc/init.d/bedrock {start|stop|restart}"
  exit 1
  ;;
esac
exit 0
EOS

chmod 755 /etc/init.d/bedrock

ufw allow ${PORT}