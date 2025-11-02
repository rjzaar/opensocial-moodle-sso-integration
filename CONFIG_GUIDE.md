# Configuration File Guide

## Overview

The `config.yml` file allows you to customize all installation settings without modifying the script. This makes it easy to maintain different configurations for different environments.

## Location

The config file must be in the same directory as the installation script:
```
/path/to/script/
├── opensocial_moodle_sso_complete_modified.sh
└── config.yml  ← Configuration file
```

## Usage

### With Default Configuration
When using `--defaults`, the script automatically loads settings from `config.yml`:

```bash
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults
```

### Without Configuration File
If `config.yml` doesn't exist, the script uses hardcoded defaults:
- Admin email: admin@example.com
- Admin username: admin
- Admin password: admin
- OpenSocial project: opensocial
- Moodle project: moodle

### Interactive Mode
Interactive mode doesn't use `config.yml`. You'll be prompted for admin email, and other settings use hardcoded defaults.

## Configuration Options

### Admin Account Settings

```yaml
admin:
  email: "admin@example.com"     # Email for admin accounts
  username: "admin"               # Username for both platforms
  password: "admin"               # Password for both platforms
```

**Important:** Both OpenSocial and Moodle will use the same admin credentials.

### OpenSocial Configuration

```yaml
opensocial:
  project_name: "opensocial"      # DDEV project name
  site_name: "OpenSocial Community"  # Display name
  version: "dev-master"           # Version to install
  php_version: "8.2"              # PHP version
  mysql_version: "8.0"            # MySQL version
  nodejs_version: "18"            # Node.js version
```

**Available versions:**
- `dev-master` - Latest development version
- `12.4.2` - Specific stable release
- Check [OpenSocial releases](https://www.drupal.org/project/social) for available versions

**PHP version notes:**
- OpenSocial 12.x requires PHP 8.1 or 8.2
- Use `8.2` for best compatibility

### Moodle Configuration

```yaml
moodle:
  project_name: "moodle"          # DDEV project name
  fullname: "Moodle LMS"          # Full site name
  shortname: "Moodle"             # Short site name
  version: "MOODLE_404_STABLE"    # Git branch/tag
  php_version: "8.1"              # PHP version
  mysql_version: "8.0"            # MySQL version
```

**Available versions:**
- `MOODLE_404_STABLE` - Moodle 4.4 (Long Term Support)
- `MOODLE_405_STABLE` - Moodle 4.5 (latest stable)
- See [Moodle versions](https://docs.moodle.org/dev/Releases) for all options

**PHP version notes:**
- Moodle 4.4+ requires PHP 8.1 minimum
- Moodle 4.5+ supports PHP 8.3

### OAuth Configuration

```yaml
oauth:
  auto_generate: true             # Always true for security
```

OAuth Client ID and Secret are automatically generated for security and saved in `opensocial_moodle_ddev_credentials.txt`.

### Advanced Options

```yaml
advanced:
  skip_system_update: false       # Skip apt update/upgrade
  composer_timeout: 600           # Composer timeout (seconds)
  ddev_router_http_port: "80"     # HTTP port
  ddev_router_https_port: "443"   # HTTPS port
```

**Note:** Advanced options are currently defined but not fully implemented in the script.

## Example Configurations

### Production Configuration

```yaml
# config.yml - Production setup
admin:
  email: "admin@yourcompany.com"
  username: "admin"
  password: "SecureP@ssw0rd123!"

opensocial:
  project_name: "company-social"
  site_name: "Company Social Network"
  version: "12.4.2"
  php_version: "8.2"
  mysql_version: "8.0"
  nodejs_version: "18"

moodle:
  project_name: "company-lms"
  fullname: "Company Learning Management System"
  shortname: "CompanyLMS"
  version: "MOODLE_404_STABLE"
  php_version: "8.1"
  mysql_version: "8.0"
```

### Development Configuration

```yaml
# config.yml - Development setup
admin:
  email: "dev@localhost"
  username: "admin"
  password: "admin"

opensocial:
  project_name: "dev-social"
  site_name: "Dev Social Network"
  version: "dev-master"
  php_version: "8.2"
  mysql_version: "8.0"
  nodejs_version: "18"

moodle:
  project_name: "dev-moodle"
  fullname: "Dev Moodle"
  shortname: "DevMoodle"
  version: "MOODLE_405_STABLE"
  php_version: "8.1"
  mysql_version: "8.0"
```

### Testing Different Versions

```yaml
# config.yml - Testing older versions
admin:
  email: "test@example.com"
  username: "admin"
  password: "test123"

opensocial:
  project_name: "test-social-12-3"
  site_name: "Test Social"
  version: "12.3.0"
  php_version: "8.1"
  mysql_version: "8.0"
  nodejs_version: "16"

moodle:
  project_name: "test-moodle-43"
  fullname: "Test Moodle 4.3"
  shortname: "TestMoodle"
  version: "MOODLE_403_STABLE"
  php_version: "8.0"
  mysql_version: "8.0"
```

## Configuration Priority

When using `--defaults`:

1. **Config file exists**: Uses values from `config.yml`
2. **Config file missing**: Uses hardcoded defaults in script
3. **Environment variables**: Can still override (e.g., `OPENSOCIAL_PROJECT=custom`)

## Validation

The script will:
- ✅ Load `config.yml` if it exists
- ✅ Show a warning if file is missing (then use defaults)
- ✅ Display loaded configuration before proceeding
- ✅ Auto-increment project names if conflicts detected

## Multiple Environments

You can maintain multiple configuration files:

```bash
# Save different configs
cp config.yml config.prod.yml
cp config.yml config.dev.yml

# Use specific config
cp config.prod.yml config.yml
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults

# Or
cp config.dev.yml config.yml
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults
```

## Troubleshooting

### Config not loading
- Ensure `config.yml` is in the same directory as the script
- Check YAML syntax (use a YAML validator)
- Run with `--defaults` flag (config only loads in this mode)

### Invalid YAML syntax
Common issues:
```yaml
# ❌ Wrong - no quotes around password with special chars
password: p@ssw0rd!

# ✅ Correct - use quotes
password: "p@ssw0rd!"

# ❌ Wrong - inconsistent indentation
admin:
  email: "test@test.com"
    username: "admin"

# ✅ Correct - consistent 2-space indentation
admin:
  email: "test@test.com"
  username: "admin"
```

### Values not applying
- Check that you're using `--defaults` flag
- Verify config file is named exactly `config.yml`
- Check for typos in configuration keys
- Review script output for "Loading configuration" message

## Security Notes

- ⚠️ **Never commit config.yml with real passwords to version control**
- ⚠️ Use strong passwords for production environments
- ✅ OAuth credentials are always auto-generated (cannot be set in config)
- ✅ Config file should have restricted permissions: `chmod 600 config.yml`

## Schema Reference

Full configuration schema:

```yaml
admin:
  email: string
  username: string
  password: string

opensocial:
  project_name: string
  site_name: string
  version: string
  php_version: string ("8.1" | "8.2" | "8.3")
  mysql_version: string ("5.7" | "8.0")
  nodejs_version: string ("16" | "18" | "20")

moodle:
  project_name: string
  fullname: string
  shortname: string
  version: string (Git branch/tag)
  php_version: string ("8.0" | "8.1" | "8.2" | "8.3")
  mysql_version: string ("5.7" | "8.0")

oauth:
  auto_generate: boolean (always true)

advanced:
  skip_system_update: boolean
  composer_timeout: integer
  ddev_router_http_port: string
  ddev_router_https_port: string
```
