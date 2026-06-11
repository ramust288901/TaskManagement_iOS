//
//  TaskListView.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//

import SwiftUI
import CoreData

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedCategory = "All"
    @State private var showingCreate = false
    @State private var taskToEdit: TaskItem?
    @State private var searchText = ""
    @State private var isSelectMode = false
    @State private var selectedTaskIDs: Set<NSManagedObjectID> = []
    @State private var showDeleteSelectedConfirm = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)],
        animation: .default)
    private var tasks: FetchedResults<TaskItem>

    @AppStorage("allCategoriesString") private var allCategoriesString = "Work,Personal,Shopping,Health"

    private var allCategories: [String] {
        ["All"] + allCategoriesString.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var filteredTasks: [TaskItem] {
        var result = Array(tasks)
        if selectedCategory != "All" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter { ($0.title ?? "").localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var pendingTasks: [TaskItem]   { filteredTasks.filter { !$0.isCompleted } }
    var completedTasks: [TaskItem] { filteredTasks.filter { $0.isCompleted } }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // MARK: Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(allCategories, id: \.self) { cat in
                            CategoryChip(
                                title: cat,
                                isSelected: selectedCategory == cat,
                                color: colorForCategory(cat)
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

                // MARK: Stats row
                HStack(spacing: 12) {
                    StatCard(title: "Pending",   count: pendingTasks.count,   color: .orange)
                    StatCard(title: "Completed", count: completedTasks.count, color: .green)
                    StatCard(title: "Total",     count: filteredTasks.count,  color: .blue)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)

                // MARK: Task list
                List {
                    if !pendingTasks.isEmpty {
                        Section(header: Text("Pending").font(.headline).foregroundColor(.primary)) {
                            ForEach(pendingTasks, id: \.id) { task in
                                HStack(spacing: 12) {
                                    if isSelectMode {
                                        Image(systemName: selectedTaskIDs.contains(task.objectID) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedTaskIDs.contains(task.objectID) ? .red : .secondary)
                                            .font(.title3)
                                            .onTapGesture { toggleSelection(task) }
                                    }
                                    TaskRowView(task: task,
                                                onToggle: { if !isSelectMode { toggleComplete(task) } },
                                                onTap:    { isSelectMode ? toggleSelection(task) : (taskToEdit = task) })
                                }
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing) {
                                    if !isSelectMode {
                                        Button(role: .destructive) { deleteTask(task) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !completedTasks.isEmpty {
                        Section(header: Text("Completed").font(.headline).foregroundColor(.primary)) {
                            ForEach(completedTasks, id: \.id) { task in
                                HStack(spacing: 12) {
                                    if isSelectMode {
                                        Image(systemName: selectedTaskIDs.contains(task.objectID) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedTaskIDs.contains(task.objectID) ? .red : .secondary)
                                            .font(.title3)
                                            .onTapGesture { toggleSelection(task) }
                                    }
                                    TaskRowView(task: task,
                                                onToggle: { if !isSelectMode { toggleComplete(task) } },
                                                onTap:    { isSelectMode ? toggleSelection(task) : (taskToEdit = task) })
                                }
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing) {
                                    if !isSelectMode {
                                        Button(role: .destructive) { deleteTask(task) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if filteredTasks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checklist")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("No tasks yet")
                                .font(.title3)
                                .foregroundColor(.gray)
                            Text("Tap + to add your first task")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("My Tasks")
            .searchable(text: $searchText, prompt: "Search tasks...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !filteredTasks.isEmpty {
                        Button(isSelectMode ? "Done" : "Select") {
                            withAnimation {
                                isSelectMode.toggle()
                                if !isSelectMode { selectedTaskIDs.removeAll() }
                            }
                        }
                        .foregroundColor(isSelectMode ? .red : .blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSelectMode {
                        Button { showingCreate = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            // Create mode — pass no task (nil)
            .sheet(isPresented: $showingCreate) {
                TaskFormView()
            }
            // Edit mode — pass the tapped task
            .sheet(item: $taskToEdit) { task in
                TaskFormView(task: task)
            }
            .confirmationDialog(
                "Delete \(selectedTaskIDs.count) task\(selectedTaskIDs.count == 1 ? "" : "s")?",
                isPresented: $showDeleteSelectedConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteSelectedTasks() }
                Button("Cancel", role: .cancel) { }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectMode {
                    HStack {
                        Button {
                            let allIDs = Set(filteredTasks.map { $0.objectID })
                            selectedTaskIDs = (selectedTaskIDs.count == allIDs.count) ? [] : allIDs
                        } label: {
                            Text(selectedTaskIDs.count == filteredTasks.count ? "Deselect All" : "Select All")
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                        Button(role: .destructive) {
                            if !selectedTaskIDs.isEmpty { showDeleteSelectedConfirm = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text(selectedTaskIDs.isEmpty ? "Delete" : "Delete (\(selectedTaskIDs.count))")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(selectedTaskIDs.isEmpty ? .secondary : .red)
                        }
                        .disabled(selectedTaskIDs.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .overlay(Divider(), alignment: .top)
                }
            }
        }
    }

    // MARK: - Actions
    private func toggleComplete(_ task: TaskItem) {
        withAnimation {
            task.isCompleted.toggle()
            try? viewContext.save()
        }
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation {
            viewContext.delete(task)
            try? viewContext.save()
        }
    }

    private func toggleSelection(_ task: TaskItem) {
        if selectedTaskIDs.contains(task.objectID) {
            selectedTaskIDs.remove(task.objectID)
        } else {
            selectedTaskIDs.insert(task.objectID)
        }
    }

    private func deleteSelectedTasks() {
        withAnimation {
            filteredTasks
                .filter { selectedTaskIDs.contains($0.objectID) }
                .forEach { viewContext.delete($0) }
            try? viewContext.save()
            selectedTaskIDs.removeAll()
            isSelectMode = false
        }
    }

    private func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "Work":     return .blue
        case "Personal": return .purple
        case "Shopping": return .orange
        case "Health":   return .green
        default:         return .gray
        }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.1))
            .foregroundColor(isSelected ? .white : color)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.3), lineWidth: isSelected ? 0 : 1))
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)").font(.title2.bold()).foregroundColor(color)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Task Row
struct TaskRowView: View {
    @ObservedObject var task: TaskItem
    var onToggle: () -> Void
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Tap the circle to mark complete / undo
            Button { onToggle() } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)

            // Tap the text area to open edit sheet
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled")
                    .font(.body.weight(.medium))
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let cat = task.category {
                        Text(cat)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(cat).opacity(0.15))
                            .foregroundColor(categoryColor(cat))
                            .cornerRadius(4)
                    }
                    if let due = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar").font(.caption2)
                            Text(due, style: .date).font(.caption2)
                        }
                        .foregroundColor(due < Date() && !task.isCompleted ? .red : .secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            Spacer()

            // Clear priority label — no more mystery dots
            PriorityFlag(priority: task.priority)
        }
        .padding(.vertical, 4)
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Work":     return .blue
        case "Personal": return .purple
        case "Shopping": return .orange
        case "Health":   return .green
        default:         return .gray
        }
    }
}

// MARK: - Priority Flag
struct PriorityFlag: View {
    let priority: Int16

    var label: String {
        switch priority { case 0: return "High"; case 1: return "Med"; default: return "Low" }
    }
    var color: Color {
        switch priority { case 0: return .red; case 1: return .orange; default: return .green }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill").font(.caption2)
            Text(label).font(.caption2.weight(.semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    TaskListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
