<?php

namespace Drupal\opensocial_oauth_provider\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Session\AccountProxyInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Drupal\user\Entity\User;

/**
 * Controller for OAuth2 user info endpoint.
 */
class UserInfoController extends ControllerBase {

  /**
   * The current user.
   *
   * @var \Drupal\Core\Session\AccountProxyInterface
   */
  protected $currentUser;

  /**
   * Constructs a UserInfoController object.
   *
   * @param \Drupal\Core\Session\AccountProxyInterface $current_user
   *   The current user.
   */
  public function __construct(AccountProxyInterface $current_user) {
    $this->currentUser = $current_user;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('current_user')
    );
  }

  /**
   * Returns user information for OAuth2.
   *
   * @param \Symfony\Component\HttpFoundation\Request $request
   *   The request object.
   *
   * @return \Symfony\Component\HttpFoundation\JsonResponse
   *   JSON response with user information.
   */
  public function userInfo(Request $request) {
    // Get the access token from the Authorization header.
    $auth_header = $request->headers->get('Authorization');
    
    if (!$auth_header || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
      return new JsonResponse(['error' => 'No access token provided'], 401);
    }

    $access_token = $matches[1];

    // Validate the token and get user information.
    $token_storage = \Drupal::service('entity_type.manager')->getStorage('oauth2_token');
    $tokens = $token_storage->loadByProperties(['value' => $access_token]);

    if (empty($tokens)) {
      return new JsonResponse(['error' => 'Invalid access token'], 401);
    }

    $token = reset($tokens);
    
    // Check if token is expired.
    if ($token->get('expire')->value < time()) {
      return new JsonResponse(['error' => 'Access token expired'], 401);
    }

    // Get user entity.
    $user_id = $token->get('auth_user_id')->target_id;
    $user = User::load($user_id);

    if (!$user) {
      return new JsonResponse(['error' => 'User not found'], 404);
    }

    // Build user info response.
    $user_info = [
      'sub' => (string) $user->id(),
      'name' => $user->getDisplayName(),
      'preferred_username' => $user->getAccountName(),
      'email' => $user->getEmail(),
      'email_verified' => TRUE,
      'given_name' => $user->get('field_profile_first_name')->value ?? '',
      'family_name' => $user->get('field_profile_last_name')->value ?? '',
    ];

    // Add profile picture if available.
    if ($user->hasField('user_picture') && !$user->get('user_picture')->isEmpty()) {
      $picture = $user->get('user_picture')->entity;
      if ($picture) {
        $user_info['picture'] = file_create_url($picture->getFileUri());
      }
    }

    return new JsonResponse($user_info);
  }

}
