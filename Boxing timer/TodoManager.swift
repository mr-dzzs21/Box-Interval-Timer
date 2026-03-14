//
//  TodoManager.swift
//  Boxing timer
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

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
    static let shared = TodoManager()

    @Published var todos: [Todo] = []

    private let key = "todos"

    init() { load() }

    func add(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        todos.append(Todo(title: title))
        save()
        scheduleNotificationIfNeeded()
    }

    func toggle(_ todo: Todo) {
        guard let i = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[i].isDone.toggle()
        save()
        scheduleNotificationIfNeeded()
    }

    func delete(at offsets: IndexSet) {
        todos.remove(atOffsets: offsets)
        save()
        scheduleNotificationIfNeeded()
    }

    // MARK: - Usage Tracking

    func recordAppOpen() {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        // Nacht-Öffnungen ignorieren (00:00 – 06:59), z.B. versehentlich
        guard hour >= 7 else { return }
        let minutesSinceMidnight = hour * 60 + minute
        var opens = UserDefaults.standard.array(forKey: "appOpenTimes") as? [Int] ?? []
        opens.append(minutesSinceMidnight)
        // Nur die letzten 20 Öffnungen behalten
        if opens.count > 20 { opens = Array(opens.suffix(20)) }
        UserDefaults.standard.set(opens, forKey: "appOpenTimes")
    }

    private func averageNotificationTime() -> (hour: Int, minute: Int) {
        let opens = UserDefaults.standard.array(forKey: "appOpenTimes") as? [Int] ?? []
        // Mindestens 3 Datenpunkte nötig, sonst Standard 9:00
        guard opens.count >= 3 else { return (9, 0) }
        let avg = opens.reduce(0, +) / opens.count
        return (avg / 60, avg % 60)
    }

    // MARK: - Notifications

    func scheduleNotificationIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "todoNotificationsEnabled") else {
            cancelNotifications()
            return
        }
        let open = todos.filter { !$0.isDone }
        guard !open.isEmpty else {
            cancelNotifications()
            return
        }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Box Interval Timer"
        content.body = open.count == 1
            ? "Du hast noch 1 offenes Todo!"
            : "Du hast noch \(open.count) offene Todos!"
        content.sound = .default
        let time = averageNotificationTime()
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "todo_daily", content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: ["todo_daily"])
        center.add(request)
    }

    func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["todo_daily"])
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
