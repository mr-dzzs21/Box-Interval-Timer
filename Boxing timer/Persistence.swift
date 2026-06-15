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

        container.loadPersistentStores { [container] description, error in
            guard let error = error as NSError? else { return }
#if DEBUG
            fatalError("Unresolved error \(error), \(error.userInfo)")
#else
            print("Core Data store konnte nicht geladen werden: \(error), \(error.userInfo)")
            // Wiederherstellung: beschädigten/inkompatiblen Store entfernen und neu
            // anlegen, damit die App nutzbar bleibt (alte History geht dabei verloren,
            // statt die App dauerhaft in einem kaputten Zustand laufen zu lassen).
            guard let storeURL = description.url, storeURL.path != "/dev/null" else { return }
            do {
                try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
                container.loadPersistentStores { _, retryError in
                    if let retryError = retryError as NSError? {
                        print("Core Data Wiederherstellung fehlgeschlagen: \(retryError), \(retryError.userInfo)")
                    }
                }
            } catch {
                print("Core Data Store-Wiederherstellung nicht möglich: \(error)")
            }
#endif
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
