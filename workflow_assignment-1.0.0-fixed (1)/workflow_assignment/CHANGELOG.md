# Changelog

All notable changes to the Workflow Assignment module will be documented in this file.

## [1.0.0-fixed] - 2025-11-02

### Fixed
- **CRITICAL FIX**: Missing "Add Workflow List" button on `/admin/structure/workflow-list`
  - Added `add-form` link to WorkflowList entity annotation
  - Added `AdminHtmlRouteProvider` as route provider
  - Created `workflow_assignment.links.action.yml` for local action
  - Updated `WorkflowListListBuilder` with proper render method
  - Ensured all routes are properly defined

### Added
- Complete module structure with all required files
- WorkflowList entity with proper annotations
- WorkflowListInterface for type hinting
- WorkflowListForm for add/edit operations
- QuickEditWorkflowForm for rapid updates
- NodeAssignWorkflowForm for content assignment
- SettingsForm for module configuration
- WorkflowListListBuilder with enhanced display
- Installation hooks for automatic setup
- Workflow info display template
- Comprehensive README documentation
- Permission system (administer, assign, view)
- Menu links and local tasks
- Theme integration

### Technical Details
- Fixed entity annotation with complete `links` array
- Added `route_provider` using `AdminHtmlRouteProvider`
- Implemented proper local action for Add button
- Created all necessary routing definitions
- Added field management on install/uninstall
- Included template for workflow information display

### Known Issues
- None at this time

## Architecture Improvements

### Entity Structure
```
WorkflowList (ConfigEntityType)
├── Links (add-form, edit-form, delete-form, collection)
├── Route Provider (AdminHtmlRouteProvider)
├── List Builder (WorkflowListListBuilder)
└── Forms (add, edit, delete, quick-edit)
```

### Key Files Added
- `workflow_assignment.links.action.yml` - Defines the Add button
- `workflow_assignment.routing.yml` - All route definitions
- `src/Entity/WorkflowList.php` - Entity with fixed annotations
- `src/WorkflowListListBuilder.php` - List builder with render method
- `src/Form/WorkflowListForm.php` - Main form handler
- `src/Form/QuickEditWorkflowForm.php` - Quick edit interface
- `src/Form/SettingsForm.php` - Module configuration
- `src/Form/NodeAssignWorkflowForm.php` - Content assignment

## Installation Notes

This version should work immediately after installation with:
```bash
drush en workflow_assignment -y
drush cr
```

The "Add Workflow List" button will appear automatically at:
`/admin/structure/workflow-list`

---

**Maintainer Notes**: This changelog documents the fix for the critical missing Add button issue. All future changes should be documented here.
