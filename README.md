# OpenSocial + Moodle SSO Integration - Module Folder Version

This is a modified version of the OpenSocial-Moodle SSO installation package that uses module folders instead of inline file creation.

## What's Different?

Instead of creating module files inline within the installation script using bash heredocs, this version:
- Stores the OpenSocial OAuth Provider module in `opensocial_moodle_sso/` folder
- Stores the Moodle authentication plugin in `moodle_opensocial_auth/` folder
- Installation script copies from these folders instead of creating files

## Benefits

- ✅ Single source of truth for module code
- ✅ Full IDE support (syntax highlighting, code completion, debugging)
- ✅ Easier to maintain and update
- ✅ Modules can be tested independently
- ✅ Better version control with git
- ✅ Installation script is ~270 lines shorter

## Package Contents

```
opensocial-moodle-sso-package/
├── README.md                                    # This file
├── README_MODULES.md                            # Module structure documentation
├── CHANGES.md                                   # Detailed change log
├── SCRIPT_MODIFICATIONS.txt                     # Code snippet changes
├── config.yml                                   # Configuration file
├── .gitignore                                   # Git ignore rules
├── opensocial_moodle_sso/                       # OpenSocial OAuth Provider
│   ├── opensocial_oauth_provider.info.yml
│   ├── opensocial_oauth_provider.module
│   ├── opensocial_oauth_provider.routing.yml
│   └── src/
│       ├── Controller/UserInfoController.php
│       └── Form/SettingsForm.php
└── moodle_opensocial_auth/                      # Moodle Auth Plugin
    ├── version.php
    ├── auth.php
    ├── settings.html
    ├── lang/en/auth_opensocial.php
    └── db/upgrade.php
```

## Installation

**Note:** The full installation script is large (~1200 lines). To create it:

1. Start with `opensocial_moodle_sso_complete.sh` from the original package
2. Apply the modifications from `SCRIPT_MODIFICATIONS.txt`
3. Or use the provided script if included

Once you have the script:

```bash
# Extract package
tar -xzf opensocial-moodle-sso-modules.tar.gz
cd opensocial-moodle-sso-package/

# Run installation with defaults
sudo bash opensocial_moodle_sso_complete_modified.sh --defaults

# Or interactive mode
sudo bash opensocial_moodle_sso_complete_modified.sh
```

## Configuration

Edit `config.yml` to customize:
- Admin credentials
- Project names
- PHP/MySQL versions
- Site names

See CONFIG_GUIDE.md (if included) for full configuration options.

## Quick Start

1. Place all files in a directory
2. Ensure module folders are present:
   - `opensocial_moodle_sso/`
   - `moodle_opensocial_auth/`
3. Run: `sudo bash opensocial_moodle_sso_complete_modified.sh --defaults`
4. Follow post-installation OAuth configuration steps

## Requirements

- Ubuntu/Debian Linux
- Root/sudo access
- Internet connection
- 4GB+ RAM
- 10GB+ disk space

## Documentation

- `README_MODULES.md` - Module folder structure details
- `CHANGES.md` - Complete list of modifications
- `SCRIPT_MODIFICATIONS.txt` - Code-level changes
- `config.yml` - Configuration options

## Support

For issues or questions:
1. Check the credentials file after installation
2. Review logs: `ddev logs`
3. Verify module folders are complete
4. Ensure script and folders are in same directory

## License

GNU General Public License v3.0 or later (same as original)

## Credits

Modified from: https://github.com/rjzaar/opensocial-moodle-sso-integration
Changes: Module folder structure instead of inline creation
