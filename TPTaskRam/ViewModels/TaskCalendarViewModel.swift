//
//  TaskCalendarViewModel.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//
//  Owns all state and business logic for TaskCalendarView.
//  The view keeps @FetchRequest (Core Data requires it on the main actor)
//  and passes the resulting array into the ViewModel's pure functions.

import Foundation
import Combine
import CoreData
import SwiftUI

final class TaskCalendarViewModel: ObservableObject {

    // MARK: - Published UI State

    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var taskToEdit: TaskItem?
    @Published var showingCreate: Bool = false

    // MARK: - Derived Data

    /// All tasks whose dueDate falls on `date`.
    func tasksForDate(_ tasks: [TaskItem], on date: Date) -> [TaskItem] {
        tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDate(due, inSameDayAs: date)
        }
    }

    /// Set of "yyyy-MM-dd" strings for every day that has at least one task with a due date.
    func datesWithTasks(from tasks: [TaskItem]) -> Set<String> {
        let formatter = dateKeyFormatter()
        var dates = Set<String>()
        for task in tasks {
            if let due = task.dueDate {
                dates.insert(formatter.string(from: due))
            }
        }
        return dates
    }

    /// Whether a specific calendar day has any task.
    func hasTask(on date: Date, in datesWithTasks: Set<String>) -> Bool {
        datesWithTasks.contains(dateKeyFormatter().string(from: date))
    }

    // MARK: - Month Grid

    /// Returns an array of optional Dates for the calendar grid.
    /// Leading `nil` entries pad to the correct weekday start.
    func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    // MARK: - Navigation Actions

    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func jumpToToday() {
        selectedDate = Date()
        currentMonth = Date()
    }

    // MARK: - Display Helpers

    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Private

    private func dateKeyFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
