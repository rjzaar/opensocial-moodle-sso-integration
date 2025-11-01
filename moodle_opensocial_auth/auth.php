<?php
/**
 * OpenSocial OAuth2 authentication plugin.
 *
 * @package    auth_opensocial
 * @copyright  2025
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

require_once($CFG->libdir.'/authlib.php');

/**
 * OpenSocial OAuth2 authentication plugin.
 */
class auth_plugin_opensocial extends auth_plugin_base {

    /**
     * Constructor.
     */
    public function __construct() {
        $this->authtype = 'opensocial';
        $this->config = get_config('auth_opensocial');
    }

    /**
     * Returns true if the username and password work or don't exist and false
     * if they are set and don't work.
     *
     * @param string $username The username
     * @param string $password The password
     * @return bool Authentication success or failure.
     */
    public function user_login($username, $password) {
        global $CFG, $DB;
        
        // This plugin uses OAuth2, not username/password.
        return false;
    }

    /**
     * Returns true if this authentication plugin can change the user's password.
     *
     * @return bool
     */
    public function can_change_password() {
        return false;
    }

    /**
     * Returns the URL for changing the user's pw, or empty if the default can
     * be used.
     *
     * @return moodle_url
     */
    public function change_password_url() {
        return null;
    }

    /**
     * Returns true if this authentication plugin can edit the users' profile.
     *
     * @return bool
     */
    public function can_edit_profile() {
        return false;
    }

    /**
     * Hook for overriding behaviour of login page.
     * This method is called from login/index.php page for all enabled auth plugins.
     */
    public function loginpage_hook() {
        global $CFG, $SESSION;

        // Check if we should redirect to OpenSocial OAuth2 login.
        if (!empty($this->config->autoredirect)) {
            $issuer = \core\oauth2\api::get_issuer($this->config->issuerid);
            if ($issuer && $issuer->get('enabled')) {
                $url = new moodle_url('/auth/oauth2/login.php', [
                    'id' => $issuer->get('id'),
                    'wantsurl' => $SESSION->wantsurl ?? '',
                ]);
                redirect($url);
            }
        }
    }

    /**
     * Prints a form for configuring this authentication plugin.
     *
     * This function is called from admin/auth.php, and outputs a full page with
     * a form for configuring this plugin.
     *
     * @param array $config An object containing all the data for this page.
     * @param string $error
     * @param array $user_fields
     */
    public function config_form($config, $err, $user_fields) {
        include(__DIR__ . '/settings.html');
    }

    /**
     * Processes and stores configuration data for this authentication plugin.
     *
     * @param object $config Configuration object
     */
    public function process_config($config) {
        // Set defaults.
        if (!isset($config->opensocial_url)) {
            $config->opensocial_url = '';
        }
        if (!isset($config->autoredirect)) {
            $config->autoredirect = 0;
        }
        if (!isset($config->issuerid)) {
            $config->issuerid = 0;
        }

        // Save settings.
        set_config('opensocial_url', trim($config->opensocial_url), 'auth_opensocial');
        set_config('autoredirect', $config->autoredirect, 'auth_opensocial');
        set_config('issuerid', $config->issuerid, 'auth_opensocial');

        return true;
    }

    /**
     * Called when the user record is updated.
     *
     * @param mixed $olduser     Userobject before modifications
     * @param mixed $newuser     Userobject new modified userobject
     * @return boolean result
     */
    public function user_update($olduser, $newuser) {
        return true;
    }

    /**
     * Post logout hook.
     *
     * Note: this method is called from all auth plugins after user logout.
     */
    public function postlogout_hook($user) {
        global $CFG;
        
        // Redirect to OpenSocial logout if configured.
        if (!empty($this->config->opensocial_url)) {
            $logout_url = rtrim($this->config->opensocial_url, '/') . '/user/logout';
            redirect($logout_url);
        }
    }

    /**
     * Sync roles for user from OpenSocial.
     *
     * @param stdClass $user The user object
     */
    public function sync_roles($user) {
        // This can be extended to sync roles from OpenSocial.
        return true;
    }

}
