<?php

namespace Drupal\workflow_assignment\Entity;

use Drupal\Core\Config\Entity\ConfigEntityInterface;

/**
 * Provides an interface for defining Workflow list entities.
 */
interface WorkflowListInterface extends ConfigEntityInterface {

  /**
   * Gets the workflow list description.
   *
   * @return string
   *   Description of the workflow list.
   */
  public function getDescription();

  /**
   * Sets the workflow list description.
   *
   * @param string $description
   *   The workflow list description.
   *
   * @return $this
   */
  public function setDescription($description);

  /**
   * Gets the assigned users.
   *
   * @return array
   *   Array of user IDs.
   */
  public function getAssignedUsers();

  /**
   * Sets the assigned users.
   *
   * @param array $users
   *   Array of user IDs.
   *
   * @return $this
   */
  public function setAssignedUsers(array $users);

  /**
   * Adds an assigned user.
   *
   * @param int $user_id
   *   The user ID to add.
   *
   * @return $this
   */
  public function addAssignedUser($user_id);

  /**
   * Removes an assigned user.
   *
   * @param int $user_id
   *   The user ID to remove.
   *
   * @return $this
   */
  public function removeAssignedUser($user_id);

  /**
   * Gets the assigned groups.
   *
   * @return array
   *   Array of group IDs.
   */
  public function getAssignedGroups();

  /**
   * Sets the assigned groups.
   *
   * @param array $groups
   *   Array of group IDs.
   *
   * @return $this
   */
  public function setAssignedGroups(array $groups);

  /**
   * Adds an assigned group.
   *
   * @param int $group_id
   *   The group ID to add.
   *
   * @return $this
   */
  public function addAssignedGroup($group_id);

  /**
   * Removes an assigned group.
   *
   * @param int $group_id
   *   The group ID to remove.
   *
   * @return $this
   */
  public function removeAssignedGroup($group_id);

  /**
   * Gets the resource location tags.
   *
   * @return array
   *   Array of taxonomy term IDs.
   */
  public function getResourceTags();

  /**
   * Sets the resource location tags.
   *
   * @param array $tags
   *   Array of taxonomy term IDs.
   *
   * @return $this
   */
  public function setResourceTags(array $tags);

  /**
   * Adds a resource location tag.
   *
   * @param int $tag_id
   *   The taxonomy term ID to add.
   *
   * @return $this
   */
  public function addResourceTag($tag_id);

  /**
   * Removes a resource location tag.
   *
   * @param int $tag_id
   *   The taxonomy term ID to remove.
   *
   * @return $this
   */
  public function removeResourceTag($tag_id);

  /**
   * Gets the workflow list creation timestamp.
   *
   * @return int
   *   Creation timestamp of the workflow list.
   */
  public function getCreatedTime();

  /**
   * Gets the workflow list changed timestamp.
   *
   * @return int
   *   Last changed timestamp of the workflow list.
   */
  public function getChangedTime();

}
