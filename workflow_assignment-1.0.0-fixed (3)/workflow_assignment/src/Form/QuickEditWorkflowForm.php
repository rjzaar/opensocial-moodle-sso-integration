<?php

namespace Drupal\workflow_assignment\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\workflow_assignment\Entity\WorkflowList;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Config\ConfigFactoryInterface;

/**
 * Form handler for quick edit workflow form.
 */
class QuickEditWorkflowForm extends FormBase {

  /**
   * The entity type manager.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected $entityTypeManager;

  /**
   * The config factory.
   *
   * @var \Drupal\Core\Config\ConfigFactoryInterface
   */
  protected $configFactory;

  /**
   * Constructs a QuickEditWorkflowForm object.
   *
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   The entity type manager.
   * @param \Drupal\Core\Config\ConfigFactoryInterface $config_factory
   *   The config factory.
   */
  public function __construct(EntityTypeManagerInterface $entity_type_manager, ConfigFactoryInterface $config_factory) {
    $this->entityTypeManager = $entity_type_manager;
    $this->configFactory = $config_factory;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('entity_type.manager'),
      $container->get('config.factory')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'workflow_assignment_quick_edit_form';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state, WorkflowList $workflow_list = NULL) {
    if (!$workflow_list) {
      return $form;
    }

    $form_state->set('workflow_list', $workflow_list);

    $form['#title'] = $this->t('Quick Edit: @label', ['@label' => $workflow_list->label()]);

    // Assigned Users
    $form['assigned_users'] = [
      '#type' => 'entity_autocomplete',
      '#title' => $this->t('Assigned Users'),
      '#target_type' => 'user',
      '#tags' => TRUE,
      '#default_value' => $this->loadUsers($workflow_list->getAssignedUsers()),
    ];

    // Assigned Groups
    if ($this->moduleHandler()->moduleExists('group')) {
      $form['assigned_groups'] = [
        '#type' => 'entity_autocomplete',
        '#title' => $this->t('Assigned Groups'),
        '#target_type' => 'group',
        '#tags' => TRUE,
        '#default_value' => $this->loadGroups($workflow_list->getAssignedGroups()),
      ];
    }

    // Resource Tags
    $config = $this->configFactory->get('workflow_assignment.settings');
    $vocabulary = $config->get('resource_location_vocabulary') ?? 'resource_locations';

    $form['resource_tags'] = [
      '#type' => 'entity_autocomplete',
      '#title' => $this->t('Resource Location Tags'),
      '#target_type' => 'taxonomy_term',
      '#tags' => TRUE,
      '#selection_settings' => [
        'target_bundles' => [$vocabulary],
      ],
      '#default_value' => $this->loadTerms($workflow_list->getResourceTags()),
    ];

    $form['actions']['#type'] = 'actions';
    $form['actions']['submit'] = [
      '#type' => 'submit',
      '#value' => $this->t('Update Workflow'),
      '#button_type' => 'primary',
    ];

    $form['actions']['cancel'] = [
      '#type' => 'link',
      '#title' => $this->t('Cancel'),
      '#url' => $workflow_list->toUrl('collection'),
      '#attributes' => ['class' => ['button']],
    ];

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    /** @var \Drupal\workflow_assignment\Entity\WorkflowListInterface $workflow_list */
    $workflow_list = $form_state->get('workflow_list');

    // Update assigned users
    $assigned_users = [];
    if ($users = $form_state->getValue('assigned_users')) {
      foreach ($users as $user) {
        $assigned_users[] = $user['target_id'];
      }
    }
    $workflow_list->setAssignedUsers($assigned_users);

    // Update assigned groups
    $assigned_groups = [];
    if ($groups = $form_state->getValue('assigned_groups')) {
      foreach ($groups as $group) {
        $assigned_groups[] = $group['target_id'];
      }
    }
    $workflow_list->setAssignedGroups($assigned_groups);

    // Update resource tags
    $resource_tags = [];
    if ($tags = $form_state->getValue('resource_tags')) {
      foreach ($tags as $tag) {
        $resource_tags[] = $tag['target_id'];
      }
    }
    $workflow_list->setResourceTags($resource_tags);

    $workflow_list->save();

    $this->messenger()->addStatus($this->t('Workflow list %label has been updated.', [
      '%label' => $workflow_list->label(),
    ]));

    $form_state->setRedirectUrl($workflow_list->toUrl('collection'));
  }

  /**
   * Load user entities from IDs.
   */
  protected function loadUsers(array $user_ids) {
    if (empty($user_ids)) {
      return [];
    }
    return $this->entityTypeManager->getStorage('user')->loadMultiple($user_ids);
  }

  /**
   * Load group entities from IDs.
   */
  protected function loadGroups(array $group_ids) {
    if (empty($group_ids)) {
      return [];
    }
    return $this->entityTypeManager->getStorage('group')->loadMultiple($group_ids);
  }

  /**
   * Load term entities from IDs.
   */
  protected function loadTerms(array $term_ids) {
    if (empty($term_ids)) {
      return [];
    }
    return $this->entityTypeManager->getStorage('taxonomy_term')->loadMultiple($term_ids);
  }

}
