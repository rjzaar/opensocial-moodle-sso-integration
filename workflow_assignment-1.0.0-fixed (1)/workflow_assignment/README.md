# Workflow Assignment Module

A custom Drupal 10/11 module that provides a flexible workflow system where you can create workflow lists containing assigned users and/or groups, with resource locations designated by taxonomy tags.

## FIXES INCLUDED IN THIS VERSION

This version includes critical fixes for the missing "Add Workflow List" button issue:

1. **Fixed Entity Annotation**: Added proper `add-form` link in the WorkflowList entity
2. **Fixed Route Provider**: Using `AdminHtmlRouteProvider` for automatic route generation
3. **Added Local Action**: Created `workflow_assignment.links.action.yml` for the Add button
4. **Fixed List Builder**: Updated `WorkflowListListBuilder` with proper render method
5. **Complete Routing**: All routes properly defined in `workflow_assignment.routing.yml`

## Features

- **Create Custom Workflow Lists** - Define named workflows with descriptions
- **Assign Users** - Add/remove users to workflows dynamically
- **Assign Groups** - Add/remove Open Social or Group module groups to workflows
- **Resource Location Tagging** - Tag workflows with resource locations using taxonomy
- **On-the-Fly Changes** - Modify all assignments at any time without restrictions
- **Content Assignment** - Assign workflow lists to any content type
- **Quick Edit Interface** - Rapid workflow modification without full edit form
- **Visual Workflow Info** - Display workflow assignments on content pages

## Requirements

- Drupal 10.x or 11.x
- Node module (core)
- Taxonomy module (core)
- User module (core)
- Optional: Group module (for group assignments in Open Social)

## Installation

1. Copy the `workflow_assignment` folder to your Drupal installation's `modules/custom` directory

2. Enable the module:
   ```bash
   drush en workflow_assignment -y
   ```

3. Clear caches:
   ```bash
   drush cr
   ```

4. The module will automatically create:
   - A "Resource Locations" taxonomy vocabulary
   - Field storage for workflow assignments

## Configuration

### Step 1: Configure Settings

Navigate to **Configuration > Workflow > Workflow Assignment** (`/admin/config/workflow/workflow-assignment`)

Configure:
- **Enabled Content Types** - Select which content types can have workflow lists assigned
- **Resource Location Vocabulary** - Choose the taxonomy vocabulary for resource locations (default: "resource_locations")

### Step 2: Create Resource Locations

Navigate to **Structure > Taxonomy > Resource Locations** (`/admin/structure/taxonomy/manage/resource_locations`)

Create terms for your resource locations, for example:
- Google Drive - Marketing Folder
- Project Server - /projects/q1
- SharePoint Site
- GitHub Repository
- Confluence Space

### Step 3: Create Workflow Lists

Navigate to **Structure > Workflow Lists** (`/admin/structure/workflow-list`)

Click **Add Workflow List** (this button should now be visible!) and configure:
- **Name** - Give your workflow a descriptive name
- **Description** - Optional description
- **Assigned Users** - Select users (can be changed anytime)
- **Assigned Groups** - Select groups if Group module is installed
- **Resource Location Tags** - Tag with relevant resource locations

## Usage

### Creating a Workflow List

1. Go to **Structure > Workflow Lists**
2. Click **Add Workflow List**
3. Fill in the details:
   - Name: "Q1 Marketing Campaign"
   - Description: "Marketing workflow for Q1 2025"
   - Assign users: Select team members
   - Assign groups: Select relevant groups
   - Tag resources: Select resource locations
4. Click **Save**

### Assigning Workflows to Content

**Method 1: From Content Edit**
- Create or edit content (page, topic, event, etc.)
- Look for the "Workflow List" field
- Select the workflow list
- Save

**Method 2: Using Assign Tab**
- View any content item
- Click the **Assign Workflow** tab
- Select workflow list
- Click **Assign Workflow**

### Editing Workflows

**Quick Edit Method (Fastest):**
- Go to **Structure > Workflow Lists**
- Click **Quick Edit** on any workflow list
- Modify users, groups, or resource tags
- Click **Update Workflow**

**Full Edit Method:**
- Go to **Structure > Workflow Lists**
- Click **Edit** on any workflow list
- Make changes
- Click **Save**

## Workflow Information Display

When viewing content with an assigned workflow, a "Workflow Information" section appears showing:
- Workflow name and description
- Assigned users
- Assigned groups (if applicable)
- Resource locations

Example:
```
Workflow: "Summer 2025 Campaign"
Assigned Users:
- marketing_manager
- content_writer
- designer
Resource Locations:
- Google Drive - Summer Campaign Folder
- Trello Board - Summer 2025
```

## Permissions

- **Administer workflow lists** - Create, edit, delete workflow lists and modify assignments
- **Assign workflow lists to content** - Assign and change workflows on content
- **View workflow list assignments** - View workflow information on content

Configure permissions at: **People > Permissions** (`/admin/people/permissions`)

## Programmatic Usage

### Creating a Workflow List

```php
use Drupal\workflow_assignment\Entity\WorkflowList;

// Create a new workflow list
$workflow = WorkflowList::create([
  'id' => 'my_project',
  'label' => 'My Project Workflow',
  'description' => 'Workflow for my awesome project',
]);

// Assign users
$workflow->addAssignedUser(5);
$workflow->addAssignedUser(12);

// Assign groups
$workflow->addAssignedGroup(3);

// Add resource tags
$workflow->addResourceTag(10);

$workflow->save();
```

### Modifying a Workflow List

```php
// Load workflow
$workflow = \Drupal::entityTypeManager()
  ->getStorage('workflow_list')
  ->load('my_project');

// Add a user
$workflow->addAssignedUser(20);

// Remove a user
$workflow->removeAssignedUser(5);

// Change resource tags
$workflow->setResourceTags([10, 11, 12]);

$workflow->save();
```

### Assigning Workflow to Content

```php
use Drupal\node\Entity\Node;

// Load node
$node = Node::load(123);

// Assign workflow
$node->set('field_workflow_list', 'my_project');
$node->save();

// Remove workflow
$node->set('field_workflow_list', NULL);
$node->save();
```

## Troubleshooting

### "Add Workflow List" Button Not Showing

This version includes all necessary fixes. If the button still doesn't appear:

1. **Clear cache**:
   ```bash
   drush cr
   ```

2. **Rebuild routes**:
   ```bash
   drush router:rebuild
   ```

3. **Check permissions**: Ensure your role has "Administer workflow lists" permission

### Workflow Field Not Available on Content Type

1. Go to **Configuration > Workflow > Workflow Assignment**
2. Enable the content type in settings
3. Clear cache

### Resource Location Vocabulary Missing

1. Navigate to **Structure > Taxonomy** (`/admin/structure/taxonomy`)
2. Create a vocabulary named "Resource Locations" with machine name `resource_locations`
3. Or select a different vocabulary in the module settings

## Uninstallation

The module will automatically:
- Remove workflow list field from all content types
- Remove field storage
- Keep the Resource Locations vocabulary (contains user data)

```bash
drush pmu workflow_assignment -y
```

## Open Social Integration

This module is designed to work seamlessly with Open Social:
- **Group Support** - Automatically detects and supports Group module groups
- **Content Types** - Works with Open Social content types (topic, event, book)
- **Team Collaboration** - Perfect for community-based workflows
- **Resource Sharing** - Tag shared resources for easy team access

## Technical Details

### Architecture

- **WorkflowList Entity** - Config entity storing workflow data
- **WorkflowListForm** - Full create/edit form
- **QuickEditWorkflowForm** - Streamlined on-the-fly editing
- **NodeAssignWorkflowForm** - Assign workflows to content
- **WorkflowListListBuilder** - Administration interface

### Data Storage

- **Workflow lists**: Configuration entities (exportable)
- **Content assignments**: Field on node entities
- **Resource locations**: Taxonomy terms

## Support

For issues or feature requests:
- Review this documentation
- Check Drupal.org issue queues
- Review Drupal API documentation

## License

This module is provided as-is for use with Drupal 10 and 11.

---

**Version**: 1.0.0 (Fixed)  
**Designed for**: Flexible, dynamic workflow management in Drupal 10/11 and Open Social distributions
