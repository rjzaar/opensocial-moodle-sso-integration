<?php
/**
 * Version information for OpenSocial OAuth2 authentication plugin.
 *
 * @package    auth_opensocial
 * @copyright  2025
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

$plugin->version   = 2025110100;        // The current plugin version (Date: YYYYMMDDXX).
$plugin->requires  = 2022041900;        // Requires Moodle 4.0 or later.
$plugin->component = 'auth_opensocial'; // Full name of the plugin (used for diagnostics).
$plugin->maturity  = MATURITY_STABLE;
$plugin->release   = '1.0.0';

$plugin->dependencies = [
    'auth_oauth2' => ANY_VERSION,
];
