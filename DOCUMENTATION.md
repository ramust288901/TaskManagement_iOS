# TPTaskRam — App Documentation

**Developer:** Ramgopal Reddy Bovilla (UST, IN)
**Version:** 1.0.0
**Platform:** iOS (SwiftUI + Core Data)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Model](#data-model)
4. [Persistence Layer](#persistence-layer)
5. [Screens & Features](#screens--features)
   - [Task List Screen](#task-list-screen)
   - [Task Form Screen](#task-form-screen)
   - [Calendar Screen](#calendar-screen)
   - [Settings Screen](#settings-screen)
6. [Notifications](#notifications)
7. [Category Management](#category-management)
8. [UI Components Reference](#ui-components-reference)
9. [Test Coverage](#test-coverage)

---

## Overview

TPTaskRam is a personal task management iOS app. It allows users to create, edit, complete, and delete tasks, organise them by category, assign priorities, set due dates, and receive local notifications 30 minutes before a task is due. A built-in calendar view shows tasks grouped by their due date.

---

## Architecture

```
TPTaskRam/
├── TPTaskRamApp.swift        — App entry point, injects Core Data context
├── ContentView.swift         — Tab bar host (Tasks | Calendar | Settings)
├── Persistence.swift         — Core Data stack (PersistenceController)
├── ViewModels/
│   ├── TaskListViewModel.swift    — State & logic for TaskListView
│   ├── TaskFormViewModel.swift    — State & logic for TaskFormView
│   └── TaskCalendarViewModel.swift — State & logic for TaskCalendarView
└── Views/
    ├── TaskListView.swift    — Main task list + bulk-edit mode
    ├── TaskFormView.swift    — Create / Edit task form (shared sheet)
    └── CalendarView.swift    — Month grid + per-day task list
```

**Pattern:** MVVM.
- **Views** own only UI rendering, `@Environment` wrappers (context, dismiss), `@AppStorage`, and `@FetchRequest` (Core Data requires these on the main actor in SwiftUI).
- **ViewModels** (`ObservableObject`) own all `@Published` state, filtering logic, actions, and helper functions. Views use `@StateObject` to create and hold their ViewModel.

```swift
// Example — TaskListView
@StateObject private var viewModel = TaskListViewModel()
// pass FetchRequest results into the VM's pure filtering functions
var filtered: [TaskItem] { viewModel.filteredTasks(Array(tasks)) }
// delegate actions
viewModel.toggleComplete(task, in: viewContext)
```

---

## Data Model

### Entity: `TaskItem`

Defined in `TPTaskRam.xcdatamodeld`.

| Attribute | Type | Optional | Notes |
|---|---|---|---|
| `id` | UUID | Yes | Unique identifier; also used as the notification request ID |
| `title` | String | Yes | Required at UI level (enforced by form validation) |
| `taskDescription` | String | Yes | Free-text description |
| `category` | String | Yes | One of the user-defined categories |
| `priority` | Integer 16 | Yes | `0` = High, `1` = Medium, `2` = Low. Default: `1` |
| `dueDate` | Date | Yes | `nil` means no due date set |
| `isCompleted` | Boolean | Yes | `false` by default |
| `createdAt` | Date | Yes | Set at creation time |
| `notificationEnabled` | Boolean | Yes | Whether a local notification should fire for this task |

---

## Persistence Layer

**File:** `Persistence.swift`

`PersistenceController` is a singleton (`PersistenceController.shared`) that owns the `NSPersistentContainer`.

- `container.viewContext.automaticallyMergesChangesFromParent = true` keeps the UI context in sync with background saves.
- A static `preview` instance uses an in-memory store populated with 10 sample tasks for SwiftUI Previews and unit tests.

**Usage pattern in views:**
```swift
@Environment(\.managedObjectContext) private var viewContext
// read
@FetchRequest(...) private var tasks: FetchedResults<TaskItem>
// write — always through the ViewModel
viewModel.toggleComplete(task, in: viewContext)
viewModel.deleteTask(task, in: viewContext)
```

## ViewModels Reference

### `TaskListViewModel`

**File:** `ViewModels/TaskListViewModel.swift`
**Used by:** `TaskListView` via `@StateObject`

| Property / Method | Type | Description |
|---|---|---|
| `selectedCategory` | `@Published String` | Currently active category filter chip |
| `searchText` | `@Published String` | Bound to `.searchable` in the view |
| `isSelectMode` | `@Published Bool` | Whether bulk-edit mode is active |
| `selectedTaskIDs` | `@Published Set<NSManagedObjectID>` | IDs of tasks checked for deletion |
| `showDeleteSelectedConfirm` | `@Published Bool` | Triggers the deletion confirmation dialog |
| `showingCreate` | `@Published Bool` | Controls the create-task sheet |
| `taskToEdit` | `@Published TaskItem?` | Controls the edit-task sheet |
| `allCategories(from:)` | `func` | Parses stored CSV, prepends "All" |
| `filteredTasks(_:)` | `func` | Applies category + search filter |
| `pendingTasks(_:)` | `func` | Filtered tasks where `isCompleted == false` |
| `completedTasks(_:)` | `func` | Filtered tasks where `isCompleted == true` |
| `toggleSelection(_:)` | `func` | Adds/removes a task ID from the selection set |
| `toggleSelectAll(tasks:)` | `func` | Selects all when partial/none; deselects all when all selected |
| `exitEditMode()` | `func` | Sets `isSelectMode = false` and clears selection |
| `toggleComplete(_:in:)` | `func` | Flips `isCompleted` and saves to context |
| `deleteTask(_:in:)` | `func` | Deletes one task from context |
| `deleteSelectedTasks(from:in:)` | `func` | Deletes all selected tasks, then exits edit mode |
| `colorForCategory(_:)` | `func` | Maps category name to `Color` |

---

### `TaskFormViewModel`

**File:** `ViewModels/TaskFormViewModel.swift`
**Used by:** `TaskFormView` via `@StateObject`

| Property / Method | Type | Description |
|---|---|---|
| `title` | `@Published String` | Task title field |
| `taskDescription` | `@Published String` | Optional description field |
| `selectedCategory` | `@Published String` | Selected category |
| `priority` | `@Published Int` | 0 = High, 1 = Medium, 2 = Low |
| `dueDate` | `@Published Date` | Value of the date picker |
| `hasDueDate` | `@Published Bool` | Whether the due-date section is expanded |
| `notificationEnabled` | `@Published Bool` | Whether a reminder should be scheduled |
| `titleTouched` | `@Published Bool` | Set `true` on first keystroke; gates the error message |
| `showingAddCategory` | `@Published Bool` | Triggers the "New Category" alert |
| `newCategoryName` | `@Published String` | Input for the new category alert text field |
| `showingDuplicateCategoryAlert` | `@Published Bool` | Triggers the "Duplicate" alert |
| `showingDeleteAlert` | `@Published Bool` | Triggers the delete-confirmation alert |
| `showingSaveAlert` | `@Published Bool` | Triggers the "Task Saved" alert (create mode only) |
| `isTitleValid` | `var Bool` | `true` when `title` has non-whitespace content |
| `showTitleError` | `var Bool` | `true` when touched **and** invalid |
| `load(from:prefilledDate:)` | `func` | Populates form from an existing task or a calendar date |
| `allCategories(from:)` | `func` | Parses stored CSV into an array |
| `addCategory(name:to:)` | `func → AddCategoryResult` | Validates and appends a new category |
| `save(existingTask:context:globalNotificationsEnabled:)` | `func → Bool` | Writes to Core Data; returns `true` in edit mode |
| `deleteTask(_:in:)` | `func` | Deletes a task from context |
| `scheduleNotification(for:)` | `func` | Registers a `UNCalendarNotificationTrigger` 30 min before due |
| `iconForCategory(_:)` | `func` | SF Symbol name for a category |
| `colorForPriority(_:)` | `func` | `Color` for a priority index |

#### `AddCategoryResult` enum

```swift
enum AddCategoryResult {
    case added(newStoredString: String, selectedCategory: String)
    case duplicate     // name already exists (case-insensitive)
    case emptyName     // blank / whitespace-only input
}
```

---



### Task List Screen

**File:** `Views/TaskListView.swift`
**View:** `TaskListView`

The primary screen, accessible via the "Tasks" tab.

#### Category Filter Chips

A horizontal scroll row at the top. Chips are generated from `allCategoriesString` (an `@AppStorage` key) prefixed with "All". Tapping a chip filters the list to that category.

#### Stats Row

Three `StatCard` components showing live counts for **Pending**, **Completed**, and **Total** tasks within the current filter.

#### Task List

Split into two sections — **Pending** and **Completed** — using `Section` headers. Each row uses `TaskRowView`.

When no tasks match the current filter/search, an empty-state illustration is shown.

**Search:** The `.searchable` modifier adds a search bar. Matches are case-insensitive and applied to the task title.

**Sorting:** Tasks are sorted by `dueDate` ascending (set in `@FetchRequest`).

#### Edit (Bulk Select) Mode

Activated by the **Edit** button (top-left navigation bar). Pressing **Done** exits it.

**Row layout in Edit mode:**

| Left | Centre | Right |
|---|---|---|
| Green/grey completion circle *(disabled)* | Title + meta | Priority flag + **blue selection circle** |

The blue circle at the far right is the selection indicator — it is separate from the green completion circle to avoid any ambiguity.

- Tapping a row (text area or selection circle) toggles that task's selection.
- A bottom toolbar appears with **Select All / Deselect All** and **Delete (n)** buttons.
- Confirming delete shows a `confirmationDialog` before permanently removing the selected tasks.

#### Swipe-to-Delete

Available in normal (non-edit) mode. Swipe left on any row to reveal the red **Delete** action.

---

### Task Form Screen

**File:** `Views/TaskFormView.swift`
**View:** `TaskFormView`

A single form used for both **creating** and **editing** tasks. Presented as a sheet.

| Initialiser | Mode |
|---|---|
| `TaskFormView()` | Create new task |
| `TaskFormView(task: existingTask)` | Edit existing task |
| `TaskFormView(prefilledDate: date)` | Create with due date pre-filled (from Calendar) |

#### Sections

1. **Task Details** — Title (required, marked with `*`) and optional description.
   Inline validation shows "Title is required" if the field is touched and left blank.

2. **Category** — Picker (menu style) populated from `allCategoriesString`. An "Add Category" button opens an inline alert to create a new category.

3. **Priority** — Segmented picker: **High** (0) / **Medium** (1) / **Low** (2).

4. **Schedule** — Toggle for due date. When enabled, a graphical `DatePicker` appears along with a "Remind me 30 min before" notification toggle. Disabling the due date automatically disables the notification toggle.

5. **Save / Create Task** — Disabled until the title is non-empty.

6. **Delete Task** *(edit mode only)* — Destructive button with a confirmation alert.

#### Save Logic

- Creates a new `TaskItem` or updates the existing one.
- If `notificationEnabled` is true and the global notification switch (Settings) is on, a local notification is scheduled via `UNUserNotificationCenter`.
- In create mode, shows a "Task Saved" alert before dismissing. In edit mode, dismisses immediately.

---

### Calendar Screen

**File:** `Views/CalendarView.swift`
**View:** `TaskCalendarView`

Accessible via the "Calendar" tab.

#### Month Grid

- Navigate months with chevron buttons (previous / next).
- Today's date is highlighted.
- Days that have at least one task due show a coloured dot indicator.
- Tapping a day selects it and updates the task list below.

#### Task List for Selected Day

Shows all tasks whose `dueDate` falls on the selected day. Each row has an **Edit** button that opens `TaskFormView` in edit mode.

The `+` button pre-fills the form with the selected calendar date so the user doesn't have to pick the date manually.

A **Today** button (top-left) jumps the calendar back to the current date.

---

### Settings Screen

**File:** `ContentView.swift` (inline `SettingsView`)

Accessible via the "Settings" tab.

| Section | Content |
|---|---|
| App header | App name, icon, tagline |
| Statistics | Live total / completed / pending counts across ALL tasks (no category filter) |
| Preferences | Global notifications toggle; Manage Categories navigation link |
| Data | Delete All Completed Tasks (destructive, with confirmation alert) |
| About | Version, developer, company |

**Global Notifications Toggle:** When turned off, all pending notification requests are cancelled. Re-enabling reschedules notifications for all tasks that have `notificationEnabled = true` and a future due date.

---

## Notifications

Local notifications are managed with `UNUserNotificationCenter`.

**Trigger:** `UNCalendarNotificationTrigger` fires **30 minutes before** a task's `dueDate`.

**Request ID:** The task's `UUID` string — this allows pending requests to be removed or replaced when a task is edited.

**Permission:** Requested lazily the first time a notification is about to be scheduled (`requestAuthorization`).

**Guard conditions — a notification is only scheduled if:**
- `hasDueDate` is `true`
- `notificationEnabled` is `true` on the task
- `globalNotificationsEnabled` (`@AppStorage`) is `true`

---

## Category Management

Categories are stored as a comma-separated string in `@AppStorage("allCategoriesString")`. Default value: `"Work,Personal,Shopping,Health"`.

**Adding a category:**
1. Open Task Form → Category section → "Add Category".
2. Enter a name in the alert text field.
3. Duplicate detection is case-insensitive. A duplicate shows "Duplicate Category" alert.
4. On success, the new category is appended to `allCategoriesString` and immediately selected.

**Icon & colour mapping (built-in categories):**

| Category | Icon | Chip colour |
|---|---|---|
| Work | `briefcase` | Blue |
| Personal | `person` | Purple |
| Shopping | `cart` | Orange |
| Health | `heart` | Green |
| *(custom)* | `folder` | Gray |

Categories can be managed (view / delete) via **Settings → Manage Categories** (`CategorySettingsView`).

---

## UI Components Reference

All reusable components are defined in `TaskListView.swift`.

### `CategoryChip`

Pill-shaped filter chip. Selected state fills the chip with the category colour; deselected state shows a tinted background with a subtle border.

```swift
CategoryChip(title: "Work", isSelected: true, color: .blue)
```

### `StatCard`

Compact card showing a numeric count and a label.

```swift
StatCard(title: "Pending", count: 3, color: .orange)
```

### `TaskRowView`

The main list row. Adapts its layout based on `isSelectMode`.

```swift
TaskRowView(
    task: task,
    isSelectMode: isSelectMode,
    isSelected: selectedTaskIDs.contains(task.objectID),
    onToggle: { toggleComplete(task) },
    onSelect: { toggleSelection(task) },
    onTap: { taskToEdit = task }
)
```

**Layout:**

```
[ ● completion ] [ Title + category chip + due date ]  [ Priority flag ] [ ○ selection* ]
                                                                           * Edit mode only
```

### `PriorityFlag`

Small coloured badge: `High` (red), `Med` (orange), `Low` (green).

```swift
PriorityFlag(priority: task.priority)   // priority: Int16
```

### `CalendarDayView`

Single day cell in the calendar grid. Shows the day number, today highlight ring, selected-day filled background, and a small dot if tasks exist.

### `CalendarTaskRow`

Simplified task row used inside the calendar's per-day list with an Edit button.

---

## Test Coverage

### Data Layer Tests

**File:** `TPTaskRamTests/TPTaskRamTests.swift`

All tests use an in-memory `PersistenceController` (isolated, no disk state).

| Test Class | What is tested |
|---|---|
| `TaskItemCRUDTests` | Create with all fields, update title, delete, toggle completion, nil due date, multiple tasks |
| `TaskFilteringTests` | "All" category pass-through, per-category filter, case-insensitive search, no-match search, combined filter, pending/completed split |
| `TaskPriorityTests` | High/Medium/Low stored values, default priority from data model |
| `TaskDueDateTests` | Past due = overdue, future due = not overdue, completed past-due = not overdue |
| `CategoryManagementTests` | Parse CSV string, add new category, reject duplicate, case-insensitive duplicate, whitespace-only name rejection, "All" prepend |
| `BulkSelectionTests` | Select all, deselect all, toggle individual selection, delete only selected tasks, Select/Deselect All toggle logic |
| `CalendarDateGroupingTests` | Same-day match, nil due date excluded, multiple tasks on same day |

---

### ViewModel Tests

**Files:** `TPTaskRamTests/TaskListViewModelTests.swift`, `TPTaskRamTests/TaskFormViewModelTests.swift`, `TPTaskRamTests/TaskCalendarViewModelTests.swift`

Tests instantiate the ViewModels directly and call their methods — no SwiftUI involved.

> **Note on test isolation:** `NSManagedObject.managedObjectContext` is a **weak** reference. Each test class that creates managed objects retains an `NSManagedObjectContext` as an `ivar` initialised in `setUp()` so the context — and thus all object property values — remain alive for the full test.

| Test Class | ViewModel | What is tested |
|---|---|---|
| `TaskListViewModelFilteringTests` | `TaskListViewModel` | All-category passthrough, specific category filter, no-match, case-insensitive search, partial search, combined filter, pending/completed split |
| `TaskListViewModelSelectionTests` | `TaskListViewModel` | `toggleSelection` add/remove, `toggleSelectAll` (none → all, all → none, partial → all), `exitEditMode` clears state |
| `TaskListViewModelActionTests` | `TaskListViewModel` | `toggleComplete` both directions, `deleteTask` removes from context, `deleteSelectedTasks` removes only selected tasks and exits edit mode |
| `TaskListViewModelHelperTests` | `TaskListViewModel` | `allCategories` prepends "All", empty string, `colorForCategory` known vs default |
| `TaskFormViewModelValidationTests` | `TaskFormViewModel` | `isTitleValid` (empty, whitespace, valid), `showTitleError` (not touched, touched+empty, touched+valid) |
| `TaskFormViewModelLoadTests` | `TaskFormViewModel` | Load from task (all fields), nil due date → `hasDueDate=false`, prefilled date → `hasDueDate=true`, nil+nil → defaults |
| `TaskFormViewModelCategoryTests` | `TaskFormViewModel` | CSV parsing, `addCategory` success, duplicate, case-insensitive duplicate, empty name, whitespace name, count after add |
| `TaskFormViewModelSaveTests` | `TaskFormViewModel` | Create mode persists fields, returns `false`, sets save alert; edit mode updates existing task, returns `true`, no alert; due date saved/not saved; title trimmed |
| `TaskFormViewModelHelperTests` | `TaskFormViewModel` | `iconForCategory` all known cases + default, `colorForPriority` all three levels, `priorityLabels` count and values |
| `TaskCalendarViewModelDateTests` | `TaskCalendarViewModel` | `tasksForDate` exact-day, nil exclusion, multiple same-day, empty input; `datesWithTasks` keys/nil exclusion/deduplication; `hasTask` true/false |
| `TaskCalendarViewModelNavigationTests` | `TaskCalendarViewModel` | Forward/back month, 12-month full cycle, `jumpToToday` resets both dates |
| `TaskCalendarViewModelGridTests` | `TaskCalendarViewModel` | Grid count is multiple of 7, correct non-nil day count, first/last day correctness, reflects month change |
| `TaskCalendarViewModelHelperTests` | `TaskCalendarViewModel` | `monthYearString` non-empty and contains year, `dateString` non-empty, different months differ |
