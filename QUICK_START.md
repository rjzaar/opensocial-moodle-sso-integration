# Quick Start Guide: OpenSocial-Moodle SSO

This guide provides the fastest path to getting OpenSocial-Moodle SSO working.

## Prerequisites

- OpenSocial and Moodle both running on HTTPS
- Administrator access to both systems
- Command-line access to OpenSocial server

---

## 5-Minute Setup

### Step 1: OpenSocial Setup (2 minutes)

```bash
# Install Simple OAuth
cd /path/to/opensocial
composer require drupal/simple_oauth
drush en simple_oauth -y

# Copy and enable the OAuth Provider module
cp -r /path/to/opensocial_moodle_sso modules/custom/
drush en opensocial_oauth_provider -y

# Generate OAuth2 keys
./opensocial_setup_keys.sh
# When prompted, enter your OpenSocial path and web server user

# Clear cache
drush cr
```

### Step 2: Configure Simple OAuth (1 minute)

1. Go to: `Configuration > People > Simple OAuth`
2. Enter key paths (provided by the setup script)
3. Save

### Step 3: Create OAuth2 Client (1 minute)

1. Go to: `Configuration > People > Simple OAuth > OAuth2 Clients`
2. Click **Add OAuth2 Client**
3. Fill in:
   - **Label:** Moodle
   - **New Secret:** (generate a strong password)
   - **Is Confidential:** ✓
   - **Redirect URI:** `https://YOUR-MOODLE-SITE/admin/oauth2callback.php`
4. **Save and note the Client ID and Secret!**

### Step 4: Moodle Setup (1 minute)

```bash
# Install the auth plugin
cp -r /path/to/moodle_opensocial_auth /path/to/moodle/auth/opensocial

# In Moodle web UI:
# 1. Go to Site Administration (will prompt for DB upgrade)
# 2. Click "Upgrade Moodle database now"
```

### Step 5: Configure Moodle OAuth2 (2 minutes)

1. Go to: `Site administration > Server > OAuth 2 services`
2. Click **Create new custom service**
3. Fill in:
   - **Name:** OpenSocial
   - **Client ID:** [from Step 3]
   - **Client secret:** [from Step 3]
   - **Service base URL:** `https://YOUR-OPENSOCIAL-SITE`
   - **Enabled:** ✓
   - **Show on login page:** ✓
   
4. Add endpoints:
   - **Authorization:** `https://YOUR-OPENSOCIAL-SITE/oauth/authorize`
   - **Token:** `https://YOUR-OPENSOCIAL-SITE/oauth/token`
   - **User info:** `https://YOUR-OPENSOCIAL-SITE/oauth/userinfo`

5. Save and **note the Issuer ID**

### Step 6: Configure Field Mappings (30 seconds)

1. Click **Configure user field mappings**
2. Add mappings:
   - Email → `email` (Every login)
   - First name → `given_name` (Every login)
   - Last name → `family_name` (Every login)
3. Save

### Step 7: Enable Authentication (30 seconds)

1. Go to: `Plugins > Authentication > Manage authentication`
2. Enable **OAuth 2** (click eye icon)
3. Enable **OpenSocial OAuth2** (click eye icon)
4. Click **Settings** for OpenSocial OAuth2
5. Enter:
   - **OpenSocial URL:** `https://YOUR-OPENSOCIAL-SITE`
   - **OAuth2 Issuer ID:** [from Step 5]
6. Save

---

## Test It! (1 minute)

1. Open Moodle in an incognito/private window
2. Click the **OpenSocial** button
3. Log in with your OpenSocial credentials
4. ✓ You should be automatically logged into Moodle!

---

## Troubleshooting Quick Fixes

### Can't see OpenSocial button?
- Check "Show on login page" is enabled in OAuth2 service
- Verify OAuth2 service is enabled
- Purge all caches

### "Invalid client" error?
- Double-check Client ID and Secret match exactly
- Ensure Client ID is the full UUID, not the label

### "Redirect URI mismatch"?
- Verify redirect URI in OpenSocial client settings
- Must be: `https://YOUR-MOODLE-SITE/admin/oauth2callback.php`
- Check for typos and trailing slashes

### Still not working?
- Check both sites are using HTTPS
- Review logs in both systems
- Verify all endpoint URLs are accessible
- Refer to the full README.md for detailed troubleshooting

---

## What's Next?

### Optional Configurations

**Auto-redirect to OpenSocial:**
- In Moodle: OpenSocial OAuth2 settings
- Enable "Auto-redirect to OpenSocial login"
- Users bypass Moodle login page entirely

**Profile Pictures:**
- Already configured if you followed field mappings
- Syncs automatically from OpenSocial

**Role Mapping:**
- Requires custom development
- See README.md for extension guide

---

## Security Reminders

⚠️ **Before going to production:**

- [ ] Both sites MUST use HTTPS
- [ ] Store Client Secret securely
- [ ] Don't commit secrets to version control
- [ ] Set proper key file permissions (600 for private, 644 for public)
- [ ] Review security settings in both systems

---

## Support

For detailed documentation, see:
- **README.md** - Full installation and configuration guide
- **CONFIGURATION_CHECKLIST.md** - Step-by-step verification checklist

Need help? Common issues are covered in the Troubleshooting section of README.md.

---

## Summary

You now have:
- ✓ OpenSocial as an OAuth2 provider
- ✓ Moodle configured to authenticate via OpenSocial
- ✓ Automatic user provisioning
- ✓ Profile data synchronization

Users can now log into Moodle using their OpenSocial credentials with a single click!
