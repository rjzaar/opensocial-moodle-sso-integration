#!/bin/bash

################################################################################
# OpenSocial + Moodle Fully Integrated SSO Installation Script
# Based on: https://github.com/rjzaar/opensocial-moodle-sso-integration
# 
# This script performs a complete installation of:
# 1. OpenSocial (Drupal) with OAuth Provider module
# 2. Moodle LMS with OpenSocial OAuth authentication plugin
# 3. Full SSO configuration between both platforms
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
}

print_step() {
    echo ""
    echo -e "${CYAN}>>> $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script needs root privileges"
        print_error "Please run with: sudo bash $0"
        exit 1
    fi
}

check_root

# Get the actual user (not root when using sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

print_section "Integrated OpenSocial + Moodle SSO Installation"
echo "This script will install and configure:"
echo "  1. OpenSocial (Drupal) via DDEV"
echo "  2. OpenSocial OAuth Provider module"
echo "  3. Moodle LMS via Nginx"
echo "  4. Moodle OpenSocial OAuth authentication plugin"
echo "  5. Complete SSO integration with automatic user provisioning"
echo ""

# Configuration variables
print_section "Configuration"

# OpenSocial Configuration
OPENSOCIAL_PROJECT="${OPENSOCIAL_PROJECT:-opensocial}"
OPENSOCIAL_VERSION="${OPENSOCIAL_VERSION:-dev-master}"
OPENSOCIAL_PHP_VERSION="8.2"
OPENSOCIAL_MYSQL_VERSION="8.0"
OPENSOCIAL_NODEJS_VERSION="18"

# Moodle Configuration
MOODLE_VERSION="${MOODLE_VERSION:-MOODLE_404_STABLE}"
MOODLE_DIR="/var/www/moodle"
MOODLE_DATA="/var/moodledata"
MOODLE_DB_NAME="moodle"
MOODLE_DB_USER="moodleuser"
MOODLE_DB_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
MYSQL_ROOT_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Domain Configuration
read -p "Enter domain for Moodle (e.g., moodle.example.com or moodle.localhost): " MOODLE_DOMAIN
MOODLE_DOMAIN="${MOODLE_DOMAIN:-moodle.localhost}"

read -p "Enter admin email: " ADMIN_EMAIL
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# OAuth Configuration
OAUTH_CLIENT_ID=$(cat /proc/sys/kernel/random/uuid)
OAUTH_CLIENT_SECRET=$(openssl rand -hex 32)

# OpenSocial site config
OPENSOCIAL_SITE_NAME="OpenSocial Community"
OPENSOCIAL_ADMIN_USER="admin"
OPENSOCIAL_ADMIN_PASS="Admin@123"
OPENSOCIAL_URL="https://${OPENSOCIAL_PROJECT}.ddev.site"

# Moodle admin config
MOODLE_ADMIN_USER="admin"
MOODLE_ADMIN_PASS="Admin@123"

print_status "Configuration set:"
echo "  OpenSocial Project: $OPENSOCIAL_PROJECT"
echo "  OpenSocial URL: $OPENSOCIAL_URL"
echo "  OpenSocial Version: $OPENSOCIAL_VERSION"
echo "  Moodle Domain: $MOODLE_DOMAIN"
echo "  Moodle Directory: $MOODLE_DIR"
echo "  Admin Email: $ADMIN_EMAIL"
echo ""

# Checkpoint and credentials files
CHECKPOINT_FILE="/var/log/opensocial_moodle_sso_install.checkpoint"
CREDENTIALS_FILE="/root/opensocial_moodle_sso_credentials.txt"

# Initialize checkpoint
if [ ! -f "$CHECKPOINT_FILE" ]; then
    touch "$CHECKPOINT_FILE"
fi

# Checkpoint functions
mark_complete() {
    echo "$1=done" >> "$CHECKPOINT_FILE"
}

is_complete() {
    grep -q "^$1=done$" "$CHECKPOINT_FILE" 2>/dev/null
    return $?
}

################################################################################
# PART 1: SYSTEM PREREQUISITES
################################################################################

print_section "PART 1: System Prerequisites"

if ! is_complete "STEP_SYSTEM_UPDATE"; then
    print_step "Updating system packages..."
    apt update && apt upgrade -y
    mark_complete "STEP_SYSTEM_UPDATE"
    print_status "✓ System updated"
else
    print_status "✓ System already updated (skipping)"
fi

if ! is_complete "STEP_PREREQUISITES"; then
    print_step "Installing system prerequisites..."
    
    PACKAGES=(
        "ca-certificates"
        "curl"
        "gnupg"
        "lsb-release"
        "libnss3-tools"
        "apt-transport-https"
        "software-properties-common"
        "git"
        "certbot"
        "python3-certbot-nginx"
        "unzip"
        "wget"
    )
    
    apt install -y "${PACKAGES[@]}"
    mark_complete "STEP_PREREQUISITES"
    print_status "✓ Prerequisites installed"
else
    print_status "✓ Prerequisites already installed (skipping)"
fi

################################################################################
# PART 2: DOCKER AND DDEV INSTALLATION
################################################################################

print_section "PART 2: Docker and DDEV Installation"

if ! is_complete "STEP_DOCKER"; then
    if ! command -v docker &> /dev/null; then
        print_step "Installing Docker..."
        
        # Add Docker's official GPG key
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Set up Docker repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Add user to docker group
        usermod -aG docker $ACTUAL_USER
        
        print_status "✓ Docker installed"
    else
        print_status "✓ Docker already installed"
    fi
    mark_complete "STEP_DOCKER"
else
    print_status "✓ Docker already installed (skipping)"
fi

if ! is_complete "STEP_DDEV"; then
    if ! command -v ddev &> /dev/null; then
        print_step "Installing DDEV..."
        curl -fsSL https://ddev.com/install.sh | bash
        print_status "✓ DDEV installed"
    else
        print_status "✓ DDEV already installed"
    fi
    mark_complete "STEP_DDEV"
else
    print_status "✓ DDEV already installed (skipping)"
fi

if ! is_complete "STEP_MKCERT"; then
    print_step "Installing mkcert for HTTPS..."
    
    if ! command -v mkcert &> /dev/null; then
        curl -fsSL https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64 -o mkcert
        chmod +x mkcert
        mv mkcert /usr/local/bin/
    fi
    
    # Install CA as the actual user
    su - $ACTUAL_USER -c "mkcert -install"
    
    mark_complete "STEP_MKCERT"
    print_status "✓ mkcert installed and CA configured"
else
    print_status "✓ mkcert already installed (skipping)"
fi

################################################################################
# PART 3: MOODLE PREREQUISITES
################################################################################

print_section "PART 3: Moodle Prerequisites"

if ! is_complete "STEP_MOODLE_PACKAGES"; then
    print_step "Installing Moodle packages..."
    
    apt install -y nginx mariadb-server php-fpm php-mysql php-xml php-xmlrpc \
        php-curl php-gd php-imagick php-cli php-dev php-imap php-mbstring \
        php-opcache php-soap php-zip php-intl php-ldap php-json
    
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    print_status "✓ Detected PHP version: $PHP_VERSION"
    
    mark_complete "STEP_MOODLE_PACKAGES"
    print_status "✓ Moodle packages installed"
else
    print_status "✓ Moodle packages already installed (skipping)"
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
fi

if ! is_complete "STEP_PHP_CONFIG"; then
    print_step "Configuring PHP for Moodle..."
    
    PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
    cp "$PHP_INI" "$PHP_INI.backup"
    
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 256M/' $PHP_INI
    sed -i 's/post_max_size = .*/post_max_size = 256M/' $PHP_INI
    sed -i 's/memory_limit = .*/memory_limit = 512M/' $PHP_INI
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' $PHP_INI
    sed -i 's/max_input_time = .*/max_input_time = 300/' $PHP_INI
    sed -i 's/;max_input_vars = .*/max_input_vars = 5000/' $PHP_INI
    
    mark_complete "STEP_PHP_CONFIG"
    print_status "✓ PHP configured"
else
    print_status "✓ PHP already configured (skipping)"
fi

################################################################################
# PART 4: MARIADB CONFIGURATION
################################################################################

print_section "PART 4: MariaDB Configuration"

if ! is_complete "STEP_MARIADB"; then
    print_step "Starting and securing MariaDB..."
    
    systemctl start mariadb
    systemctl enable mariadb
    
    # Secure MariaDB
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';" 2>/dev/null || true
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    mark_complete "STEP_MARIADB"
    print_status "✓ MariaDB configured and secured"
else
    print_status "✓ MariaDB already configured (skipping)"
fi

if ! is_complete "STEP_MOODLE_DATABASE"; then
    print_step "Creating Moodle database..."
    
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS $MOODLE_DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "CREATE USER IF NOT EXISTS '$MOODLE_DB_USER'@'localhost' IDENTIFIED BY '$MOODLE_DB_PASS';"
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON $MOODLE_DB_NAME.* TO '$MOODLE_DB_USER'@'localhost';"
    mysql -uroot -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"
    
    mark_complete "STEP_MOODLE_DATABASE"
    print_status "✓ Moodle database created"
else
    print_status "✓ Moodle database already created (skipping)"
fi

################################################################################
# PART 5: MOODLE INSTALLATION
################################################################################

print_section "PART 5: Moodle Installation"

if ! is_complete "STEP_MOODLE_DOWNLOAD"; then
    print_step "Downloading Moodle..."
    
    cd /var/www
    if [ -d "moodle" ]; then
        mv moodle "moodle.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    git clone -b $MOODLE_VERSION git://git.moodle.org/moodle.git
    
    mark_complete "STEP_MOODLE_DOWNLOAD"
    print_status "✓ Moodle downloaded"
else
    print_status "✓ Moodle already downloaded (skipping)"
fi

if ! is_complete "STEP_MOODLE_DATA"; then
    print_step "Creating Moodle data directory..."
    
    mkdir -p $MOODLE_DATA
    chmod 770 $MOODLE_DATA
    chown -R www-data:www-data $MOODLE_DATA
    chown -R www-data:www-data $MOODLE_DIR
    
    mark_complete "STEP_MOODLE_DATA"
    print_status "✓ Moodle data directory created"
else
    print_status "✓ Moodle data directory already created (skipping)"
fi

if ! is_complete "STEP_MOODLE_NGINX"; then
    print_step "Configuring Nginx for Moodle..."
    
    cat > /etc/nginx/sites-available/moodle <<EOF
server {
    listen 80;
    server_name $MOODLE_DOMAIN;
    root $MOODLE_DIR;
    index index.php index.html index.htm;

    client_max_body_size 256M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ [^/]\.php(/|\$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        include fastcgi_params;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
        fastcgi_read_timeout 300;
    }

    location /dataroot/ {
        internal;
        alias $MOODLE_DATA/;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t
    systemctl restart nginx
    systemctl restart php${PHP_VERSION}-fpm
    
    mark_complete "STEP_MOODLE_NGINX"
    print_status "✓ Nginx configured for Moodle"
else
    print_status "✓ Nginx already configured (skipping)"
fi

if ! is_complete "STEP_MOODLE_CONFIG"; then
    print_step "Creating Moodle configuration..."
    
    cat > $MOODLE_DIR/config.php <<EOF
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = '$MOODLE_DB_NAME';
\$CFG->dbuser    = '$MOODLE_DB_USER';
\$CFG->dbpass    = '$MOODLE_DB_PASS';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = 'http://$MOODLE_DOMAIN';
\$CFG->dataroot  = '$MOODLE_DATA';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0770;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF
    
    chown www-data:www-data $MOODLE_DIR/config.php
    chmod 640 $MOODLE_DIR/config.php
    
    mark_complete "STEP_MOODLE_CONFIG"
    print_status "✓ Moodle configuration created"
else
    print_status "✓ Moodle configuration already exists (skipping)"
fi

if ! is_complete "STEP_MOODLE_INSTALL"; then
    print_step "Installing Moodle via CLI..."
    
    # Run Moodle CLI installation
    sudo -u www-data php $MOODLE_DIR/admin/cli/install.php \
        --lang=en \
        --wwwroot="http://$MOODLE_DOMAIN" \
        --dataroot="$MOODLE_DATA" \
        --dbtype=mariadb \
        --dbhost=localhost \
        --dbname="$MOODLE_DB_NAME" \
        --dbuser="$MOODLE_DB_USER" \
        --dbpass="$MOODLE_DB_PASS" \
        --fullname="Moodle LMS" \
        --shortname="Moodle" \
        --adminuser="$MOODLE_ADMIN_USER" \
        --adminpass="$MOODLE_ADMIN_PASS" \
        --adminemail="$ADMIN_EMAIL" \
        --agree-license \
        --non-interactive
    
    mark_complete "STEP_MOODLE_INSTALL"
    print_status "✓ Moodle installed via CLI"
else
    print_status "✓ Moodle already installed (skipping)"
fi

################################################################################
# PART 6: OPENSOCIAL INSTALLATION
################################################################################

print_section "PART 6: OpenSocial Installation"

OPENSOCIAL_DIR="$ACTUAL_HOME/$OPENSOCIAL_PROJECT"

if ! is_complete "STEP_OPENSOCIAL_DIR"; then
    print_step "Creating OpenSocial project directory..."
    
    su - $ACTUAL_USER -c "mkdir -p $OPENSOCIAL_DIR"
    
    mark_complete "STEP_OPENSOCIAL_DIR"
    print_status "✓ OpenSocial directory created"
else
    print_status "✓ OpenSocial directory already exists (skipping)"
fi

if ! is_complete "STEP_OPENSOCIAL_DDEV"; then
    print_step "Configuring DDEV for OpenSocial..."
    
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev config --project-type=drupal \
        --docroot=html \
        --php-version=$OPENSOCIAL_PHP_VERSION \
        --database=mysql:$OPENSOCIAL_MYSQL_VERSION \
        --nodejs-version=$OPENSOCIAL_NODEJS_VERSION \
        --project-name='$OPENSOCIAL_PROJECT' \
        --create-docroot"
    
    # Create custom DDEV config
    cat > "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml" <<EOF
# OpenSocial custom configuration
webimage_extra_packages: [php${OPENSOCIAL_PHP_VERSION}-gd, php${OPENSOCIAL_PHP_VERSION}-uploadprogress]
php_memory_limit: 512M
hooks:
  post-start:
    - exec: composer install --no-interaction || true
EOF
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$OPENSOCIAL_DIR/.ddev"
    
    mark_complete "STEP_OPENSOCIAL_DDEV"
    print_status "✓ DDEV configured for OpenSocial"
else
    print_status "✓ DDEV already configured (skipping)"
fi

if ! is_complete "STEP_OPENSOCIAL_START"; then
    print_step "Starting DDEV..."
    
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev start"
    
    mark_complete "STEP_OPENSOCIAL_START"
    print_status "✓ DDEV started"
else
    print_status "✓ DDEV already started (skipping)"
fi

if ! is_complete "STEP_OPENSOCIAL_COMPOSER"; then
    print_step "Installing OpenSocial via Composer..."
    
    if [ "$OPENSOCIAL_VERSION" = "dev-master" ]; then
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer create-project goalgorilla/social_template:dev-master . --no-interaction --stability dev"
    else
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer create-project goalgorilla/social_template:$OPENSOCIAL_VERSION . --no-interaction"
    fi
    
    # Install Drush
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer require drush/drush --dev"
    
    mark_complete "STEP_OPENSOCIAL_COMPOSER"
    print_status "✓ OpenSocial installed via Composer"
else
    print_status "✓ OpenSocial already installed (skipping)"
fi

if ! is_complete "STEP_OPENSOCIAL_PRIVATE"; then
    print_step "Configuring private file directory..."
    
    su - $ACTUAL_USER -c "mkdir -p $OPENSOCIAL_DIR/../private"
    su - $ACTUAL_USER -c "chmod 755 $OPENSOCIAL_DIR/../private"
    
    mark_complete "STEP_OPENSOCIAL_PRIVATE"
    print_status "✓ Private directory configured"
else
    print_status "✓ Private directory already configured (skipping)"
fi

if ! is_complete "STEP_OPENSOCIAL_INSTALL"; then
    print_step "Installing Drupal/OpenSocial..."
    
    SETTINGS_DIR="$OPENSOCIAL_DIR/html/sites/default"
    su - $ACTUAL_USER -c "chmod 755 $SETTINGS_DIR"
    
    if [ -f "$SETTINGS_DIR/default.settings.php" ] && [ ! -f "$SETTINGS_DIR/settings.php" ]; then
        su - $ACTUAL_USER -c "cp $SETTINGS_DIR/default.settings.php $SETTINGS_DIR/settings.php"
    fi
    
    su - $ACTUAL_USER -c "chmod 666 $SETTINGS_DIR/settings.php"
    
    # Add private file path
    cat >> "$SETTINGS_DIR/settings.php" <<'EOF'

/**
 * Private file path configuration.
 */
$settings['file_private_path'] = '../private';
EOF
    
    # Install OpenSocial
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush site:install social \
        --account-name='$OPENSOCIAL_ADMIN_USER' \
        --account-pass='$OPENSOCIAL_ADMIN_PASS' \
        --account-mail='$ADMIN_EMAIL' \
        --site-name='$OPENSOCIAL_SITE_NAME' \
        --site-mail='$ADMIN_EMAIL' \
        --locale=en \
        --yes"
    
    # Set proper permissions
    su - $ACTUAL_USER -c "chmod 444 $SETTINGS_DIR/settings.php"
    su - $ACTUAL_USER -c "chmod 755 $SETTINGS_DIR"
    
    mark_complete "STEP_OPENSOCIAL_INSTALL"
    print_status "✓ OpenSocial installed"
else
    print_status "✓ OpenSocial already installed (skipping)"
fi

################################################################################
# PART 7: OAUTH MODULES INSTALLATION
################################################################################

print_section "PART 7: OAuth Modules Installation"

if ! is_complete "STEP_OAUTH_SIMPLE_OAUTH"; then
    print_step "Installing Simple OAuth module..."
    
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer require 'drupal/simple_oauth:^5.2'"
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush en simple_oauth -y"
    
    mark_complete "STEP_OAUTH_SIMPLE_OAUTH"
    print_status "✓ Simple OAuth module installed"
else
    print_status "✓ Simple OAuth already installed (skipping)"
fi

if ! is_complete "STEP_OAUTH_KEYS"; then
    print_step "Generating OAuth keys..."
    
    OAUTH_KEYS_DIR="$OPENSOCIAL_DIR/keys"
    su - $ACTUAL_USER -c "mkdir -p $OAUTH_KEYS_DIR"
    su - $ACTUAL_USER -c "chmod 700 $OAUTH_KEYS_DIR"
    
    # Generate private key
    su - $ACTUAL_USER -c "openssl genrsa -out $OAUTH_KEYS_DIR/private.key 2048"
    
    # Generate public key
    su - $ACTUAL_USER -c "openssl rsa -in $OAUTH_KEYS_DIR/private.key -pubout -out $OAUTH_KEYS_DIR/public.key"
    
    # Set permissions
    su - $ACTUAL_USER -c "chmod 600 $OAUTH_KEYS_DIR/private.key"
    su - $ACTUAL_USER -c "chmod 644 $OAUTH_KEYS_DIR/public.key"
    
    mark_complete "STEP_OAUTH_KEYS"
    print_status "✓ OAuth keys generated"
else
    print_status "✓ OAuth keys already generated (skipping)"
fi

if ! is_complete "STEP_OAUTH_CONFIG"; then
    print_step "Configuring Simple OAuth..."
    
    OAUTH_KEYS_DIR="$OPENSOCIAL_DIR/keys"
    
    # Configure key paths (use absolute paths inside container)
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush config:set simple_oauth.settings public_key '/var/www/html/../keys/public.key' -y"
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush config:set simple_oauth.settings private_key '/var/www/html/../keys/private.key' -y"
    
    # Clear cache
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush cr"
    
    mark_complete "STEP_OAUTH_CONFIG"
    print_status "✓ Simple OAuth configured"
else
    print_status "✓ Simple OAuth already configured (skipping)"
fi

################################################################################
# PART 8: OPENSOCIAL OAUTH PROVIDER MODULE
################################################################################

print_section "PART 8: OpenSocial OAuth Provider Module"

if ! is_complete "STEP_OAUTH_PROVIDER_MODULE"; then
    print_step "Creating OpenSocial OAuth Provider module..."
    
    MODULE_DIR="$OPENSOCIAL_DIR/html/modules/custom/opensocial_oauth_provider"
    su - $ACTUAL_USER -c "mkdir -p $MODULE_DIR/src/Controller"
    su - $ACTUAL_USER -c "mkdir -p $MODULE_DIR/src/Form"
    
    # Create module info file
    cat > "$MODULE_DIR/opensocial_oauth_provider.info.yml" <<'EOF'
name: 'OpenSocial OAuth Provider'
type: module
description: 'Provides OAuth2 authentication endpoints for Moodle integration'
core_version_requirement: ^9 || ^10
package: 'OpenSocial'
dependencies:
  - drupal:user
  - simple_oauth:simple_oauth
EOF
    
    # Create module file
    cat > "$MODULE_DIR/opensocial_oauth_provider.module" <<'EOF'
<?php

/**
 * @file
 * Contains opensocial_oauth_provider.module.
 */

use Drupal\Core\Routing\RouteMatchInterface;

/**
 * Implements hook_help().
 */
function opensocial_oauth_provider_help($route_name, RouteMatchInterface $route_match) {
  switch ($route_name) {
    case 'help.page.opensocial_oauth_provider':
      $output = '';
      $output .= '<h3>' . t('About') . '</h3>';
      $output .= '<p>' . t('Provides OAuth2 authentication endpoints for Moodle integration.') . '</p>';
      return $output;

    default:
  }
}
EOF
    
    # Create routing file
    cat > "$MODULE_DIR/opensocial_oauth_provider.routing.yml" <<'EOF'
opensocial_oauth_provider.userinfo:
  path: '/oauth/userinfo'
  defaults:
    _controller: '\Drupal\opensocial_oauth_provider\Controller\UserInfoController::getUserInfo'
  requirements:
    _permission: 'access content'
  options:
    no_cache: TRUE

opensocial_oauth_provider.settings:
  path: '/admin/config/opensocial/oauth-provider'
  defaults:
    _form: '\Drupal\opensocial_oauth_provider\Form\SettingsForm'
    _title: 'OAuth Provider Settings'
  requirements:
    _permission: 'administer site configuration'
EOF
    
    # Create UserInfo Controller
    cat > "$MODULE_DIR/src/Controller/UserInfoController.php" <<'EOF'
<?php

namespace Drupal\opensocial_oauth_provider\Controller;

use Drupal\Core\Controller\ControllerBase;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Drupal\Core\Session\AccountInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Returns responses for OAuth userinfo endpoint.
 */
class UserInfoController extends ControllerBase {

  /**
   * The current user.
   *
   * @var \Drupal\Core\Session\AccountInterface
   */
  protected $currentUser;

  /**
   * Constructs a UserInfoController object.
   *
   * @param \Drupal\Core\Session\AccountInterface $current_user
   *   The current user.
   */
  public function __construct(AccountInterface $current_user) {
    $this->currentUser = $current_user;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('current_user')
    );
  }

  /**
   * Returns user information for OAuth.
   *
   * @param \Symfony\Component\HttpFoundation\Request $request
   *   The request object.
   *
   * @return \Symfony\Component\HttpFoundation\JsonResponse
   *   JSON response with user data.
   */
  public function getUserInfo(Request $request) {
    $user = \Drupal::currentUser();
    
    if ($user->isAnonymous()) {
      return new JsonResponse(['error' => 'Unauthorized'], 401);
    }

    $account = \Drupal\user\Entity\User::load($user->id());
    
    $user_data = [
      'sub' => (string) $user->id(),
      'preferred_username' => $user->getAccountName(),
      'email' => $user->getEmail(),
      'email_verified' => TRUE,
    ];

    // Add profile fields if available
    if ($account->hasField('field_profile_first_name')) {
      $user_data['given_name'] = $account->get('field_profile_first_name')->value;
    }
    
    if ($account->hasField('field_profile_last_name')) {
      $user_data['family_name'] = $account->get('field_profile_last_name')->value;
    }

    // Add profile picture if available
    if ($account->hasField('user_picture') && !$account->get('user_picture')->isEmpty()) {
      $file = $account->get('user_picture')->entity;
      if ($file) {
        $user_data['picture'] = file_create_url($file->getFileUri());
      }
    }

    return new JsonResponse($user_data);
  }

}
EOF
    
    # Create Settings Form
    cat > "$MODULE_DIR/src/Form/SettingsForm.php" <<'EOF'
<?php

namespace Drupal\opensocial_oauth_provider\Form;

use Drupal\Core\Form\ConfigFormBase;
use Drupal\Core\Form\FormStateInterface;

/**
 * Configure OpenSocial OAuth Provider settings.
 */
class SettingsForm extends ConfigFormBase {

  /**
   * {@inheritdoc}
   */
  protected function getEditableConfigNames() {
    return ['opensocial_oauth_provider.settings'];
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'opensocial_oauth_provider_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config('opensocial_oauth_provider.settings');

    $form['moodle_url'] = [
      '#type' => 'url',
      '#title' => $this->t('Moodle URL'),
      '#default_value' => $config->get('moodle_url'),
      '#description' => $this->t('The URL of your Moodle installation.'),
      '#required' => TRUE,
    ];

    $form['auto_provision'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Enable automatic user provisioning'),
      '#default_value' => $config->get('auto_provision'),
      '#description' => $this->t('Automatically create Moodle user accounts when they first log in via OAuth.'),
    ];

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    $this->config('opensocial_oauth_provider.settings')
      ->set('moodle_url', $form_state->getValue('moodle_url'))
      ->set('auto_provision', $form_state->getValue('auto_provision'))
      ->save();

    parent::submitForm($form, $form_state);
  }

}
EOF
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$MODULE_DIR"
    
    mark_complete "STEP_OAUTH_PROVIDER_MODULE"
    print_status "✓ OpenSocial OAuth Provider module created"
else
    print_status "✓ OAuth Provider module already created (skipping)"
fi

if ! is_complete "STEP_ENABLE_OAUTH_PROVIDER"; then
    print_step "Enabling OpenSocial OAuth Provider module..."
    
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush en opensocial_oauth_provider -y"
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush cr"
    
    mark_complete "STEP_ENABLE_OAUTH_PROVIDER"
    print_status "✓ OAuth Provider module enabled"
else
    print_status "✓ OAuth Provider module already enabled (skipping)"
fi

if ! is_complete "STEP_CREATE_OAUTH_CLIENT"; then
    print_step "Creating OAuth client for Moodle..."
    
    # Create OAuth consumer via Drush
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush php-eval \"
\\$client = \\Drupal\\consumers\\Entity\\Consumer::create([
  'label' => 'Moodle LMS',
  'client_id' => '$OAUTH_CLIENT_ID',
  'secret' => '$OAUTH_CLIENT_SECRET',
  'confidential' => TRUE,
  'third_party' => TRUE,
  'redirect' => 'http://$MOODLE_DOMAIN/admin/oauth2callback.php',
  'user_id' => NULL,
]);
\\$client->save();
echo 'OAuth client created successfully';
\""
    
    mark_complete "STEP_CREATE_OAUTH_CLIENT"
    print_status "✓ OAuth client created for Moodle"
else
    print_status "✓ OAuth client already created (skipping)"
fi

################################################################################
# PART 9: MOODLE OAUTH PLUGIN INSTALLATION
################################################################################

print_section "PART 9: Moodle OAuth Authentication Plugin"

if ! is_complete "STEP_MOODLE_OAUTH_PLUGIN"; then
    print_step "Creating Moodle OpenSocial OAuth plugin..."
    
    MOODLE_AUTH_DIR="$MOODLE_DIR/auth/opensocial"
    mkdir -p "$MOODLE_AUTH_DIR/lang/en"
    mkdir -p "$MOODLE_AUTH_DIR/db"
    
    # Create version.php
    cat > "$MOODLE_AUTH_DIR/version.php" <<EOF
<?php
defined('MOODLE_INTERNAL') || die();

\$plugin->version   = 2024010100;
\$plugin->requires  = 2022041900; // Moodle 4.0
\$plugin->component = 'auth_opensocial';
\$plugin->maturity  = MATURITY_STABLE;
\$plugin->release   = '1.0.0';
EOF
    
    # Create auth.php
    cat > "$MOODLE_AUTH_DIR/auth.php" <<'AUTHEOF'
<?php
defined('MOODLE_INTERNAL') || die();

require_once($CFG->libdir.'/authlib.php');

/**
 * OpenSocial OAuth2 authentication plugin.
 */
class auth_plugin_opensocial extends auth_plugin_base {

    /**
     * Constructor.
     */
    public function __construct() {
        $this->authtype = 'opensocial';
        $this->config = get_config('auth_opensocial');
    }

    /**
     * Returns true if the username and password work against the authentication plugin.
     *
     * @param string $username The username
     * @param string $password The password
     * @return bool Authentication success or failure.
     */
    public function user_login($username, $password) {
        return false; // OAuth doesn't use traditional login
    }

    /**
     * Returns true if this authentication plugin can change the user's password.
     *
     * @return bool
     */
    public function can_change_password() {
        return false;
    }

    /**
     * Returns the URL for changing the user's password, or empty if the default should be used.
     *
     * @return moodle_url
     */
    public function change_password_url() {
        return null;
    }

    /**
     * Returns true if this authentication plugin can edit the users' profile.
     *
     * @return bool
     */
    public function can_edit_profile() {
        return false;
    }

    /**
     * Returns true if this authentication plugin is 'internal'.
     *
     * @return bool
     */
    public function is_internal() {
        return false;
    }

    /**
     * Indicates if password hashes should be stored in local moodle database.
     *
     * @return bool
     */
    public function prevent_local_passwords() {
        return true;
    }

    /**
     * Returns true if this authentication plugin uses an external source.
     *
     * @return bool
     */
    public function is_synchronised_with_external() {
        return true;
    }

    /**
     * Prints a form for configuring this authentication plugin.
     *
     * @param array $config
     * @param string $err
     * @param array $user_fields
     */
    public function config_form($config, $err, $user_fields) {
        include 'settings.html';
    }

    /**
     * Processes and stores configuration data for this authentication plugin.
     */
    public function process_config($config) {
        if (!isset($config->opensocial_url)) {
            $config->opensocial_url = '';
        }
        if (!isset($config->oauth2_issuer_id)) {
            $config->oauth2_issuer_id = '';
        }
        if (!isset($config->auto_redirect)) {
            $config->auto_redirect = 0;
        }

        set_config('opensocial_url', $config->opensocial_url, 'auth_opensocial');
        set_config('oauth2_issuer_id', $config->oauth2_issuer_id, 'auth_opensocial');
        set_config('auto_redirect', $config->auto_redirect, 'auth_opensocial');

        return true;
    }
}
AUTHEOF
    
    # Create settings.html
    cat > "$MOODLE_AUTH_DIR/settings.html" <<'SETTINGSEOF'
<table cellspacing="0" cellpadding="5" border="0">
<tr>
   <td colspan="3">
        <h2 class="main"><?php print_string('auth_opensocialsettings', 'auth_opensocial'); ?></h2>
   </td>
</tr>
<tr>
    <td align="right"><label for="opensocial_url"><?php print_string('opensocial_url', 'auth_opensocial'); ?></label></td>
    <td>
        <input id="opensocial_url" name="opensocial_url" type="text" size="50" value="<?php echo $config->opensocial_url ?? ''; ?>" />
    </td>
    <td><?php print_string('opensocial_url_desc', 'auth_opensocial'); ?></td>
</tr>
<tr>
    <td align="right"><label for="oauth2_issuer_id"><?php print_string('oauth2_issuer_id', 'auth_opensocial'); ?></label></td>
    <td>
        <input id="oauth2_issuer_id" name="oauth2_issuer_id" type="text" size="10" value="<?php echo $config->oauth2_issuer_id ?? ''; ?>" />
    </td>
    <td><?php print_string('oauth2_issuer_id_desc', 'auth_opensocial'); ?></td>
</tr>
<tr>
    <td align="right"><label for="auto_redirect"><?php print_string('auto_redirect', 'auth_opensocial'); ?></label></td>
    <td>
        <input id="auto_redirect" name="auto_redirect" type="checkbox" value="1" <?php echo !empty($config->auto_redirect) ? 'checked' : ''; ?> />
    </td>
    <td><?php print_string('auto_redirect_desc', 'auth_opensocial'); ?></td>
</tr>
</table>
SETTINGSEOF
    
    # Create language file
    cat > "$MOODLE_AUTH_DIR/lang/en/auth_opensocial.php" <<'LANGEOF'
<?php
$string['pluginname'] = 'OpenSocial OAuth2';
$string['auth_opensocialdescription'] = 'OpenSocial OAuth2 authentication';
$string['auth_opensocialsettings'] = 'OpenSocial OAuth2 Settings';
$string['opensocial_url'] = 'OpenSocial URL';
$string['opensocial_url_desc'] = 'The base URL of your OpenSocial installation (e.g., https://opensocial.example.com)';
$string['oauth2_issuer_id'] = 'OAuth2 Issuer ID';
$string['oauth2_issuer_id_desc'] = 'The ID of the OAuth2 issuer configured in Moodle';
$string['auto_redirect'] = 'Auto-redirect to OpenSocial login';
$string['auto_redirect_desc'] = 'Automatically redirect users to OpenSocial login page';
LANGEOF
    
    chown -R www-data:www-data "$MOODLE_AUTH_DIR"
    
    mark_complete "STEP_MOODLE_OAUTH_PLUGIN"
    print_status "✓ Moodle OAuth plugin created"
else
    print_status "✓ Moodle OAuth plugin already created (skipping)"
fi

################################################################################
# PART 10: MOODLE OAUTH CONFIGURATION
################################################################################

print_section "PART 10: Configuring OAuth in Moodle"

if ! is_complete "STEP_MOODLE_OAUTH_SERVICE"; then
    print_step "Configuring OAuth2 service in Moodle..."
    
    # Create OAuth2 issuer via Moodle CLI
    sudo -u www-data php $MOODLE_DIR/admin/cli/cfg.php \
        --name=auth_oauth2_issuer \
        --set="OpenSocial"
    
    print_warning "OAuth2 service must be configured via web interface"
    print_status "Please complete the following steps in Moodle admin:"
    echo "  1. Go to: Site administration > Server > OAuth 2 services"
    echo "  2. Click 'Create new custom service'"
    echo "  3. Use these settings:"
    echo "     Name: OpenSocial"
    echo "     Client ID: $OAUTH_CLIENT_ID"
    echo "     Client secret: $OAUTH_CLIENT_SECRET"
    echo "     Service base URL: $OPENSOCIAL_URL"
    echo "     Authorization endpoint: $OPENSOCIAL_URL/oauth/authorize"
    echo "     Token endpoint: $OPENSOCIAL_URL/oauth/token"
    echo "     User info endpoint: $OPENSOCIAL_URL/oauth/userinfo"
    
    mark_complete "STEP_MOODLE_OAUTH_SERVICE"
else
    print_status "✓ OAuth service configuration marked (skipping)"
fi

################################################################################
# PART 11: SAVE CREDENTIALS
################################################################################

print_section "PART 11: Saving Installation Information"

cat > "$CREDENTIALS_FILE" <<EOF
========================================
OpenSocial + Moodle SSO Integration
Complete Installation Credentials
========================================
Installation Date: $(date)

OPENSOCIAL (Drupal) INFORMATION:
---------------------------------
Project Directory: $OPENSOCIAL_DIR
Project Name: $OPENSOCIAL_PROJECT
URL: $OPENSOCIAL_URL
Admin Username: $OPENSOCIAL_ADMIN_USER
Admin Password: $OPENSOCIAL_ADMIN_PASS
Admin Email: $ADMIN_EMAIL

DDEV Commands:
  cd $OPENSOCIAL_DIR
  ddev start           - Start project
  ddev stop            - Stop project
  ddev drush uli       - Get admin login link
  ddev launch          - Open in browser
  ddev drush cr        - Clear cache

MOODLE INFORMATION:
-------------------
Installation Directory: $MOODLE_DIR
Data Directory: $MOODLE_DATA
URL: http://$MOODLE_DOMAIN
Admin Username: $MOODLE_ADMIN_USER
Admin Password: $MOODLE_ADMIN_PASS
Admin Email: $ADMIN_EMAIL
Database Name: $MOODLE_DB_NAME
Database User: $MOODLE_DB_USER
Database Password: $MOODLE_DB_PASS
MySQL Root Password: $MYSQL_ROOT_PASS

OAUTH INTEGRATION:
------------------
OAuth Client ID: $OAUTH_CLIENT_ID
OAuth Client Secret: $OAUTH_CLIENT_SECRET
OAuth Keys Directory: $OPENSOCIAL_DIR/keys

OpenSocial OAuth Endpoints:
  Authorization: $OPENSOCIAL_URL/oauth/authorize
  Token: $OPENSOCIAL_URL/oauth/token
  User Info: $OPENSOCIAL_URL/oauth/userinfo

Moodle Redirect URI: http://$MOODLE_DOMAIN/admin/oauth2callback.php

MOODLE WEB CONFIGURATION REQUIRED:
-----------------------------------
Complete these steps in Moodle web interface:

1. Configure OAuth2 Service:
   - Go to: Site administration > Server > OAuth 2 services
   - Click "Create new custom service"
   - Name: OpenSocial
   - Client ID: $OAUTH_CLIENT_ID
   - Client secret: $OAUTH_CLIENT_SECRET
   - Service base URL: $OPENSOCIAL_URL
   - Enabled: Yes
   - Show on login page: Yes
   
2. Configure Endpoints:
   - Authorization endpoint: $OPENSOCIAL_URL/oauth/authorize
   - Token endpoint: $OPENSOCIAL_URL/oauth/token
   - User info endpoint: $OPENSOCIAL_URL/oauth/userinfo
   
3. Configure User Field Mappings:
   - Email address -> email (Every login)
   - First name -> given_name (Every login)
   - Last name -> family_name (Every login)
   - User picture -> picture (Every login)
   
4. Enable OAuth Authentication:
   - Go to: Site administration > Plugins > Authentication > Manage authentication
   - Enable "OAuth 2" authentication
   - Enable "OpenSocial OAuth2" authentication (if visible)

5. Test SSO:
   - Log out of Moodle
   - Visit: http://$MOODLE_DOMAIN
   - Click "OpenSocial" login button
   - Authenticate with OpenSocial credentials

NEXT STEPS:
-----------
1. Access OpenSocial: $OPENSOCIAL_URL
   Login: $OPENSOCIAL_ADMIN_USER / $OPENSOCIAL_ADMIN_PASS

2. Access Moodle: http://$MOODLE_DOMAIN
   Login: $MOODLE_ADMIN_USER / $MOODLE_ADMIN_PASS

3. Complete Moodle OAuth2 configuration via web interface (see above)

4. Test SSO login

5. Configure SSL for production:
   For Moodle: sudo certbot --nginx -d $MOODLE_DOMAIN
   For OpenSocial: DDEV uses mkcert (already configured)

TROUBLESHOOTING:
----------------
View OpenSocial logs:
  cd $OPENSOCIAL_DIR && ddev logs

View Moodle logs:
  tail -f /var/log/nginx/error.log
  tail -f $MOODLE_DATA/error.log

Test OAuth endpoints:
  curl $OPENSOCIAL_URL/oauth/authorize
  curl $OPENSOCIAL_URL/oauth/token
  curl $OPENSOCIAL_URL/oauth/userinfo

SECURITY NOTES:
---------------
- Change default admin passwords immediately
- Keep this file secure (contains sensitive credentials)
- Configure firewall rules as needed
- Set up regular backups
- Use HTTPS in production

Checkpoint File: $CHECKPOINT_FILE
Installation Log: /var/log/opensocial_moodle_sso_install.log
========================================
EOF

chmod 600 "$CREDENTIALS_FILE"

print_status "✓ Credentials saved to: $CREDENTIALS_FILE"

################################################################################
# PART 12: FINAL SUMMARY
################################################################################

print_section "Installation Complete!"

echo ""
print_status "OpenSocial Installation:"
echo "  URL: $OPENSOCIAL_URL"
echo "  Admin: $OPENSOCIAL_ADMIN_USER / $OPENSOCIAL_ADMIN_PASS"
echo "  Login command: cd $OPENSOCIAL_DIR && ddev drush uli"
echo "  Launch: cd $OPENSOCIAL_DIR && ddev launch"
echo ""

print_status "Moodle Installation:"
echo "  URL: http://$MOODLE_DOMAIN"
echo "  Admin: $MOODLE_ADMIN_USER / $MOODLE_ADMIN_PASS"
echo "  Database: $MOODLE_DB_NAME"
echo ""

print_status "OAuth Integration:"
echo "  Client ID: $OAUTH_CLIENT_ID"
echo "  Client Secret: [saved in credentials file]"
echo "  OAuth Endpoints configured in OpenSocial"
echo ""

print_warning "IMPORTANT: Complete OAuth Configuration in Moodle Web Interface"
echo ""
echo "Follow these steps:"
echo "  1. Log in to Moodle as admin: http://$MOODLE_DOMAIN"
echo "  2. Go to: Site administration > Server > OAuth 2 services"
echo "  3. Create new custom service with credentials from:"
echo "     sudo cat $CREDENTIALS_FILE"
echo "  4. Configure endpoints and user field mappings"
echo "  5. Enable OAuth 2 authentication"
echo "  6. Test SSO login"
echo ""

print_section "Quick Start Commands"
echo "Access OpenSocial:"
echo "  cd $OPENSOCIAL_DIR"
echo "  ddev launch"
echo ""
echo "Access Moodle:"
echo "  http://$MOODLE_DOMAIN"
echo ""
echo "View credentials:"
echo "  sudo cat $CREDENTIALS_FILE"
echo ""
echo "Check OpenSocial status:"
echo "  cd $OPENSOCIAL_DIR && ddev describe"
echo ""
echo "Check Moodle status:"
echo "  sudo systemctl status nginx"
echo "  sudo systemctl status php${PHP_VERSION}-fpm"
echo ""

print_status "All credentials saved to: $CREDENTIALS_FILE"
print_status "Installation log: $CHECKPOINT_FILE"
print_status "Installation script completed successfully!"

exit 0
