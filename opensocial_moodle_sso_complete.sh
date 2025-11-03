#!/bin/bash

################################################################################
# OpenSocial + Moodle Fully Integrated SSO Installation Script (DDEV Version)
# IMPROVED VERSION with cleanup and better step tracking
# Both platforms installed in DDEV to avoid port conflicts
# Based on: https://github.com/rjzaar/opensocial-moodle-sso-integration
# Modified to use module folders instead of inline creation
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=50
CURRENT_STEP=0

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} ${WHITE}$1${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
}

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[Step $CURRENT_STEP/$TOTAL_STEPS]${NC} ${WHITE}$1${NC} ${BLUE}($percentage%)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_checking() {
    echo -e "${BLUE}[Checking]${NC} $1..."
}

print_doing() {
    echo -e "${YELLOW}[Executing]${NC} $1..."
}

print_skipping() {
    echo -e "${GREEN}[Skipping]${NC} $1 (already complete)"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: sudo bash $0 [OPTIONS]

OpenSocial + Moodle SSO Integration Installation Script

OPTIONS:
    --defaults, -d    Run with default options (non-interactive mode)
    --cleanup         Remove existing installations before starting
    --help, -h        Show this help message
    --force           Force reinstallation even if components exist

EXAMPLES:
    # Interactive mode
    sudo bash $0
    
    # Non-interactive with cleanup
    sudo bash $0 --defaults --cleanup
    
    # Force reinstall everything
    sudo bash $0 --defaults --force

FEATURES:
    ✓ Automatic step verification
    ✓ Resume from last successful step
    ✓ Cleanup previous installations
    ✓ Progress tracking
    ✓ Detailed status reporting

EOF
}

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

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

# Parse command line arguments
USE_DEFAULTS=false
DO_CLEANUP=false
FORCE_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --defaults|-d)
            USE_DEFAULTS=true
            shift
            ;;
        --cleanup)
            DO_CLEANUP=true
            shift
            ;;
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

################################################################################
# CONFIGURATION LOADING
################################################################################

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
        print_status "Configuration loaded successfully"
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
    
    if ! command -v ddev &> /dev/null; then
        echo "$test_name"
        return
    fi
    
    while su - $ACTUAL_USER -c "ddev list 2>/dev/null | grep -q \"$test_name\""; do
        counter=$((counter + 1))
        test_name="${project_name}${counter}"
    done
    
    echo "$test_name"
}

################################################################################
# STATE CHECKING FUNCTIONS
################################################################################

check_system_updated() {
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

check_oauth_configured() {
    [ -d "$OPENSOCIAL_DIR" ] || return 1
    
    local config_check=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush config:get simple_oauth.settings 2>/dev/null" || echo "")
    
    if echo "$config_check" | grep -qE "public_key.*(/var/www/keys|../keys|keys)"; then
        return 0
    fi
    
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec 'test -f /var/www/keys/public.key' 2>/dev/null"; then
        if check_simple_oauth_installed; then
            return 0
        fi
    fi
    
    return 1
}

check_oauth_provider_module_exists() {
    [ -f "$OPENSOCIAL_DIR/html/modules/custom/opensocial_oauth_provider/opensocial_oauth_provider.info.yml" ]
}

check_oauth_provider_enabled() {
    [ -d "$OPENSOCIAL_DIR" ] || return 1
    
    local module_check=$(su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module --status=enabled 2>/dev/null | grep opensocial_oauth_provider || true")
    [ -n "$module_check" ] && return 0
    
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
# CLEANUP FUNCTIONS
################################################################################

cleanup_opensocial() {
    print_step "Cleaning up OpenSocial installation"
    
    if [ -d "$OPENSOCIAL_DIR" ]; then
        print_doing "Stopping OpenSocial DDEV"
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev stop" 2>/dev/null || true
        
        print_doing "Removing OpenSocial DDEV project"
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev delete -y" 2>/dev/null || true
        
        print_doing "Removing OpenSocial directory"
        rm -rf "$OPENSOCIAL_DIR"
        
        print_status "OpenSocial cleanup complete"
    else
        print_skipping "OpenSocial cleanup (directory doesn't exist)"
    fi
}

cleanup_moodle() {
    print_step "Cleaning up Moodle installation"
    
    if [ -d "$MOODLE_DIR" ]; then
        print_doing "Stopping Moodle DDEV"
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev stop" 2>/dev/null || true
        
        print_doing "Removing Moodle DDEV project"
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev delete -y" 2>/dev/null || true
        
        print_doing "Removing Moodle directory"
        rm -rf "$MOODLE_DIR"
        
        print_status "Moodle cleanup complete"
    else
        print_skipping "Moodle cleanup (directory doesn't exist)"
    fi
}

cleanup_all() {
    print_section "CLEANUP: Removing Previous Installations"
    
    cleanup_opensocial
    cleanup_moodle
    
    # Remove credentials file
    if [ -f "$CREDENTIALS_FILE" ]; then
        print_doing "Removing credentials file"
        rm -f "$CREDENTIALS_FILE"
        print_status "Credentials file removed"
    fi
    
    print_status "✓ All cleanup complete"
}

################################################################################
# PRE-FLIGHT CHECK
################################################################################

run_preflight_check() {
    print_section "PRE-FLIGHT CHECK: Analyzing Current State"
    
    local steps_needed=0
    local steps_complete=0
    
    echo ""
    print_status "Checking system prerequisites..."
    
    # Check each major component
    local checks=(
        "System packages|check_system_updated"
        "Prerequisites|check_prerequisites_installed"
        "Docker|check_docker_installed"
        "DDEV|check_ddev_installed"
        "mkcert|check_mkcert_installed"
        "OpenSocial directory|check_opensocial_dir_exists"
        "OpenSocial DDEV config|check_opensocial_ddev_configured"
        "OpenSocial DDEV running|check_opensocial_ddev_running"
        "OpenSocial Composer|check_opensocial_composer_installed"
        "OpenSocial private dir|check_opensocial_private_configured"
        "OpenSocial installed|check_opensocial_installed"
        "Simple OAuth|check_simple_oauth_installed"
        "OAuth keys|check_oauth_keys_exist"
        "OAuth configured|check_oauth_configured"
        "OAuth Provider module|check_oauth_provider_module_exists"
        "OAuth Provider enabled|check_oauth_provider_enabled"
        "Moodle directory|check_moodle_dir_exists"
        "Moodle downloaded|check_moodle_downloaded"
        "Moodle DDEV config|check_moodle_ddev_configured"
        "Moodle DDEV running|check_moodle_ddev_running"
        "Moodle data directory|check_moodle_data_exists"
        "Moodle installed|check_moodle_installed"
        "Moodle OAuth plugin|check_moodle_oauth_plugin_exists"
    )
    
    echo ""
    echo -e "${CYAN}Component Status:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    
    for check in "${checks[@]}"; do
        IFS='|' read -r name func <<< "$check"
        steps_needed=$((steps_needed + 1))
        
        if $func 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $name"
            steps_complete=$((steps_complete + 1))
        else
            echo -e "  ${RED}✗${NC} $name ${YELLOW}(needs installation)${NC}"
        fi
    done
    
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    
    local percentage=$((steps_complete * 100 / steps_needed))
    echo -e "${WHITE}Installation Status:${NC} $steps_complete/$steps_needed complete ${BLUE}($percentage%)${NC}"
    
    if [ $steps_complete -eq $steps_needed ]; then
        echo ""
        print_status "All components are already installed!"
        if [ "$FORCE_INSTALL" = true ]; then
            print_warning "Force flag detected - will reinstall anyway"
        else
            echo ""
            read -p "Do you want to proceed anyway? (y/N): " confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                print_status "Installation cancelled"
                exit 0
            fi
        fi
    else
        echo -e "${YELLOW}Steps remaining:${NC} $((steps_needed - steps_complete))"
    fi
    
    echo ""
    print_status "Pre-flight check complete"
    sleep 2
}

################################################################################
# MAIN CONFIGURATION
################################################################################

print_section "OpenSocial + Moodle SSO Installation (DDEV)"
echo ""
print_status "Script directory: $SCRIPT_DIR"
print_status "Running as user: $ACTUAL_USER"
echo ""

# Handle cleanup if requested
if [ "$DO_CLEANUP" = true ]; then
    echo ""
    print_warning "Cleanup requested - this will remove ALL existing installations!"
    if [ "$USE_DEFAULTS" != true ]; then
        read -p "Are you sure you want to continue? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            print_status "Cleanup cancelled"
            exit 0
        fi
    fi
    cleanup_all
    echo ""
fi

# Load configuration
if [ "$USE_DEFAULTS" = true ]; then
    load_config
fi

# Set configuration variables
if [ "$USE_DEFAULTS" = true ] && [ -n "$CONFIG_admin_email" ]; then
    ADMIN_EMAIL="${CONFIG_admin_email}"
    ADMIN_USER="${CONFIG_admin_username}"
    ADMIN_PASS="${CONFIG_admin_password}"
else
    ADMIN_USER="admin"
    ADMIN_PASS="admin"
    if [ "$USE_DEFAULTS" = true ]; then
        ADMIN_EMAIL="admin@example.com"
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
OPENSOCIAL_DIR="$SCRIPT_DIR/$OPENSOCIAL_PROJECT"
OPENSOCIAL_URL="https://${OPENSOCIAL_PROJECT}.ddev.site"
OPENSOCIAL_ADMIN_USER="$ADMIN_USER"
OPENSOCIAL_ADMIN_PASS="$ADMIN_PASS"

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
MOODLE_DIR="$SCRIPT_DIR/$MOODLE_PROJECT"
MOODLE_URL="https://${MOODLE_PROJECT}.ddev.site"
MOODLE_ADMIN_USER="$ADMIN_USER"
MOODLE_ADMIN_PASS="$ADMIN_PASS"

# OAuth Configuration
OAUTH_CLIENT_ID=$(cat /proc/sys/kernel/random/uuid)
OAUTH_CLIENT_SECRET=$(openssl rand -hex 32)

# Credentials file
CREDENTIALS_FILE="$SCRIPT_DIR/opensocial_moodle_ddev_credentials.txt"

# Display configuration
print_section "CONFIGURATION SUMMARY"
echo ""
echo -e "${WHITE}OpenSocial:${NC}"
echo "  URL: $OPENSOCIAL_URL"
echo "  Directory: $OPENSOCIAL_DIR"
echo "  Version: $OPENSOCIAL_VERSION"
echo ""
echo -e "${WHITE}Moodle:${NC}"
echo "  URL: $MOODLE_URL"
echo "  Directory: $MOODLE_DIR"
echo "  Version: $MOODLE_VERSION"
echo ""
echo -e "${WHITE}Admin Account:${NC}"
echo "  Email: $ADMIN_EMAIL"
echo "  Username: $ADMIN_USER"
echo "  Password: $ADMIN_PASS"
echo ""

# Run pre-flight check
run_preflight_check

# Confirmation before starting
if [ "$USE_DEFAULTS" != true ]; then
    echo ""
    read -p "Press Enter to begin installation or Ctrl+C to cancel..."
fi

################################################################################
# PART 1: SYSTEM PREREQUISITES
################################################################################

print_section "PART 1/8: System Prerequisites"

print_step "Checking system package updates"
print_checking "Last system update"
if ! check_system_updated || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Updating system packages"
    apt update && apt upgrade -y
    print_status "System updated successfully"
else
    print_skipping "System update (recently updated)"
fi

print_step "Checking prerequisite packages"
print_checking "curl, git, unzip, wget"
if ! check_prerequisites_installed || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Installing prerequisite packages"
    
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
    print_status "Prerequisites installed successfully"
else
    print_skipping "Prerequisite installation (all packages present)"
fi

################################################################################
# PART 2: DOCKER AND DDEV INSTALLATION
################################################################################

print_section "PART 2/8: Docker and DDEV Installation"

print_step "Checking Docker installation"
print_checking "Docker availability"
if ! check_docker_installed || [ "$FORCE_INSTALL" = true ]; then
    if ! command -v docker &> /dev/null || [ "$FORCE_INSTALL" = true ]; then
        print_doing "Installing Docker"
        
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        usermod -aG docker $ACTUAL_USER
        
        print_status "Docker installed successfully"
    else
        print_status "Docker already installed"
    fi
else
    print_skipping "Docker installation (already present and working)"
fi

print_step "Checking DDEV installation"
print_checking "DDEV availability"
if ! check_ddev_installed || [ "$FORCE_INSTALL" = true ]; then
    if ! command -v ddev &> /dev/null || [ "$FORCE_INSTALL" = true ]; then
        print_doing "Installing DDEV"
        curl -fsSL https://ddev.com/install.sh | bash
        print_status "DDEV installed successfully"
    else
        print_status "DDEV already installed"
    fi
else
    print_skipping "DDEV installation (already present and working)"
fi

print_step "Checking mkcert for HTTPS"
print_checking "mkcert availability"
if ! check_mkcert_installed || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Installing mkcert"
    
    if ! command -v mkcert &> /dev/null || [ "$FORCE_INSTALL" = true ]; then
        curl -fsSL https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64 -o mkcert
        chmod +x mkcert
        mv mkcert /usr/local/bin/
    fi
    
    su - $ACTUAL_USER -c "mkcert -install"
    
    print_status "mkcert installed and CA configured"
else
    print_skipping "mkcert installation (already present and configured)"
fi

################################################################################
# PART 3: OPENSOCIAL INSTALLATION
################################################################################

print_section "PART 3/8: OpenSocial Installation"

print_step "Creating OpenSocial project directory"
print_checking "Directory: $OPENSOCIAL_DIR"
if ! check_opensocial_dir_exists || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Creating OpenSocial directory"
    
    if [ ! -d "$OPENSOCIAL_DIR" ] || [ "$FORCE_INSTALL" = true ]; then
        mkdir -p "$OPENSOCIAL_DIR" || su - $ACTUAL_USER -c "mkdir -p '$OPENSOCIAL_DIR'"
        print_status "Directory created: $OPENSOCIAL_DIR"
    fi
    
    if [ -d "$OPENSOCIAL_DIR" ] && [ -w "$OPENSOCIAL_DIR" ]; then
        print_status "OpenSocial directory ready"
    else
        print_error "Failed to create or access directory"
        exit 1
    fi
else
    print_skipping "Directory creation (already exists)"
fi

print_step "Configuring DDEV for OpenSocial"
print_checking "DDEV configuration files"
if ! check_opensocial_ddev_configured || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Setting up DDEV configuration"
    
    if [ ! -f "$OPENSOCIAL_DIR/.ddev/config.yaml" ] || [ "$FORCE_INSTALL" = true ]; then
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev config --project-type=drupal \
            --docroot=html \
            --php-version=$OPENSOCIAL_PHP_VERSION \
            --database=mysql:$OPENSOCIAL_MYSQL_VERSION \
            --nodejs-version=$OPENSOCIAL_NODEJS_VERSION \
            --project-name='$OPENSOCIAL_PROJECT' \
            --create-docroot"
        print_status "Base DDEV config created"
    fi
    
    if [ ! -f "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml" ] || [ "$FORCE_INSTALL" = true ]; then
        print_doing "Creating custom OpenSocial configuration"
        cat > "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml" <<EOF
webimage_extra_packages: [php${OPENSOCIAL_PHP_VERSION}-gd, php${OPENSOCIAL_PHP_VERSION}-uploadprogress]
php_memory_limit: 512M
hooks:
  post-start:
    - exec: composer install --no-interaction || true
EOF
        chown $ACTUAL_USER:$ACTUAL_USER "$OPENSOCIAL_DIR/.ddev/config.opensocial.yaml"
        print_status "Custom configuration created"
    fi
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$OPENSOCIAL_DIR/.ddev"
    print_status "DDEV configured for OpenSocial"
else
    print_skipping "DDEV configuration (already exists)"
fi

print_step "Starting OpenSocial DDEV"
print_checking "DDEV container status"
if ! check_opensocial_ddev_running || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Starting DDEV containers"
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev start"
    
    if su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev describe >/dev/null 2>&1"; then
        print_status "OpenSocial DDEV started successfully"
    else
        print_error "Failed to start DDEV"
        exit 1
    fi
else
    print_skipping "DDEV start (already running)"
    if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev describe >/dev/null 2>&1"; then
        print_warning "DDEV was marked as running but is not. Restarting..."
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev start"
    fi
fi

print_step "Installing OpenSocial via Composer"
print_checking "Composer installation status"
if ! check_opensocial_composer_installed || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Running Composer installation"
    
    COMPOSER_FLAGS=""
    if [ "$USE_DEFAULTS" = true ]; then
        COMPOSER_FLAGS="--no-interaction"
    fi
    
    if [ ! -f "$OPENSOCIAL_DIR/composer.json" ] || [ "$FORCE_INSTALL" = true ]; then
        if [ "$OPENSOCIAL_VERSION" = "dev-master" ]; then
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer create-project rjzaar/commons_template:dev-master . --no-interaction --stability dev"
        else
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer create-project rjzaar/commons_template:$OPENSOCIAL_VERSION . --no-interaction"
        fi
    else
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer install $COMPOSER_FLAGS"
    fi
    
    if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush --version >/dev/null 2>&1"; then
        print_doing "Installing Drush"
        su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer require drush/drush --dev $COMPOSER_FLAGS"
    fi
    
    print_status "OpenSocial installed via Composer"
else
    print_skipping "Composer installation (already complete)"
fi

print_step "Configuring private file directory"
print_checking "Private directory status"
if ! check_opensocial_private_configured || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Setting up private directory"
    
    PRIVATE_DIR="$OPENSOCIAL_DIR/../private"
    
    if [ ! -d "$PRIVATE_DIR" ] || [ "$FORCE_INSTALL" = true ]; then
        su - $ACTUAL_USER -c "mkdir -p '$PRIVATE_DIR'"
        su - $ACTUAL_USER -c "chmod 755 '$PRIVATE_DIR'"
        print_status "Private directory created"
    fi
    
    print_status "Private directory configured"
else
    print_skipping "Private directory configuration (already set up)"
fi

print_step "Installing Drupal/OpenSocial"
print_checking "Drupal installation status"
if ! check_opensocial_installed || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Running Drupal site installation"
    
    SETTINGS_DIR="$OPENSOCIAL_DIR/html/sites/default"
    
    if [ -d "$SETTINGS_DIR" ]; then
        su - $ACTUAL_USER -c "chmod 755 '$SETTINGS_DIR'" 2>/dev/null || true
        
        if [ -f "$SETTINGS_DIR/default.settings.php" ] && [ ! -f "$SETTINGS_DIR/settings.php" ]; then
            su - $ACTUAL_USER -c "cp '$SETTINGS_DIR/default.settings.php' '$SETTINGS_DIR/settings.php'"
        fi
        
        if [ -f "$SETTINGS_DIR/settings.php" ]; then
            su - $ACTUAL_USER -c "chmod 666 '$SETTINGS_DIR/settings.php'" 2>/dev/null || true
            
            if ! grep -q "\$settings\['file_private_path'\]" "$SETTINGS_DIR/settings.php"; then
                cat >> "$SETTINGS_DIR/settings.php" <<'EOF'

/**
 * Private file path configuration.
 */
$settings['file_private_path'] = '../private';
EOF
            fi
        fi
    fi
    
    print_doing "Installing OpenSocial (this may take several minutes)"
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush site:install social \
        --account-name='$OPENSOCIAL_ADMIN_USER' \
        --account-pass='$OPENSOCIAL_ADMIN_PASS' \
        --account-mail='$ADMIN_EMAIL' \
        --site-name='$OPENSOCIAL_SITE_NAME' \
        --site-mail='$ADMIN_EMAIL' \
        --locale=en \
        --yes"
    
    if [ -f "$SETTINGS_DIR/settings.php" ]; then
        su - $ACTUAL_USER -c "chmod 444 '$SETTINGS_DIR/settings.php'" 2>/dev/null || true
    fi
    if [ -d "$SETTINGS_DIR" ]; then
        su - $ACTUAL_USER -c "chmod 755 '$SETTINGS_DIR'" 2>/dev/null || true
    fi
    
    print_status "OpenSocial installed successfully"
else
    print_skipping "OpenSocial installation (already complete)"
fi

################################################################################
# PART 4: MOODLE INSTALLATION
################################################################################

print_section "PART 4/8: Moodle Installation"

print_step "Creating Moodle project directory"
print_checking "Directory: $MOODLE_DIR"
if ! check_moodle_dir_exists || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Creating Moodle directory"
    
    if [ ! -d "$MOODLE_DIR" ] || [ "$FORCE_INSTALL" = true ]; then
        mkdir -p "$MOODLE_DIR" || su - $ACTUAL_USER -c "mkdir -p '$MOODLE_DIR'"
        print_status "Directory created: $MOODLE_DIR"
    fi
    
    print_status "Moodle directory ready"
else
    print_skipping "Directory creation (already exists)"
fi

print_step "Downloading Moodle"
print_checking "Moodle source code"
if ! check_moodle_downloaded || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Cloning Moodle repository (this may take several minutes)"
    
    if [ ! -d "$MOODLE_DIR/html" ] || [ "$FORCE_INSTALL" = true ]; then
        [ -d "$MOODLE_DIR/html" ] && rm -rf "$MOODLE_DIR/html"
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && git clone -b $MOODLE_VERSION git://git.moodle.org/moodle.git html"
        print_status "Moodle repository cloned"
    fi
    
    print_status "Moodle downloaded successfully"
else
    print_skipping "Moodle download (already present)"
fi

print_step "Configuring DDEV for Moodle"
print_checking "DDEV configuration files"
if ! check_moodle_ddev_configured || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Setting up DDEV configuration"
    
    if [ ! -f "$MOODLE_DIR/.ddev/config.yaml" ] || [ "$FORCE_INSTALL" = true ]; then
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev config --project-type=php \
            --docroot=html \
            --php-version=$MOODLE_PHP_VERSION \
            --database=mysql:$MOODLE_MYSQL_VERSION \
            --project-name='$MOODLE_PROJECT'"
        print_status "Base DDEV config created"
    fi
    
    if [ ! -f "$MOODLE_DIR/.ddev/config.moodle.yaml" ] || [ "$FORCE_INSTALL" = true ]; then
        print_doing "Creating custom Moodle configuration"
        cat > "$MOODLE_DIR/.ddev/config.moodle.yaml" <<EOF
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
        print_status "Custom configuration created"
    fi
    
    mkdir -p "$MOODLE_DIR/.ddev/mysql"
    
    if [ ! -f "$MOODLE_DIR/.ddev/mysql/moodle.cnf" ] || [ "$FORCE_INSTALL" = true ]; then
        print_doing "Creating MySQL configuration"
        cat > "$MOODLE_DIR/.ddev/mysql/moodle.cnf" <<'MYSQLEOF'
[mysqld]
innodb_large_prefix=ON
innodb_file_format=Barracuda
innodb_file_per_table=ON
innodb_buffer_pool_size=256M
max_allowed_packet=64M
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

[mysql]
default-character-set=utf8mb4
MYSQLEOF
        chown $ACTUAL_USER:$ACTUAL_USER "$MOODLE_DIR/.ddev/mysql/moodle.cnf"
        print_status "MySQL configuration created"
    fi
    
    chown -R $ACTUAL_USER:$ACTUAL_USER "$MOODLE_DIR/.ddev"
    print_status "DDEV configured for Moodle"
else
    print_skipping "DDEV configuration (already exists)"
fi

print_step "Starting Moodle DDEV"
print_checking "DDEV container status"
if ! check_moodle_ddev_running || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Starting DDEV containers"
    su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev start"
    
    print_doing "Waiting for database to initialize"
    sleep 5
    
    if su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev describe >/dev/null 2>&1"; then
        print_status "Moodle DDEV started successfully"
    else
        print_error "Failed to start DDEV"
        exit 1
    fi
else
    print_skipping "DDEV start (already running)"
    if ! su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev describe >/dev/null 2>&1"; then
        print_warning "DDEV was marked as running but is not. Restarting..."
        su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev start"
        sleep 5
    fi
fi

print_step "Creating Moodle data directory"
print_checking "Data directory status"
if ! check_moodle_data_exists || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Setting up moodledata directory"
    
    if [ ! -d "$MOODLE_DIR/moodledata" ] || [ "$FORCE_INSTALL" = true ]; then
        su - $ACTUAL_USER -c "mkdir -p '$MOODLE_DIR/moodledata'"
        su - $ACTUAL_USER -c "chmod 777 '$MOODLE_DIR/moodledata'"
        print_status "Moodledata directory created"
    fi
    
    print_status "Moodle data directory configured"
else
    print_skipping "Data directory creation (already exists)"
fi

print_step "Installing Moodle via CLI"
print_checking "Moodle installation status"
if ! check_moodle_installed || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Running Moodle installation (this may take several minutes)"
    
    if [ -f "$MOODLE_DIR/html/config.php" ] && [ "$FORCE_INSTALL" = true ]; then
        rm -f "$MOODLE_DIR/html/config.php"
    fi
    
    DB_HOST="db"
    DB_NAME="db"
    DB_USER="db"
    DB_PASS="db"
    
    su - $ACTUAL_USER -c "cd '$MOODLE_DIR' && ddev exec php html/admin/cli/install.php \
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
        --non-interactive" 2>&1 | tee /tmp/moodle_install.log || true
    
    if [ -f "$MOODLE_DIR/html/config.php" ]; then
        print_status "Moodle installed successfully"
    else
        print_warning "Moodle installation may have had issues"
        print_warning "You can complete installation via web interface at: $MOODLE_URL"
    fi
else
    print_skipping "Moodle installation (already complete)"
fi

################################################################################
# PART 5: OAUTH MODULES
################################################################################

print_section "PART 5/8: OAuth Modules Installation"

print_step "Installing Simple OAuth module"
print_checking "Simple OAuth status"
if ! check_simple_oauth_installed || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Installing Simple OAuth"
    
    COMPOSER_FLAGS=""
    if [ "$USE_DEFAULTS" = true ]; then
        COMPOSER_FLAGS="--no-interaction"
    fi
    
    if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush pm:list --type=module 2>/dev/null | grep -q simple_oauth"; then
        if ! grep -q "drupal/simple_oauth" "$OPENSOCIAL_DIR/composer.json" 2>/dev/null; then
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer require 'drupal/simple_oauth:^6.0' --with-all-dependencies $COMPOSER_FLAGS"
        else
            su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev composer install $COMPOSER_FLAGS"
        fi
    fi
    
    print_doing "Enabling Simple OAuth module"
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush en simple_oauth -y"
    
    print_status "Simple OAuth installed and enabled"
else
    print_skipping "Simple OAuth installation (already installed)"
fi

print_step "Generating OAuth keys"
print_checking "OAuth key files"
if ! check_oauth_keys_exist || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Creating OAuth keys"
    
    OAUTH_KEYS_DIR="$OPENSOCIAL_DIR/keys"
    
    if [ ! -d "$OAUTH_KEYS_DIR" ] || [ "$FORCE_INSTALL" = true ]; then
        su - $ACTUAL_USER -c "mkdir -p '$OAUTH_KEYS_DIR'"
        su - $ACTUAL_USER -c "chmod 755 '$OAUTH_KEYS_DIR'"
    fi
    
    if [ ! -f "$OAUTH_KEYS_DIR/private.key" ] || [ "$FORCE_INSTALL" = true ]; then
        print_doing "Generating 2048-bit RSA private key"
        su - $ACTUAL_USER -c "openssl genrsa -out '$OAUTH_KEYS_DIR/private.key' 2048"
        su - $ACTUAL_USER -c "chmod 600 '$OAUTH_KEYS_DIR/private.key'"
    fi
    
    if [ ! -f "$OAUTH_KEYS_DIR/public.key" ] || [ "$FORCE_INSTALL" = true ]; then
        print_doing "Extracting public key"
        su - $ACTUAL_USER -c "openssl rsa -in '$OAUTH_KEYS_DIR/private.key' -pubout -out '$OAUTH_KEYS_DIR/public.key'"
        su - $ACTUAL_USER -c "chmod 644 '$OAUTH_KEYS_DIR/public.key'"
    fi
    
    print_status "OAuth keys generated successfully"
else
    print_skipping "OAuth key generation (already exist)"
fi

print_step "Configuring Simple OAuth"
print_checking "Simple OAuth configuration"
if ! check_oauth_configured || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Setting OAuth key paths"
    
    EXPECTED_PUBLIC="/var/www/keys/public.key"
    EXPECTED_PRIVATE="/var/www/keys/private.key"
    
    print_checking "Key accessibility from container"
    if ! su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev exec 'test -f $EXPECTED_PUBLIC' 2>/dev/null"; then
        print_warning "Using relative paths"
        EXPECTED_PUBLIC="../keys/public.key"
        EXPECTED_PRIVATE="../keys/private.key"
    fi
    
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush config:set simple_oauth.settings public_key '$EXPECTED_PUBLIC' -y 2>&1" || \
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush php-eval \"
\\\$config = \\Drupal::service('config.factory')->getEditable('simple_oauth.settings');
\\\$config->set('public_key', '$EXPECTED_PUBLIC');
\\\$config->set('private_key', '$EXPECTED_PRIVATE');
\\\$config->save();
\""
    
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush config:set simple_oauth.settings private_key '$EXPECTED_PRIVATE' -y 2>&1" || true
    
    print_doing "Clearing Drupal cache"
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush cr"
    
    print_status "Simple OAuth configured"
else
    print_skipping "Simple OAuth configuration (already configured)"
fi

################################################################################
# PART 6: OPENSOCIAL OAUTH PROVIDER MODULE
################################################################################

print_section "PART 6/8: OpenSocial OAuth Provider Module"

print_step "Installing OAuth Provider module"
print_checking "Module source files"

MODULE_SRC="$SCRIPT_DIR/opensocial_moodle_sso"
MODULE_DEST="$OPENSOCIAL_DIR/html/modules/custom/opensocial_oauth_provider"

if [ ! -d "$MODULE_SRC" ]; then
    print_error "Module source not found at: $MODULE_SRC"
    print_error "Please ensure opensocial_moodle_sso/ folder exists in script directory"
    exit 1
fi

if ! check_oauth_provider_module_exists || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Copying OAuth Provider module"
    
    su - $ACTUAL_USER -c "mkdir -p '$OPENSOCIAL_DIR/html/modules/custom'"
    [ -d "$MODULE_DEST" ] && rm -rf "$MODULE_DEST"
    su - $ACTUAL_USER -c "cp -r '$MODULE_SRC' '$MODULE_DEST'"
    chown -R $ACTUAL_USER:$ACTUAL_USER "$MODULE_DEST"
    
    print_status "OAuth Provider module installed"
else
    print_skipping "OAuth Provider installation (already installed)"
fi

print_step "Enabling OAuth Provider module"
print_checking "Module enabled status"
if ! check_oauth_provider_enabled || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Enabling module via Drush"
    
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush en opensocial_oauth_provider -y 2>&1" | grep -v "Deprecated" || true
    su - $ACTUAL_USER -c "cd '$OPENSOCIAL_DIR' && ddev drush cr 2>/dev/null"
    
    print_status "OAuth Provider module enabled"
    print_warning "PHP deprecation warnings from OpenSocial core are harmless"
else
    print_skipping "Module enable (already enabled)"
fi

print_step "Creating OAuth client for Moodle"
print_checking "OAuth client existence"
if ! check_oauth_client_exists || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Creating OAuth consumer"
    
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
echo 'OAuth client created';
\""
    
    print_status "OAuth client created successfully"
else
    print_skipping "OAuth client creation (already exists)"
fi

################################################################################
# PART 7: MOODLE OAUTH PLUGIN
################################################################################

print_section "PART 7/8: Moodle OAuth Authentication Plugin"

print_step "Installing Moodle OAuth plugin"
print_checking "Plugin source files"

PLUGIN_SRC="$SCRIPT_DIR/moodle_opensocial_auth"
PLUGIN_DEST="$MOODLE_DIR/html/auth/opensocial"

if [ ! -d "$PLUGIN_SRC" ]; then
    print_error "Plugin source not found at: $PLUGIN_SRC"
    print_error "Please ensure moodle_opensocial_auth/ folder exists in script directory"
    exit 1
fi

if ! check_moodle_oauth_plugin_exists || [ "$FORCE_INSTALL" = true ]; then
    print_doing "Copying Moodle OAuth plugin"
    
    [ -d "$PLUGIN_DEST" ] && rm -rf "$PLUGIN_DEST"
    su - $ACTUAL_USER -c "cp -r '$PLUGIN_SRC' '$PLUGIN_DEST'"
    chown -R $ACTUAL_USER:$ACTUAL_USER "$PLUGIN_DEST"
    
    print_status "Moodle OAuth plugin installed"
else
    print_skipping "Plugin installation (already installed)"
fi

################################################################################
# PART 8: SAVE CREDENTIALS AND COMPLETE
################################################################################

print_section "PART 8/8: Finalizing Installation"

print_step "Saving installation credentials"
print_doing "Creating credentials file"

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
   - Enable "OpenSocial OAuth2" authentication

5. Test SSO:
   - Log out of Moodle
   - Visit: $MOODLE_URL
   - Click "OpenSocial" login button
   - Authenticate with OpenSocial credentials

Credentials File: $CREDENTIALS_FILE
========================================
EOF

chmod 600 "$CREDENTIALS_FILE"
print_status "Credentials saved to: $CREDENTIALS_FILE"

################################################################################
# FINAL SUMMARY
################################################################################

print_section "✓ INSTALLATION COMPLETE!"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC} ${WHITE}Installation Summary${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}OpenSocial:${NC}"
echo "  URL: $OPENSOCIAL_URL"
echo "  Admin: $OPENSOCIAL_ADMIN_USER / $OPENSOCIAL_ADMIN_PASS"
echo "  Location: $OPENSOCIAL_DIR"
echo "  Quick start: cd $OPENSOCIAL_DIR && ddev launch"
echo ""

echo -e "${CYAN}Moodle:${NC}"
echo "  URL: $MOODLE_URL"
echo "  Admin: $MOODLE_ADMIN_USER / $MOODLE_ADMIN_PASS"
echo "  Location: $MOODLE_DIR"
echo "  Quick start: cd $MOODLE_DIR && ddev launch"
echo ""

echo -e "${CYAN}OAuth Integration:${NC}"
echo "  Client ID: $OAUTH_CLIENT_ID"
echo "  Configuration: See $CREDENTIALS_FILE"
echo ""

echo -e "${YELLOW}⚠ IMPORTANT: Next Steps${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Complete Moodle OAuth2 configuration via web interface"
echo "2. Open Moodle at: $MOODLE_URL"
echo "3. Follow instructions in: $CREDENTIALS_FILE"
echo ""

echo -e "${GREEN}✓ Both platforms are running in DDEV${NC}"
echo -e "${GREEN}✓ All files stored in: $SCRIPT_DIR${NC}"
echo -e "${GREEN}✓ Installation completed successfully!${NC}"
echo ""

exit 0