# OpenSocial-Moodle SSO Configuration Checklist

Use this checklist to ensure proper configuration of the OpenSocial-Moodle SSO integration.

## Pre-Installation Checklist

- [ ] OpenSocial (Drupal) is installed and accessible via HTTPS
- [ ] Moodle is installed and accessible via HTTPS
- [ ] You have administrator access to both systems
- [ ] Simple OAuth module is available for Drupal
- [ ] OpenSSL is installed on the server

---

## OpenSocial Configuration

### Module Installation
- [ ] Simple OAuth module installed via Composer
- [ ] Simple OAuth module enabled
- [ ] OpenSocial OAuth Provider module copied to `modules/custom/`
- [ ] OpenSocial OAuth Provider module enabled

### OAuth2 Keys
- [ ] Keys directory created with proper permissions (700)
- [ ] Private key generated (2048-bit RSA)
- [ ] Public key generated
- [ ] Private key permissions set to 600
- [ ] Public key permissions set to 644
- [ ] Keys owned by web server user

### Simple OAuth Configuration
- [ ] Public key path configured in Simple OAuth settings
- [ ] Private key path configured in Simple OAuth settings
- [ ] Configuration saved successfully

### OAuth2 Client Creation
- [ ] New OAuth2 client created
- [ ] Client labeled appropriately (e.g., "Moodle")
- [ ] Client secret generated and saved securely
- [ ] "Is Confidential" checked
- [ ] Redirect URI set to: `https://your-moodle-site.com/admin/oauth2callback.php`
- [ ] Client ID (UUID) noted for Moodle configuration
- [ ] Client Secret noted for Moodle configuration

### OpenSocial OAuth Provider Settings
- [ ] Moodle URL configured
- [ ] Automatic user provisioning enabled (if desired)
- [ ] Settings saved

---

## Moodle Configuration

### Plugin Installation
- [ ] Plugin files copied to `auth/opensocial/`
- [ ] Logged in as Moodle administrator
- [ ] Database upgrade completed
- [ ] No errors during installation

### OAuth2 Issuer Setup
- [ ] New custom OAuth2 service created
- [ ] Service name set (e.g., "OpenSocial")
- [ ] Client ID entered (from OpenSocial)
- [ ] Client secret entered (from OpenSocial)
- [ ] Service base URL set: `https://your-opensocial-site.com`
- [ ] "Enabled" checked
- [ ] "Show on login page" checked (if desired)
- [ ] Authorization endpoint: `https://your-opensocial-site.com/oauth/authorize`
- [ ] Token endpoint: `https://your-opensocial-site.com/oauth/token`
- [ ] User info endpoint: `https://your-opensocial-site.com/oauth/userinfo`
- [ ] Configuration saved
- [ ] Issuer ID noted for plugin configuration

### User Field Mappings
- [ ] Email address mapped to `email`
- [ ] First name mapped to `given_name`
- [ ] Last name mapped to `family_name`
- [ ] User picture mapped to `picture` (optional)
- [ ] All mappings set to update on every login
- [ ] Field mappings saved

### Authentication Configuration
- [ ] OAuth 2 authentication plugin enabled
- [ ] OpenSocial OAuth2 authentication plugin enabled
- [ ] OpenSocial URL entered in plugin settings
- [ ] OAuth2 Issuer ID entered in plugin settings
- [ ] Auto-redirect configured (if desired)
- [ ] Plugin settings saved

---

## Testing Checklist

### Pre-Test Verification
- [ ] Both sites accessible via HTTPS
- [ ] OAuth2 issuer shows as "Enabled" in Moodle
- [ ] No PHP errors in Moodle or Drupal logs
- [ ] Caches cleared in both systems

### Login Flow Test
- [ ] Logged out of both Moodle and OpenSocial completely
- [ ] Cleared browser cookies and cache
- [ ] Navigated to Moodle login page
- [ ] "OpenSocial" login button visible
- [ ] Clicked OpenSocial login button
- [ ] Redirected to OpenSocial authorization page
- [ ] Logged in with OpenSocial credentials
- [ ] Authorization prompt displayed (if first time)
- [ ] Approved authorization request
- [ ] Redirected back to Moodle
- [ ] Automatically logged into Moodle
- [ ] User profile data populated correctly

### User Data Verification
- [ ] Email address synced correctly
- [ ] First name synced correctly
- [ ] Last name synced correctly
- [ ] Profile picture synced correctly (if configured)
- [ ] User authentication method shows as "OAuth 2"

### Subsequent Login Test
- [ ] Logged out of Moodle (stay logged in to OpenSocial)
- [ ] Clicked OpenSocial login button in Moodle
- [ ] Automatically logged in without re-entering credentials
- [ ] User data still correct

---

## Troubleshooting Checklist

If login fails, verify:

### Moodle Issues
- [ ] OAuth2 service is enabled
- [ ] Client ID and secret are correct
- [ ] All endpoint URLs are correct and accessible
- [ ] Field mappings are configured
- [ ] Authentication plugin is enabled
- [ ] Moodle logs checked for errors

### OpenSocial Issues
- [ ] Simple OAuth module is enabled
- [ ] OAuth2 keys are valid and accessible
- [ ] Keys have correct permissions
- [ ] OAuth2 client exists and is active
- [ ] Redirect URI matches Moodle's callback URL
- [ ] Drupal logs checked for errors

### Network Issues
- [ ] Both sites use HTTPS (required for OAuth2)
- [ ] Firewalls allow communication between servers
- [ ] SSL certificates are valid
- [ ] No proxy or CDN interfering with OAuth flow

### Common Error Resolution
- [ ] "Invalid client" → Verify Client ID and Secret
- [ ] "Redirect URI mismatch" → Check redirect URI in OAuth2 client
- [ ] "Invalid scope" → Verify scopes in OAuth2 configuration
- [ ] "Token expired" → Check server time synchronization
- [ ] "User not found" → Verify user field mappings

---

## Security Verification

- [ ] Both sites accessible only via HTTPS in production
- [ ] OAuth2 keys stored outside web root
- [ ] Private key has restricted permissions (600)
- [ ] Client secret not committed to version control
- [ ] Token lifetimes configured appropriately
- [ ] User data transmission encrypted
- [ ] Audit logging enabled in both systems

---

## Post-Deployment

### Documentation
- [ ] Client ID and secret documented securely
- [ ] Key locations documented
- [ ] Configuration settings documented
- [ ] Troubleshooting procedures documented

### Monitoring
- [ ] Login success/failure monitoring configured
- [ ] Error logging enabled
- [ ] Regular log review scheduled
- [ ] Key rotation schedule established

### User Communication
- [ ] Users informed about SSO availability
- [ ] Login instructions provided
- [ ] Support contact information shared
- [ ] FAQ or help documentation created

---

## Maintenance Schedule

### Monthly
- [ ] Review authentication logs
- [ ] Check for failed login attempts
- [ ] Verify OAuth2 issuer status

### Quarterly
- [ ] Test login flow end-to-end
- [ ] Review user data synchronization
- [ ] Update documentation if needed

### Annually
- [ ] Rotate OAuth2 keys
- [ ] Review and update security settings
- [ ] Audit user access and permissions
- [ ] Update modules/plugins to latest versions

---

## Sign-Off

Configuration completed by: _________________ Date: _________

Tested by: _________________ Date: _________

Approved by: _________________ Date: _________

---

## Notes

Use this section to document any custom configurations or issues encountered:

_______________________________________________________________

_______________________________________________________________

_______________________________________________________________

_______________________________________________________________
