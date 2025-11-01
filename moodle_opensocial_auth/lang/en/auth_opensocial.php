<?php
/**
 * Strings for component 'auth_opensocial', language 'en'.
 *
 * @package    auth_opensocial
 * @copyright  2025
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

$string['pluginname'] = 'OpenSocial OAuth2';
$string['auth_opensocialdescription'] = 'Authenticate users via OpenSocial OAuth2 provider';

// Settings.
$string['opensocial_url'] = 'OpenSocial URL';
$string['opensocial_url_desc'] = 'The base URL of your OpenSocial (Drupal) installation (e.g., https://opensocial.example.com)';
$string['autoredirect'] = 'Auto-redirect to OpenSocial login';
$string['autoredirect_desc'] = 'Automatically redirect users to OpenSocial OAuth2 login page';
$string['issuerid'] = 'OAuth2 Issuer ID';
$string['issuerid_desc'] = 'The ID of the OAuth2 issuer configured in Site administration > Server > OAuth2 services';

// Instructions.
$string['setup_instructions'] = 'Setup Instructions';
$string['setup_step1'] = 'Step 1: Configure OAuth2 in OpenSocial';
$string['setup_step1_desc'] = 'Install and configure the Simple OAuth module in your OpenSocial installation. Create OAuth2 keys and an OAuth2 client.';
$string['setup_step2'] = 'Step 2: Create OAuth2 Issuer in Moodle';
$string['setup_step2_desc'] = 'Go to Site administration > Server > OAuth2 services and create a new custom OAuth2 service with the following endpoints:';
$string['setup_step3'] = 'Step 3: Configure Field Mappings';
$string['setup_step3_desc'] = 'Map the following OpenSocial user fields to Moodle fields: sub (User ID), email, username, firstname, lastname';
$string['setup_step4'] = 'Step 4: Enable Authentication';
$string['setup_step4_desc'] = 'Enable this authentication plugin and enter the OAuth2 Issuer ID from step 2.';

// Endpoints.
$string['authorization_endpoint'] = 'Authorization endpoint: {$a}/oauth/authorize';
$string['token_endpoint'] = 'Token endpoint: {$a}/oauth/token';
$string['userinfo_endpoint'] = 'User info endpoint: {$a}/oauth/userinfo';

// Errors.
$string['error_no_issuer'] = 'OAuth2 issuer not configured. Please configure an issuer in Site administration > Server > OAuth2 services';
$string['error_issuer_disabled'] = 'OAuth2 issuer is disabled';
$string['error_opensocial_url'] = 'OpenSocial URL is not configured';

// Privacy.
$string['privacy:metadata'] = 'The OpenSocial OAuth2 authentication plugin does not store any personal data.';
$string['privacy:metadata:auth_opensocial'] = 'OpenSocial OAuth2 authentication';
$string['privacy:metadata:auth_opensocial:userid'] = 'The user ID from OpenSocial';
