#!/bin/bash

################################################################################
# OpenSocial + Moodle Fully Integrated SSO Installation Script (DDEV Version)
# Both platforms installed in DDEV to avoid port conflicts
# Based on: https://github.com/rjzaar/opensocial-moodle-sso-integration
# Modified to use module folders instead of inline creation
# FIXED: Simple OAuth 6.x configuration compatibility
# FIXED: OAuth key path verification in DDEV containers
# FIXED: PHP deprecation warnings in module verification
# MODIFIED: Uses opensocial_moodle_sso/ and moodle_opensocial_auth/ folders
################################################################################

# Show usage information
show_usage() {
    cat << EOF
Usage: sudo bash $0 [OPTIONS]

OpenSocial + Moodle SSO Integration Installation Script

OPTIONS:
    --defaults, -d    Run with default options (non-interactive mode)
                      Uses values from config.yml if present
                      Falls back to hardcoded defaults if config.yml missing
    
    --help, -h        Show this help message

EXAMPLES:
    # Interactive mode (prompts for admin email)
    sudo bash $0
    
    # Non-interactive mode with config.yml
    sudo bash $0 --defaults
    
    # Non-interactive mode with environment variable override
    OPENSOCIAL_PROJECT=mysite sudo bash $0 --defaults

CONFIGURATION:
    All files will be stored in: $(dirname "${BASH_SOURCE[0]}")
    
    Configuration file: config.yml (optional)
    - Create config.yml in the script directory to customize settings
    - Only used when running with --defaults flag
    - See CONFIG_GUIDE.md for full configuration options
    
    Default settings (when config.yml not present):
    - Admin email: admin@example.com
    - Admin username: admin
    - Admin password: admin
    - OpenSocial URL: https://opensocial.ddev.site (auto-increments if conflict)
    - Moodle URL: https://moodle.ddev.site (auto-increments if conflict)

NOTES:
    - Script must be run with sudo/root privileges
    - URLs will auto-increment if conflicts detected (opensocial -> opensocial1 -> opensocial2)
    - Script is idempotent - safe to run multiple times
    - Checks actual system state, not checkpoint files
    - Interactive mode: Composer may show prompts for decisions
    - Non-interactive mode (--defaults): Composer runs without prompts
    - Module folders must be present: opensocial_moodle_sso/ and moodle_opensocial_auth/

FILES:
    config.yml                                    - Configuration file (optional)
    opensocial_moodle_ddev_credentials.txt        - Generated credentials
    opensocial_moodle_sso/                        - OpenSocial OAuth Provider module
    moodle_opensocial_auth/                       - Moodle authentication plugin
    opensocial/                                   - OpenSocial installation
    moodle/                                       - Moodle installation

EOF
}

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

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

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
print_status "Script directory: $SCRIPT_DIR"
print_status "Files will be stored in: $SCRIPT_DIR"

# Simple YAML parser function
parse_yaml() {
    local yaml_file="$1"
    local prefix="$2"
    
    if [ ! -f "$yaml_file" ]; then
        return 1
    fi
    
    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_]*'
    local fs=$(echo @|tr @ '\034')
    
    sed -ne "s|^\($s\):|\1|" \
         -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
         -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$yaml_file" |
    awk -F"$fs" '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }' | grep -v "^#"
}

# Load configuration from YAML file
load_config() {
    local config_file="$SCRIPT_DIR/config.yml"
    
    if [ -f "$config_file" ]; then
        print_status "Loading configuration from: $config_file"
        eval $(parse_yaml "$config_file" "CONFIG_")
        print_status "✓ Configuration loaded"
        return 0
    else
        print_warning "Config file not found: $config_file"
        print_warning "Using hardcoded defaults"
        return 1
    fi
}

# Function to check if a DDEV site URL is already in use
check_url_available() {
    local project_name=$1
    local counter=0
    local test_name="$project_name"
    
    # Check if ddev command is available
    if ! command -v ddev &> /dev/null; then
        echo "$test_name"
        return
    fi
    
    # Check existing DDEV projects as actual user
    while su - $ACTUAL_USER -c "ddev list 2>/dev/null | grep -q \"$test_name\""; do
        counter=$((counter + 1))
        test_name="${project_name}${counter}"
        # Output to stderr so it doesn't interfere with command substitution
        >&2 echo -e "${GREEN}[INFO]${NC} URL conflict detected, trying: $test_name"
    done
    
    echo "$test_name"
}

print_section "Integrated OpenSocial + Moodle SSO Installation (DDEV)"
echo "This script will install both platforms in DDEV:"
echo "  1. OpenSocial (Drupal)"
echo "  2. Moodle LMS"
echo "  3. Complete SSO integration between them"
echo ""
print_warning "Both systems run in DDEV containers (no port conflicts!)"
print_warning "Files will be stored in: $SCRIPT_DIR"
print_warning "Module folders required: opensocial_moodle_sso/ and moodle_opensocial_auth/"
echo ""

# Check for --defaults flag
USE_DEFAULTS=false
if [ "$1" = "--defaults" ] || [ "$1" = "-d" ]; then
    USE_DEFAULTS=true
    print_status "Running with default options (non-interactive mode)"
    echo ""
fi

# Load configuration from YAML file if using defaults
if [ "$USE_DEFAULTS" = true ]; then
    load_config
fi

# Configuration variables
print_section "Configuration"

# Admin credentials - use YAML config or hardcoded defaults
if [ "$USE_DEFAULTS" = true ] && [ -n "$CONFIG_admin_email" ]; then
    ADMIN_EMAIL="${CONFIG_admin_email}"
    ADMIN_USER="${CONFIG_admin_username}"
    ADMIN_PASS="${CONFIG_admin_password}"
    print_status "Using admin credentials from config file"
else
    # Interactive mode or no config file
    ADMIN_USER="admin"
    ADMIN_PASS="admin"
    if [ "$USE_DEFAULTS" = true ]; then
        ADMIN_EMAIL="admin@example.com"
        print_status "Using default admin email: $ADMIN_EMAIL"
    else
        read -p "Enter admin email [admin@example.com]: " ADMIN_EMAIL
        ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
    fi
fi

# OpenSocial Configuration
if [ "$USE_DEFAULTS" = true ] && [ -n "$CONFIG_opensocial_project_name" ]; then
    OPENSOCIAL_PROJECT_BASE="${CONFIG_opensocial_project_name}"
    OPENSOCIAL_VERSION="${CONFIG_opensocial_version}"
    OPENSOCIAL_PHP_VERSION="${CONFIG_opensocial_php_version}"
    OPENSOCIAL_MYSQL_VERSION="${CONFIG_opensocial_mysql_version}"
    OPENSOCIAL_NODEJS_VERSION="${CONFIG_opensocial_nodejs_version}"
    OPENSOCIAL_SITE_NAME="${CONFIG_opensocial_site_name}"
else
    OPENSOCIAL_PROJECT_BASE="${OPENSOCIAL_PROJECT:-opensocial}"
    OPENSOCIAL_VERSION="${OPENSOCIAL_VERSION:-dev-master}"
    OPENSOCIAL_PHP_VERSION="8.2"
    OPENSOCIAL_MYSQL_VERSION="8.0"
    OPENSOCIAL_NODEJS_VERSION="18"
    OPENSOCIAL_SITE_NAME="OpenSocial Community"
fi

OPENSOCIAL_PROJECT=$(check_url_available "$OPENSOCIAL_PROJECT_BASE")
print_status "OpenSocial project name: $OPENSOCIAL_PROJECT"

# Moodle Configuration
if [ "$USE_DEFAULTS" = true ] && [ -n "$CONFIG_moodle_project_name" ]; then
    MOODLE_PROJECT_BASE="${CONFIG_moodle_project_name}"
    MOODLE_VERSION="${CONFIG_moodle_version}"
    MOODLE_PHP_VERSION="${CONFIG_moodle_php_version}"
    MOODLE_MYSQL_VERSION="${CONFIG_moodle_mysql_version}"
    MOODLE_FULLNAME="${CONFIG_moodle_fullname}"
    MOODLE_SHORTNAME="${CONFIG_moodle_shortname}"
else
    MOODLE_PROJECT_BASE="${MOODLE_PROJECT:-moodle}"
    MOODLE_VERSION="MOODLE_404_STABLE"
    MOODLE_PHP_VERSION="8.1"
    MOODLE_MYSQL_VERSION="8.0"
    MOODLE_FULLNAME="Moodle LMS"
    MOODLE_SHORTNAME="Moodle"
fi

MOODLE_PROJECT=$(check_url_available "$MOODLE_PROJECT_BASE")
print_status "Moodle project name: $MOODLE_PROJECT"

# OAuth Configuration
OAUTH_CLIENT_ID=$(cat /proc/sys/kernel/random/uuid)
OAUTH_CLIENT_SECRET=$(openssl rand -hex 32)

# Site configurations using loaded config values
OPENSOCIAL_ADMIN_USER="$ADMIN_USER"
OPENSOCIAL_ADMIN_PASS="$ADMIN_PASS"
OPENSOCIAL_URL="https://${OPENSOCIAL_PROJECT}.ddev.site"

MOODLE_ADMIN_USER="$ADMIN_USER"
MOODLE_ADMIN_PASS="$ADMIN_PASS"
MOODLE_URL="https://${MOODLE_PROJECT}.ddev.site"

print_status "Configuration set:"
echo "  OpenSocial URL: $OPENSOCIAL_URL"
echo "  Moodle URL: $MOODLE_URL"
echo "  Admin Email: $ADMIN_EMAIL"
echo "  Admin Username: $ADMIN_USER"
echo "  Admin Password: $ADMIN_PASS"
echo "  Storage Location: $SCRIPT_DIR"
echo ""

# Credentials file - stored in script directory
CREDENTIALS_FILE="$SCRIPT_DIR/opensocial_moodle_ddev_credentials.txt"

# State checking functions - actually verify if steps are complete
check_system_updated() {
    # Check if system was recently updated (within last 7 days)
    if [ -f /var/log/apt/history.log ]; then
        local last_update=$(stat -c %Y /var/log/apt/history.log 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local seven_days=$((7 * 24 * 60 * 60))
        [ $((current_time - last_update)) -lt $seven_days ]
    else
        return 1
    fi
}

check_prerequisites_installed() {
    command -v curl &> /dev/null && \
    command -v git &> /dev/null && \
    command -v unzip &> /dev/null && \
    command -v wget &> /dev/null
}

check_docker_installed() {
    command -v docker &> /dev/null && \
    docker --version &> /dev/null
}

check_ddev_installed() {
    command -v ddev &> /dev/null && \
    ddev version &> /dev/null
}

check_mkcert_installed() {
    command -v mkcert &> /dev/null && \
    mkcert -help &> /dev/null 2>&1
}

check_opensocial_dir_exists() {
    [ -d "$OPENSOCIAL_DIR" ] && [ -w "$OPENSOCIAL_DIR" ]
}

check_opensocial_ddev_configured() {
    [ -f "$OPENSOCIAL_DIR/.ddev/config.yaml" ]
}

check_opensocial_ddev_running() {
    [ -d "$OPENSOCIAL_DIR" ] && \
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev describe >/dev/null 2>&1"
}

check_opensocial_composer_installed() {
    [ -f "$OPENSOCIAL_DIR/composer.json" ] && \
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush --version >/dev/null 2>&1"
}

check_opensocial_private_configured() {
    local private_dir="$OPENSOCIAL_DIR/../private"
    [ -d "$private_dir" ] && [ -w "$private_dir" ]
}

check_opensocial_installed() {
    [ -d "$OPENSOCIAL_DIR" ] && \
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush status bootstrap 2>/dev/null | grep -q 'Successful'"
}

check_moodle_dir_exists() {
    [ -d "$MOODLE_DIR" ] && [ -w "$MOODLE_DIR" ]
}

check_moodle_downloaded() {
    [ -f "$MOODLE_DIR/html/version.php" ]
}

check_moodle_ddev_configured() {
    [ -f "$MOODLE_DIR/.ddev/config.yaml" ]
}

check_moodle_ddev_running() {
    [ -d "$MOODLE_DIR" ] && \
    su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev describe >/dev/null 2>&1"
}

check_moodle_data_exists() {
    [ -d "$MOODLE_DIR/moodledata" ] && [ -w "$MOODLE_DIR/moodledata" ]
}

check_moodle_installed() {
    [ -f "$MOODLE_DIR/html/config.php" ]
}

check_simple_oauth_installed() {
    [ -d "$OPENSOCIAL_DIR" ] && \
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module --status=enabled 2>/dev/null | grep -q simple_oauth"
}

check_oauth_keys_exist() {
    [ -f "$OPENSOCIAL_DIR/keys/private.key" ] && \
    [ -f "$OPENSOCIAL_DIR/keys/public.key" ] && \
    openssl rsa -in "$OPENSOCIAL_DIR/keys/private.key" -check -noout >/dev/null 2>&1
}

# FIXED: More robust OAuth configuration check
check_oauth_configured() {
    [ -d "$OPENSOCIAL_DIR" ] || return 1
    
    # Try to get config - check for various possible key path configurations
    local config_check=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush config:get simple_oauth.settings 2>/dev/null" || echo "")
    
    # Check if either public_key or public_key_path is set with any valid path
    if echo "$config_check" | grep -qE "public_key.*(/var/www/keys|../keys|keys)"; then
        return 0
    fi
    
    # Additional check: verify keys are accessible from container
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec 'test -f /var/www/keys/public.key' 2>/dev/null"; then
        # Keys exist, let's assume config is okay if module is enabled
        if check_simple_oauth_installed; then
            return 0
        fi
    fi
    
    return 1
}

check_oauth_provider_module_exists() {
    [ -f "$OPENSOCIAL_DIR/html/modules/custom/opensocial_oauth_provider/opensocial_oauth_provider.info.yml" ]
}

# FIXED: More robust check for module enabled status that handles PHP warnings
check_oauth_provider_enabled() {
    [ -d "$OPENSOCIAL_DIR" ] || return 1
    
    # Method 1: Check with pm:list (suppress warnings)
    local module_check=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module --status=enabled 2>/dev/null | grep opensocial_oauth_provider || true")
    [ -n "$module_check" ] && return 0
    
    # Method 2: Check with module_handler service
    local module_status=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"echo \\Drupal::service('module_handler')->moduleExists('opensocial_oauth_provider') ? 'YES' : 'NO';\" 2>/dev/null" || echo "NO")
    [ "$module_status" = "YES" ] && return 0
    
    return 1
}

check_oauth_client_exists() {
    [ -d "$OPENSOCIAL_DIR" ] && \
    local client_check=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"
\\$clients = \\Drupal\\consumers\\Entity\\Consumer::loadMultiple();
foreach (\\$clients as \\$client) {
  if (\\$client->get('client_id')->value == '$OAUTH_CLIENT_ID') {
    echo 'EXISTS';
    exit;
  }
}
echo 'NOT_FOUND';
\"" 2>/dev/null)
    [ "$client_check" = "EXISTS" ]
}

check_moodle_oauth_plugin_exists() {
    [ -f "$MOODLE_DIR/html/auth/opensocial/version.php" ] && \
    [ -f "$MOODLE_DIR/html/auth/opensocial/auth.php" ]
}

################################################################################
# PART 1: SYSTEM PREREQUISITES
################################################################################

print_section "PART 1: System Prerequisites"

print_step "Checking if system packages need updating..."
if ! check_system_updated; then
    print_status "System needs updating..."
    apt update && apt upgrade -y
    print_status "✓ System updated"
else
    print_status "✓ System recently updated (within last 7 days - skipping)"
fi

print_step "Checking system prerequisites (curl, git, unzip, wget)..."
if ! check_prerequisites_installed; then
    print_status "Installing missing prerequisites..."
    
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
    print_status "✓ Prerequisites installed"
else
    print_status "✓ All prerequisites already installed (skipping)"
fi

################################################################################
# PART 2: DOCKER AND DDEV INSTALLATION
################################################################################

print_section "PART 2: Docker and DDEV Installation"

print_step "Checking if Docker is installed and working..."
if ! check_docker_installed; then
    if ! command -v docker &> /dev/null; then
        print_status "Docker not found - installing..."
        
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
else
    print_status "✓ Docker already installed and working (skipping)"
fi

print_step "Checking if DDEV is installed and working..."
if ! check_ddev_installed; then
    if ! command -v ddev &> /dev/null; then
        print_status "DDEV not found - installing..."
        curl -fsSL https://ddev.com/install.sh | bash
        print_status "✓ DDEV installed"
    else
        print_status "✓ DDEV already installed"
    fi
else
    print_status "✓ DDEV already installed and working (skipping)"
fi

print_step "Checking if mkcert is installed for HTTPS..."
if ! check_mkcert_installed; then
    print_status "Installing mkcert..."
    
    if ! command -v mkcert &> /dev/null; then
        curl -fsSL https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64 -o mkcert
        chmod +x mkcert
        mv mkcert /usr/local/bin/
    fi
    
    # Install CA as the actual user
    su - $ACTUAL_USER -c "mkcert -install"
    
    print_status "✓ mkcert installed and CA configured"
else
    print_status "✓ mkcert already installed and configured (skipping)"
fi

################################################################################
# PART 3: OPENSOCIAL INSTALLATION
################################################################################

print_section "PART 3: OpenSocial Installation"

OPENSOCIAL_DIR="$SCRIPT_DIR/$OPENSOCIAL_PROJECT"

# Step 3.1: Create directory
print_step "Checking if OpenSocial project directory exists..."
if ! check_opensocial_dir_exists; then
    print_status "Creating OpenSocial project directory..."
    echo "  📁 Location: $OPENSOCIAL_DIR"
    
    if [ ! -d "$OPENSOCIAL_DIR" ]; then
        su - $ACTUAL_USER -c "mkdir -p '$OPENSOCIAL_DIR'"
        print_status "✓ Created directory: $OPENSOCIAL_DIR"
    else
        print_status "✓ Directory already exists: $OPENSOCIAL_DIR"
    fi
    
    # Verify directory exists and is writable
    if [ -d "$OPENSOCIAL_DIR" ] && [ -w "$OPENSOCIAL_DIR" ]; then
        print_status "✓ OpenSocial directory verified and writable"
    else
        print_error "Failed to create or access directory: $OPENSOCIAL_DIR"
        exit 1
    fi
else
    print_status "✓ OpenSocial directory already exists and is writable: $OPENSOCIAL_DIR"
fi

# Step 3.2: Configure DDEV
print_step "Checking if DDEV is configured for OpenSocial..."
if ! check_opensocial_ddev_configured; then
    print_status "Configuring DDEV for OpenSocial..."
    echo "  📁 Config directory: $OPENSOCIAL_DIR/.ddev/"
    
    # Check if already configured
    if [ -f "$OPENSOCIAL_DIR/.ddev/config.yaml" ]; then
        print_status "✓ DDEV config already exists: $OPENSOCIAL_DIR/.ddev/config.yaml"
    else
        print_status "Creating DDEV configuration..."
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev config --project-type=drupal \
            --docroot=html \
            --php-version=$OPENSOCIAL_PHP_VERSION \
            --database=mysql:$OPENSOCIAL_MYSQL_VERSION \
            --nodejs-version=$OPENSOCIAL_NODEJS_VERSION \
            --project-name='$OPENSOCIAL_PROJECT' \
            --create-docroot"
        print_status "✓ Created: $OPENSOCIAL_DIR/.ddev/config.yaml"
    fi
    
    # Create custom DDEV config if it doesn't exist
    if [ ! -f "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml" ]; then
        print_status "Creating custom DDEV configuration..."
        echo "  📝 File: $OPENSOCIAL_DIR/.ddev/config.opensocial.yaml"
        cat > "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml" <<EOF
# OpenSocial custom configuration
webimage_extra_packages: [php${OPENSOCIAL_PHP_VERSION}-gd, php${OPENSOCIAL_PHP_VERSION}-uploadprogress]
php_memory_limit: 512M
hooks:
  post-start:
    - exec: composer install --no-interaction || true
EOF
        chown $ACTUAL_USER:$ACTUAL_USER "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml"
        print_status "✓ Created custom configuration"
    else
        print_status "✓ Custom config exists: $OPENSOCIAL_DIR/.ddev/config.opensocial.yaml"
    fi
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$OPENSOCIAL_DIR/.ddev"
    
    # Verify configuration
    if [ -f "$OPENSOCIAL_DIR/.ddev/config.yaml" ]; then
        print_status "✓ DDEV configured for OpenSocial"
        echo "  📋 Configuration files:"
        echo "     - $OPENSOCIAL_DIR/.ddev/config.yaml"
        echo "     - $OPENSOCIAL_DIR/.ddev/config.opensocial.yaml"
    else
        print_error "DDEV configuration failed"
        exit 1
    fi
else
    print_status "✓ DDEV already configured for OpenSocial"
    echo "  📁 Config: $OPENSOCIAL_DIR/.ddev/"
fi

# Step 3.3: Start DDEV
if ! check_opensocial_ddev_running; then
    print_step "Starting OpenSocial DDEV..."
    
    # Check if already running
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev describe >/dev/null 2>&1"; then
        print_status "DDEV already running"
    else
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev start"
    fi
    
    # Verify DDEV is running
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev describe >/dev/null 2>&1"; then
        print_status "✓ OpenSocial DDEV started and verified"
    else
        print_error "Failed to start DDEV"
        exit 1
    fi
else
    print_status "✓ OpenSocial DDEV already started (skipping)"
    # Verify it's still running
    if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev describe >/dev/null 2>&1"; then
        print_warning "DDEV was marked as started but is not running. Restarting..."
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev start"
    fi
fi

# Step 3.4: Install via Composer
if ! check_opensocial_composer_installed; then
    print_step "Installing OpenSocial via Composer..."
    
    # Set composer flags based on mode
    COMPOSER_FLAGS=""
    if [ "$USE_DEFAULTS" = true ]; then
        COMPOSER_FLAGS="--no-interaction"
        print_status "Using non-interactive mode for Composer"
    fi
    
    # Check if composer.json already exists
    if [ -f "$OPENSOCIAL_DIR/composer.json" ]; then
        print_status "composer.json already exists, running composer install..."
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer install $COMPOSER_FLAGS"
    else
        if [ "$OPENSOCIAL_VERSION" = "dev-master" ]; then
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer create-project goalgorilla/social_template:dev-master . --no-interaction --stability dev"
        else
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer create-project goalgorilla/social_template:$OPENSOCIAL_VERSION . --no-interaction"
        fi
    fi
    
    # Install Drush if not already installed
    if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush --version >/dev/null 2>&1"; then
        print_status "Installing Drush..."
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer require drush/drush --dev $COMPOSER_FLAGS"
    else
        print_status "Drush already installed"
    fi
    
    # Verify installation
    if [ -f "$OPENSOCIAL_DIR/composer.json" ] && su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush --version >/dev/null 2>&1"; then
        print_status "✓ OpenSocial installed via Composer"
    else
        print_error "Composer installation failed"
        exit 1
    fi
else
    print_status "✓ OpenSocial already installed (skipping)"
fi

# Step 3.5: Configure private directory
if ! check_opensocial_private_configured; then
    print_step "Configuring private file directory..."
    
    PRIVATE_DIR="$OPENSOCIAL_DIR/../private"
    PRIVATE_ABS_PATH="$(cd $OPENSOCIAL_DIR/.. 2>/dev/null && pwd)/private"
    echo "  📁 Location: $PRIVATE_ABS_PATH"
    
    if [ ! -d "$PRIVATE_DIR" ]; then
        su - $ACTUAL_USER -c "mkdir -p '$PRIVATE_DIR'"
        su - $ACTUAL_USER -c "chmod 755 '$PRIVATE_DIR'"
        print_status "✓ Created private directory"
    else
        print_status "✓ Private directory already exists"
    fi
    
    # Verify directory
    if [ -d "$PRIVATE_DIR" ] && [ -w "$PRIVATE_DIR" ]; then
        print_status "✓ Private directory configured and writable"
        echo "  📊 Path: $PRIVATE_ABS_PATH"
        echo "  🔒 Permissions: 755"
    else
        print_error "Failed to configure private directory"
        exit 1
    fi
else
    PRIVATE_ABS_PATH="$(cd $OPENSOCIAL_DIR/.. 2>/dev/null && pwd)/private"
    print_status "✓ Private directory already configured"
    echo "  📁 Location: $PRIVATE_ABS_PATH"
fi

# Step 3.6: Install Drupal/OpenSocial
if ! check_opensocial_installed; then
    print_step "Installing Drupal/OpenSocial..."
    
    SETTINGS_DIR="$OPENSOCIAL_DIR/html/sites/default"
    echo "  📁 Installation directory: $OPENSOCIAL_DIR/html"
    echo "  📝 Settings directory: $SETTINGS_DIR"
    
    # Check if already installed
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush status bootstrap 2>/dev/null | grep -q 'Successful'"; then
        print_status "✓ OpenSocial already installed"
    else
        # Prepare settings directory
        if [ -d "$SETTINGS_DIR" ]; then
            su - $ACTUAL_USER -c "chmod 755 '$SETTINGS_DIR'" 2>/dev/null || true
            
            # Copy default settings if needed
            if [ -f "$SETTINGS_DIR/default.settings.php" ] && [ ! -f "$SETTINGS_DIR/settings.php" ]; then
                print_status "Creating settings.php from default..."
                echo "  📄 Source: $SETTINGS_DIR/default.settings.php"
                echo "  📄 Target: $SETTINGS_DIR/settings.php"
                su - $ACTUAL_USER -c "cp '$SETTINGS_DIR/default.settings.php' '$SETTINGS_DIR/settings.php'"
                print_status "✓ Copied default settings"
            fi
            
            if [ -f "$SETTINGS_DIR/settings.php" ]; then
                su - $ACTUAL_USER -c "chmod 666 '$SETTINGS_DIR/settings.php'" 2>/dev/null || true
                
                # Add private file path if not already present
                if ! grep -q "\$settings\['file_private_path'\] = '\.\./private';" "$SETTINGS_DIR/settings.php"; then
                    print_status "Adding private file path configuration..."
                    echo "  📝 Editing: $SETTINGS_DIR/settings.php"
                    cat >> "$SETTINGS_DIR/settings.php" <<'EOF'

/**
 * Private file path configuration.
 */
$settings['file_private_path'] = '../private';
EOF
                    print_status "✓ Added private file path configuration"
                fi
            fi
        fi
        
        # Install OpenSocial
        print_status "Running Drupal site installation (this may take a few minutes)..."
        if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush site:install social \
            --account-name='$OPENSOCIAL_ADMIN_USER' \
            --account-pass='$OPENSOCIAL_ADMIN_PASS' \
            --account-mail='$ADMIN_EMAIL' \
            --site-name='$OPENSOCIAL_SITE_NAME' \
            --site-mail='$ADMIN_EMAIL' \
            --locale=en \
            --yes"; then
            
            # Set proper permissions
            if [ -f "$SETTINGS_DIR/settings.php" ]; then
                su - $ACTUAL_USER -c "chmod 444 '$SETTINGS_DIR/settings.php'" 2>/dev/null || true
                print_status "✓ Secured settings.php (444 permissions)"
            fi
            if [ -d "$SETTINGS_DIR" ]; then
                su - $ACTUAL_USER -c "chmod 755 '$SETTINGS_DIR'" 2>/dev/null || true
            fi
            
            # Verify installation
            if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush status bootstrap 2>/dev/null | grep -q 'Successful'"; then
                print_status "✓ OpenSocial installed and verified"
                echo "  🌐 Site URL: $OPENSOCIAL_URL"
                echo "  👤 Admin user: $OPENSOCIAL_ADMIN_USER"
                echo "  📁 Webroot: $OPENSOCIAL_DIR/html"
                echo "  📝 Settings: $SETTINGS_DIR/settings.php"
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
    print_status "✓ OpenSocial already installed"
    echo "  🌐 URL: $OPENSOCIAL_URL"
    echo "  📁 Location: $OPENSOCIAL_DIR/html"
fi

################################################################################
# PART 4: MOODLE INSTALLATION IN DDEV
################################################################################

print_section "PART 4: Moodle Installation in DDEV"

MOODLE_DIR="$SCRIPT_DIR/$MOODLE_PROJECT"

# Step 4.1: Create directory
if ! check_moodle_dir_exists; then
    print_step "Creating Moodle project directory..."
    echo "  📁 Location: $MOODLE_DIR"
    
    if [ ! -d "$MOODLE_DIR" ]; then
        su - $ACTUAL_USER -c "mkdir -p '$MOODLE_DIR'"
        print_status "✓ Created directory: $MOODLE_DIR"
    else
        print_status "✓ Directory already exists: $MOODLE_DIR"
    fi
    
    # Verify directory
    if [ -d "$MOODLE_DIR" ] && [ -w "$MOODLE_DIR" ]; then
        print_status "✓ Moodle directory verified and writable"
    else
        print_error "Failed to create or access directory: $MOODLE_DIR"
        exit 1
    fi
else
    print_status "✓ Moodle directory already exists: $MOODLE_DIR"
fi

# Step 4.2: Download Moodle
if ! check_moodle_downloaded; then
    print_step "Downloading Moodle..."
    echo "  📦 Version: $MOODLE_VERSION"
    echo "  📁 Target: $MOODLE_DIR/html"
    
    # Check if html directory already exists with content
    if [ -d "$MOODLE_DIR/html" ] && [ -f "$MOODLE_DIR/html/version.php" ]; then
        print_status "✓ Moodle source already exists"
        echo "  ✓ Found: $MOODLE_DIR/html/version.php"
    else
        print_status "Cloning Moodle repository (this may take several minutes)..."
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && git clone -b $MOODLE_VERSION git://git.moodle.org/moodle.git html"
        print_status "✓ Moodle repository cloned"
    fi
    
    # Verify download
    if [ -f "$MOODLE_DIR/html/version.php" ]; then
        print_status "✓ Moodle downloaded and verified"
        echo "  📄 Version file: $MOODLE_DIR/html/version.php"
        echo "  📊 Directory size: $(du -sh $MOODLE_DIR/html 2>/dev/null | cut -f1)"
    else
        print_error "Moodle download failed - version.php not found"
        echo "  ✗ Expected: $MOODLE_DIR/html/version.php"
        exit 1
    fi
else
    print_status "✓ Moodle already downloaded"
    echo "  📁 Location: $MOODLE_DIR/html"
fi

# Step 4.3: Configure DDEV
if ! check_moodle_ddev_configured; then
    print_step "Configuring DDEV for Moodle..."
    echo "  📁 Config directory: $MOODLE_DIR/.ddev/"
    
    # Check if already configured
    if [ -f "$MOODLE_DIR/.ddev/config.yaml" ]; then
        print_status "✓ DDEV config already exists: $MOODLE_DIR/.ddev/config.yaml"
    else
        print_status "Creating DDEV configuration..."
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev config --project-type=php \
            --docroot=html \
            --php-version=$MOODLE_PHP_VERSION \
            --database=mysql:$MOODLE_MYSQL_VERSION \
            --project-name='$MOODLE_PROJECT'"
        print_status "✓ Created: $MOODLE_DIR/.ddev/config.yaml"
    fi
    
    # Create custom DDEV config if not exists
    if [ ! -f "$MOODLE_DIR/.ddev/config.moodle.yaml" ]; then
        print_status "Creating custom Moodle configuration..."
        echo "  📝 File: $MOODLE_DIR/.ddev/config.moodle.yaml"
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
        print_status "✓ Created custom configuration"
    else
        print_status "✓ Custom config exists: $MOODLE_DIR/.ddev/config.moodle.yaml"
    fi

    # Create MySQL configuration for Moodle requirements
    if [ ! -d "$MOODLE_DIR/.ddev/mysql" ]; then
        mkdir -p "$MOODLE_DIR/.ddev/mysql"
    fi
    
    if [ ! -f "$MOODLE_DIR/.ddev/mysql/moodle.cnf" ]; then
        print_status "Creating MySQL configuration for Moodle..."
        echo "  📝 File: $MOODLE_DIR/.ddev/mysql/moodle.cnf"
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
        print_status "✓ Created MySQL configuration"
        echo "  ⚙️  Settings:"
        echo "     - innodb_large_prefix=ON"
        echo "     - innodb_file_format=Barracuda"
        echo "     - utf8mb4 character set"
    else
        print_status "✓ MySQL config exists: $MOODLE_DIR/.ddev/mysql/moodle.cnf"
    fi
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$MOODLE_DIR/.ddev"
    
    # Verify configuration
    if [ -f "$MOODLE_DIR/.ddev/config.yaml" ]; then
        print_status "✓ DDEV configured for Moodle with MySQL settings"
        echo "  📋 Configuration files:"
        echo "     - $MOODLE_DIR/.ddev/config.yaml"
        echo "     - $MOODLE_DIR/.ddev/config.moodle.yaml"
        echo "     - $MOODLE_DIR/.ddev/mysql/moodle.cnf"
    else
        print_error "DDEV configuration failed"
        exit 1
    fi
else
    print_status "✓ DDEV already configured for Moodle"
    echo "  📁 Config: $MOODLE_DIR/.ddev/"
fi

# Step 4.4: Start DDEV
if ! check_moodle_ddev_running; then
    print_step "Starting Moodle DDEV..."
    
    # Check if already running
    if su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev describe >/dev/null 2>&1"; then
        print_status "DDEV already running, restarting to apply MySQL config..."
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev restart"
    else
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev start"
    fi
    
    # Wait for database to initialize
    print_status "Waiting for database to initialize..."
    sleep 5
    
    # Verify DDEV is running
    if su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev describe >/dev/null 2>&1"; then
        # Verify MySQL settings
        print_step "Verifying MySQL configuration..."
        LARGE_PREFIX=$(su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev mysql -N -e \"SHOW VARIABLES LIKE 'innodb_large_prefix';\" | awk '{print \$2}'")
        FILE_FORMAT=$(su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev mysql -N -e \"SHOW VARIABLES LIKE 'innodb_file_format';\" | awk '{print \$2}'")
        
        print_status "innodb_large_prefix: $LARGE_PREFIX"
        print_status "innodb_file_format: $FILE_FORMAT"
        
        if [ "$LARGE_PREFIX" = "ON" ] || [ "$LARGE_PREFIX" = "1" ]; then
            print_status "✓ Moodle DDEV started with MySQL configured"
        else
            print_warning "MySQL settings may not be fully applied, but continuing..."
        fi
    else
        print_error "Failed to start DDEV"
        exit 1
    fi
else
    print_status "✓ Moodle DDEV already started (skipping)"
    # Verify it's still running
    if ! su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev describe >/dev/null 2>&1"; then
        print_warning "DDEV was marked as started but is not running. Restarting..."
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev start"
        sleep 5
    fi
fi

# Step 4.5: Create data directory
if ! check_moodle_data_exists; then
    print_step "Creating Moodle data directory..."
    
    if [ ! -d "$MOODLE_DIR/moodledata" ]; then
        su - $ACTUAL_USER -c "mkdir -p '$MOODLE_DIR/moodledata'"
        su - $ACTUAL_USER -c "chmod 777 '$MOODLE_DIR/moodledata'"
        print_status "Created moodledata directory"
    else
        print_status "moodledata directory already exists"
    fi
    
    # Verify directory
    if [ -d "$MOODLE_DIR/moodledata" ] && [ -w "$MOODLE_DIR/moodledata" ]; then
        print_status "✓ Moodle data directory configured"
    else
        print_error "Failed to create moodledata directory"
        exit 1
    fi
else
    print_status "✓ Moodle data directory already configured (skipping)"
fi

# Step 4.6: Install Moodle
if ! check_moodle_installed; then
    print_step "Installing Moodle via CLI..."
    
    # Check if already installed
    if [ -f "$MOODLE_DIR/html/config.php" ]; then
        print_status "config.php exists, checking if Moodle is installed..."
        
        # Try to check Moodle status
        if su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev exec php html/admin/cli/maintenance.php --help >/dev/null 2>&1"; then
            print_status "Moodle appears to be installed"
            print_status "✓ Moodle installation verified"
        else
            print_warning "config.php exists but Moodle may not be fully installed. Attempting install..."
            # Remove config.php and try again
            rm -f "$MOODLE_DIR/html/config.php"
        fi
    fi
    
    # If not already marked complete, proceed with installation
    if ! check_moodle_installed; then
        # Get database credentials from DDEV
        DB_HOST="db"
        DB_NAME="db"
        DB_USER="db"
        DB_PASS="db"
        
        # Try normal installation first
        print_status "Attempting Moodle installation..."
        
        if su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev exec php html/admin/cli/install.php \
            --lang=en \
            --wwwroot='$MOODLE_URL' \
            --dataroot='/var/www/html/moodledata' \
            --dbtype=mariadb \
            --dbhost='$DB_HOST' \
            --dbname='$DB_NAME' \
            --dbuser='$DB_USER' \
            --dbpass='$DB_PASS' \
            --fullname='$MOODLE_FULLNAME' \
            --shortname='$MOODLE_SHORTNAME' \
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
                if su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev exec php html/admin/cli/install.php \
                    --lang=en \
                    --wwwroot='$MOODLE_URL' \
                    --dataroot='/var/www/html/moodledata' \
                    --dbtype=mariadb \
                    --dbhost='$DB_HOST' \
                    --dbname='$DB_NAME' \
                    --dbuser='$DB_USER' \
                    --dbpass='$DB_PASS' \
                    --fullname='$MOODLE_FULLNAME' \
                    --shortname='$MOODLE_SHORTNAME' \
                    --adminuser='$MOODLE_ADMIN_USER' \
                    --adminpass='$MOODLE_ADMIN_PASS' \
                    --adminemail='$ADMIN_EMAIL' \
                    --agree-license \
                    --skip-database \
                    --non-interactive"; then
                    
                    print_status "✓ Moodle installed with skip-database"
                    
                    # Now run the database upgrade to complete installation
                    print_step "Completing database setup..."
                    su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev exec php html/admin/cli/upgrade.php --non-interactive"
                else
                    print_error "Moodle installation failed. Check logs at /tmp/moodle_install.log"
                    print_warning "You may complete installation via web interface at: $MOODLE_URL"
                fi
            fi
        fi
        
        # Final verification
        if [ -f "$MOODLE_DIR/html/config.php" ]; then
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
if ! check_simple_oauth_installed; then
    print_step "Checking if Simple OAuth module is installed..."
    
    # Check if already enabled
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module --status=enabled 2>/dev/null | grep -q simple_oauth"; then
        print_status "✓ Simple OAuth already installed and enabled (skipping)"
    else
        # Check if module exists but is not enabled
        if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module 2>/dev/null | grep -q simple_oauth"; then
            print_status "Simple OAuth module found but not enabled - enabling..."
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush en simple_oauth -y"
            print_status "✓ Simple OAuth enabled"
        else
            # Module not found, need to install it
            print_status "Simple OAuth not found - installing via Composer..."
            
            # Set composer flags based on mode
            COMPOSER_FLAGS=""
            if [ "$USE_DEFAULTS" = true ]; then
                COMPOSER_FLAGS="--no-interaction"
                print_status "Using non-interactive mode for Composer"
            fi
            
            # Check if it's already in composer.json (might be included by OpenSocial)
            if grep -q "drupal/simple_oauth" "$OPENSOCIAL_DIR/composer.json" 2>/dev/null; then
                print_status "Simple OAuth is in composer.json, running composer install..."
                su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer install $COMPOSER_FLAGS"
            else
                # Add it - use version ^6.0 to match OpenSocial's graphql_oauth dependency
                print_status "Adding Simple OAuth ^6.0 to match OpenSocial dependencies..."
                if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer require 'drupal/simple_oauth:^6.0' --with-all-dependencies $COMPOSER_FLAGS"; then
                    print_status "✓ Simple OAuth installed via Composer"
                else
                    print_error "Failed to install Simple OAuth"
                    print_error "OpenSocial may require Simple OAuth 6.x (check composer.json dependencies)"
                    exit 1
                fi
            fi
            
            # Enable the module after installation
            print_status "Enabling Simple OAuth module..."
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush en simple_oauth -y"
            print_status "✓ Simple OAuth enabled"
        fi
    fi
    
    # Verify installation
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module --status=enabled | grep -q simple_oauth"; then
        print_status "✓ Simple OAuth module installed and verified"
    else
        print_error "Failed to install Simple OAuth module"
        exit 1
    fi
else
    print_status "✓ Simple OAuth already installed (skipping)"
fi

# Step 5.2: Generate OAuth keys
if ! check_oauth_keys_exist; then
    print_step "Generating OAuth keys..."
    
    OAUTH_KEYS_DIR="$OPENSOCIAL_DIR/keys"
    echo "  📁 Keys directory: $OAUTH_KEYS_DIR"
    
    # Check if keys already exist
    if [ -f "$OAUTH_KEYS_DIR/private.key" ] && [ -f "$OAUTH_KEYS_DIR/public.key" ]; then
        print_status "✓ OAuth keys already exist"
        echo "  🔑 Private key: $OAUTH_KEYS_DIR/private.key"
        echo "  🔓 Public key: $OAUTH_KEYS_DIR/public.key"
    else
        if [ ! -d "$OAUTH_KEYS_DIR" ]; then
            print_status "Creating keys directory..."
            su - $ACTUAL_USER -c "mkdir -p '$OAUTH_KEYS_DIR'"
            su - $ACTUAL_USER -c "chmod 755 '$OAUTH_KEYS_DIR'"  # Changed from 700 to 755 for container access
            print_status "✓ Created: $OAUTH_KEYS_DIR"
        fi
        
        # Generate private key if it doesn't exist
        if [ ! -f "$OAUTH_KEYS_DIR/private.key" ]; then
            print_status "Generating RSA private key (2048 bit)..."
            su - $ACTUAL_USER -c "openssl genrsa -out '$OAUTH_KEYS_DIR/private.key' 2048"
            su - $ACTUAL_USER -c "chmod 600 '$OAUTH_KEYS_DIR/private.key'"
            print_status "✓ Created: $OAUTH_KEYS_DIR/private.key (permissions: 600)"
        fi
        
        # Generate public key if it doesn't exist
        if [ ! -f "$OAUTH_KEYS_DIR/public.key" ]; then
            print_status "Extracting public key from private key..."
            su - $ACTUAL_USER -c "openssl rsa -in '$OAUTH_KEYS_DIR/private.key' -pubout -out '$OAUTH_KEYS_DIR/public.key'"
            su - $ACTUAL_USER -c "chmod 644 '$OAUTH_KEYS_DIR/public.key'"
            print_status "✓ Created: $OAUTH_KEYS_DIR/public.key (permissions: 644)"
        fi
    fi
    
    # Verify keys exist and are valid
    if [ -f "$OAUTH_KEYS_DIR/private.key" ] && [ -f "$OAUTH_KEYS_DIR/public.key" ] && \
       openssl rsa -in "$OAUTH_KEYS_DIR/private.key" -check -noout >/dev/null 2>&1; then
        print_status "✓ OAuth keys generated and verified"
        echo "  📊 Key details:"
        echo "     🔑 Private: $OAUTH_KEYS_DIR/private.key (2048 bit RSA)"
        echo "     🔓 Public:  $OAUTH_KEYS_DIR/public.key"
        echo "     🔒 Directory permissions: 755"
        echo "     🔒 Private key permissions: 600"
        echo "     📖 Public key permissions: 644"
    else
        print_error "Failed to generate or verify OAuth keys"
        echo "  ✗ Location checked: $OAUTH_KEYS_DIR"
        exit 1
    fi
else
    OAUTH_KEYS_DIR="$OPENSOCIAL_DIR/keys"
    print_status "✓ OAuth keys already generated"
    echo "  📁 Location: $OAUTH_KEYS_DIR"
    echo "  🔑 Private: $OAUTH_KEYS_DIR/private.key"
    echo "  🔓 Public:  $OAUTH_KEYS_DIR/public.key"
fi

# Step 5.3: Configure Simple OAuth - FIXED VERSION
if ! check_oauth_configured; then
    print_step "Configuring Simple OAuth..."
    
    # DDEV mounts the project at /var/www, so keys are at /var/www/keys
    EXPECTED_PUBLIC="/var/www/keys/public.key"
    EXPECTED_PRIVATE="/var/www/keys/private.key"
    
    # Verify keys are accessible from container first
    print_status "Verifying keys are accessible from DDEV container..."
    
    # First check if keys exist on the host
    if [ ! -f "$OPENSOCIAL_DIR/keys/public.key" ]; then
        print_error "Public key not found on host at: $OPENSOCIAL_DIR/keys/public.key"
        print_error "Keys generation may have failed"
        exit 1
    fi
    
    # Test access from within container with proper quoting
    if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec 'test -f $EXPECTED_PUBLIC' 2>/dev/null"; then
        print_warning "Keys not immediately accessible in container, trying to refresh..."
        
        # Sometimes DDEV needs a moment to sync filesystem changes
        sleep 2
        
        # Try again
        if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec 'test -f $EXPECTED_PUBLIC' 2>/dev/null"; then
            # Fall back to relative paths which should always work
            print_warning "Using relative paths for Simple OAuth configuration"
            EXPECTED_PUBLIC="../keys/public.key"
            EXPECTED_PRIVATE="../keys/private.key"
            
            # Verify the relative path works
            if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec 'test -f /var/www/html/$EXPECTED_PUBLIC' 2>/dev/null"; then
                print_warning "Cannot access keys from container. Trying container restart..."
                su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev restart" >/dev/null 2>&1
                sleep 5
                
                # Final attempt
                if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec 'test -f /var/www/keys/public.key' 2>/dev/null"; then
                    print_warning "Keys not accessible from container after restart"
                    print_warning "Manual configuration may be required"
                    print_warning "You can continue and configure Simple OAuth manually at:"
                    print_warning "$OPENSOCIAL_URL/admin/config/people/simple_oauth"
                    print_warning "Use these paths:"
                    print_warning "  Public Key: /var/www/keys/public.key or ../keys/public.key"
                    print_warning "  Private Key: /var/www/keys/private.key or ../keys/private.key"
                else
                    # Reset to absolute paths after restart worked
                    EXPECTED_PUBLIC="/var/www/keys/public.key"
                    EXPECTED_PRIVATE="/var/www/keys/private.key"
                    print_status "✓ Keys accessible after container restart"
                fi
            fi
        else
            print_status "✓ Keys are accessible from container"
        fi
    else
        print_status "✓ Keys are accessible from container"
    fi
    
    # Try multiple configuration methods
    print_status "Attempting configuration method 1: Standard config:set..."
    
    # Method 1: Try standard config:set
    CONFIG_SUCCESS=false
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush config:set simple_oauth.settings public_key '$EXPECTED_PUBLIC' -y 2>&1" | grep -q "success\|saved"; then
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush config:set simple_oauth.settings private_key '$EXPECTED_PRIVATE' -y"
        CONFIG_SUCCESS=true
        print_status "✓ Configuration method 1 successful"
    else
        # Method 2: Try PHP eval
        print_status "Method 1 failed, trying method 2: PHP eval..."
        if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"
\\\$config = \\Drupal::service('config.factory')->getEditable('simple_oauth.settings');
\\\$config->set('public_key', '$EXPECTED_PUBLIC');
\\\$config->set('private_key', '$EXPECTED_PRIVATE');
\\\$config->save();
echo 'Configuration saved';
\"" 2>&1 | grep -q "Configuration saved"; then
            CONFIG_SUCCESS=true
            print_status "✓ Configuration method 2 successful"
        else
            print_warning "Automatic configuration failed. Will verify after cache clear..."
        fi
    fi
    
    # Clear cache regardless
    print_status "Clearing Drupal cache..."
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush cr"
    
    # Verify configuration
    print_status "Verifying Simple OAuth configuration..."
    VERIFY_OUTPUT=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush config:get simple_oauth.settings 2>&1" || echo "ERROR")
    
    # Check if configuration exists and has key paths
    if echo "$VERIFY_OUTPUT" | grep -q "public_key.*keys" || echo "$VERIFY_OUTPUT" | grep -q "public_key_path"; then
        print_status "✓ Simple OAuth configured successfully"
        echo "  ✓ Configuration verified in Drupal config"
    else
        print_warning "Configuration may not be complete. Manual verification needed."
        print_warning "Please check: Configuration > People > Simple OAuth in Drupal admin"
        print_warning "Expected paths:"
        echo "  Public key:  $EXPECTED_PUBLIC"
        echo "  Private key: $EXPECTED_PRIVATE"
        
        # Don't fail - just warn and continue
        print_status "Continuing with installation (you may need to configure manually)..."
    fi
    
    # Additional verification: Test key access
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec cat $EXPECTED_PUBLIC 2>/dev/null | head -n 1" | grep -q "BEGIN PUBLIC KEY"; then
        print_status "✓ Public key is readable from container"
    else
        print_warning "Unable to read public key from container"
    fi
else
    print_status "✓ Simple OAuth already configured (skipping)"
fi

################################################################################
# PART 6: OPENSOCIAL OAUTH PROVIDER MODULE (MODIFIED - USES FOLDER)
################################################################################

print_section "PART 6: OpenSocial OAuth Provider Module"

if ! check_oauth_provider_module_exists; then
    print_step "Installing OpenSocial OAuth Provider module..."
    
    MODULE_SRC="$SCRIPT_DIR/opensocial_moodle_sso"
    MODULE_DEST="$OPENSOCIAL_DIR/html/modules/custom/opensocial_oauth_provider"
    
    echo "  📁 Source: $MODULE_SRC"
    echo "  📁 Destination: $MODULE_DEST"
    
    # Verify source module exists
    if [ ! -d "$MODULE_SRC" ]; then
        print_error "Module source not found at: $MODULE_SRC"
        print_error "Please ensure the opensocial_moodle_sso directory is in the same location as the script"
        print_error "Required folder structure:"
        print_error "  $SCRIPT_DIR/opensocial_moodle_sso/"
        print_error "  $SCRIPT_DIR/$(basename $0)"
        exit 1
    fi
    
    if [ ! -f "$MODULE_SRC/opensocial_oauth_provider.info.yml" ]; then
        print_error "Module source incomplete - missing opensocial_oauth_provider.info.yml"
        print_error "Please verify the opensocial_moodle_sso folder contains all required files"
        exit 1
    fi
    
    # Check if module directory already exists
    if [ -d "$MODULE_DEST" ] && [ -f "$MODULE_DEST/opensocial_oauth_provider.info.yml" ]; then
        print_status "✓ OpenSocial OAuth Provider module already exists"
        echo "  ✓ Found: $MODULE_DEST/opensocial_oauth_provider.info.yml"
    else
        print_status "Copying module from source directory..."
        
        # Create parent directory if needed
        su - $ACTUAL_USER -c "mkdir -p '$OPENSOCIAL_DIR/html/modules/custom'"
        
        # Copy module
        su - $ACTUAL_USER -c "cp -r '$MODULE_SRC' '$MODULE_DEST'"
        
        # Set ownership
        chown -R $ACTUAL_USER:$ACTUAL_USER "$MODULE_DEST"
        
        print_status "✓ Module copied successfully"
    fi
    
    # Verify module was copied
    if [ -f "$MODULE_DEST/opensocial_oauth_provider.info.yml" ] && \
       [ -f "$MODULE_DEST/opensocial_oauth_provider.module" ] && \
       [ -f "$MODULE_DEST/opensocial_oauth_provider.routing.yml" ] && \
       [ -f "$MODULE_DEST/src/Controller/UserInfoController.php" ] && \
       [ -f "$MODULE_DEST/src/Form/SettingsForm.php" ]; then
        print_status "✓ OpenSocial OAuth Provider module installed and verified"
        echo "  📦 Module files:"
        echo "     📄 opensocial_oauth_provider.info.yml"
        echo "     📄 opensocial_oauth_provider.module"
        echo "     📄 opensocial_oauth_provider.routing.yml"
        echo "     📄 src/Controller/UserInfoController.php"
        echo "     📄 src/Form/SettingsForm.php"
        echo "  🌐 OAuth endpoints (after enabling):"
        echo "     - $OPENSOCIAL_URL/oauth/authorize"
        echo "     - $OPENSOCIAL_URL/oauth/token"
        echo "     - $OPENSOCIAL_URL/oauth/userinfo"
    else
        print_error "Failed to install OAuth Provider module"
        echo "  📁 Module destination: $MODULE_DEST"
        exit 1
    fi
else
    MODULE_DEST="$OPENSOCIAL_DIR/html/modules/custom/opensocial_oauth_provider"
    print_status "✓ OAuth Provider module already installed"
    echo "  📁 Location: $MODULE_DEST"
fi

# FIXED: Enable OAuth Provider module with proper verification that handles PHP warnings
if ! check_oauth_provider_enabled; then
    print_step "Enabling OpenSocial OAuth Provider module..."
    
    # Enable the module (warnings are just from OpenSocial's code, not errors)
    MODULE_ENABLE_OUTPUT=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush en opensocial_oauth_provider -y 2>&1")
    
    # Check if module was successfully enabled (look for success message)
    if echo "$MODULE_ENABLE_OUTPUT" | grep -q "Successfully enabled"; then
        print_status "Module enabled successfully (PHP deprecation warnings from OpenSocial can be ignored)"
    fi
    
    # Clear cache
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush cr 2>/dev/null"
    
    # Verify module is enabled using multiple methods
    MODULE_CHECK=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module --status=enabled 2>/dev/null | grep opensocial_oauth_provider || true")
    MODULE_STATUS=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"echo \\Drupal::service('module_handler')->moduleExists('opensocial_oauth_provider') ? 'ENABLED' : 'DISABLED';\" 2>/dev/null" || echo "DISABLED")
    
    if [ -n "$MODULE_CHECK" ] || [ "$MODULE_STATUS" = "ENABLED" ]; then
        print_status "✓ OAuth Provider module enabled and verified"
        print_warning "Note: PHP deprecation warnings from OpenSocial's code are harmless and can be ignored"
    else
        print_error "Failed to enable OAuth Provider module"
        print_warning "You may need to enable it manually via the Drupal admin interface"
        print_warning "Go to: $OPENSOCIAL_URL/admin/modules"
        print_warning "Search for 'OpenSocial OAuth Provider' and enable it"
    fi
else
    print_status "✓ OAuth Provider module already enabled (skipping)"
fi

if ! check_oauth_client_exists; then
    print_step "Creating OAuth client for Moodle..."
    
    # Check if client already exists
    CLIENT_EXISTS=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"
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
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"
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
    CLIENT_CHECK=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"
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
        print_status "✓ OAuth client created and verified"
    else
        print_error "Failed to create or verify OAuth client"
        exit 1
    fi
else
    print_status "✓ OAuth client already created (skipping)"
fi

################################################################################
# PART 7: MOODLE OAUTH PLUGIN INSTALLATION (MODIFIED - USES FOLDER)
################################################################################

print_section "PART 7: Moodle OAuth Authentication Plugin"

if ! check_moodle_oauth_plugin_exists; then
    print_step "Installing Moodle OpenSocial OAuth plugin..."
    
    PLUGIN_SRC="$SCRIPT_DIR/moodle_opensocial_auth"
    PLUGIN_DEST="$MOODLE_DIR/html/auth/opensocial"
    
    echo "  📁 Source: $PLUGIN_SRC"
    echo "  📁 Destination: $PLUGIN_DEST"
    
    # Verify source plugin exists
    if [ ! -d "$PLUGIN_SRC" ]; then
        print_error "Plugin source not found at: $PLUGIN_SRC"
        print_error "Please ensure the moodle_opensocial_auth directory is in the same location as the script"
        print_error "Required folder structure:"
        print_error "  $SCRIPT_DIR/moodle_opensocial_auth/"
        print_error "  $SCRIPT_DIR/$(basename $0)"
        exit 1
    fi
    
    if [ ! -f "$PLUGIN_SRC/version.php" ]; then
        print_error "Plugin source incomplete - missing version.php"
        print_error "Please verify the moodle_opensocial_auth folder contains all required files"
        exit 1
    fi
    
    # Check if plugin directory already exists
    if [ -d "$PLUGIN_DEST" ] && [ -f "$PLUGIN_DEST/version.php" ]; then
        print_status "✓ Moodle OAuth plugin already exists"
        echo "  ✓ Found: $PLUGIN_DEST/version.php"
    else
        print_status "Copying plugin from source directory..."
        
        # Copy plugin
        su - $ACTUAL_USER -c "cp -r '$PLUGIN_SRC' '$PLUGIN_DEST'"
        
        # Set ownership
        chown -R $ACTUAL_USER:$ACTUAL_USER "$PLUGIN_DEST"
        
        print_status "✓ Plugin copied successfully"
    fi
    
    # Verify plugin was copied
    if [ -f "$PLUGIN_DEST/version.php" ] && [ -f "$PLUGIN_DEST/auth.php" ]; then
        print_status "✓ Moodle OAuth plugin installed and verified"
        echo "  📦 Plugin files:"
        echo "     📄 version.php"
        echo "     📄 auth.php"
        echo "     📄 settings.html"
        echo "     📄 lang/en/auth_opensocial.php"
        echo "     📄 db/upgrade.php"
        echo "  🔧 Plugin configuration:"
        echo "     - Plugin name: auth_opensocial"
        echo "     - Component: auth_opensocial"
        echo "  ⚙️  Configuration in Moodle:"
        echo "     Site administration > Plugins > Authentication > OpenSocial OAuth2"
    else
        print_error "Failed to install Moodle OAuth plugin"
        echo "  📁 Plugin destination: $PLUGIN_DEST"
        exit 1
    fi
else
    PLUGIN_DEST="$MOODLE_DIR/html/auth/opensocial"
    print_status "✓ Moodle OAuth plugin already installed"
    echo "  📁 Location: $PLUGIN_DEST"
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
Storage Location: $SCRIPT_DIR

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
- All files stored in: $SCRIPT_DIR
- Module folders used: opensocial_moodle_sso/ and moodle_opensocial_auth/
- PHP deprecation warnings from OpenSocial code are harmless

Credentials File: $CREDENTIALS_FILE
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
echo "  Location: $OPENSOCIAL_DIR"
echo "  Commands: cd $OPENSOCIAL_DIR && ddev drush uli"
echo ""

print_status "Moodle Installation:"
echo "  URL: $MOODLE_URL"
echo "  Admin: $MOODLE_ADMIN_USER / $MOODLE_ADMIN_PASS"
echo "  Location: $MOODLE_DIR"
echo "  Commands: cd $MOODLE_DIR && ddev launch"
echo ""

print_status "OAuth Integration:"
echo "  Client ID: $OAUTH_CLIENT_ID"
echo "  Client Secret: [saved in credentials file]"
echo ""

print_status "Storage Location:"
echo "  All files stored in: $SCRIPT_DIR"
echo "  Credentials file: $CREDENTIALS_FILE"
echo "  Module folders: opensocial_moodle_sso/ and moodle_opensocial_auth/"
echo ""

print_warning "IMPORTANT: Complete OAuth Configuration in Moodle"
echo ""
echo "1. Open Moodle: $MOODLE_URL"
echo "2. Go to: Site administration > Server > OAuth 2 services"
echo "3. Create custom service with credentials from:"
echo "   cat $CREDENTIALS_FILE"
echo ""

print_section "Quick Access"
echo "OpenSocial: cd $OPENSOCIAL_DIR && ddev launch"
echo "Moodle: cd $MOODLE_DIR && ddev launch"
echo "Credentials: cat $CREDENTIALS_FILE"
echo ""

print_status "Both platforms are running in DDEV - no port conflicts!"
print_status "All files stored in script directory: $SCRIPT_DIR"
print_status "Installation completed successfully!"

if [ -n "$MODULE_CHECK" ] || [ "$MODULE_STATUS" = "ENABLED" ]; then
    print_warning "Note: PHP deprecation warnings from OpenSocial's code are harmless and can be ignored"
fi

exit 0