//
//  Persistence.swift
//  TPTaskRam
//
//  Created by Ramgopal Reddy Bovilla(UST,IN) on 27/05/26.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        let categories = ["Work", "Personal", "Shopping", "Health"]
        let titles = [
            "Complete project report", "Buy groceries", "Morning workout",
            "Team meeting", "Read a book", "Doctor appointment",
            "Code review", "Plan vacation", "Pay bills", "Clean house"
        ]

        for i in 0..<10 {
            let task = TaskItem(context: viewContext)
            task.id = UUID()
            task.title = titles[i]
            task.taskDescription = "Description for \(titles[i])"
            task.category = categories[i % categories.count]
            task.priority = Int16(i % 3)
            task.dueDate = Calendar.current.date(byAdding: .day, value: i - 3, to: Date())
            task.isCompleted = i > 6
            task.createdAt = Date()
            task.notificationEnabled = i % 2 == 0
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TPTaskRam")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
