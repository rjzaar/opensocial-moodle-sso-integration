# OpenSocial + Moodle SSO Integration Script

Complete automated installation script for OpenSocial (Drupal) and Moodle LMS with Single Sign-On (SSO) integration.

## Quick Start

### Option 1: Interactive Mode
Prompts for admin email, allows Composer to show decision prompts:
```bash
sudo bash opensocial_moodle_sso_complete_modified.sh
```

### Option 2: Non-Interactive Mode (Recommended for Automation)
Uses all defaults from config.yml or hardcoded values:
```bash
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults
```

### Option 3: View Help
```bash
bash opensocial_moodle_sso_complete_modified.sh --help
```

## Features

✅ **YAML Configuration** - Customize via config.yml file  
✅ **No Checkpoint Files** - Checks actual system state  
✅ **URL Conflict Detection** - Auto-increments project names  
✅ **Idempotent** - Safe to run multiple times  
✅ **Files in Script Directory** - All files stored together  
✅ **Two Modes** - Interactive or fully automated  
✅ **Simple OAuth 6.x** - Compatible with OpenSocial 12.4.2  

## What Gets Installed

1. **System Prerequisites** - Required packages
2. **Docker & DDEV** - Container environment
3. **OpenSocial** - Drupal-based social platform
4. **Moodle** - Learning Management System
5. **OAuth Integration** - SSO between platforms

## File Structure

```
/path/to/script/
├── opensocial_moodle_sso_complete_modified.sh  # Installation script
├── config.yml                                   # Configuration (optional)
├── opensocial_moodle_ddev_credentials.txt      # Generated credentials
├── opensocial/                                  # OpenSocial installation
│   ├── .ddev/                                  # DDEV config
│   ├── html/                                   # Web files
│   └── keys/                                   # OAuth keys
├── moodle/                                     # Moodle installation
│   ├── .ddev/                                  # DDEV config
│   ├── html/                                   # Web files
│   └── moodledata/                             # Moodle data
└── private/                                    # Private files
```

## Configuration

### Using config.yml (Recommended)

Create a `config.yml` file in the script directory:

```yaml
admin:
  email: "admin@example.com"
  username: "admin"
  password: "admin"

opensocial:
  project_name: "opensocial"
  site_name: "OpenSocial Community"
  version: "dev-master"
  php_version: "8.2"

moodle:
  project_name: "moodle"
  fullname: "Moodle LMS"
  shortname: "Moodle"
  version: "MOODLE_404_STABLE"
  php_version: "8.1"
```

Then run:
```bash
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults
```

See **CONFIG_GUIDE.md** for complete configuration options.

### Default Values (Without config.yml)

- Admin Email: admin@example.com
- Admin Username: admin
- Admin Password: admin
- OpenSocial: https://opensocial.ddev.site
- Moodle: https://moodle.ddev.site

## After Installation

### 1. View Credentials
```bash
cat opensocial_moodle_ddev_credentials.txt
```

### 2. Access Sites

**OpenSocial:**
- URL: https://opensocial.ddev.site (or as shown in credentials)
- Login: admin / admin (or your config values)

**Moodle:**
- URL: https://moodle.ddev.site (or as shown in credentials)
- Login: admin / admin (or your config values)

### 3. Complete OAuth Configuration

Follow the instructions in the credentials file to configure OAuth2 in Moodle's web interface.

## Managing Projects

### Start/Stop Projects
```bash
cd opensocial && ddev start
cd moodle && ddev start

cd opensocial && ddev stop
cd moodle && ddev stop
```

### View Status
```bash
cd opensocial && ddev describe
cd moodle && ddev describe
```

### Open in Browser
```bash
cd opensocial && ddev launch
cd moodle && ddev launch
```

### Get Admin Login Link (OpenSocial)
```bash
cd opensocial && ddev drush uli
```

## Documentation Files

- **README.md** (this file) - Quick start guide
- **USAGE.md** - Detailed usage instructions
- **CONFIG_GUIDE.md** - Complete configuration reference
- **CHANGES.md** - Changelog and modifications
- **YAML_CONFIG_SUMMARY.md** - Configuration feature details
- **SIMPLE_OAUTH_FIX.md** - Simple OAuth compatibility notes
- **NON_INTERACTIVE_FIX.md** - Interactive vs non-interactive modes

## Requirements

- Ubuntu/Debian Linux
- Root/sudo access
- Internet connection
- 4GB+ RAM recommended
- 10GB+ disk space

## Troubleshooting

### View Logs
```bash
cd opensocial && ddev logs
cd moodle && ddev logs
```

### Restart Projects
```bash
cd opensocial && ddev restart
cd moodle && ddev restart
```

### Re-run Script
The script is idempotent - you can safely run it again:
```bash
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults
```

It will:
- Skip completed steps
- Only install/configure what's missing
- Check actual system state

### Reset Everything
```bash
# Stop and remove DDEV projects
cd opensocial && ddev delete -y
cd moodle && ddev delete -y

# Remove directories
rm -rf opensocial moodle private

# Run script again
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults
```

## Environment Variables

Override any setting:
```bash
OPENSOCIAL_PROJECT=mysite sudo bash script.sh --defaults
MOODLE_VERSION=MOODLE_405_STABLE sudo bash script.sh --defaults
```

## Support

For issues or questions:
1. Check the credentials file for OAuth configuration steps
2. Review logs: `ddev logs`
3. Check DDEV status: `ddev describe`
4. Verify configuration: Review config.yml
5. Re-run script (it's safe): `sudo bash script.sh --defaults`

## License

Based on: https://github.com/rjzaar/opensocial-moodle-sso-integration

Modified to include:
- YAML configuration support
- Real state checking (no checkpoint files)
- Files stored in script directory
- URL conflict detection
- Conditional composer interaction
- Simple OAuth 6.x compatibility
