//
//  TaskFormView.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//
//  Single view for both creating and editing tasks.
//  Pass nil for `task` to create, or an existing TaskItem to edit.

import SwiftUI
import CoreData
import UserNotifications

struct TaskFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("globalNotificationsEnabled") private var globalNotificationsEnabled = true

    /// nil  → Create mode   |   non-nil → Edit mode
    var task: TaskItem?
    /// Pass a date to pre-fill the due date (e.g. when creating from Calendar)
    var prefilledDate: Date? = nil

    @AppStorage("allCategoriesString") private var allCategoriesString = "Work,Personal,Shopping,Health"

    @StateObject private var viewModel = TaskFormViewModel()

    private var isEditing: Bool { task != nil }

    var body: some View {
        NavigationView {
            Form {
                // MARK: Details
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("Task title", text: $viewModel.title)
                            .onChange(of: viewModel.title) { viewModel.titleTouched = true }
                        Text("*")
                            .foregroundColor(.red)
                            .font(.body.weight(.bold))
                    }
                    if viewModel.showTitleError {
                        Text("Title is required")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    TextField("Description (optional)", text: $viewModel.taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Label("Task Details", systemImage: "pencil.and.list.clipboard")
                }

                // MARK: Category
                Section {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(viewModel.allCategories(from: allCategoriesString), id: \.self) { cat in
                            HStack {
                                Image(systemName: viewModel.iconForCategory(cat))
                                Text(cat)
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    Button {
                        viewModel.newCategoryName = ""
                        viewModel.showingAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                            .foregroundColor(.accentColor)
                    }
                } header: {
                    Label("Category", systemImage: "folder")
                }

                // MARK: Priority
                Section {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(0..<3) { i in
                            HStack {
                                Circle()
                                    .fill(viewModel.colorForPriority(i))
                                    .frame(width: 10, height: 10)
                                Text(viewModel.priorityLabels[i])
                            }
                            .tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Priority", systemImage: "flag")
                }

                // MARK: Schedule
                Section {
                    Toggle("Set due date", isOn: $viewModel.hasDueDate.animation())
                    if viewModel.hasDueDate {
                        DatePicker("Due Date", selection: $viewModel.dueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)

                        Toggle(isOn: $viewModel.notificationEnabled) {
                            HStack {
                                Image(systemName: "bell.badge").foregroundColor(.orange)
                                Text("Remind me 30 min before")
                            }
                        }
                    }
                } header: {
                    Label("Schedule", systemImage: "calendar")
                } footer: {
                    if viewModel.hasDueDate && viewModel.notificationEnabled {
                        Text("A local notification will fire 30 minutes before the due time.")
                            .font(.caption)
                    }
                }
                .onChange(of: viewModel.hasDueDate) { _, enabled in
                    if !enabled { viewModel.notificationEnabled = false }
                }

                // MARK: Save
                Section {
                    Button {
                        let wasEditing = viewModel.save(
                            existingTask: task,
                            context: viewContext,
                            globalNotificationsEnabled: globalNotificationsEnabled
                        )
                        if wasEditing { dismiss() }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isEditing ? "Save Changes" : "Create Task")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(!viewModel.isTitleValid)
                }

                // MARK: Delete (edit mode only)
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            viewModel.showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Task")
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { viewModel.load(from: task, prefilledDate: prefilledDate) }
            .alert("Task Saved", isPresented: $viewModel.showingSaveAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("'\(viewModel.title)' has been added to your tasks.")
            }
            .alert("Delete Task", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let task { viewModel.deleteTask(task, in: viewContext) }
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this task? This cannot be undone.")
            }
            .alert("New Category", isPresented: $viewModel.showingAddCategory) {
                TextField("Category name", text: $viewModel.newCategoryName)
                Button("Add") {
                    switch viewModel.addCategory(name: viewModel.newCategoryName, to: allCategoriesString) {
                    case .added(let newStored, let newCat):
                        allCategoriesString = newStored
                        viewModel.selectedCategory = newCat
                    case .duplicate:
                        viewModel.showingDuplicateCategoryAlert = true
                    case .emptyName:
                        break
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new category.")
            }
            .alert("Duplicate Category", isPresented: $viewModel.showingDuplicateCategoryAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A category with that name already exists.")
            }
        }
    }
}

#Preview("Create") {
    TaskFormView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Edit") {
    TaskFormView(task: {
        let ctx = PersistenceController.preview.container.viewContext
        let t = TaskItem(context: ctx)
        t.id = UUID(); t.title = "Sample Task"; t.category = "Work"
        t.priority = 1; t.dueDate = Date()
        return t
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
