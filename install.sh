#!/bin/bash
#
#       Osachu mail setup
#
#-----------------------------------------------------------

## Install MySQL
apt-get -y install mysql-client mysql-server
echo -e "------- MySQL SETUP ----------"
echo -e "[*] Setting up your MySQL preferences"
echo -e "[*] Please provide your root password:"; read mysql

#
# Get information about the  MySQL user setup
echo -e "\n------- DATABASE SETUP ----------"
echo -e "Please enter the name and password of the\n
MySQL user you want assigned with your database."
echo -e "[*] MySQL database: "; read MDB;
echo -e "[*] MySQL username: "; read MUSER;
echo -e "[*] MySQL user password:"; read MPASS;


## Setup ~/.my.cnf
echo "[client]" > ~/.my.cnf
echo "user=root" >> ~/.my.cnf
echo "pass=\"$mysql\"" >> ~/.my.cnf

echo -e "------- CREATE MAIL DATABASE AND USER ----------"

echo -e "[*] Create database $MDB"
mysql -e "CREATE DATABASE $MDB;"

echo -e "[*] Add MySQL user to database $MDB"
mysql -e "grant usage on *.* to $MUSER@localhost identified by '$MPASS';"
mysql -e "grant all privileges on $MDB.* to $MUSER@localhost ;"

echo -e "[*] Import database configuration"
mysql $MDB < config/mysql/database.sql

echo -e "\n------- Mailserver SETUP ----------"
echo -e "[*] Hostname your'd like to use for your mail server:"; read MHOST;
echo -e "[*] Postmaster email address: "; read MPOSTMASTER;


echo -e "------- INSTALL POSTFIX ----------"
## Install Postfix
apt-get -y install postfix postfix-mysql postfix-pcre 

echo -e "------- INSTALL DOVECOT ----------"
## Install Dovecot
apt-get -y install dovecot-core dovecot-imapd dovecot-lmtpd dovecot-pop3d dovecot-mysql

echo -e "------- INSTALL SPAMASSASSIN ----------"
## Install SpamAssassin
apt-get -y install spamassassin 

## Backup old configurations
echo -e "------- BACKUP CONFIGURATION ----------"
mv /etc/postfix/ /etc/old.postfix/
mv /etc/dovecot/ /etc/old.dovecot/
mkdir /etc/postfix/ /etc/dovecot/ /etc/spamassassin/

echo -e "------- INSTALL OSACHU CONFIGURATION----------"
echo "[*] Postfix"
cp -prfv config/postfix/* /etc/postfix/
cp /etc/old.postfix/dynamicmaps.cf /etc/postfix/

echo "\_ Apply configuration to Postfix"
sed -i "s/HOSTNAME/$MHOST/g" /etc/postfix/main.cf
find /etc/postfix/db/ -type f -name "*.cf" | while read i; do 
  sed -i "s/MUSER/$MUSER/g" "$i"
  sed -i "s/MPASS/$MPASS/g" "$i"
  sed -i "s/MDB/$MDB/g" "$i"
done

echo "[*] Dovecot"
cp -prfv config/dovecot/* /etc/dovecot/
cat config/spamassassin/local.cf > /etc/spamassassin/local.cf

echo "\_ Apply Dovecot configuration"
sed -i "s/POSTMASTER/$MPOSTMASTER/g" /etc/dovecot/dovecot.conf
sed -i "s/MUSER/$MUSER/g" /etc/dovecot/dovecot-sql.conf
sed -i "s/MDB/$MDB/g" /etc/dovecot/dovecot-sql.conf
sed -i "s/MPASS/$MPASS/g" /etc/dovecot/dovecot-sql.conf


##
## Configure the templates with this information
##
## Postfix



echo "------------- GENERATE A POSTFIX TLS CERTIFICATE"
mkdir -p /etc/postfix/ssl/{public,private}
openssl req -new -x509 -days 3650 -nodes -out /etc/postfix/ssl/public/smtpd.pem -keyout /etc/postfix/ssl/private/smtpd.pem

# Use the same info for Dovecot
echo "------------- SETUP DOVECOT SSL"
mkdir -p /etc/dovecot/{certs,private}
cp /etc/postfix/ssl/public/smtpd.pem /etc/dovecot/certs/server.pem
cp /etc/postfix/ssl/private/smtpd.pem /etc/dovecot/private/server.key

## Enable SpamAssassin
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/spamassassin



##
## Reconfigure postfix plugins to ensure everything's generated correctly
service postfix restart
service dovecot restart
service spamassassin restart
