<?php
/**
 * Database upgrade script for auth_opensocial.
 *
 * @package    auth_opensocial
 * @copyright  2025
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

/**
 * Upgrade code for the OpenSocial OAuth2 authentication plugin.
 *
 * @param int $oldversion the version we are upgrading from
 * @return bool result
 */
function xmldb_auth_opensocial_upgrade($oldversion) {
    global $DB;

    $dbman = $DB->get_manager();

    // Automatically generated Moodle v4.0.0 release upgrade line.
    // Put any upgrade step following this.

    if ($oldversion < 2025110100) {
        // Initial installation, no upgrade needed.
        upgrade_plugin_savepoint(true, 2025110100, 'auth', 'opensocial');
    }

    return true;
}
