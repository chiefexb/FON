#!/bin/sh

check_docker() {
docker_chk=`which docker`
compose_chk=`which docker-compose`

if [ -f "$docker_chk" ]

    then
	echo "Great! Docker found!"
    else
        echo "Exit. Docker not found. Please install docker!"
        exit 1
fi

if [ -f "$compose_chk" ]
    then
	echo "Great! Docker-compose found!"
    else
	echo "Exit. Docker-compose not foumd. Please install docker-compose!"
	exit 1
    fi

if [ -d /opt/fido ]
    then
	echo "Error. Directory /opt/fido already exist!"
        exit 1
    else
	return
fi
}

check_docker


mkdir -p /opt/fido/etc/php
mkdir -p /opt/fido/etc/nginx
mkdir -p /opt/fido/data/tmp/in
mkdir -p /opt/fido/data/tmp/out
mkdir -p /opt/fido/data/lib
mkdir -p /opt/fido/data/etc
mkdir -p /opt/fido/data/log
mkdir -p /opt/fido/mysql
mkdir -p /opt/fido/web
mkdir -p /opt/fido/var/run
mkdir -p /opt/fido/var/log
mkdir -p /opt/fido/data/var/xml/archive
mkdir -p /opt/fido/data/inbound
mkdir -p /opt/fido/data/insecure
mkdir -p /opt/fido/data/outbound
mkdir -p /opt/fido/data/msg/dupe
mkdir -p /opt/fido/data/fileareas

cp -R ./samples/binkd/* /opt/fido/etc/
cp -R ./samples/nginx/* /opt/fido/etc/nginx
cp -R ./samples/php-fpm/* /opt/fido/etc/php
cp -R ./samples/husky/* /opt/fido/data/etc
cp ./samples/toss.sh	/opt/fido/data/lib/toss.sh
git clone -b master-php7 https://github.com/kosfango/wfido.git
cp  ./wfido/hpt/filter.pl  /opt/fido/data/lib/filter.pl
sed -i 's/\/home\/fidonet\/var\/fidonet\/xml\/$random_string.xml/\/usr\/local\/fido\/var\/xml\/$random_string.xml/g' /opt/fido/data/lib/filter.pl
cp -R ./wfido/htdocs/* /opt/fido/web/
cp -R ./wfido/scripts/* /opt/fido/data/lib/
        

docker-compose -f ./docker-compose.yml up --build -d

while [ "$(docker exec fido_node ls /var/run/mysqld/mysqld.sock)" != /var/run/mysqld/mysqld.sock ];
do
    echo "Waiting MySQL socket..."
    sleep 5
done

docker restart fon_maria-db_1

while [ "$(docker exec fido_node ls /var/run/mysqld/mysqld.sock)" != /var/run/mysqld/mysqld.sock ];
do
    echo "Waiting MySQL socket..."
    sleep 5
done

docker exec -ti fido_node mysql -u root -ppassword --socket=/var/run/mysqld/mysqld.sock -e "set global sql_mode='NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';"
docker exec -ti fido_node sh -c 'mysql -u root -ppassword --socket=/var/run/mysqld/mysqld.sock < /root/devel/wfido/dump_install.sql'
docker exec -ti fido_node mysql -u root -ppassword --socket=/var/run/mysqld/mysqld.sock -e 'use wfido; ALTER TABLE `messages` ADD FULLTEXT KEY `text` (`text`);'

#Entering variables
read -p 'Please enter your First Name: ' namevar
read -p 'Please enter your Second Name: ' surnamevar
read -p 'Please enter your Fidonet node address (3D format): ' nodeaddrrvar
read -p 'Please enter your station name: ' stnamevar
read -p 'Please enter location of your station (e.g.: Kostroma, Russia): ' locvar
read -p 'Please enter WFIDO domain name for your station (e.g.: wfido.net), if you dont have real domain name try to edit your hosts file: ' wfidovar
read -sp 'Please enter password for .1 point (password for real connections via binkd): ' passvar
echo " "

#Uplink
read -p 'Please enter uplink First Name: ' upnamevar
read -p 'Please enter uplink Second Name: ' upsurnamervar
read -p 'Please enter your uplink address 3D format: ' upnodeaddrrvar
read -p 'Please enter your uplink domain name or IP: ' upnodehostvar
read -sp 'Please enter password for your uplink: ' uppassvar
echo " "

#Editing fido config
sed -i "s/MyFirstName MySecondName/$namevar $surnamevar/g" /opt/fido/data/etc/config
sed -i "s#2:5034\/17#$nodeaddrrvar#" /opt/fido/data/etc/config
sed -i "s/TEST Station/$stnamevar/g" /opt/fido/data/etc/config
sed -i "s/Kostroma, Russia/$locvar/g" /opt/fido/data/etc/config

#Editing links config
sed -i "s#2:5034/17#$nodeaddrrvar#g" /opt/fido/data/etc/links
sed -i "s/UplinkFirstName UplinkSecondName/$upnamevar $upsurnamervar/g" /opt/fido/data/etc/links
sed -i "s#2:9999/99#$upnodeaddrrvar#g" /opt/fido/data/etc/links
sed -i "s/yourpassword/$uppassvar/g" /opt/fido/data/etc/links
sed -i "s/pointpassword/$passvar/g" /opt/fido/data/etc/links
sed -i "s#link MyFirstName MySecondName#link $namevar $surnamevar#g" /opt/fido/data/etc/links

#Editing route config
sed -i "s#2:9999/99#$upnodeaddrrvar#" /opt/fido/data/etc/route
sed -i "s#2:5034/17.\*#${nodeaddrrvar}.\*#" /opt/fido/data/etc/route

#Editing binkdconfig
sed -i "s#2:5034\/17@fidonet#${nodeaddrrvar}@fidonet#" /opt/fido/etc/binkd.conf
sed -i "s/TEST Station/$stnamevar/g" /opt/fido/etc/binkd.conf
sed -i "s/Kostroma, Russia/$locvar/g" /opt/fido/etc/binkd.conf
sed -i "s#MyFirstName MySecondName#${namevar} ${surnamevar}#" /opt/fido/etc/binkd.conf
sed -i "s#2:9999/99@fidonet#${upnodeaddrrvar}@fidonet#" /opt/fido/etc/binkd.conf
sed -i "s/domain.com/$upnodehostvar/g" /opt/fido/etc/binkd.conf
sed -i "s/bosspassword/$uppassvar/g" /opt/fido/etc/binkd.conf
sed -i "s#2:5034\/17.1@fidonet#${nodeaddrrvar}.1@fidonet#" /opt/fido/etc/binkd.conf
sed -i "s/yourpassword/$passvar/g" /opt/fido/etc/binkd.conf

#Edititng toss script
#sed -i "s/\/home\/fidonet\/bin\/sql2pkt.pl/\/opt\/fido\/data\/lib\/sql2pkt.pl/g" /opt/fido/data/lib/toss.sh
#sed -i "s/\/home\/fidonet\/bin\/hpt/\/opt\/fido\/data\/lib\/hpt/g" /opt/fido/data/lib/toss.sh
#sed -i "s/\/home\/fidonet\/bin\/xml2sql.pl/\/opt\/fido\/data\/lib\/xml2sql.pl/g" /opt/fido/data/lib/toss.sh
#sed -i "s/\/var\/www\/wfido\/bin\/fastlink.php/\/opt\/fido\/web\/bin\/fastlink.php/g" /opt/fido/data/lib/toss.sh

#Editing wfido vhost config file
sed -i "s/server_name wfido.net;/server_name ${wfidovar};/g" /opt/fido/etc/nginx/wfido.conf

#Web interface
mv /opt/fido/web/search_mysql.php /opt/fido/web/search.php

sed -i 's|$mywww="http://vds.lushnikov.net/wfido";|$mywww="http://'${wfidovar}'";|g' /opt/fido/web/config.php
sed -i 's|$adminmail="max@lushnikov.net";|$adminmail="support@'${wfidovar}'";|g' /opt/fido/web/config.php
sed -i 's/$webroot=.*/$webroot="";/g' /opt/fido/web/config.php
sed -i 's|$mynode="2:5020/1519";|$mynode="'${nodeaddrrvar}'";|g' /opt/fido/web/config.php

sed -i 's/$sql_base=.*/$sql_base="wfido";/g' /opt/fido/web/config.php
sed -i 's/$sql_host=.*/$sql_host="\/var\/run\/mysqld\/mysqld\.sock";/g' /opt/fido/web/config.php
sed -i 's/$sql_user=.*/$sql_user="wfido";/g' /opt/fido/web/config.php
sed -i 's/$sql_pass=.*/$sql_pass="PASSWORD";/g' /opt/fido/web/config.php

#Patch connection string
sed -i 's/($sql_host, $sql_user, $sql_pass, $sql_base)/(NULL, $sql_user, $sql_pass, $sql_base, NULL, $sql_host)/g' /opt/fido/web/lib/lib.php

#Editing perl scripts
sed -i "s#$inbound='/home/fidonet/var/fidonet/inbound/';#$inbound='/usr/local/fido/inbound/';#" /opt/fido/data/lib/sql2pkt.pl
sed -i "s#$mynode='2:5020/1519';#$mynode='"$nodeaddrrvar"';#g" /opt/fido/data/lib/sql2pkt.pl
sed -i "s#$my_tech_link='2:5020/1519';#$my_tech_link='"$nodeaddrrvar"';#g" /opt/fido/data/lib/sql2pkt.pl
sed -i 's#$sql_user="USER";#$sql_user="wfido";#g' /opt/fido/data/lib/sql2pkt.pl
sed -i 's#$sql_pass="PASS";#$sql_pass="PASSWORD";#g' /opt/fido/data/lib/sql2pkt.pl
sed -i 's#$xml_spool="/home/fidonet/var/fidonet/xml";#$xml_spool="/usr/local/fido/var/xml";#g' /opt/fido/data/lib/xml2sql.pl
sed -i 's#$sql_user="USER";#$sql_user="wfido";#g' /opt/fido/data/lib/xml2sql.pl
sed -i 's#$sql_pass="PASS";#$sql_pass="PASSWORD";#g' /opt/fido/data/lib/xml2sql.pl

sed -i 's/use Digest::Perl::MD5/use Digest::MD5/g' /opt/fido/data/lib/xml2sql.pl
sed -i 's/\$sql_host="127.0.0.1";/\$sql_sock="\/var\/run\/mysqld\/mysqld.sock";/g' /opt/fido/data/lib/xml2sql.pl
sed -i 's/host=\$sql_host"/mysql_socket=\$sql_sock"/g' /opt/fido/data/lib/xml2sql.pl
sed -i 's/\$sql_host="127.0.0.1";/\$sql_sock="\/var\/run\/mysqld\/mysqld.sock";/g' /opt/fido/data/lib/sql2pkt.pl
sed -i 's/host=\$sql_host"/mysql_socket=\$sql_sock"/g' /opt/fido/data/lib/sql2pkt.pl

sed -i 's/# hptperlfile \/home\/username\/fido\/lib\/hptfunctions.pl/hptperlfile \/usr\/local\/fido\/lib\/filter.pl/g' /opt/fido/data/etc/config

#Tossing script
cp ./samples/toss.sh /opt/fido/data/lib/toss.sh
cp ./samples/poll.sh /opt/fido/data/lib/poll.sh
sed -i "s#2:9999/99#$upnodeaddrrvar#g" /opt/fido/data/lib/poll.sh
docker restart fido_node
