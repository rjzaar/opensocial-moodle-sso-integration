# Module Folder Structure Changes

## Overview

This package has been modified so that modules are stored in separate folders rather than being created inline within the installation script.

## Module Locations

### OpenSocial OAuth Provider Module
**Location:** `opensocial_moodle_sso/`

This is a Drupal module that provides OAuth2 endpoints for Moodle authentication.

**Files:**
- `opensocial_oauth_provider.info.yml` - Module metadata
- `opensocial_oauth_provider.module` - Module hooks
- `opensocial_oauth_provider.routing.yml` - Route definitions
- `src/Controller/UserInfoController.php` - User info endpoint controller
- `src/Form/SettingsForm.php` - Admin configuration form

### Moodle Authentication Plugin
**Location:** `moodle_opensocial_auth/`

This is a Moodle authentication plugin that enables OAuth2 login via OpenSocial.

**Files:**
- `version.php` - Plugin version metadata
- `auth.php` - Authentication plugin class
- `settings.html` - Admin settings form
- `lang/en/auth_opensocial.php` - English language strings
- `db/upgrade.php` - Database upgrade script

## Installation Script Changes

The installation script (`opensocial_moodle_sso_complete_modified.sh`) has been modified in two key sections:

### PART 6: OpenSocial OAuth Provider Module

**OLD BEHAVIOR:** Created module files inline using bash heredocs

**NEW BEHAVIOR:** Copies module from `opensocial_moodle_sso/` folder

```bash
# Modified code in PART 6
MODULE_SRC="$SCRIPT_DIR/opensocial_moodle_sso"
MODULE_DEST="$OPENSOCIAL_DIR/html/modules/custom/opensocial_oauth_provider"

# Verify source module exists
if [ ! -d "$MODULE_SRC" ]; then
    print_error "Module source not found at: $MODULE_SRC"
    exit 1
fi

# Copy module
su - $ACTUAL_USER -c "cp -r '$MODULE_SRC' '$MODULE_DEST'"
```

### PART 7: Moodle OAuth Plugin

**OLD BEHAVIOR:** Created plugin files inline using bash heredocs

**NEW BEHAVIOR:** Copies plugin from `moodle_opensocial_auth/` folder

```bash
# Modified code in PART 7
PLUGIN_SRC="$SCRIPT_DIR/moodle_opensocial_auth"
PLUGIN_DEST="$MOODLE_DIR/html/auth/opensocial"

# Verify source plugin exists
if [ ! -d "$PLUGIN_SRC" ]; then
    print_error "Plugin source not found at: $PLUGIN_SRC"
    exit 1
fi

# Copy plugin
su - $ACTUAL_USER -c "cp -r '$PLUGIN_SRC' '$PLUGIN_DEST'"
```

## Benefits of This Approach

1. **Single Source of Truth** - Module code exists in one place only
2. **Easier Maintenance** - Update modules by editing PHP files directly
3. **Better Testing** - Can test modules independently of the script
4. **Version Control Friendly** - Proper file structure for git
5. **IDE Support** - Full syntax highlighting and code completion
6. **Cleaner Script** - Installation script is more readable

## Distribution

When distributing this package, include:
- `opensocial_moodle_sso_complete_modified.sh` - Installation script
- `opensocial_moodle_sso/` - OpenSocial OAuth Provider module
- `moodle_opensocial_auth/` - Moodle authentication plugin
- `config.yml` - Configuration file (optional)
- All documentation files

## Usage

Place all files in the same directory and run:

```bash
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults
```

The script will automatically detect and copy modules from the folders.
