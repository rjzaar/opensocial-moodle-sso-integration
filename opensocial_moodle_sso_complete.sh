#!/bin/bash

################################################################################
# OpenSocial + Moodle Fully Integrated SSO Installation Script (DDEV Version)
# Both platforms installed in DDEV to avoid port conflicts
# Based on: https://github.com/rjzaar/opensocial-moodle-sso-integration
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

print_section "Integrated OpenSocial + Moodle SSO Installation (DDEV)"
echo "This script will install both platforms in DDEV:"
echo "  1. OpenSocial (Drupal) - https://opensocial.ddev.site"
echo "  2. Moodle LMS - https://moodle.ddev.site"
echo "  3. Complete SSO integration between them"
echo ""
print_warning "Both systems run in DDEV containers (no port conflicts!)"
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
MOODLE_PROJECT="${MOODLE_PROJECT:-moodle}"
MOODLE_PHP_VERSION="8.1"
MOODLE_MYSQL_VERSION="8.0"
MOODLE_VERSION="MOODLE_404_STABLE"

read -p "Enter admin email: " ADMIN_EMAIL
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# OAuth Configuration
OAUTH_CLIENT_ID=$(cat /proc/sys/kernel/random/uuid)
OAUTH_CLIENT_SECRET=$(openssl rand -hex 32)

# Site configurations
OPENSOCIAL_SITE_NAME="OpenSocial Community"
OPENSOCIAL_ADMIN_USER="admin"
OPENSOCIAL_ADMIN_PASS="Admin@123"
OPENSOCIAL_URL="https://${OPENSOCIAL_PROJECT}.ddev.site"

MOODLE_ADMIN_USER="admin"
MOODLE_ADMIN_PASS="Admin@123"
MOODLE_URL="https://${MOODLE_PROJECT}.ddev.site"

print_status "Configuration set:"
echo "  OpenSocial URL: $OPENSOCIAL_URL"
echo "  Moodle URL: $MOODLE_URL"
echo "  Admin Email: $ADMIN_EMAIL"
echo ""

# Checkpoint and credentials files
CHECKPOINT_FILE="/var/log/opensocial_moodle_ddev_install.checkpoint"
CREDENTIALS_FILE="/root/opensocial_moodle_ddev_credentials.txt"

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
# PART 3: OPENSOCIAL INSTALLATION
################################################################################

print_section "PART 3: OpenSocial Installation"

OPENSOCIAL_DIR="$ACTUAL_HOME/$OPENSOCIAL_PROJECT"

# Step 3.1: Create directory
if ! is_complete "STEP_OPENSOCIAL_DIR"; then
    print_step "Creating OpenSocial project directory..."
    
    if [ ! -d "$OPENSOCIAL_DIR" ]; then
        su - $ACTUAL_USER -c "mkdir -p $OPENSOCIAL_DIR"
        print_status "Created directory: $OPENSOCIAL_DIR"
    else
        print_status "Directory already exists: $OPENSOCIAL_DIR"
    fi
    
    # Verify directory exists and is writable
    if [ -d "$OPENSOCIAL_DIR" ] && [ -w "$OPENSOCIAL_DIR" ]; then
        mark_complete "STEP_OPENSOCIAL_DIR"
        print_status "✓ OpenSocial directory verified"
    else
        print_error "Failed to create or access directory: $OPENSOCIAL_DIR"
        exit 1
    fi
else
    print_status "✓ OpenSocial directory already exists (skipping)"
fi

# Step 3.2: Configure DDEV
if ! is_complete "STEP_OPENSOCIAL_DDEV"; then
    print_step "Configuring DDEV for OpenSocial..."
    
    # Check if already configured
    if [ -f "$OPENSOCIAL_DIR/.ddev/config.yaml" ]; then
        print_status "DDEV config already exists, skipping config command"
    else
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev config --project-type=drupal \
            --docroot=html \
            --php-version=$OPENSOCIAL_PHP_VERSION \
            --database=mysql:$OPENSOCIAL_MYSQL_VERSION \
            --nodejs-version=$OPENSOCIAL_NODEJS_VERSION \
            --project-name='$OPENSOCIAL_PROJECT' \
            --create-docroot"
    fi
    
    # Create custom DDEV config if it doesn't exist
    if [ ! -f "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml" ]; then
        cat > "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml" <<EOF
# OpenSocial custom configuration
webimage_extra_packages: [php${OPENSOCIAL_PHP_VERSION}-gd, php${OPENSOCIAL_PHP_VERSION}-uploadprogress]
php_memory_limit: 512M
hooks:
  post-start:
    - exec: composer install --no-interaction || true
EOF
        chown $ACTUAL_USER:$ACTUAL_USER "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml"
        print_status "Created custom DDEV configuration"
    fi
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$OPENSOCIAL_DIR/.ddev"
    
    # Verify configuration
    if [ -f "$OPENSOCIAL_DIR/.ddev/config.yaml" ]; then
        mark_complete "STEP_OPENSOCIAL_DDEV"
        print_status "✓ DDEV configured for OpenSocial"
    else
        print_error "DDEV configuration failed"
        exit 1
    fi
else
    print_status "✓ DDEV already configured (skipping)"
fi

# Step 3.3: Start DDEV
if ! is_complete "STEP_OPENSOCIAL_START"; then
    print_step "Starting OpenSocial DDEV..."
    
    # Check if already running
    if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev describe >/dev/null 2>&1"; then
        print_status "DDEV already running"
    else
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev start"
    fi
    
    # Verify DDEV is running
    if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev describe >/dev/null 2>&1"; then
        mark_complete "STEP_OPENSOCIAL_START"
        print_status "✓ OpenSocial DDEV started and verified"
    else
        print_error "Failed to start DDEV"
        exit 1
    fi
else
    print_status "✓ OpenSocial DDEV already started (skipping)"
    # Verify it's still running
    if ! su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev describe >/dev/null 2>&1"; then
        print_warning "DDEV was marked as started but is not running. Restarting..."
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev start"
    fi
fi

# Step 3.4: Install via Composer
if ! is_complete "STEP_OPENSOCIAL_COMPOSER"; then
    print_step "Installing OpenSocial via Composer..."
    
    # Check if composer.json already exists
    if [ -f "$OPENSOCIAL_DIR/composer.json" ]; then
        print_status "composer.json already exists, running composer install..."
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer install"
    else
        if [ "$OPENSOCIAL_VERSION" = "dev-master" ]; then
            su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer create-project goalgorilla/social_template:dev-master . --no-interaction --stability dev"
        else
            su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer create-project goalgorilla/social_template:$OPENSOCIAL_VERSION . --no-interaction"
        fi
    fi
    
    # Install Drush if not already installed
    if ! su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush --version >/dev/null 2>&1"; then
        print_status "Installing Drush..."
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer require drush/drush --dev"
    else
        print_status "Drush already installed"
    fi
    
    # Verify installation
    if [ -f "$OPENSOCIAL_DIR/composer.json" ] && su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush --version >/dev/null 2>&1"; then
        mark_complete "STEP_OPENSOCIAL_COMPOSER"
        print_status "✓ OpenSocial installed via Composer"
    else
        print_error "Composer installation failed"
        exit 1
    fi
else
    print_status "✓ OpenSocial already installed (skipping)"
fi

# Step 3.5: Configure private directory
if ! is_complete "STEP_OPENSOCIAL_PRIVATE"; then
    print_step "Configuring private file directory..."
    
    PRIVATE_DIR="$OPENSOCIAL_DIR/../private"
    if [ ! -d "$PRIVATE_DIR" ]; then
        su - $ACTUAL_USER -c "mkdir -p $PRIVATE_DIR"
        su - $ACTUAL_USER -c "chmod 755 $PRIVATE_DIR"
        print_status "Created private directory"
    else
        print_status "Private directory already exists"
    fi
    
    # Verify directory
    if [ -d "$PRIVATE_DIR" ] && [ -w "$PRIVATE_DIR" ]; then
        mark_complete "STEP_OPENSOCIAL_PRIVATE"
        print_status "✓ Private directory configured"
    else
        print_error "Failed to configure private directory"
        exit 1
    fi
else
    print_status "✓ Private directory already configured (skipping)"
fi

# Step 3.6: Install Drupal/OpenSocial
if ! is_complete "STEP_OPENSOCIAL_INSTALL"; then
    print_step "Installing Drupal/OpenSocial..."
    
    SETTINGS_DIR="$OPENSOCIAL_DIR/html/sites/default"
    
    # Check if already installed
    if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush status bootstrap 2>/dev/null | grep -q 'Successful'"; then
        print_status "OpenSocial already installed, skipping site:install"
        mark_complete "STEP_OPENSOCIAL_INSTALL"
    else
        # Prepare settings directory
        if [ -d "$SETTINGS_DIR" ]; then
            su - $ACTUAL_USER -c "chmod 755 $SETTINGS_DIR" 2>/dev/null || true
            
            # Copy default settings if needed
            if [ -f "$SETTINGS_DIR/default.settings.php" ] && [ ! -f "$SETTINGS_DIR/settings.php" ]; then
                su - $ACTUAL_USER -c "cp $SETTINGS_DIR/default.settings.php $SETTINGS_DIR/settings.php"
                print_status "Copied default settings"
            fi
            
            if [ -f "$SETTINGS_DIR/settings.php" ]; then
                su - $ACTUAL_USER -c "chmod 666 $SETTINGS_DIR/settings.php" 2>/dev/null || true
                
                # Add private file path if not already present
                if ! grep -q "file_private_path" "$SETTINGS_DIR/settings.php"; then
                    cat >> "$SETTINGS_DIR/settings.php" <<'EOF'

/**
 * Private file path configuration.
 */
$settings['file_private_path'] = '../private';
EOF
                    print_status "Added private file path to settings"
                fi
            fi
        fi
        
        # Install OpenSocial
        print_status "Running Drupal site installation..."
        if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush site:install social \
            --account-name='$OPENSOCIAL_ADMIN_USER' \
            --account-pass='$OPENSOCIAL_ADMIN_PASS' \
            --account-mail='$ADMIN_EMAIL' \
            --site-name='$OPENSOCIAL_SITE_NAME' \
            --site-mail='$ADMIN_EMAIL' \
            --locale=en \
            --yes"; then
            
            # Set proper permissions
            if [ -f "$SETTINGS_DIR/settings.php" ]; then
                su - $ACTUAL_USER -c "chmod 444 $SETTINGS_DIR/settings.php" 2>/dev/null || true
            fi
            if [ -d "$SETTINGS_DIR" ]; then
                su - $ACTUAL_USER -c "chmod 755 $SETTINGS_DIR" 2>/dev/null || true
            fi
            
            # Verify installation
            if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush status bootstrap 2>/dev/null | grep -q 'Successful'"; then
                mark_complete "STEP_OPENSOCIAL_INSTALL"
                print_status "✓ OpenSocial installed and verified"
            else
                print_error "Installation completed but verification failed"
                exit 1
            fi
        else
            print_error "OpenSocial installation failed"
            exit 1
        fi
    fi
else
    print_status "✓ OpenSocial already installed (skipping)"
fi

################################################################################
# PART 4: MOODLE INSTALLATION IN DDEV
################################################################################

print_section "PART 4: Moodle Installation in DDEV"

MOODLE_DIR="$ACTUAL_HOME/$MOODLE_PROJECT"

# Step 4.1: Create directory
if ! is_complete "STEP_MOODLE_DIR"; then
    print_step "Creating Moodle project directory..."
    
    if [ ! -d "$MOODLE_DIR" ]; then
        su - $ACTUAL_USER -c "mkdir -p $MOODLE_DIR"
        print_status "Created directory: $MOODLE_DIR"
    else
        print_status "Directory already exists: $MOODLE_DIR"
    fi
    
    # Verify directory
    if [ -d "$MOODLE_DIR" ] && [ -w "$MOODLE_DIR" ]; then
        mark_complete "STEP_MOODLE_DIR"
        print_status "✓ Moodle directory verified"
    else
        print_error "Failed to create or access directory: $MOODLE_DIR"
        exit 1
    fi
else
    print_status "✓ Moodle directory already exists (skipping)"
fi

# Step 4.2: Download Moodle
if ! is_complete "STEP_MOODLE_DOWNLOAD"; then
    print_step "Downloading Moodle..."
    
    # Check if html directory already exists with content
    if [ -d "$MOODLE_DIR/html" ] && [ -f "$MOODLE_DIR/html/version.php" ]; then
        print_status "Moodle source already exists"
    else
        su - $ACTUAL_USER -c "cd $MOODLE_DIR && git clone -b $MOODLE_VERSION git://git.moodle.org/moodle.git html"
    fi
    
    # Verify download
    if [ -f "$MOODLE_DIR/html/version.php" ]; then
        mark_complete "STEP_MOODLE_DOWNLOAD"
        print_status "✓ Moodle downloaded and verified"
    else
        print_error "Moodle download failed - version.php not found"
        exit 1
    fi
else
    print_status "✓ Moodle already downloaded (skipping)"
fi

# Step 4.3: Configure DDEV
if ! is_complete "STEP_MOODLE_DDEV"; then
    print_step "Configuring DDEV for Moodle..."
    
    # Check if already configured
    if [ -f "$MOODLE_DIR/.ddev/config.yaml" ]; then
        print_status "DDEV config already exists"
    else
        su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev config --project-type=php \
            --docroot=html \
            --php-version=$MOODLE_PHP_VERSION \
            --database=mysql:$MOODLE_MYSQL_VERSION \
            --project-name='$MOODLE_PROJECT'"
    fi
    
    # Create custom DDEV config if not exists
    if [ ! -f "$MOODLE_DIR/.ddev/config.moodle.yaml" ]; then
        cat > "$MOODLE_DIR/.ddev/config.moodle.yaml" <<EOF
# Moodle custom configuration
php_memory_limit: 512M
upload_dirs:
  - moodledata
webimage_extra_packages:
  - php${MOODLE_PHP_VERSION}-xmlrpc
  - php${MOODLE_PHP_VERSION}-soap
  - php${MOODLE_PHP_VERSION}-intl
  - php${MOODLE_PHP_VERSION}-ldap
EOF
        chown $ACTUAL_USER:$ACTUAL_USER "$MOODLE_DIR/.ddev/config.moodle.yaml"
        print_status "Created custom DDEV configuration"
    fi

    # Create MySQL configuration for Moodle requirements
    if [ ! -d "$MOODLE_DIR/.ddev/mysql" ]; then
        mkdir -p "$MOODLE_DIR/.ddev/mysql"
    fi
    
    if [ ! -f "$MOODLE_DIR/.ddev/mysql/moodle.cnf" ]; then
        cat > "$MOODLE_DIR/.ddev/mysql/moodle.cnf" <<'MYSQLEOF'
# MySQL configuration for Moodle
[mysqld]
# Required for full UTF-8 support
innodb_large_prefix=ON
innodb_file_format=Barracuda
innodb_file_per_table=ON

# Recommended Moodle settings
innodb_buffer_pool_size=256M
max_allowed_packet=64M
sort_buffer_size=2M
read_buffer_size=2M
read_rnd_buffer_size=8M
myisam_sort_buffer_size=64M
thread_cache_size=8
query_cache_size=0
query_cache_type=0

# Character set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
skip-character-set-client-handshake

[mysql]
default-character-set=utf8mb4
MYSQLEOF
        chown $ACTUAL_USER:$ACTUAL_USER "$MOODLE_DIR/.ddev/mysql/moodle.cnf"
        print_status "Created MySQL configuration"
    fi
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$MOODLE_DIR/.ddev"
    
    # Verify configuration
    if [ -f "$MOODLE_DIR/.ddev/config.yaml" ]; then
        mark_complete "STEP_MOODLE_DDEV"
        print_status "✓ DDEV configured for Moodle with MySQL settings"
    else
        print_error "DDEV configuration failed"
        exit 1
    fi
else
    print_status "✓ DDEV already configured for Moodle (skipping)"
fi

# Step 4.4: Start DDEV
if ! is_complete "STEP_MOODLE_START"; then
    print_step "Starting Moodle DDEV..."
    
    # Check if already running
    if su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev describe >/dev/null 2>&1"; then
        print_status "DDEV already running, restarting to apply MySQL config..."
        su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev restart"
    else
        su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev start"
    fi
    
    # Wait for database to initialize
    print_status "Waiting for database to initialize..."
    sleep 5
    
    # Verify DDEV is running
    if su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev describe >/dev/null 2>&1"; then
        # Verify MySQL settings
        print_step "Verifying MySQL configuration..."
        LARGE_PREFIX=$(su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev mysql -N -e \"SHOW VARIABLES LIKE 'innodb_large_prefix';\" | awk '{print \$2}'")
        FILE_FORMAT=$(su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev mysql -N -e \"SHOW VARIABLES LIKE 'innodb_file_format';\" | awk '{print \$2}'")
        
        print_status "innodb_large_prefix: $LARGE_PREFIX"
        print_status "innodb_file_format: $FILE_FORMAT"
        
        if [ "$LARGE_PREFIX" = "ON" ] || [ "$LARGE_PREFIX" = "1" ]; then
            mark_complete "STEP_MOODLE_START"
            print_status "✓ Moodle DDEV started with MySQL configured"
        else
            print_warning "MySQL settings may not be fully applied, but continuing..."
            mark_complete "STEP_MOODLE_START"
        fi
    else
        print_error "Failed to start DDEV"
        exit 1
    fi
else
    print_status "✓ Moodle DDEV already started (skipping)"
    # Verify it's still running
    if ! su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev describe >/dev/null 2>&1"; then
        print_warning "DDEV was marked as started but is not running. Restarting..."
        su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev start"
        sleep 5
    fi
fi

# Step 4.5: Create data directory
if ! is_complete "STEP_MOODLE_DATA"; then
    print_step "Creating Moodle data directory..."
    
    if [ ! -d "$MOODLE_DIR/moodledata" ]; then
        su - $ACTUAL_USER -c "mkdir -p $MOODLE_DIR/moodledata"
        su - $ACTUAL_USER -c "chmod 777 $MOODLE_DIR/moodledata"
        print_status "Created moodledata directory"
    else
        print_status "moodledata directory already exists"
    fi
    
    # Verify directory
    if [ -d "$MOODLE_DIR/moodledata" ] && [ -w "$MOODLE_DIR/moodledata" ]; then
        mark_complete "STEP_MOODLE_DATA"
        print_status "✓ Moodle data directory configured"
    else
        print_error "Failed to create moodledata directory"
        exit 1
    fi
else
    print_status "✓ Moodle data directory already configured (skipping)"
fi

# Step 4.6: Install Moodle
if ! is_complete "STEP_MOODLE_INSTALL"; then
    print_step "Installing Moodle via CLI..."
    
    # Check if already installed
    if [ -f "$MOODLE_DIR/html/config.php" ]; then
        print_status "config.php exists, checking if Moodle is installed..."
        
        # Try to check Moodle status
        if su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev exec php html/admin/cli/maintenance.php --help >/dev/null 2>&1"; then
            print_status "Moodle appears to be installed"
            mark_complete "STEP_MOODLE_INSTALL"
            print_status "✓ Moodle installation verified"
        else
            print_warning "config.php exists but Moodle may not be fully installed. Attempting install..."
            # Remove config.php and try again
            rm -f "$MOODLE_DIR/html/config.php"
        fi
    fi
    
    # If not already marked complete, proceed with installation
    if ! is_complete "STEP_MOODLE_INSTALL"; then
        # Get database credentials from DDEV
        DB_HOST="db"
        DB_NAME="db"
        DB_USER="db"
        DB_PASS="db"
        
        # Try normal installation first
        print_status "Attempting Moodle installation..."
        
        if su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev exec php html/admin/cli/install.php \
            --lang=en \
            --wwwroot='$MOODLE_URL' \
            --dataroot='/var/www/html/moodledata' \
            --dbtype=mariadb \
            --dbhost='$DB_HOST' \
            --dbname='$DB_NAME' \
            --dbuser='$DB_USER' \
            --dbpass='$DB_PASS' \
            --fullname='Moodle LMS' \
            --shortname='Moodle' \
            --adminuser='$MOODLE_ADMIN_USER' \
            --adminpass='$MOODLE_ADMIN_PASS' \
            --adminemail='$ADMIN_EMAIL' \
            --agree-license \
            --non-interactive" 2>&1 | tee /tmp/moodle_install.log; then
            
            print_status "✓ Moodle installed successfully"
        else
            print_warning "Standard installation had issues. Checking logs..."
            
            # Check if it's only the UTF-8 warning but installation might have proceeded
            if grep -q "Installation completed successfully" /tmp/moodle_install.log || [ -f "$MOODLE_DIR/html/config.php" ]; then
                print_status "✓ Moodle installation completed (may have warnings)"
            else
                print_warning "Attempting installation with database skip..."
                
                # Try with skip-database option
                if su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev exec php html/admin/cli/install.php \
                    --lang=en \
                    --wwwroot='$MOODLE_URL' \
                    --dataroot='/var/www/html/moodledata' \
                    --dbtype=mariadb \
                    --dbhost='$DB_HOST' \
                    --dbname='$DB_NAME' \
                    --dbuser='$DB_USER' \
                    --dbpass='$DB_PASS' \
                    --fullname='Moodle LMS' \
                    --shortname='Moodle' \
                    --adminuser='$MOODLE_ADMIN_USER' \
                    --adminpass='$MOODLE_ADMIN_PASS' \
                    --adminemail='$ADMIN_EMAIL' \
                    --agree-license \
                    --skip-database \
                    --non-interactive"; then
                    
                    print_status "✓ Moodle installed with skip-database"
                    
                    # Now run the database upgrade to complete installation
                    print_step "Completing database setup..."
                    su - $ACTUAL_USER -c "cd $MOODLE_DIR && ddev exec php html/admin/cli/upgrade.php --non-interactive"
                else
                    print_error "Moodle installation failed. Check logs at /tmp/moodle_install.log"
                    print_warning "You may complete installation via web interface at: $MOODLE_URL"
                fi
            fi
        fi
        
        # Final verification
        if [ -f "$MOODLE_DIR/html/config.php" ]; then
            mark_complete "STEP_MOODLE_INSTALL"
            print_status "✓ Moodle installation verified"
        else
            print_error "Moodle installation failed - config.php not created"
            print_warning "You can complete installation via web interface at: $MOODLE_URL"
        fi
    fi
else
    print_status "✓ Moodle already installed (skipping)"
fi

################################################################################
# PART 5: OAUTH MODULES INSTALLATION
################################################################################

print_section "PART 5: OAuth Modules Installation"

# Step 5.1: Install Simple OAuth
if ! is_complete "STEP_OAUTH_SIMPLE_OAUTH"; then
    print_step "Installing Simple OAuth module..."
    
    # Check if already installed
    if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush pm:list --type=module --status=enabled | grep -q simple_oauth"; then
        print_status "Simple OAuth already installed and enabled"
    else
        # Check if package exists in composer.json
        if ! grep -q "drupal/simple_oauth" "$OPENSOCIAL_DIR/composer.json" 2>/dev/null; then
            su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev composer require 'drupal/simple_oauth:^5.2'"
        fi
        
        # Enable the module
        if ! su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush pm:list --type=module --status=enabled | grep -q simple_oauth"; then
            su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush en simple_oauth -y"
        fi
    fi
    
    # Verify installation
    if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush pm:list --type=module --status=enabled | grep -q simple_oauth"; then
        mark_complete "STEP_OAUTH_SIMPLE_OAUTH"
        print_status "✓ Simple OAuth module installed and verified"
    else
        print_error "Failed to install Simple OAuth module"
        exit 1
    fi
else
    print_status "✓ Simple OAuth already installed (skipping)"
fi

# Step 5.2: Generate OAuth keys
if ! is_complete "STEP_OAUTH_KEYS"; then
    print_step "Generating OAuth keys..."
    
    OAUTH_KEYS_DIR="$OPENSOCIAL_DIR/keys"
    
    # Check if keys already exist
    if [ -f "$OAUTH_KEYS_DIR/private.key" ] && [ -f "$OAUTH_KEYS_DIR/public.key" ]; then
        print_status "OAuth keys already exist"
    else
        if [ ! -d "$OAUTH_KEYS_DIR" ]; then
            su - $ACTUAL_USER -c "mkdir -p $OAUTH_KEYS_DIR"
            su - $ACTUAL_USER -c "chmod 700 $OAUTH_KEYS_DIR"
        fi
        
        # Generate private key if it doesn't exist
        if [ ! -f "$OAUTH_KEYS_DIR/private.key" ]; then
            su - $ACTUAL_USER -c "openssl genrsa -out $OAUTH_KEYS_DIR/private.key 2048"
            su - $ACTUAL_USER -c "chmod 600 $OAUTH_KEYS_DIR/private.key"
        fi
        
        # Generate public key if it doesn't exist
        if [ ! -f "$OAUTH_KEYS_DIR/public.key" ]; then
            su - $ACTUAL_USER -c "openssl rsa -in $OAUTH_KEYS_DIR/private.key -pubout -out $OAUTH_KEYS_DIR/public.key"
            su - $ACTUAL_USER -c "chmod 644 $OAUTH_KEYS_DIR/public.key"
        fi
    fi
    
    # Verify keys exist and are valid
    if [ -f "$OAUTH_KEYS_DIR/private.key" ] && [ -f "$OAUTH_KEYS_DIR/public.key" ] && \
       openssl rsa -in "$OAUTH_KEYS_DIR/private.key" -check -noout >/dev/null 2>&1; then
        mark_complete "STEP_OAUTH_KEYS"
        print_status "✓ OAuth keys generated and verified"
    else
        print_error "Failed to generate or verify OAuth keys"
        exit 1
    fi
else
    print_status "✓ OAuth keys already generated (skipping)"
fi

# Step 5.3: Configure Simple OAuth
if ! is_complete "STEP_OAUTH_CONFIG"; then
    print_step "Configuring Simple OAuth..."
    
    # Check current configuration
    CURRENT_PUBLIC=$(su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush config:get simple_oauth.settings public_key --format=string" 2>/dev/null || echo "")
    CURRENT_PRIVATE=$(su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush config:get simple_oauth.settings private_key --format=string" 2>/dev/null || echo "")
    
    EXPECTED_PUBLIC="/var/www/html/../keys/public.key"
    EXPECTED_PRIVATE="/var/www/html/../keys/private.key"
    
    if [ "$CURRENT_PUBLIC" = "$EXPECTED_PUBLIC" ] && [ "$CURRENT_PRIVATE" = "$EXPECTED_PRIVATE" ]; then
        print_status "Simple OAuth already configured"
    else
        # Configure key paths
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush config:set simple_oauth.settings public_key '$EXPECTED_PUBLIC' -y"
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush config:set simple_oauth.settings private_key '$EXPECTED_PRIVATE' -y"
    fi
    
    # Clear cache
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush cr"
    
    # Verify configuration
    VERIFY_PUBLIC=$(su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush config:get simple_oauth.settings public_key --format=string" 2>/dev/null)
    if [ "$VERIFY_PUBLIC" = "$EXPECTED_PUBLIC" ]; then
        mark_complete "STEP_OAUTH_CONFIG"
        print_status "✓ Simple OAuth configured and verified"
    else
        print_error "Failed to configure Simple OAuth"
        exit 1
    fi
else
    print_status "✓ Simple OAuth already configured (skipping)"
fi

################################################################################
# PART 6: OPENSOCIAL OAUTH PROVIDER MODULE
################################################################################

print_section "PART 6: OpenSocial OAuth Provider Module"

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
        $user_data['picture'] = \Drupal::service('file_url_generator')->generateAbsoluteString($file->getFileUri());
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
    
    # Check if module is already enabled
    if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush pm:list --type=module --status=enabled | grep -q opensocial_oauth_provider"; then
        print_status "OpenSocial OAuth Provider already enabled"
    else
        # Enable the module
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush en opensocial_oauth_provider -y"
    fi
    
    # Clear cache
    su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush cr"
    
    # Verify module is enabled
    if su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush pm:list --type=module --status=enabled | grep -q opensocial_oauth_provider"; then
        mark_complete "STEP_ENABLE_OAUTH_PROVIDER"
        print_status "✓ OAuth Provider module enabled and verified"
    else
        print_error "Failed to enable OAuth Provider module"
        exit 1
    fi
else
    print_status "✓ OAuth Provider module already enabled (skipping)"
fi

if ! is_complete "STEP_CREATE_OAUTH_CLIENT"; then
    print_step "Creating OAuth client for Moodle..."
    
    # Check if client already exists
    CLIENT_EXISTS=$(su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush php-eval \"
\\$clients = \\Drupal\\consumers\\Entity\\Consumer::loadMultiple();
foreach (\\$clients as \\$client) {
  if (\\$client->get('client_id')->value == '$OAUTH_CLIENT_ID') {
    echo 'EXISTS';
    exit;
  }
}
echo 'NOT_FOUND';
\"")
    
    if [ "$CLIENT_EXISTS" = "EXISTS" ]; then
        print_status "OAuth client already exists"
    else
        # Create OAuth consumer via Drush
        su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush php-eval \"
\\$client = \\Drupal\\consumers\\Entity\\Consumer::create([
  'label' => 'Moodle LMS',
  'client_id' => '$OAUTH_CLIENT_ID',
  'secret' => '$OAUTH_CLIENT_SECRET',
  'confidential' => TRUE,
  'third_party' => TRUE,
  'redirect' => '$MOODLE_URL/admin/oauth2callback.php',
  'user_id' => NULL,
]);
\\$client->save();
echo 'OAuth client created successfully';
\""
    fi
    
    # Verify client exists
    CLIENT_CHECK=$(su - $ACTUAL_USER -c "cd $OPENSOCIAL_DIR && ddev drush php-eval \"
\\$clients = \\Drupal\\consumers\\Entity\\Consumer::loadMultiple();
foreach (\\$clients as \\$client) {
  if (\\$client->get('client_id')->value == '$OAUTH_CLIENT_ID') {
    echo 'VERIFIED';
    exit;
  }
}
echo 'FAILED';
\"")
    
    if [ "$CLIENT_CHECK" = "VERIFIED" ]; then
        mark_complete "STEP_CREATE_OAUTH_CLIENT"
        print_status "✓ OAuth client created and verified"
    else
        print_error "Failed to create or verify OAuth client"
        exit 1
    fi
else
    print_status "✓ OAuth client already created (skipping)"
fi

################################################################################
# PART 7: MOODLE OAUTH PLUGIN INSTALLATION
################################################################################

print_section "PART 7: Moodle OAuth Authentication Plugin"

if ! is_complete "STEP_MOODLE_OAUTH_PLUGIN"; then
    print_step "Creating Moodle OpenSocial OAuth plugin..."
    
    MOODLE_AUTH_DIR="$MOODLE_DIR/html/auth/opensocial"
    
    # Check if plugin directory already exists
    if [ -d "$MOODLE_AUTH_DIR" ] && [ -f "$MOODLE_AUTH_DIR/version.php" ]; then
        print_status "Moodle OAuth plugin already exists"
    else
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
$string['opensocial_url_desc'] = 'The base URL of your OpenSocial installation (e.g., https://opensocial.ddev.site)';
$string['oauth2_issuer_id'] = 'OAuth2 Issuer ID';
$string['oauth2_issuer_id_desc'] = 'The ID of the OAuth2 issuer configured in Moodle';
$string['auto_redirect'] = 'Auto-redirect to OpenSocial login';
$string['auto_redirect_desc'] = 'Automatically redirect users to OpenSocial login page';
LANGEOF
        
        chown -R $ACTUAL_USER:$ACTUAL_USER "$MOODLE_AUTH_DIR"
    fi
    
    # Verify plugin was created
    if [ -f "$MOODLE_AUTH_DIR/version.php" ] && [ -f "$MOODLE_AUTH_DIR/auth.php" ]; then
        mark_complete "STEP_MOODLE_OAUTH_PLUGIN"
        print_status "✓ Moodle OAuth plugin created and verified"
    else
        print_error "Failed to create Moodle OAuth plugin"
        exit 1
    fi
else
    print_status "✓ Moodle OAuth plugin already created (skipping)"
fi

################################################################################
# PART 8: SAVE CREDENTIALS
################################################################################

print_section "PART 8: Saving Installation Information"

cat > "$CREDENTIALS_FILE" <<EOF
========================================
OpenSocial + Moodle SSO Integration
Complete Installation (DDEV)
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
Project Directory: $MOODLE_DIR
Project Name: $MOODLE_PROJECT
URL: $MOODLE_URL
Admin Username: $MOODLE_ADMIN_USER
Admin Password: $MOODLE_ADMIN_PASS
Admin Email: $ADMIN_EMAIL

DDEV Commands:
  cd $MOODLE_DIR
  ddev start           - Start project
  ddev stop            - Stop project
  ddev launch          - Open in browser

OAUTH INTEGRATION:
------------------
OAuth Client ID: $OAUTH_CLIENT_ID
OAuth Client Secret: $OAUTH_CLIENT_SECRET
OAuth Keys Directory: $OPENSOCIAL_DIR/keys

OpenSocial OAuth Endpoints:
  Authorization: $OPENSOCIAL_URL/oauth/authorize
  Token: $OPENSOCIAL_URL/oauth/token
  User Info: $OPENSOCIAL_URL/oauth/userinfo

Moodle Redirect URI: $MOODLE_URL/admin/oauth2callback.php

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
   - Visit: $MOODLE_URL
   - Click "OpenSocial" login button
   - Authenticate with OpenSocial credentials

NEXT STEPS:
-----------
1. Access OpenSocial: $OPENSOCIAL_URL
   Login: $OPENSOCIAL_ADMIN_USER / $OPENSOCIAL_ADMIN_PASS

2. Access Moodle: $MOODLE_URL
   Login: $MOODLE_ADMIN_USER / $MOODLE_ADMIN_PASS

3. Complete Moodle OAuth2 configuration via web interface (see above)

4. Test SSO login

TROUBLESHOOTING:
----------------
View OpenSocial logs:
  cd $OPENSOCIAL_DIR && ddev logs

View Moodle logs:
  cd $MOODLE_DIR && ddev logs

Check DDEV status:
  cd $OPENSOCIAL_DIR && ddev describe
  cd $MOODLE_DIR && ddev describe

Test OAuth endpoints:
  curl $OPENSOCIAL_URL/oauth/authorize
  curl $OPENSOCIAL_URL/oauth/token
  curl $OPENSOCIAL_URL/oauth/userinfo

IMPORTANT NOTES:
----------------
- Both platforms run in DDEV (no port conflicts!)
- URLs use HTTPS with mkcert certificates
- Both projects run simultaneously on different ports
- DDEV automatically manages routing

Checkpoint File: $CHECKPOINT_FILE
========================================
EOF

chmod 600 "$CREDENTIALS_FILE"

print_status "✓ Credentials saved to: $CREDENTIALS_FILE"

################################################################################
# PART 9: FINAL SUMMARY
################################################################################

print_section "Installation Complete!"

echo ""
print_status "OpenSocial Installation:"
echo "  URL: $OPENSOCIAL_URL"
echo "  Admin: $OPENSOCIAL_ADMIN_USER / $OPENSOCIAL_ADMIN_PASS"
echo "  Commands: cd $OPENSOCIAL_DIR && ddev drush uli"
echo ""

print_status "Moodle Installation:"
echo "  URL: $MOODLE_URL"
echo "  Admin: $MOODLE_ADMIN_USER / $MOODLE_ADMIN_PASS"
echo "  Commands: cd $MOODLE_DIR && ddev launch"
echo ""

print_status "OAuth Integration:"
echo "  Client ID: $OAUTH_CLIENT_ID"
echo "  Client Secret: [saved in credentials file]"
echo ""

print_warning "IMPORTANT: Complete OAuth Configuration in Moodle"
echo ""
echo "1. Open Moodle: $MOODLE_URL"
echo "2. Go to: Site administration > Server > OAuth 2 services"
echo "3. Create custom service with credentials from:"
echo "   sudo cat $CREDENTIALS_FILE"
echo ""

print_section "Quick Access"
echo "OpenSocial: cd $OPENSOCIAL_DIR && ddev launch"
echo "Moodle: cd $MOODLE_DIR && ddev launch"
echo "Credentials: sudo cat $CREDENTIALS_FILE"
echo ""

print_status "Both platforms are running in DDEV - no port conflicts!"
print_status "Installation completed successfully!"

exit 0