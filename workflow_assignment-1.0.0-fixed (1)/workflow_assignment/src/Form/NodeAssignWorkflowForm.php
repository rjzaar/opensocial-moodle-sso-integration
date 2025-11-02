<?php

namespace Drupal\workflow_assignment\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\node\NodeInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;

/**
 * Form for assigning workflow to content.
 */
class NodeAssignWorkflowForm extends FormBase {

  /**
   * The entity type manager.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected $entityTypeManager;

  /**
   * Constructs a NodeAssignWorkflowForm object.
   *
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   The entity type manager.
   */
  public function __construct(EntityTypeManagerInterface $entity_type_manager) {
    $this->entityTypeManager = $entity_type_manager;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('entity_type.manager')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'workflow_assignment_node_assign_form';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state, NodeInterface $node = NULL) {
    if (!$node) {
      return $form;
    }

    $form_state->set('node', $node);

    // Get current workflow assignment
    $current_workflow = NULL;
    if ($node->hasField('field_workflow_list') && !$node->get('field_workflow_list')->isEmpty()) {
      $current_workflow = $node->get('field_workflow_list')->target_id;
    }

    $form['workflow_list'] = [
      '#type' => 'select',
      '#title' => $this->t('Workflow List'),
      '#options' => $this->getWorkflowOptions(),
      '#default_value' => $current_workflow,
      '#empty_option' => $this->t('- None -'),
      '#description' => $this->t('Select a workflow list to assign to this content.'),
    ];

    $form['actions']['#type'] = 'actions';
    $form['actions']['submit'] = [
      '#type' => 'submit',
      '#value' => $this->t('Assign Workflow'),
      '#button_type' => 'primary',
    ];

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    /** @var \Drupal\node\NodeInterface $node */
    $node = $form_state->get('node');
    $workflow_id = $form_state->getValue('workflow_list');

    if ($node->hasField('field_workflow_list')) {
      $node->set('field_workflow_list', $workflow_id);
      $node->save();

      if ($workflow_id) {
        $this->messenger()->addStatus($this->t('Workflow has been assigned to this content.'));
      }
      else {
        $this->messenger()->addStatus($this->t('Workflow has been removed from this content.'));
      }
    }

    $form_state->setRedirectUrl($node->toUrl());
  }

  /**
   * Get workflow list options.
   *
   * @return array
   *   Array of workflow list options.
   */
  protected function getWorkflowOptions() {
    $options = [];
    $workflows = $this->entityTypeManager
      ->getStorage('workflow_list')
      ->loadMultiple();

    foreach ($workflows as $workflow) {
      $options[$workflow->id()] = $workflow->label();
    }

    return $options;
  }

}
