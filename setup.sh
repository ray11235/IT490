#!/bin/bash
set -e

UCID="###"
UCID_PASSWORD="###"
HOSTNAME="test-individual"
RABBITMQ_USER="adminrzh"
RABBITMQ_PASSWORD="IT490123"
GITHUB_REPO="https://github.com/MattToegel/IT490.git"
INSTALL_DIR="/home/$UCID/it490"

echo "Setting hostname to $HOSTNAME..."
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts

echo "Updating system and installing prerequisites..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl gnupg git vim

echo "Creating user $UCID..."
useradd -m -s /bin/bash "$UCID"
echo "$UCID:$UCID_PASSWORD" | chpasswd
usermod -aG sudo "$UCID"
echo "User $UCID created with sudo privileges"

echo "Configuring SSH for $UCID..."
mkdir -p /home/"$UCID"/.ssh
chmod 700 /home/"$UCID"/.ssh
touch /home/"$UCID"/.ssh/authorized_keys
chmod 600 /home/"$UCID"/.ssh/authorized_keys
chown -R "$UCID":"$UCID" /home/"$UCID"/.ssh

echo "Installing Erlang and RabbitMQ..."

curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/setup.deb.sh' | bash
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/setup.deb.sh' | bash
apt-get update -y
apt-get install -y erlang-base erlang-nox rabbitmq-server
systemctl enable rabbitmq-server
systemctl start rabbitmq-server

echo "Configuring RabbitMQ..."
rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"
rabbitmqctl set_user_tags "$RABBITMQ_USER" administrator
rabbitmqctl set_permissions -p "/" "$RABBITMQ_USER" ".*" ".*" ".*"
rabbitmq-plugins enable rabbitmq_management
systemctl restart rabbitmq-server

echo "Installing PHP and Composer..."
apt-get install -y php php-cli php-mbstring unzip
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

echo "Cloning IT490 repository..."
sudo -u "$UCID" git clone "$GITHUB_REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"
sudo -u "$UCID" composer install
chown -R "$UCID":"$UCID" "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

echo "Configuring firewall..."
ufw allow 22
ufw allow 5672
ufw allow 15672
ufw --force enable

echo "Setup complete! To test RabbitMQ:"
echo "1. Open two SSH sessions to the VM as $UCID user"
echo "2. In the first session, run:"
echo "   cd $INSTALL_DIR"
echo "   php RabbitMQServerSample.php"
echo "3. In the second session, run:"
echo "   cd $INSTALL_DIR"
echo "   php RabbitMQClientSample.php"
echo "4. The client should send a message, and the server should receive and display it"
echo "Note: Ensure your SSH public key is added to /home/$UCID/.ssh/authorized_keys"
echo "RabbitMQ Management UI is available at http://<VM_EXTERNAL_IP>:15672"
echo "Login with user: $RABBITMQ_USER, password: $RABBITMQ_PASSWORD"