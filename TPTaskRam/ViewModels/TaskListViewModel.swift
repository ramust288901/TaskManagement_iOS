//
//  TaskListViewModel.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//
//  Owns all state and business logic for TaskListView.
//  The view keeps @FetchRequest (Core Data requires it on the main actor)
//  and passes the resulting array into the ViewModel's filtering methods.

import Foundation
import Combine
import CoreData
import SwiftUI

final class TaskListViewModel: ObservableObject {

    // MARK: - Published UI State

    @Published var selectedCategory: String = "All"
    @Published var searchText: String = ""
    @Published var isSelectMode: Bool = false
    @Published var selectedTaskIDs: Set<NSManagedObjectID> = []
    @Published var showDeleteSelectedConfirm: Bool = false
    @Published var showingCreate: Bool = false
    @Published var taskToEdit: TaskItem?

    // MARK: - Category Helpers

    /// Returns ["All"] + all non-empty categories parsed from the stored CSV string.
    func allCategories(from stored: String) -> [String] {
        ["All"] + stored.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    // MARK: - Filtering

    /// Applies the current category filter and search text to the given task list.
    func filteredTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        var result = tasks
        if selectedCategory != "All" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter { ($0.title ?? "").localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    func pendingTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        filteredTasks(tasks).filter { !$0.isCompleted }
    }

    func completedTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        filteredTasks(tasks).filter { $0.isCompleted }
    }

    // MARK: - Selection

    func toggleSelection(_ task: TaskItem) {
        if selectedTaskIDs.contains(task.objectID) {
            selectedTaskIDs.remove(task.objectID)
        } else {
            selectedTaskIDs.insert(task.objectID)
        }
    }

    /// Selects all when nothing / partial is selected; deselects all when every task is already selected.
    func toggleSelectAll(tasks: [TaskItem]) {
        let allIDs = Set(tasks.map { $0.objectID })
        selectedTaskIDs = (selectedTaskIDs.count == allIDs.count) ? [] : allIDs
    }

    // MARK: - Edit Mode

    func exitEditMode() {
        isSelectMode = false
        selectedTaskIDs.removeAll()
    }

    // MARK: - Actions

    func toggleComplete(_ task: TaskItem, in context: NSManagedObjectContext) {
        task.isCompleted.toggle()
        try? context.save()
    }

    func deleteTask(_ task: TaskItem, in context: NSManagedObjectContext) {
        context.delete(task)
        try? context.save()
    }

    /// Deletes only the tasks whose objectIDs are in `selectedTaskIDs`, then exits edit mode.
    func deleteSelectedTasks(from tasks: [TaskItem], in context: NSManagedObjectContext) {
        tasks
            .filter { selectedTaskIDs.contains($0.objectID) }
            .forEach { context.delete($0) }
        try? context.save()
        selectedTaskIDs.removeAll()
        isSelectMode = false
    }

    // MARK: - Helpers

    func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "Work":     return .blue
        case "Personal": return .purple
        case "Shopping": return .orange
        case "Health":   return .green
        default:         return .gray
        }
    }
}
