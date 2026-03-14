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
        container.persistentStoreDescriptions.first?.shouldAddStoreAsynchronously = true
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Load stores asynchronously on a background queue
        Task.detached {
            await self.loadStores()
        }
    }
    
    private func loadStores() async {
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
#if DEBUG
                    fatalError("Unresolved error \(error), \(error.userInfo)")
#endif
                }
                continuation.resume()
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
