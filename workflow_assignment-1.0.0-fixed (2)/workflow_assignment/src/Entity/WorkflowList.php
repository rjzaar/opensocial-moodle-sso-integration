<?php

namespace Drupal\workflow_assignment\Entity;

use Drupal\Core\Config\Entity\ConfigEntityBase;
use Drupal\Core\Entity\EntityStorageInterface;

/**
 * Defines the Workflow list entity.
 *
 * @ConfigEntityType(
 *   id = "workflow_list",
 *   label = @Translation("Workflow list"),
 *   label_collection = @Translation("Workflow lists"),
 *   label_singular = @Translation("workflow list"),
 *   label_plural = @Translation("workflow lists"),
 *   label_count = @PluralTranslation(
 *     singular = "@count workflow list",
 *     plural = "@count workflow lists",
 *   ),
 *   handlers = {
 *     "view_builder" = "Drupal\Core\Entity\EntityViewBuilder",
 *     "list_builder" = "Drupal\workflow_assignment\WorkflowListListBuilder",
 *     "form" = {
 *       "add" = "Drupal\workflow_assignment\Form\WorkflowListForm",
 *       "edit" = "Drupal\workflow_assignment\Form\WorkflowListForm",
 *       "delete" = "Drupal\Core\Entity\EntityDeleteForm"
 *     },
 *     "route_provider" = {
 *       "html" = "Drupal\Core\Entity\Routing\AdminHtmlRouteProvider",
 *     },
 *   },
 *   config_prefix = "workflow_list",
 *   admin_permission = "administer workflow lists",
 *   links = {
 *     "canonical" = "/admin/structure/workflow-list/{workflow_list}",
 *     "add-form" = "/admin/structure/workflow-list/add",
 *     "edit-form" = "/admin/structure/workflow-list/{workflow_list}/edit",
 *     "delete-form" = "/admin/structure/workflow-list/{workflow_list}/delete",
 *     "collection" = "/admin/structure/workflow-list"
 *   },
 *   entity_keys = {
 *     "id" = "id",
 *     "label" = "label",
 *     "uuid" = "uuid"
 *   },
 *   config_export = {
 *     "id",
 *     "label",
 *     "description",
 *     "assigned_users",
 *     "assigned_groups",
 *     "resource_tags",
 *     "created",
 *     "changed",
 *   }
 * )
 */
class WorkflowList extends ConfigEntityBase implements WorkflowListInterface {

  /**
   * The Workflow list ID.
   *
   * @var string
   */
  protected $id;

  /**
   * The Workflow list label.
   *
   * @var string
   */
  protected $label;

  /**
   * The Workflow list description.
   *
   * @var string
   */
  protected $description;

  /**
   * The assigned users.
   *
   * @var array
   */
  protected $assigned_users = [];

  /**
   * The assigned groups.
   *
   * @var array
   */
  protected $assigned_groups = [];

  /**
   * The resource location tags.
   *
   * @var array
   */
  protected $resource_tags = [];

  /**
   * The creation timestamp.
   *
   * @var int
   */
  protected $created;

  /**
   * The last changed timestamp.
   *
   * @var int
   */
  protected $changed;

  /**
   * {@inheritdoc}
   */
  public function getDescription() {
    return $this->description;
  }

  /**
   * {@inheritdoc}
   */
  public function setDescription($description) {
    $this->description = $description;
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function getAssignedUsers() {
    return $this->assigned_users ?? [];
  }

  /**
   * {@inheritdoc}
   */
  public function setAssignedUsers(array $users) {
    $this->assigned_users = $users;
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function addAssignedUser($user_id) {
    if (!in_array($user_id, $this->assigned_users)) {
      $this->assigned_users[] = $user_id;
    }
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function removeAssignedUser($user_id) {
    $key = array_search($user_id, $this->assigned_users);
    if ($key !== FALSE) {
      unset($this->assigned_users[$key]);
      $this->assigned_users = array_values($this->assigned_users);
    }
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function getAssignedGroups() {
    return $this->assigned_groups ?? [];
  }

  /**
   * {@inheritdoc}
   */
  public function setAssignedGroups(array $groups) {
    $this->assigned_groups = $groups;
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function addAssignedGroup($group_id) {
    if (!in_array($group_id, $this->assigned_groups)) {
      $this->assigned_groups[] = $group_id;
    }
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function removeAssignedGroup($group_id) {
    $key = array_search($group_id, $this->assigned_groups);
    if ($key !== FALSE) {
      unset($this->assigned_groups[$key]);
      $this->assigned_groups = array_values($this->assigned_groups);
    }
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function getResourceTags() {
    return $this->resource_tags ?? [];
  }

  /**
   * {@inheritdoc}
   */
  public function setResourceTags(array $tags) {
    $this->resource_tags = $tags;
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function addResourceTag($tag_id) {
    if (!in_array($tag_id, $this->resource_tags)) {
      $this->resource_tags[] = $tag_id;
    }
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function removeResourceTag($tag_id) {
    $key = array_search($tag_id, $this->resource_tags);
    if ($key !== FALSE) {
      unset($this->resource_tags[$key]);
      $this->resource_tags = array_values($this->resource_tags);
    }
    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function getCreatedTime() {
    return $this->created;
  }

  /**
   * {@inheritdoc}
   */
  public function getChangedTime() {
    return $this->changed;
  }

  /**
   * {@inheritdoc}
   */
  public function preSave(EntityStorageInterface $storage) {
    parent::preSave($storage);
    
    if ($this->isNew()) {
      $this->created = \Drupal::time()->getRequestTime();
    }
    $this->changed = \Drupal::time()->getRequestTime();
  }

}
