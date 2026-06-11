//
//  TPTaskRamTests.swift
//  TPTaskRamTests
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//

import XCTest
import CoreData
@testable import TPTaskRam

// MARK: - Base test case with an in-memory Core Data stack

class TPTaskRamBaseTestCase: XCTestCase {

    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        try super.tearDownWithError()
    }

    // Convenience: create and return a TaskItem with sane defaults
    @discardableResult
    func makeTask(
        title: String = "Test Task",
        category: String = "Work",
        priority: Int16 = 1,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        notificationEnabled: Bool = false
    ) -> TaskItem {
        let task = TaskItem(context: context)
        task.id = UUID()
        task.title = title
        task.taskDescription = "Description"
        task.category = category
        task.priority = priority
        task.isCompleted = isCompleted
        task.dueDate = dueDate
        task.notificationEnabled = notificationEnabled
        task.createdAt = Date()
        return task
    }

    func saveContext() throws {
        try context.save()
    }
}

// MARK: - TaskItem CRUD Tests

final class TaskItemCRUDTests: TPTaskRamBaseTestCase {

    // Creating a task persists all fields correctly
    func testCreateTask_savesAllFields() throws {
        let due = Date().addingTimeInterval(3600)
        let task = makeTask(title: "Buy milk", category: "Shopping", priority: 0, dueDate: due, notificationEnabled: true)
        try saveContext()

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", "Buy milk")
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1, "Exactly one task should be saved")
        let saved = try XCTUnwrap(results.first)
        XCTAssertEqual(saved.title, "Buy milk")
        XCTAssertEqual(saved.category, "Shopping")
        XCTAssertEqual(saved.priority, 0)
        XCTAssertFalse(saved.isCompleted)
        XCTAssertTrue(saved.notificationEnabled)
        XCTAssertNotNil(saved.id)
        XCTAssertNotNil(saved.createdAt)
    }

    // Updating a task's title persists the change
    func testUpdateTask_titleChange_isPersisted() throws {
        let task = makeTask(title: "Old Title")
        try saveContext()

        task.title = "New Title"
        try saveContext()

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertEqual(results.first?.title, "New Title")
    }

    // Deleting a task removes it from the store
    func testDeleteTask_removesFromStore() throws {
        let task = makeTask(title: "To Delete")
        try saveContext()

        context.delete(task)
        try saveContext()

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertTrue(results.isEmpty, "Deleted task should not exist in the store")
    }

    // Toggling isCompleted persists correctly
    func testToggleCompletion_persistsBothStates() throws {
        let task = makeTask(isCompleted: false)
        try saveContext()

        task.isCompleted = true
        try saveContext()
        XCTAssertTrue(task.isCompleted)

        task.isCompleted = false
        try saveContext()
        XCTAssertFalse(task.isCompleted)
    }

    // A task created without a due date has nil dueDate
    func testCreateTask_withoutDueDate_dueDateIsNil() throws {
        let task = makeTask(dueDate: nil)
        try saveContext()
        XCTAssertNil(task.dueDate)
    }

    // Multiple tasks can be saved independently
    func testCreateMultipleTasks_allPersisted() throws {
        makeTask(title: "Task A")
        makeTask(title: "Task B")
        makeTask(title: "Task C")
        try saveContext()

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 3)
    }
}

// MARK: - Filtering Logic Tests
// These mirror the computed properties in TaskListView so we test the same predicate logic.

final class TaskFilteringTests: TPTaskRamBaseTestCase {

    private func fetchAll() throws -> [TaskItem] {
        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)]
        return try context.fetch(request)
    }

    private func filter(tasks: [TaskItem], category: String, search: String) -> [TaskItem] {
        var result = tasks
        if category != "All" {
            result = result.filter { $0.category == category }
        }
        if !search.isEmpty {
            result = result.filter { ($0.title ?? "").localizedCaseInsensitiveContains(search) }
        }
        return result
    }

    // "All" category returns every task
    func testFilter_allCategory_returnsAllTasks() throws {
        makeTask(title: "Work task", category: "Work")
        makeTask(title: "Personal task", category: "Personal")
        try saveContext()

        let all = try fetchAll()
        let filtered = filter(tasks: all, category: "All", search: "")
        XCTAssertEqual(filtered.count, 2)
    }

    // Category filter returns only matching tasks
    func testFilter_specificCategory_returnsOnlyMatchingTasks() throws {
        makeTask(title: "Work task", category: "Work")
        makeTask(title: "Health task", category: "Health")
        makeTask(title: "Another work", category: "Work")
        try saveContext()

        let all = try fetchAll()
        let filtered = filter(tasks: all, category: "Work", search: "")
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "Work" })
    }

    // Search is case-insensitive
    func testFilter_search_isCaseInsensitive() throws {
        makeTask(title: "Buy Groceries")
        makeTask(title: "Team Meeting")
        try saveContext()

        let all = try fetchAll()
        let filtered = filter(tasks: all, category: "All", search: "groceries")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Buy Groceries")
    }

    // Search with no match returns empty list
    func testFilter_search_noMatch_returnsEmpty() throws {
        makeTask(title: "Buy Groceries")
        try saveContext()

        let all = try fetchAll()
        let filtered = filter(tasks: all, category: "All", search: "ZZZNOMATCH")
        XCTAssertTrue(filtered.isEmpty)
    }

    // Combined category + search filter
    func testFilter_categoryAndSearch_combined() throws {
        makeTask(title: "Work report", category: "Work")
        makeTask(title: "Work meeting", category: "Work")
        makeTask(title: "Personal report", category: "Personal")
        try saveContext()

        let all = try fetchAll()
        let filtered = filter(tasks: all, category: "Work", search: "report")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Work report")
    }

    // Pending and completed split
    func testFilter_pendingAndCompleted_splitCorrectly() throws {
        makeTask(title: "Done", isCompleted: true)
        makeTask(title: "Not Done", isCompleted: false)
        makeTask(title: "Also Done", isCompleted: true)
        try saveContext()

        let all = try fetchAll()
        let pending   = all.filter { !$0.isCompleted }
        let completed = all.filter { $0.isCompleted }

        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(completed.count, 2)
    }
}

// MARK: - Priority Tests

final class TaskPriorityTests: TPTaskRamBaseTestCase {

    func testPriority_high_isZero() throws {
        let task = makeTask(priority: 0)
        XCTAssertEqual(task.priority, 0, "High priority should be stored as 0")
    }

    func testPriority_medium_isOne() throws {
        let task = makeTask(priority: 1)
        XCTAssertEqual(task.priority, 1, "Medium priority should be stored as 1")
    }

    func testPriority_low_isTwo() throws {
        let task = makeTask(priority: 2)
        XCTAssertEqual(task.priority, 2, "Low priority should be stored as 2")
    }

    // Default priority value from model is 1 (Medium)
    func testPriority_defaultValue_isMedium() throws {
        let task = TaskItem(context: context)
        task.id = UUID()
        task.title = "No priority set explicitly"
        try saveContext()
        // Core Data default for Integer16 "1" as set in .xcdatamodel
        XCTAssertEqual(task.priority, 1)
    }
}

// MARK: - Due Date & Overdue Tests

final class TaskDueDateTests: TPTaskRamBaseTestCase {

    func testDueDate_inPast_flagsAsOverdue() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = makeTask(dueDate: yesterday)
        try saveContext()

        let isOverdue = (task.dueDate ?? Date()) < Date() && !task.isCompleted
        XCTAssertTrue(isOverdue, "A pending task with a past due date should be overdue")
    }

    func testDueDate_inFuture_isNotOverdue() throws {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = makeTask(dueDate: tomorrow)
        try saveContext()

        let isOverdue = (task.dueDate ?? Date()) < Date() && !task.isCompleted
        XCTAssertFalse(isOverdue, "A task with a future due date should not be overdue")
    }

    func testDueDate_completedPastDue_isNotOverdue() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = makeTask(isCompleted: true, dueDate: yesterday)
        try saveContext()

        // Overdue logic: past date AND not completed — completed task is never overdue
        let isOverdue = (task.dueDate ?? Date()) < Date() && !task.isCompleted
        XCTAssertFalse(isOverdue, "A completed task should never be marked overdue")
    }
}

// MARK: - Category Management Tests

final class CategoryManagementTests: XCTestCase {

    // Helper that mirrors allCategoriesString parsing logic
    private func parseCategories(from string: String) -> [String] {
        string.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    private func addCategory(_ name: String, to existing: inout String) -> Bool {
        let all = parseCategories(from: existing)
        guard !all.contains(where: { $0.lowercased() == name.lowercased() }) else { return false }
        existing = (all + [name]).joined(separator: ",")
        return true
    }

    func testParseCategories_returnsCorrectList() {
        let string = "Work,Personal,Shopping,Health"
        let cats = parseCategories(from: string)
        XCTAssertEqual(cats, ["Work", "Personal", "Shopping", "Health"])
    }

    func testParseCategories_emptyString_returnsEmptyList() {
        let cats = parseCategories(from: "")
        XCTAssertTrue(cats.isEmpty)
    }

    func testAddCategory_newName_appendsSuccessfully() {
        var stored = "Work,Personal"
        let added = addCategory("Fitness", to: &stored)
        XCTAssertTrue(added)
        XCTAssertTrue(stored.contains("Fitness"))
        XCTAssertEqual(parseCategories(from: stored).count, 3)
    }

    func testAddCategory_duplicateName_returnsFalse() {
        var stored = "Work,Personal"
        let added = addCategory("Work", to: &stored)
        XCTAssertFalse(added, "Adding a duplicate category should be rejected")
        XCTAssertEqual(parseCategories(from: stored).count, 2, "Count should remain 2")
    }

    func testAddCategory_duplicateCaseInsensitive_returnsFalse() {
        var stored = "Work,Personal"
        let added = addCategory("work", to: &stored)
        XCTAssertFalse(added, "Case-insensitive duplicate should be rejected")
    }

    func testAddCategory_whitespaceOnlyName_notAdded() {
        var stored = "Work"
        let trimmed = "   ".trimmingCharacters(in: .whitespaces)
        let added = trimmed.isEmpty ? false : addCategory(trimmed, to: &stored)
        XCTAssertFalse(added, "Whitespace-only category name should be rejected")
    }

    func testAllCategoriesWithAll_prependsAllOption() {
        let stored = "Work,Personal"
        let all = ["All"] + parseCategories(from: stored)
        XCTAssertEqual(all.first, "All")
        XCTAssertEqual(all.count, 3)
    }
}

// MARK: - Bulk Selection Logic Tests

final class BulkSelectionTests: TPTaskRamBaseTestCase {

    func testSelectAll_addsAllTaskIDsToSet() throws {
        let t1 = makeTask(title: "T1")
        let t2 = makeTask(title: "T2")
        let t3 = makeTask(title: "T3")
        try saveContext()

        let tasks = [t1, t2, t3]
        var selectedIDs: Set<NSManagedObjectID> = []

        // Simulate "Select All"
        selectedIDs = Set(tasks.map { $0.objectID })
        XCTAssertEqual(selectedIDs.count, 3)
    }

    func testDeselectAll_clearsSet() throws {
        let t1 = makeTask(title: "T1")
        let t2 = makeTask(title: "T2")
        try saveContext()

        var selectedIDs: Set<NSManagedObjectID> = [t1.objectID, t2.objectID]
        // Simulate "Deselect All"
        selectedIDs.removeAll()
        XCTAssertTrue(selectedIDs.isEmpty)
    }

    func testToggleSelection_addsAndRemovesID() throws {
        let task = makeTask(title: "Toggle me")
        try saveContext()

        var selectedIDs: Set<NSManagedObjectID> = []

        // First tap — select
        if selectedIDs.contains(task.objectID) {
            selectedIDs.remove(task.objectID)
        } else {
            selectedIDs.insert(task.objectID)
        }
        XCTAssertTrue(selectedIDs.contains(task.objectID))

        // Second tap — deselect
        if selectedIDs.contains(task.objectID) {
            selectedIDs.remove(task.objectID)
        } else {
            selectedIDs.insert(task.objectID)
        }
        XCTAssertFalse(selectedIDs.contains(task.objectID))
    }

    func testDeleteSelected_removesOnlySelectedTasks() throws {
        let t1 = makeTask(title: "Keep me")
        let t2 = makeTask(title: "Delete me")
        let t3 = makeTask(title: "Delete me too")
        try saveContext()

        let selectedIDs: Set<NSManagedObjectID> = [t2.objectID, t3.objectID]
        let allTasks = [t1, t2, t3]

        allTasks
            .filter { selectedIDs.contains($0.objectID) }
            .forEach { context.delete($0) }
        try saveContext()

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let remaining = try context.fetch(request)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "Keep me")
    }

    // Select All / Deselect All toggle logic
    func testSelectAllToggle_whenAllSelected_deselects() throws {
        let t1 = makeTask(title: "T1")
        let t2 = makeTask(title: "T2")
        try saveContext()

        let allTasks = [t1, t2]
        var selectedIDs: Set<NSManagedObjectID> = Set(allTasks.map { $0.objectID })

        // All already selected → Deselect All
        let allIDs = Set(allTasks.map { $0.objectID })
        selectedIDs = (selectedIDs.count == allIDs.count) ? [] : allIDs
        XCTAssertTrue(selectedIDs.isEmpty)
    }

    func testSelectAllToggle_whenNoneSelected_selectsAll() throws {
        let t1 = makeTask(title: "T1")
        let t2 = makeTask(title: "T2")
        try saveContext()

        let allTasks = [t1, t2]
        var selectedIDs: Set<NSManagedObjectID> = []

        // None selected → Select All
        let allIDs = Set(allTasks.map { $0.objectID })
        selectedIDs = (selectedIDs.count == allIDs.count) ? [] : allIDs
        XCTAssertEqual(selectedIDs.count, 2)
    }
}

// MARK: - Calendar Date Grouping Tests

final class CalendarDateGroupingTests: XCTestCase {

    // Retain the controller so its context (and the task objects) stay alive for the test
    private var controller: PersistenceController!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        controller = nil
        super.tearDown()
    }

    private func tasksForDate(_ date: Date, from tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDate(due, inSameDayAs: date)
        }
    }

    private func makeMockTask(dueDate: Date?) -> TaskItem {
        let task = TaskItem(context: controller.container.viewContext)
        task.id = UUID()
        task.title = "Mock"
        task.dueDate = dueDate
        return task
    }

    func testTasksForDate_matchesExactDay() {
        let today = Date()
        let task1 = makeMockTask(dueDate: today)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let task2 = makeMockTask(dueDate: tomorrow)

        let result = tasksForDate(today, from: [task1, task2])
        XCTAssertEqual(result.count, 1)
    }

    func testTasksForDate_noDueDateTasksExcluded() {
        let task = makeMockTask(dueDate: nil)
        let result = tasksForDate(Date(), from: [task])
        XCTAssertTrue(result.isEmpty, "Tasks with no due date should not appear in any calendar day")
    }

    func testTasksForDate_multipleTasksSameDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let morningTime = Calendar.current.date(byAdding: .hour, value: 9,  to: today)!
        let eveningTime = Calendar.current.date(byAdding: .hour, value: 18, to: today)!

        let t1 = makeMockTask(dueDate: morningTime)
        let t2 = makeMockTask(dueDate: eveningTime)
        let t3 = makeMockTask(dueDate: Calendar.current.date(byAdding: .day, value: 2, to: today)!)

        let result = tasksForDate(today, from: [t1, t2, t3])
        XCTAssertEqual(result.count, 2, "Both tasks on the same day should be returned")
    }
}
