<?php

namespace Drupal\opensocial_oauth_provider\Form;

use Drupal\Core\Form\ConfigFormBase;
use Drupal\Core\Form\FormStateInterface;

/**
 * Configuration form for OpenSocial OAuth Provider.
 */
class SettingsForm extends ConfigFormBase {

  /**
   * {@inheritdoc}
   */
  protected function getEditableConfigNames() {
    return ['opensocial_oauth_provider.settings'];
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'opensocial_oauth_provider_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config('opensocial_oauth_provider.settings');

    $form['info'] = [
      '#type' => 'markup',
      '#markup' => $this->t('<p>This module extends Simple OAuth to provide OAuth2 authentication for Moodle.</p>
        <h3>Setup Instructions:</h3>
        <ol>
          <li>Generate OAuth2 keys using the Simple OAuth module settings</li>
          <li>Create an OAuth2 Client at /admin/config/people/simple_oauth</li>
          <li>Note the Client ID and Client Secret</li>
          <li>Configure Moodle with these OAuth2 credentials</li>
        </ol>
        <h3>OAuth2 Endpoints:</h3>
        <ul>
          <li><strong>Authorization URL:</strong> /oauth/authorize</li>
          <li><strong>Token URL:</strong> /oauth/token</li>
          <li><strong>User Info URL:</strong> /oauth/userinfo</li>
        </ul>'),
    ];

    $form['moodle_url'] = [
      '#type' => 'url',
      '#title' => $this->t('Moodle URL'),
      '#default_value' => $config->get('moodle_url'),
      '#description' => $this->t('The base URL of your Moodle installation.'),
    ];

    $form['enable_auto_provisioning'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Enable automatic user provisioning'),
      '#default_value' => $config->get('enable_auto_provisioning') ?? TRUE,
      '#description' => $this->t('Automatically create Moodle accounts for OpenSocial users on first login.'),
    ];

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    $this->config('opensocial_oauth_provider.settings')
      ->set('moodle_url', $form_state->getValue('moodle_url'))
      ->set('enable_auto_provisioning', $form_state->getValue('enable_auto_provisioning'))
      ->save();

    parent::submitForm($form, $form_state);
  }

}
