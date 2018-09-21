#!/usr/bin/env bash

COIN_NAME='ANON' #no spaces

#wallet information
WALLET_DOWNLOAD='http://masternodes.alttank.ca/downloads/anon-linux.zip'
WALLET_TAR_FILE='anon-linux.zip'
ZIPTAR='unzip' #can be either unzip or tar -xfzg
EXTRACT_DIR='' #not always necessary, can be blank if zip/tar file has no subdirectories
CONFIG_FOLDER='/root/.anon'
CONFIG_FILE='anon.conf'
COIN_DAEMON='anond'
COIN_CLI='anon-cli'
COIN_PATH='/usr/bin'
ADDNODE1='172.245.97.67'
ADDNODE2='204.152.210.202'
ADDNODE3='96.126.112.77'
PORT='33130'
RPCPORT='19050'

BOOTSTRAP='https://www.dropbox.com/s/raw/xu4c1twns4x7ove/anon-bootstrap.zip'
BOOTSTRAP_ZIP='anon-bootstrap.zip'

FETCHPARAMS='https://raw.githubusercontent.com/anonymousbitcoin/anon/master/anonutil/fetch-params.sh'


#end of required details
#
#
#

echo "=================================================================="
echo "ALTTANK $COIN_NAME MN DEFAULT INSTALLER"
echo "=================================================================="
echo "Installing packages and updates..."
sudo apt-get update -y
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get install git -y
sudo apt-get install curl -y
sudo apt-get install nano -y
sudo apt-get install pwgen -y
sudo apt-get install ufw -y
sudo apt-get install dnsutils -y
sudo apt-get install build-essential libtool autotools-dev pkg-config libssl-dev -y
sudo apt-get install  libc6-dev m4 g++-multilib -y
sudo apt-get install autoconf libtool ncurses-dev unzip git python -y
sudo apt-get install zlib1g-dev wget bsdmainutils automake -y
sudo apt-get install libboost-all-dev -y
sudo apt-get install libevent-dev -y
sudo apt-get install libminiupnpc-dev -y
sudo apt-get install libzmq3-dev -y
sudo apt-get install autoconf -y
sudo apt-get install automake -y
sudo apt-get install unzip -y
sudo apt-get update
sudo apt-get install libdb4.8-dev libdb4.8++-dev -y
sudo apt-get install libminiupnpc-dev libzmq3-dev libevent-pthreads-2.0-5 -y
sudo apt-get install libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev -y
sudo apt-get install libqrencode-dev bsdmainutils -y
echo "Packages complete..."

WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
PASSWORD=`pwgen -1 20 -n`
if [ "x$PASSWORD" = "x" ]; then
    PASSWORD=${WANIP}-`date +%s`
fi

#begin downloading wallet
echo "Killing and removing all old instances of $COIN_NAME and Downloading new wallet..."
sudo killall $COIN_DAEMON > /dev/null 2>&1
cd /usr/bin && sudo rm $COIN_CLI $COIN_DAEMON > /dev/null 2>&1 && sleep 2 && cd

rm -rf $EXTRACT_DIR
rm -rf $WALLET_TAR_FILE
wget -U Mozilla/5.0 $WALLET_DOWNLOAD

$ZIPTAR $WALLET_TAR_FILE
cd $EXTRACT_DIR
sudo chmod +x $COIN_CLI $COIN_DAEMON
cp $COIN_CLI $COIN_DAEMON $COIN_PATH
sudo chmod +× /usr/bin/anon*
cd
rm -rf $EXTRACT_DIR
rm -rf $WALLET_TAR_FILE
#end downloading/cleaning up wallet

wget -U Mozilla/5.0 $BOOTSTRAP
sudo mkdir $CONFIG_FOLDER
unzip $BOOTSTRAP_ZIP -d $CONFIG_FOLDER
rm -rf $BOOTSTRAP_ZIP
echo "downloading chain params"
wget $FETCHPARAMS
sudo bash fetch-params.sh
echo "Done fetching chain params"

echo "Creating Conf File wallet"
sudo touch $CONFIG_FOLDER/$CONFIG_FILE
cat <<EOF > $CONFIG_FOLDER/$CONFIG_FILE
rpcuser=$COIN_NAME
rpcpassword=$PASSWORD
rpcallowip=127.0.0.1
server=1
daemon=1
listen=1
rpcport=$RPCPORT
port=$PORT
externalip=$WANIP
addnode=$ADDNODE1
addnode=$ADDNODE2
addnode=$ADDNODE3
txindex=1
dbcache=50
maxmempool=300
maxconnections=16
maxorphantx=1
banscore=50
rpcthreads=1
EOF

echo "Creating system service file...."
 cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=$CONFIG_FOLDER/$COIN_NAME.pid
ExecStart=$COIN_PATH/$COIN_DAEMON -daemon -conf=$CONFIG_FOLDER/$CONFIG_FILE -datadir=$CONFIG_FOLDER
ExecStop=-$COIN_PATH/$COIN_CLI -conf=$CONFIG_FOLDER/$CONFIG_FILE -datadir=$CONFIG_FOLDER stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
sleep 3
systemctl start $COIN_NAME.service
systemctl enable $COIN_NAME.service >/dev/null 2>&1

echo "Systemctl Complete...."

echo "If you see *error* message, do not worry we are killing wallet again to make sure its dead"
echo ""
echo "=================================================================="
echo "DO NOT CLOSE THIS WINDOW OR TRY TO FINISH THIS PROCESS "
echo "PLEASE WAIT ~2 MINUTES UNTIL YOU SEE THE RELOADING WALLET MESSAGE"
echo "=================================================================="
echo ""

echo "Stopping daemon again and creating final config..."

echo "Configuring firewall..."
#add a firewall
sudo ufw allow $PORT/tcp
sudo ufw allow $RPCPORT/tcp
echo "Basic security completed..."


echo "Installing sentinel..."
cd $CONFIG_FOLDER
sudo apt-get install -y git python-virtualenv

git clone https://github.com/anonymousbitcoin/sentinel.git && cd sentinel
virtualenv ./venv
./venv/bin/pip install -r requirements.txt

echo "Adding crontab jobs..."
crontab -l > tempcron
#echo new cron into cron file
echo "* * * * * cd $CONFIG_FOLDER/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> tempcron
echo "@reboot /bin/sleep 20 ; $COIN_DAEMON -daemon &" >> tempcron

#install new cron file
crontab tempcron
rm tempcron
echo "Sentinel Installed"

echo "Restarting $COIN_NAME wallet with new configs, 30 seconds..."
sudo chmod +x /usr/bin/anon*
$COIN_DAEMON -daemon
sleep 60

echo "Making genkey..."
GENKEY=$($COIN_CLI masternode genkey)

echo "Mining info..."
$COIN_CLI getmininginfo
$COIN_CLI stop

echo "Stopping daemon again and creating final config..."
cat <<EOF > $CONFIG_FOLDER/$CONFIG_FILE
rpcuser=$COIN_NAME
rpcpassword=$PASSWORD
rpcallowip=127.0.0.1
server=1
daemon=1
listen=1
rpcport=$RPCPORT
port=$PORT
externalip=$WANIP
masternode=1
masternodeprivkey=$GENKEY
addnode=$ADDNODE1
addnode=$ADDNODE2
addnode=$ADDNODE3
txindex=1
dbcache=50
maxmempool=300
maxconnections=16
maxorphantx=1
banscore=50
rpcthreads=1
EOF

sleep 30

echo "Starting your ANON NODE with final details"

$COIN_DAEMON -daemon

echo "============================================================================="
echo "COPY THIS TO HOT WALLET CONFIG FILE AND REPLACE TxID and OUTPUT"
echo "WITH THE DETAILS FROM YOUR COLLATERAL TRANSACTION"
echo "MN1 $WANIP:$PORT $GENKEY TxID OUTPUT"
echo "Courtesy of AltTank Shared MASTERNODES"
echo "https://masternodes.alttank.ca"
echo "============================================================================="
sleep 1
