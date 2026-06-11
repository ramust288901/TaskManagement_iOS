//
//  TaskCalendarViewModelTests.swift
//  TPTaskRamTests
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//
//  Unit tests for TaskCalendarViewModel.
//  All Core Data operations use an isolated in-memory store.

import XCTest
import CoreData
@testable import TPTaskRam

// MARK: - In-memory helpers

private func makeInMemoryContext() -> NSManagedObjectContext {
    PersistenceController(inMemory: true).container.viewContext
}

// MARK: - Tasks-for-date Tests

final class TaskCalendarViewModelDateTests: XCTestCase {

    var vm: TaskCalendarViewModel!
    // Retained so managed objects stay valid throughout the test
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        vm = TaskCalendarViewModel()
        context = makeInMemoryContext()
    }

    override func tearDown() {
        vm = nil
        context = nil
        super.tearDown()
    }

    private func makeTask(dueDate: Date?) -> TaskItem {
        let task = TaskItem(context: context)
        task.id = UUID()
        task.title = "Task"
        task.dueDate = dueDate
        task.createdAt = Date()
        return task
    }

    // MARK: tasksForDate

    func testTasksForDate_matchesExactDay() {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let t1 = makeTask(dueDate: today)
        let t2 = makeTask(dueDate: tomorrow)

        let result = vm.tasksForDate([t1, t2], on: today)
        XCTAssertEqual(result.count, 1)
    }

    func testTasksForDate_nilDueDate_excluded() {
        let t = makeTask(dueDate: nil)
        let result = vm.tasksForDate([t], on: Date())
        XCTAssertTrue(result.isEmpty)
    }

    func testTasksForDate_multipleTasksSameDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let morning = Calendar.current.date(byAdding: .hour, value: 9,  to: today)!
        let evening = Calendar.current.date(byAdding: .hour, value: 18, to: today)!
        let other   = Calendar.current.date(byAdding: .day,  value: 2,  to: today)!

        let t1 = makeTask(dueDate: morning)
        let t2 = makeTask(dueDate: evening)
        let t3 = makeTask(dueDate: other)

        let result = vm.tasksForDate([t1, t2, t3], on: today)
        XCTAssertEqual(result.count, 2)
    }

    func testTasksForDate_emptyInput_returnsEmpty() {
        let result = vm.tasksForDate([], on: Date())
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: datesWithTasks

    func testDatesWithTasks_returnsCorrectDateStrings() {
        let today   = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let t1 = makeTask(dueDate: today)
        let t2 = makeTask(dueDate: tomorrow)

        let result = vm.datesWithTasks(from: [t1, t2])
        XCTAssertEqual(result.count, 2)
    }

    func testDatesWithTasks_nilDueDates_excluded() {
        let t = makeTask(dueDate: nil)
        let result = vm.datesWithTasks(from: [t])
        XCTAssertTrue(result.isEmpty)
    }

    func testDatesWithTasks_multipleSameDay_deduplicatedInSet() {
        let today = Calendar.current.startOfDay(for: Date())
        let t1 = makeTask(dueDate: today)
        let t2 = makeTask(dueDate: Calendar.current.date(byAdding: .hour, value: 3, to: today)!)

        let result = vm.datesWithTasks(from: [t1, t2])
        XCTAssertEqual(result.count, 1, "Two tasks on the same day should produce one date entry")
    }

    // MARK: hasTask

    func testHasTask_returnsTrueWhenDatePresent() {
        let today = Calendar.current.startOfDay(for: Date())
        let t = makeTask(dueDate: today)
        let dates = vm.datesWithTasks(from: [t])
        XCTAssertTrue(vm.hasTask(on: today, in: dates))
    }

    func testHasTask_returnsFalseWhenDateAbsent() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let today = Calendar.current.startOfDay(for: Date())
        let t = makeTask(dueDate: today)
        let dates = vm.datesWithTasks(from: [t])
        XCTAssertFalse(vm.hasTask(on: yesterday, in: dates))
    }
}

// MARK: - Month Navigation Tests

final class TaskCalendarViewModelNavigationTests: XCTestCase {

    var vm: TaskCalendarViewModel!

    override func setUp() {
        super.setUp()
        vm = TaskCalendarViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    func testChangeMonth_forwardByOne_advancesMonth() {
        let original = vm.currentMonth
        vm.changeMonth(by: 1)
        let expected = Calendar.current.date(byAdding: .month, value: 1, to: original)!
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month], from: vm.currentMonth),
            Calendar.current.dateComponents([.year, .month], from: expected)
        )
    }

    func testChangeMonth_backByOne_retreatsMonth() {
        let original = vm.currentMonth
        vm.changeMonth(by: -1)
        let expected = Calendar.current.date(byAdding: .month, value: -1, to: original)!
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month], from: vm.currentMonth),
            Calendar.current.dateComponents([.year, .month], from: expected)
        )
    }

    func testChangeMonth_forward12_returnsSameMonthNextYear() {
        let original = vm.currentMonth
        for _ in 0..<12 { vm.changeMonth(by: 1) }
        let originalYear  = Calendar.current.component(.year,  from: original)
        let originalMonth = Calendar.current.component(.month, from: original)
        let newYear       = Calendar.current.component(.year,  from: vm.currentMonth)
        let newMonth      = Calendar.current.component(.month, from: vm.currentMonth)
        XCTAssertEqual(newYear,  originalYear + 1)
        XCTAssertEqual(newMonth, originalMonth)
    }

    func testJumpToToday_resetsSelectedDateAndCurrentMonth() {
        vm.changeMonth(by: 3)
        vm.selectedDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        vm.jumpToToday()
        XCTAssertTrue(Calendar.current.isDateInToday(vm.selectedDate))
        XCTAssertTrue(Calendar.current.isDate(vm.currentMonth, equalTo: Date(), toGranularity: .month))
    }
}

// MARK: - Days-in-month Grid Tests

final class TaskCalendarViewModelGridTests: XCTestCase {

    var vm: TaskCalendarViewModel!

    override func setUp() {
        super.setUp()
        vm = TaskCalendarViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    func testDaysInMonth_countIsMultipleOf7() {
        let days = vm.daysInMonth()
        XCTAssertEqual(days.count % 7, 0, "Grid must always have a multiple of 7 cells")
    }

    func testDaysInMonth_hasCorrectNumberOfNonNilDays() {
        let range = Calendar.current.range(of: .day, in: .month, for: vm.currentMonth)!
        let nonNilCount = vm.daysInMonth().compactMap { $0 }.count
        XCTAssertEqual(nonNilCount, range.count)
    }

    func testDaysInMonth_firstNonNilDay_isFirstOfMonth() {
        let firstNonNil = vm.daysInMonth().compactMap { $0 }.first!
        XCTAssertEqual(Calendar.current.component(.day, from: firstNonNil), 1)
    }

    func testDaysInMonth_lastNonNilDay_isLastOfMonth() {
        let range = Calendar.current.range(of: .day, in: .month, for: vm.currentMonth)!
        let lastNonNil = vm.daysInMonth().compactMap { $0 }.last!
        XCTAssertEqual(Calendar.current.component(.day, from: lastNonNil), range.count)
    }

    func testDaysInMonth_afterMonthChange_reflectsNewMonth() {
        vm.changeMonth(by: 1)
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        let expectedRange = Calendar.current.range(of: .day, in: .month, for: nextMonth)!
        let nonNilCount = vm.daysInMonth().compactMap { $0 }.count
        XCTAssertEqual(nonNilCount, expectedRange.count)
    }
}

// MARK: - Display Helper Tests

final class TaskCalendarViewModelHelperTests: XCTestCase {

    let vm = TaskCalendarViewModel()

    func testMonthYearString_returnsNonEmptyString() {
        let result = vm.monthYearString(from: Date())
        XCTAssertFalse(result.isEmpty)
    }

    func testMonthYearString_containsYear() {
        let year = String(Calendar.current.component(.year, from: Date()))
        XCTAssertTrue(vm.monthYearString(from: Date()).contains(year))
    }

    func testDateString_returnsNonEmptyString() {
        XCTAssertFalse(vm.dateString(from: Date()).isEmpty)
    }

    func testMonthYearString_differentMonths_areDifferent() {
        let thisMonth = Date()
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: thisMonth)!
        XCTAssertNotEqual(
            vm.monthYearString(from: thisMonth),
            vm.monthYearString(from: nextMonth)
        )
    }
}
