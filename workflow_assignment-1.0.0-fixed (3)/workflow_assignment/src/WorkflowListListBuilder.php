<?php

namespace Drupal\workflow_assignment;

use Drupal\Core\Config\Entity\ConfigEntityListBuilder;
use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Url;

/**
 * Provides a listing of Workflow list entities.
 */
class WorkflowListListBuilder extends ConfigEntityListBuilder {

  /**
   * {@inheritdoc}
   */
  public function buildHeader() {
    $header['label'] = $this->t('Workflow List');
    $header['id'] = $this->t('Machine name');
    $header['description'] = $this->t('Description');
    $header['users'] = $this->t('Assigned Users');
    $header['groups'] = $this->t('Assigned Groups');
    $header['resources'] = $this->t('Resource Locations');
    return $header + parent::buildHeader();
  }

  /**
   * {@inheritdoc}
   */
  public function buildRow(EntityInterface $entity) {
    /** @var \Drupal\workflow_assignment\Entity\WorkflowListInterface $entity */
    $row['label'] = $entity->label();
    $row['id'] = $entity->id();
    $row['description'] = $entity->getDescription();
    
    // Display user count
    $users = $entity->getAssignedUsers();
    $row['users'] = !empty($users) ? count($users) : $this->t('None');
    
    // Display group count
    $groups = $entity->getAssignedGroups();
    $row['groups'] = !empty($groups) ? count($groups) : $this->t('None');
    
    // Display resource tag count
    $tags = $entity->getResourceTags();
    $row['resources'] = !empty($tags) ? count($tags) : $this->t('None');
    
    return $row + parent::buildRow($entity);
  }

  /**
   * {@inheritdoc}
   */
  public function render() {
    $build = parent::render();
    
    // Add helpful empty message with link
    $build['table']['#empty'] = $this->t('No workflow lists available. <a href="@link">Add a workflow list</a>.', [
      '@link' => Url::fromRoute('entity.workflow_list.add_form')->toString(),
    ]);
    
    return $build;
  }

  /**
   * {@inheritdoc}
   */
  protected function getDefaultOperations(EntityInterface $entity) {
    $operations = parent::getDefaultOperations($entity);
    
    // Add quick edit operation
    $operations['quick_edit'] = [
      'title' => $this->t('Quick Edit'),
      'weight' => 15,
      'url' => Url::fromRoute('entity.workflow_list.quick_edit_form', [
        'workflow_list' => $entity->id(),
      ]),
    ];
    
    return $operations;
  }

}
