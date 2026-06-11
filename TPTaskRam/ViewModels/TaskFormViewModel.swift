//
//  TaskFormViewModel.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//
//  Owns all form state and business logic for TaskFormView.
//  The view keeps @Environment (context, dismiss) and @AppStorage
//  and passes those values into ViewModel methods when needed.

import Foundation
import Combine
import CoreData
import SwiftUI
import UserNotifications

// MARK: - Result type for adding a category

enum AddCategoryResult {
    /// Category was added successfully. Carries the updated CSV string and the new category name.
    case added(newStoredString: String, selectedCategory: String)
    /// The name already exists (case-insensitive match).
    case duplicate
    /// The name was empty or whitespace-only.
    case emptyName
}

// MARK: - ViewModel

final class TaskFormViewModel: ObservableObject {

    // MARK: - Form Fields

    @Published var title: String = ""
    @Published var taskDescription: String = ""
    @Published var selectedCategory: String = "Work"
    @Published var priority: Int = 1
    @Published var dueDate: Date = Date()
    @Published var hasDueDate: Bool = false
    @Published var notificationEnabled: Bool = false
    @Published var titleTouched: Bool = false

    // MARK: - Category UI State

    @Published var showingAddCategory: Bool = false
    @Published var newCategoryName: String = ""
    @Published var showingDuplicateCategoryAlert: Bool = false

    // MARK: - Alert Flags

    @Published var showingDeleteAlert: Bool = false
    @Published var showingSaveAlert: Bool = false

    // MARK: - Constants

    let priorityLabels = ["High", "Medium", "Low"]

    // MARK: - Validation

    var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var showTitleError: Bool {
        titleTouched && !isTitleValid
    }

    // MARK: - Load

    /// Populates form fields from an existing task (edit mode) or a prefilled calendar date (create mode).
    func load(from task: TaskItem?, prefilledDate: Date?) {
        if let task {
            title = task.title ?? ""
            taskDescription = task.taskDescription ?? ""
            selectedCategory = task.category ?? "Work"
            priority = Int(task.priority)
            dueDate = task.dueDate ?? Date()
            hasDueDate = task.dueDate != nil
            notificationEnabled = task.notificationEnabled
        } else if let prefilledDate {
            dueDate = prefilledDate
            hasDueDate = true
        }
    }

    // MARK: - Category Management

    /// Parses the stored CSV string into a category array.
    func allCategories(from stored: String) -> [String] {
        stored.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    /// Tries to add a new category name.  Returns an `AddCategoryResult` describing the outcome.
    func addCategory(name: String, to existing: String) -> AddCategoryResult {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .emptyName }
        let current = existing.components(separatedBy: ",").filter { !$0.isEmpty }
        guard !current.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            return .duplicate
        }
        let newString = (current + [trimmed]).joined(separator: ",")
        return .added(newStoredString: newString, selectedCategory: trimmed)
    }

    // MARK: - Save

    /// Writes form data to Core Data and schedules a notification if needed.
    /// - Returns: `true` when updating an existing task (caller should dismiss immediately);
    ///            `false` when creating a new task (caller should show "Task Saved" alert).
    @discardableResult
    func save(existingTask: TaskItem?,
              context: NSManagedObjectContext,
              globalNotificationsEnabled: Bool) -> Bool {
        let isEditing = existingTask != nil
        let target = existingTask ?? TaskItem(context: context)

        target.title = title.trimmingCharacters(in: .whitespaces)
        target.taskDescription = taskDescription.trimmingCharacters(in: .whitespaces)
        target.category = selectedCategory
        target.priority = Int16(priority)
        target.dueDate = hasDueDate ? dueDate : nil
        target.notificationEnabled = notificationEnabled

        if !isEditing {
            target.id = UUID()
            target.isCompleted = false
            target.createdAt = Date()
        }

        try? context.save()

        if notificationEnabled && hasDueDate && globalNotificationsEnabled {
            scheduleNotification(for: target)
        }

        if !isEditing {
            showingSaveAlert = true
        }

        return isEditing
    }

    // MARK: - Delete

    func deleteTask(_ task: TaskItem, in context: NSManagedObjectContext) {
        context.delete(task)
        try? context.save()
    }

    // MARK: - Notification

    func scheduleNotification(for task: TaskItem) {
        let center = UNUserNotificationCenter.current()
        if let id = task.id?.uuidString {
            center.removePendingNotificationRequests(withIdentifiers: [id])
        }
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted, let due = task.dueDate else { return }
            let content = UNMutableNotificationContent()
            content.title = "Task Reminder"
            content.body = task.title ?? "You have a task due soon!"
            content.sound = .default
            let triggerDate = Calendar.current.date(byAdding: .minute, value: -30, to: due) ?? due
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: task.id?.uuidString ?? UUID().uuidString,
                content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Helpers

    func iconForCategory(_ cat: String) -> String {
        switch cat {
        case "Work":     return "briefcase"
        case "Personal": return "person"
        case "Shopping": return "cart"
        case "Health":   return "heart"
        default:         return "folder"
        }
    }

    func colorForPriority(_ p: Int) -> Color {
        switch p {
        case 0: return .red
        case 1: return .orange
        default: return .green
        }
    }
}
