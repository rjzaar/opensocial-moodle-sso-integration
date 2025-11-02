# OpenSocial-Moodle SSO Integration

This package provides OAuth2-based single sign-on (SSO) integration between OpenSocial (Drupal) and Moodle, allowing users to automatically log into Moodle using their OpenSocial credentials.

## Package Contents

### 1. OpenSocial OAuth Provider Module (Drupal)
**Location:** `opensocial_moodle_sso/`

A Drupal module that extends the Simple OAuth module to provide OAuth2 authentication endpoints for Moodle.

### 2. Moodle Authentication Plugin
**Location:** `moodle_opensocial_auth/`

A Moodle authentication plugin that enables OAuth2 authentication with OpenSocial.

---

## Prerequisites

### OpenSocial (Drupal) Requirements:
- Drupal 9.x or 10.x
- OpenSocial distribution installed
- Simple OAuth module (simple_oauth)
- OpenSSL PHP extension

### Moodle Requirements:
- Moodle 4.0 or later
- OAuth2 authentication plugin enabled (included in Moodle core)

---

## Installation Guide

### Part 1: OpenSocial Configuration

#### Step 1: Install Required Drupal Modules

```bash
cd /path/to/opensocial
composer require drupal/simple_oauth
```

Enable the modules:
```bash
drush en simple_oauth -y
```

#### Step 2: Install the OpenSocial OAuth Provider Module

1. Copy the `opensocial_moodle_sso` directory to your Drupal modules directory:
   ```bash
   cp -r opensocial_moodle_sso /path/to/opensocial/modules/custom/
   ```

2. Enable the module:
   ```bash
   drush en opensocial_oauth_provider -y
   ```
   
   Or via the UI: Admin > Extend > Enable "OpenSocial OAuth Provider"

#### Step 3: Generate OAuth2 Keys

1. Create a directory for OAuth2 keys:
   ```bash
   mkdir -p /path/to/opensocial/keys
   chmod 700 /path/to/opensocial/keys
   ```

2. Generate the private key:
   ```bash
   openssl genrsa -out /path/to/opensocial/keys/private.key 2048
   ```

3. Generate the public key:
   ```bash
   openssl rsa -in /path/to/opensocial/keys/private.key -pubout -out /path/to/opensocial/keys/public.key
   ```

4. Set proper permissions:
   ```bash
   chmod 600 /path/to/opensocial/keys/private.key
   chmod 644 /path/to/opensocial/keys/public.key
   ```

#### Step 4: Configure Simple OAuth

1. Navigate to: **Configuration > People > Simple OAuth** (`/admin/config/people/simple_oauth`)

2. Enter the paths to your keys:
   - **Public Key:** `/path/to/opensocial/keys/public.key`
   - **Private Key:** `/path/to/opensocial/keys/private.key`

3. Save the configuration

#### Step 5: Create OAuth2 Client

1. Navigate to: **Configuration > People > Simple OAuth > OAuth2 Clients** (`/admin/config/people/simple_oauth/oauth2_client`)

2. Click **"Add OAuth2 Client"**

3. Fill in the details:
   - **Label:** Moodle
   - **New Secret:** Generate a strong secret (save this!)
   - **Is Confidential:** Yes (checked)
   - **Redirect URI:** `https://your-moodle-site.com/admin/oauth2callback.php`
   - **User ID:** Select an admin user or leave empty for public client

4. Click **Save**

5. **Important:** Note down the **Client ID** (UUID) and **Client Secret** - you'll need these for Moodle

#### Step 6: Configure OpenSocial OAuth Provider Settings

1. Navigate to: **Configuration > OpenSocial > OAuth Provider Settings** (`/admin/config/opensocial/oauth-provider`)

2. Enter your Moodle URL: `https://your-moodle-site.com`

3. Enable automatic user provisioning if desired

4. Save configuration

---

### Part 2: Moodle Configuration

#### Step 1: Install the Moodle Authentication Plugin

1. Copy the plugin to your Moodle auth directory:
   ```bash
   cp -r moodle_opensocial_auth /path/to/moodle/auth/opensocial
   ```

2. Log in to Moodle as an administrator

3. Navigate to **Site administration** - you should see a notification to upgrade the database

4. Click **Upgrade Moodle database now**

#### Step 2: Create OAuth2 Issuer in Moodle

1. Navigate to: **Site administration > Server > OAuth 2 services** (`/admin/tool/oauth2/issuers.php`)

2. Click **"Create new custom service"**

3. Fill in the service details:
   - **Name:** OpenSocial
   - **Client ID:** [Client ID from OpenSocial Step 5]
   - **Client secret:** [Client Secret from OpenSocial Step 5]
   - **Service base URL:** `https://your-opensocial-site.com`
   - **Enabled:** Yes (checked)
   - **Show on login page:** Yes (checked)

4. Configure the endpoints:
   - **Authorization endpoint:** `https://your-opensocial-site.com/oauth/authorize`
   - **Token endpoint:** `https://your-opensocial-site.com/oauth/token`
   - **User info endpoint:** `https://your-opensocial-site.com/oauth/userinfo`

5. Click **Save changes**

6. **Note the Issuer ID** (visible in the URL or the issuer list)

#### Step 3: Configure User Field Mappings

1. On the OAuth2 services page, click **"Configure user field mappings"** for your OpenSocial issuer

2. Map the following fields:

   | Internal field | External field name | Update on login |
   |---------------|---------------------|-----------------|
   | Email address | email               | Every login     |
   | First name    | given_name          | Every login     |
   | Last name     | family_name         | Every login     |
   | User picture  | picture             | Every login     |

3. Click **Save changes**

#### Step 4: Enable OAuth2 Authentication

1. Navigate to: **Site administration > Plugins > Authentication > Manage authentication** (`/admin/settings.php?section=manageauths`)

2. Enable **OAuth 2** authentication by clicking the eye icon

3. Move **OAuth 2** above **Email-based self-registration** in the priority list (optional but recommended)

#### Step 5: Configure the OpenSocial Authentication Plugin

1. Navigate to: **Site administration > Plugins > Authentication > OpenSocial OAuth2** (`/admin/auth_config.php?auth=opensocial`)

2. Enter the settings:
   - **OpenSocial URL:** `https://your-opensocial-site.com`
   - **OAuth2 Issuer ID:** [ID from Step 2]
   - **Auto-redirect to OpenSocial login:** Check this if you want automatic redirect

3. Click **Save changes**

4. Enable the authentication plugin:
   - Go to **Site administration > Plugins > Authentication > Manage authentication**
   - Enable **OpenSocial OAuth2** by clicking the eye icon

---

## Configuration Details

### OAuth2 Endpoints

The OpenSocial OAuth Provider module provides the following OAuth2 endpoints:

- **Authorization:** `/oauth/authorize`
- **Token:** `/oauth/token`  
- **User Info:** `/oauth/userinfo`
- **Introspection:** `/oauth/token/introspect` (optional)

### User Data Mapping

The following user data is transmitted from OpenSocial to Moodle:

| OpenSocial Field | Moodle Field | Description |
|-----------------|--------------|-------------|
| `sub` | User ID | Unique user identifier |
| `email` | Email | User email address |
| `preferred_username` | Username | Username |
| `given_name` | First name | User's first name |
| `family_name` | Last name | User's last name |
| `picture` | Profile picture | User profile image URL |

---

## Testing the Integration

### Test Login Flow

1. Log out of Moodle completely

2. Navigate to your Moodle login page

3. You should see an **"OpenSocial"** login button (if "Show on login page" is enabled)

4. Click the OpenSocial login button

5. You will be redirected to OpenSocial's authorization page

6. Log in with your OpenSocial credentials (if not already logged in)

7. Authorize Moodle to access your profile

8. You will be redirected back to Moodle and automatically logged in

### Troubleshooting

#### Users cannot log in

1. **Check OAuth2 issuer status:**
   - Go to Site administration > Server > OAuth 2 services
   - Ensure the issuer is enabled

2. **Verify endpoints:**
   - Test each endpoint URL in your browser
   - Authorization and token endpoints may require authentication

3. **Check logs:**
   - **Moodle:** Site administration > Reports > Logs
   - **Drupal:** Reports > Recent log messages

4. **Verify client credentials:**
   - Ensure Client ID and Client Secret match between OpenSocial and Moodle

#### Users are created but cannot log in

1. **Check authentication method:**
   - Go to Site administration > Users > Browse list of users
   - Find the user and verify Authentication method is "OAuth 2"

2. **Verify field mappings:**
   - Ensure all required fields are properly mapped

#### Redirect URI mismatch error

1. **Update the redirect URI in OpenSocial:**
   - Go to Configuration > People > Simple OAuth > OAuth2 Clients
   - Edit your Moodle client
   - Ensure Redirect URI is: `https://your-moodle-site.com/admin/oauth2callback.php`

---

## Security Considerations

### Key Management
- Store OAuth2 keys securely outside the web root
- Use proper file permissions (600 for private key, 644 for public key)
- Rotate keys periodically (recommended every 12 months)

### HTTPS Required
- **Both OpenSocial and Moodle MUST use HTTPS in production**
- OAuth2 will not work securely over HTTP

### Token Lifetime
- Access tokens expire after 300 seconds (5 minutes) by default
- Refresh tokens expire after 2 weeks by default
- These can be configured in Simple OAuth settings

### Client Secret
- Keep the Client Secret secure
- Never commit it to version control
- Rotate periodically if compromised

---

## Advanced Configuration

### Automatic Account Creation

By default, Moodle will automatically create accounts for OpenSocial users on first login. To disable this:

1. Go to: Site administration > Plugins > Authentication > OpenSocial OAuth2
2. Uncheck "Auto-redirect to OpenSocial login"

### Logout Synchronization

When enabled, logging out of Moodle will also log users out of OpenSocial:

1. This is configured in the OpenSocial OAuth2 plugin settings
2. The logout URL must be set to your OpenSocial logout page

### Role Mapping

To synchronize roles from OpenSocial to Moodle, you can extend the `sync_roles()` method in the `auth.php` file.

---

## Maintenance

### Updating the Modules

#### OpenSocial Module:
```bash
cd /path/to/opensocial
drush pm:update opensocial_oauth_provider -y
drush cr
```

#### Moodle Plugin:
1. Replace the plugin files
2. Visit Site administration to trigger database upgrade
3. Purge all caches

### Key Rotation

When rotating OAuth2 keys:

1. Generate new keys in OpenSocial
2. Update Simple OAuth configuration
3. No changes needed in Moodle (it will fetch the new public key automatically)

---

## Support and Development

### File Structure

**OpenSocial Module:**
```
opensocial_moodle_sso/
├── opensocial_oauth_provider.info.yml
├── opensocial_oauth_provider.module
├── opensocial_oauth_provider.routing.yml
└── src/
    ├── Controller/
    │   └── UserInfoController.php
    └── Form/
        └── SettingsForm.php
```

**Moodle Plugin:**
```
moodle_opensocial_auth/
├── version.php
├── auth.php
├── settings.html
├── lang/
│   └── en/
│       └── auth_opensocial.php
└── db/
    └── upgrade.php
```

### Extending the Integration

Both modules are designed to be extensible. Common customizations include:

- Adding custom user fields
- Implementing role synchronization
- Adding custom authentication hooks
- Extending user profile data

---

## License

These modules are released under the GNU General Public License v3.0 or later.

---

## Changelog

### Version 1.0.0 (2025-11-01)
- Initial release
- OAuth2 authentication support
- Automatic user provisioning
- User data synchronization
- Field mapping configuration

---

## Credits

Developed for OpenSocial and Moodle integration using:
- Drupal Simple OAuth module
- Moodle OAuth2 authentication framework
