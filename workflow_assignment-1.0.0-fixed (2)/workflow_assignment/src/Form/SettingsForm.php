<?php

namespace Drupal\workflow_assignment\Form;

use Drupal\Core\Form\ConfigFormBase;
use Drupal\Core\Form\FormStateInterface;

/**
 * Configure workflow assignment settings.
 */
class SettingsForm extends ConfigFormBase {

  /**
   * {@inheritdoc}
   */
  protected function getEditableConfigNames() {
    return ['workflow_assignment.settings'];
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'workflow_assignment_settings_form';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config('workflow_assignment.settings');

    $form['enabled_content_types'] = [
      '#type' => 'checkboxes',
      '#title' => $this->t('Enabled Content Types'),
      '#description' => $this->t('Select which content types can have workflow lists assigned.'),
      '#options' => $this->getContentTypeOptions(),
      '#default_value' => $config->get('enabled_content_types') ?? [],
    ];

    $form['resource_location_vocabulary'] = [
      '#type' => 'select',
      '#title' => $this->t('Resource Location Vocabulary'),
      '#description' => $this->t('Select the taxonomy vocabulary to use for resource locations.'),
      '#options' => $this->getVocabularyOptions(),
      '#default_value' => $config->get('resource_location_vocabulary') ?? 'resource_locations',
      '#required' => TRUE,
    ];

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    $this->config('workflow_assignment.settings')
      ->set('enabled_content_types', array_filter($form_state->getValue('enabled_content_types')))
      ->set('resource_location_vocabulary', $form_state->getValue('resource_location_vocabulary'))
      ->save();

    parent::submitForm($form, $form_state);
  }

  /**
   * Get content type options.
   *
   * @return array
   *   Array of content type options.
   */
  protected function getContentTypeOptions() {
    $options = [];
    $content_types = \Drupal::entityTypeManager()
      ->getStorage('node_type')
      ->loadMultiple();

    foreach ($content_types as $type) {
      $options[$type->id()] = $type->label();
    }

    return $options;
  }

  /**
   * Get vocabulary options.
   *
   * @return array
   *   Array of vocabulary options.
   */
  protected function getVocabularyOptions() {
    $options = [];
    $vocabularies = \Drupal::entityTypeManager()
      ->getStorage('taxonomy_vocabulary')
      ->loadMultiple();

    foreach ($vocabularies as $vocabulary) {
      $options[$vocabulary->id()] = $vocabulary->label();
    }

    return $options;
  }

}
