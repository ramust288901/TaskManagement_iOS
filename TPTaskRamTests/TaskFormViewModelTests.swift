//
//  TaskFormViewModelTests.swift
//  TPTaskRamTests
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//
//  Unit tests for TaskFormViewModel.
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
    dueDate: Date? = nil,
    notificationEnabled: Bool = false
) -> TaskItem {
    let task = TaskItem(context: context)
    task.id = UUID()
    task.title = title
    task.taskDescription = "Desc"
    task.category = category
    task.priority = priority
    task.isCompleted = isCompleted
    task.dueDate = dueDate
    task.notificationEnabled = notificationEnabled
    task.createdAt = Date()
    return task
}

// MARK: - Validation

final class TaskFormViewModelValidationTests: XCTestCase {

    var vm: TaskFormViewModel!

    override func setUp() {
        super.setUp()
        vm = TaskFormViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    func testIsTitleValid_emptyString_isFalse() {
        vm.title = ""
        XCTAssertFalse(vm.isTitleValid)
    }

    func testIsTitleValid_whitespaceOnly_isFalse() {
        vm.title = "   "
        XCTAssertFalse(vm.isTitleValid)
    }

    func testIsTitleValid_validTitle_isTrue() {
        vm.title = "Buy milk"
        XCTAssertTrue(vm.isTitleValid)
    }

    func testShowTitleError_falseWhenNotTouched() {
        vm.title = ""
        vm.titleTouched = false
        XCTAssertFalse(vm.showTitleError)
    }

    func testShowTitleError_trueWhenTouchedAndEmpty() {
        vm.title = ""
        vm.titleTouched = true
        XCTAssertTrue(vm.showTitleError)
    }

    func testShowTitleError_falseWhenTouchedButValid() {
        vm.title = "Valid title"
        vm.titleTouched = true
        XCTAssertFalse(vm.showTitleError)
    }
}

// MARK: - Load

final class TaskFormViewModelLoadTests: XCTestCase {

    var vm: TaskFormViewModel!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        vm = TaskFormViewModel()
        context = makeInMemoryContext()
    }

    override func tearDown() {
        vm = nil
        context = nil
        super.tearDown()
    }

    func testLoad_fromTask_populatesAllFields() {
        let due = Date().addingTimeInterval(3600)
        let task = makeTask(in: context, title: "My Task", category: "Health",
                            priority: 0, dueDate: due, notificationEnabled: true)
        vm.load(from: task, prefilledDate: nil)

        XCTAssertEqual(vm.title, "My Task")
        XCTAssertEqual(vm.selectedCategory, "Health")
        XCTAssertEqual(vm.priority, 0)
        XCTAssertTrue(vm.hasDueDate)
        XCTAssertTrue(vm.notificationEnabled)
    }

    func testLoad_fromTask_nilDueDate_setHasDueDateFalse() {
        let task = makeTask(in: context, dueDate: nil)
        vm.load(from: task, prefilledDate: nil)
        XCTAssertFalse(vm.hasDueDate)
    }

    func testLoad_withPrefilledDate_setsDueDateAndEnablesToggle() {
        let prefilled = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        vm.load(from: nil, prefilledDate: prefilled)
        XCTAssertTrue(vm.hasDueDate)
        XCTAssertTrue(Calendar.current.isDate(vm.dueDate, inSameDayAs: prefilled))
    }

    func testLoad_nilTaskNilDate_usesDefaults() {
        vm.load(from: nil, prefilledDate: nil)
        XCTAssertEqual(vm.title, "")
        XCTAssertEqual(vm.priority, 1)
        XCTAssertFalse(vm.hasDueDate)
        XCTAssertFalse(vm.notificationEnabled)
    }
}

// MARK: - Category Management

final class TaskFormViewModelCategoryTests: XCTestCase {

    let vm = TaskFormViewModel()

    func testAllCategories_parsesCSVCorrectly() {
        let result = vm.allCategories(from: "Work,Personal,Shopping")
        XCTAssertEqual(result, ["Work", "Personal", "Shopping"])
    }

    func testAllCategories_emptyString_returnsEmpty() {
        XCTAssertTrue(vm.allCategories(from: "").isEmpty)
    }

    func testAddCategory_newName_returnsAddedResult() {
        let result = vm.addCategory(name: "Fitness", to: "Work,Personal")
        if case .added(let newStored, let newCat) = result {
            XCTAssertTrue(newStored.contains("Fitness"))
            XCTAssertEqual(newCat, "Fitness")
        } else {
            XCTFail("Expected .added but got \(result)")
        }
    }

    func testAddCategory_duplicate_returnsDuplicateResult() {
        let result = vm.addCategory(name: "Work", to: "Work,Personal")
        if case .duplicate = result { } else {
            XCTFail("Expected .duplicate but got \(result)")
        }
    }

    func testAddCategory_caseInsensitiveDuplicate_returnsDuplicate() {
        let result = vm.addCategory(name: "work", to: "Work,Personal")
        if case .duplicate = result { } else {
            XCTFail("Expected .duplicate for case-insensitive match")
        }
    }

    func testAddCategory_emptyName_returnsEmptyName() {
        let result = vm.addCategory(name: "", to: "Work")
        if case .emptyName = result { } else {
            XCTFail("Expected .emptyName but got \(result)")
        }
    }

    func testAddCategory_whitespaceOnlyName_returnsEmptyName() {
        let result = vm.addCategory(name: "   ", to: "Work")
        if case .emptyName = result { } else {
            XCTFail("Expected .emptyName for whitespace-only input")
        }
    }

    func testAddCategory_newStoredStringHasCorrectCount() {
        let result = vm.addCategory(name: "Hobbies", to: "Work,Personal")
        if case .added(let newStored, _) = result {
            let count = newStored.components(separatedBy: ",").filter { !$0.isEmpty }.count
            XCTAssertEqual(count, 3)
        } else {
            XCTFail("Expected .added result")
        }
    }
}

// MARK: - Save

final class TaskFormViewModelSaveTests: XCTestCase {

    var vm: TaskFormViewModel!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        vm = TaskFormViewModel()
        context = makeInMemoryContext()
    }

    override func tearDown() {
        vm = nil
        context = nil
        super.tearDown()
    }

    func testSave_createMode_createsNewTask() throws {
        vm.title = "New Task"
        vm.selectedCategory = "Shopping"
        vm.priority = 2
        vm.hasDueDate = false
        vm.save(existingTask: nil, context: context, globalNotificationsEnabled: false)

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "New Task")
        XCTAssertEqual(results.first?.category, "Shopping")
        XCTAssertEqual(results.first?.priority, 2)
        XCTAssertNil(results.first?.dueDate)
    }

    func testSave_createMode_returnsFalse() {
        vm.title = "Task"
        let isEditMode = vm.save(existingTask: nil, context: context, globalNotificationsEnabled: false)
        XCTAssertFalse(isEditMode)
    }

    func testSave_createMode_setsSaveAlert() {
        vm.title = "Task"
        vm.save(existingTask: nil, context: context, globalNotificationsEnabled: false)
        XCTAssertTrue(vm.showingSaveAlert)
    }

    func testSave_editMode_updatesExistingTask() throws {
        let existing = makeTask(in: context, title: "Old Title", category: "Work", priority: 1)
        try context.save()

        vm.title = "New Title"
        vm.selectedCategory = "Personal"
        vm.priority = 0
        vm.hasDueDate = false
        vm.save(existingTask: existing, context: context, globalNotificationsEnabled: false)

        XCTAssertEqual(existing.title, "New Title")
        XCTAssertEqual(existing.category, "Personal")
        XCTAssertEqual(existing.priority, 0)
    }

    func testSave_editMode_returnsTrue() throws {
        let existing = makeTask(in: context)
        try context.save()
        vm.title = "Updated"
        let isEditMode = vm.save(existingTask: existing, context: context, globalNotificationsEnabled: false)
        XCTAssertTrue(isEditMode)
    }

    func testSave_editMode_doesNotSetSaveAlert() throws {
        let existing = makeTask(in: context)
        try context.save()
        vm.title = "Updated"
        vm.save(existingTask: existing, context: context, globalNotificationsEnabled: false)
        XCTAssertFalse(vm.showingSaveAlert)
    }

    func testSave_withDueDate_persistsDueDate() throws {
        let due = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        vm.title = "Task with due date"
        vm.hasDueDate = true
        vm.dueDate = due
        vm.save(existingTask: nil, context: context, globalNotificationsEnabled: false)

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results.first?.dueDate)
    }

    func testSave_withoutDueDate_persistsNilDueDate() throws {
        vm.title = "No due date"
        vm.hasDueDate = false
        vm.save(existingTask: nil, context: context, globalNotificationsEnabled: false)

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNil(results.first?.dueDate)
    }

    func testSave_titleIsTrimmed() throws {
        vm.title = "  Padded Title  "
        vm.save(existingTask: nil, context: context, globalNotificationsEnabled: false)

        let request: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertEqual(results.first?.title, "Padded Title")
    }
}

// MARK: - Helpers

final class TaskFormViewModelHelperTests: XCTestCase {

    let vm = TaskFormViewModel()

    func testIconForCategory_knownCategories() {
        XCTAssertEqual(vm.iconForCategory("Work"),     "briefcase")
        XCTAssertEqual(vm.iconForCategory("Personal"), "person")
        XCTAssertEqual(vm.iconForCategory("Shopping"), "cart")
        XCTAssertEqual(vm.iconForCategory("Health"),   "heart")
    }

    func testIconForCategory_unknown_returnsFolder() {
        XCTAssertEqual(vm.iconForCategory("Custom"), "folder")
    }

    func testColorForPriority_highIsRed() {
        XCTAssertEqual(vm.colorForPriority(0), .red)
    }

    func testColorForPriority_mediumIsOrange() {
        XCTAssertEqual(vm.colorForPriority(1), .orange)
    }

    func testColorForPriority_lowIsGreen() {
        XCTAssertEqual(vm.colorForPriority(2), .green)
    }

    func testPriorityLabels_hasThreeEntries() {
        XCTAssertEqual(vm.priorityLabels.count, 3)
        XCTAssertEqual(vm.priorityLabels[0], "High")
        XCTAssertEqual(vm.priorityLabels[1], "Medium")
        XCTAssertEqual(vm.priorityLabels[2], "Low")
    }
}
