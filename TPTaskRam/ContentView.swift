//
//  ContentView.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//

import SwiftUI
import CoreData
import UserNotifications

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Tasks")
                }
                .tag(0)

            TaskCalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    /// Persisted across launches — the real global notifications switch
    @AppStorage("globalNotificationsEnabled") private var globalNotificationsEnabled = true

    @State private var showingDeleteAlert = false

    @FetchRequest(sortDescriptors: [])
    private var allTasks: FetchedResults<TaskItem>

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TPTaskRam")
                                .font(.title2.bold())
                            Text("Task Management App")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }

                Section("Statistics") {
                    HStack {
                        Label("Total Tasks", systemImage: "list.bullet")
                        Spacer()
                        Text("\(allTasks.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Completed", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(allTasks.filter { $0.isCompleted }.count)")
                            .foregroundColor(.green)
                    }
                    HStack {
                        Label("Pending", systemImage: "clock")
                        Spacer()
                        Text("\(allTasks.filter { !$0.isCompleted }.count)")
                            .foregroundColor(.orange)
                    }
                }

                Section("Preferences") {
                    Toggle(isOn: $globalNotificationsEnabled) {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                    .onChange(of: globalNotificationsEnabled) { _, enabled in
                        if enabled {
                            rescheduleAll()
                        } else {
                            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                        }
                    }

                    if !globalNotificationsEnabled {
                        Text("All task reminders are turned off. Enable to restore scheduled reminders.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    NavigationLink {
                        CategorySettingsView()
                    } label: {
                        Label("Manage Categories", systemImage: "folder.badge.gear")
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete All Completed Tasks", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Ramgopal Reddy Bovilla")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Company")
                        Spacer()
                        Text("UST")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete Completed Tasks", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteCompletedTasks()
                }
            } message: {
                Text("Are you sure you want to delete all completed tasks? This action cannot be undone.")
            }
        }
    }

    private func deleteCompletedTasks() {
        let completed = allTasks.filter { $0.isCompleted }
        for task in completed {
            // Cancel any pending notification for this task before deleting
            if let id = task.id?.uuidString {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            }
            viewContext.delete(task)
        }
        try? viewContext.save()
    }

    /// Re-schedules notifications for every task that has reminders enabled
    private func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            for task in allTasks where task.notificationEnabled && !task.isCompleted {
                guard let due = task.dueDate, let id = task.id?.uuidString else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Task Reminder"
                content.body = task.title ?? "You have a task due soon!"
                content.sound = .default
                let triggerDate = Calendar.current.date(byAdding: .minute, value: -30, to: due) ?? due
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
}

// MARK: - Category Settings View
struct CategorySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("allCategoriesString") private var allCategoriesString = "Work,Personal,Shopping,Health"

    @FetchRequest(sortDescriptors: [])
    private var allTasks: FetchedResults<TaskItem>

    @State private var categories: [String] = []
    @State private var editingCategory: String? = nil
    @State private var newName = ""
    @State private var showRenameAlert = false
    @State private var showAddAlert = false
    @State private var newCategoryName = ""
    @State private var showDuplicateAlert = false

    var body: some View {
        List {
            Section {
                ForEach(categories, id: \.self) { cat in
                    HStack {
                        Image(systemName: iconForCategory(cat))
                            .foregroundColor(colorForCategory(cat))
                            .frame(width: 28)
                        Text(cat)
                        Spacer()
                        Button {
                            editingCategory = cat
                            newName = cat
                            showRenameAlert = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { indices, newOffset in
                    categories.move(fromOffsets: indices, toOffset: newOffset)
                    allCategoriesString = categories.joined(separator: ",")
                }
            } footer: {
                Text("Drag rows to reorder. Tap the pencil to rename. Changes apply immediately to all tasks.")
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newCategoryName = ""
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            let loaded = allCategoriesString.components(separatedBy: ",").filter { !$0.isEmpty }
            categories = loaded
        }
        .onChange(of: allCategoriesString) { _, new in
            let loaded = new.components(separatedBy: ",").filter { !$0.isEmpty }
            if loaded != categories { categories = loaded }
        }
        .alert("Rename Category", isPresented: $showRenameAlert) {
            TextField("Category name", text: $newName)
            Button("Rename") {
                guard let old = editingCategory else { return }
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                if categories.contains(where: { $0.lowercased() == trimmed.lowercased() && $0.lowercased() != old.lowercased() }) {
                    showDuplicateAlert = true
                    return
                }
                if let idx = categories.firstIndex(of: old) {
                    categories[idx] = trimmed
                    allCategoriesString = categories.joined(separator: ",")
                    for task in allTasks where task.category == old {
                        task.category = trimmed
                    }
                    try? viewContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let categoryName = editingCategory ?? ""
            Text("Enter a new name for \"\(categoryName)\".")
        }
        .alert("New Category", isPresented: $showAddAlert) {
            TextField("Category name", text: $newCategoryName)
            Button("Add") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                if categories.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
                    showDuplicateAlert = true
                    return
                }
                categories.append(trimmed)
                allCategoriesString = categories.joined(separator: ",")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new category.")
        }
        .alert("Duplicate Category", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A category with that name already exists.")
        }
    }

    private func iconForCategory(_ cat: String) -> String {
        switch cat {
        case "Work":     return "briefcase"
        case "Personal": return "person"
        case "Shopping": return "cart"
        case "Health":   return "heart"
        default:         return "folder"
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

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
