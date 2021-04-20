#!/bin/bash
# https://github.com/INoTime

if [ "$EUID" -ne 0 ]
  then echo "Run as root"
  exit
fi

sudo apt-get update
sudo apt-get upgrade

sudo apt install libmbim-utils net-tools

sudo ifconfig wwan0 up

mbimNetworkConfFile=/etc/mbim-network.conf
if [ ! -f "$mbimNetworkConfFile" ]
then
  sudo touch "$mbimNetworkConfFile"

  if [ -f "$mbimNetworkConfFile" ]
  then
    echo "Created $mbimNetworkConfFile file!"
  else
    echo "Could not created $mbimNetworkConfFile file! Please do it on your own, or restart program!"
  fi

  echo "You have to enter your APN data! If you don't must fill anything, you have to press enter!"

  read -p "APN=" apn
  if [ ! -z "$apn" ]
  then
    sudo sh -c "echo 'APN=$apn' >> $mbimNetworkConfFile"
  fi

  read -p "APN_USER=" apn_user
  if [ ! -z "$apn_user" ]
  then
    sudo echo "\nAPN_USER=$apn_user" >> $mbimNetworkConfFile
  fi

  read -p "APN_PASS=" apn_pass
  if [ ! -z "$apn_pass" ]
  then
    sudo echo "\nAPN_PASS=$apn_pass" >> $mbimNetworkConfFile
  fi

  read -p "APN_AUTH=" apn_auth
  if [ ! -z "$apn_auth" ]
  then
    sudo echo "\nAPN_AUTH=$apn_auth" >> $mbimNetworkConfFile
  fi

  read -p "PROXY=" proxy
  if [ ! -z "$proxy" ]
  then
    sudo echo "\nPROXY=$proxy" >> $mbimNetworkConfFile
  fi
fi

read -sp "Do you have a sim pin? Enter. Else skip: " simPin
if [ ! -z "$simPin" ]
then
    sudo mbimcli -d /dev/cdc-wdm0 -p --enter-pin=$simPin
fi

sudo mbim-network /dev/cdc-wdm0 start

sudo chmod 777 mbim-set-ip.sh
sudo ./mbim-set-ip /dev/cdc-wdm0 wwan0

echo "GSM modem is ready to go!"