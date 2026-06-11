//
//  CalendarView.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//

import SwiftUI
import CoreData

struct TaskCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = TaskCalendarViewModel()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)],
        animation: .default)
    private var allTasks: FetchedResults<TaskItem>

    // MARK: - Derived (delegate to ViewModel)

    private var tasksForSelectedDate: [TaskItem] {
        viewModel.tasksForDate(Array(allTasks), on: viewModel.selectedDate)
    }

    private var datesWithTasksSet: Set<String> {
        viewModel.datesWithTasks(from: Array(allTasks))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month Navigation
                HStack {
                    Button {
                        withAnimation { viewModel.changeMonth(by: -1) }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Text(viewModel.monthYearString(from: viewModel.currentMonth))
                        .font(.title2.bold())

                    Spacer()

                    Button {
                        withAnimation { viewModel.changeMonth(by: 1) }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Day headers
                HStack(spacing: 0) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)

                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(viewModel.daysInMonth(), id: \.self) { date in
                        if let date = date {
                            CalendarDayView(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                                isToday: Calendar.current.isDateInToday(date),
                                hasTask: viewModel.hasTask(on: date, in: datesWithTasksSet)
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectedDate = date
                                }
                            }
                        } else {
                            Text("")
                                .frame(height: 40)
                        }
                    }
                }
                .padding(.horizontal, 8)

                Divider()
                    .padding(.vertical, 12)

                // Tasks for selected date
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tasks for \(viewModel.dateString(from: viewModel.selectedDate))")
                            .font(.headline)
                        Spacer()
                        Text("\(tasksForSelectedDate.count) task(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    if tasksForSelectedDate.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("No tasks for this date")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(tasksForSelectedDate, id: \.id) { task in
                                CalendarTaskRow(task: task, onEdit: { viewModel.taskToEdit = task })
                            }
                        }
                        .listStyle(.plain)
                    }
                }

                Spacer()
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { viewModel.showingCreate = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { viewModel.jumpToToday() }
                    } label: {
                        Text("Today")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            // Create task pre-filled with the selected calendar date
            .sheet(isPresented: $viewModel.showingCreate) {
                TaskFormView(prefilledDate: viewModel.selectedDate)
            }
            // Edit task tapped from calendar list
            .sheet(item: $viewModel.taskToEdit) { task in
                TaskFormView(task: task)
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        // Kept for reference — logic now lives in TaskCalendarViewModel.daysInMonth()
        viewModel.daysInMonth()
    }

    private func hasTask(on date: Date) -> Bool {
        viewModel.hasTask(on: date, in: datesWithTasksSet)
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasTask: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
                .foregroundColor(foregroundColor)

            if hasTask {
                Circle()
                    .fill(isSelected ? .white : .blue)
                    .frame(width: 5, height: 5)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
    }

    var backgroundColor: Color {
        if isSelected { return .blue }
        if isToday { return .blue.opacity(0.1) }
        return .clear
    }

    var foregroundColor: Color {
        if isSelected { return .white }
        if isToday { return .blue }
        return .primary
    }
}

// MARK: - Calendar Task Row
struct CalendarTaskRow: View {
    @ObservedObject var task: TaskItem
    @Environment(\.managedObjectContext) private var viewContext
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(categoryColor)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title ?? "Untitled")
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isCompleted)

                if let dueDate = task.dueDate {
                    Text(dueDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }

            Spacer()

            Button {
                withAnimation {
                    task.isCompleted.toggle()
                    try? viewContext.save()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    var categoryColor: Color {
        switch task.category {
        case "Work": return .blue
        case "Personal": return .purple
        case "Shopping": return .orange
        case "Health": return .green
        default: return .gray
        }
    }
}

#Preview {
    TaskCalendarView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
