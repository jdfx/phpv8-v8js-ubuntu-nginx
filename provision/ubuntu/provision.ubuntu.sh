#!/usr/bin/env bash

# @todo - DO NOT USE THIS FOR PRODUCTION - UPDATE, memory_limit etc

#####
## GET READY ##
#####

export DEBIAN_FRONTEND=noninteractive

# Update Package List
apt-get update
apt-get upgrade -y

# Force Locale
apt-get install -y locales
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8

#Required for install
apt-get install -y software-properties-common nano curl build-essential wget

# Update Package Lists
apt-get update -y

# PPA
apt-add-repository ppa:ondrej/php -y
apt-add-repository ppa:ondrej/nginx-mainline -y

# Update Package Lists
apt-get update -y

# Basic packages
apt-get install -y dos2unix gcc git git-flow libpcre3-dev apt-utils \
make python3 python2 python-is-python2 python3-pip re2c supervisor unattended-upgrades whois vim zip unzip ninja-build libglib2.0-dev


# #####
# ## NGINX & PHP ##
# #####

# # Create web_runtime_user user
adduser web_runtime_user --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
echo "web_runtime_user:[PUTYOURPASSWORDHERE]" | chpasswd

# # Add web_runtime_user to the sudo group and www-data
usermod -aG sudo web_runtime_user
usermod -aG www-data web_runtime_user

# # Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# # PHP
apt-get install -y nginx
apt-get update -y

apt install php7.4-fpm php7.4-common php7.4-dom php7.4-intl php7.4-xml php7.4-xmlrpc php7.4-curl php7.4-gd php7.4-cli php7.4-dev php7.4-mbstring php7.4-zip php7.4-bcmath -y

# # Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# # Add Composer Global Bin To Path
printf "\nPATH=\"/home/web_runtime_user/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/web_runtime_user/.profile

composer config -g repo.packagist composer https://packagist.org
composer config -g github-protocols https ssh

# # Set Some PHP CLI Settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.4/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.4/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = -1/" /etc/php/7.4/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.4/cli/php.ini
echo "extension=v8js.so" >> /etc/php/7.4/cli/php.ini

sed -i "s/.*daemonize.*/daemonize = no/" /etc/php/7.4/fpm/php-fpm.conf
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.4/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.4/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.4/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = -1/" /etc/php/7.4/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.4/fpm/php.ini
echo "extension=v8js.so" >> /etc/php/7.4/fpm/php.ini

# # Set The Nginx & PHP-FPM User
sed -i '1 idaemon off;' /etc/nginx/nginx.conf
sed -i "s/user www-data;/user web_runtime_user;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

mkdir -p /run/php
touch /run/php/php7.4-fpm.sock
sed -i "s/user = www-data/user = web_runtime_user/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = web_runtime_user/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;listen\.owner.*/listen.owner = web_runtime_user/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;listen\.group.*/listen.group = web_runtime_user/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.4/fpm/pool.d/www.conf

pip3 install --upgrade pip
pip3 install certbot-nginx

# ##
# ## V8 --------
# ##

cd /tmp

# # Install depot_tools first (needed for source checkout)
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"

# # Download v8
fetch v8
cd v8

# # (optional) If you'd like to build a certain version:
git checkout 8.0.426.30
gclient sync

# # Setup GN
tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false

# # Build
ninja -C out.gn/x64.release/

# # Install to /opt/v8/
mkdir -p /opt/v8/lib
mkdir -p /opt/v8/include
cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin \
  out.gn/x64.release/icudtl.dat /opt/v8/lib/
cp -R include/* /opt/v8/include/

apt-get update
apt-get upgrade -y

cd /tmp
git clone https://github.com/phpv8/v8js.git
cd v8js
phpize
./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS"
make
make test
make install

# # Install SQLite
# # apt-get install -y sqlite3 libsqlite3-dev
