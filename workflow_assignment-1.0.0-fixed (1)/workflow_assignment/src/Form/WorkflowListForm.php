<?php

namespace Drupal\workflow_assignment\Form;

use Drupal\Core\Entity\EntityForm;
use Drupal\Core\Form\FormStateInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Config\ConfigFactoryInterface;

/**
 * Form handler for workflow list add and edit forms.
 */
class WorkflowListForm extends EntityForm {

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
   * Constructs a WorkflowListForm object.
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
  public function form(array $form, FormStateInterface $form_state) {
    $form = parent::form($form, $form_state);

    /** @var \Drupal\workflow_assignment\Entity\WorkflowListInterface $workflow_list */
    $workflow_list = $this->entity;

    $form['label'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Name'),
      '#maxlength' => 255,
      '#default_value' => $workflow_list->label(),
      '#description' => $this->t('Name of the workflow list.'),
      '#required' => TRUE,
    ];

    $form['id'] = [
      '#type' => 'machine_name',
      '#default_value' => $workflow_list->id(),
      '#machine_name' => [
        'exists' => '\Drupal\workflow_assignment\Entity\WorkflowList::load',
      ],
      '#disabled' => !$workflow_list->isNew(),
    ];

    $form['description'] = [
      '#type' => 'textarea',
      '#title' => $this->t('Description'),
      '#default_value' => $workflow_list->getDescription(),
      '#description' => $this->t('Optional description of the workflow list.'),
    ];

    // Assigned Users
    $form['assigned_users'] = [
      '#type' => 'entity_autocomplete',
      '#title' => $this->t('Assigned Users'),
      '#target_type' => 'user',
      '#tags' => TRUE,
      '#default_value' => $this->loadUsers($workflow_list->getAssignedUsers()),
      '#description' => $this->t('Select users to assign to this workflow.'),
    ];

    // Assigned Groups (if Group module is available)
    if ($this->moduleHandler()->moduleExists('group')) {
      $form['assigned_groups'] = [
        '#type' => 'entity_autocomplete',
        '#title' => $this->t('Assigned Groups'),
        '#target_type' => 'group',
        '#tags' => TRUE,
        '#default_value' => $this->loadGroups($workflow_list->getAssignedGroups()),
        '#description' => $this->t('Select groups to assign to this workflow.'),
      ];
    }

    // Resource Location Tags
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
      '#description' => $this->t('Tag this workflow with resource locations.'),
    ];

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function save(array $form, FormStateInterface $form_state) {
    /** @var \Drupal\workflow_assignment\Entity\WorkflowListInterface $workflow_list */
    $workflow_list = $this->entity;

    // Process assigned users
    $assigned_users = [];
    if ($users = $form_state->getValue('assigned_users')) {
      foreach ($users as $user) {
        $assigned_users[] = $user['target_id'];
      }
    }
    $workflow_list->setAssignedUsers($assigned_users);

    // Process assigned groups
    $assigned_groups = [];
    if ($groups = $form_state->getValue('assigned_groups')) {
      foreach ($groups as $group) {
        $assigned_groups[] = $group['target_id'];
      }
    }
    $workflow_list->setAssignedGroups($assigned_groups);

    // Process resource tags
    $resource_tags = [];
    if ($tags = $form_state->getValue('resource_tags')) {
      foreach ($tags as $tag) {
        $resource_tags[] = $tag['target_id'];
      }
    }
    $workflow_list->setResourceTags($resource_tags);

    $status = $workflow_list->save();

    if ($status === SAVED_NEW) {
      $this->messenger()->addStatus($this->t('Created the %label workflow list.', [
        '%label' => $workflow_list->label(),
      ]));
    }
    else {
      $this->messenger()->addStatus($this->t('Updated the %label workflow list.', [
        '%label' => $workflow_list->label(),
      ]));
    }

    $form_state->setRedirectUrl($workflow_list->toUrl('collection'));

    return $status;
  }

  /**
   * Load user entities from IDs.
   *
   * @param array $user_ids
   *   Array of user IDs.
   *
   * @return array
   *   Array of user entities.
   */
  protected function loadUsers(array $user_ids) {
    if (empty($user_ids)) {
      return [];
    }
    return $this->entityTypeManager->getStorage('user')->loadMultiple($user_ids);
  }

  /**
   * Load group entities from IDs.
   *
   * @param array $group_ids
   *   Array of group IDs.
   *
   * @return array
   *   Array of group entities.
   */
  protected function loadGroups(array $group_ids) {
    if (empty($group_ids) || !$this->moduleHandler()->moduleExists('group')) {
      return [];
    }
    return $this->entityTypeManager->getStorage('group')->loadMultiple($group_ids);
  }

  /**
   * Load term entities from IDs.
   *
   * @param array $term_ids
   *   Array of term IDs.
   *
   * @return array
   *   Array of term entities.
   */
  protected function loadTerms(array $term_ids) {
    if (empty($term_ids)) {
      return [];
    }
    return $this->entityTypeManager->getStorage('taxonomy_term')->loadMultiple($term_ids);
  }

}
