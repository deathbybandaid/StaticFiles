#!/bin/bash

VERSION="0.9.12"

# Grab a password for MySQL Root
read -s -p "Enter the password that will be used for MySQL Root: " mysqlrootpassword
debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlrootpassword"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlrootpassword"

# Grab a password for Guacamole Database User Account
read -s -p "Enter the password that will be used for the Guacamole database: " guacdbuserpassword

# Install Features
sudo apt-get update
sudo apt-get -y install build-essential
sudo apt-get -y install libcairo2-dev
sudo apt-get -y install libjpeg-turbo8-dev
sudo apt-get -y install libpng12-dev
sudo apt-get -y install libossp-uuid-dev
sudo apt-get -y install libavcodec-dev
sudo apt-get -y install libavutil-dev
sudo apt-get -y install libswscale-dev
sudo apt-get -y install libfreerdp-dev
sudo apt-get -y install libpango1.0-dev
sudo apt-get -y install libssh2-1-dev
sudo apt-get -y install libtelnet-dev
sudo apt-get -y install libvncserver-dev
sudo apt-get -y install libpulse-dev
sudo apt-get -y install libssl-dev
sudo apt-get -y install libvorbis-dev
sudo apt-get -y install libwebp-dev
sudo apt-get -y install mysql-server
sudo apt-get -y install mysql-client
sudo apt-get -y install mysql-common
sudo apt-get -y install mysql-utilities
sudo apt-get -y install tomcat8
sudo apt-get -y install freerdp
sudo apt-get -y install ghostscript
sudo apt-get -y install jq
sudo apt-get -y install wget
sudo apt-get -y install curl

SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.preferred|rtrimstr("/")')

# Add GUACAMOLE_HOME to Tomcat8 ENV
sudo echo "" >> /etc/default/tomcat8
sudo echo "# GUACAMOLE EVN VARIABLE" >> /etc/default/tomcat8
sudo echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat8

# Download Guacample Files
sudo wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/source/guacamole-server-${VERSION}-incubating.tar.gz
sudo wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-${VERSION}-incubating.war
sudo wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
sudo wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.41.tar.gz

# Extract Guacamole Files
sudo tar -xzf guacamole-server-${VERSION}-incubating.tar.gz
sudo tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
sudo tar -xzf mysql-connector-java-5.1.41.tar.gz

# MAKE DIRECTORIES
sudo mkdir /etc/guacamole
sudo mkdir /etc/guacamole/lib
sudo mkdir /etc/guacamole/extensions

# Install GUACD
cd guacamole-server-${VERSION}-incubating
sudo bash configure --with-init-dir=/etc/init.d
sudo make
sudo make install
sudo ldconfig
sudo systemctl enable guacd
cd ..

# Move files to correct locations
sudo mv guacamole-${VERSION}-incubating.war /etc/guacamole/guacamole.war
sudo ln -s /etc/guacamole/guacamole.war /var/lib/tomcat8/webapps/
sudo ln -s /usr/local/lib/freerdp/* /usr/lib/x86_64-linux-gnu/freerdp/.
sudo cp mysql-connector-java-5.1.41/mysql-connector-java-5.1.41-bin.jar /etc/guacamole/lib/
sudo cp guacamole-auth-jdbc-${VERSION}-incubating/mysql/guacamole-auth-jdbc-mysql-${VERSION}-incubating.jar /etc/guacamole/extensions/

# Configure guacamole.properties
sudo echo "mysql-hostname: localhost" >> /etc/guacamole/guacamole.properties
sudo echo "mysql-port: 3306" >> /etc/guacamole/guacamole.properties
sudo echo "mysql-database: guacamole_db" >> /etc/guacamole/guacamole.properties
sudo echo "mysql-username: guacamole_user" >> /etc/guacamole/guacamole.properties
sudo echo "mysql-password: $guacdbuserpassword" >> /etc/guacamole/guacamole.properties
sudo rm -rf /usr/share/tomcat8/.guacamole
sudo ln -s /etc/guacamole /usr/share/tomcat8/.guacamole

# restart tomcat
sudo service tomcat8 restart

# Create guacamole_db and grant guacamole_user permissions to it

# SQL Code
SQLCODE="
create database guacamole_db;
create user 'guacamole_user'@'localhost' identified by \"$guacdbuserpassword\";
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
flush privileges;"

# Execute SQL Code
sudo echo $SQLCODE | mysql -u root -p$mysqlrootpassword

# Add Guacamole Schema to newly created database
sudo cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword guacamole_db

# Cleanup
sudo rm -rf guacamole-*
sudo rm -rf mysql-connector-java-5.1.41*
