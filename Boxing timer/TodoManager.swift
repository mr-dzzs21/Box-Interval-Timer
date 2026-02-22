//
//  TodoManager.swift
//  Boxing timer
//

import Foundation
import SwiftUI
import Combine

struct Todo: Identifiable, Codable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.createdAt = Date()
    }
}

class TodoManager: ObservableObject {
    @Published var todos: [Todo] = []

    private let key = "todos"

    init() { load() }

    func add(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        todos.append(Todo(title: title))
        save()
    }

    func toggle(_ todo: Todo) {
        guard let i = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[i].isDone.toggle()
        save()
    }

    func delete(at offsets: IndexSet) {
        todos.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Todo].self, from: data) else { return }
        todos = decoded
    }
}
