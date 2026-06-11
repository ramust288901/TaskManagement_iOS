//
//  TaskListViewModelTests.swift
//  TPTaskRamTests
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//
//  Unit tests for TaskListViewModel.
//  All Core Data operations use an isolated in-memory store.

import XCTest
import CoreData
import SwiftUI
@testable import TPTaskRam

// MARK: - In-memory helpers

private func makeInMemoryContext() -> NSManagedObjectContext {
    PersistenceController(inMemory: true).container.viewContext
}

@discardableResult
private func makeTask(
    in context: NSManagedObjectContext,
    title: String = "Test",
    category: String = "Work",
    priority: Int16 = 1,
    isCompleted: Bool = false,
    dueDate: Date? = nil
) -> TaskItem {
    let task = TaskItem(context: context)
    task.id = UUID()
    task.title = title
    task.taskDescription = "Desc"
    task.category = category
    task.priority = priority
    task.isCompleted = isCompleted
    task.dueDate = dueDate
    task.createdAt = Date()
    return task
}

// MARK: - Filtering

final class TaskListViewModelFilteringTests: XCTestCase {

    var vm: TaskListViewModel!
    // Retained for the lifetime of each test so managed objects stay valid
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        vm = TaskListViewModel()
        context = makeInMemoryContext()
    }

    override func tearDown() {
        vm = nil
        context = nil
        super.tearDown()
    }

    private func makeTasks() -> [TaskItem] {
        // Reuse self.context so the context is not released between creation and use
        return [
            makeTask(in: context, title: "Work report",   category: "Work",     isCompleted: false),
            makeTask(in: context, title: "Work meeting",  category: "Work",     isCompleted: true),
            makeTask(in: context, title: "Buy groceries", category: "Shopping", isCompleted: false),
            makeTask(in: context, title: "Morning run",   category: "Health",   isCompleted: false),
        ]
    }

    func testFilteredTasks_allCategory_returnsAllTasks() {
        vm.selectedCategory = "All"
        vm.searchText = ""
        XCTAssertEqual(vm.filteredTasks(makeTasks()).count, 4)
    }

    func testFilteredTasks_specificCategory_returnsOnlyMatching() {
        vm.selectedCategory = "Work"
        vm.searchText = ""
        let result = vm.filteredTasks(makeTasks())
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.category == "Work" })
    }

    func testFilteredTasks_categoryWithNoMatch_returnsEmpty() {
        vm.selectedCategory = "Personal"
        vm.searchText = ""
        XCTAssertTrue(vm.filteredTasks(makeTasks()).isEmpty)
    }

    func testFilteredTasks_search_isCaseInsensitive() {
        vm.selectedCategory = "All"
        vm.searchText = "REPORT"
        let result = vm.filteredTasks(makeTasks())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Work report")
    }

    func testFilteredTasks_search_partialMatch() {
        vm.selectedCategory = "All"
        vm.searchText = "work"
        let result = vm.filteredTasks(makeTasks())
        XCTAssertEqual(result.count, 2)
    }

    func testFilteredTasks_search_noMatch_returnsEmpty() {
        vm.selectedCategory = "All"
        vm.searchText = "ZZZNOMATCH"
        XCTAssertTrue(vm.filteredTasks(makeTasks()).isEmpty)
    }

    func testFilteredTasks_combinedCategoryAndSearch() {
        vm.selectedCategory = "Work"
        vm.searchText = "meeting"
        let result = vm.filteredTasks(makeTasks())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Work meeting")
    }

    func testPendingTasks_returnsOnlyIncomplete() {
        vm.selectedCategory = "All"
        vm.searchText = ""
        let pending = vm.pendingTasks(makeTasks())
        XCTAssertTrue(pending.allSatisfy { !$0.isCompleted })
        XCTAssertEqual(pending.count, 3)
    }

    func testCompletedTasks_returnsOnlyCompleted() {
        vm.selectedCategory = "All"
        vm.searchText = ""
        let completed = vm.completedTasks(makeTasks())
        XCTAssertTrue(completed.allSatisfy { $0.isCompleted })
        XCTAssertEqual(completed.count, 1)
    }
}

// MARK: - Selection

final class TaskListViewModelSelectionTests: XCTestCase {

    var vm: TaskListViewModel!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        vm = TaskListViewModel()
        context = makeInMemoryContext()
    }

    override func tearDown() {
        vm = nil
        context = nil
        super.tearDown()
    }

    func testToggleSelection_selectsTask() {
        let task = makeTask(in: context)
        vm.toggleSelection(task)
        XCTAssertTrue(vm.selectedTaskIDs.contains(task.objectID))
    }

    func testToggleSelection_deselectsAlreadySelectedTask() {
        let task = makeTask(in: context)
        vm.toggleSelection(task)
        vm.toggleSelection(task)
        XCTAssertFalse(vm.selectedTaskIDs.contains(task.objectID))
    }

    func testToggleSelectAll_whenNoneSelected_selectsAll() {
        let tasks = [makeTask(in: context, title: "A"), makeTask(in: context, title: "B")]
        vm.toggleSelectAll(tasks: tasks)
        XCTAssertEqual(vm.selectedTaskIDs.count, 2)
    }

    func testToggleSelectAll_whenAllSelected_deselectsAll() {
        let tasks = [makeTask(in: context, title: "A"), makeTask(in: context, title: "B")]
        vm.toggleSelectAll(tasks: tasks)
        vm.toggleSelectAll(tasks: tasks)
        XCTAssertTrue(vm.selectedTaskIDs.isEmpty)
    }

    func testToggleSelectAll_whenPartiallySelected_selectsAll() {
        let tasks = [makeTask(in: context, title: "A"), makeTask(in: context, title: "B")]
        vm.toggleSelection(tasks[0])
        vm.toggleSelectAll(tasks: tasks)
        XCTAssertEqual(vm.selectedTaskIDs.count, 2)
    }

    func testExitEditMode_clearsSelectionAndMode() {
        let task = makeTask(in: context)
        vm.isSelectMode = true
        vm.toggleSelection(task)
        vm.exitEditMode()
        XCTAssertFalse(vm.isSelectMode)
        XCTAssertTrue(vm.selectedTaskIDs.isEmpty)
    }
}

// MARK: - Actions

final class TaskListViewModelActionTests: XCTestCase {

    var vm: TaskListViewModel!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        vm = TaskListViewModel()
        context = makeInMemoryContext()
    }

    override func tearDown() {
        vm = nil
        context = nil
        super.tearDown()
    }

    func testToggleComplete_setsIsCompletedTrue() throws {
        let task = makeTask(in: context, isCompleted: false)
        try context.save()
        vm.toggleComplete(task, in: context)
        XCTAssertTrue(task.isCompleted)
    }

    func testToggleComplete_setsIsCompletedFalse() throws {
        let task = makeTask(in: context, isCompleted: true)
        try context.save()
        vm.toggleComplete(task, in: context)
        XCTAssertFalse(task.isCompleted)
    }

    func testDeleteTask_removesFromContext() throws {
        let task = makeTask(in: context, title: "To delete")
        try context.save()
        vm.deleteTask(task, in: context)
        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let remaining = try context.fetch(request)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testDeleteSelectedTasks_removesOnlySelected() throws {
        let keep = makeTask(in: context, title: "Keep")
        let del1 = makeTask(in: context, title: "Delete 1")
        let del2 = makeTask(in: context, title: "Delete 2")
        try context.save()

        vm.toggleSelection(del1)
        vm.toggleSelection(del2)
        vm.deleteSelectedTasks(from: [keep, del1, del2], in: context)

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let remaining = try context.fetch(request)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "Keep")
    }

    func testDeleteSelectedTasks_clearsSelectionAndExitsEditMode() throws {
        let task = makeTask(in: context)
        try context.save()
        vm.isSelectMode = true
        vm.toggleSelection(task)
        vm.deleteSelectedTasks(from: [task], in: context)
        XCTAssertFalse(vm.isSelectMode)
        XCTAssertTrue(vm.selectedTaskIDs.isEmpty)
    }
}

// MARK: - Helpers

final class TaskListViewModelHelperTests: XCTestCase {

    let vm = TaskListViewModel()

    func testAllCategories_prependsAll() {
        let result = vm.allCategories(from: "Work,Personal")
        XCTAssertEqual(result.first, "All")
        XCTAssertEqual(result.count, 3)
    }

    func testAllCategories_emptyString_returnsJustAll() {
        let result = vm.allCategories(from: "")
        XCTAssertEqual(result, ["All"])
    }

    func testColorForCategory_knownVsDefault_areDifferent() {
        let workColor = vm.colorForCategory("Work")
        let grayColor = vm.colorForCategory("UnknownXYZ")
        XCTAssertNotEqual(workColor, grayColor)
    }
}
