//
//  Persistence.swift
//  Boxing timer
//
//  Created by Diyar on 27.01.26.
//

import Foundation
import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BoxingTimer")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions.first?.shouldAddStoreAsynchronously = false
        
        container.viewContext.automaticallyMergesChangesFromParent = true

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
#if DEBUG
                fatalError("Unresolved error \(error), \(error.userInfo)")
#else
                print("Core Data store konnte nicht geladen werden: \(error), \(error.userInfo)")
#endif
            }
        }
    }
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
#if DEBUG
                let nsError = error as NSError
                print("Unresolved error \(nsError), \(nsError.userInfo)")
#endif
            }
        }
    }
}
